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

    // Claude  Date 07/23/2026
    // The glyph, textured for gems. A ringless gem badge (diamond / emerald on the
    // profile card) pours the faceted cut-gem material *into the icon shape itself*
    // — the glyph is the gem, with no disc around it — by masking the tier gradient +
    // GemFacetOverlay with the glyph. Every other case keeps the flat-tinted glyph;
    // the medallion still draws a white knockout glyph over its textured disc.
    @ViewBuilder private var glyphLayer: some View {
        if unlocked && tier.hasGemFacets && !isMedallion {
            ZStack {
                tier.fillGradient
                GemFacetOverlay(diameter: size, highlight: tier.glimmerColor)
            }
            .frame(width: size, height: size)
            .mask(glyphView())
            // A soft dark edge keeps the light gem glyph legible over card art.
            .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
        } else {
            glyphView()
                .foregroundStyle(glyphColor)
                // Soft dark edge keeps the white glyph legible on light tiers
                // (diamond / silver); a no-op on dark tiers and non-medallion badges.
                .shadow(color: isMedallion ? .black.opacity(0.28) : .clear,
                        radius: 1, y: 0.5)
        }
    }

    var body: some View {
        ZStack {
            if ringed {
                if unlocked {
                    // Filled medallion. Legend earns a purple→gold gradient rim;
                    // every other tier gets a subtle white inner highlight.
                    Circle().fill(tier.fillGradient)
                    // Claude  Date 07/23/2026
                    // Gemstone tiers (diamond / emerald) get a faceted, cut-gem
                    // surface over the flat material fill. Drawn above the fill and
                    // below the rim so the rim stays crisp.
                    if tier.hasGemFacets {
                        GemFacetOverlay(diameter: size, highlight: tier.glimmerColor)
                            .clipShape(Circle())
                    }
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

            glyphLayer

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

// Claude  Date 07/23/2026
// A procedural cut-gem facet overlay for the gemstone tiers (diamond / emerald).
// Rather than pie wedges, the disc is tessellated into triangular facets — an
// octagonal center "table" plus two concentric rings of zig-zag triangles, the way
// a brilliant cut reads from the top. Each facet is flat-shaded to one of four
// discrete light/shadow steps (brighter toward the upper-left key light, with a
// small per-facet jitter so neighbours land on different steps), so the surface
// reads as a faceted, textured stone instead of a smooth sheen. Blended .overlay so
// facets modulate the tier hue without recolouring it; a soft specular spot near
// the light adds the glassy sparkle. Clipped to the medallion circle, above fill.
struct GemFacetOverlay: View {
    let diameter: CGFloat
    // Claude  Date 07/23/2026 last changed: 07/23/2026 by: Claude
    // Facets per ring. Defaults to 8 for badges; the gemstone profile-card
    // background (GemCardBackground) passes a higher count for finer facets at card
    // scale. (Was a private constant.)
    var sides: Int = 8
    // Claude  Date 07/23/2026
    // The facet finish — the colour of the lit facets + specular. White for the icy/
    // green gems (diamond/emerald); Legend passes gold for a gold finish. Shadows
    // stay black regardless. Callers pass tier.glimmerColor.
    var highlight: Color = .white
    // Ring radii as fractions of the disc radius: table, crown, rim. The rim ring
    // overshoots so its facets cover out to the round edge (the excess is clipped).
    private let rings: [CGFloat] = [0.32, 0.63, 1.15]
    // Four discrete shade steps (+ white highlight … − black shadow) laid over the
    // tier gradient. Quantising to a few flat steps is what gives the faceted,
    // low-poly gem look instead of a smooth gradient.
    private let steps: [Double] = [0.26, 0.12, 0.0, -0.15]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let light = CGVector(dx: -0.72, dy: -0.69)          // upper-left key light

            // A vertex on `ring` at position `i`. Each ring is rotated a half-step
            // from the previous one, so successive rings tessellate into triangles.
            func vertex(_ ring: Int, _ i: Int) -> CGPoint {
                let step = 2 * Double.pi / Double(sides)
                let a = Double(i) * step + Double(ring) * step / 2 - .pi / 2
                let r = radius * rings[ring]
                return CGPoint(x: center.x + CGFloat(cos(a)) * r,
                               y: center.y + CGFloat(sin(a)) * r)
            }

            // Flat-shade one facet: quantise how squarely its centroid faces the key
            // light, nudge by `offset`, then fill with the resulting step.
            func fill(_ tri: [CGPoint], _ offset: Int) {
                let cx = (tri[0].x + tri[1].x + tri[2].x) / 3
                let cy = (tri[0].y + tri[1].y + tri[2].y) / 3
                var dx = Double(cx - center.x), dy = Double(cy - center.y)
                let len = max(0.0001, (dx * dx + dy * dy).squareRoot())
                dx /= len; dy /= len
                let facing = dx * light.dx + dy * light.dy       // −1 (away) … 1 (toward)
                var idx = Int((1 - (facing + 1) / 2) * Double(steps.count)) + offset
                idx = min(steps.count - 1, max(0, idx))
                let s = steps[idx]
                var path = Path()
                path.move(to: tri[0]); path.addLine(to: tri[1])
                path.addLine(to: tri[2]); path.closeSubpath()
                ctx.fill(path, with: s >= 0 ? .color(highlight.opacity(s))
                                            : .color(.black.opacity(-s)))
            }

            // Center table — a fan of triangles biased bright (the flat top facet).
            for i in 0..<sides {
                fill([center, vertex(0, i), vertex(0, (i + 1) % sides)],
                     i.isMultiple(of: 2) ? -1 : 0)
            }
            // Two facet rings: a triangle strip between each pair of rings gives
            // alternating outward ("up") and inward ("down") triangles. A small
            // deterministic jitter spreads neighbours across the shade steps, and the
            // inward facets sit a step darker so each up/down pair reads as two cuts.
            for ring in 0..<2 {
                for i in 0..<sides {
                    let aIn = vertex(ring, i),      bIn = vertex(ring, (i + 1) % sides)
                    let aOut = vertex(ring + 1, i), bOut = vertex(ring + 1, (i + 1) % sides)
                    let jUp = ((i * 7 + ring * 5) % 3) - 1       // −1, 0, 1
                    let jDn = ((i * 5 + ring * 3) % 3) - 1
                    fill([aIn, bIn, aOut], jUp)                  // up   — points outward
                    fill([bIn, aOut, bOut], 1 + jDn)             // down — points inward
                }
            }
        }
        .blendMode(.overlay)
        .overlay(
            Circle().fill(RadialGradient(
                colors: [highlight.opacity(0.6), .clear],
                center: .init(x: 0.34, y: 0.30),
                startRadius: 0, endRadius: diameter * 0.42))
                .blendMode(.plusLighter))
        .allowsHitTesting(false)
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
