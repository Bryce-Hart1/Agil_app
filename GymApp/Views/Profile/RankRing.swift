import SwiftUI

// Claude  Date 07/09/2026
// Segment-ring geometry. Lives outside RankRing because Swift forbids static stored
// properties in a generic type, and RankRing is generic over its core view. Not private:
// callers use `coreDiameter(for:)` to size a core view to the ring's central slot, and
// referencing it here (rather than as a static on the generic RankRing) avoids a
// generic-inference cycle when the call sits inside RankRing's own core closure.
// Claude  Date 07/09/2026
// What the segment ring encodes:
//   .rankSegments — N of 7 segments lit = your rank (a map of the whole ladder). The
//                   default; progress-to-next shows as a faint partial fill on the next
//                   segment. Rank is legible at a glance, matching StrategistEmblem.
//   .rankProgress — the ring fills continuously (0…1) with your progress toward the next
//                   rank, in the current rank's color. Headlines "how close to level-up",
//                   at the cost of showing absolute rank only by color.
enum RankRingFill {
    case rankSegments
    case rankProgress
}

enum RingGeometry {
    static let segmentCount = 7
    /// 360 / 7 ≈ 51.43°, of which 4° is the gap between neighbours.
    static let segmentSweep = 360.0 / Double(segmentCount)
    static let segmentGap = 4.0
    /// Fraction of the ring's size occupied by the centered core.
    static let coreRadiusFraction: CGFloat = 0.54
    /// Diameter of the centered core for a ring of the given size.
    static func coreDiameter(for size: CGFloat) -> CGFloat { size * coreRadiusFraction }
}

// Claude  Date 07/09/2026
// The rank ring — a procedural "crest" frame whose complexity grows with the user's
// StrategistRank. Fully drawn (Canvas + Path), no art assets. See
// elemental_ring_avatar_design.md for the layer spec and elemental_ring_avatar_plan.md
// for why it frames the avatar rather than replacing it.
//
// The core is generic on purpose: the profile card puts the rank's own StrategistGlyph
// inside, while the friend card puts initials inside (SharedCard syncs `rank`, never a
// picture). It briefly held a configurable avatar/character; that feature is gone.
//
// Rank N lights N of the 7 segments — Initiate one, Legend all seven. Colors come from
// `rank.tier`, so a rank is the same color here, on StrategistEmblem, and on its badges.
struct RankRing<Core: View>: View {
    let rank: StrategistRank
    var progress: Double = 1
    var size: CGFloat = 92
    /// Partially fills the next unearned segment with the color of the rank being climbed
    /// toward — the ring's equivalent of StrategistEmblem's progress arc.
    var showsProgress: Bool = true
    /// Sweep-in fraction (0…1) for the *newest* lit segment — the one this rank just
    /// earned. 1 (the default) draws it fully, so every static call site is unchanged;
    /// animating it 0→1 is how RankPromotionOverlay lights the new segment on a rank-up.
    var revealProgress: Double = 1
    /// Whether the segments map your rank (default) or fill with progress to the next rank.
    var fillMode: RankRingFill = .rankSegments
    let core: Core

    init(rank: StrategistRank,
         progress: Double = 1,
         size: CGFloat = 92,
         showsProgress: Bool = true,
         revealProgress: Double = 1,
         fillMode: RankRingFill = .rankSegments,
         @ViewBuilder core: () -> Core) {
        self.rank = rank
        self.progress = progress
        self.size = size
        self.showsProgress = showsProgress
        self.revealProgress = revealProgress
        self.fillMode = fillMode
        self.core = core()
    }

    // MARK: - Geometry
    //
    // Radii are fractions of `size / 2`, measured to the *centerline* of each stroked
    // band. Ordered outside → in so the layout reads top-to-bottom like the design table.
    private let auraRadius: CGFloat      = 0.98
    private let detailRadius: CGFloat    = 0.93
    private let segmentRadius: CGFloat   = 0.79
    private let innerRingRadius: CGFloat = 0.60
    private var coreRadius: CGFloat { RingGeometry.coreRadiusFraction }

    private var segmentWidth: CGFloat { size * 0.072 }
    private var detailWidth: CGFloat { max(0.75, size * 0.012) }
    private var innerRingWidth: CGFloat { max(0.75, size * 0.016) }

    /// Rank N lights N segments: Initiate (rawValue 0) lights 1, Legend lights 7.
    private var litSegments: Int { rank.rawValue + 1 }

    // Claude  Date 07/09/2026
    // Layer gates. The outer detail band is suppressed under 56pt — at list-row sizes the
    // notches and 7 segments mush into a smudge, so the ring degrades to just the segments.
    private var showsInnerRing: Bool { rank >= .squire }
    private var showsTickedInnerRing: Bool { rank >= .warrior }
    private var showsOuterDetail: Bool { rank >= .gladiator && size >= 56 }
    private var showsSpikes: Bool { rank >= .spartan && size >= 56 }
    private var showsAura: Bool { rank >= .spartan }
    private var isLegend: Bool { rank == .legend }

    /// The next rank's color, used for the partial progress segment (top rank: its own).
    private var nextColor: Color {
        (StrategistScoring.nextRank(after: rank)?.tier.color) ?? rank.tier.color
    }

    /// Track color for unlit segments. Matches StrategistEmblem's progress track, so it
    /// adapts to light/dark instead of being pinned to a dark-mode hex.
    // CLAUDE  Date 09/24/2026 — on a profile card the track follows the card's chosen text
    // colour instead, since the card's background (not the system scheme) sits behind it.
    @Environment(\.cardInk) private var cardInk
    private var trackColor: Color { cardInk.map { $0.color.opacity(0.12) } ?? Color.primary.opacity(0.12) }

    var body: some View {
        ZStack {
            aura
            trackLayer
            progressSegment
            fillLayer
            flareLayer
            outerDetail
            innerRing
            innerFill
            centurionGlyph
            coreContent
        }
        .frame(width: size, height: size)
    }

    // MARK: - Aura (rank 6+)
    //
    // Legend breathes on a ~3s loop; Spartan's aura is static. TimelineView(.animation)
    // redraws every frame, so it is gated behind Legend alone — a scrolling list of
    // lower-rank rings costs nothing.
    @ViewBuilder private var aura: some View {
        if showsAura {
            if isLegend {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let phase = (sin(t * 2 * .pi / 3.0) + 1) / 2   // 0…1 over 3 seconds
                    auraCircle(intensity: 0.55 + 0.45 * phase,
                               scale: 1.0 + 0.05 * phase)
                }
            } else {
                auraCircle(intensity: 0.6, scale: 1.0)
            }
        }
    }

    private func auraCircle(intensity: Double, scale: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [rank.tier.color.opacity(0.5 * intensity), .clear],
                center: .center,
                startRadius: size * 0.36,
                endRadius: size * 0.5 * auraRadius))
            .scaleEffect(scale)
            .blur(radius: size * 0.05)
            .allowsHitTesting(false)
    }

    // MARK: - Segment ring
    //
    // A dim track ring of all 7 segments sits behind a fill layer masked out of the tier's
    // material gradient. (The mask trick is what lets a Canvas carry `tier.fillGradient` —
    // a SwiftUI style Canvas can't stroke with directly — without exposing BadgeTier's
    // private gradient hexes.) What the fill covers depends on `fillMode`.

    private var trackLayer: some View {
        Canvas { ctx, canvas in
            for i in 0..<RingGeometry.segmentCount {
                ctx.stroke(segmentPath(in: canvas, index: i),
                           with: .color(trackColor),
                           style: segmentStroke)
            }
        }
    }

    /// Index of the newest lit segment (the one this rank just earned); it's the one
    /// `revealProgress` sweeps in. Always ≥ 0 since a rank lights at least one segment.
    private var newestSegment: Int { litSegments - 1 }

    private var fillLayer: some View {
        rank.tier.fillGradient.mask {
            Canvas { ctx, canvas in
                switch fillMode {
                case .rankSegments:
                    // N lit segments = rank; the newest fills by revealProgress (1 = full).
                    for i in 0..<litSegments {
                        let fraction = (i == newestSegment) ? revealProgress : 1
                        ctx.stroke(segmentPath(in: canvas, index: i, fraction: fraction),
                                   with: .color(.white), style: segmentStroke)
                    }
                case .rankProgress:
                    // Progress-to-next spread across all 7 segments as one meter.
                    let filled = max(0, min(1, progress)) * Double(RingGeometry.segmentCount)
                    let full = Int(filled)
                    for i in 0..<full {
                        ctx.stroke(segmentPath(in: canvas, index: i),
                                   with: .color(.white), style: segmentStroke)
                    }
                    let partial = filled - Double(full)
                    if full < RingGeometry.segmentCount, partial > 0 {
                        ctx.stroke(segmentPath(in: canvas, index: full, fraction: partial),
                                   with: .color(.white), style: segmentStroke)
                    }
                }
            }
        }
    }

    // A bright shimmer over the newest segment as it sweeps in — drawn only mid-reveal in
    // segment mode, peaking at the midpoint (sin) and gone by the time revealProgress
    // reaches 1, so it never shows in the static state. Reuses the segment geometry.
    @ViewBuilder private var flareLayer: some View {
        if fillMode == .rankSegments, revealProgress < 1 {
            let intensity = sin(min(1, max(0, revealProgress)) * .pi)
            Canvas { ctx, canvas in
                ctx.stroke(segmentPath(in: canvas, index: newestSegment, fraction: revealProgress),
                           with: .color(rank.tier.glimmerColor.opacity(intensity)),
                           style: StrokeStyle(lineWidth: segmentWidth * 1.2, lineCap: .round))
            }
            .blur(radius: size * 0.02)
            .allowsHitTesting(false)
        }
    }

    /// Fills the first unearned segment by `progress`, in the color of the rank being
    /// climbed toward. Absent at Legend (nothing left to climb) and when showsProgress off.
    @ViewBuilder private var progressSegment: some View {
        if fillMode == .rankSegments, showsProgress,
           litSegments < RingGeometry.segmentCount, progress > 0 {
            Canvas { ctx, canvas in
                ctx.stroke(segmentPath(in: canvas, index: litSegments, fraction: progress),
                           with: .color(nextColor.opacity(0.75)),
                           style: segmentStroke)
            }
        }
    }

    private var segmentStroke: StrokeStyle {
        StrokeStyle(lineWidth: segmentWidth, lineCap: .round)
    }

    /// Arc for one segment, starting at 12 o'clock and running clockwise. `fraction`
    /// trims the arc from its start, which is how the progress segment partially fills.
    private func segmentPath(in canvas: CGSize, index: Int, fraction: Double = 1) -> Path {
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let r = min(canvas.width, canvas.height) / 2 * segmentRadius
        let sweep = RingGeometry.segmentSweep - RingGeometry.segmentGap
        let start = -90 + Double(index) * RingGeometry.segmentSweep + RingGeometry.segmentGap / 2
        let end = start + sweep * min(1, max(0, fraction))

        var p = Path()
        p.addArc(center: center, radius: r,
                 startAngle: .degrees(start), endAngle: .degrees(end),
                 clockwise: false)
        return p
    }

    // MARK: - Outer detail band (rank 4+)
    //
    // A hairline ring with radial notches on the segment boundaries. Spartan and Legend
    // add longer "spike" marks at the segment midpoints — the doc's rune marks.
    @ViewBuilder private var outerDetail: some View {
        if showsOuterDetail {
            rank.tier.color.opacity(0.85).mask {
                Canvas { ctx, canvas in
                    let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                    let r = min(canvas.width, canvas.height) / 2 * detailRadius

                    var band = Path()
                    band.addArc(center: center, radius: r,
                                startAngle: .degrees(0), endAngle: .degrees(360),
                                clockwise: false)
                    ctx.stroke(band, with: .color(.white),
                               style: StrokeStyle(lineWidth: detailWidth))

                    // Boundary notches, then midpoint spikes at rank 6+.
                    for i in 0..<RingGeometry.segmentCount {
                        let boundary = -90 + Double(i) * RingGeometry.segmentSweep
                        ctx.stroke(tick(center: center, radius: r, degrees: boundary,
                                        length: size * 0.035),
                                   with: .color(.white),
                                   style: StrokeStyle(lineWidth: detailWidth * 1.6, lineCap: .round))

                        if showsSpikes {
                            let mid = boundary + RingGeometry.segmentSweep / 2
                            ctx.stroke(tick(center: center, radius: r, degrees: mid,
                                            length: size * 0.055),
                                       with: .color(.white),
                                       style: StrokeStyle(lineWidth: detailWidth * 1.2, lineCap: .round))
                        }
                    }
                }
            }
        }
    }

    /// A radial mark straddling `radius` at the given angle, `length` long.
    private func tick(center: CGPoint, radius: CGFloat, degrees: Double, length: CGFloat) -> Path {
        let a = degrees * .pi / 180
        let unit = CGPoint(x: cos(a), y: sin(a))
        let inner = CGPoint(x: center.x + unit.x * (radius - length / 2),
                            y: center.y + unit.y * (radius - length / 2))
        let outer = CGPoint(x: center.x + unit.x * (radius + length / 2),
                            y: center.y + unit.y * (radius + length / 2))
        var p = Path()
        p.move(to: inner)
        p.addLine(to: outer)
        return p
    }

    // MARK: - Inner ring (rank 2+) and inner fill

    @ViewBuilder private var innerRing: some View {
        if showsInnerRing {
            Circle()
                .strokeBorder(
                    rank.tier.color.opacity(0.7),
                    style: showsTickedInnerRing
                        // Warrior+ : the doc's "subtle dash pattern or tick marks".
                        ? StrokeStyle(lineWidth: innerRingWidth, dash: [size * 0.03, size * 0.022])
                        : StrokeStyle(lineWidth: innerRingWidth))
                .frame(width: size * innerRingRadius, height: size * innerRingRadius)
        }
    }

    // Gladiator+ gets the doc's "very subtle gradient"; below that a flat disc. Legend's
    // core glows.
    @ViewBuilder private var innerFill: some View {
        let d = size * coreRadius
        if rank >= .gladiator {
            Circle()
                .fill(RadialGradient(
                    colors: [rank.tier.color.opacity(0.22), rank.tier.color.opacity(0.04)],
                    center: .center, startRadius: 0, endRadius: d / 2))
                .frame(width: d, height: d)
                .shadow(color: isLegend ? rank.tier.glimmerColor.opacity(0.6) : .clear,
                        radius: size * 0.06)
        } else {
            Circle()
                .fill(Color.primary.opacity(0.05))
                .frame(width: d, height: d)
        }
    }

    // MARK: - Centurion glyph (rank 5+)
    //
    // The design doc's "small geometric symbol behind the initials" — a compass diamond +
    // cross — appearing at Centurion. Drawn behind the core, so it reads through the
    // translucent initials disc; an opaque avatar core covers it (intended: it's a backdrop
    // for the initials/friend case). Deepens through the top ranks.
    @ViewBuilder private var centurionGlyph: some View {
        if rank >= .centurion {
            CenturionMark(color: rank.tier.color.opacity(isLegend ? 0.5 : 0.35))
                .frame(width: size * coreRadius * 0.9, height: size * coreRadius * 0.9)
        }
    }

    // MARK: - Core

    private var coreContent: some View {
        ZStack {
            core
                .frame(width: size * coreRadius, height: size * coreRadius)
                .clipShape(Circle())

            // Reuse the badge twinkle rather than a bespoke glow — same premium tiers.
            if rank.tier.hasPremiumShine {
                SparkleField(extent: size * 0.72, color: rank.tier.glimmerColor)
            }
        }
    }
}

// Claude  Date 07/09/2026
// The Centurion mark: a compass diamond with an inscribed cross, non-figurative per the
// design doc. Pure Path in a Canvas, scaled to whatever frame it's given.
struct CenturionMark: View {
    var color: Color = .white

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let c = CGPoint(x: w / 2, y: h / 2)
            let lw = max(1, w * 0.03)

            var diamond = Path()
            diamond.move(to: CGPoint(x: c.x, y: 0))
            diamond.addLine(to: CGPoint(x: w, y: c.y))
            diamond.addLine(to: CGPoint(x: c.x, y: h))
            diamond.addLine(to: CGPoint(x: 0, y: c.y))
            diamond.closeSubpath()
            ctx.stroke(diamond, with: .color(color), lineWidth: lw)

            var cross = Path()
            cross.move(to: CGPoint(x: c.x, y: h * 0.16)); cross.addLine(to: CGPoint(x: c.x, y: h * 0.84))
            cross.move(to: CGPoint(x: w * 0.16, y: c.y)); cross.addLine(to: CGPoint(x: w * 0.84, y: c.y))
            ctx.stroke(cross, with: .color(color), lineWidth: lw)
        }
        .allowsHitTesting(false)
    }
}

// Claude  Date 08/02/2026 last changed: 08/07/2026 by: Claude
// Just the rank's chess piece, with no ring of its own — StrategistEmblem always brings its
// own outline, which would sit inside the RankRing and read as two concentric rings. Same
// asset-or-SF-Symbol fallback as StrategistEmblem/BadgeView.
// (Moved here from RankCoinView when the profile-face feature was removed: it was never
// about the coin, it's the ring's default core, and this is where the ring lives.)
struct StrategistGlyph: View {
    let rank: StrategistRank
    var size: CGFloat = 60
    var unlocked: Bool = true

    var body: some View {
        glyph
            .foregroundStyle(unlocked ? AnyShapeStyle(rank.tier.fillGradient)
                                      : AnyShapeStyle(Color.gray.opacity(0.5)))
            .shadow(color: unlocked ? .black.opacity(0.18) : .clear,
                    radius: size * 0.03, y: 0.5)
    }

    @ViewBuilder private var glyph: some View {
        #if canImport(UIKit)
        if UIImage(named: rank.iconName) != nil {
            Image(rank.iconName)
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: rank.fallbackSymbol)
                .font(.system(size: size, weight: .semibold))
        }
        #else
        Image(systemName: rank.fallbackSymbol)
            .font(.system(size: size, weight: .semibold))
        #endif
    }
}

// Claude  Date 07/09/2026
// Convenience core for surfaces with no avatar art — chiefly the friend card, whose
// SharedCard payload carries `rank` but not a picture. Derives up to two initials from a
// display name, matching the design doc's original "first + last initial" core.
struct RankRingInitials: View {
    let name: String
    var size: CGFloat = 92
    // CLAUDE  Date 09/24/2026 — the card's text colour when drawn on a card, else white.
    @Environment(\.cardInk) private var cardInk

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        if letters.isEmpty { return "?" }
        return String(letters).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.3, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle((cardInk ?? .white).color.opacity(0.92))
    }
}

// Claude  Date 07/09/2026
// Visual QA for the spec: every rank at the three sizes the design doc calls out
// (40pt list row, 80pt profile header, 120pt edit screen). Check both color schemes —
// the ring is dark-mode-first but must degrade on light backgrounds.
#Preview("All ranks") {
    ScrollView {
        VStack(spacing: 28) {
            ForEach(StrategistRank.allCases, id: \.self) { r in
                HStack(spacing: 24) {
                    RankRing(rank: r, progress: 0.45, size: 40) {
                        RankRingInitials(name: "Bryce Hart", size: 40)
                    }
                    RankRing(rank: r, progress: 0.45, size: 80) {
                        RankRingInitials(name: "Bryce Hart", size: 80)
                    }
                    RankRing(rank: r, progress: 0.45, size: 120) {
                        RankRingInitials(name: "Bryce Hart", size: 120)
                    }
                    VStack(alignment: .leading) {
                        Text(r.title).font(.headline)
                        Text("\(r.rawValue + 1) / 7 segments")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 40)
    }
}
