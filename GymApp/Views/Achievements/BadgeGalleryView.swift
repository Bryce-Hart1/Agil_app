import SwiftUI

// Claude  Date 06/15/2026
// Dev/alpha gallery for eyeballing all badge + rank art without grinding data.
// Shows every category across all 7 tiers (earned medallion or locked, medallion
// or card style) and the full chess rank ladder. Tap any badge to preview its
// unlock celebration; tap any rank to preview its promotion — both non-destructive
// (see AppStore.replayCelebration / previewPromotion).
struct BadgeGalleryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private enum State_: String, CaseIterable { case earned = "Earned", locked = "Locked" }
    private enum Style_: String, CaseIterable { case medallion = "Medallion", card = "Card" }

    @State private var state: State_ = .earned
    @State private var style: Style_ = .medallion

    private var unlocked: Bool { state == .earned }
    private var ringed: Bool { style == .medallion }

    var body: some View {
        List {
            Section {
                Picker("State", selection: $state) {
                    ForEach(State_.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Style", selection: $style) {
                    ForEach(Style_.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Tap a badge to preview its unlock celebration. Medallion = list/celebration look; Card = the ringless glyph used on the profile card.")
            }

            ForEach(Achievement.Category.allCases, id: \.self) { category in
                Section(category.title) {
                    badgeRow(for: category)
                }
            }

            Section {
                rankRow
            } header: {
                Text("Strategist ranks")
            } footer: {
                Text("Tap a rank to preview its promotion celebration.")
            }
        }
        .navigationTitle("Badge Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
    }

    // One horizontal strip of all 7 tiers for a category.
    private func badgeRow(for category: Achievement.Category) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(BadgeTier.allCases, id: \.self) { tier in
                    // Claude  Date 07/14/2026 — gender-calibrated catalog so previewed
                    // celebrations show the right title/threshold text.
                    let achievement = store.achievementCatalog.first { $0.category == category && $0.tier == tier }
                    VStack(spacing: 6) {
                        BadgeView(icon: category.iconName, tier: tier,
                                  unlocked: unlocked, size: 54, glimmer: true, ringed: ringed)
                        Text(tier.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 64)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let achievement { store.replayCelebration(achievement) }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // The chess rank ladder; tap to preview the promotion overlay.
    private var rankRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(StrategistRank.allCases, id: \.self) { rank in
                    VStack(spacing: 6) {
                        StrategistEmblem(rank: rank, size: 56, showProgress: false, unlocked: unlocked)
                        Text(rank.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 70)
                    .contentShape(Rectangle())
                    .onTapGesture { store.previewPromotion(rank) }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    NavigationStack { BadgeGalleryView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
