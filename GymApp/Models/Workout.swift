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

/// A target repetition range for an exercise, e.g. 6–8 reps. Used as a goal
/// annotation while logging and as the basis for saved exercise presets later.
struct RepRange: Codable, Hashable {
    var min: Int
    var max: Int

    init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }

    /// Always reads low–high regardless of input order, e.g. "6–8" (or "8" if equal).
    var display: String {
        let low = Swift.min(min, max)
        let high = Swift.max(min, max)
        return low == high ? "\(low)" : "\(low)–\(high)"
    }
}

/// All the sets performed for one exercise during a single workout.
struct LoggedExercise: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseId: UUID            // references an Exercise in the library
    var targetRepRange: RepRange?   // optional per-exercise rep-range goal (e.g. 6–8)
    var note: String?               // optional form cue (e.g. "pause at chest")
    var restSeconds: Int?           // rest timer duration (s), carried from a preset
    var sets: [ExerciseSet]

    init(id: UUID = UUID(), exerciseId: UUID, targetRepRange: RepRange? = nil,
         note: String? = nil, restSeconds: Int? = nil, sets: [ExerciseSet] = []) {
        self.id = id
        self.exerciseId = exerciseId
        self.targetRepRange = targetRepRange
        self.note = note
        self.restSeconds = restSeconds
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
