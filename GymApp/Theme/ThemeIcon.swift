import Foundation

// CLAUDE  Date 09/03/2026
// Maps a theme to its art: the alternate app icon it equips on the home screen, and the
// logo imageset the app draws in-app. Buying a theme grants both — icon ownership IS theme
// ownership, so nothing new is persisted.
//
// A lookup table keyed by the built-in UUIDs rather than fields on AppTheme, for the same
// reason ShopItem.blurbs is one: AppTheme is Codable and persisted to theme.json, so a new
// stored property means touching CodingKeys + the custom decoder to save static asset names
// to disk. It also keeps AppTheme.swift — which is compiled into the widget extension too —
// free of anything app-only.
enum ThemeIcon {
    /// The app icon the theme wears, as an ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES
    /// entry (see project.yml). nil means the primary AppIcon — Classic's own art, which is
    /// also the fallback for custom themes.
    static func alternateIconName(for theme: AppTheme) -> String? {
        alternateIconNames[theme.id] ?? nil
    }

    /// The imageset the app renders for this theme's mark (AgilLogoMark). Always a real
    /// asset: custom themes fall back to Classic. Deliberately an imageset and not the
    /// .appiconset — Image(_:) can't reliably load app icon assets.
    static func logoAsset(for theme: AppTheme) -> String {
        logoAssets[theme.id] ?? classicLogoAsset
    }

    /// Classic's mark, and the fallback for anything unmapped.
    static let classicLogoAsset = "Agil_logo_classic_v2"

    // Keyed by the fixed built-in ids in AppTheme. Classic maps to nil on purpose: its art
    // is the primary icon, so equipping it means clearing the alternate rather than setting one.
    private static let alternateIconNames: [UUID: String?] = [
        AppTheme.classic.id:  nil,
        AppTheme.midnight.id: "AppIcon-Midnight",
        AppTheme.deep_sea.id: "AppIcon-DeepSea",
        AppTheme.sunset.id:   "AppIcon-Sunset",
        AppTheme.leaf.id:     "AppIcon-Leaf",
        AppTheme.woods.id:    "AppIcon-Woods",
    ]

    private static let logoAssets: [UUID: String] = [
        AppTheme.classic.id:  classicLogoAsset,
        AppTheme.midnight.id: "Agil_logo_midnight_v2",
        AppTheme.deep_sea.id: "Agil_logo_deep_sea_v2",
        AppTheme.sunset.id:   "Agil_logo_sunset_v2",
        AppTheme.leaf.id:     "Agil_logo_leaf_v2",
        AppTheme.woods.id:    "Agil_logo_woods_v2",
    ]
}
