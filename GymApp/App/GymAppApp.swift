import SwiftUI

@main
struct GymAppApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var theme = ThemeManager()
    // Claude  Date 06/16/2026
    // Live in-progress-workout state (rest timer + mini-bar navigation), shared app-wide.
    @StateObject private var session = WorkoutSession()
    // Claude  Date 06/18/2026
    // Shared profile-card sync (Friends mode). Owns the device identity + push/fetch;
    // no-ops entirely while the user is Offline. See CardSyncService.
    @StateObject private var cardSync = CardSyncService()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(theme)
                .environmentObject(session)
                .environmentObject(cardSync)
        }
    }
}
