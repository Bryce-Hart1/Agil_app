import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 06/30/2026
// Renders an Avatar in a circular frame with a subtle backing disc + ring, so any avatar
// reads cleanly over any card background (or a Form row). Full-colour art when the asset
// exists; otherwise the SF Symbol fallback tinted with `tint` — the same
// `UIImage(named:) ? asset : symbol` approach as StrategistEmblem / BadgeView, so it
// works before the custom art is imported. Disc/ring colours are overridable so it looks
// right both on the dark card (default white) and in the light picker rows.
struct AvatarView: View {
    let avatar: Avatar
    var size: CGFloat = 92
    var tint: Color = .white
    var discColor: Color = Color.white.opacity(0.15)
    var ringColor: Color = Color.white.opacity(0.35)

    var body: some View {
        ZStack {
            Circle().fill(discColor)
            content
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ringColor, lineWidth: max(1, size * 0.022)))
        .shadow(radius: size * 0.06, y: size * 0.03)
    }

    @ViewBuilder private var content: some View {
        if assetExists {
            Image(avatar.asset).resizable().scaledToFill()
        } else {
            Image(systemName: avatar.fallbackSymbol)
                .resizable().scaledToFit()
                .padding(size * 0.2)
                .foregroundStyle(tint)
        }
    }

    private var assetExists: Bool {
        #if canImport(UIKit)
        return UIImage(named: avatar.asset) != nil
        #else
        return false
        #endif
    }
}
