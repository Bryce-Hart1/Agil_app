import SwiftUI

@main
struct GymAppApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(theme)
        }
    }
}
