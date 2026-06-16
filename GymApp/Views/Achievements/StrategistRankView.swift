import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 06/15/2026 last changed: 06/16/2026 by: Claude
// The rank emblem, "reversed" from the badge medallion to make it pop on the card:
// the chess piece itself is filled with the rank's material gradient over a CLEAR
// interior, ringed by a thin outline (or, when showProgress, the progress ring that
// fills with the next rank's color as you climb). Premium ranks twinkle.
struct StrategistEmblem: View {
    let rank: StrategistRank
    var progress: Double = 1
    var size: CGFloat = 96
    var showProgress: Bool = true
    var unlocked: Bool = true

    // The progress ring fills with the color of the rank you're climbing toward.
    private var nextColor: Color {
        (StrategistScoring.nextRank(after: rank)?.tier.color) ?? rank.tier.color
    }

    private var glyphStyle: AnyShapeStyle {
        unlocked ? AnyShapeStyle(rank.tier.fillGradient)
                 : AnyShapeStyle(Color.gray.opacity(0.5))
    }

    private var lineWidth: CGFloat { size * 0.055 }

    var body: some View {
        ZStack {
            ring
            glyphView()
                .foregroundStyle(glyphStyle)
                .shadow(color: unlocked ? .black.opacity(0.18) : .clear,
                        radius: size * 0.02, y: 0.5)

            if unlocked && rank.tier.hasPremiumShine {
                SparkleField(extent: size, color: rank.tier.glimmerColor)
            }
        }
        .frame(width: size, height: size)
    }

    // Outline ring (clear interior). Legend gets the purple→gold gradient rim;
    // when showProgress, a gray track + colored progress arc instead.
    @ViewBuilder private var ring: some View {
        if showProgress {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(nextColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        } else if unlocked && rank.tier == .legend {
            Circle().strokeBorder(
                AngularGradient(colors: [rank.tier.color, rank.tier.glimmerColor, rank.tier.color],
                                center: .center),
                lineWidth: lineWidth)
        } else {
            Circle().strokeBorder((unlocked ? rank.tier.color : Color.gray.opacity(0.5)),
                                  lineWidth: lineWidth)
        }
    }

    // Custom chess symbol if imported, else a valid SF Symbol fallback.
    @ViewBuilder private func glyphView() -> some View {
        let s = size * (showProgress ? 0.5 : 0.64)
        #if canImport(UIKit)
        if UIImage(named: rank.iconName) != nil {
            Image(rank.iconName)
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: s, height: s)
        } else {
            Image(systemName: rank.fallbackSymbol).font(.system(size: s, weight: .semibold))
        }
        #else
        Image(systemName: rank.fallbackSymbol).font(.system(size: s, weight: .semibold))
        #endif
    }
}

// Claude  Date 06/15/2026
// The tappable rank row shown below the profile card — emblem + current rank +
// progress to the next. Wrap in a NavigationLink to push StrategistRankView.
struct StrategistRankBanner: View {
    let rank: StrategistRank
    let progress: Double
    let pointsToNext: Int

    var body: some View {
        HStack(spacing: 14) {
            StrategistEmblem(rank: rank, progress: progress, size: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text("Strategist rank")
                    .font(.caption).foregroundStyle(.secondary)
                Text(rank.title).font(.headline)
                if let next = StrategistScoring.nextRank(after: rank) {
                    Text("\(pointsToNext) to \(next.title)")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Highest rank reached")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

// Claude  Date 06/15/2026
// The Strategist detail screen: a big emblem with progress, then the full 7-rung
// ladder (earned ranks lit, locked ones dimmed) and how the score is computed.
struct StrategistRankView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        let score = store.strategistScore
        let rank = store.strategistRank
        let progress = store.strategistProgress

        List {
            Section {
                VStack(spacing: 12) {
                    StrategistEmblem(rank: rank, progress: progress, size: 132)
                    Text(rank.title).font(.title2.weight(.bold))
                    if let next = StrategistScoring.nextRank(after: rank) {
                        Text("\(StrategistScoring.pointsToNext(forScore: score)) points to \(next.title)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Text("You've reached the highest rank.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(StrategistRank.allCases, id: \.self) { r in
                    rankRow(r, current: rank)
                }
            } header: {
                Text("Ranks")
            } footer: {
                Text("Score counts every badge you've earned, weighted by tier (Bronze 1 → Legend 7). Your score: \(score) / \(StrategistScoring.maxScore).")
            }
        }
        .navigationTitle("Strategist")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
    }

    @ViewBuilder
    private func rankRow(_ r: StrategistRank, current: StrategistRank) -> some View {
        let earned = r <= current
        HStack(spacing: 14) {
            StrategistEmblem(rank: r, size: 44, showProgress: false, unlocked: earned)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.title)
                    .font(.headline)
                    .foregroundStyle(earned ? .primary : .secondary)
                Text("\(r.scoreThreshold) pts")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if r == current {
                Text("Current")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(r.tier.color)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { StrategistRankView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
