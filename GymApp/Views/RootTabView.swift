import SwiftUI

/// The app's top-level tab bar. Each tab is an independent navigation stack.
/// Applies the selected theme's accent tint and light/dark appearance app-wide.
struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    // Claude  Date 06/16/2026
    // Live in-progress-workout state, for the global mini-bar + jump-back navigation.
    @EnvironmentObject private var session: WorkoutSession
    // Claude  Date 06/18/2026
    // Shared-card sync. The single hook point: we nudge it on launch, on foreground,
    // and whenever the profile or earned badges change. It only acts in Friends mode
    // and dedupes/debounces, so calling it freely here is cheap and safe.
    @EnvironmentObject private var cardSync: CardSyncService
    @Environment(\.scenePhase) private var scenePhase
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
        // Claude  Date 06/16/2026
        // Global "now playing"-style bar for an in-progress workout, floating just
        // above the tab bar in every tab/mode. Renders nothing when no workout is
        // active. Applied BEFORE the celebration overlay so badge pop-ups sit on top.
        .overlay(alignment: .bottom) {
            WorkoutMiniBar(onOpen: openActiveWorkout)
                .padding(.bottom, 49)
        }
        // Claude  Date 06/13/2026
        // Achievement-unlock celebration, shown over the whole app. Keyed by id so
        // each queued unlock gets a fresh pop-in animation as you tap through.
        // Claude  Date 06/15/2026
        // Badge celebrations come first; once they drain, any Strategist rank
        // promotion plays — so you watch the badges pop, then get crowned.
        .overlay {
            // Claude  Date 06/16/2026
            // On finishing a workout the performance card shows first; once dismissed,
            // any queued badge celebrations play, then rank promotions.
            if let summary = store.pendingWorkoutSummary {
                PerformanceCardView(
                    summary: summary,
                    style: CardStyle.style(for: store.profile.cardStyleID),
                    onDismiss: { store.dismissWorkoutSummary() }
                )
                .id(summary.id)
                .transition(.opacity)
                .zIndex(2)
            } else if let achievement = store.pendingCelebrations.first {
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
        .animation(.easeInOut(duration: 0.25), value: store.pendingWorkoutSummary?.id)
        .animation(.easeInOut(duration: 0.25), value: store.pendingCelebrations.first?.id)
        .animation(.easeInOut(duration: 0.25), value: store.pendingPromotions.first)
        // Claude  Date 06/18/2026
        // Keep the shared card in sync (Friends mode only). Push on launch + whenever
        // the app returns to the foreground, and react to card-relevant edits: profile
        // (name / style / rank toggle / pinned badges) and the earned-badge set (which
        // drives the equipped rank). Each call no-ops unless in Friends mode + changed.
        .task { cardSync.sync(from: store) }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                cardSync.sync(from: store)
                // Catch the rest timer up to real elapsed time after backgrounding/locking.
                session.refreshRest()
            }
        }
        .onChange(of: store.profile) { _ in cardSync.sync(from: store) }
        .onChange(of: store.unlockedAchievementIDs) { _ in cardSync.sync(from: store) }
    }

    // Claude  Date 06/16/2026
    // Jump back into the active workout from the mini-bar: switch to Lifting mode +
    // the Workouts tab, then hand the id to WorkoutsListView (it pushes the editor).
    private func openActiveWorkout() {
        guard let id = store.activeWorkout?.id else { return }
        if mode != .lifting { modeRaw = AppMode.lifting.rawValue }
        selection = 1
        session.requestedWorkoutID = id
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
        .environmentObject(WorkoutSession())
        .environmentObject(CardSyncService())
}
