import Foundation

// Claude  Date 06/17/2026
// The "random, but the same for everyone" daily shop engine.
//
// THE TRICK (per Bryce's concept): there is no backend. The featured line-up is a
// pure function of the calendar date, so every device computes the *identical*
// shop for a given day, offline, with zero sync. Rarity comes from (a) seeding a
// deterministic pseudo-random generator from the date and (b) weighting the pick
// so legendary items show up less often (see ShopItem.weight).
//
// Bryce floated `month*day + year` as the seed. That works but collides a lot and
// barely changes day-to-day, so we instead build a YYYYMMDD key (a distinct,
// monotonic number per day) and run it through SplitMix64, which diffuses it so
// consecutive days look completely unrelated. The "date in, same shop out" spirit
// is unchanged — just a sturdier seed. Swap `seed(for:)` if you want the literal
// month*day+year version back.
enum DailyShop {

    // MARK: - Tunable knobs (the whole concept lives here)

    /// How many themes / cards are featured each day.
    static let themeCount = 2
    static let cardCount  = 3

    // MARK: - Pools (paid items only — free base items are always available
    // elsewhere, so they don't take up a precious featured slot).

    static var themePool: [ShopItem] {
        AppTheme.builtIns.filter { $0.price > 0 }.map(ShopItem.theme)
    }
    static var cardPool: [ShopItem] {
        CardStyle.all.filter { $0.price > 0 }.map(ShopItem.card)
    }

    // MARK: - Rotation

    // Claude  Date 06/17/2026
    // The featured line-up for a given day plus when it rolls over. `date` is the
    // start of the shop day; `refreshesAt` is the next local midnight, which the
    // UI counts down to. (Day boundaries are local-time, matching "on 6-17-26"
    // thinking — users in different timezones flip at their own midnight.)
    struct Rotation {
        let date: Date
        let themes: [ShopItem]
        let cards: [ShopItem]
        let refreshesAt: Date

        /// Themes first, then cards — a single list for the featured grid.
        var featured: [ShopItem] { themes + cards }
    }

    static func rotation(for date: Date = .now, calendar: Calendar = .current) -> Rotation {
        let day = calendar.startOfDay(for: date)
        // One generator stream for the whole day so the pick is fully deterministic.
        var gen = SeededShopGenerator(seed: seed(for: day, calendar: calendar))
        let themes = weightedPick(themePool, count: themeCount, using: &gen)
        let cards  = weightedPick(cardPool,  count: cardCount,  using: &gen)
        let refreshesAt = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return Rotation(date: day, themes: themes, cards: cards, refreshesAt: refreshesAt)
    }

    // MARK: - Seeding

    // Claude  Date 06/17/2026
    // Turn a calendar day into a stable 64-bit seed. YYYYMMDD (e.g. 20260617) is
    // unique per day and identical on every device; SplitMix64.next() then mixes it
    // so the resulting shop has no visible day-to-day pattern.
    static func seed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = UInt64(c.year  ?? 2026)
        let m = UInt64(c.month ?? 1)
        let d = UInt64(c.day   ?? 1)
        return y &* 10_000 &+ m &* 100 &+ d
    }

    // MARK: - Weighted sampling (without replacement)

    // Claude  Date 06/17/2026
    // Efraimidis–Spirakis weighted reservoir pick: give each item a key of
    // u^(1/weight) with u uniform in (0,1], then keep the largest `count` keys.
    // Items with higher weight tend to score higher, so rare (low-weight) items are
    // selected proportionally less often — that's the rarity. All randomness comes
    // from the passed-in seeded generator, drawn in fixed pool order, so the result
    // is reproducible for a given day.
    private static func weightedPick(_ pool: [ShopItem], count: Int,
                                     using gen: inout SeededShopGenerator) -> [ShopItem] {
        guard count < pool.count else { return pool }
        let keyed = pool.map { item -> (item: ShopItem, key: Double) in
            let u = Double.random(in: 1e-9...1, using: &gen)
            return (item, pow(u, 1.0 / item.weight))
        }
        return keyed.sorted { $0.key > $1.key }.prefix(count).map(\.item)
    }
}

// Claude  Date 06/17/2026
// A tiny deterministic PRNG (SplitMix64) so `random(using:)` produces the same
// sequence for the same seed on every device and OS version — Swift's default
// generator is explicitly non-reproducible, which would break the "same shop for
// everyone" guarantee. Named distinctly from the animated-card file's own private
// SeededGenerator (different algorithm, different purpose). Cosmetic use only.
struct SeededShopGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
