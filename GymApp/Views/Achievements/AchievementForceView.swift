import SwiftUI

// Claude  Date 07/25/2026
// Dev/alpha tool: force any achievement locked or unlocked, one at a time.
//
// The pre-existing helpers in Settings are all-or-nothing — unlock everything, or
// wipe and re-earn from history — which is useless for checking how a SINGLE badge
// looks and behaves (its glyph knocked out on its tier disc, how it sorts on the
// card, what it does to the Strategist score). Manufacturing the workout history to
// earn one legitimately is worse. This screen writes the unlocked set directly via
// AppStore.devSetAchievements, so any combination is reachable in two taps.
//
// Deliberately NOT behind #if DEBUG: it sits with the other "Developer (alpha)"
// tools, which all ship in release builds so they work on a real device during the
// alpha. Gate the whole section when that stops being true.
struct AchievementForceView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var search = ""
    @State private var tierFilter: BadgeTier?
    // Forced unlocks land unopened by default, so they queue in the Achievement Book
    // and light the Profile-tab count — that's the path most worth exercising.
    @State private var queueAsNew = true
    // Off by default, matching unlockAllAchievements: bulk-forcing a set of badges
    // shouldn't throw a stack of promotion overlays unless you asked for it.
    @State private var firePromotions = false

    // The gender-calibrated catalog, so titles/details match what the user sees.
    private var catalog: [Achievement] { store.achievementCatalog }

    private var filtered: [Achievement] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return catalog.filter { achievement in
            if let tierFilter, achievement.tier != tierFilter { return false }
            guard !query.isEmpty else { return true }
            return achievement.title.lowercased().contains(query)
                || achievement.id.lowercased().contains(query)
                || achievement.detail.lowercased().contains(query)
        }
    }

    // Claude  Date 07/25/2026
    // Grouped for display the same way the Achievement Book pages are: one section
    // per category, with secrets pulled out into their own trailing section rather
    // than hiding inside whatever category they nominally carry.
    private var sections: [(title: String, entries: [Achievement])] {
        var result: [(String, [Achievement])] = Achievement.Category.allCases.compactMap { category in
            let entries = filtered.filter { $0.category == category && !$0.isSecret }
            return entries.isEmpty ? nil : (category.title, entries)
        }
        let secrets = filtered.filter(\.isSecret)
        if !secrets.isEmpty { result.append(("Secrets", secrets)) }
        return result
    }

    var body: some View {
        List {
            summarySection
            optionsSection

            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.entries) { achievement in
                        row(for: achievement)
                    }
                } header: {
                    sectionHeader(title: section.title, entries: section.entries)
                }
            }

            Section {
                Button("Lock everything", role: .destructive) {
                    store.devSetAchievements(ids: Set(catalog.map(\.id)), unlocked: false)
                }
            } footer: {
                Text("Clears every unlock, including any earned legitimately. Settings › Reset achievements re-earns them from your activity history; this screen does not.")
            }
        }
        .navigationTitle("Force Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .searchable(text: $search, prompt: "Title, id, or requirement")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Tier", selection: $tierFilter) {
                        Text("All tiers").tag(BadgeTier?.none)
                        ForEach(BadgeTier.allCases, id: \.self) { tier in
                            Text(tier.title).tag(BadgeTier?.some(tier))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: tierFilter == nil
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .retintOnThemeChange(theme.current, salt: "force-tier")
            }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            LabeledContent("Unlocked") {
                Text("\(store.unlockedAchievementIDs.count) / \(catalog.count)")
                    .monospacedDigit()
                    .foregroundStyle(theme.current.accent)
            }
            LabeledContent("Waiting in the book") {
                Text("\(store.unopenedAchievementCount)")
                    .monospacedDigit()
            }
            LabeledContent("Strategist") {
                Text("\(store.strategistRank.title) · \(store.strategistScore) / \(StrategistScoring.maxScore)")
                    .monospacedDigit()
                    .supportingTextFont()
            }
        }
    }

    private var optionsSection: some View {
        Section {
            Toggle("Unlock as new", isOn: $queueAsNew)
            Toggle("Fire rank promotions", isOn: $firePromotions)
        } header: {
            Text("How forced unlocks land")
        } footer: {
            Text("Unlock as new leaves badges unopened, so they queue in the Achievement Book and light the Profile tab count; off marks them already seen. Fire rank promotions plays the promotion overlay when the forced badges push you up the ladder — off still keeps the rank in sync, it just does it silently.")
        }
    }

    private func sectionHeader(title: String, entries: [Achievement]) -> some View {
        HStack {
            Text(title)
            Text("\(unlockedCount(in: entries)) / \(entries.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Spacer()
            // Bulk actions scoped to what's actually on screen: with a tier filter or
            // a search active these act on the visible subset, not the whole category.
            Button("All") { setAll(entries, unlocked: true) }
                .buttonStyle(.borderless)
            Button("None") { setAll(entries, unlocked: false) }
                .buttonStyle(.borderless)
        }
        .textCase(nil)
    }

    private func row(for achievement: Achievement) -> some View {
        let isUnlocked = store.unlockedAchievementIDs.contains(achievement.id)
        return Toggle(isOn: Binding(
            get: { isUnlocked },
            set: { newValue in
                store.devSetAchievement(id: achievement.id, unlocked: newValue,
                                        queueAsNew: queueAsNew, firePromotions: firePromotions)
            }
        )) {
            HStack(spacing: 12) {
                // The real BadgeView, so this doubles as a check that the glyph reads
                // correctly knocked out on its tier disc.
                BadgeView(icon: achievement.icon, tier: achievement.tier,
                          unlocked: isUnlocked, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    // Secrets show their real title here — concealing them from the
                    // person forcing them would defeat the point of the tool.
                    Text(achievement.title)
                        .font(.subheadline.weight(.medium))
                    Text("\(achievement.tier.title) · \(achievement.detail)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .supportingTextFont()
                    Text(achievement.id)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .supportingTextFont()
                }
            }
        }
    }

    // MARK: - Helpers

    private func unlockedCount(in entries: [Achievement]) -> Int {
        entries.filter { store.unlockedAchievementIDs.contains($0.id) }.count
    }

    private func setAll(_ entries: [Achievement], unlocked: Bool) {
        store.devSetAchievements(ids: Set(entries.map(\.id)), unlocked: unlocked,
                                 queueAsNew: queueAsNew, firePromotions: firePromotions)
    }
}

#Preview {
    NavigationStack {
        AchievementForceView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
    }
}
