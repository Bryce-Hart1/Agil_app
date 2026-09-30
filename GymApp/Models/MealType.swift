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

    // CLAUDE  Date 09/30/2026
    // The hours where logging this meal means eating it now (nil = anytime), and the
    // fallback "usual" time before the diary has history. Both feed MealTiming; the
    // windows are the same ones FoodDetailView's meal guess always used.
    var window: Range<Int>? {
        switch self {
        case .breakfast: return 4..<11
        case .lunch:     return 11..<15
        case .dinner:    return 18..<22
        case .snack, .other: return nil
        }
    }

    var defaultSeconds: TimeInterval {
        switch self {
        case .breakfast: return 8 * 3600
        case .lunch:     return 12.5 * 3600
        case .dinner:    return 18.5 * 3600
        case .snack:     return 15.5 * 3600
        case .other:     return 12 * 3600
        }
    }

    // CLAUDE  Date 09/30/2026
    // Best-guess meal for a clock time: the meal whose window holds the hour, else snack.
    static func forTime(_ date: Date, calendar: Calendar = .current) -> MealType {
        let hour = calendar.component(.hour, from: date)
        return [.breakfast, .lunch, .dinner].first { $0.window?.contains(hour) == true } ?? .snack
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
