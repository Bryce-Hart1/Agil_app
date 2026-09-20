import Foundation

// CLAUDE  Date 09/19/2026
// One morning on the scale. Identity is the LOCAL calendar day, not a Date: the persistence
// layer encodes ISO-8601 in whole UTC seconds, so a stored start-of-day stops comparing equal
// after a reload or a flight. `loggedAt` is kept for display only. Logging the same day twice
// replaces the entry (see BodyStore.logWeighIn).
struct WeighIn: Identifiable, Codable, Hashable {
    let id: UUID
    /// "yyyy-MM-dd" in the user's calendar — the real key for everything that groups by day.
    var dayKey: String
    var weightLb: Double
    /// Optional body-fat estimate in percent (18.5 = 18.5%). Powers Katch-McArdle and lean mass.
    var bodyFatPct: Double?
    var loggedAt: Date

    init(id: UUID = UUID(), dayKey: String, weightLb: Double,
         bodyFatPct: Double? = nil, loggedAt: Date = Date()) {
        self.id = id
        self.dayKey = dayKey
        self.weightLb = weightLb
        self.bodyFatPct = bodyFatPct
        self.loggedAt = loggedAt
    }

    /// Lean mass in lb, when this weigh-in carried a body-fat estimate.
    var leanMassLb: Double? {
        guard let bodyFatPct, bodyFatPct > 0, bodyFatPct < 100 else { return nil }
        return weightLb * (1 - bodyFatPct / 100)
    }
}

// CLAUDE  Date 09/19/2026
// The local-day key everything in the body feature groups by, and the arithmetic on it.
// Formatting is fixed to the POSIX locale so a user's regional calendar can't change the
// shape of a stored key; the time zone is the CURRENT one on purpose, so "today" means the
// user's today rather than UTC's.
enum DayKey {
    static let format = "yyyy-MM-dd"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = format
        return f
    }()

    static func key(for date: Date = Date()) -> String {
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// Midnight at the start of that local day, or nil for a key that isn't one.
    static func date(from key: String) -> Date? {
        formatter.timeZone = TimeZone.current
        return formatter.date(from: key)
    }

    static func offset(_ key: String, byDays days: Int, calendar: Calendar = .current) -> String? {
        guard let date = date(from: key),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return nil }
        return self.key(for: moved)
    }

    /// Whole days from `start` to `end`, negative when `end` is earlier.
    static func days(from start: String, to end: String, calendar: Calendar = .current) -> Int? {
        guard let a = date(from: start), let b = date(from: end) else { return nil }
        return calendar.dateComponents([.day], from: a, to: b).day
    }

    // CLAUDE  Date 09/19/2026
    // A rolling window of `length` days ending ON `end` (inclusive) — the check-in's unit of
    // comparison. Rolling rather than Monday weeks, so the user's chosen check-in weekday
    // never changes which days are measured.
    static func window(endingOn end: String, length: Int, calendar: Calendar = .current) -> [String] {
        guard length > 0, let endDate = date(from: end) else { return [] }
        return (0..<length).compactMap { back in
            calendar.date(byAdding: .day, value: -(length - 1 - back), to: endDate).map { key(for: $0) }
        }
    }
}

// CLAUDE  Date 09/19/2026
// Averages over a set of days — the whole point of daily weigh-ins. A single morning carries
// several pounds of water and food weight, so nothing in the plan ever reads one weigh-in;
// it reads the average of a window, and refuses to answer when the window is too thin.
enum WeightTrend {

    struct Window {
        let average: Double
        let count: Int
        /// Average body fat across the weigh-ins in the window that carried one.
        let bodyFatPct: Double?
    }

    // CLAUDE  Date 09/19/2026
    // The window's average, or nil when fewer than `minimumCount` days were logged. Returning
    // nil rather than a thin average is deliberate: a check-in built on one weigh-in would
    // chase water weight, so the engine asks for more instead of guessing.
    static func window(_ weighIns: [WeighIn], keys: [String], minimumCount: Int = 1) -> Window? {
        let keySet = Set(keys)
        let inWindow = weighIns.filter { keySet.contains($0.dayKey) }
        guard inWindow.count >= max(1, minimumCount) else { return nil }
        let average = inWindow.reduce(0) { $0 + $1.weightLb } / Double(inWindow.count)
        let fats = inWindow.compactMap(\.bodyFatPct)
        let fat = fats.isEmpty ? nil : fats.reduce(0, +) / Double(fats.count)
        return Window(average: average, count: inWindow.count, bodyFatPct: fat)
    }

    /// The 7-day trend weight ending on `end` — what the Journal card and charts display.
    static func trendWeight(_ weighIns: [WeighIn], endingOn end: String = DayKey.key(),
                            days: Int = 7) -> Double? {
        window(weighIns, keys: DayKey.window(endingOn: end, length: days))?.average
    }

    /// The most recent weigh-in by day, or nil when nothing is logged.
    static func latest(_ weighIns: [WeighIn]) -> WeighIn? {
        weighIns.max { $0.dayKey < $1.dayKey }
    }

    // CLAUDE  Date 09/19/2026
    // The most recent body-fat estimate, which can be much older than the last weigh-in —
    // callers show its date so a months-old number is never passed off as current.
    static func latestBodyFat(_ weighIns: [WeighIn]) -> WeighIn? {
        weighIns.filter { $0.bodyFatPct != nil }.max { $0.dayKey < $1.dayKey }
    }
}
