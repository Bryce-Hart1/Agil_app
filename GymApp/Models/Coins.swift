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

    // Claude  Date 06/13/2026
    // Coins granted by unlocked achievements = Σ of their tier rewards. Driven by
    // the persisted unlocked set (AppStore.unlockedAchievementIDs) so, like the
    // achievements themselves, these coins stick once earned.
    static func earnedFromAchievements(unlockedIDs: Set<String>) -> Int {
        Achievement.all
            .filter { unlockedIDs.contains($0.id) }
            .reduce(0) { $0 + $1.reward }
    }
}
