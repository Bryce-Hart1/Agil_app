import Foundation



/// Aggregate lifting stats for the profile. Computed from the user's data, and
/// Codable so the exact same shape can be sent to a server later for an online
/// profile / leaderboards.
/// Edited 6/10/26 Bryce Hart
/// added favoriteCurrentExercise, points total, 
struct ProfileStats: Codable, Hashable {
    var totalWorkouts: Int
    var totalSets: Int
    var daysLogged: Int          // distinct calendar days with at least one workout
    var totalVolume: Double      // Σ reps×weight across all sets, in lb
    var heaviestLift: Double     // single heaviest set weight, in lb
    // Claude  Date 06/14/2026
    // Heaviest confirmed set per big-3 lift, in lb — each drives its own badges now
    // (split out from the old single bestBig3Lift).
    var bestSquatLift: Double
    var bestBenchLift: Double
    var bestDeadliftLift: Double
    var weekStreak: Int          // consecutive calendar weeks (incl. current) with a workout
    var topMuscleGroup: String?  // most-trained category by set count
    var memberSince: Date?       // date of the earliest workout
    var favoriteCurrentExercise: String? //current favorite exercise based on last 15 workouts avg
    var totalPoints: Int //total points racked up by user
    

    init(workouts: [Workout], exercises: [Exercise]) {
        totalWorkouts = workouts.count
        totalSets = workouts.reduce(0) { $0 + $1.totalSets }
        // Claude  Date 06/13/2026
        // Distinct days trained (used as the "Days Logged" achievement).
        daysLogged = Set(workouts.map { Calendar.current.startOfDay(for: $0.date) }).count

        var volume = 0.0
        var heaviest = 0.0
        var bestByLift: [LiftType: Double] = [:]
        let categoryByExercise = Dictionary(
            exercises.map { ($0.id, $0.category) }, uniquingKeysWith: { first, _ in first }
        )
        var setsByCategory: [String: Int] = [:]

        // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
        // Map each big-3 exercise to its lift type, so each lift's best is tracked
        // separately (squat / bench / deadlift each earn their own badges).
        let liftTypeByExercise = Dictionary(
            exercises.compactMap { e in e.liftType.map { (e.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )

        for workout in workouts {
            for logged in workout.exercises {
                let category = categoryByExercise[logged.exerciseId] ?? "Other"
                setsByCategory[category, default: 0] += logged.sets.count
                let liftType = liftTypeByExercise[logged.exerciseId]
                for set in logged.sets {
                    volume += Double(set.reps) * set.weight
                    heaviest = Swift.max(heaviest, set.weight)
                    if let liftType {
                        bestByLift[liftType] = Swift.max(bestByLift[liftType] ?? 0, set.weight)
                    }
                }
            }
        }

        totalVolume = volume
        heaviestLift = heaviest
        bestSquatLift = bestByLift[.squat] ?? 0
        bestBenchLift = bestByLift[.bench] ?? 0
        bestDeadliftLift = bestByLift[.deadlift] ?? 0
        topMuscleGroup = setsByCategory.max { $0.value < $1.value }?.key
        memberSince = workouts.map(\.date).min()

        // Consecutive calendar weeks ending this week that contain a workout.
        let calendar = Calendar.current
        var weeksWithWorkouts = Set<Date>()
        for workout in workouts {
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start {
                weeksWithWorkouts.insert(weekStart)
            }
        }
        var streak = 0
        if let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start {
            var cursor = thisWeek
            while weeksWithWorkouts.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
                cursor = previous
            }
        }
        weekStreak = streak

        // Claude  Date 06/10/2026 last changed: 06/13/2026 by: Claude
        // favoriteCurrentExercise = the most-performed exercise (by set count)
        // across the most recent 15 workouts. totalPoints is now the lifetime
        // coins earned from workout consistency (see Coins.earned) — this is the
        // *earned* total; the spendable balance subtracts what's been spent.
        let recentWorkouts = workouts.sorted { $0.date > $1.date }.prefix(15)
        var setsByExercise: [UUID: Int] = [:]
        for workout in recentWorkouts {
            for logged in workout.exercises {
                setsByExercise[logged.exerciseId, default: 0] += logged.sets.count
            }
        }
        let nameByExercise = Dictionary(
            exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }
        )
        favoriteCurrentExercise = setsByExercise.max { $0.value < $1.value }
            .flatMap { nameByExercise[$0.key] }
        totalPoints = Coins.earned(from: workouts)
    }

    // Claude  Date 06/14/2026
    // Achievement-facing stats derived from the tamper-resistant activity ledger
    // (ActivityEvent) instead of editable workout numbers. Only the fields the
    // achievement catalog actually reads are meaningful here — daysLogged,
    // totalVolume, bestBig3Lift, heaviestLift, weekStreak; display-only fields are
    // left at neutral defaults because unlock decisions never touch them. This is
    // the anti-cheat boundary: credit comes ONLY from sets completed in real time,
    // and days/streak are counted from each event's `loggedAt`, so backdating or
    // bulk-typing in a single session can't fabricate progress.
    init(events: [ActivityEvent]) {
        let calendar = Calendar.current
        totalWorkouts = 0
        totalSets = events.count
        // Days/streak count every day a set was completed (real-time gated in
        // Phase 1); plausibility filtering below only affects lift/volume credit.
        daysLogged = Set(events.map { calendar.startOfDay(for: $0.loggedAt) }).count

        // Claude  Date 06/14/2026 — Phase 2 plausibility guards (AchievementPolicy).
        // 1) Drop humanly-impossible sets so garbage numbers can't earn credit.
        let plausible = events.filter {
            $0.reps > 0 && $0.reps <= AchievementPolicy.maxPlausibleReps
                && $0.weight > 0 && $0.weight <= AchievementPolicy.maxPlausibleWeight
        }

        // Group the plausible sets by the real calendar day they were completed.
        let byDay = Dictionary(grouping: plausible) { calendar.startOfDay(for: $0.loggedAt) }

        // 2) Total Lifted credit: each day contributes at most dailyVolumeCap, so
        // the volume milestones can't be dumped in one session.
        var creditedVolume = 0.0
        for (_, dayEvents) in byDay {
            let dayVolume = dayEvents.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            creditedVolume += Swift.min(dayVolume, AchievementPolicy.dailyVolumeCap)
        }
        totalVolume = creditedVolume

        // heaviestLift is display-only (no achievement reads it) — take the heaviest
        // plausible set so it isn't skewed by rejected garbage.
        heaviestLift = plausible.map(\.weight).max() ?? 0

        // 3) Big-3 credit requires a weight to be hit on ≥ big3ConfirmationDays
        // distinct days, per lift. The credited best for a lift is the Nth-highest
        // of its per-day bests, so a single fake heavy set never unlocks a tier.
        func confirmedBest(_ type: LiftType) -> Double {
            let dayBests = byDay.values
                .compactMap { day in day.filter { $0.liftType == type }.map(\.weight).max() }
                .sorted(by: >)
            return dayBests.count >= AchievementPolicy.big3ConfirmationDays
                ? dayBests[AchievementPolicy.big3ConfirmationDays - 1]
                : 0
        }
        bestSquatLift = confirmedBest(.squat)
        bestBenchLift = confirmedBest(.bench)
        bestDeadliftLift = confirmedBest(.deadlift)

        // Consecutive calendar weeks ending this week with a completed set
        // (mirrors the workout-based logic above, but keyed on real `loggedAt`).
        var weeksWithActivity = Set<Date>()
        for event in events {
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: event.loggedAt)?.start {
                weeksWithActivity.insert(weekStart)
            }
        }
        var streak = 0
        if let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start {
            var cursor = thisWeek
            while weeksWithActivity.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
                cursor = previous
            }
        }
        weekStreak = streak

        // Display-only fields — not used by any achievement.
        topMuscleGroup = nil
        memberSince = events.map(\.loggedAt).min()
        favoriteCurrentExercise = nil
        totalPoints = 0
    }

}
