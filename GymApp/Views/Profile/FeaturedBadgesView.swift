import SwiftUI

// Claude  Date 07/01/2026
// Pick and arrange the (up to 4) achievement badges shown on the profile card. Reuses the
// existing showcase state: `store.profile.showcasedAchievementIDs` (ordered, capped at
// AchievementShowcase.maxFeatured) via toggleShowcased / moveShowcased. Only what's chosen
// here appears on the card — no auto-fill (see AchievementShowcase.featured). Reached from
// Edit Profile Card. Since showcasedAchievementIDs is already in the shared card payload,
// friends see these picks automatically.
struct FeaturedBadgesView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var accent: Color { theme.current.accent }
    private var cap: Int { AchievementShowcase.maxFeatured }

    // The chosen badges, in display order (dropping any not currently unlocked — badges are
    // sticky, so this is just defensive).
    private var featured: [Achievement] {
        store.profile.showcasedAchievementIDs.compactMap { id in
            Achievement.all.first { $0.id == id }
        }
    }

    // Unlocked badges not already featured, best tier first — the pool you can add from.
    private var available: [Achievement] {
        AchievementShowcase.unlockedSorted(store.unlockedAchievementIDs)
            .filter { !store.profile.showcasedAchievementIDs.contains($0.id) }
    }

    private var isFull: Bool { featured.count >= cap }

    var body: some View {
        List {
            Section {
                if featured.isEmpty {
                    Text("No badges featured yet. Add up to \(cap) from below.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(featured) { badge in
                        HStack {
                            BadgeRow(badge: badge)
                            Spacer()
                            Button {
                                store.toggleShowcased(badge.id)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(badge.title)")
                        }
                    }
                    .onMove(perform: store.moveShowcased)
                    .onDelete { offsets in
                        offsets.map { featured[$0].id }.forEach { store.toggleShowcased($0) }
                    }
                }
            } header: {
                Text("On your card (\(featured.count)/\(cap))")
            } footer: {
                if !featured.isEmpty {
                    Text("Drag to reorder (Edit) · swipe or tap − to remove.")
                }
            }

            Section {
                if available.isEmpty {
                    Text(store.unlockedAchievementIDs.isEmpty
                         ? "Earn achievements to feature them here."
                         : "Every unlocked badge is already featured.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(available) { badge in
                        Button {
                            store.toggleShowcased(badge.id)
                        } label: {
                            HStack {
                                BadgeRow(badge: badge)
                                Spacer()
                                if !isFull {
                                    Image(systemName: "plus.circle.fill").foregroundStyle(accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isFull)
                    }
                }
            } header: {
                Text("Your badges")
            } footer: {
                if isFull {
                    Text("Your card is full. Remove one above to add another.")
                }
            }
        }
        .navigationTitle("Featured Badges")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .toolbar {
            if featured.count > 1 {
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
        }
    }
}

// Claude  Date 07/01/2026 — badge thumbnail + title + tier, shared by both sections.
private struct BadgeRow: View {
    let badge: Achievement

    var body: some View {
        HStack(spacing: 14) {
            BadgeView(icon: badge.icon, tier: badge.tier, unlocked: true, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(badge.tier.title).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { FeaturedBadgesView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
