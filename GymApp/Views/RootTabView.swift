import SwiftUI

/// The app's top-level tab bar. Each tab is an independent navigation stack.
/// Applies the selected theme's accent tint and light/dark appearance app-wide.
struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    // Claude  Date 06/16/2026
    // The bar leads with a mode switcher (tag 0). Real tabs start at tag 1, so the
    // first content tab is selected on launch and after every mode flip.
    @State private var selection = 1
    // Claude  Date 06/16/2026
    // Which world the bar shows — lifting vs nutrition. Persisted so the app reopens
    // where you left off. Tapping the tag-0 switcher tab flips it (see onChange).
    @AppStorage("appMode") private var modeRaw = AppMode.lifting.rawValue
    private var mode: AppMode { AppMode(rawValue: modeRaw) ?? .lifting }

    // Claude  Date 06/12/2026
    // First-run onboarding shows until the user completes it (enters a name).
    private var showOnboarding: Binding<Bool> {
        Binding(get: { !store.profile.hasOnboarded }, set: { _ in })
    }

    var body: some View {
        TabView(selection: $selection) {
            // Claude  Date 06/16/2026
            // Mode switcher — the leftmost icon. It advertises the OTHER world (fork
            // in Lifting, dumbbell in Nutrition); selecting it flips modes and bounces
            // selection back to tag 1, so its placeholder content never actually shows.
            Color.clear
                .tabItem { Label(mode.switchLabel, systemImage: mode.switchIcon) }
                .tag(0)

            if mode == .lifting {
                WorkoutsListView()
                    .tabItem { Label("Workouts", systemImage: "dumbbell") }
                    .tag(1)

                // Claude  Date 06/16/2026
                // The "Build" hub: workout presets (templates), with the exercise
                // library reachable from its top-left link.
                PresetsListView()
                    .tabItem { Label("Build", systemImage: "plus.square.on.square") }
                    .tag(2)

                ProgressDashboardView()
                    .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
                    .tag(3)

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(4)
            } else {
                // Claude  Date 06/16/2026 Edited 6/16/26 Bryce Hart
                // Nutrition world: per-day food Journal, the food library, and the
                // shared profile. Goals are reached from the Journal's toolbar.
                NutritionJournalView()
                    .tabItem { Label("Journal", systemImage: "fork.knife") }
                    .tag(1)

                FoodLibraryView()
                    .tabItem { Label("Foods", systemImage: "carrot") }
                    .tag(2)

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(3)
            }
        }
        // Claude  Date 06/16/2026
        // Intercept a tap on the switcher tab: flip the world and land on its first
        // real tab instead of staying on the empty placeholder.
        .onChange(of: selection) { newValue in
            guard newValue == 0 else { return }
            modeRaw = mode.toggled.rawValue
            selection = 1
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
