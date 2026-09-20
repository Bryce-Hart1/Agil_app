import Foundation
import UserNotifications

// CLAUDE  Date 09/19/2026
// The weekly check-in reminder. Built like SupplementNotifications — one id prefix, a resync
// that clears its own pending requests first — but schedules a ONE-SHOT rather than a repeat:
// a repeating weekly trigger can't skip a phase's two-week warm-up, and would keep firing
// after a check-in was already done.
enum BodyCheckInNotifications {

    private static let idPrefix = "agil.bodycheckin."
    private static let requestID = idPrefix + "next"

    static func handles(identifier: String) -> Bool {
        identifier.hasPrefix(idPrefix)
    }

    // CLAUDE  Date 09/19/2026
    // Call after anything that moves the next due date: starting a plan, changing phase,
    // finishing a check-in, or toggling the reminder. Side effect: always clears the pending
    // request first, so no plan change can leave a stale reminder behind.
    static func resync(plan: BodyPlan?, hour: Int = 8) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])

        guard let plan, plan.remindersOn, let request = buildRequest(plan: plan, hour: hour) else {
            return
        }
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                center.add(request)
            default:
                return
            }
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [requestID])
    }

    // CLAUDE  Date 09/19/2026
    // Fires on the user's chosen weekday on or after the date the check-in actually becomes
    // due. The copy carries NO numbers — a lock screen is a public place, and someone's weight
    // is nobody else's business.
    private static func buildRequest(plan: BodyPlan, hour: Int) -> UNNotificationRequest? {
        guard let fireDate = nextFireDate(plan: plan, hour: hour) else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Weekly check-in"
        content.body = "Step on the scale and see how your week went."
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
    }

    /// The first instance of the plan's check-in weekday on or after the due date.
    static func nextFireDate(plan: BodyPlan, hour: Int = 8,
                             calendar: Calendar = .current, now: Date = Date()) -> Date? {
        guard let dueKey = BodyCheckInEngine.nextDueDayKey(plan: plan),
              let dueDate = DayKey.date(from: dueKey) else { return nil }
        let start = max(dueDate, calendar.startOfDay(for: now))

        for offset in 0..<7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            guard calendar.component(.weekday, from: candidate) == plan.checkInWeekday else { continue }
            guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: candidate),
                  fire > now else { continue }
            return fire
        }
        // The weekday has already gone by this week: take it next week.
        return calendar.date(byAdding: .day, value: 7, to: start)
    }
}
