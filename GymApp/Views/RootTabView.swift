import SwiftUI

/// The app's top-level tab bar. Each tab is an independent navigation stack.
/// Applies the selected theme's accent tint and light/dark appearance app-wide.
struct RootTabView: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            WorkoutsListView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
                .tag(0)

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
                .tag(1)

            ExercisesListView()
                .tabItem { Label("Exercises", systemImage: "list.bullet") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(3)
        }
        .tint(theme.current.accent)
        .preferredColorScheme(theme.current.colorScheme)
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
