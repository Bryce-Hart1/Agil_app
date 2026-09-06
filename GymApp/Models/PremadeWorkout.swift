import Foundation

// Claude  Date 07/25/2026
// Shipped, ready-made workout templates offered to users who haven't built any
// presets yet (see PremadeWorkoutsView). Picking one installs a normal
// WorkoutPreset into the user's library — after that it's an ordinary preset with
// no link back to this catalog beyond `premadeID`, so it's freely editable.
//
// These types are NOT Codable and never persisted: the catalog is compiled in, and
// the only thing that hits disk is the WorkoutPreset it produces.

/// One lift inside a shipped template.
///
/// Lifts are referenced BY NAME, never by id — `AppStore.seedExercises` builds its
/// exercises with fresh `UUID()`s on each install, so the ids differ per device and
/// can't be baked into a shipped catalog. `AppStore.installPremade` resolves the name
/// against the user's library at install time.
struct PremadeExercise {
    /// Must match an `AppStore.seedExercises` name exactly (case-insensitively), unless
    /// `fallback` supplies the metadata for a lift outside the seed library.
    let name: String
    /// Planned working sets, pre-filled when a workout is started from the preset.
    var sets: Int? = PresetItem.defaultTargetSets
    /// Target rep range, e.g. `RepRange(min: 6, max: 8)`. nil = no target.
    var reps: RepRange? = nil
    /// Rest between sets in seconds — use a value from `RestDuration.options`.
    var restSeconds: Int? = nil
    /// Optional form cue, carried into the preset item and into started workouts.
    var note: String? = nil
    // Claude  Date 07/25/2026
    // Metadata used ONLY when `name` matches neither the user's library nor the seed
    // list — it lets the catalog introduce lifts beyond the 55 shipped ones. Its `id`
    // is ignored; installPremade mints a fresh one. nil for every seed-library lift,
    // which is the common case.
    var fallback: Exercise? = nil

    init(_ name: String, sets: Int? = PresetItem.defaultTargetSets, reps: RepRange? = nil,
         rest: Int? = nil, note: String? = nil, fallback: Exercise? = nil) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = rest
        self.note = note
        self.fallback = fallback
    }
}

/// A shipped workout template. The user can rename it and swap its icon before
/// installing; everything else carries over as-is.
struct PremadeWorkout: Identifiable {
    /// Stable slug (e.g. "push-day"), stored on the installed preset as `premadeID` so
    /// the browse list can mark it "Added" even after the user renames it. Never
    /// change a slug once shipped — that orphans the mark on existing installs.
    let id: String
    /// Default preset name, pre-filled in the detail screen's name field.
    let name: String
    /// Default icon — must be a value from `PresetIcons.all`.
    let symbolName: String
    /// One-line "what is this" for the browse row, e.g. "Chest, shoulders, triceps".
    let subtitle: String
    /// Seeds the installed preset's adaptive (double-progression) toggle.
    var isAdaptive: Bool = false
    let items: [PremadeExercise]

    /// "6 lifts · Chest, shoulders, triceps" — the browse row's secondary line.
    var rowSubtitle: String {
        "\(items.count) lift\(items.count == 1 ? "" : "s") · \(subtitle)"
    }
}

// Claude  Date 07/25/2026
// The shipped catalog. PLACEHOLDER CONTENT: these two are stand-ins built strictly
// from AppStore.seedExercises names so the feature is testable end to end. The real
// set is being authored in new_workouts/new_workouts.md and will replace them —
// see that file for the fields each entry needs.
enum PremadeWorkouts {
    static let all: [PremadeWorkout] = [
        PremadeWorkout(
            id: "push-day",
            name: "Push Day",
            symbolName: "figure.strengthtraining.traditional",
            subtitle: "Chest, shoulders, triceps",
            items: [
                PremadeExercise("Barbell Bench Press", sets: 4, reps: RepRange(min: 6, max: 8), rest: 180),
                PremadeExercise("Incline Barbell Press", sets: 3, reps: RepRange(min: 8, max: 10), rest: 150),
                PremadeExercise("Overhead Press", sets: 3, reps: RepRange(min: 8, max: 10), rest: 150),
                PremadeExercise("Cable Lateral Raise", sets: 3, reps: RepRange(min: 12, max: 15), rest: 60),
                PremadeExercise("Triceps Pushdown", sets: 3, reps: RepRange(min: 10, max: 12), rest: 75),
                PremadeExercise("Overhead Cable Extension", sets: 3, reps: RepRange(min: 10, max: 12), rest: 75),
            ]
        ),
        PremadeWorkout(
            id: "full-body-a",
            name: "Full Body A",
            symbolName: "dumbbell.fill",
            subtitle: "One session, every major muscle",
            items: [
                PremadeExercise("Barbell Back Squat", sets: 3, reps: RepRange(min: 5, max: 8), rest: 180),
                PremadeExercise("Barbell Bench Press", sets: 3, reps: RepRange(min: 6, max: 8), rest: 180),
                PremadeExercise("Seated Cable Row", sets: 3, reps: RepRange(min: 8, max: 12), rest: 120),
                PremadeExercise("Romanian Deadlift", sets: 3, reps: RepRange(min: 8, max: 10), rest: 150),
                PremadeExercise("Dumbbell Lateral Raise", sets: 3, reps: RepRange(min: 12, max: 15), rest: 60),
                PremadeExercise("Hanging Leg Raise", sets: 3, reps: RepRange(min: 10, max: 15), rest: 60),
            ]
        ),
    ]
}
