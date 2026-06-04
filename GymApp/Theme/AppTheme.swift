import SwiftUI

/// A visual theme. Colors are stored as hex strings so the whole thing is
/// Codable and can be persisted to JSON alongside the rest of the app's data.
struct AppTheme: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var isBuiltIn: Bool
    var isDark: Bool
    var accentHex: String
    var backgroundHex: String
    var surfaceHex: String

    init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false, isDark: Bool,
         accentHex: String, backgroundHex: String, surfaceHex: String) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.isDark = isDark
        self.accentHex = accentHex
        self.backgroundHex = backgroundHex
        self.surfaceHex = surfaceHex
    }

    var accent: Color { Color(hex: accentHex) }
    var background: Color { Color(hex: backgroundHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    /// A fresh, editable copy seeded from this theme's colors (used to start a
    /// new custom theme from the currently selected one).
    func asNewTemplate() -> AppTheme {
        AppTheme(id: UUID(), name: "My Theme", isBuiltIn: false, isDark: isDark,
                 accentHex: accentHex, backgroundHex: backgroundHex, surfaceHex: surfaceHex)
    }
}

/** Bryce Hart - 6/4/26 - last updated 6/4/26
 Made these themed around stuff I like that is easy to understand for users
 should be themed as main color - background - icons.
 changed from generic names.
 */

extension AppTheme {
    static let classic = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Classic", isBuiltIn: true, isDark: false,
        accentHex: "#0a6300", backgroundHex: "#F2F2F7", surfaceHex: "#FFFFFF")

    static let midnight = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Midnight", isBuiltIn: true, isDark: true,
        accentHex: "#5E5CE6", backgroundHex: "#0B0B0F", surfaceHex: "#1C1C1E")

    static let outside = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Deep Sea", isBuiltIn: true, isDark: false,
        accentHex: "#17646c", backgroundHex: "#EAF6F8", surfaceHex: "#FFFFFF")

    static let sunset = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Slide", isBuiltIn: true, isDark: false,
        accentHex: "#FF7043", backgroundHex: "#bb5f2a", surfaceHex: "#000000")

    static let forest = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Leaf", isBuiltIn: true, isDark: true,
        accentHex: "#34C759", backgroundHex: "#0E1511", surfaceHex: "#16201A")

    static let builtIns: [AppTheme] = [classic, midnight, ocean, sunset, forest]
}
