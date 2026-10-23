import SwiftUI
import StoreKit

// CLAUDE  Date 10/23/2026
// The Founders Pack page, opened from the banner at the bottom of the Shop. Shows the cards,
// what the pack is, and the one real-money button in Agil (price from StoreKit, never typed
// in here), plus Restore Purchases. Closes itself once the cards land so the unlock
// celebration, which RootTabView draws under any sheet, can be seen.
struct FoundersPackView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var foundersStore: FoundersStore
    @Environment(\.dismiss) private var dismiss

    @State private var appear = false

    // Founders gold, matching CardTier.founders.color.
    private let gold = Color(red: 1.0, green: 0.82, blue: 0.25)

    private var founderCards: [CardStyle] { CardStyle.all.filter(\.isFounders) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    FoundersCardRow(cards: founderCards, appear: appear,
                                    captionColor: .primary)
                    perks
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) { actionBar }
            .background(theme.current.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(theme.current.accent)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appear = true }
            }
            .onChange(of: theme.ownsFoundersCards) { owned in
                if owned { dismiss() }
            }
            .alert("Waiting for approval", isPresented: $foundersStore.pendingApproval) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This purchase needs to be approved. Your cards will arrive automatically once it is.")
            }
            .alert("No Founders Pack found",
                   isPresented: $foundersStore.restoreFoundNothing) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This Apple ID hasn't bought the Founders Pack.")
            }
            .alert("Something went wrong",
                   isPresented: .init(get: { foundersStore.errorMessage != nil },
                                      set: { if !$0 { foundersStore.errorMessage = nil } })) {
                Button("OK", role: .cancel) { foundersStore.errorMessage = nil }
            } message: {
                Text(foundersStore.errorMessage ?? "")
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 6) {
            Text("Founders Edition")
                .font(.subheadline.weight(.bold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(gold)
            Text("Founders Pack")
                .font(.largeTitle.weight(.heavy))
            Text("Back Agil early and get the cards nobody else can.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 12) {
            perk("sparkles", "Three animated Founders Edition cards: Shooting Stars, Galaxy and Constellation.")
            perk("lock.fill", "Never sold for coins and never in the Shop rotation.")
            perk("arrow.clockwise", "Pay once, keep them for good. They come back on any phone signed in to your Apple ID.")
            perk("heart.fill", "Everything else in Agil stays free and is earned by training.")
        }
        .padding()
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func perk(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(gold)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 10) {
            if theme.ownsFoundersCards {
                Label("Owned", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                Text("Equip them from Edit Profile Card.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let product = foundersStore.product {
                Button {
                    Task { await foundersStore.purchase() }
                } label: {
                    Group {
                        if foundersStore.isPurchasing {
                            ProgressView()
                        } else {
                            // StoreKit's own localised price string.
                            Text("Buy for \(product.displayPrice)")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(gold)
                .foregroundStyle(.black)
                .disabled(foundersStore.isPurchasing || foundersStore.isRestoring)

                restoreButton
            } else if foundersStore.isLoadingProduct {
                ProgressView().padding()
            } else {
                Text("The Founders Pack isn't available right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await foundersStore.loadProduct() } }
                    .buttonStyle(.bordered)
                    .tint(theme.current.accent)
                restoreButton
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(theme.current.background)
    }

    private var restoreButton: some View {
        Button {
            Task { await foundersStore.restore() }
        } label: {
            if foundersStore.isRestoring {
                ProgressView()
            } else {
                Text("Restore Purchases")
            }
        }
        .font(.subheadline)
        .tint(theme.current.accent)
        .disabled(foundersStore.isPurchasing || foundersStore.isRestoring)
    }
}

#Preview {
    FoundersPackView()
        .environmentObject(ThemeManager())
        .environmentObject(FoundersStore())
}
