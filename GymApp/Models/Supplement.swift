import Foundation

// Claude  Date 08/29/2026
// The supplement tracker's model layer. Shaped after WaterEntry.swift, which solves
// the same problem: a user-defined list of things (WaterPreset), a dated log of what
// actually happened (WaterEntry), and a Settings toggle for whether the journal shows
// any of it (WaterTracking).
//
// The one structural difference is SLOTS. Water is a single running total, but people
// split supplements across the day — creatine post-workout, magnesium at night — so a
// supplement belongs to a named slot, and the slot owns the reminder time and the days
// of the week it applies to. Those weekdays do double duty on purpose: they decide when
// the slot notifies AND which days its supplements count as due. One "Daily" slot ships
// seeded, so a user who takes everything at once never meets the grouping UI.

// Claude  Date 08/29/2026
// One thing the user takes. `dose` is deliberately free text rather than a number+unit:
// supplements are labelled in scoops, caps, IU, mg and drops, and the app has nothing to
// compute from it — it's a reminder to the user, not data. (Micros.swift owns the real
// nutrient vocabulary if supplements ever need to contribute to macros.)
struct Supplement: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var dose: String?
    // Claude  Date 08/29/2026
    // NON-optional on purpose. An optional slot would let a supplement exist with no
    // weekday set at all — never due, so never on the checklist, while still counting
    // against maxCount. There is always at least one slot (see deleteSlot in AppStore:
    // the last one can't be removed, and a deleted slot's supplements are reassigned).
    var slotId: UUID
    // Manual order within a slot, so the checklist reads in the order the user takes them.
    var sortIndex: Int

    // Long enough for "Magnesium Glycinate", short enough to stay on one line.
    static let maxNameLength = 24
    static let maxDoseLength = 12
    // A cap keeps the journal card from swallowing the screen above Summary, and keeps
    // the pending-notification count bounded (see SupplementNotifications).
    static let maxCount = 12

    init(id: UUID = UUID(), name: String, dose: String? = nil,
         slotId: UUID, sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.dose = dose
        self.slotId = slotId
        self.sortIndex = sortIndex
    }
}

// Claude  Date 08/29/2026
// A named time of day that a group of supplements belongs to ("Morning", "Post-workout",
// "Bedtime"), plus the reminder schedule for it.
//
// `weekdays` uses Calendar's numbering — 1 = Sunday … 7 = Saturday. That numbering is
// FIXED and independent of Calendar.firstWeekday, which only moves where a week starts;
// display order is a separate concern (see displayOrder below).
//
// Time is stored as hour+minute rather than a Date because there is no date involved —
// it's a wall-clock time that must keep meaning 8am after the user flies somewhere else.
// UNCalendarNotificationTrigger wants exactly these two components (see
// SupplementNotifications.resync, which deliberately leaves the trigger's timeZone nil).
struct SupplementSlot: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var hour: Int
    var minute: Int
    var weekdays: Set<Int>
    var remindersOn: Bool

    static let maxNameLength = 16
    // Four is plenty for morning/midday/post-workout/bedtime, and it bounds the pending
    // notification count at 4 x 7 = 28 against iOS's shared 64-request ceiling.
    static let maxCount = 4

    static let allWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    init(id: UUID = UUID(), name: String, hour: Int = 8, minute: Int = 0,
         weekdays: Set<Int> = allWeekdays, remindersOn: Bool = false) {
        self.id = id
        self.name = name
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.remindersOn = remindersOn
    }

    // What ships before the user makes any of their own: one everyday slot, no reminder.
    // Someone who takes everything at once never has to think about slots at all.
    static let defaults: [SupplementSlot] = [
        SupplementSlot(name: "Daily")
    ]

    /// Whether this slot's supplements are due on `date`.
    func isDue(on date: Date, calendar: Calendar = .current) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }

    // Claude  Date 08/29/2026
    // Weekday numbers in the order the user's week reads — Sun-first in the US, Mon-first
    // in most of Europe. The single source of truth for display order, shared by
    // WeekdayPicker and daysLabel below, because getting this rotation subtly wrong in two
    // places is exactly how a day picker ends up off by one.
    static func displayOrder(calendar: Calendar = .current) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    /// One-letter labels for `displayOrder`, e.g. ["S", "M", "T", "W", "T", "F", "S"].
    static func initials(calendar: Calendar = .current) -> [String] {
        // veryShortWeekdaySymbols is indexed 0 = Sunday regardless of firstWeekday.
        displayOrder(calendar: calendar).map { calendar.veryShortWeekdaySymbols[$0 - 1] }
    }

    /// "8:00 AM", in the user's locale and 12/24-hour preference.
    var timeLabel: String {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// "Every day" / "Weekdays" / "Weekends" / "Mon, Wed, Fri" — never a raw set.
    var daysLabel: String {
        let calendar = Calendar.current
        if weekdays == Self.allWeekdays { return "Every day" }
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        if weekdays.isEmpty { return "No days" }
        return Self.displayOrder(calendar: calendar)
            .filter { weekdays.contains($0) }
            .map { calendar.shortWeekdaySymbols[$0 - 1] }
            .joined(separator: ", ")
    }
}

// Claude  Date 08/29/2026
// One supplement taken, once. The calendar day of `takenAt` IS the day it counts for,
// mirroring FoodEntry and WaterEntry — no separate day key is stored anywhere in this app.
//
// Unlike food and water, these are never backdated: AppStore.setSupplement writes only for
// today. That's what keeps clearedSupplementDays a real-time ledger rather than a number
// the user can type in, which is what the achievement ladder is scored against.
struct SupplementEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var supplementId: UUID
    var takenAt: Date

    init(id: UUID = UUID(), supplementId: UUID, takenAt: Date = Date()) {
        self.id = id
        self.supplementId = supplementId
        self.takenAt = takenAt
    }
}

// Claude  Date 08/29/2026
// Whether the journal and Settings surface the supplement tracker at all. Defaults ON,
// like water — but unlike water, the journal card only draws once at least one supplement
// exists, so someone who takes none never sees furniture above their Summary. Turning this
// off HIDES the tracker and cancels its reminders; nothing logged is deleted, so turning it
// back on restores the stack and the history.
enum SupplementTracking {
    static let storageKey = "trackSupplements"
    static let defaultValue = true

    // Claude  Date 08/29/2026
    // For the non-View code that has to agree with the setting (AppStore's cleared-day
    // guard, SupplementNotifications.resync). Reads through object(forKey:) because
    // bool(forKey:) reports false for a key that was never written, which would read as
    // "off" for every user who has never opened Settings — same reason as WaterTracking.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: storageKey) as? Bool ?? defaultValue
    }

    // The journal card's zero-supplement invite is dismissible and never comes back.
    // Plain @AppStorage rather than a NutritionSetup field: that struct's synthesized
    // Codable throws on a missing key, and PersistenceService.load silently RESETS a file
    // it can't decode — adding a field there would wipe existing users' whole profile.
    static let inviteDismissedKey = "supplementsInviteDismissed"
}

// CLAUDE  Date 09/24/2026
// The optional follow-up: one more nudge a day, at a chosen time, only if something due is
// still unchecked. OFF by default since it's an extra alert. UserDefaults for the same reason
// as SupplementTracking; the time is minutes after midnight, so one key holds it.
enum SupplementFollowUp {
    static let enabledKey = "supplementFollowUpOn"
    static let timeKey = "supplementFollowUpMinutes"
    static let defaultMinutes = 20 * 60 // 8:00 PM

    // bool(forKey:) is safe here: a never-written key reads false, which IS the default.
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static var minutes: Int {
        let stored = UserDefaults.standard.object(forKey: timeKey) as? Int ?? defaultMinutes
        return (0..<24 * 60).contains(stored) ? stored : defaultMinutes
    }
}
