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

// Claude  Date 07/01/2026
// The weight the app suggests for an exercise this session, computed from history
// when a workout is started from an ADAPTIVE preset (double progression). `outcome`
// says why (hit top → up, missed bottom twice → down, otherwise hold) and
// `deltaFromLast` is the signed change from last session's working weight, both used
// to render the editable hint in the workout editor. Nothing here forces a value —
// it just seeds the first set and shows the reasoning; the user can overwrite freely.
struct AdaptiveSuggestion: Codable, Hashable {
    enum Outcome: String, Codable, Hashable { case increased, held, deloaded }
    var weight: Double
    var deltaFromLast: Double   // +inc when increased, -inc when deloaded, 0 when held
    var outcome: Outcome
}

/// All the sets performed for one exercise during a single workout.
struct LoggedExercise: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseId: UUID            // references an Exercise in the library
    var targetRepRange: RepRange?   // optional per-exercise rep-range goal (e.g. 6–8)
    var note: String?               // optional form cue (e.g. "pause at chest")
    var restSeconds: Int?           // rest timer duration (s), carried from a preset
    var sets: [ExerciseSet]
    // Claude  Date 07/01/2026
    // Adaptive-preset weight suggestion for this session (nil for non-adaptive presets
    // and ad-hoc exercises). Synthesized Codable defaults it to nil for old data.
    var adaptive: AdaptiveSuggestion?

    init(id: UUID = UUID(), exerciseId: UUID, targetRepRange: RepRange? = nil,
         note: String? = nil, restSeconds: Int? = nil, sets: [ExerciseSet] = [],
         adaptive: AdaptiveSuggestion? = nil) {
        self.id = id
        self.exerciseId = exerciseId
        self.targetRepRange = targetRepRange
        self.note = note
        self.restSeconds = restSeconds
        self.sets = sets
        self.adaptive = adaptive
    }
}

/// A single training session.
struct Workout: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var exercises: [LoggedExercise]
    var notes: String
    // Claude  Date 06/16/2026
    // Whether the session has been marked complete. A newly started workout is
    // active (false) — it shows in the live mini-bar and grants NO badges/stats
    // until finished. Marking it complete (AppStore.finishWorkout) logs its done
    // sets to the activity ledger and flips this true.
    var isFinished: Bool
    // Claude  Date 07/01/2026
    // Wall-clock stamps of the REAL session span, used for the performance card's
    // elapsed time. `date` is the user-facing workout date (editable in the DatePicker);
    // these two are set by the app and never edited, so elapsed stays correct even when
    // the app is backgrounded / the phone is locked, and it can't be skewed by changing
    // the date. `startedAt` is stamped on creation; `finishedAt` once, when the workout
    // is completed (see AppStore.finishWorkout) — nil while still in progress.
    var startedAt: Date
    var finishedAt: Date?

    init(id: UUID = UUID(), date: Date = Date(), exercises: [LoggedExercise] = [],
         notes: String = "", isFinished: Bool = false,
         startedAt: Date = Date(), finishedAt: Date? = nil) {
        self.id = id
        self.date = date
        self.exercises = exercises
        self.notes = notes
        self.isFinished = isFinished
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    /// Total number of sets across all exercises in this workout.
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    // Claude  Date 06/16/2026
    // Count of sets the user has checked off (the ones that will be credited on
    // completion). Used by the mini-bar / in-progress row summary.
    var completedSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { $0.completedAt != nil }.count }
    }

    // Claude  Date 06/16/2026
    // Custom decode so workouts saved before `isFinished` existed load as FINISHED
    // (true) — they predate the active-session concept, so they shouldn't suddenly
    // appear as in-progress. New workouts use the init default (false = active).
    // encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey {
        case id, date, exercises, notes, isFinished, startedAt, finishedAt
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        exercises = try c.decodeIfPresent([LoggedExercise].self, forKey: .exercises) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isFinished = try c.decodeIfPresent(Bool.self, forKey: .isFinished) ?? true
        // Claude  Date 07/01/2026
        // New stamps: workouts saved before these existed fall back to `date` for the
        // start and carry no finish time (WorkoutSummary then uses its old set-span calc).
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? date
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
    }
}
