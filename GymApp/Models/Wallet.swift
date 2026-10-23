import Foundation

// Claude  Date 08/03/2026 last changed: 10/23/2026 by: CLAUDE
// The coin wallet: balance = earnedHighWater − spentTotal. Earned coins stay derived from
// workouts and achievements but are held at a high-water mark, and spends go to a ledger at
// the price actually paid, so retuning the catalogue can't rewrite anyone's balance.
// (10/23) Coins can no longer be bought (the Founders Pack is the only purchase), so the
// purchased-coins total and its StoreKit transaction ids are gone.
struct Wallet: Codable, Equatable {
    // Claude  Date 08/03/2026
    // The highest lifetime-earned total ever observed (see AppStore.totalCoinsEarned).
    // Monotonic on purpose: deleting a workout no longer costs you coins you already
    // banked, which was a real pre-existing bug — it just stops the number growing.
    var earnedHighWater: Int = 0

    /// Every spend, in order, at the price actually charged at the time.
    var spendLedger: [SpendEntry] = []

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
    var balance: Int { earnedHighWater - spentTotal }

    // MARK: - Mutation

    /// Raise the earned high-water mark. Never lowers it.
    mutating func noteEarned(_ earned: Int) {
        earnedHighWater = max(earnedHighWater, earned)
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
    // Note the ledger and the earned total have to travel TOGETHER — merging coins
    // without the spends they paid for would refund every past purchase.
    func merged(with other: Wallet) -> Wallet {
        var out = self
        out.earnedHighWater = max(earnedHighWater, other.earnedHighWater)

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
