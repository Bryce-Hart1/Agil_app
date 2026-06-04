import Foundation

/// A single set within a workout.
/// `weight` is always stored in pounds (lb) — the canonical unit. Convert only for display.
struct ExerciseSet: Identifiable, Codable, Hashable {
    let id: UUID
    var reps: Int
    var weight: Double

    init(id: UUID = UUID(), reps: Int, weight: Double) {
        self.id = id
        self.reps = reps
        self.weight = weight
    }
}

/// All the sets performed for one exercise during a single workout.
struct LoggedExercise: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseId: UUID   // references an Exercise in the library
    var sets: [ExerciseSet]

    init(id: UUID = UUID(), exerciseId: UUID, sets: [ExerciseSet] = []) {
        self.id = id
        self.exerciseId = exerciseId
        self.sets = sets
    }
}

/// A single training session.
struct Workout: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var exercises: [LoggedExercise]
    var notes: String

    init(id: UUID = UUID(), date: Date = Date(), exercises: [LoggedExercise] = [], notes: String = "") {
        self.id = id
        self.date = date
        self.exercises = exercises
        self.notes = notes
    }

    /// Total number of sets across all exercises in this workout.
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}
