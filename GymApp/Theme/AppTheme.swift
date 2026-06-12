import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A visual theme. Colors are stored as hex strings so the whole thing is
/// Codable and can be persisted to JSON alongside the rest of the app's data.
///
// Claude  Date 06/09/2026
// A theme may optionally provide dark-mode colors (darkAccentHex/…). When it
// does, it is "adaptive": its color accessors return a dynamic Color that
// auto-switches with the system appearance, and the app follows the system
// light/dark setting instead of being forced to one mode. Themes without dark
// colors behave exactly as before (single palette, forced appearance), so this
// is fully backward compatible with previously saved custom themes.
struct AppTheme: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var isBuiltIn: Bool
    var isDark: Bool
    var accentHex: String
    var backgroundHex: String
    var surfaceHex: String
    var darkAccentHex: String?
    var darkBackgroundHex: String?
    var darkSurfaceHex: String?

    init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false, isDark: Bool,
         accentHex: String, backgroundHex: String, surfaceHex: String,
         darkAccentHex: String? = nil, darkBackgroundHex: String? = nil, darkSurfaceHex: String? = nil) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.isDark = isDark
        self.accentHex = accentHex
        self.backgroundHex = backgroundHex
        self.surfaceHex = surfaceHex
        self.darkAccentHex = darkAccentHex
        self.darkBackgroundHex = darkBackgroundHex
        self.darkSurfaceHex = darkSurfaceHex
    }

    // Claude  Date 06/09/2026
    // True when the theme carries any dark-mode color (so it adapts to system appearance).
    var isAdaptive: Bool {
        darkAccentHex != nil || darkBackgroundHex != nil || darkSurfaceHex != nil
    }

    var accent: Color { dynamicColor(light: accentHex, dark: darkAccentHex) }
    var background: Color { dynamicColor(light: backgroundHex, dark: darkBackgroundHex) }
    var surface: Color { dynamicColor(light: surfaceHex, dark: darkSurfaceHex) }

    // Claude  Date 06/09/2026
    // Adaptive themes follow the system (nil = don't force); fixed themes pin their mode.
    var preferredColorScheme: ColorScheme? {
        isAdaptive ? nil : (isDark ? .dark : .light)
    }

    // Claude  Date 06/09/2026
    // Build a Color that resolves to the dark hex in dark mode (if provided) and
    // the light hex otherwise. Falls back to a static color off UIKit-less platforms.
    private func dynamicColor(light: String, dark: String?) -> Color {
        guard let dark else { return Color(hex: light) }
        #if canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
        #else
        return Color(hex: light)
        #endif
    }

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
    // Claude  Date 06/09/2026 last changed: 06/10/2026 by: Claude
    // Classic: built around the logo pink (#EA0F8B). Adaptive — light mode is a
    // soft pink-tinted white; dark mode is a deep near-black magenta with a
    // brighter pink accent so it reads on dark.
    static let classic = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Classic", isBuiltIn: true, isDark: true,
        accentHex: "#EA0F8B", backgroundHex: "#FCEEF6", surfaceHex: "#FFFFFF",
        darkAccentHex: "#FF4FB0", darkBackgroundHex: "#130810", darkSurfaceHex: "#211019")

    static let midnight = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Midnight", isBuiltIn: true, isDark: true,
        accentHex: "#5E5CE6", backgroundHex: "#0B0B0F", surfaceHex: "#1C1C1E")

    static let deep_sea = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Deep Sea", isBuiltIn: true, isDark: false,
        accentHex: "#17646c", backgroundHex: "#EAF6F8", surfaceHex: "#FFFFFF")

    static let sunset = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "sunset", isBuiltIn: true, isDark: false,
        accentHex: "#FF7043", backgroundHex: "#bb5f2a", surfaceHex: "#000000")

    static let leaf = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Leaf", isBuiltIn: true, isDark: true,
        accentHex: "#34C759", backgroundHex: "#0E1511", surfaceHex: "#16201A")

    static let builtIns: [AppTheme] = [classic, midnight, deep_sea, sunset, leaf]
}
