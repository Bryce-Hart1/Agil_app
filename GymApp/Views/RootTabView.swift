import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    // Claude  Date 06/16/2026 last changed: 07/13/2026 by: Claude
    // Selected tab. Tabs are tagged from 1 (the old tag-0 switcher placeholder is
    // gone — the ModeNotch pill at the top switches worlds now).
    @State private var selection = 1
    // Claude  Date 06/16/2026 last changed: 07/13/2026 by: Claude
    // Which world the bar shows — lifting vs nutrition. Persisted so the app reopens
    // where you left off. Flipped by switchMode(to:), driven by the ModeNotch pill.
    @AppStorage("appMode") private var modeRaw = AppMode.lifting.rawValue
    private var mode: AppMode { AppMode(rawValue: modeRaw) ?? .lifting }
    // Claude  Date 07/13/2026
    // Each world remembers its last-selected tab across switches (and relaunches).
    @AppStorage("liftingTab") private var liftingTab = 1
    @AppStorage("nutritionTab") private var nutritionTab = 1

    // Claude  Date 06/12/2026
    // First-run onboarding shows until the user completes it (enters a name).
    private var showOnboarding: Binding<Bool> {
        Binding(get: { !store.profile.hasOnboarded }, set: { _ in })
    }

    var body: some View {
        TabView(selection: $selection) {
            // Claude  Date 07/16/2026
            // Every tab hosts the workout mini-bar as a bottom safe-area inset
            // (.workoutMiniBar) instead of the old TabView-wide floating overlay.
            // The overlay painted the bar on top of each page, so the last ~55pt
            // of every scroll view was hidden underneath it and untappable while
            // a workout was active (e.g. the Settings row at the bottom of
            // Profile). The inset keeps the bar just above the tab bar but lets
            // scroll content end above it; it collapses when no bar is shown.
            if mode == .lifting {
                WorkoutsListView()
                    .workoutMiniBar(onOpen: openActiveWorkout)
                    .tabItem { Label("Workouts", systemImage: "dumbbell") }
                    .tag(1)

                // Claude  Date 06/16/2026 last changed: 07/13/2026 by: Claude
                // The "Build" hub: workout presets (templates), with the exercise
                // library reachable from its top-left link. (Icon: custom template
                // asset "hammer" via Label(_:image:), replacing plus.square.on.square.)
                PresetsListView()
                    .workoutMiniBar(onOpen: openActiveWorkout)
                    .tabItem { Label("Build", image: "hammer") }
                    .tag(2)

                // Claude  Date 07/13/2026
                // Icon: custom template asset "chart-scatter" (was chart.bar.xaxis).
                ProgressDashboardView()
                    .workoutMiniBar(onOpen: openActiveWorkout)
                    .tabItem { Label("Progress", image: "chart-scatter") }
                    .tag(3)

                // Claude  Date 07/13/2026
                // Icon: custom template asset "user-circle-dashed" (was
                // person.crop.circle). Shared by both worlds' Profile tab.
                ProfileView()
                    .workoutMiniBar(onOpen: openActiveWorkout)
                    .tabItem { Label("Profile", image: "user-circle-dashed") }
                    .tag(4)
            } else {
                // Claude  Date 06/16/2026 Edited 6/16/26 Bryce Hart last changed: 07/13/2026 by: Claude
                // Nutrition world: per-day food Journal, the food library, and the
                // shared profile. Goals are reached from the Journal's toolbar.
                // (Icons: custom template assets "notepad"/"orange", replacing
                // fork.knife/carrot.)
                NutritionJournalView()
                    .workoutMiniBar(onOpen: openActiveWorkout)
                    .tabItem { Label("Journal", image: "notepad") }
                    .tag(1)

                FoodLibraryView()
                    .workoutMiniBar(onOpen: openActiveWorkout)
                    .tabItem { Label("Foods", image: "orange") }
                    .tag(2)

                // Claude  Date 07/13/2026
                // Icon: custom template asset "user-circle-dashed" (was
                // person.crop.circle). Shared by both worlds' Profile tab.
                ProfileView()
                    .workoutMiniBar(onOpen: openActiveWorkout)
                    .tabItem { Label("Profile", image: "user-circle-dashed") }
                    .tag(3)
            }
        }
        // Claude  Date 07/13/2026
        // World flips come from the ModeNotch pill (mounted in each root screen's
        // nav bar), which writes the shared "appMode" key. React here: bank the
        // outgoing world's tab and restore the incoming world's last-selected one.
        // With only two modes, the outgoing mode is always the new one's toggle.
        .onChange(of: modeRaw) { newRaw in
            let next = AppMode(rawValue: newRaw) ?? .lifting
            if next == .lifting {
                nutritionTab = selection
                selection = liftingTab
            } else {
                liftingTab = selection
                selection = nutritionTab
            }
        }
        .tint(theme.current.accent)
        .preferredColorScheme(theme.current.preferredColorScheme)
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView()
        }
        // Claude  Date 07/11/2026
        // Full-screen rest countdown, opened by tapping the mini-bar or the inline
        // rest row while resting (see WorkoutSession.showFullScreenTimer).
        .fullScreenCover(isPresented: $session.showFullScreenTimer) {
            RestTimerFullScreenView()
        }
        // Claude  Date 06/16/2026 last changed: 07/16/2026 by: Claude
        // The global workout mini-bar used to be a floating overlay here (with a
        // hardcoded 49pt tab-bar offset); it's now a per-tab safe-area inset —
        // see .workoutMiniBar above — so pages scroll clear of it. Celebration
        // overlays below still sit on top of it, same as before.
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
            } else if !store.pendingFoundersUnlock.isEmpty {
                // Claude  Date 07/12/2026
                // Founders Edition unlock celebration (dev-triggered today; IAP
                // purchase-success later). Sits last in the chain — nothing else is
                // ever queued at the same time as it.
                FoundersUnlockOverlay(
                    cards: store.pendingFoundersUnlock,
                    onDismiss: { store.dismissFoundersUnlock() }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.pendingWorkoutSummary?.id)
        .animation(.easeInOut(duration: 0.25), value: store.pendingCelebrations.first?.id)
        .animation(.easeInOut(duration: 0.25), value: store.pendingPromotions.first)
        .animation(.easeInOut(duration: 0.25), value: store.pendingFoundersUnlock.isEmpty)
        // Claude  Date 07/14/2026 last changed: 07/14/2026 by: Claude
        // The first-boot spotlight tour, above everything (its own layer, after the
        // celebration ladder — in practice they never coexist: the tour fires on a
        // fresh profile with nothing queued, and replays are user-initiated). The
        // GeometryReader ignores safe area, so anchors resolve — and the synthesized
        // chrome fallbacks are computed — in full-screen coordinates. NOTE: ignoring
        // safe area also zeroes proxy.safeAreaInsets, so the real device insets come
        // from UIKit (deviceInsets below) — using the proxy's was the bug that put
        // the notch spotlight too high and the tab spotlights too low.
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if store.tourActive {
                    TourOverlay(
                        steps: TourScript.steps,
                        frameFor: { target in
                            anchors[target].map { proxy[$0] }
                                ?? target.fallbackFrame(size: proxy.size,
                                                        insets: deviceInsets,
                                                        mode: mode)
                        },
                        onApply: applyTourStep,
                        onFinish: { store.completeTour() },
                        size: proxy.size,
                        insets: deviceInsets
                    )
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.25), value: store.tourActive)
        // Claude  Date 07/14/2026
        // Auto-start the tour exactly once, right after onboarding completes. The
        // delay lets the fullScreenCover's dismissal animation finish first (the
        // cover closes reactively when hasOnboarded flips). The onAppear catch-up
        // covers a relaunch where the tour never ran (killed mid-tour, or an
        // existing pre-tour profile that migrated in hasSeenTour = false).
        .onChange(of: store.profile.hasOnboarded) { done in
            guard done, !store.profile.hasSeenTour else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { store.startTour() }
        }
        .onAppear {
            if store.profile.hasOnboarded && !store.profile.hasSeenTour {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { store.startTour() }
            }
        }
        // Claude  Date 06/18/2026
        // Keep the shared card in sync (Friends mode only). Push on launch + whenever
        // the app returns to the foreground, and react to card-relevant edits: profile
        // (name / style / rank toggle / pinned badges) and the earned-badge set (which
        // drives the equipped rank). Each call no-ops unless in Friends mode + changed.
        .task { cardSync.sync(from: store) }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                cardSync.sync(from: store)
                // Catch the rest timer up to real elapsed time after backgrounding/locking.
                session.refreshRest()
                // Claude  Date 07/01/2026
                // They came back — drop any pending "still running" nudge (and clear it
                // from Notification Center if it already fired).
                WorkoutNotifications.cancelStillRunningReminder()
            case .background:
                // Claude  Date 07/01/2026
                // Left the app mid-session: nudge in 15 minutes if they never return.
                // Rescheduled on every background, so the countdown restarts each time.
                if store.activeWorkout != nil {
                    WorkoutNotifications.scheduleStillRunningReminder()
                }
            default:
                break
            }
        }
        .onChange(of: store.profile) { _ in cardSync.sync(from: store) }
        .onChange(of: store.unlockedAchievementIDs) { _ in cardSync.sync(from: store) }
    }

    // Claude  Date 06/16/2026 last changed: 07/13/2026 by: Claude
    // Jump back into the active workout from the mini-bar: switch to Lifting mode +
    // the Workouts tab, then hand the id to WorkoutsListView (it pushes the editor).
    // When flipping from Food, pre-set liftingTab so the onChange(of: modeRaw)
    // restore lands on Workouts regardless of ordering with `selection = 1` here.
    private func openActiveWorkout() {
        guard let id = store.activeWorkout?.id else { return }
        if mode != .lifting {
            liftingTab = 1
            modeRaw = AppMode.lifting.rawValue
        }
        selection = 1
        session.requestedWorkoutID = id
    }

    // Claude  Date 07/14/2026
    // The real device safe-area insets, read from the key window. Needed because
    // the tour overlay's GeometryReader ignores safe area for full-screen
    // coordinates, which zeroes the insets SwiftUI would otherwise report.
    private var deviceInsets: EdgeInsets {
        #if canImport(UIKit)
        let insets = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero
        return EdgeInsets(top: insets.top, leading: insets.left,
                          bottom: insets.bottom, trailing: insets.right)
        #else
        return EdgeInsets()
        #endif
    }

    // Claude  Date 07/14/2026
    // Put the app in the state a tour step needs before its spotlight lands. Uses
    // the same ordering trick as openActiveWorkout: when flipping worlds, pre-set
    // the destination world's remembered tab so the onChange(of: modeRaw) restore
    // lands exactly where the step points.
    private func applyTourStep(_ tourStep: TourStep) {
        if tourStep.mode != mode {
            if tourStep.mode == .lifting {
                liftingTab = tourStep.tab ?? liftingTab
            } else {
                nutritionTab = tourStep.tab ?? nutritionTab
            }
            modeRaw = tourStep.mode.rawValue
        } else if let tab = tourStep.tab {
            selection = tab
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
        .environmentObject(WorkoutSession())
        .environmentObject(CardSyncService())
}
