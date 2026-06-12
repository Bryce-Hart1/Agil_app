import SwiftUI

/// The app's top-level tab bar. Each tab is an independent navigation stack.
/// Applies the selected theme's accent tint and light/dark appearance app-wide.
struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var selection = 0

    // Claude  Date 06/12/2026
    // First-run onboarding shows until the user completes it (enters a name).
    private var showOnboarding: Binding<Bool> {
        Binding(get: { !store.profile.hasOnboarded }, set: { _ in })
    }

    var body: some View {
        TabView(selection: $selection) {
            WorkoutsListView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
                .tag(0)

            PresetsListView()
                .tabItem { Label("Presets", systemImage: "square.stack") }
                .tag(1)

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
                .tag(2)

            ExercisesListView()
                .tabItem { Label("Exercises", systemImage: "list.bullet") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .tint(theme.current.accent)
        .preferredColorScheme(theme.current.preferredColorScheme)
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView()
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
