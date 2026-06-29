import SwiftUI

// Claude  Date 06/13/2026 last changed: 06/17/2026 by: Claude
// The Shop — reworked into a Fortnite-style FEATURED tab.
//
// Concept (Bryce, 6/17/26): instead of one long static list, the shop shows a
// small daily line-up — a couple of themes and a few profile cards — chosen by a
// date-seeded random pick (see DailyShop). The same items appear for everyone on
// a given day with no backend, and a live countdown shows when it rolls over.
// Rarer items surface less often, which gives the catalogue some scarcity.
//
// This is an outline pass: layout + wiring are real, but the artwork mocks, copy,
// rarity tiers for themes, and "what stays permanently buyable" are all meant to
// be tweaked. A "Browse all" drawer keeps every item reachable for now so nothing
// gets locked behind the rotation while we iterate.
//
// Balance is still derived live: lifetime earned (store.totalCoinsEarned) minus
// what's been spent (ThemeManager.coinsSpent). No stored wallet. Local-only.
struct ShopView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // The item shown full-size in the preview sheet (tap a tile to set it).
    @State private var previewItem: ShopItem?

    // Today's featured line-up — a pure function of the date, recomputed on render.
    private var rotation: DailyShop.Rotation { DailyShop.rotation() }

    // Spendable balance (earned − everything spent on themes + card styles).
    private var balance: Int { theme.balance(earned: store.totalCoinsEarned) }

    // Every item, for the "Browse all" drawer (free base items included).
    private var fullCatalog: [ShopItem] {
        AppTheme.builtIns.map(ShopItem.theme) + CardStyle.all.map(ShopItem.card)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                featuredSection
                browseAllSection
            }
            .padding()
        }
        .navigationTitle("Shop")
        .themed(theme.current)
        .sheet(item: $previewItem) { item in
            ShopItemPreviewSheet(
                item: item,
                isOwned: isOwned(item),
                isEquipped: isEquipped(item),
                canAfford: balance >= item.price,
                balance: balance,
                onBuy: { buy(item) },
                onEquip: { equip(item) }
            )
            .environmentObject(theme)
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header (balance + refresh countdown)

    private var header: some View {
        HStack {
            Label("\(balance)", systemImage: "circle.hexagongrid.fill")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(theme.current.accent)

            Spacer()

            // Claude  Date 06/17/2026
            // Live "refreshes in …" countdown to the next local midnight. Ticks once
            // a second; when it hits zero the rotation (date-derived) rolls over on
            // its own the next time the view renders.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(countdown(to: rotation.refreshesAt, now: context.date),
                      systemImage: "clock")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Featured grid

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Featured")
                    .font(.title2.weight(.bold))
                Spacer()
                Text("Rotates daily")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)],
                      spacing: 14) {
                ForEach(rotation.featured) { item in
                    FeaturedItemCard(
                        item: item,
                        isOwned: isOwned(item),
                        isEquipped: isEquipped(item),
                        onTap: { previewItem = item }
                    )
                }
            }
        }
    }

    // MARK: - Browse-all drawer

    // Claude  Date 06/17/2026
    // Escape hatch so the daily rotation doesn't trap an item the user wants for
    // days. Remove (or gate behind something) if we want pure scarcity later.
    private var browseAllSection: some View {
        DisclosureGroup {
            VStack(spacing: 0) {
                ForEach(fullCatalog) { item in
                    CatalogRow(
                        item: item,
                        isOwned: isOwned(item),
                        isEquipped: isEquipped(item),
                        onTap: { previewItem = item }
                    )
                    if item.id != fullCatalog.last?.id { Divider() }
                }
            }
            .padding(.top, 4)
        } label: {
            Text("Browse all items").font(.headline)
        }
        .padding()
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Ownership / purchase plumbing

    private func isOwned(_ item: ShopItem) -> Bool {
        switch item {
        case .theme(let t): return theme.isUnlocked(t)
        case .card(let c):  return theme.isCardStyleUnlocked(c)
        }
    }

    private func isEquipped(_ item: ShopItem) -> Bool {
        switch item {
        case .theme(let t): return t.id == theme.selectedID
        case .card(let c):  return c.id == store.profile.cardStyleID
        }
    }

    // Buy (if affordable) and immediately equip — mirrors the old shop's behaviour.
    private func buy(_ item: ShopItem) {
        switch item {
        case .theme(let t):
            if theme.purchase(t, balance: balance) { theme.select(t) }
        case .card(let c):
            if theme.purchaseCardStyle(c, balance: balance) { store.profile.cardStyleID = c.id }
        }
    }

    private func equip(_ item: ShopItem) {
        switch item {
        case .theme(let t): theme.select(t)
        case .card(let c):  store.profile.cardStyleID = c.id
        }
    }

    // "5h 03m 12s" until the given instant.
    private func countdown(to end: Date, now: Date) -> String {
        let secs = max(0, Int(end.timeIntervalSince(now)))
        return String(format: "%dh %02dm %02ds", secs / 3600, (secs % 3600) / 60, secs % 60)
    }
}

// MARK: - Featured tile

// Claude  Date 06/17/2026
// One hero tile in the featured grid: full-bleed artwork (the live card or a mini
// theme mock), a rarity badge, the name, and a price / owned line. Tapping opens
// the preview sheet where the actual buying happens.
private struct FeaturedItemCard: View {
    let item: ShopItem
    let isOwned: Bool
    let isEquipped: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ShopItemArtwork(item: item)
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(item.rarityColor.opacity(0.65), lineWidth: 1.5)
                        )
                        .shadow(color: item.rarityColor.opacity(0.35), radius: 8, y: 2)

                    RarityBadge(label: item.rarityLabel, color: item.rarityColor)
                        .padding(8)
                }

                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                priceLine
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var priceLine: some View {
        if isEquipped {
            Label("Equipped", systemImage: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        } else if isOwned {
            Text("Owned").font(.caption).foregroundStyle(.secondary)
        } else {
            Label("\(item.price.formatted())", systemImage: "circle.hexagongrid.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.rarityColor)
                .monospacedDigit()
        }
    }
}

// MARK: - Browse-all row

// Claude  Date 06/17/2026
// Compact list row mirroring the old shop rows, for the "Browse all" drawer.
private struct CatalogRow: View {
    let item: ShopItem
    let isOwned: Bool
    let isEquipped: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ShopItemArtwork(item: item)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).foregroundStyle(.primary).lineLimit(1)
                RarityBadge(label: item.rarityLabel, color: item.rarityColor)
            }

            Spacer(minLength: 8)

            if isEquipped {
                Image(systemName: "checkmark").fontWeight(.semibold)
            } else if isOwned {
                Text("Owned").font(.subheadline).foregroundStyle(.secondary)
            } else if item.price > 0 {
                Label("\(item.price.formatted())", systemImage: "circle.hexagongrid.fill")
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Preview sheet (the buy screen)

// Claude  Date 06/17/2026
// Full-size look at one item with the buy / equip action. This doubles as the
// "preview for the shop" Bryce asked for — see the theme or card big before
// spending. A confirm alert could be layered on later; for now the prominent
// "Buy for N" button is the confirmation step.
private struct ShopItemPreviewSheet: View {
    let item: ShopItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let balance: Int
    let onBuy: () -> Void
    let onEquip: () -> Void

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            ShopItemArtwork(item: item)
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(item.rarityColor.opacity(0.65), lineWidth: 2)
                )
                .shadow(color: item.rarityColor.opacity(0.4), radius: 14, y: 4)

            VStack(spacing: 8) {
                Text(item.name).font(.title2.weight(.bold))
                RarityBadge(label: item.rarityLabel, color: item.rarityColor)
            }

            Text(kindDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            actionButton
                .padding(.horizontal)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
        .background(theme.current.background.ignoresSafeArea())
    }

    private var kindDescription: String {
        switch item {
        case .theme: return "An app-wide colour theme. Equip it to recolour every screen."
        case .card:  return "A profile-card background. Equip it from your profile card."
        }
    }

    @ViewBuilder private var actionButton: some View {
        if isEquipped {
            Label("Equipped", systemImage: "checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        } else if isOwned {
            Button { onEquip(); dismiss() } label: {
                Text("Equip").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(item.rarityColor)
            .controlSize(.large)
        } else {
            Button { onBuy(); dismiss() } label: {
                Label("Buy for \(item.price.formatted())", systemImage: "circle.hexagongrid.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(item.rarityColor)
            .controlSize(.large)
            .disabled(!canAfford)
            .opacity(canAfford ? 1 : 0.5)

            if !canAfford {
                Text("You need \((item.price - balance).formatted()) more coins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Shared bits

// Claude  Date 06/17/2026
// Small coloured rarity capsule, shared by the tile, the row, and the sheet.
private struct RarityBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.5))
    }
}

// Claude  Date 06/17/2026
// Renders a preview of any ShopItem, scaled to whatever frame it's given — the one
// place that knows how each kind looks. Cards reuse the real CardBackgroundView
// (so animated cards animate here too); themes get a tiny mocked "app screen" so
// the palette reads at a glance. Refine the theme mock later.
private struct ShopItemArtwork: View {
    let item: ShopItem

    var body: some View {
        switch item {
        case .card(let style):
            CardBackgroundView(background: style.background)
        case .theme(let appTheme):
            ThemeMiniMock(theme: appTheme)
        }
    }
}

// Claude  Date 06/17/2026
// A miniature fake "app screen" that shows off a theme's palette: tinted
// background, an accent header bar, a couple of surface cards, and an accent
// "button". Purely cosmetic placeholder art for the shop tiles.
private struct ThemeMiniMock: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            theme.background
            GeometryReader { geo in
                let unit = geo.size.height
                VStack(alignment: .leading, spacing: unit * 0.06) {
                    Capsule().fill(theme.accent)
                        .frame(width: geo.size.width * 0.5, height: unit * 0.1)
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4).fill(theme.surface)
                            .frame(height: unit * 0.2)
                    }
                    Capsule().fill(theme.accent)
                        .frame(width: geo.size.width * 0.4, height: unit * 0.12)
                }
                .padding(unit * 0.12)
            }
        }
    }
}

#Preview {
    NavigationStack { ShopView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
