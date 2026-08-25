import Foundation

// Claude  Date 08/23/2026
// The daily check-in bonus: +20 coins for each distinct day you OPEN Agil, capped at
// 5 days (100 coins) per Mon–Sun week.
//
// WHY THIS ISN'T A WALLET FIELD. The wallet's earned side is deliberately *derived*
// and then held at a high-water mark (Wallet.earnedHighWater ← AppStore.totalCoinsEarned),
// so nothing in the app ever "awards" coins imperatively — achievement rewards already
// work exactly this way. Storing a set of check-in days and folding it into
// totalCoinsEarned preserves that property: the set only ever grows and each week
// contributes min(count, 5) × 20, so the derived total stays MONOTONIC — which is the
// invariant the clamp-free balance in Wallet rests on. A new Wallet term would instead
// have needed a rule in Wallet.merged(with:), a CloudWalletSync change and isSafeMode
// handling — all the money-grade machinery — for coins nobody paid real money for.
//
// Weeks are Monday-anchored (firstWeekday = 2) to match Coins.earned and
// DailyShop.weeklyRotation, so "this week" means the same seven days in the coin
// streak, in the shop rotation and here, in every locale.
enum DailyCheckIn {
    /// Coins for one day's first open.
    static let coinsPerDay = 20
    /// Paying days per week. 5 × 20 = 100, the weekly cap.
    static let daysPerWeek = 5

    // Claude  Date 08/23/2026
    // Transient payload for the toast — built once, on the first open of a new day.
    // `id` is fresh per award so re-showing one restarts its entrance animation.
    struct Award: Identifiable, Equatable {
        let id = UUID()
        let coins: Int
        /// 1...daysPerWeek — which dot lights up.
        let dayInWeek: Int
    }

    // Claude  Date 08/23/2026
    // What the Shop's "This week" strip renders.
    struct WeekProgress: Equatable {
        /// Days checked in this week. CAN exceed `cap`: days 6 and 7 are still recorded
        /// so the strip stays truthful about the week, they just stop paying.
        let claimed: Int
        let cap: Int
        /// Coins banked this week — min(claimed, cap) × coinsPerDay.
        let coins: Int
        /// Next Monday, local midnight. The same boundary the weekly shop flips on.
        let resetsAt: Date

        var isMaxed: Bool { claimed >= cap }
        var maxCoins: Int { cap * coinsPerDay }
    }

    /// Monday-anchored copy of a calendar, shared by every helper below.
    private static func mondayCalendar(_ calendar: Calendar) -> Calendar {
        var cal = calendar
        cal.firstWeekday = 2
        return cal
    }

    /// The Mon–Sun week containing `date`.
    static func mondayWeek(for date: Date, calendar: Calendar = .current) -> DateInterval {
        let cal = mondayCalendar(calendar)
        if let interval = cal.dateInterval(of: .weekOfYear, for: date) { return interval }
        // Defensive only — a week interval always resolves for a Gregorian calendar.
        let start = cal.startOfDay(for: date)
        return DateInterval(start: start, duration: 7 * 24 * 60 * 60)
    }

    // Claude  Date 08/23/2026
    // Where the user sits in the current week. Membership is a half-open [start, end)
    // test rather than DateInterval.contains, which is inclusive of `end` and would
    // count next Monday's midnight in BOTH weeks.
    static func progress(days: Set<Date>, asOf now: Date = .now,
                         calendar: Calendar = .current) -> WeekProgress {
        let week = mondayWeek(for: now, calendar: calendar)
        let claimed = days.filter { $0 >= week.start && $0 < week.end }.count
        return WeekProgress(
            claimed: claimed,
            cap: daysPerWeek,
            coins: min(claimed, daysPerWeek) * coinsPerDay,
            resetsAt: week.end
        )
    }

    // Claude  Date 08/23/2026
    // Lifetime coins earned from check-ins. Buckets days into Monday-anchored weeks and
    // pays min(days, 5) × 20 for each — the same shape as Coins.earned(from:), minus the
    // doubling schedule. Monotonic in `days`, which is precisely what lets this feed the
    // wallet's high-water mark (see the file header).
    static func earned(from days: Set<Date>, calendar: Calendar = .current) -> Int {
        let cal = mondayCalendar(calendar)
        var countPerWeek: [Date: Int] = [:]
        for day in days {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: day)?.start else { continue }
            countPerWeek[weekStart, default: 0] += 1
        }
        return countPerWeek.values.reduce(0) { $0 + min($1, daysPerWeek) * coinsPerDay }
    }
}
