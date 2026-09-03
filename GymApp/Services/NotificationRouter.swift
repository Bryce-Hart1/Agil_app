import Foundation
import UserNotifications

// Claude  Date 09/03/2026
// Where a tapped notification should take you. The app had no UNUserNotificationCenter
// delegate at all, so every alert — the supplement reminder included — simply reopened
// whatever tab the app was last left on. This is the single place that turns a
// notification identifier into a destination; RootTabView does the actual navigating.
//
// A published one-shot rather than a callback, because the tap can land BEFORE any
// SwiftUI view exists (a cold launch straight from the banner). @Published hands its
// current value to each new subscriber, so a route set during didFinishLaunching still
// reaches RootTabView when it finally appears. RootTabView clears it once it has acted.
@MainActor
final class NotificationRouter: ObservableObject {
    enum Route: Equatable {
        /// The supplement checklist — i.e. the Journal, where the day gets checked off.
        case supplements
    }

    /// A singleton because AppDelegate has no way to reach the SwiftUI environment.
    static let shared = NotificationRouter()

    @Published var route: Route?

    // Unrecognised identifiers route nowhere on purpose: the workout nudge and the
    // rest-timer alert are both about the screen you were already on, so hijacking the
    // user's place in the app for those would be worse than doing nothing.
    func handleTap(identifier: String) {
        if SupplementNotifications.handles(identifier: identifier) {
            route = .supplements
        }
    }
}
