import Foundation

/// One exercise within a preset: which exercise, and the target rep range to
/// aim for. (No sets — those get filled in when you actually do the workout.)
struct PresetItem: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseId: UUID
    var targetRepRange: RepRange?
    var note: String?               // optional form cue, carried into started workouts
    // Claude  Date 06/12/2026
    // Optional rest duration (seconds) between sets, carried into started workouts
    // where it drives a live countdown timer. nil = no rest timer for this exercise.
    var restSeconds: Int?

    init(id: UUID = UUID(), exerciseId: UUID, targetRepRange: RepRange? = nil,
         note: String? = nil, restSeconds: Int? = nil) {
        self.id = id
        self.exerciseId = exerciseId
        self.targetRepRange = targetRepRange
        self.note = note
        self.restSeconds = restSeconds
    }
}

/// A reusable workout template, e.g. "Push Day". Customizable by name, icon, and
/// the exercises (with rep ranges) it contains. Used to start a pre-filled workout.
struct WorkoutPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var symbolName: String      // an SF Symbol name, see PresetIcons
    var items: [PresetItem]

    init(id: UUID = UUID(), name: String = "", symbolName: String = "dumbbell.fill",
         items: [PresetItem] = []) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.items = items
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

    // Claude  Date 06/30/2026
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
