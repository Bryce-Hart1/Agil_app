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
    // Claude  Date 07/11/2026
    // Heaviest confirmed Bicep Curl set, in lb — drives the Bicep Curl badges
    // (same treatment as the big-3 lifts, just not flagged isBig3Lift).
    var bestCurlLift: Double
    // Heaviest confirmed non-deadlift back exercise, in lb. This drives the Back
    // Strength badge while leaving conventional deadlift to its own ladder.
    var bestBackLift: Double
    var weekStreak: Int          // consecutive calendar weeks (incl. current) with a workout
    var topMuscleGroup: String?  // most-trained category by set count
    var memberSince: Date?       // date of the earliest workout
    var favoriteCurrentExercise: String? //current favorite exercise based on last 15 workouts avg
    var totalPoints: Int //total points racked up by user
    // Claude  Date 07/11/2026
    // Distinct days the food diary landed within 75%-100% of the calorie goal —
    // drives the Days Tracked badges. Only populated by init(events:) (see there);
    // init(workouts:exercises:) has no nutrition data to compute it from.
    var daysNutritionOnGoal: Int
    // Claude  Date 07/25/2026
    // Whether the nutrition setup checklist's REQUIRED items are done (calorie +
    // water goals set) — drives the First Plan secret badge. Unlike every other
    // stat here this is UI-driven rather than derived from the activity ledger or
    // the food diary, so it arrives through its own `setup:` parameter; see the
    // note on init(events:). Only populated there — init(workouts:exercises:) is
    // the display path and has no profile to read.
    var completedNutritionSetup: Bool
    // Claude  Date 07/27/2026
    // Whether the user has left the Workouts tab's get-started state — installing a
    // premade split or starting a workout. Drives the First Step badge. Same
    // non-ledger exception as completedNutritionSetup above, and for the same
    // reason: it's a welcome badge with nothing to cheat. Only init(events:)
    // populates it; init(workouts:exercises:) is the display path with no profile.
    var tookFirstStep: Bool
    // Claude  Date 08/29/2026
    // Distinct days the whole due supplement stack was cleared — the count of
    // AppStore.clearedSupplementDays, which is a real-time, monotone ledger (same
    // anti-cheat shape as daysLogged). Ready to drive supplement badges; nothing
    // in the catalog reads it yet. Only init(events:) populates it —
    // init(workouts:exercises:) is the display path with no supplement data.
    var daysSupplementsCleared: Int


    init(workouts: [Workout], exercises: [Exercise]) {
        totalWorkouts = workouts.count
        totalSets = workouts.reduce(0) { $0 + $1.totalSets }
        // Claude  Date 06/13/2026
        // Distinct days trained (used as the "Days Logged" achievement).
        daysLogged = Set(workouts.map { Calendar.current.startOfDay(for: $0.date) }).count

        var volume = 0.0
        var heaviest = 0.0
        var bestByLift: [LiftType: Double] = [:]
        var bestBack = 0.0
        let exerciseByID = Dictionary(
            exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        let categoryByExercise = Dictionary(
            exercises.map { ($0.id, $0.category) }, uniquingKeysWith: { first, _ in first }
        )
        var setsByCategory: [String: Int] = [:]

        // Claude  Date 06/13/2026 last changed: 07/11/2026 by: Claude
        // Map each lift-tracked exercise to its lift type, so each lift's best is
        // tracked separately. Uses effectiveLiftType (not the raw tag) so any
        // Arms/Biceps exercise counts toward the curl badge automatically.
        let liftTypeByExercise = Dictionary(
            exercises.compactMap { e in e.effectiveLiftType.map { (e.id, $0) } },
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
                    if let exercise = exerciseByID[logged.exerciseId],
                       exercise.region == .back, exercise.effectiveLiftType != .deadlift {
                        bestBack = Swift.max(bestBack, set.weight)
                    }
                }
            }
        }

        totalVolume = volume
        heaviestLift = heaviest
        bestSquatLift = bestByLift[.squat] ?? 0
        bestBenchLift = bestByLift[.bench] ?? 0
        bestDeadliftLift = bestByLift[.deadlift] ?? 0
        bestCurlLift = bestByLift[.curl] ?? 0
        bestBackLift = bestBack
        topMuscleGroup = setsByCategory.max { $0.value < $1.value }?.key
        memberSince = workouts.map(\.date).min()

        // Claude  Date 07/13/2026
        // Consecutive calendar weeks ending this week that contain a workout —
        // shared helper (also used by the mode notch's Food-side stat).
        weekStreak = Self.weekStreak(of: workouts.map(\.date))

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
        // No nutrition data in this init — see init(events:) for the real computation.
        daysNutritionOnGoal = 0
        // Likewise no profile here, so the profile-driven flags stay neutral.
        completedNutritionSetup = false
        tookFirstStep = false
        daysSupplementsCleared = 0
    }

    // Claude  Date 06/14/2026
    // Achievement-facing stats derived from the tamper-resistant activity ledger
    // (ActivityEvent) instead of editable workout numbers. Only the fields the
    // achievement catalog actually reads are meaningful here — daysLogged,
    // totalVolume, confirmed lift/back bests, heaviestLift, and weekStreak;
    // display-only fields are left at neutral defaults. This is
    // the anti-cheat boundary: credit comes ONLY from sets completed in real time,
    // and days/streak are counted from each event's `loggedAt`, so backdating or
    // bulk-typing in a single session can't fabricate progress.
    // Claude  Date 07/11/2026 last changed: 07/11/2026 by: Claude
    // Added foodLog/nutritionGoals (defaulted, so the one existing call site in
    // AppStore.evaluateAchievements is the only place that needs updating) to
    // drive daysNutritionOnGoal — the Days Tracked badge.
    // Claude  Date 07/25/2026 last changed: 07/25/2026 by: Claude
    // Added `setup` (defaulted, same trick as foodLog/nutritionGoals above so the
    // one real call site is the only one to update) for the First Plan badge. Note
    // this is the first input here that is NOT ledger-derived — it's a record of
    // what the user configured, not of what they did. That's a deliberate exception
    // for a welcome badge with nothing to cheat; anything that competes on progress
    // must keep coming from `events`.
    // Claude  Date 07/27/2026 last changed: 07/27/2026 by: Claude
    // Added `tookFirstStep` (defaulted, same trick again) for the First Step badge —
    // the second and, deliberately, last of the non-ledger welcome-badge inputs.
    // Claude  Date 08/29/2026
    // Added `clearedSupplementDays` (defaulted, same trick) — the supplement
    // ledger AppStore.evaluateAchievements already passes; counted into
    // daysSupplementsCleared for the coming supplement badges.
    init(events: [ActivityEvent], exercises: [Exercise] = [], foodLog: [FoodEntry] = [],
         nutritionGoals: NutritionGoals = NutritionGoals(),
         setup: NutritionSetup = NutritionSetup(),
         tookFirstStep: Bool = false,
         clearedSupplementDays: Set<Date> = []) {
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
        func confirmedBest(where includes: (ActivityEvent) -> Bool) -> Double {
            let dayBests = byDay.values
                .compactMap { day in day.filter(includes).map(\.weight).max() }
                .sorted(by: >)
            return dayBests.count >= AchievementPolicy.big3ConfirmationDays
                ? dayBests[AchievementPolicy.big3ConfirmationDays - 1]
                : 0
        }
        bestSquatLift = confirmedBest { $0.liftType == .squat }
        bestBenchLift = confirmedBest { $0.liftType == .bench }
        bestDeadliftLift = confirmedBest { $0.liftType == .deadlift }
        bestCurlLift = confirmedBest { $0.liftType == .curl }

        // Current events carry a frozen region. For older ledger entries that
        // predate that field, fall back to the referenced exercise so existing
        // legitimate back work receives credit when this badge is introduced.
        let historicalBackExerciseIDs = Set(exercises.lazy.filter {
            $0.region == .back && $0.effectiveLiftType != .deadlift
        }.map(\.id))
        bestBackLift = confirmedBest { event in
            guard event.liftType != .deadlift else { return false }
            return event.muscleRegion == .back
                || (event.muscleRegion == nil && historicalBackExerciseIDs.contains(event.exerciseId))
        }

        // Claude  Date 07/13/2026
        // Consecutive calendar weeks ending this week with a completed set — same
        // shared helper as the workout-based init, but keyed on real `loggedAt`.
        weekStreak = Self.weekStreak(of: events.map(\.loggedAt))

        // Display-only fields — not used by any achievement.
        topMuscleGroup = nil
        memberSince = events.map(\.loggedAt).min()
        favoriteCurrentExercise = nil
        totalPoints = 0

        // Claude  Date 07/11/2026
        // Days Tracked credit: group the food diary by real calendar day and count
        // days whose total calories land within 75%-100% of the current goal — close
        // enough to "hit goal" without rewarding trivial under-logging. Uses the
        // *current* nutritionGoals for all days (goals aren't versioned historically),
        // matching how big-3 thresholds are just fixed numbers, not point-in-time
        // snapshots.
        let foodByDay = Dictionary(grouping: foodLog) { calendar.startOfDay(for: $0.loggedAt) }
        let goalCalories = nutritionGoals.calories
        let lowerBound = 0.75 * goalCalories
        daysNutritionOnGoal = foodByDay.values.filter { dayEntries in
            let dayCalories = dayEntries.reduce(0.0) { $0 + $1.consumed.calories }
            return dayCalories >= lowerBound && dayCalories <= goalCalories
        }.count

        // Claude  Date 07/25/2026
        // The checklist's two required items (calorie + water goals). The optional
        // focus-goals item is excluded by NutritionSetup.isComplete on purpose.
        completedNutritionSetup = setup.isComplete

        // Claude  Date 07/27/2026
        // Straight passthrough of profile.tookFirstStep — see the property note.
        self.tookFirstStep = tookFirstStep

        // Claude  Date 08/29/2026
        // The ledger entries are already day-normalized by AppStore, so the count
        // IS the distinct-day count — see the property note.
        daysSupplementsCleared = clearedSupplementDays.count
    }

    // Claude  Date 07/13/2026
    // Consecutive calendar weeks ending this week that contain at least one of
    // `dates`. Extracted from the two inits above (which duplicated this loop) so
    // the mode notch can compute the streak from workout dates alone, without
    // paying for a full ProfileStats build.
    static func weekStreak(of dates: [Date], asOf now: Date = Date()) -> Int {
        let calendar = Calendar.current
        var weeksWithActivity = Set<Date>()
        for date in dates {
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
                weeksWithActivity.insert(weekStart)
            }
        }
        var streak = 0
        if let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start {
            var cursor = thisWeek
            while weeksWithActivity.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
                cursor = previous
            }
        }
        return streak
    }

}
