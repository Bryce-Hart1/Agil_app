import SwiftUI

// CLAUDE  Date 09/24/2026
// The picture inside the card's avatar disc: the rank's chess piece or an AGIL icon on a
// faint backing disc. Shared by the card itself and the Avatar sheet's choices, so the
// options look exactly like the result. `.none` draws only the empty disc.
struct CardAvatarCore: View {
    let avatar: CardAvatar
    let rank: StrategistRank?
    let diameter: CGFloat

    @Environment(\.cardInk) private var cardInk

    var body: some View {
        ZStack {
            Circle().fill((cardInk ?? .white).color.opacity(0.15))
            switch avatar {
            case .rank:
                if let rank { StrategistGlyph(rank: rank, size: diameter * 0.62) }
            case .icon(let icon):
                ProfileIconGlyph(icon: icon, rank: rank, size: diameter * 0.7)
            case .none:
                EmptyView()
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
}

// CLAUDE  Date 09/24/2026
// One AGIL icon, template-tinted with the rank's tier gradient — the same treatment as
// StrategistGlyph, so a Ram at Warrior is gold like the knight it replaced. With no rank
// (a friend's card with rank hidden) it falls back to the card's text colour.
struct ProfileIconGlyph: View {
    let icon: ProfileIcon
    var rank: StrategistRank? = nil
    var size: CGFloat = 60

    @Environment(\.cardInk) private var cardInk

    var body: some View {
        Image(icon.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(rank.map { AnyShapeStyle($0.tier.fillGradient) }
                             ?? AnyShapeStyle((cardInk ?? .white).color))
            .shadow(color: rank == nil ? .clear : .black.opacity(0.18),
                    radius: size * 0.03, y: 0.5)
    }
}

// CLAUDE  Date 09/24/2026
// The rank ring unrolled into a bar of 7 capsules, for cards that pick "Bar" over the
// ring. Same two readings as RankRing.fillLayer — continuous progress on your own card,
// N of 7 lit (plus a faint next segment) on a friend's — so switching styles loses nothing.
struct RankProgressBar: View {
    let rank: StrategistRank
    var progress: Double = 1
    var fillMode: RankRingFill = .rankSegments
    var width: CGFloat = 150
    var height: CGFloat = 8

    @Environment(\.cardInk) private var cardInk

    private let gap: CGFloat = 4
    private var count: Int { RingGeometry.segmentCount }
    private var litSegments: Int { rank.rawValue + 1 }
    private var clampedProgress: Double { max(0, min(1, progress)) }
    private var nextColor: Color {
        (StrategistScoring.nextRank(after: rank)?.tier.color) ?? rank.tier.color
    }

    var body: some View {
        ZStack {
            Canvas { ctx, canvas in
                for i in 0..<count {
                    ctx.fill(segment(i, in: canvas), with: .color(trackColor))
                }
            }
            if fillMode == .rankSegments, litSegments < count, clampedProgress > 0 {
                Canvas { ctx, canvas in
                    ctx.fill(segment(litSegments, fraction: clampedProgress, in: canvas),
                             with: .color(nextColor.opacity(0.75)))
                }
            }
            rank.tier.fillGradient.mask {
                Canvas { ctx, canvas in
                    for (i, fraction) in fills.enumerated() where fraction > 0 {
                        ctx.fill(segment(i, fraction: fraction, in: canvas), with: .color(.white))
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel("\(rank.title) rank progress")
    }

    private var trackColor: Color { (cardInk ?? .white).color.opacity(0.18) }

    // How much of each segment the tier gradient covers, per fill mode.
    private var fills: [Double] {
        switch fillMode {
        case .rankSegments:
            return (0..<count).map { $0 < litSegments ? 1 : 0 }
        case .rankProgress:
            let filled = clampedProgress * Double(count)
            return (0..<count).map { max(0, min(1, filled - Double($0))) }
        }
    }

    // Segment i as a capsule, trimmed from its leading edge to `fraction` of its width.
    private func segment(_ i: Int, fraction: Double = 1, in canvas: CGSize) -> Path {
        let w = (canvas.width - gap * CGFloat(count - 1)) / CGFloat(count)
        let rect = CGRect(x: CGFloat(i) * (w + gap), y: 0,
                          width: w * CGFloat(fraction), height: canvas.height)
        return Path(roundedRect: rect, cornerRadius: min(rect.height, rect.width) / 2)
    }
}
