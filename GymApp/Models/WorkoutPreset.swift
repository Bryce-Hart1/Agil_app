import Foundation

/// One exercise within a preset: which exercise, and the target rep range to
/// aim for. (No sets — those get filled in when you actually do the workout.)
struct PresetItem: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseId: UUID
    var targetRepRange: RepRange?
    var note: String?               // optional form cue, carried into started workouts

    init(id: UUID = UUID(), exerciseId: UUID, targetRepRange: RepRange? = nil, note: String? = nil) {
        self.id = id
        self.exerciseId = exerciseId
        self.targetRepRange = targetRepRange
        self.note = note
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

/// Curated SF Symbols offered as preset icons (all available on iOS 16+).
enum PresetIcons {
    static let all: [String] = [
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
}
