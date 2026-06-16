import SwiftUI

// Claude  Date 06/13/2026
// The Shop: spend coins (earned from workout consistency) to unlock themes.
// First pass — themes only; user icons / namecard backgrounds come later.
// The balance is derived live: lifetime earned (Coins.earned) minus what's been
// spent on unlocked themes (ThemeManager.coinsSpent), so there's no stored
// wallet to keep in sync. Local-only for now.
struct ShopView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // The theme awaiting a buy-confirmation, if any.
    @State private var pendingPurchase: AppTheme?

    // Lifetime coins earned (consistency + achievements).
    private var earned: Int { store.totalCoinsEarned }
    // Spendable balance (earned − everything spent on themes + card styles).
    private var balance: Int { theme.balance(earned: earned) }

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Coins", systemImage: "circle.hexagongrid.fill")
                    Spacer()
                    Text("\(balance)")
                        .font(.headline)
                        .foregroundStyle(theme.current.accent)
                        .monospacedDigit()
                }
            } footer: {
                Text("Earn coins by training each week. Spend them on themes.")
            }

            Section("Themes") {
                ForEach(AppTheme.builtIns) { preset in
                    ShopThemeRow(
                        rowTheme: preset,
                        isSelected: preset.id == theme.selectedID,
                        isUnlocked: theme.isUnlocked(preset),
                        canAfford: balance >= preset.price,
                        onSelect: { theme.select(preset) },
                        onBuy: { pendingPurchase = preset }
                    )
                }
            }
        }
        .navigationTitle("Shop")
        .themed(theme.current)
        .alert("Buy Theme", isPresented: purchaseAlertBinding, presenting: pendingPurchase) { preset in
            Button("Buy for \(preset.price)") { confirmPurchase(preset) }
            Button("Cancel", role: .cancel) {}
        } message: { preset in
            Text("Unlock \(preset.name) for \(preset.price) coins?")
        }
    }

    // Drives the confirmation alert; clearing it dismisses.
    private var purchaseAlertBinding: Binding<Bool> {
        Binding(get: { pendingPurchase != nil }, set: { if !$0 { pendingPurchase = nil } })
    }

    // Buy, then equip the newly unlocked theme.
    private func confirmPurchase(_ preset: AppTheme) {
        if theme.purchase(preset, balance: balance) {
            theme.select(preset)
        }
        pendingPurchase = nil
    }
}

// Claude  Date 06/13/2026
// One theme row in the Shop: swatch + name, with a trailing control that depends
// on state — selected (checkmark), owned (tap to equip), or locked (Buy button,
// disabled when you can't afford it).
private struct ShopThemeRow: View {
    let rowTheme: AppTheme
    let isSelected: Bool
    let isUnlocked: Bool
    let canAfford: Bool
    let onSelect: () -> Void
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            swatch
            Text(rowTheme.name).foregroundStyle(.primary)
            Spacer()
            trailing
        }
        .contentShape(Rectangle())
        .onTapGesture { if isUnlocked { onSelect() } }
    }

    @ViewBuilder private var trailing: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .foregroundStyle(rowTheme.accent)
                .fontWeight(.semibold)
        } else if isUnlocked {
            Text("Owned").font(.subheadline).foregroundStyle(.secondary)
        } else {
            Button(action: onBuy) {
                Label("\(rowTheme.price)", systemImage: "circle.hexagongrid.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .tint(rowTheme.accent)
            .disabled(!canAfford)
            .opacity(canAfford ? 1 : 0.5)
        }
    }

    private var swatch: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(rowTheme.background)
            Circle().fill(rowTheme.accent).frame(width: 16, height: 16)
        }
        .frame(width: 34, height: 34)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
    }
}

#Preview {
    NavigationStack { ShopView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
