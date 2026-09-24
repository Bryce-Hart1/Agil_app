import Foundation

// CLAUDE  Date 09/24/2026
// The AGIL-made pictures a user can put in the card's avatar disc instead of their rank
// piece. Free for now; the unlock wiring in docs/profile_icons.md can hang off this enum
// later. rawValue is the synced id, so never rename a case's raw value.
enum ProfileIcon: String, CaseIterable, Identifiable, Hashable {
    case ram, rhino, raptor
    case northStar = "north_star"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ram:       return "Ram"
        case .rhino:     return "Rhino"
        case .raptor:    return "Raptor"
        case .northStar: return "North Star"
        }
    }

    // Black silhouettes with alpha in Assets.xcassets, drawn as template images.
    var assetName: String {
        switch self {
        case .ram:       return "ram_pfp"
        case .rhino:     return "rhino_pfp"
        case .raptor:    return "raptor_pfp"
        case .northStar: return "north_star"
        }
    }
}
