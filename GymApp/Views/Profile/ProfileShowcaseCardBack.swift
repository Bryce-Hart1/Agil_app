import SwiftUI

// CLAUDE  Date 09/05/2026
// Which part of the card BACK was tapped; the owner raises the matching sheet. Mirrors
// ProfileCardEditActions on the front, defaulted so a caller wires only what it needs.
struct ProfileCardBackEditActions {
    var background: () -> Void = {}
    var stats: () -> Void = {}
}

// CLAUDE  Date 09/05/2026
// The card's back face: the same chrome as the front, carrying one hero stat over a grid
// of up to CardStat.maxTiles. It takes RESOLVED values and no EnvironmentObject — same
// discipline as the front, and the reason a friend's back can never render your numbers.
struct ProfileShowcaseCardBack: View {
    let name: String
    let style: CardStyle
    var logoAsset: String = ThemeIcon.classicLogoAsset
    let stats: CardBackStats
    let memberSince: Date?
    var edit: ProfileCardBackEditActions? = nil

    private var canAddMore: Bool {
        stats.hero == nil || stats.tiles.count < CardStat.maxTiles
    }

    var body: some View {
        VStack(spacing: 16) {
            CardBrandHeader(logoAsset: logoAsset) {
                if let edit { CardPaletteChip(action: edit.background) }
            }

            // Smaller than the front's largeTitle — on this face the stats are the
            // subject and the name is just the attribution on a shared screenshot.
            Text(name)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            statsSection

            Spacer(minLength: 12)

            if let memberSince {
                Text("Member since \(memberSince.formatted(.dateTime.month().year()))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .cardFaceChrome(style: style)
    }

    // MARK: - Stats

    @ViewBuilder private var statsSection: some View {
        if let edit {
            VStack(spacing: 10) {
                if !stats.isEmpty {
                    Button(action: edit.stats) { statsContent }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) { CardEditChip().padding(-4) }
                }
                // Under the cap there's a slot to fill; at the cap there's nowhere to put
                // a new stat, so the prompt routes to the same picker to swap one out.
                Button(action: edit.stats) {
                    if canAddMore { addStatSlot } else { changePrompt }
                }
                .buttonStyle(.plain)
            }
        } else if !stats.isEmpty {
            statsContent
        } else {
            Text("No stats on this side yet.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var statsContent: some View {
        VStack(spacing: 10) {
            if let hero = stats.hero { heroTile(hero) }
            if !stats.tiles.isEmpty { statGrid }
        }
    }

    // A single tile would sit as a lonely half-width box, so one stat spans the row.
    @ViewBuilder private var statGrid: some View {
        if stats.tiles.count == 1, let only = stats.tiles.first {
            tile(only)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(stats.tiles) { tile($0) }
            }
        }
    }

    // CLAUDE  Date 09/05/2026
    // The headline stat, shaped after PerformanceCardView's best-set tile. Free-text
    // stats (an exercise name rather than a number) get two lines and shrink harder,
    // since a branded lift name is far longer than "225 lb".
    private func heroTile(_ value: CardStatValue) -> some View {
        VStack(spacing: 6) {
            Label(value.stat.title, systemImage: value.stat.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(value.value)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(value.stat.carriesUserText ? 2 : 1)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
            if let caption = value.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }

    // White on a translucent fill, matching PerformanceCardView.statCell — StatCard's
    // .secondary palette is built for the light Progress list and vanishes on a card.
    private func tile(_ value: CardStatValue) -> some View {
        VStack(spacing: 4) {
            Image(systemName: value.stat.systemImage)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Text(value.value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(value.stat.carriesUserText ? 2 : 1)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
            Text(value.stat.title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    // The same two edit affordances the front's badge row uses, so both faces teach the
    // same gesture: a plus-shaped empty slot, or a swap prompt once it's full.
    private var addStatSlot: some View {
        VStack(spacing: 6) {
            Image("selection-plus")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 44, height: 44)
            Text(stats.isEmpty ? "Add stats" : "Add")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
        .frame(maxWidth: .infinity)
    }

    private var changePrompt: some View {
        VStack(spacing: 4) {
            Image("minus-square")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 22, height: 22)
            Text("Change or remove stats")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}
