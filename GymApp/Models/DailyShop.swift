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

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // Six featured slots: 4 that turn over daily, 2 that hold for the week. The
    // weekly pair exists because items cost real money to skip toward now — at
    // 3,000 coins a legendary is roughly twelve weeks of training, and a line-up
    // that vanishes at midnight gives nobody time to decide or to save up. The
    // weekly slots are the ones you can actually plan around.
    static let dailyCount  = 4
    static let weeklyCount = 2

    // MARK: - Pool (paid items only — free base items are always available
    // elsewhere, so they don't take up a precious featured slot).

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // ONE mixed pool now, instead of separate theme/card pools with fixed slot
    // counts. Either cadence can surface either kind, so a week can be two themes,
    // two cards, or one of each — which is the point of mixing. Ordering is fixed
    // (themes then cards, each in declaration order) because the weighted pick draws
    // in pool order and determinism depends on that order never wobbling.
    static var pool: [ShopItem] {
        AppTheme.builtIns.filter { $0.price > 0 }.map(ShopItem.theme)
            + CardStyle.all.filter { $0.price > 0 }.map(ShopItem.card)
    }

    // MARK: - Rotation

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // One cadence's line-up plus when it rolls over. `start` is the beginning of the
    // shop period (local midnight, or the start of the shop week); `refreshesAt` is
    // when it flips, which the UI counts down to. Boundaries are local-time, so
    // users in different timezones flip at their own midnight.
    struct Rotation {
        let start: Date
        let items: [ShopItem]
        let refreshesAt: Date
    }

    /// Both cadences, computed together so they can't offer the same item at once.
    struct Lineup {
        let daily: Rotation
        let weekly: Rotation
    }

    // Claude  Date 08/03/2026
    // The whole shop for a moment in time.
    //
    // Order matters: the WEEKLY pair is drawn first, then the daily four are drawn
    // from the pool minus that pair. If it were the other way round the weekly slots
    // would churn every day (as the daily exclusion shifted under them), which is the
    // one thing a weekly slot must not do. As a consequence the daily line-up does
    // change when the week flips even mid-week — that's correct: the pool it draws
    // from genuinely changed.
    static func lineup(for date: Date = .now, calendar: Calendar = .current) -> Lineup {
        let weekly = weeklyRotation(for: date, calendar: calendar)

        let day = calendar.startOfDay(for: date)
        var gen = SeededShopGenerator(seed: daySeed(for: day, calendar: calendar))
        let remaining = pool.filter { item in !weekly.items.contains(where: { $0.id == item.id }) }
        let dailyItems = weightedPick(remaining, count: dailyCount, using: &gen)
        let dailyRefresh = calendar.date(byAdding: .day, value: 1, to: day) ?? day

        return Lineup(
            daily: Rotation(start: day, items: dailyItems, refreshesAt: dailyRefresh),
            weekly: weekly
        )
    }

    // Claude  Date 08/03/2026
    // The weekly pair. Weeks are Monday-anchored to match the coin-earning week in
    // Coins.earned (which also forces firstWeekday = 2), so "this week's shop" and
    // "this week's coin streak" mean the same seven days everywhere.
    private static func weeklyRotation(for date: Date, calendar: Calendar) -> Rotation {
        var cal = calendar
        cal.firstWeekday = 2 // Monday, same as Coins.earned
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        // A generator of its own — sharing one with the daily pick would make the
        // weekly result depend on which day you asked.
        var gen = SeededShopGenerator(seed: weekSeed(for: date, calendar: cal))
        let items = weightedPick(pool, count: weeklyCount, using: &gen)
        let refreshesAt = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        return Rotation(start: start, items: items, refreshesAt: refreshesAt)
    }

    // MARK: - Seeding

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // Turn a calendar day into a stable 64-bit seed. YYYYMMDD (e.g. 20260617) is
    // unique per day and identical on every device; SplitMix64.next() then mixes it
    // so the resulting shop has no visible day-to-day pattern.
    static func daySeed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = UInt64(c.year  ?? 2026)
        let m = UInt64(c.month ?? 1)
        let d = UInt64(c.day   ?? 1)
        return y &* 10_000 &+ m &* 100 &+ d
    }

    // Claude  Date 08/03/2026
    // The weekly twin. Two details that are easy to get wrong:
    //
    //   - `.yearForWeekOfYear`, NOT `.year`. They disagree in the days either side of
    //     New Year (Dec 31 2026 can belong to week 1 of 2027), and using `.year`
    //     there would make the shop flip mid-week.
    //   - The XOR constant domain-separates this stream from the daily one, so a
    //     week seed can never collide with some day's seed and hand out the same
    //     line-up twice.
    static func weekSeed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let y = UInt64(c.yearForWeekOfYear ?? 2026)
        let w = UInt64(c.weekOfYear ?? 1)
        return (y &* 100 &+ w) ^ 0x5745_454B_5F41_4749  // "WEEK_AGI"
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
