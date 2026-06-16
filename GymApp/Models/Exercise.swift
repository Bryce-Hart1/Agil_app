import Foundation

// Claude  Date 06/13/2026
// Optional "big 3" classification used by the lift achievements. nil = unspecified
// (we fall back to a name heuristic in ProfileStats). Lets users tag an exercise
// explicitly so achievements don't depend on how it's named.
enum LiftType: String, Codable, CaseIterable, Hashable {
    case squat, bench, deadlift

    var title: String {
        switch self {
        case .squat:    return "Back Squat"
        case .bench:    return "Bench Press"
        case .deadlift: return "Deadlift"
        }
    }
}

// Claude  Date 06/14/2026
// Science-based quality tag for a movement, from the curated lift library:
// "Optimal" = high stimulus-to-fatigue / great resistance profile, "Classic" = a
// proven staple. Stored on every seed lift; nil for user-created exercises until
// they pick one. Not surfaced in the UI yet — kept for an upcoming feature.
enum LiftQuality: String, Codable, CaseIterable, Hashable {
    case optimal, classic

    var title: String { rawValue.capitalized }
}

// Claude  Date 06/14/2026
// Top-level body region — the PRIMARY grouping for browsing the library, sitting
// above the muscle sub-group (`category`). e.g. region "Legs" contains the Quads /
// Hamstrings / Glutes / Calves sub-groups. `allCases` order defines section order;
// `.other` catches custom exercises with no region assigned.
enum MuscleRegion: String, Codable, CaseIterable, Hashable {
    case legs, chest, back, shoulders, arms, core, other

    var title: String {
        switch self {
        case .legs:      return "Legs"
        case .chest:     return "Chest"
        case .back:      return "Back"
        case .shoulders: return "Shoulders"
        case .arms:      return "Arms"
        case .core:      return "Core"
        case .other:     return "Other"
        }
    }
}

/// A movement you can perform, e.g. "Barbell Bench Press".
/// This is your reusable exercise library; individual workouts reference it by `id`.
struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    // Claude  Date 06/14/2026
    // Two-level grouping: `region` is the body region (Legs, Back…) used as the
    // primary browse section; `category` is the muscle sub-group within it.
    var region: MuscleRegion
    var category: String   // muscle sub-group, e.g. "Quads", "Lats" — drives graphs
    // Claude  Date 06/09/2026
    // Whether the movement is performed one side at a time (e.g. single-arm row).
    // Set when creating the exercise; used to track it differently on graphs.
    var isUnilateral: Bool
    // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
    // Explicit "big 3" tag for the lift achievements. Now the SOLE source of big-3
    // truth (the old name heuristic is gone) — nil simply means "not a big-3 lift".
    var liftType: LiftType?
    // Claude  Date 06/14/2026
    // The muscle this movement primarily drives, e.g. "Quadriceps", "Gluteus
    // Maximus", "Latissimus Dorsi". The science detail for the curated library;
    // `category` holds the coarser sub-group used for grouping/graphs.
    var primaryMover: String
    // Claude  Date 06/14/2026
    // Optimal/Classic quality tag (see LiftQuality). nil for untagged custom lifts.
    var quality: LiftQuality?

    init(id: UUID = UUID(), name: String, region: MuscleRegion = .other, category: String,
         isUnilateral: Bool = false, liftType: LiftType? = nil,
         primaryMover: String = "", quality: LiftQuality? = nil) {
        self.id = id
        self.name = name
        self.region = region
        self.category = category
        self.isUnilateral = isUnilateral
        self.liftType = liftType
        self.primaryMover = primaryMover
        self.quality = quality
    }

    // Claude  Date 06/09/2026 Edited 6/10/2026 Bryce Hart
    // Name with a "(unilateral)" suffix when applicable, for graph/stat labels.
    //made capital
    var displayLabel: String {
        isUnilateral ? "\(name) (Unilateral)" : name
    }

    // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
    // Whether this exercise counts toward the "big 3" lift achievements. Driven
    // solely by the explicit `liftType` tag now — the old name heuristic was
    // dropped because the expanded library (Hack Squat, Bulgarian Split Squat,
    // Close-Grip Bench Press…) would otherwise false-match on "squat"/"bench".
    var countsAsBig3: Bool {
        liftType != nil
    }

    // Claude  Date 06/09/2026 last changed: 06/14/2026 by: Claude
    // Custom decode so exercises saved before newer fields existed still load
    // (missing keys default to false / nil / ""). encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey {
        case id, name, region, category, isUnilateral, liftType, primaryMover, quality
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        region = try c.decodeIfPresent(MuscleRegion.self, forKey: .region) ?? .other
        category = try c.decode(String.self, forKey: .category)
        isUnilateral = try c.decodeIfPresent(Bool.self, forKey: .isUnilateral) ?? false
        liftType = try c.decodeIfPresent(LiftType.self, forKey: .liftType)
        primaryMover = try c.decodeIfPresent(String.self, forKey: .primaryMover) ?? ""
        quality = try c.decodeIfPresent(LiftQuality.self, forKey: .quality)
    }
}
