import Foundation
import StoreKit

// Claude  Date 08/03/2026
// The App Store side of the coin economy: fetches the coin-pack products, runs
// purchases, and credits verified transactions into the wallet.
//
// Everything here is StoreKit 2 (iOS 15+; the app targets 16.1, so no bump). The
// ordering rules below are the ones that actually matter — they're what stands
// between a user and coins they paid for going missing:
//
//   1. Never trust an unverified transaction. StoreKit signs them; `.unverified`
//      means the signature didn't check out, and we drop it.
//   2. Credit and PERSIST before calling finish(). finish() tells the App Store we
//      have delivered the goods and it can stop re-sending the transaction. Finish
//      first and crash second, and the coins are gone permanently.
//   3. Dedupe on transaction id. StoreKit re-delivers — after an interrupted
//      purchase, on relaunch, on another device. Wallet.credit() is the idempotency
//      gate and it must be the thing that decides, not a flag in the UI.
//   4. Listen from app launch, not from a view. Transactions arrive when nothing is
//      on screen — Ask to Buy approvals land hours later.
@MainActor
final class CoinStore: ObservableObject {
    /// Loaded products, in pack order (small → large).
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    /// The product id currently being purchased, for per-row spinners.
    @Published private(set) var purchasingProductID: String?
    /// Set when a purchase needs approval (Ask to Buy) — not a failure.
    @Published var pendingApproval = false
    @Published var errorMessage: String?
    /// Coins granted by the most recent credit, for a confirmation message.
    @Published var lastGrantedCoins: Int?

    private weak var theme: ThemeManager?
    private var updatesTask: Task<Void, Never>?

    deinit { updatesTask?.cancel() }

    // MARK: - Lifecycle

    // Claude  Date 08/03/2026
    // Called once at launch from GymAppApp. Starts the Transaction.updates listener
    // BEFORE loading products, so a transaction that's already waiting (an
    // interrupted purchase, an approved Ask to Buy) is handled even if the product
    // fetch fails or the user never opens the shop.
    func start(theme: ThemeManager) {
        self.theme = theme
        listenForTransactions()
        Task { await loadProducts() }
        Task { await creditUnfinishedTransactions() }
    }

    private func listenForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    // Claude  Date 08/03/2026
    // Anything still unfinished at launch — we crashed or were killed between the
    // purchase and the grant. Transaction.unfinished is exactly the set StoreKit
    // still expects delivery for.
    private func creditUnfinishedTransactions() async {
        for await update in Transaction.unfinished {
            await handle(update)
        }
    }

    // MARK: - Products

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: CoinPack.allProductIDs)
            // Sort by our own pack order rather than whatever the Store returns.
            products = fetched.sorted {
                (CoinPack.pack(for: $0.id)?.coins ?? 0) < (CoinPack.pack(for: $1.id)?.coins ?? 0)
            }
        } catch {
            errorMessage = "Couldn't reach the App Store. Check your connection and try again."
            print("⚠️ Failed to load coin products: \(error)")
        }
    }

    /// The pack a loaded product represents.
    func pack(for product: Product) -> CoinPack? { CoinPack.pack(for: product.id) }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        guard purchasingProductID == nil else { return }
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .pending:
                // Ask to Buy / SCA. Not an error — the transaction will arrive
                // through Transaction.updates whenever it's approved, possibly days
                // later. Crediting anything now would be giving away coins.
                pendingApproval = true
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "That purchase couldn't be completed."
            print("⚠️ Purchase failed: \(error)")
        }
    }

    // MARK: - Granting

    // Claude  Date 08/03/2026
    // The one path where coins are created. Every guard here is load-bearing; see
    // the rules at the top of the file.
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            print("⚠️ Dropping unverified transaction")
            return
        }

        // Refunded or revoked (family sharing removal). Deliver nothing, but finish
        // it so StoreKit stops re-sending.
        guard transaction.revocationDate == nil else {
            await transaction.finish()
            return
        }

        guard let pack = CoinPack.pack(for: transaction.productID) else {
            // Not one of ours — finish it so it doesn't loop forever.
            await transaction.finish()
            return
        }

        guard let theme else { return }   // Not wired up yet; leave it unfinished.

        // credit() returns false when this id was already applied (re-delivery) or
        // when the wallet is in safe mode. Re-delivery is fine to finish; safe mode
        // is not — leave it unfinished so it comes back once the wallet is readable.
        let credited = theme.creditPurchasedCoins(transactionID: transaction.id, coins: pack.coins)
        if !credited && theme.isSafeMode { return }

        if credited { lastGrantedCoins = pack.coins }

        // Only now: the wallet write happened synchronously above (ThemeManager's
        // didSet persists it), so the coins are durable before we release the
        // transaction.
        await transaction.finish()
    }
}
