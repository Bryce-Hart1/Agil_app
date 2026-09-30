import Foundation

// CLAUDE  Date 09/30/2026
// Time-of-day rules for the food log: when a meal is usually eaten, what time a new log
// defaults to, and which foods are a meal's "usuals". Pure over [FoodEntry] so the swiftc
// harness can run it; AppStore wraps each function with its own foodLog.
enum MealTiming {
    // How far back "usual" looks, and how many logs make a habit rather than a one-off.
    // Same values as AppStore.TopPicks, kept separate so either can be retuned alone.
    static let historyDays = 21
    static let minLogs = 2
    static let maxUsuals = 3
    // Logging just after a meal's window still reads as "I just ate" (brunch at 11:30,
    // dinner at 22:40), so now stays the default for this long past the window's end.
    static let windowGrace: TimeInterval = 90 * 60

    // Seconds since midnight — the time-of-day coordinate everything here is measured in.
    // (Moved from AppStore, where Top picks still uses it.)
    static func secondsIntoDay(_ date: Date, calendar: Calendar = .current) -> TimeInterval {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = TimeInterval(c.hour ?? 0)
        let minute = TimeInterval(c.minute ?? 0)
        let second = TimeInterval(c.second ?? 0)
        return hour * 3600 + minute * 60 + second
    }

    // Distance between two times of day, THE SHORT WAY ROUND. Without the wrap, a ±3h
    // window at 01:00 would cover 01:00–04:00 only and quietly drop the 22:00–24:00 half
    // of a late-night routine.
    static func clockDistance(_ a: TimeInterval, _ b: TimeInterval) -> TimeInterval {
        let raw = abs(a - b)
        return min(raw, 86_400 - raw)
    }

    // CLAUDE  Date 09/30/2026
    // `day`'s calendar date at a time of day given in seconds. Goes through
    // bySettingHour rather than startOfDay + seconds, which lands an hour off on DST days.
    static func placing(seconds: TimeInterval, on day: Date, calendar: Calendar = .current) -> Date {
        let s = Int(max(0, min(seconds, 86_399)))
        return calendar.date(bySettingHour: s / 3600, minute: (s % 3600) / 60, second: s % 60,
                             of: day) ?? day
    }

    // CLAUDE  Date 09/30/2026
    // The day from `day`, the clock time from `time`. Every time picker edits a full Date,
    // so this is what keeps a picked 7:40 on the diary's selected day.
    static func placing(timeOf time: Date, on day: Date, calendar: Calendar = .current) -> Date {
        placing(seconds: secondsIntoDay(time, calendar: calendar), on: day, calendar: calendar)
    }

    // CLAUDE  Date 09/30/2026
    // When this meal is usually eaten: the median time of day of its recent logs, or the
    // meal's built-in default until there are `minLogs` of them. Median, so one breakfast
    // logged at 8pm under the old stamping rule can't drag the whole habit to evening.
    static func usualSeconds(for meal: MealType, in log: [FoodEntry], asOf now: Date = Date(),
                             calendar: Calendar = .current) -> TimeInterval {
        let start = calendar.date(byAdding: .day, value: -historyDays, to: now) ?? now
        let times = log
            .filter { $0.mealType == meal && $0.loggedAt > start }
            .map { secondsIntoDay($0.loggedAt, calendar: calendar) }
            .sorted()
        guard times.count >= minLogs else { return meal.defaultSeconds }
        let mid = times.count / 2
        return times.count.isMultiple(of: 2) ? (times[mid - 1] + times[mid]) / 2 : times[mid]
    }

    // CLAUDE  Date 09/30/2026
    // The time a new log should get when the user hasn't picked one. Today, in the meal's
    // window (or any time for snacks), that's now. Otherwise it's the meal's usual time on
    // `day`, never later than now, so nothing in the diary sits ahead of the real clock.
    static func suggestedTime(for meal: MealType, on day: Date, now: Date = Date(),
                              log: [FoodEntry], calendar: Calendar = .current) -> Date {
        let isToday = calendar.isDate(day, inSameDayAs: now)
        if isToday && isInWindow(meal, at: now, calendar: calendar) { return now }
        let usual = placing(seconds: usualSeconds(for: meal, in: log, asOf: now, calendar: calendar),
                            on: day, calendar: calendar)
        return isToday ? min(usual, now) : usual
    }

    // CLAUDE  Date 09/30/2026
    // The time actually written for a log: a picked time moved onto `day` (and clamped to
    // now), or the suggestion when nothing was picked. The store's one choke point.
    static func resolvedTime(_ picked: Date?, for meal: MealType, on day: Date, now: Date = Date(),
                             log: [FoodEntry], calendar: Calendar = .current) -> Date {
        guard let picked else {
            return suggestedTime(for: meal, on: day, now: now, log: log, calendar: calendar)
        }
        return min(placing(timeOf: picked, on: day, calendar: calendar), now)
    }

    // Whether "now" counts as eating this meal now: inside its window or just past it.
    // Meals without a window (snack, other) are anytime.
    private static func isInWindow(_ meal: MealType, at date: Date, calendar: Calendar) -> Bool {
        guard let window = meal.window else { return true }
        let seconds = secondsIntoDay(date, calendar: calendar)
        let lower = TimeInterval(window.lowerBound * 3600)
        let upper = TimeInterval(window.upperBound * 3600) + windowGrace
        return seconds >= lower && seconds < upper
    }

    // CLAUDE  Date 09/30/2026
    // The foods this meal usually holds, best first: logged under this meal at least
    // `minLogs` times in the history window, minus `excluding` (already eaten today).
    // Count, then recency, then id, so equal foods never swap places between renders.
    static func usualFoodIDs(for meal: MealType, in log: [FoodEntry], asOf now: Date = Date(),
                             excluding: Set<UUID> = [], limit: Int = maxUsuals,
                             calendar: Calendar = .current) -> [UUID] {
        guard let start = calendar.date(byAdding: .day, value: -historyDays, to: now) else { return [] }
        var counts: [UUID: Int] = [:]
        var latest: [UUID: Date] = [:]
        for entry in log where entry.mealType == meal && entry.loggedAt > start {
            guard let id = entry.foodId, !excluding.contains(id) else { continue }
            counts[id, default: 0] += 1
            if let seen = latest[id], seen >= entry.loggedAt { continue }
            latest[id] = entry.loggedAt
        }
        return counts
            .filter { $0.value >= minLogs }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                let l = latest[lhs.key] ?? .distantPast
                let r = latest[rhs.key] ?? .distantPast
                if l != r { return l > r }
                return lhs.key.uuidString < rhs.key.uuidString
            }
            .prefix(limit)
            .map(\.key)
    }

    // CLAUDE  Date 09/30/2026
    // Split time-ordered entries into runs wherever one of `breaks` (times of day, seconds)
    // falls between two neighbours. The Log uses it so a snack at 3pm and one at 10pm become
    // two chapters on either side of dinner instead of one chapter spanning it.
    static func runs(of entries: [FoodEntry], splitAt breaks: [TimeInterval],
                     calendar: Calendar = .current) -> [[FoodEntry]] {
        var runs: [[FoodEntry]] = []
        for entry in entries {
            let seconds = secondsIntoDay(entry.loggedAt, calendar: calendar)
            if let previous = runs.last?.last {
                let prior = secondsIntoDay(previous.loggedAt, calendar: calendar)
                if !breaks.contains(where: { $0 > prior && $0 <= seconds }) {
                    runs[runs.count - 1].append(entry)
                    continue
                }
            }
            runs.append([entry])
        }
        return runs
    }

    // MARK: - Formatting

    // Whether this device shows a 24-hour clock ("j" resolves to H or HH there). Read once.
    static let localeUses24Hour: Bool =
        !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")

    // CLAUDE  Date 09/30/2026
    // Gutter-width clock time: "7:40a" / "12:05p" on a 12-hour clock, "19:40" on 24-hour.
    // Built by hand because the system's short style ("7:40 AM") doesn't fit the Log's gutter.
    static func compactTime(_ date: Date, uses24Hour: Bool = localeUses24Hour,
                            calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let hour = c.hour ?? 0
        let minute = String(format: "%02d", c.minute ?? 0)
        if uses24Hour { return "\(hour):\(minute)" }
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12):\(minute)\(hour < 12 ? "a" : "p")"
    }

    // CLAUDE  Date 09/30/2026
    // A gap between meals, short: "45m", "4h", "4h 20m". Rounded to the minute.
    static func gapText(_ interval: TimeInterval) -> String {
        let minutes = Int((max(0, interval) / 60).rounded())
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
