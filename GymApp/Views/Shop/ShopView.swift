import SwiftUI

// Claude  Date 06/13/2026 last changed: 08/03/2026 by: Claude
// The Shop — a Fortnite-style FEATURED tab.
//
// Concept (Bryce, 6/17/26): instead of one long static list, the shop shows a
// small line-up chosen by a date-seeded random pick (see DailyShop). The same items
// appear for everyone on a given day with no backend, and a live countdown shows
// when it rolls over. Rarer items surface less often, which gives the catalogue
// some scarcity.
//
// A "Browse all" drawer keeps every item reachable so nothing gets locked behind
// the rotation while we iterate.
//
// Claude  Date 08/03/2026
// Two cadences now: four items that turn over daily and two that hold for the week
// (see DailyShop.lineup). Coins can also be bought with real money, so the balance
// lives in the navigation bar where it's always visible and always tappable, and an
// item you can't afford offers a way to top up.
struct ShopView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var coinStore: CoinStore

    // The item shown full-size in the preview sheet (tap a tile to set it).
    @State private var previewItem: ShopItem?
    @State private var showingCoinShop = false

    // Both line-ups — a pure function of the date, recomputed on render.
    private var lineup: DailyShop.Lineup { DailyShop.lineup() }

    // Spendable balance (earned high-water + purchased − spent; see Wallet).
    private var balance: Int { theme.balance }

    // Every item, for the "Browse all" drawer (free base items included).
    // Claude  Date 07/12/2026 last changed: 07/23/2026 by: Claude
    // Grant-only cards (Founders + earned gem cards) are never sold, so they're
    // excluded here too — this drawer is meant to be a complete view of what's
    // *purchasable*, not a leak of exclusive cards other players can't actually buy.
    private var fullCatalog: [ShopItem] {
        AppTheme.builtIns.map(ShopItem.theme) + CardStyle.all.filter { !$0.isGrantOnly }.map(ShopItem.card)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                rotationSection(
                    title: "Featured",
                    cadence: "Rotates daily",
                    rotation: lineup.daily
                )
                rotationSection(
                    title: "This Week",
                    cadence: "Rotates weekly",
                    rotation: lineup.weekly
                )
                browseAllSection
            }
            .padding()
        }
        .navigationTitle("Shop")
        .themed(theme.current)
        // Claude  Date 08/03/2026
        // Balance in the top right, where it stays put while the grid scrolls — it
        // used to be a row at the top of the content and scrolled away exactly when
        // you were deciding whether you could afford something. Tapping it opens the
        // coin shop. (.topBarTrailing is @available(iOS 14) + @backDeployed, so it's
        // fine at the 16.1 deployment target.)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCoinShop = true } label: {
                    Label("\(balance.formatted())", systemImage: "circle.hexagongrid.fill")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                .tint(theme.current.accent)
                .accessibilityLabel("\(balance) coins. Tap to get more.")
            }
        }
        .sheet(isPresented: $showingCoinShop) {
            CoinShopView()
                .environmentObject(theme)
                .environmentObject(coinStore)
        }
        // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
        // fullScreenCover, not a sheet. The old .sheet opened at a .medium detent that
        // was shorter than the detail content's intrinsic height, so the description
        // and the "you need N more coins" line were pushed off the bottom edge. An
        // item is also the thing you're about to spend 3,000 coins on — it deserves
        // the whole screen. Dismissal is the detail view's own Go Back button and
        // toolbar chevron, since a full-screen cover has no drag-to-dismiss.
        .fullScreenCover(item: $previewItem) { item in
            ShopItemDetailView(
                item: item,
                isOwned: isOwned(item),
                isEquipped: isEquipped(item),
                canAfford: balance >= item.price,
                balance: balance,
                onBuy: { buy(item) },
                onEquip: { equip(item) },
                onGetCoins: { showingCoinShop = true }
            )
            .environmentObject(theme)
            .environmentObject(coinStore)
        }
    }

    // MARK: - Rotation sections

    // Claude  Date 08/03/2026
    // One section per cadence — "Featured" (4, daily) and "This Week" (2, weekly).
    // The live countdown now sits in the section header next to the cadence label,
    // because with two rotations running there's no one number a shared header could
    // show. Ticks once a second; when it hits zero the line-up (date-derived) rolls
    // over on its own the next time the view renders.
    private func rotationSection(title: String, cadence: String,
                                 rotation: DailyShop.Rotation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.weight(.bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(cadence)
                        .font(.caption)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(countdown(to: rotation.refreshesAt, now: context.date))
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)],
                      spacing: 14) {
                ForEach(rotation.items) { item in
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

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // Buy (if affordable) and immediately equip. The balance is no longer passed in:
    // ThemeManager owns the wallet now and checks affordability itself, so there's
    // one place that can authorise a spend.
    private func buy(_ item: ShopItem) {
        switch item {
        case .theme(let t):
            if theme.purchase(t) { theme.select(t) }
        case .card(let c):
            if theme.purchaseCardStyle(c) { store.profile.cardStyleID = c.id }
        }
    }

    private func equip(_ item: ShopItem) {
        switch item {
        case .theme(let t): theme.select(t)
        case .card(let c):  store.profile.cardStyleID = c.id
        }
    }

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // "5h 03m 12s", or "6d 04h 12m" once there's more than a day left. The day
    // branch exists for the weekly rotation — without it a fresh week reads
    // "163h 04m 12s", which nobody can parse at a glance.
    private func countdown(to end: Date, now: Date) -> String {
        let secs = max(0, Int(end.timeIntervalSince(now)))
        if secs >= 86_400 {
            return String(format: "%dd %02dh %02dm", secs / 86_400, (secs % 86_400) / 3600, (secs % 3600) / 60)
        }
        return String(format: "%dh %02dm %02ds", secs / 3600, (secs % 3600) / 60, secs % 60)
    }
}

// MARK: - Featured tile

// Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
// One hero tile in the featured grid: full-bleed artwork (the live card or a mini
// theme mock), the name, and a price / owned line. Tapping opens the detail screen
// where the actual buying happens.
//
// No rarity badge here any more (Bryce, 8/3/26): a capsule sitting on top of the
// artwork competed with the item it was labelling — you looked at the badge instead
// of the card. Rarity is still on the tile, just not as chrome: the stroke and glow
// are the tier colour, so gold still reads as legendary at a glance. The spelled-out
// badge lives on the detail screen, where there's room for it to not be in the way.
private struct FeaturedItemCard: View {
    let item: ShopItem
    let isOwned: Bool
    let isEquipped: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ShopItemArtwork(item: item)
                    .frame(height: 130)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(item.rarityColor.opacity(0.65), lineWidth: 1.5)
                    )
                    .shadow(color: item.rarityColor.opacity(0.35), radius: 8, y: 2)

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

// MARK: - Item detail (the buy screen)

// Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
// Full-screen look at one item with the buy / equip action — the "preview for the
// shop" Bryce asked for: see the theme or card big before spending.
//
// Was ShopItemPreviewSheet, a fixed-height VStack in a .medium sheet detent, which
// clipped its own copy off the bottom. Two structural changes stop that recurring:
// the content scrolls (so it can never overflow, on any device size or Dynamic Type
// setting), and the buttons live in a .safeAreaInset bar pinned to the bottom
// instead of being pushed there by a Spacer that had no room to give.
private struct ShopItemDetailView: View {
    let item: ShopItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let balance: Int
    let onBuy: () -> Void
    let onEquip: () -> Void
    let onGetCoins: () -> Void

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero

                    VStack(spacing: 8) {
                        Text(item.name)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        RarityBadge(label: item.rarityLabel, color: item.rarityColor)
                    }

                    // Per-item copy (see ShopItem.blurb) — used to be one of two
                    // generic strings shared by every theme / every card.
                    Text(item.blurb)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    priceRow
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(theme.current.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { actionBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Second dismissal affordance — the bottom Go Back button is the
                // primary one, this is the reachable-with-a-thumb twin.
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .tint(theme.current.accent)
                }
            }
        }
    }

    // MARK: Hero

    // Claude  Date 08/03/2026
    // Cards show their real background full-bleed (animated ones animate here too).
    // Themes get ThemeShowcaseView — a slice of actual app UI in the theme's palette
    // and typeface — instead of the old abstract ThemeMiniMock, so you can judge
    // legibility before buying. The showcase needs more height than a card since it
    // holds real components at real size.
    @ViewBuilder private var hero: some View {
        Group {
            switch item {
            case .card:
                ShopItemArtwork(item: item).frame(height: 240)
            case .theme(let appTheme):
                ThemeShowcaseView(theme: appTheme).frame(height: 330)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(item.rarityColor.opacity(0.65), lineWidth: 2)
        )
        .shadow(color: item.rarityColor.opacity(0.4), radius: 14, y: 4)
    }

    // Price and what's left in the wallet — worth showing now there's room for it.
    @ViewBuilder private var priceRow: some View {
        if !isOwned {
            HStack(spacing: 10) {
                Label("\(item.price.formatted())", systemImage: "circle.hexagongrid.fill")
                    .font(.headline)
                    .foregroundStyle(item.rarityColor)
                Text("·").foregroundStyle(.secondary)
                Text("Balance \(balance.formatted())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
        }
    }

    // MARK: Action bar

    // Claude  Date 08/03/2026
    // Pinned to the bottom of the screen, so nothing here can ever be scrolled or
    // squeezed out of view. Order is deliberate: the action, then why it's disabled,
    // then the way out.
    private var actionBar: some View {
        VStack(spacing: 10) {
            actionButton

            // Claude  Date 08/03/2026
            // Deliberately a sibling here rather than living inside actionButton's
            // @ViewBuilder. In the old code it was returned from that builder as part
            // of a TupleView, which flattened it into the parent stack as an extra
            // row below the button — and it was the first thing to fall off the
            // bottom edge. Keeping it explicit is what actually fixes the clipping.
            if !isOwned && !canAfford {
                Text("You need \((item.price - balance).formatted()) more coins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Claude  Date 08/03/2026
                // The top-up path, shown only when you're actually short. Deliberately
                // a secondary .bordered control rather than a prominent one: coins are
                // meant to be earned by training, and this is an app that exists to get
                // you to train. Offering the shortcut is fair; leading with it isn't.
                Button {
                    dismiss()
                    onGetCoins()
                } label: {
                    Label("Get Coins", systemImage: "cart")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(theme.current.accent)
            }

            // The clear way out. Required, not decorative: a full-screen cover can't
            // be swiped away.
            Button { dismiss() } label: {
                Text("Go Back")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(theme.current.background)
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

// Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
// Renders a preview of any ShopItem, scaled to whatever frame it's given — the one
// place that knows how each kind looks. Cards reuse the real CardBackgroundView
// (so animated cards animate here too); themes get a tiny mocked "app screen" so
// the palette reads at a glance.
//
// This is the SMALL artwork only: the 130pt featured tiles and the 44pt browse-all
// rows. The detail screen deliberately doesn't go through here for themes — it
// renders ThemeShowcaseView instead (real components at real size). At tile size
// that showcase would be unreadable mush, so the abstract mock still earns its keep
// at the top of the funnel.
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

// Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
// A miniature fake "app screen" that shows off a theme's palette: tinted
// background, an accent header bar, a couple of surface cards, and an accent
// "button". Purely cosmetic art, and now only used at TILE size — the detail screen
// shows the real thing (ThemeShowcaseView). Everything is proportional to the frame
// height, which is why it survives being shrunk to a 44pt browse-all row.
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
        .environmentObject(CoinStore())
}
