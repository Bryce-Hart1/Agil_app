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

            // Claude  Date 06/16/2026
            // The "Build" hub: workout presets (templates), with the exercise library
            // reachable from its top-left link. Exercises is no longer its own tab —
            // that frees the 5th slot for a future nutrition/calories tab.
            PresetsListView()
                .tabItem { Label("Build", systemImage: "plus.square.on.square") }
                .tag(1)

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
                .tag(2)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(theme.current.accent)
        .preferredColorScheme(theme.current.preferredColorScheme)
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView()
        }
        // Claude  Date 06/13/2026
        // Achievement-unlock celebration, shown over the whole app. Keyed by id so
        // each queued unlock gets a fresh pop-in animation as you tap through.
        // Claude  Date 06/15/2026
        // Badge celebrations come first; once they drain, any Strategist rank
        // promotion plays — so you watch the badges pop, then get crowned.
        .overlay {
            if let achievement = store.pendingCelebrations.first {
                CelebrationOverlay(
                    achievement: achievement,
                    remaining: store.pendingCelebrations.count - 1,
                    onDismiss: { store.dismissCurrentCelebration() }
                )
                .id(achievement.id)
                .transition(.opacity)
                .zIndex(1)
            } else if let rank = store.pendingPromotions.first {
                RankPromotionOverlay(
                    rank: rank,
                    remaining: store.pendingPromotions.count - 1,
                    onDismiss: { store.dismissCurrentPromotion() }
                )
                .id(rank)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.pendingCelebrations.first?.id)
        .animation(.easeInOut(duration: 0.25), value: store.pendingPromotions.first)
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
