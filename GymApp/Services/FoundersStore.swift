import Foundation
import StoreKit

// CLAUDE  Date 10/23/2026
// The Founders Pack, Agil's only real-money purchase: a one-time, non-consumable unlock of
// the Founders Edition cards. Replaces CoinStore (coins are earned only now). Side effects:
// grants the cards through ThemeManager and queues AppStore's founders celebration.
@MainActor
final class FoundersStore: ObservableObject {
    /// Must match App Store Connect and Agil.storekit exactly.
    static let productID = "com.brycehart.gymapp.founders"

    /// The pack as the App Store describes it; nil until loaded (or if the Store is unreachable).
    @Published private(set) var product: Product?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    /// Set when a purchase needs approval (Ask to Buy). Not a failure.
    @Published var pendingApproval = false
    @Published var errorMessage: String?
    /// Restore ran fine but this Apple ID never bought the pack.
    @Published var restoreFoundNothing = false

    private weak var theme: ThemeManager?
    private weak var store: AppStore?
    private var updatesTask: Task<Void, Never>?

    deinit { updatesTask?.cancel() }

    // MARK: - Lifecycle

    // CLAUDE  Date 10/23/2026
    // Called once at launch from GymAppApp. Listens before anything else so an Ask to Buy
    // approval is never missed, then re-grants from the current entitlement. That launch
    // check is what restores the cards after a reinstall or on a new phone, silently.
    func start(theme: ThemeManager, store: AppStore) {
        self.theme = theme
        self.store = store
        listenForTransactions()
        Task { await loadProduct() }
        Task { await refreshEntitlement(celebrate: false) }
        Task { await finishUnfinished() }
    }

    private func listenForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update, celebrate: true)
            }
        }
    }

    // CLAUDE  Date 10/23/2026
    // Anything StoreKit still expects delivery for: an interrupted pack purchase, or a coin
    // pack bought on an older alpha build (no longer sold; finished without granting).
    private func finishUnfinished() async {
        for await update in Transaction.unfinished {
            await handle(update, celebrate: false)
        }
    }

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            print("⚠️ Failed to load the Founders Pack: \(error)")
        }
    }

    // MARK: - Purchase / restore

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification, celebrate: true)
            case .pending:
                // Ask to Buy / SCA: the transaction arrives through Transaction.updates
                // once approved, possibly days later.
                pendingApproval = true
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "That purchase couldn't be completed."
            print("⚠️ Founders Pack purchase failed: \(error)")
        }
    }

    // CLAUDE  Date 10/23/2026
    // "Restore Purchases" (App Review requires one for a non-consumable). AppStore.sync is
    // qualified because the app has its own AppStore type. It may ask the user to sign in.
    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await StoreKit.AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            errorMessage = "Couldn't reach the App Store. Check your connection and try again."
            return
        }
        if !(await refreshEntitlement(celebrate: true)) { restoreFoundNothing = true }
    }

    // MARK: - Granting

    // CLAUDE  Date 10/23/2026
    // Grants the cards if this Apple ID owns the pack. Returns whether it does. Safe to
    // run any number of times: grantFoundersCards only reports (and celebrates) new cards.
    @discardableResult
    private func refreshEntitlement(celebrate: Bool) async -> Bool {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        if owned { grant(celebrate: celebrate) }
        return owned
    }

    // CLAUDE  Date 10/23/2026
    // One delivered transaction. Unverified ones are dropped; refunded ones and products we
    // don't sell are finished without granting so StoreKit stops re-sending them.
    private func handle(_ result: VerificationResult<Transaction>, celebrate: Bool) async {
        guard case .verified(let transaction) = result else {
            print("⚠️ Dropping unverified transaction")
            return
        }
        if transaction.productID == Self.productID, transaction.revocationDate == nil {
            grant(celebrate: celebrate)
        }
        // Finishing is safe even if the grant didn't persist: the entitlement is re-checked
        // on every launch, so a non-consumable can't be lost the way a coin pack could.
        await transaction.finish()
    }

    private func grant(celebrate: Bool) {
        guard let theme else { return }
        if theme.grantFoundersCards() && celebrate {
            store?.celebrateFoundersUnlock()
        }
    }
}
