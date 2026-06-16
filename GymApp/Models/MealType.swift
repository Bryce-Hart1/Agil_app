import Foundation

// Claude  Date 06/16/2026
// Which meal a logged food belongs to. Drives the diary's day layout: entries are
// grouped into these sections in `allCases` order (breakfast → snack). `.other`
// is a catch-all so an entry always has a home. Mirrors the enum style used for
// MuscleRegion / LiftType (raw String, CaseIterable, a display title).
enum MealType: String, Codable, CaseIterable, Hashable, Identifiable {
    case breakfast, lunch, dinner, snack, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snack:     return "Snack"
        case .other:     return "Other"
        }
    }

    // Claude  Date 06/16/2026
    // SF Symbol for the meal's diary section header (UI-only hint).
    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch:     return "sun.max"
        case .dinner:    return "moon.stars"
        case .snack:     return "carrot"
        case .other:     return "fork.knife"
        }
    }
}
