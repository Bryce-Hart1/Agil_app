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
    // CLAUDE  Date 09/24/2026
    // `takenToday` feeds the follow-up (see buildFollowUps), so AppStore now resyncs on every
    // check-off too. Side effect: rapid taps can overlap, so only the newest call applies.
    static func resync(slots: [SupplementSlot], supplements: [Supplement],
                       takenToday: Set<UUID> = [], now: Date = Date()) {
        let calendar = Calendar.current
        var requests: [UNNotificationRequest] = []
        if SupplementTracking.isEnabled {
            requests = buildRequests(slots: slots, supplements: supplements)
                + buildFollowUps(slots: slots, supplements: supplements,
                                 takenToday: takenToday, now: now, calendar: calendar)
        }
        let staleDelivered = staleFollowUpIDs(slots: slots, supplements: supplements,
                                              takenToday: takenToday, now: now,
                                              calendar: calendar)
        let generation = generationLock.withLock {
            latestGeneration += 1
            return latestGeneration
        }
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            let authorized: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: authorized = true
            default: authorized = false
            }

            center.getPendingNotificationRequests { pending in
                // CLAUDE  Date 09/24/2026
                // These callbacks land on a background queue with no ordering promise, so an
                // older resync finishing last could re-add a follow-up the user has since
                // cleared. The generation check drops any pass that's been superseded.
                generationLock.withLock {
                    guard generation == latestGeneration else { return }
                    let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
                    if !ours.isEmpty {
                        center.removePendingNotificationRequests(withIdentifiers: ours)
                    }
                    center.removeDeliveredNotifications(withIdentifiers: staleDelivered)
                    guard authorized else { return }
                    for request in requests { center.add(request) }
                }
            }
        }
    }

    private static let generationLock = NSLock()
    private static var latestGeneration = 0 // guarded by generationLock

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
                                components: DateComponents,
                                repeats: Bool = true) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats))
    }

    // "Vitamin D and Iron" / "Vitamin D, Iron and 2 more" — the names are the whole point
    // of the banner (a bare "Time for your supplements" makes you open the app to find out
    // what you were meant to take).
    private static func body(for items: [Supplement]) -> String {
        "Time for \(nameList(items))."
    }

    private static func nameList(_ items: [Supplement]) -> String {
        let names = items.map(\.name)
        switch names.count {
        case 0:  return ""
        case 1:  return names[0]
        case 2:  return "\(names[0]) and \(names[1])"
        case 3:  return "\(names[0]), \(names[1]) and \(names[2])"
        default: return "\(names[0]), \(names[1]) and \(names.count - 2) more"
        }
    }

    // MARK: - Follow-up

    // CLAUDE  Date 09/24/2026
    // How many days of follow-ups are queued ahead. One-shots rather than a repeating trigger,
    // because today's must be cancellable on its own once the stack is cleared. A week keeps
    // them firing between app opens, and 7 + the slots' 28 stays well under iOS's 64 cap.
    static let followUpWindowDays = 7

    private static let followUpPrefix = idPrefix + "followup."

    private static func followUpID(for day: Date) -> String {
        followUpPrefix + DayKey.key(for: day)
    }

    // CLAUDE  Date 09/24/2026
    // One follow-up per day in the window, for days that still have something outstanding at
    // the follow-up time. Today's lists only what's unchecked, and AppStore resyncs on every
    // check-off, so clearing the stack removes it. Future days list everything due.
    private static func buildFollowUps(slots: [SupplementSlot], supplements: [Supplement],
                                       takenToday: Set<UUID>, now: Date,
                                       calendar: Calendar) -> [UNNotificationRequest] {
        guard SupplementFollowUp.isEnabled else { return [] }
        let minutes = SupplementFollowUp.minutes
        let today = calendar.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        for offset in 0..<followUpWindowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                           second: 0, of: day),
                  fire > now else { continue }
            let left = followUpItems(slots: slots, supplements: supplements, on: day,
                                     minutes: minutes, calendar: calendar)
                .filter { offset > 0 || !takenToday.contains($0.id) }
            guard !left.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Supplements left today"
            content.body = "You haven't checked off \(nameList(left)) yet."
            content.sound = .default

            // Floating wall-clock time, no timeZone — same reasoning as components(_:weekday:).
            var when = calendar.dateComponents([.year, .month, .day], from: day)
            when.hour = minutes / 60
            when.minute = minutes % 60
            requests.append(request(id: followUpID(for: day), content: content,
                                    components: when, repeats: false))
        }
        return requests
    }

    // CLAUDE  Date 09/24/2026
    // What a follow-up on `day` covers: that day's due supplements, minus any slot whose own
    // reminder is at or after the follow-up time — an 8 PM nudge mustn't nag about a 10 PM
    // bedtime group. Slots with reminders off have no real time set, so they always count.
    private static func followUpItems(slots: [SupplementSlot], supplements: [Supplement],
                                      on day: Date, minutes: Int,
                                      calendar: Calendar) -> [Supplement] {
        let counted = slots.filter { slot in
            slot.isDue(on: day, calendar: calendar)
                && !(slot.remindersOn && slot.hour * 60 + slot.minute >= minutes)
        }
        return counted.flatMap { slot in
            supplements.filter { $0.slotId == slot.id }.sorted { $0.sortIndex < $1.sortIndex }
        }
    }

    // CLAUDE  Date 09/24/2026
    // Follow-ups already sitting in Notification Center that no longer apply: every earlier
    // day's (check-offs are today-only), plus today's once nothing it covers is left. Keeps
    // a "you haven't taken X" banner from outliving the moment you took X.
    private static func staleFollowUpIDs(slots: [SupplementSlot], supplements: [Supplement],
                                         takenToday: Set<UUID>, now: Date,
                                         calendar: Calendar) -> [String] {
        let today = calendar.startOfDay(for: now)
        var ids = (1...followUpWindowDays).compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: today).map(followUpID(for:))
        }
        let stillLeft = SupplementTracking.isEnabled && SupplementFollowUp.isEnabled
            && followUpItems(slots: slots, supplements: supplements, on: today,
                             minutes: SupplementFollowUp.minutes, calendar: calendar)
                .contains { !takenToday.contains($0.id) }
        if !stillLeft { ids.append(followUpID(for: today)) }
        return ids
    }
}
