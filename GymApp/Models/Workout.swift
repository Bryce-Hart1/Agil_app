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
    // Claude  Date 09/07/2026
    // A CARDIO BOUT is an ExerciseSet with a duration: `durationSeconds != nil` is the
    // discriminator, and such a set carries reps = 0 / weight = 0 so it stays invisible to
    // every volume, PR and 1RM site (they all guard `reps > 0 && weight > 0`) with no edit.
    // Same move as `isBodyweight`: one logging mode more, not one data shape more.
    var durationSeconds: Int?
    /// Canonical METERS, like `weight` is canonical pounds. nil when the machine reports no
    /// honest distance (stair climber) or the user just didn't log one. Convert for display.
    var distanceMeters: Double?

    /// Whether this set is a cardio bout rather than a loaded set.
    var isCardioBout: Bool { durationSeconds != nil }

    init(id: UUID = UUID(), reps: Int, weight: Double,
         side: ExerciseSide? = nil, completedAt: Date? = nil,
         durationSeconds: Int? = nil, distanceMeters: Double? = nil) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.side = side
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
    }

    // Claude  Date 06/14/2026 last changed: 09/07/2026 by: Claude
    // Custom decode so sets saved before `completedAt` / `side` existed still load
    // (missing keys default to nil). encode(to:) is synthesized.
    // (09/07) Added durationSeconds + distanceMeters — absent on every set saved before
    // cardio existed, so nil, which means "a normal loaded set".
    // NOTE: encode(to:) is synthesized off CodingKeys, so a field left out of the enum below
    // is silently dropped on every save. Add new fields to BOTH lists (same trap as Exercise).
    enum CodingKeys: String, CodingKey {
        case id, reps, weight, side, completedAt, durationSeconds, distanceMeters
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reps = try c.decode(Int.self, forKey: .reps)
        weight = try c.decode(Double.self, forKey: .weight)
        side = try c.decodeIfPresent(ExerciseSide.self, forKey: .side)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters)
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
    var note: String?               // a note to your NEXT session (see noteIsCarriedForward)
    var restSeconds: Int?           // rest timer duration (s), carried from a preset
    var sets: [ExerciseSet]
    // Claude  Date 07/01/2026
    // Adaptive-preset weight suggestion for this session (nil for non-adaptive presets
    // and ad-hoc exercises). Synthesized Codable defaults it to nil for old data.
    var adaptive: AdaptiveSuggestion?
    // Claude  Date 08/11/2026
    // Where `note` came from, which is what gives the note a one-session lifespan:
    //
    //   nil / false — written DURING this session. A note to your future self, not yet
    //                 delivered. Renders with a filled icon and is copied into the next
    //                 session of this preset.
    //   true        — carried in from the previous session. This is its last showing, so
    //                 it renders as an outline icon and is NOT copied forward again.
    //
    // Expiry needs no cleanup pass anywhere: the next session only copies notes that were
    // fresh, so a carried note simply isn't picked up and dies with its workout. Editing a
    // carried note clears this back to false, which re-arms it for one more session.
    // Optional because LoggedExercise uses synthesized Codable — a non-optional would fail
    // to decode every workout saved before this existed.
    var noteIsCarriedForward: Bool?

    init(id: UUID = UUID(), exerciseId: UUID, targetRepRange: RepRange? = nil,
         note: String? = nil, restSeconds: Int? = nil, sets: [ExerciseSet] = [],
         adaptive: AdaptiveSuggestion? = nil, noteIsCarriedForward: Bool? = nil) {
        self.id = id
        self.exerciseId = exerciseId
        self.targetRepRange = targetRepRange
        self.note = note
        self.restSeconds = restSeconds
        self.sets = sets
        self.adaptive = adaptive
        self.noteIsCarriedForward = noteIsCarriedForward
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
    // Claude  Date 07/13/2026
    // The preset this workout was started from (nil for an empty/ad-hoc workout). Lets
    // the editor offer "Override Preset" — pushing the workout's current exercises, rep
    // ranges, and set counts back onto the source template. Synthesized decode below
    // defaults it to nil for workouts saved before the field existed.
    var presetID: UUID?

    init(id: UUID = UUID(), date: Date = Date(), exercises: [LoggedExercise] = [],
         notes: String = "", isFinished: Bool = false,
         startedAt: Date = Date(), finishedAt: Date? = nil, presetID: UUID? = nil) {
        self.id = id
        self.date = date
        self.exercises = exercises
        self.notes = notes
        self.isFinished = isFinished
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.presetID = presetID
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

    // Claude  Date 07/01/2026 last changed: 08/21/2026 by: Claude
    // How long the session actually took. Elapsed = the real wall-clock span
    // (startedAt → finishedAt), so warm-up, rest between sets, the stretch after your
    // last set, and any time the app spent backgrounded all count. The fallback — first
    // checked set to last checked set — undercounts all of that (and reads 0 for a
    // single-set session), so it's only used for workouts finished before these stamps
    // existed. nil when neither is available: an untouched workout has no honest
    // duration to show, and callers hide the label rather than print "<1 min".
    //
    // (08/21) Moved down here from WorkoutSummary, which now reads it. The History rows
    // and the editor header want this number too, and building a WorkoutSummary per row
    // would scan the exercise library and the whole activity ledger to get it.
    var elapsed: TimeInterval? {
        if let finished = finishedAt {
            return max(0, finished.timeIntervalSince(startedAt))
        }
        let times = exercises.flatMap { $0.sets.compactMap(\.completedAt) }
        guard let first = times.min(), let last = times.max() else { return nil }
        return last.timeIntervalSince(first)
    }

    // Claude  Date 09/02/2026
    // How long an active session may sit with nothing checked off before the app
    // closes it out on its own (see AppStore.autoFinishStaleWorkouts).
    static let idleFinishLimit: TimeInterval = 60 * 60

    // Claude  Date 09/02/2026
    // The last moment this session showed real activity: the newest checked-off set,
    // or `startedAt` when nothing has been checked yet (so a just-started workout gets
    // the full idle window). Clamped to `startedAt` so a hand-edited date can't push it
    // earlier. This is both the idle clock for auto-finish AND the finish stamp it uses,
    // which is what keeps a forgotten session's elapsed time honest.
    var lastActivityAt: Date {
        let times = exercises.flatMap { $0.sets.compactMap(\.completedAt) }
        return Swift.max(times.max() ?? startedAt, startedAt)
    }

    // Claude  Date 09/02/2026
    // True for an unfinished workout that's been idle past `idleFinishLimit` — i.e. the
    // user walked away and never hit Complete.
    func isStale(asOf now: Date = Date()) -> Bool {
        !isFinished && now.timeIntervalSince(lastActivityAt) >= Workout.idleFinishLimit
    }

    // Claude  Date 08/21/2026
    // `elapsed` rendered for display, or nil when there's nothing to show.
    var elapsedText: String? {
        elapsed.map(Workout.durationText)
    }

    // Claude  Date 06/16/2026 last changed: 08/21/2026 by: Claude
    // "1h 5m" / "42 min" / "<1 min" — compact duration. (08/21) The one formatter for
    // session length, so the performance card, the monthly recap, the History rows and
    // the editor header can't drift apart in how they word it.
    static func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m) min" }
        return "<1 min"
    }

    // Claude  Date 06/16/2026
    // Custom decode so workouts saved before `isFinished` existed load as FINISHED
    // (true) — they predate the active-session concept, so they shouldn't suddenly
    // appear as in-progress. New workouts use the init default (false = active).
    // encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey {
        case id, date, exercises, notes, isFinished, startedAt, finishedAt, presetID
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
        // Claude  Date 07/13/2026
        // Source preset link: absent on older workouts (they weren't tagged), so nil.
        presetID = try c.decodeIfPresent(UUID.self, forKey: .presetID)
    }
}

// Claude  Date 09/07/2026
// What KIND of session this was. DERIVED from the exercises in it, never stored: there is
// no field to migrate, no stored value that can drift out of agreement with the contents,
// and every workout ever logged classifies correctly the moment this ships.
enum WorkoutKind {
    case lifting, cardio, mixed

    var title: String {
        switch self {
        case .lifting: return "Lifting"
        case .cardio:  return "Cardio"
        case .mixed:   return "Mixed"
        }
    }

    /// What this session's entries are called — a treadmill bout is not a "set".
    func entryNoun(_ count: Int) -> String {
        switch self {
        case .lifting: return count == 1 ? "set"   : "sets"
        case .cardio:  return count == 1 ? "bout"  : "bouts"
        case .mixed:   return count == 1 ? "entry" : "entries"
        }
    }
}

extension Workout {
    // Claude  Date 09/07/2026
    // Pure function over the library, like WorkoutSummary(workout:exercises:) and
    // PersonalRecord.bests(from:exercises:) — Models never reaches into Persistence.
    // nil when the session has no exercises: an empty workout has no honest kind to
    // report, the same stance `elapsed` takes on a session with no measurable span.
    func kind(using library: [Exercise]) -> WorkoutKind? {
        guard !exercises.isEmpty else { return nil }
        let cardioIDs = Set(library.lazy.filter(\.isCardio).map(\.id))
        var sawCardio = false
        var sawLifting = false
        for logged in exercises {
            if cardioIDs.contains(logged.exerciseId) { sawCardio = true } else { sawLifting = true }
            if sawCardio && sawLifting { return .mixed }
        }
        return sawCardio ? .cardio : .lifting
    }
}
