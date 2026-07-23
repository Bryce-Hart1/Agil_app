import SwiftUI

// Claude  Date 06/12/2026 last changed: 07/22/2026 by: Claude
// (07/22) Rebuilt as a tap-to-edit screen: the live profile card fills the view and each
// part of it is tappable — tap the avatar/rank, name, badges, or the header palette chip
// and the matching editor slides up as a bottom sheet. The old Form of stacked sections is
// gone; every control now lives behind the element it changes. The pickers themselves
// (card styles, avatars, coin/buy flow) are unchanged — just relocated into the sheets.
struct EditProfileCardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Which element's editor is currently presented (nil = none).
    @State private var target: EditTarget?

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    // Claude  Date 07/22/2026
    // The tappable regions of the card, each mapped to a bottom sheet. `.rank` shares the
    // avatar sheet (the rank ring frames the avatar, so they're edited together). Name is
    // deliberately absent — renaming lives in Settings › Change Name, not on the card.
    private enum EditTarget: String, Identifiable {
        case style, avatar, badges
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 12) {
                    ProfileShowcaseCard(
                        name: store.profile.resolvedName,
                        style: CardStyle.style(for: store.profile.cardStyleID),
                        unlockedIDs: store.unlockedAchievementIDs,
                        pinnedIDs: store.profile.showcasedAchievementIDs,
                        memberSince: stats.memberSince,
                        rank: store.profile.showsRankOnCard ? store.strategistRank : nil,
                        rankProgress: store.strategistProgress,
                        avatarID: store.profile.avatarID,
                        ringFillMode: .rankProgress,
                        catalog: store.achievementCatalog,
                        edit: ProfileCardEditActions(
                            background: { target = .style },
                            avatar: { target = .avatar },
                            rank: { target = .avatar },
                            badges: { target = .badges }
                        )
                    )
                    .frame(height: max(380, geo.size.height - 64))

                    Text("Tap any part of your card to edit it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
                .padding(16)
            }
            .background(theme.current.background.ignoresSafeArea())
        }
        .navigationTitle("Edit Profile Card")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .sheet(item: $target) { target in
            switch target {
            case .style:
                CardStylePickerSheet()
                    .environmentObject(store)
                    .environmentObject(theme)
                    .presentationDetents([.medium, .large])
            case .avatar:
                AvatarPickerSheet()
                    .environmentObject(store)
                    .environmentObject(theme)
                    .presentationDetents([.medium, .large])
            case .badges:
                NavigationStack { FeaturedBadgesView() }
                    .environmentObject(store)
                    .environmentObject(theme)
            }
        }
    }
}

// MARK: - Card style picker

// Claude  Date 07/22/2026
// The card-style chooser, raised by the header palette chip. Shows ONLY styles the user
// already owns — buying happens in the Shop, so this stays a clean "equip what you have"
// list with no coin/buy clutter. Applying a style updates the live card underneath
// immediately (store.profile is the shared source of truth).
private struct CardStylePickerSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    // Owned styles only, in catalog order.
    private var ownedStyles: [CardStyle] {
        CardStyle.all.filter { theme.isCardStyleUnlocked($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ownedStyles) { style in
                        CardStyleRow(
                            style: style,
                            isSelected: store.profile.cardStyleID == style.id,
                            isUnlocked: true,
                            canAfford: false,
                            onSelect: { store.profile.cardStyleID = style.id },
                            onBuy: {}
                        )
                    }
                } footer: {
                    Text("Unlock more styles in the Shop.")
                }
            }
            .navigationTitle("Card Style")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Avatar + rank picker

// Claude  Date 07/22/2026
// Raised by tapping the avatar or the rank title. Groups the whole avatar/ring cluster: the
// avatar strip (equip/buy) plus the "Show rank on card" toggle — putting the rank control
// here means it's reachable even when the ring is currently off (nothing to tap on the card
// in that case).
private struct AvatarPickerSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    // The avatar awaiting a buy-confirmation, if any.
    @State private var pendingAvatarPurchase: Avatar?

    private var balance: Int { theme.balance(earned: store.totalCoinsEarned) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(Avatar.all) { avatar in
                                AvatarPickCell(
                                    avatar: avatar,
                                    accent: theme.current.accent,
                                    isSelected: store.profile.avatarID == avatar.id,
                                    isUnlocked: theme.isAvatarUnlocked(avatar),
                                    canAfford: balance >= avatar.price,
                                    onSelect: { store.profile.avatarID = avatar.id },
                                    onBuy: { pendingAvatarPurchase = avatar }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Avatar")
                } footer: {
                    Text("Coins: \(balance)")
                }

                Section {
                    Toggle("Show rank on card", isOn: $store.profile.showsRankOnCard)
                } footer: {
                    Text("Frames your avatar with your Strategist rank emblem.")
                }
            }
            .navigationTitle("Avatar & Rank")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Buy Avatar", isPresented: avatarPurchaseAlertBinding, presenting: pendingAvatarPurchase) { avatar in
                Button("Buy for \(avatar.price)") { confirmAvatarPurchase(avatar) }
                Button("Cancel", role: .cancel) {}
            } message: { avatar in
                Text("Unlock the \(avatar.name) avatar for \(avatar.price) coins?")
            }
        }
    }

    private var avatarPurchaseAlertBinding: Binding<Bool> {
        Binding(get: { pendingAvatarPurchase != nil }, set: { if !$0 { pendingAvatarPurchase = nil } })
    }

    // Buy, then equip the newly unlocked avatar.
    private func confirmAvatarPurchase(_ avatar: Avatar) {
        if theme.purchaseAvatar(avatar, balance: balance) {
            store.profile.avatarID = avatar.id
        }
        pendingAvatarPurchase = nil
    }
}

// MARK: - Rows (shared by the sheets above)

// Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
// One card-style row: a swatch (color fill or image thumbnail) + name, with a
// trailing control — selected (checkmark), owned (tap to apply), or locked (Buy
// button, disabled when unaffordable).
private struct CardStyleRow: View {
    let style: CardStyle
    let isSelected: Bool
    let isUnlocked: Bool
    let canAfford: Bool
    let onSelect: () -> Void
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            swatch
            // Claude  Date 06/16/2026 last changed: 06/16/2026 by: Claude
            // Name truncates if space is tight so it can never squeeze the badge or
            // buy button into wrapping (which made the price spill into a circle).
            Text(style.name)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            // Claude  Date 06/16/2026 — rarity badge (hidden for the free base).
            if let label = style.tier.label {
                tierBadge(label, color: style.tier.color)
            }
            Spacer(minLength: 8)
            trailing
        }
        .contentShape(Rectangle())
        .onTapGesture { if isUnlocked { onSelect() } }
    }

    // Claude  Date 06/16/2026
    // Small coloured capsule marking the card's rarity tier (Rare/Epic/Legendary).
    private func tierBadge(_ label: String, color: Color) -> some View {
        Text(label.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.5))
    }

    @ViewBuilder private var swatch: some View {
        Group {
            switch style.background {
            case .color(let hex):
                Circle().fill(Color(hex: hex))
            case .gradient(let from, let to):
                Circle().fill(LinearGradient(colors: [Color(hex: from), Color(hex: to)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
            case .image(let asset):
                Image(asset).resizable().scaledToFill()
            // Claude  Date 06/16/2026
            // Live animated preview right in the swatch so the motion sells itself.
            case .animated(let kind):
                AnimatedCardBackground(kind: kind)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(.quaternary))
    }

    @ViewBuilder private var trailing: some View {
        if isSelected {
            Image(systemName: "checkmark").fontWeight(.semibold)
        } else if isUnlocked {
            Text("Owned").font(.subheadline).foregroundStyle(.secondary)
        } else {
            Button(action: onBuy) {
                Label("\(style.price.formatted())", systemImage: "circle.hexagongrid.fill")
                    .font(.subheadline)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAfford)
            .opacity(canAfford ? 1 : 0.5)
        }
    }
}

// Claude  Date 06/30/2026
// One avatar in the horizontal picker: the avatar art in a ring (accent when selected),
// its name, and a state line below — selected, "Owned", or a coin price to buy. Tapping
// an owned/free avatar equips it; a locked one triggers the buy alert.
private struct AvatarPickCell: View {
    let avatar: Avatar
    let accent: Color
    let isSelected: Bool
    let isUnlocked: Bool
    let canAfford: Bool
    let onSelect: () -> Void
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            AvatarView(avatar: avatar, size: 60, tint: accent,
                       discColor: Color.gray.opacity(0.15),
                       ringColor: isSelected ? accent : Color.gray.opacity(0.3))
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accent)
                            .background(Circle().fill(.background))
                    }
                }

            Text(avatar.name).font(.caption).lineLimit(1)

            trailing
                .font(.caption2)
                .frame(height: 16)
        }
        .frame(width: 72)
        .contentShape(Rectangle())
        .onTapGesture { if isUnlocked { onSelect() } else { onBuy() } }
    }

    @ViewBuilder private var trailing: some View {
        if isSelected {
            Text("Equipped").foregroundStyle(.secondary)
        } else if isUnlocked {
            Text("Owned").foregroundStyle(.secondary)
        } else {
            Label("\(avatar.price)", systemImage: "circle.hexagongrid.fill")
                .foregroundStyle(canAfford ? accent : .secondary)
                .opacity(canAfford ? 1 : 0.6)
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileCardView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
    }
}
