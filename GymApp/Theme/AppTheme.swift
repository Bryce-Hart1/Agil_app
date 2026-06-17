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
    // Claude  Date 06/13/2026
    // Coin cost to unlock this theme in the Shop. 0 = free (Classic + any custom
    // theme you make yourself); paid built-ins cost 500.
    var price: Int

    init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false, isDark: Bool,
         accentHex: String, backgroundHex: String, surfaceHex: String,
         darkAccentHex: String? = nil, darkBackgroundHex: String? = nil, darkSurfaceHex: String? = nil,
         price: Int = 0) {
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
        self.price = price
    }

    // Claude  Date 06/13/2026
    // Explicit CodingKeys + decoder so custom themes saved before `price` existed
    // still load (absent price → 0). Declaring the keys keeps the synthesized
    // encoder in sync (it now writes `price` too).
    enum CodingKeys: String, CodingKey {
        case id, name, isBuiltIn, isDark, accentHex, backgroundHex, surfaceHex
        case darkAccentHex, darkBackgroundHex, darkSurfaceHex, price
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isBuiltIn = try c.decode(Bool.self, forKey: .isBuiltIn)
        isDark = try c.decode(Bool.self, forKey: .isDark)
        accentHex = try c.decode(String.self, forKey: .accentHex)
        backgroundHex = try c.decode(String.self, forKey: .backgroundHex)
        surfaceHex = try c.decode(String.self, forKey: .surfaceHex)
        darkAccentHex = try c.decodeIfPresent(String.self, forKey: .darkAccentHex)
        darkBackgroundHex = try c.decodeIfPresent(String.self, forKey: .darkBackgroundHex)
        darkSurfaceHex = try c.decodeIfPresent(String.self, forKey: .darkSurfaceHex)
        price = try c.decodeIfPresent(Int.self, forKey: .price) ?? 0
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

    // Claude  Date 06/13/2026
    // The non-Classic built-ins cost 500 coins each to unlock in the Shop.
    static let midnight = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Midnight", isBuiltIn: true, isDark: true,
        accentHex: "#5E5CE6", backgroundHex: "#0B0B0F", surfaceHex: "#1C1C1E",
        price: 500)

    static let deep_sea = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Deep Sea", isBuiltIn: true, isDark: false,
        accentHex: "#17646c", backgroundHex: "#EAF6F8", surfaceHex: "#FFFFFF",
        price: 500)

    // Bryce Hart 6/4/26 last changed: 06/16/2026 by: Claude
    // Burnt-orange background with black cards. Marked isDark so the forced
    // appearance is .dark — otherwise the app forced light mode and `.primary`
    // text rendered black on the black surfaces (invisible nav rows / rank banner).
    static let sunset = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "sunset", isBuiltIn: true, isDark: true,
        accentHex: "#FF7043", backgroundHex: "#bb5f2a", surfaceHex: "#000000",
        price: 500)

    static let leaf = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Leaf", isBuiltIn: true, isDark: true,
        accentHex: "#34C759", backgroundHex: "#0E1511", surfaceHex: "#16201A",
        price: 500)

    // Claude  Date 06/16/2026
    // Woods — first-pass outline only. A dark forest palette (bark browns + a
    // mossy-green accent) to refine later; colours are placeholders.
    static let woods = AppTheme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        name: "Woods", isBuiltIn: true, isDark: true,
        accentHex: "#8FAE5D", backgroundHex: "#1A140E", surfaceHex: "#241B12",
        price: 500)

    static let builtIns: [AppTheme] = [classic, midnight, deep_sea, sunset, leaf, woods]
}
