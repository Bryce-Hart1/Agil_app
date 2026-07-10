import SwiftUI

// Claude  Date 07/09/2026
// Segment-ring geometry. Lives outside RankRing because Swift forbids static stored
// properties in a generic type, and RankRing is generic over its core view.
private enum RingGeometry {
    static let segmentCount = 7
    /// 360 / 7 ≈ 51.43°, of which 4° is the gap between neighbours.
    static let segmentSweep = 360.0 / Double(segmentCount)
    static let segmentGap = 4.0
}

// Claude  Date 07/09/2026
// The rank ring — a procedural "crest" frame whose complexity grows with the user's
// StrategistRank. Fully drawn (Canvas + Path), no art assets. See
// elemental_ring_avatar_design.md for the layer spec and elemental_ring_avatar_plan.md
// for why it frames the avatar rather than replacing it.
//
// The core is generic on purpose: the profile card puts the user's chosen AvatarView
// inside, while the friend card puts initials inside (SharedCard syncs `rank` but not
// `avatarID`, so a friend's avatar art isn't available on this device).
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
    let core: Core

    init(rank: StrategistRank,
         progress: Double = 1,
         size: CGFloat = 92,
         showsProgress: Bool = true,
         @ViewBuilder core: () -> Core) {
        self.rank = rank
        self.progress = progress
        self.size = size
        self.showsProgress = showsProgress
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
    private let coreRadius: CGFloat      = 0.54

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
    private var trackColor: Color { Color.primary.opacity(0.12) }

    var body: some View {
        ZStack {
            aura
            unlitSegments
            progressSegment
            litSegmentsLayer
            outerDetail
            innerRing
            innerFill
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
    // Drawn as three passes so each gets its own fill: unlit segments in the flat track
    // color, the in-progress segment in the next rank's color, and the earned segments
    // masked out of the tier's material gradient. The mask trick is what lets a Canvas
    // carry `tier.fillGradient` (a SwiftUI style Canvas can't stroke with directly)
    // without widening BadgeTier's API to expose its private gradient hexes.

    private var unlitSegments: some View {
        Canvas { ctx, canvas in
            for i in litSegments..<RingGeometry.segmentCount {
                ctx.stroke(segmentPath(in: canvas, index: i),
                           with: .color(trackColor),
                           style: segmentStroke)
            }
        }
    }

    private var litSegmentsLayer: some View {
        rank.tier.fillGradient.mask {
            Canvas { ctx, canvas in
                for i in 0..<litSegments {
                    ctx.stroke(segmentPath(in: canvas, index: i),
                               with: .color(.white),
                               style: segmentStroke)
                }
            }
        }
    }

    /// Fills the first unearned segment by `progress`, in the color of the rank being
    /// climbed toward. Absent at Legend (nothing left to climb) and when showsProgress off.
    @ViewBuilder private var progressSegment: some View {
        if showsProgress, litSegments < RingGeometry.segmentCount, progress > 0 {
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
// Convenience core for surfaces with no avatar art — chiefly the friend card, whose
// SharedCard payload carries `rank` but not `avatarID`. Derives up to two initials from a
// display name, matching the design doc's original "first + last initial" core.
struct RankRingInitials: View {
    let name: String
    var size: CGFloat = 92

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
            .foregroundStyle(.white.opacity(0.92))
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
