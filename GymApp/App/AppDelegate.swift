import UIKit
import UserNotifications

// Claude  Date 09/03/2026
// Exists for exactly one job: be the UNUserNotificationCenter delegate from the instant
// the app launches. The delegate must be set before didFinishLaunching returns or iOS
// drops the tap that COLD-LAUNCHED the app — which is why this can't live in a SwiftUI
// .task, and why the app needs a delegate at all.
//
// Side effect worth knowing: once a delegate exists, foreground presentation becomes
// ours to decide. `willPresent` is deliberately NOT implemented, so notifications
// arriving while the app is open stay silent exactly as they did before.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                        [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Every tap arrives here, cold launch included. The center calls back on a private
    // background queue, so the hand-off to the router hops to the main actor.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            NotificationRouter.shared.handleTap(identifier: identifier)
            completionHandler()
        }
    }
}
