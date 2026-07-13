import SwiftUI

// Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
// Customize the profile card. Name + a pick of card *styles* with a live preview.
// Styles can be solid colors or PNG-backed designs (see CardStyle); free ones
// apply on tap, paid ones prompt a coin purchase first. Trait selection later.
struct EditProfileCardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // The style awaiting a buy-confirmation, if any.
    @State private var pendingPurchase: CardStyle?
    // Claude  Date 06/30/2026 — the avatar awaiting a buy-confirmation, if any.
    @State private var pendingAvatarPurchase: Avatar?

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    // Spendable coin balance (shared pool with the Shop).
    private var balance: Int { theme.balance(earned: store.totalCoinsEarned) }

    var body: some View {
        Form {
            Section("Name") {
                TextField("First name", text: $store.profile.displayName)
                    .textInputAutocapitalization(.words)
            }

            // Claude  Date 06/30/2026
            // Avatar picker — same equip/buy flow as card styles. A horizontal strip so
            // the small set reads at a glance.
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
            }

            Section {
                // Claude  Date 07/12/2026
                // Founders cards aren't purchasable, so an unowned one shouldn't show
                // up here with a misleading "Buy" button — only list it once granted
                // (see ThemeManager.isCardStyleUnlocked / grantFoundersCards).
                ForEach(CardStyle.all.filter { !$0.isFounders || theme.isCardStyleUnlocked($0) }) { style in
                    CardStyleRow(
                        style: style,
                        isSelected: store.profile.cardStyleID == style.id,
                        isUnlocked: theme.isCardStyleUnlocked(style),
                        canAfford: balance >= style.price,
                        onSelect: { store.profile.cardStyleID = style.id },
                        onBuy: { pendingPurchase = style }
                    )
                }
            } header: {
                Text("Card style")
            } footer: {
                Text("Coins: \(balance)")
            }

            Section {
                Toggle("Show rank on card", isOn: $store.profile.showsRankOnCard)
                // Claude  Date 07/01/2026 — pick the (up to 4) badges shown on the card.
                NavigationLink {
                    FeaturedBadgesView()
                } label: {
                    HStack {
                        Label("Featured Badges", systemImage: "rosette")
                        Spacer()
                        Text("\(store.profile.showcasedAchievementIDs.count)/\(AchievementShowcase.maxFeatured)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Card elements")
            } footer: {
                Text("Equip your Strategist rank emblem, and choose which badges to feature.")
            }

            Section("Preview") {
                ProfileShowcaseCard(
                    name: store.profile.resolvedName,
                    style: CardStyle.style(for: store.profile.cardStyleID),
                    unlockedIDs: store.unlockedAchievementIDs,
                    pinnedIDs: store.profile.showcasedAchievementIDs,
                    memberSince: stats.memberSince,
                    rank: store.profile.showsRankOnCard ? store.strategistRank : nil,
                    rankProgress: store.strategistProgress,
                    avatarID: store.profile.avatarID,
                    ringFillMode: .rankProgress
                )
                .frame(height: 420)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Edit Profile Card")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .alert("Buy Card Style", isPresented: purchaseAlertBinding, presenting: pendingPurchase) { style in
            Button("Buy for \(style.price)") { confirmPurchase(style) }
            Button("Cancel", role: .cancel) {}
        } message: { style in
            Text("Unlock the \(style.name) card for \(style.price) coins?")
        }
        .alert("Buy Avatar", isPresented: avatarPurchaseAlertBinding, presenting: pendingAvatarPurchase) { avatar in
            Button("Buy for \(avatar.price)") { confirmAvatarPurchase(avatar) }
            Button("Cancel", role: .cancel) {}
        } message: { avatar in
            Text("Unlock the \(avatar.name) avatar for \(avatar.price) coins?")
        }
    }

    // Drives the confirmation alert; clearing it dismisses.
    private var purchaseAlertBinding: Binding<Bool> {
        Binding(get: { pendingPurchase != nil }, set: { if !$0 { pendingPurchase = nil } })
    }

    private var avatarPurchaseAlertBinding: Binding<Bool> {
        Binding(get: { pendingAvatarPurchase != nil }, set: { if !$0 { pendingAvatarPurchase = nil } })
    }

    // Buy, then apply the newly unlocked style to the card.
    private func confirmPurchase(_ style: CardStyle) {
        if theme.purchaseCardStyle(style, balance: balance) {
            store.profile.cardStyleID = style.id
        }
        pendingPurchase = nil
    }

    // Buy, then equip the newly unlocked avatar.
    private func confirmAvatarPurchase(_ avatar: Avatar) {
        if theme.purchaseAvatar(avatar, balance: balance) {
            store.profile.avatarID = avatar.id
        }
        pendingAvatarPurchase = nil
    }
}

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
