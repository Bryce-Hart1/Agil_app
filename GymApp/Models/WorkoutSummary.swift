import Foundation

// Claude  Date 06/16/2026
// A snapshot of how a just-finished workout went, shown on the performance card the
// moment you complete a workout (before any achievement pops). Computed purely from
// the workout's CHECKED-OFF sets (the ones that earn credit), so it mirrors what was
// actually logged. Transient — built on finish, not persisted.
//
// First pass intentionally simple; the stats (especially "best set") are meant to
// grow. `bestSet` currently picks the highest estimated 1RM (Epley) — a reasonable
// proxy until a smarter scoring lands.
struct WorkoutSummary: Identifiable, Hashable {
    let id: UUID            // the workout's id (also keys the overlay)
    let date: Date
    let duration: TimeInterval   // span of the checked-off sets (first → last)
    let completedSets: Int
    let totalVolume: Double      // Σ reps × weight, in lb
    let exerciseCount: Int       // exercises with at least one checked set
    let bestSet: BestSet?

    // Claude  Date 06/16/2026
    // The standout set of the session. e1RM is Epley: weight × (1 + reps/30).
    struct BestSet: Hashable {
        let exerciseName: String
        let reps: Int
        let weight: Double
        let estimatedOneRepMax: Double
    }

    init(workout: Workout, exercises: [Exercise]) {
        id = workout.id
        date = workout.date

        func name(_ exerciseId: UUID) -> String {
            exercises.first { $0.id == exerciseId }?.name ?? "Exercise"
        }

        var times: [Date] = []
        var volume = 0.0
        var sets = 0
        var exercisesWithSets = Set<UUID>()
        var bestE1RM = -1.0
        var best: BestSet?

        for logged in workout.exercises {
            for set in logged.sets where set.completedAt != nil {
                sets += 1
                volume += Double(set.reps) * set.weight
                exercisesWithSets.insert(logged.exerciseId)
                if let t = set.completedAt { times.append(t) }

                let e1rm = set.weight * (1 + Double(set.reps) / 30)
                if e1rm > bestE1RM {
                    bestE1RM = e1rm
                    best = BestSet(exerciseName: name(logged.exerciseId),
                                   reps: set.reps, weight: set.weight,
                                   estimatedOneRepMax: e1rm)
                }
            }
        }

        completedSets = sets
        totalVolume = volume
        exerciseCount = exercisesWithSets.count
        bestSet = best
        if let first = times.min(), let last = times.max() {
            duration = last.timeIntervalSince(first)
        } else {
            duration = 0
        }
    }

    // Claude  Date 06/16/2026
    // "1h 5m" / "42 min" / "<1 min" — compact duration for the card.
    var durationText: String {
        let minutes = Int(duration) / 60
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m) min" }
        return "<1 min"
    }
}
