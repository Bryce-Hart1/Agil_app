import Foundation

// Claude  Date 08/03/2026
// The coin wallet, reworked for real money.
//
// Until now the whole wallet was derived: `balance = max(0, earned − coinsSpent)`,
// where BOTH sides were recomputed from scratch on every read — earned from the
// workout list, spent by re-pricing everything you own against the live catalogue.
// That is a genuinely nice design for coins you can only earn, and it breaks in
// three specific ways once coins can be bought:
//
//   1. `earned` goes DOWN when you delete workouts, and the max(0,…) clamp then
//      quietly absorbs coins that were paid for. Apple's rule for purchased
//      currency is that it may not expire, so this is a compliance problem and not
//      just a bug.
//   2. `coinsSpent` re-prices against the CURRENT catalogue, so repricing or
//      removing an item retroactively rewrites everybody's balance. This already
//      happened once: when avatars were removed, everyone who had bought one
//      silently got the coins back.
//   3. Nothing recorded what was actually paid, so there was no way to answer
//      "where did my coins go".
//
// The model here keeps what worked and fixes what didn't:
//
//      balance = earnedHighWater + purchasedCoins − spentTotal
//
// Earned coins stay DERIVED from workouts and achievements (no double-counting,
// still the right model) but are held at a high-water mark so they can only ever go
// up. Purchased coins are stored and only ever added by a verified StoreKit
// transaction. Spending appends to a ledger that records the price actually paid,
// so the catalogue can be retuned freely afterwards. No clamp is needed anywhere:
// every term is monotonic, so the balance can't go negative on its own.
struct Wallet: Codable, Equatable {
    // Claude  Date 08/03/2026
    // The highest lifetime-earned total ever observed (see AppStore.totalCoinsEarned).
    // Monotonic on purpose: deleting a workout no longer costs you coins you already
    // banked, which was a real pre-existing bug — it just stops the number growing.
    var earnedHighWater: Int = 0

    /// Coins bought with real money. Only `credit(transactionID:coins:)` may raise this.
    var purchasedCoins: Int = 0

    /// Every spend, in order, at the price actually charged at the time.
    var spendLedger: [SpendEntry] = []

    // Claude  Date 08/03/2026
    // StoreKit re-delivers transactions — on relaunch, across devices, after an
    // interrupted purchase. Without this set a redelivery would grant the coins a
    // second time. This is the idempotency key for real money; it is not optional.
    var processedTransactionIDs: Set<UInt64> = []

    /// One purchase, frozen at the price that was actually paid.
    struct SpendEntry: Codable, Equatable, Identifiable, Hashable {
        /// Stable id so two devices merging their ledgers can dedupe by value.
        var id: UUID = UUID()
        /// `ShopItem.id` — "theme:<uuid>" or "card:<id>".
        var itemID: String
        var pricePaid: Int
        var date: Date = .now
    }

    /// Total ever spent — the ledger is the record, never a recomputation.
    var spentTotal: Int { spendLedger.reduce(0) { $0 + $1.pricePaid } }

    /// Spendable coins.
    var balance: Int { earnedHighWater + purchasedCoins - spentTotal }

    // MARK: - Mutation

    /// Raise the earned high-water mark. Never lowers it.
    mutating func noteEarned(_ earned: Int) {
        earnedHighWater = max(earnedHighWater, earned)
    }

    // Claude  Date 08/03/2026
    // Credit a verified StoreKit purchase. Returns false — changing nothing — when
    // this transaction has already been credited, which is what makes calling it
    // twice safe. The caller must only finish() the transaction after this has been
    // persisted; see CoinStore.
    @discardableResult
    mutating func credit(transactionID: UInt64, coins: Int) -> Bool {
        guard processedTransactionIDs.insert(transactionID).inserted else { return false }
        purchasedCoins += coins
        return true
    }

    /// Record a spend. The caller checks affordability; this just writes the receipt.
    mutating func spend(itemID: String, price: Int) {
        spendLedger.append(SpendEntry(itemID: itemID, pricePaid: price))
    }

    // MARK: - Merge

    // Claude  Date 08/03/2026
    // Reconcile this wallet with one from iCloud. Deliberately max/union rather than
    // last-writer-wins: a timestamp race must never be allowed to decide how much
    // money someone has. Every field here only grows, so merging is commutative,
    // idempotent, and always errs toward the user.
    //
    // Note the ledger and the purchased total have to travel TOGETHER — merging
    // coins without the spends they paid for would refund every past purchase.
    func merged(with other: Wallet) -> Wallet {
        var out = self
        out.earnedHighWater = max(earnedHighWater, other.earnedHighWater)
        out.purchasedCoins = max(purchasedCoins, other.purchasedCoins)
        out.processedTransactionIDs = processedTransactionIDs.union(other.processedTransactionIDs)

        // Union by entry id, keeping chronological order.
        var seen = Set(spendLedger.map(\.id))
        var ledger = spendLedger
        for entry in other.spendLedger where !seen.contains(entry.id) {
            seen.insert(entry.id)
            ledger.append(entry)
        }
        out.spendLedger = ledger.sorted { $0.date < $1.date }
        return out
    }
}
