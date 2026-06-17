import SwiftUI

@main
struct GymAppApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var theme = ThemeManager()
    // Claude  Date 06/16/2026
    // Live in-progress-workout state (rest timer + mini-bar navigation), shared app-wide.
    @StateObject private var session = WorkoutSession()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(theme)
                .environmentObject(session)
        }
    }
}
