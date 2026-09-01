import Foundation
import UserNotifications

// Claude  Date 08/29/2026
// Reminders for the supplement tracker. Same shape as WorkoutNotifications — a stateless
// enum where the pending requests ARE the state — but this is the app's first repeating
// alert, so a few things differ:
//
//  * UNCalendarNotificationTrigger with repeats: true, not UNTimeIntervalNotificationTrigger.
//  * One slot can own up to seven requests (one per weekday), so there is no single stable
//    identifier to replace. Instead every id carries `idPrefix` and resync() rebuilds the
//    whole family: read the pending list, drop everything of ours, add back what the
//    current schedule says. That keeps this correct no matter what changed upstream —
//    a renamed slot, a deleted supplement, a revoked permission — without tracking deltas.
//  * Authorization is NOT requested here. It's reused from WorkoutNotifications (one
//    options: array for the whole app, so the two can't drift), and the slot editor
//    pre-asks with NotificationRequestView before ever getting here.
enum SupplementNotifications {
    /// Every identifier this service owns starts with this. Also how the app delegate
    /// recognises a supplement tap (see GymAppApp).
    static let idPrefix = "agil.supplement."

    static func handles(identifier: String) -> Bool { identifier.hasPrefix(idPrefix) }

    // Claude  Date 08/29/2026
    // Rebuild every pending supplement reminder from the current schedule.
    //
    // Slots and supplements arrive BY VALUE and the requests are built up front, on the
    // caller's thread, before any of the UNUserNotificationCenter callbacks run. That's
    // deliberate: those callbacks fire on a private background queue, and AppStore is
    // @MainActor — reaching back into it from in there would be a cross-actor read that
    // happens to be tolerated today and is a hard error under Swift 6.
    //
    // Silently removes everything and schedules nothing when the tracker is switched off
    // in Settings or when notifications aren't authorized. That second case is why the
    // slot editor has to call this again after permission is granted: a slot created
    // before the prompt was answered would otherwise stay unscheduled forever.
    static func resync(slots: [SupplementSlot], supplements: [Supplement]) {
        let requests = SupplementTracking.isEnabled
            ? buildRequests(slots: slots, supplements: supplements)
            : []
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            let authorized: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: authorized = true
            default: authorized = false
            }

            center.getPendingNotificationRequests { pending in
                let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
                if !ours.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: ours)
                }
                guard authorized else { return }
                for request in requests { center.add(request) }
            }
        }
    }

    /// Drop every supplement reminder — Settings turning the tracker off.
    static func cancelAll() {
        resync(slots: [], supplements: [])
    }

    // MARK: - Building

    private static func buildRequests(slots: [SupplementSlot],
                                      supplements: [Supplement]) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []
        for slot in slots where slot.remindersOn && !slot.weekdays.isEmpty {
            // An empty slot must never buzz: being reminded to take nothing is the fastest
            // way to get the whole feature muted at the OS level.
            let items = supplements.filter { $0.slotId == slot.id }
            guard !items.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            content.title = slot.name
            content.body = body(for: items)
            content.sound = .default

            if slot.weekdays == SupplementSlot.allWeekdays {
                // Every day collapses to ONE daily trigger rather than seven weekly ones.
                // The seeded "Daily" slot is the common case, so this is the difference
                // between 1 and 7 pending requests for most users — and iOS's 64-request
                // ceiling is shared app-wide and evicts oldest-first, which would quietly
                // take out the workout nudge.
                requests.append(request(id: "\(idPrefix)\(slot.id.uuidString).daily",
                                        content: content,
                                        components: components(slot, weekday: nil)))
            } else {
                for weekday in slot.weekdays.sorted() {
                    requests.append(request(id: "\(idPrefix)\(slot.id.uuidString).\(weekday)",
                                            content: content,
                                            components: components(slot, weekday: weekday)))
                }
            }
        }
        return requests
    }

    // Claude  Date 08/29/2026
    // NOTE the components deliberately carry no `timeZone` and no `calendar`. Leaving both
    // nil makes iOS resolve the next fire date against the user's CURRENT calendar every
    // time, which is what keeps "8:00" meaning 8am local after a flight and across a DST
    // change. Pinning a timeZone here would be the wrong thing for a daily habit reminder,
    // and it looks enough like an oversight that it needs saying out loud.
    //
    // One known wrinkle, accepted: on the spring-forward day a time inside the skipped hour
    // (02:00–02:59 in US zones) may shift or be missed for that one occurrence.
    private static func components(_ slot: SupplementSlot, weekday: Int?) -> DateComponents {
        var when = DateComponents()
        when.hour = slot.hour
        when.minute = slot.minute
        when.weekday = weekday
        return when
    }

    private static func request(id: String, content: UNNotificationContent,
                                components: DateComponents) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
    }

    // "Vitamin D and Iron" / "Vitamin D, Iron and 2 more" — the names are the whole point
    // of the banner (a bare "Time for your supplements" makes you open the app to find out
    // what you were meant to take).
    private static func body(for items: [Supplement]) -> String {
        let names = items.map(\.name)
        switch names.count {
        case 1:  return "Time for \(names[0])."
        case 2:  return "Time for \(names[0]) and \(names[1])."
        case 3:  return "Time for \(names[0]), \(names[1]) and \(names[2])."
        default: return "Time for \(names[0]), \(names[1]) and \(names.count - 2) more."
        }
    }
}
