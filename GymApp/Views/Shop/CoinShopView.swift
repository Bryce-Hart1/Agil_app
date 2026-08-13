import SwiftUI
import StoreKit

// Claude  Date 08/03/2026
// Where coins are bought with real money. Reached from the balance chip in the
// Shop's navigation bar, or from an item you can't yet afford.
//
// The prices shown here come from StoreKit (`product.displayPrice`), never from our
// own code — that's what makes them correct in every storefront and currency, and
// what stops them rotting the day a price point changes in App Store Connect. The
// app only knows how many coins a product grants (see CoinPack).
struct CoinShopView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var coinStore: CoinStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    balanceHeader

                    if coinStore.isLoadingProducts && coinStore.products.isEmpty {
                        ProgressView().padding(.vertical, 40)
                    } else if coinStore.products.isEmpty {
                        unavailableNotice
                    } else {
                        ForEach(coinStore.products, id: \.id) { product in
                            packRow(product)
                        }
                    }

                    footnote
                }
                .padding()
            }
            .background(theme.current.background.ignoresSafeArea())
            .navigationTitle("Get Coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(theme.current.accent)
                }
            }
            // Ask to Buy: the purchase isn't finished, it's waiting on a parent. Say
            // so plainly — a silent no-op reads as a bug and invites a second attempt.
            .alert("Waiting for approval", isPresented: $coinStore.pendingApproval) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This purchase needs to be approved. Your coins will arrive automatically once it is.")
            }
            // Confirmation that the coins actually landed. Consumables are silent
            // otherwise — the balance just changes — and "did that work?" is exactly
            // the doubt that produces a duplicate purchase.
            .alert("Coins added",
                   isPresented: .init(get: { coinStore.lastGrantedCoins != nil },
                                      set: { if !$0 { coinStore.lastGrantedCoins = nil } })) {
                Button("Nice", role: .cancel) { coinStore.lastGrantedCoins = nil }
            } message: {
                Text("\((coinStore.lastGrantedCoins ?? 0).formatted()) coins are in your balance.")
            }
            .alert("Something went wrong",
                   isPresented: .init(get: { coinStore.errorMessage != nil },
                                      set: { if !$0 { coinStore.errorMessage = nil } })) {
                Button("OK", role: .cancel) { coinStore.errorMessage = nil }
            } message: {
                Text(coinStore.errorMessage ?? "")
            }
        }
    }

    // MARK: - Pieces

    private var balanceHeader: some View {
        VStack(spacing: 4) {
            Label("\(theme.balance.formatted())", systemImage: "circle.hexagongrid.fill")
                .font(.title.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(theme.current.accent)
            Text("Your balance")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func packRow(_ product: Product) -> some View {
        let pack = coinStore.pack(for: product)
        let isBuying = coinStore.purchasingProductID == product.id

        return HStack(spacing: 14) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.title2)
                .foregroundStyle(theme.current.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("\((pack?.coins ?? 0).formatted()) coins")
                    .font(.headline)
                    .monospacedDigit()
                if let pack {
                    Text(pack.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button {
                Task { await coinStore.purchase(product) }
            } label: {
                if isBuying {
                    ProgressView().frame(minWidth: 56)
                } else {
                    // StoreKit's own localised price string — never a hardcoded "$2.99".
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .frame(minWidth: 56)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.accent)
            .disabled(coinStore.purchasingProductID != nil)
        }
        .padding(14)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(pack?.isFeatured == true ? theme.current.accent.opacity(0.6) : .clear,
                        lineWidth: 1.5)
        )
    }

    private var unavailableNotice: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Coin packs aren't available right now.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Try Again") { Task { await coinStore.loadProducts() } }
                .buttonStyle(.bordered)
                .tint(theme.current.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // Claude  Date 08/03/2026
    // Two promises worth making explicitly. The first is an Apple requirement
    // (purchased currency may not expire). The second is the honest description of
    // how the wallet actually restores — it rides on the Apple ID via iCloud, which
    // is why it survives a reinstall; there's no account to log into.
    private var footnote: some View {
        VStack(spacing: 6) {
            Text("Coins never expire. Buying coins helps keep Agil free for everyone.")
            Text("Your balance is tied to your Apple ID and comes back if you reinstall Agil. ")
                .multilineTextAlignment(.center)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }
}
