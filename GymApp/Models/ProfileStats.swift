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
        let categoryByExercise = Dictionary(
            exercises.map { ($0.id, $0.category) }, uniquingKeysWith: { first, _ in first }
        )
        var setsByCategory: [String: Int] = [:]

        for workout in workouts {
            for logged in workout.exercises {
                let category = categoryByExercise[logged.exerciseId] ?? "Other"
                setsByCategory[category, default: 0] += logged.sets.count
                for set in logged.sets {
                    volume += Double(set.reps) * set.weight
                    heaviest = Swift.max(heaviest, set.weight)
                }
            }
        }

        totalVolume = volume
        heaviestLift = heaviest
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
}
