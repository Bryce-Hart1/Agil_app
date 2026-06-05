import Foundation

/// Aggregate lifting stats for the profile. Computed from the user's data, and
/// Codable so the exact same shape can be sent to a server later for an online
/// profile / leaderboards.
struct ProfileStats: Codable, Hashable {
    var totalWorkouts: Int
    var totalSets: Int
    var totalVolume: Double      // Σ reps×weight across all sets, in lb
    var heaviestLift: Double     // single heaviest set weight, in lb
    var weekStreak: Int          // consecutive calendar weeks (incl. current) with a workout
    var topMuscleGroup: String?  // most-trained category by set count
    var memberSince: Date?       // date of the earliest workout

    init(workouts: [Workout], exercises: [Exercise]) {
        totalWorkouts = workouts.count
        totalSets = workouts.reduce(0) { $0 + $1.totalSets }

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
    }
}
