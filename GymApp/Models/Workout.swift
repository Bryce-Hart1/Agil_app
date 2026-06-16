import Foundation

// Claude  Date 06/14/2026
// Which side a set was performed on, for unilateral movements (single-arm/leg).
// nil = a normal two-sided set. Unilateral exercises log sets as Left/Right pairs
// so each side is tracked (and mismatches can be surfaced).
enum ExerciseSide: String, Codable, Hashable {
    case left, right

    var title: String { self == .left ? "Left" : "Right" }
}

/// A single set within a workout.
/// `weight` is always stored in pounds (lb) — the canonical unit. Convert only for display.
struct ExerciseSet: Identifiable, Codable, Hashable {
    let id: UUID
    var reps: Int
    var weight: Double
    // Claude  Date 06/14/2026
    // Side performed for unilateral exercises (nil for normal two-sided sets).
    var side: ExerciseSide?
    // Claude  Date 06/14/2026
    // Wall-clock time the set was marked complete (nil = not completed). Set ONLY
    // by the explicit "complete set" tap — never by typing reps/weight. This is
    // what makes a set count toward achievements: completion appends a tamper-
    // resistant ActivityEvent to the ledger (see AppStore.completeSet), so editing
    // numbers without completing earns no badge credit.
    var completedAt: Date?

    init(id: UUID = UUID(), reps: Int, weight: Double,
         side: ExerciseSide? = nil, completedAt: Date? = nil) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.side = side
        self.completedAt = completedAt
    }

    // Claude  Date 06/14/2026
    // Custom decode so sets saved before `completedAt` / `side` existed still load
    // (missing keys default to nil). encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey { case id, reps, weight, side, completedAt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reps = try c.decode(Int.self, forKey: .reps)
        weight = try c.decode(Double.self, forKey: .weight)
        side = try c.decodeIfPresent(ExerciseSide.self, forKey: .side)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
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
