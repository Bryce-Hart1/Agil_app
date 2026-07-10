import Foundation
import UserNotifications

// Claude  Date 07/01/2026
// The "your workout is still running" nudge. When the app leaves the foreground with an
// unfinished workout, we schedule a single local notification for `idleDelay` later; the
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
// ask for when a workout is started (in the foreground, where the prompt has context).
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
}
