import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 06/13/2026 last changed: 06/15/2026 by: Claude
// A tier-colored achievement badge on a transparent background. Unlocked badges
// are rendered as a filled "medallion" — a solid tier-colored disc with a white
// knockout glyph — carrying a soft tier-colored glow and, when `glimmer` is on, a
// shine that sweeps across on a loop (random phase so a wall of badges doesn't
// pulse in unison). Locked badges stay a hollow gray ring + dimmed glyph, so
// earned vs. locked reads at a glance. Legend gets a purple→gold gradient rim.
struct BadgeView: View {
    let icon: String
    let tier: BadgeTier
    let unlocked: Bool
    var size: CGFloat = 56
    /// Animated shine sweep — on for the card + celebration, off for dense lists.
    var glimmer: Bool = false
    // Claude  Date 06/14/2026
    // Whether to draw the circular ring. Off for the profile card, where we want
    // the bare icon to read bigger; the glyph grows to fill the freed space.
    var ringed: Bool = true

    @State private var sweep = false

    private var tint: Color { unlocked ? tier.color : Color.gray.opacity(0.5) }

    // Claude  Date 06/15/2026
    // A filled medallion (ringed + unlocked) puts a white knockout glyph on the
    // tier-colored disc; every other case keeps the glyph in its tint color.
    private var isMedallion: Bool { ringed && unlocked }
    private var glyphColor: Color { isMedallion ? .white : tint }

    // Claude  Date 06/14/2026 last changed: 06/15/2026 by: Claude
    // Sizing for the glyph. SF Symbols size by font; catalog assets size by an
    // explicit frame (glyphSize). The medallion glyph is a touch larger to fill
    // the disc.
    private var iconFont: Font {
        .system(size: size * (ringed ? 0.46 : 0.72), weight: .semibold)
    }
    private var glyphSize: CGFloat { size * (ringed ? 0.55 : 0.82) }

    // Claude  Date 06/15/2026
    // Renders the glyph from a catalog asset when one named `icon` exists (any
    // image set — vector SVG or raster PNG — drawn as a template so it tints), and
    // otherwise falls back to the matching SF Symbol. This is how dedicated badge
    // art drops in: name the asset, point iconName at it, no other code changes.
    @ViewBuilder
    private func glyphView() -> some View {
        #if canImport(UIKit)
        if UIImage(named: icon) != nil {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: glyphSize, height: glyphSize)
        } else {
            Image(systemName: icon).font(iconFont)
        }
        #else
        Image(systemName: icon).font(iconFont)
        #endif
    }

    var body: some View {
        ZStack {
            if ringed {
                if unlocked {
                    // Filled medallion. Legend earns a purple→gold gradient rim;
                    // every other tier gets a subtle white inner highlight.
                    Circle().fill(tier.fillGradient)
                    if tier == .legend {
                        Circle().strokeBorder(
                            AngularGradient(
                                colors: [tier.color, tier.glimmerColor, tier.color],
                                center: .center),
                            lineWidth: 3)
                    } else {
                        Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                    }
                } else {
                    // Hollow gray ring = not yet earned.
                    Circle().stroke(tint, lineWidth: 2)
                }
            }

            glyphView()
                .foregroundStyle(glyphColor)
                // Soft dark edge keeps the white glyph legible on light tiers
                // (diamond / silver); a no-op on dark tiers and non-medallion badges.
                .shadow(color: isMedallion ? .black.opacity(0.28) : .clear,
                        radius: 1, y: 0.5)

            if unlocked && glimmer {
                shine
            }

            // Premium tiers (diamond / emerald / legend) get twinkling sparkles so
            // they stand out from the lower tiers.
            if unlocked && glimmer && tier.hasPremiumShine {
                SparkleField(extent: size, color: tier.glimmerColor)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: unlocked ? tier.color.opacity(0.55) : .clear,
                radius: unlocked ? size * 0.14 : 0)
        .opacity(unlocked ? 1 : 0.6)
        .onAppear {
            guard unlocked, glimmer else { return }
            withAnimation(.easeInOut(duration: 1.6)
                .repeatForever(autoreverses: false)
                .delay(Double.random(in: 0...2.0))) {
                sweep = true
            }
        }
    }

    // Claude  Date 06/13/2026 last changed: 06/15/2026 by: Claude
    // A diagonal highlight that travels across the badge. Clipped to the ring circle
    // for ringed badges, but to the glyph itself when ringless — so the gloss rides
    // the actual icon shape on the profile card instead of a phantom circle. The
    // sweep color is tier.glimmerColor (white for most tiers, gold for Legend).
    private var shine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, tier.glimmerColor.opacity(0.85), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: size * 0.55)
            .rotationEffect(.degrees(22))
            .offset(x: sweep ? size * 1.1 : -size * 1.1)
            .blendMode(.plusLighter)
            .mask(shineMask)
            .allowsHitTesting(false)
    }

    @ViewBuilder private var shineMask: some View {
        if ringed {
            Circle().frame(width: size, height: size)
        } else {
            glyphView()
        }
    }
}

// Claude  Date 06/16/2026
// A small cluster of twinkling sparkles overlaid on premium badges/ranks. Each
// star pulses scale + opacity on its own loop (staggered delays) so the effect
// shimmers rather than blinking in unison. `extent` is the badge's size; sparkles
// are placed and sized relative to it. Reused by BadgeView and StrategistEmblem.
struct SparkleField: View {
    let extent: CGFloat
    var color: Color = .white

    // Fixed relative spots (x, y as fractions of extent from center) + size + delay.
    private let spots: [(x: CGFloat, y: CGFloat, s: CGFloat, delay: Double)] = [
        (-0.26, -0.24, 0.20, 0.0),
        ( 0.28, -0.06, 0.14, 0.55),
        ( 0.12,  0.28, 0.16, 0.95),
        (-0.18,  0.22, 0.11, 1.4),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<spots.count, id: \.self) { i in
                let p = spots[i]
                Twinkle(color: color, size: extent * p.s, delay: p.delay)
                    .offset(x: extent * p.x, y: extent * p.y)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Twinkle: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    @State private var on = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundStyle(color)
            .opacity(on ? 0.95 : 0.1)
            .scaleEffect(on ? 1 : 0.4)
            .shadow(color: color.opacity(0.6), radius: size * 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.95)
                    .repeatForever(autoreverses: true)
                    .delay(delay)) { on = true }
            }
    }
}

// Claude  Date 06/13/2026
// An empty "locked" slot for the card's featured row (white-on-card styling).
struct LockedBadge: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.32))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            BadgeView(icon: "flame.fill", tier: .bronze, unlocked: true, glimmer: true)
            BadgeView(icon: "dumbbell.fill", tier: .silver, unlocked: true, glimmer: true)
            BadgeView(icon: "scalemass.fill", tier: .gold, unlocked: true, glimmer: true)
            BadgeView(icon: "calendar", tier: .platinum, unlocked: true, glimmer: true)
        }
        HStack(spacing: 16) {
            BadgeView(icon: "diamond.fill", tier: .diamond, unlocked: true, glimmer: true)
            BadgeView(icon: "leaf.fill", tier: .emerald, unlocked: true, glimmer: true)
            BadgeView(icon: "crown.fill", tier: .legend, unlocked: true, glimmer: true)
            BadgeView(icon: "flame.fill", tier: .legend, unlocked: false)
        }
    }
    .padding()
}
