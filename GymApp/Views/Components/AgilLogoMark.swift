import SwiftUI

// CLAUDE  Date 09/03/2026
// The Agil logo tile, drawn in a theme's art (see ThemeIcon.logoAsset). Replaces the
// static Image("AppLogo") everywhere the mark appears, so the logo inside the app matches
// the icon on the home screen.
//
// Takes the asset name EXPLICITLY and never reads ThemeManager from the environment. That
// is deliberate: ThemeShowcaseView previews themes you don't own, and any subview that
// resolves the equipped theme silently breaks it (see the rule at the top of that file).
struct AgilLogoMark: View {
    let assetName: String
    var size: CGFloat
    var cornerRadius: CGFloat

    init(theme: AppTheme, size: CGFloat, cornerRadius: CGFloat) {
        self.assetName = ThemeIcon.logoAsset(for: theme)
        self.size = size
        self.cornerRadius = cornerRadius
    }

    init(assetName: String, size: CGFloat, cornerRadius: CGFloat) {
        self.assetName = assetName
        self.size = size
        self.cornerRadius = cornerRadius
    }

    // CLAUDE  Date 09/03/2026
    // The near-black ground the generated icons are flattened onto (see
    // scripts/make_theme_icons.swift). Needed here because classic_v2 ships transparent —
    // without it the Classic mark reads as a floating kettlebell on whatever card it sits
    // on, while the other five (opaque renders) read as tiles.
    private static let ground = Color(hex: "#0D0D10")

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .background(Self.ground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
