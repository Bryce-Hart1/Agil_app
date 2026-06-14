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

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    // Spendable coin balance (shared pool with the Shop).
    private var balance: Int { theme.balance(earned: Coins.earned(from: store.workouts)) }

    var body: some View {
        Form {
            Section("Name") {
                TextField("First name", text: $store.profile.displayName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                ForEach(CardStyle.all) { style in
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

            Section("Preview") {
                ProfileShowcaseCard(
                    name: store.profile.resolvedName,
                    style: CardStyle.style(for: store.profile.cardStyleID),
                    traits: ProfileTrait.showcase(from: stats),
                    memberSince: stats.memberSince
                )
                .frame(height: 420)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Text("Choosing which traits to show and more card styles are coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
    }

    // Drives the confirmation alert; clearing it dismisses.
    private var purchaseAlertBinding: Binding<Bool> {
        Binding(get: { pendingPurchase != nil }, set: { if !$0 { pendingPurchase = nil } })
    }

    // Buy, then apply the newly unlocked style to the card.
    private func confirmPurchase(_ style: CardStyle) {
        if theme.purchaseCardStyle(style, balance: balance) {
            store.profile.cardStyleID = style.id
        }
        pendingPurchase = nil
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
            Text(style.name).foregroundStyle(.primary)
            Spacer()
            trailing
        }
        .contentShape(Rectangle())
        .onTapGesture { if isUnlocked { onSelect() } }
    }

    @ViewBuilder private var swatch: some View {
        Group {
            switch style.background {
            case .color(let hex):
                Circle().fill(Color(hex: hex))
            case .image(let asset):
                Image(asset).resizable().scaledToFill()
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
                Label("\(style.price)", systemImage: "circle.hexagongrid.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAfford)
            .opacity(canAfford ? 1 : 0.5)
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
