import Foundation
import UserNotifications

// Claude  Date 07/01/2026 last changed: 07/11/2026 by: Claude
// Local notifications for an in-progress workout. Two independent alerts share this
// enum: the "your workout is still running" nudge (below) and, added 07/11/2026,
// the rest-timer-complete alert (see scheduleRestComplete) so rest completion still
// shows a banner + sound when the phone is locked/backgrounded.
//
// The "still running" nudge: when the app leaves the foreground with an unfinished
// workout, we schedule a single local notification for `idleDelay` later; the
// moment the app comes back to the foreground we cancel it. So it only ever fires if the
// user genuinely walked away mid-session and never came back — which is exactly the case
// that used to quietly inflate the workout's elapsed time (see Workout.startedAt).
//
// Stateless on purpose (no stored state to keep in sync): the pending request itself is
// the state, keyed by one stable identifier so scheduling always replaces the previous
// one. UNTimeIntervalNotificationTrigger survives the app being terminated, so this still
// fires if the user force-quits with a workout open.
//
// Local notifications need no Info.plist usage key — just runtime authorization, which we
// ask for when a workout is started (in the foreground, where the prompt has context) —
// that same authorization covers both alerts below.
enum WorkoutNotifications {
    private static let reminderID = "agil.workout.stillRunning"

    /// How long an active workout may sit with the app backgrounded before we nudge.
    static let idleDelay: TimeInterval = 15 * 60

    // Ask once. No-op if the user has already allowed or denied.
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    // Claude  Date 08/13/2026
    // Async pair used by NotificationRequestView, the pre-permission screen that
    // explains what we'd notify about before iOS shows its one-and-only dialog.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Unconditional — the caller is expected to have pre-asked and checked
    /// `authorizationStatus() == .notDetermined` first. Returns false on denial and
    /// on the (harmless) no-op when iOS has already been asked once.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    // Schedule (replacing any pending one). Silently no-ops without permission.
    static func scheduleStillRunningReminder(in seconds: TimeInterval = idleDelay) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: break
            default: return
            }

            let content = UNMutableNotificationContent()
            content.title = "Workout still running"
            content.body = "Your Agil workout is still going. Jump back in, or finish it up."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, seconds), repeats: false)
            let request = UNNotificationRequest(identifier: reminderID,
                                                content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [reminderID])
            center.add(request)
        }
    }

    // Cancel the pending nudge, and clear it from Notification Center if it already fired.
    static func cancelStillRunningReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        center.removeDeliveredNotifications(withIdentifiers: [reminderID])
    }

    // Claude  Date 07/11/2026
    // Rest-timer completion. Same shape as the "still running" nudge above: one
    // stable identifier (scheduling replaces any pending one), reuses the alert+sound
    // authorization already requested when a workout starts. Exists so rest complete
    // still alerts you (banner + sound) when the phone is locked/backgrounded — the
    // in-app haptic/chime in WorkoutSession only fire while the app is running.
    private static let restCompleteID = "agil.workout.restComplete"

    static func scheduleRestComplete(at endDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: break
            default: return
            }

            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "Time to get back to it."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, endDate.timeIntervalSinceNow), repeats: false)
            let request = UNNotificationRequest(identifier: restCompleteID,
                                                content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [restCompleteID])
            center.add(request)
        }
    }

    // Cancel the pending rest-complete alert, and clear it if it already fired — called
    // on skip and on natural completion (the app being open at that moment means the
    // in-app haptic/chime already covered it).
    static func cancelRestComplete() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restCompleteID])
        center.removeDeliveredNotifications(withIdentifiers: [restCompleteID])
    }
}
