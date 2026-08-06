import Foundation
// Peer reviewed: July 29 26 Bryce Hart

/// One exercise within a preset: which exercise, and the target rep range to
/// aim for. (No sets — those get filled in when you actually do the workout.)
struct PresetItem: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseId: UUID
    var targetRepRange: RepRange?
    var note: String?               // optional form cue, carried into started workouts
    // Optional rest duration (seconds) between sets, carried into started workouts
    // where it drives a live countdown timer. nil = no rest timer for this exercise.
    var restSeconds: Int?
    // Per-exercise override of the adaptive weight increment (lb). Only meaningful when
    // the parent preset is adaptive. nil = use AppStore.smartIncrement's default (5 lb,
    // or 10 lb for lower-body / deadlift). Synthesized Codable defaults it to nil.
    var weightIncrement: Double?
    // Planned number of working sets for this exercise, chosen up front in the preset.
    // Starting a workout from the preset pre-fills this many (empty, unchecked) sets so
    // you don't tap "Add Set" repeatedly (see AppStore.workout(from:)). nil = don't
    // pre-fill (presets that predate this, or the picker's "None"). Blank workouts have
    // no preset, so this never applies to them. Synthesized Codable defaults it to nil.
    var targetSets: Int?

    // Default set count for a freshly added preset exercise (a typical working-set count
    // for a strength movement). Existing preset items keep whatever they had, incl. nil.
    static let defaultTargetSets = 3

    init(id: UUID = UUID(), exerciseId: UUID, targetRepRange: RepRange? = nil,
         note: String? = nil, restSeconds: Int? = nil, weightIncrement: Double? = nil,
         targetSets: Int? = nil) {
        self.id = id
        self.exerciseId = exerciseId
        self.targetRepRange = targetRepRange
        self.note = note
        self.restSeconds = restSeconds
        self.weightIncrement = weightIncrement
        self.targetSets = targetSets
    }
}

/// A reusable workout template, e.g. "Push Day". Customizable by name, icon, and
/// the exercises (with rep ranges) it contains. Used to start a pre-filled workout.
struct WorkoutPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var symbolName: String      // an SF Symbol name, see PresetIcons
    var items: [PresetItem]
    // Adaptive (double-progression) mode toggle. When true, starting a workout from
    // this preset pre-fills each exercise's working weight from history: up when the top
    // of the rep range was hit last time, down after repeated misses, else hold. One
    // switch applies to every item. Synthesized Codable defaults it to false for old data.
    var isAdaptive: Bool
    // Provenance: the `PremadeWorkout.id` slug this preset was installed from, or nil
    // for one the user built themselves. Only used to mark a template "Added" in the
    // browse list — it survives a rename, which a name match wouldn't. Optional, so
    // the synthesized Codable decodes presets saved before this field existed as nil.
    var premadeID: String?
    // Claude  Date 08/04/2026
    // Notes for the template as a whole — "warm up on the bar first", "superset 2
    // and 3". Copied onto a workout started from this preset (AppStore.workout(from:))
    // and back off it when the workout is saved as, or overridden onto, a preset.
    // Optional so the synthesized Codable decodes older presets as nil.
    var notes: String?

    init(id: UUID = UUID(), name: String = "", symbolName: String = "dumbbell.fill",
         items: [PresetItem] = [], isAdaptive: Bool = false, premadeID: String? = nil,
         notes: String? = nil) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.items = items
        self.isAdaptive = isAdaptive
        self.premadeID = premadeID
        self.notes = notes
    }
}

/// Icons offered for a preset. Two kinds, stored the same way (the chosen name lives
/// in `WorkoutPreset.symbolName`): curated SF Symbols, and custom PNG assets from the
/// asset catalog. `isCustomAsset` lets the render sites pick `Image(_:)` vs
/// `Image(systemName:)` — see PresetIconView.
enum PresetIcons {
    // SF Symbols (all available on iOS 16+). System-rendered, so they tint to the accent.
    static let symbols: [String] = [
        "dumbbell.fill",
        "figure.strengthtraining.traditional",
        "figure.strengthtraining.functional",
        "figure.run",
        "figure.core.training",
        "figure.arms.open",
        "figure.cooldown",
        "flame.fill",
        "bolt.fill",
        "heart.fill",
        "star.fill",
        "trophy.fill",
        "scalemass.fill",
        "timer",
        "calendar",
        "leaf.fill",
    ]

    // Custom PNG imagesets in Assets.xcassets, selectable alongside the symbols. Marked
    // template-rendering in their Contents.json, so they tint to the accent just like the
    // SF Symbols (the PNG's alpha is the shape).
    static let customAssets: [String] = [
        "SquatSide",
        "ArmSide",
        "tricepSide",
    ]

    /// Everything selectable in the icon picker (symbols first, then custom art).
    static let all: [String] = symbols + customAssets

    /// True when `name` is one of our custom PNG assets (vs an SF Symbol).
    static func isCustomAsset(_ name: String) -> Bool { customAssets.contains(name) }
}
