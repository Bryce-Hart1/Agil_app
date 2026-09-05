import UIKit

// CLAUDE  Date 09/03/2026
// Puts the equipped theme's icon on the home screen. Called from RootTabView when the
// selection changes and on every foreground, so it also self-heals a user who bought a
// theme on a build that predates themed icons.
//
// Side effect worth knowing: a real icon change makes iOS show its own "You have changed
// the icon for Agil" alert, and there is no public way to suppress it. That's why the
// no-op guard below matters — without it the alert would fire on every launch.
@MainActor
enum AppIconManager {
    /// Equip `theme`'s icon. No-ops when the device doesn't support alternate icons or the
    /// right icon is already set.
    static func apply(_ theme: AppTheme) {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons else { return }

        let target = ThemeIcon.alternateIconName(for: theme)
        guard app.alternateIconName != target else { return }

        app.setAlternateIconName(target) { error in
            // Logged, never surfaced: a failed icon swap is cosmetic, and the most common
            // cause is the app not being active — the next foreground retries it.
            if let error { print("⚠️ app icon → \(target ?? "primary") failed: \(error)") }
        }
    }
}
