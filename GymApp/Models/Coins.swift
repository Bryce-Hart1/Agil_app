import Foundation

// Claude  Date 06/13/2026 last edit Bryce Hart 6/13/26
// The coin (points) economy. Coins are *derived* from workout history rather
// than stored as a mutable balance: lifetime earned is a pure function of the
// dates you trained, so it can never double-count and survives editing or
// deleting workouts. The spendable balance is this earned total minus whatever
// has been spent (see ThemeManager.coinsSpent). Local-only for now, but eventually 
// the coin purchases will be sent to the database.
//
// Earning rule (from new_ideas.md): within each Mon–Sun week, every *distinct*
// day you train awards coins on a doubling-then-capped schedule. The doubling
// "resets" each week (it restarts at 10 the following Monday); earned coins
// themselves accumulate forever.
//
//   day in week:  1    2    3    4    5+
//   coins:        10   20   40   80   100
enum Coins {
    /// Coins awarded for the Nth (1-based) distinct training day within a week.
    /// Doubles 10→20→40→80, then caps at 100 for every further day.
    static func coins(forDayIndex index: Int) -> Int {
        switch index {
        case ..<1: return 0
        case 1: return 10
        case 2: return 20
        case 3: return 40
        case 4: return 80
        default: return 100
        }
    }

    /// Lifetime coins earned from a set of workouts. Groups distinct training
    /// days into Monday-anchored weeks (so the week "resets" Sunday night
    /// regardless of the device's locale first-weekday) and sums the schedule.
    static func earned(from workouts: [Workout], calendar: Calendar = .current) -> Int {
        var cal = calendar
        cal.firstWeekday = 2 // Monday — makes weeks run Mon–Sun everywhere.

        // Collapse to distinct calendar days, then count days per week.
        let trainingDays = Set(workouts.map { cal.startOfDay(for: $0.date) })
        var daysPerWeek: [Date: Int] = [:]
        for day in trainingDays {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: day)?.start else { continue }
            daysPerWeek[weekStart, default: 0] += 1
        }

        var total = 0
        for count in daysPerWeek.values where count > 0 {
            for dayIndex in 1...count {
                total += coins(forDayIndex: dayIndex)
            }
        }
        return total
    }

    // Claude  Date 06/13/2026 last changed: 07/14/2026 by: Claude
    // Coins granted by unlocked achievements = Σ of their tier rewards. Driven by
    // the persisted unlocked set (AppStore.unlockedAchievementIDs) so, like the
    // achievements themselves, these coins stick once earned.
    // (Deliberately stays on Achievement.all rather than the gender-calibrated
    // catalog: it reads only id + tier reward, which are identical in every variant.)
    static func earnedFromAchievements(unlockedIDs: Set<String>) -> Int {
        Achievement.all
            .filter { unlockedIDs.contains($0.id) }
            .reduce(0) { $0 + $1.reward }
    }

    // Claude  Date 08/23/2026
    // Compact balance string for width-constrained chrome — at most FOUR characters, so
    // the ModeNotch pill can carry the balance without its width depending on how rich
    // you are. "25", "300", "3.5k", "999k", "1.2m".
    //
    // Truncates, never rounds up. That matters because this is money: showing "4k" for a
    // balance of 3,999 in a shop where something costs 4,000 is a lie the user finds out
    // about at the worst possible moment. Floor can only ever understate.
    //
    // Full, grouped numbers (`.formatted()`) stay everywhere there's room for them — the
    // Shop's own chip, the Profile Shop row, CoinShopView — so this is the exception, not
    // the house style.
    static func compact(_ amount: Int) -> String {
        let value = max(0, amount)
        switch value {
        case ..<1_000:
            return "\(value)"                                  // 0…999
        case ..<10_000:
            return abbreviated(value, per: 1_000, unit: "k")    // 1k…9.9k
        case ..<1_000_000:
            return "\(value / 1_000)k"                          // 10k…999k
        case ..<10_000_000:
            return abbreviated(value, per: 1_000_000, unit: "m") // 1m…9.9m
        default:
            return "\(value / 1_000_000)m"                      // 10m+
        }
    }

    /// One-decimal abbreviation with the trailing ".0" dropped, floored at the tenth.
    private static func abbreviated(_ value: Int, per unit: Int, unit suffix: String) -> String {
        let tenths = value / (unit / 10)
        let whole = tenths / 10
        let frac = tenths % 10
        return frac == 0 ? "\(whole)\(suffix)" : "\(whole).\(frac)\(suffix)"
    }

    // Claude  Date 08/23/2026
    // The third earning rule lives in its own file: DailyCheckIn.earned(from:) pays
    // +20 for each distinct day the app was opened, capped at 5 days a week. It's
    // separate because it carries a whole feature's day/week model (the toast award and
    // the Shop's week strip) rather than just a sum, but it plugs into exactly the same
    // place — AppStore.totalCoinsEarned — and obeys the same monotonicity rule as the
    // two above. See DailyCheckIn.swift.
}
