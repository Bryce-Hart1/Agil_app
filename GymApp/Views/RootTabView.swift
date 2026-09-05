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
    // Claude  Date 09/03/2026
    // Destination for a tapped notification, published by AppDelegate.
    @EnvironmentObject private var router: NotificationRouter
    @Environment(\.scenePhase) private var scenePhase
    // Claude  Date 06/16/2026 last changed: 07/13/2026 by: Claude
    // Selected tab. Tabs are tagged from 1 (the old tag-0 switcher placeholder is
    // gone — the ModeNotch pill at the top switches worlds now).
    @State private var selection = 1
    // Claude  Date 07/27/2026
    // Frames reported by tour targets that can't carry a preference anchor — today
    // just the ModeNotch, hosted in a UIKit nav bar. Owned here and injected into
    // the environment so the notch can write to it from inside the toolbar. See
    // TourFrames.swift for why the preference path doesn't reach it.
    @StateObject private var tourFrames = TourFrames()
    // Claude  Date 06/16/2026 last changed: 07/13/2026 by: Claude
    // Which world the bar shows — lifting vs nutrition. Persisted so the app reopens
    // where you left off. Flipped by switchMode(to:), driven by the ModeNotch pill.
    @AppStorage("appMode") private var modeRaw = AppMode.lifting.rawValue
    private var mode: AppMode { AppMode(rawValue: modeRaw) ?? .lifting }
    // Claude  Date 07/13/2026
    // Each world remembers its last-selected tab across switches (and relaunches).
    @AppStorage("liftingTab") private var liftingTab = 1
    @AppStorage("nutritionTab") private var nutritionTab = 1

    // Claude  Date 09/02/2026
    // Heartbeat for the idle auto-finish (store.autoFinishStaleWorkouts). The launch and
    // foreground checks below can't catch a workout forgotten while the app just sits on
    // screen, so this re-checks every minute. Static because a struct-level publisher would
    // be rebuilt — and restarted — on every body evaluation. Cheap: the handler is one
    // filter over `workouts` that no-ops until something is genuinely stale.
    private static let idleCheck = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Claude  Date 06/12/2026
    // First-run onboarding shows until the user completes it (enters a name).
    private var showOnboarding: Binding<Bool> {
        Binding(get: { !store.profile.hasOnboarded }, set: { _ in })
    }

    var body: some View {
        // Claude  Date 07/21/2026
        // The bottom chrome is LAYOUT, not a safe-area inset. Both earlier attempts
        // — one inset around the TabView, then one per tab — drew the bar in the
        // right place but left pages believing they owned the full screen, so the
        // last ~54pt of a scroll view sat under the bar and couldn't be reached (the
        // workout editor's "Complete Workout" button, half-swallowed). Safe-area
        // insets applied outside a NavigationStack don't reach what it pushes, and
        // hiding the native tab bar took away the UIKit inset that used to cover
        // every page for us.
        //
        // A VStack removes the question: the TabView is physically shorter than the
        // screen, so nothing it hosts — root or pushed, scroll view or not — can
        // extend under the bars. The mini-bar moves up here for the same reason
        // (it collapses to zero height when it has nothing to show, so it costs
        // nothing when idle). The bar's own fill still bleeds through the home
        // indicator, so it reads as flush with the bottom edge.
        VStack(spacing: 0) {
            tabContent
            WorkoutMiniBar(onOpen: openActiveWorkout)
            // Claude  Date 07/24/2026
            // The Profile tab carries a red count of achievements earned but not yet
            // opened — the whole point of deferring reveals is that this is the only
            // thing that interrupts you, and it waits quietly until you tap it.
            AgilTabBar(
                items: AgilTabItem.items(for: mode),
                selection: $selection,
                badgeCounts: [AgilTabItem.profileTag(for: mode): store.unopenedAchievementCount]
            )
        }
        // Claude  Date 07/21/2026
        // The counterpart to the VStack above. Keyboard avoidance arrives as a bottom
        // safe-area inset on the ROOT, so without this the VStack lays out inside the
        // shortened area and drags the mini-bar and tab bar up with the keyboard —
        // landing them right on top of the keyboard's own accessory view, which is what
        // buried the workout editor's "Done" bar. Opting out pins both bars to the
        // bottom of the screen and lets the keyboard cover them. The pages keep their
        // own keyboard handling: Form/List is UIScrollView-backed, so UIKit still
        // scrolls the focused field into view.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Claude  Date 07/27/2026
        // Injected here rather than at the app root so it stays scoped to the tour's
        // only writer and reader. Toolbar content inherits the environment, which is
        // how ModeNotch — a principal toolbar item — reaches it (it already resolves
        // `store` and `theme` the same way).
        .environment(\.tourFrames, tourFrames)
        // Claude  Date 07/28/2026
        // Which tab is actually on screen. A TabView keeps visited tabs alive, so
        // every root screen's ModeNotch is live at once; each one reads this to tell
        // whether it's the visible instance before reporting its frame to the tour.
        .environment(\.activeTabTag, selection)
        .tint(theme.current.accent)
        // Claude  Date 07/21/2026
        // The app's typeface, carried by the theme (all built-ins are monospaced
        // today). One modifier is enough: SwiftUI cascades a font design over every
        // system font in the subtree, including views that set their own .font(...),
        // and presentations inherit it — so the sheets and fullScreenCovers below come
        // along too, as do both bottom bars. The UIKit-drawn navigation chrome can't
        // be reached this way; ChromeFontAppearance handles that (below).
        .fontDesign(theme.current.fontDesign.design)
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
        // Claude  Date 06/13/2026 last changed: 07/24/2026 by: Claude
        // Achievement-unlock celebration, shown over the whole app. Keyed by id so
        // each queued unlock gets a fresh pop-in animation as you tap through.
        // Earning a badge no longer queues one of these — the user opens badges from
        // the Achievement Book when they feel like it (AppStore.openAchievement),
        // which is why this layer lives on the root: it has to draw above the pushed
        // book screen that triggered it.
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
                    // CLAUDE  Date 09/03/2026 — the mark wears the equipped theme, like the icon.
                    logoAsset: ThemeIcon.logoAsset(for: theme.current),
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
            } else if let cardStyle = store.pendingCardUnlock.first {
                // Claude  Date 07/23/2026
                // Gemstone card reveal — plays after the badge celebration (which sits
                // earlier in this chain), so the diamond/emerald badge pops first, then
                // the card it just earned is revealed.
                CardUnlockOverlay(
                    style: cardStyle,
                    onEquip: {
                        store.profile.cardStyleID = cardStyle.id
                        store.dismissCardUnlock()
                    },
                    onDismiss: { store.dismissCardUnlock() }
                )
                .id(cardStyle.id)
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
        .animation(.easeInOut(duration: 0.25), value: store.pendingCardUnlock.first?.id)
        .animation(.easeInOut(duration: 0.25), value: store.pendingFoundersUnlock.isEmpty)
        // Claude  Date 08/29/2026
        // The daily check-in award no longer floats here as its own overlay layer —
        // it plays INSIDE the ModeNotch pill as one of its transient messages, so
        // the reward reads as part of the chrome rather than a banner over it. The
        // politeness gate (yield to the full-screen celebration ladder above) moved
        // with it: see ModeNotch.presentableCheckIn. recordDailyCheckIn stays here.
        // Claude  Date 07/14/2026 last changed: 07/14/2026 by: Claude
        // The first-boot spotlight tour, above everything (its own layer, after the
        // celebration ladder — in practice they never coexist: the tour fires on a
        // fresh profile with nothing queued, and replays are user-initiated). The
        // GeometryReader ignores safe area, so anchors resolve — and the synthesized
        // chrome fallbacks are computed — in full-screen coordinates. NOTE: ignoring
        // safe area also zeroes proxy.safeAreaInsets, so the real device insets come
        // from UIKit (deviceInsets below) — using the proxy's was the bug that put
        // the notch spotlight too high and the tab spotlights too low.
        //
        // Claude  Date 07/27/2026
        // Frame resolution is now three tiers, most-accurate first:
        //   1. the preference anchor (exact, and what everything on the SwiftUI side
        //      of the tree uses);
        //   2. tourFrames — an exact frame(in: .global) for targets that can't carry
        //      a preference because they live inside UIKit chrome (the ModeNotch).
        //      Same window coordinate space as the anchors, since this reader ignores
        //      safe area;
        //   3. fallbackFrame — the synthesized approximation, now a genuine backstop
        //      rather than the live path for the notch.
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if store.tourActive {
                    TourOverlay(
                        steps: TourScript.steps,
                        frameFor: { target in
                            anchors[target].map { proxy[$0] }
                                ?? tourFrames.frames[target]
                                ?? target.fallbackFrame(size: proxy.size,
                                                        insets: deviceInsets,
                                                        mode: mode)
                        },
                        onApply: applyTourStep,
                        onFinish: { store.completeTour() },
                        size: proxy.size
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
            guard done else { return }
            // Claude  Date 08/23/2026
            // Day 1 of the check-in streak. recordDailyCheckIn refuses to run while
            // hasOnboarded is false (no coin pill over the name prompt), so a brand-new
            // user needs this nudge the moment they finish — otherwise their first
            // bonus waits until the app is next foregrounded. The award's politeness
            // gate (ModeNotch.presentableCheckIn) keeps it out of the way of the tour
            // that starts just below.
            store.recordDailyCheckIn()
            guard !store.profile.hasSeenTour else { return }
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
        .task {
            // Claude  Date 09/02/2026
            // Close out any session left running since the last launch, before anything
            // else reads activeWorkout.
            store.autoFinishStaleWorkouts()
            cardSync.sync(from: store)
            // Claude  Date 07/23/2026
            // Silently backfill gemstone-card grants for any tier already earned — no
            // reveal for history (mirrors evaluateAchievements' announce: false pass).
            syncRewardCards(reveal: false)
        }
        // Claude  Date 07/21/2026
        // Mirror the theme's typeface onto the UIKit-drawn navigation chrome (titles
        // and bar-button labels), which .fontDesign above can't reach. Once at launch,
        // then on any change to the active theme's font — selecting a different theme
        // or editing the current custom one both land here, since the raw design of
        // `theme.current` is what's being watched.
        .onAppear { ChromeFontAppearance.apply(theme.current.fontDesign) }
        .onChange(of: theme.current.fontDesignRaw) { _ in
            ChromeFontAppearance.apply(theme.current.fontDesign)
        }
        // CLAUDE  Date 09/03/2026
        // Equipping a theme equips its home-screen icon too (AppIconManager). Here rather
        // than in ThemeManager.select so ThemeManager stays UIKit-free, like the font
        // chrome above. Launch/foreground is handled in scenePhase .active below.
        .onChange(of: theme.selectedID) { _ in AppIconManager.apply(theme.current) }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                cardSync.sync(from: store)
                // CLAUDE  Date 09/03/2026
                // Catch the icon up to the equipped theme. No-ops when it already matches,
                // which is the common case — without that guard iOS would show its "You
                // have changed the icon" alert on every foreground.
                AppIconManager.apply(theme.current)
                // Claude  Date 08/23/2026
                // First open of a new day pays the +20 check-in bonus. No-ops on every
                // other foreground. The wallet picks the coins up through the
                // totalCoinsEarned .onChange below.
                //
                // KNOWN LIMIT: if the app is left foregrounded across midnight there's
                // no .active transition, so the bonus waits for the next foreground.
                // ModeNotch documents and accepts the same midnight-rollover behaviour
                // for its stat; not worth a timer at alpha.
                store.recordDailyCheckIn()
                // Catch the rest timer up to real elapsed time after backgrounding/locking.
                session.refreshRest()
                // Claude  Date 09/02/2026
                // Back after a long absence with a workout still open? Finish it at its
                // last checked set rather than letting it keep accruing elapsed time.
                store.autoFinishStaleWorkouts()
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
        .onReceive(Self.idleCheck) { _ in store.autoFinishStaleWorkouts() }
        .onChange(of: store.profile) { _ in cardSync.sync(from: store) }
        .onChange(of: store.unlockedAchievementIDs) { _ in cardSync.sync(from: store) }
        // Claude  Date 07/23/2026 last changed: 07/24/2026 by: Claude
        // Gem-card reveals now ride on OPENING a badge, not earning one (this watched
        // unlockedAchievementIDs before). Since badges wait in the Achievement Book
        // until the user plays them, keying off the unlock would have popped the
        // diamond card while the diamond badge that earned it was still sealed —
        // backwards, and the one full-screen interruption this feature exists to
        // remove. Opening the badge now runs celebration → card reveal, in order.
        .onChange(of: store.openedAchievementIDs) { _ in syncRewardCards(reveal: true) }
        // Claude  Date 08/03/2026
        // Keep the wallet's earned high-water mark current as workouts and
        // achievements land. noteEarned only ever raises it, so this is also what
        // makes deleting a workout stop costing you coins you'd already banked.
        .onChange(of: store.totalCoinsEarned) { earned in theme.noteEarned(earned) }
        // Claude  Date 09/03/2026
        // Notification deep links. `$route` replays its current value to a new
        // subscriber, so a tap that cold-launched the app — routed before this view
        // existed — is still delivered here on first appear. Cleared after acting so
        // the same tap can't fire twice.
        .onReceive(router.$route.compactMap { $0 }) { route in
            switch route {
            case .supplements: openSupplements()
            }
            router.route = nil
        }
    }

    // Claude  Date 07/23/2026 last changed: 07/24/2026 by: Claude
    // Grant the gemstone profile card for each gem tier the user has OPENED a badge
    // in, and (when `reveal`) queue the "new card unlocked" reveal for any newly
    // granted. Lives here because it needs both the achievement state (store) and
    // card ownership (theme), which AppStore has no reference to. The grant is
    // idempotent, so the launch backfill (reveal: false) and live opens (reveal:
    // true) can both call it freely. Reads openedTiers rather than unlockedTiers so
    // the card can't arrive before the badge that earned it has been revealed.
    private func syncRewardCards(reveal: Bool) {
        var granted: [CardStyle] = []
        for tier in [BadgeTier.diamond, .emerald, .legend] where store.openedTiers.contains(tier) {
            if let id = CardStyle.rewardCardID(for: tier), theme.grantCardStyle(id) {
                granted.append(CardStyle.style(for: id))
            }
        }
        if reveal, !granted.isEmpty { store.celebrateCardUnlock(granted) }
    }

    // Claude  Date 07/21/2026
    // The tab pages themselves. Split out of `body` so the VStack above reads as the
    // three stacked pieces it is (pages, mini-bar, tab bar) — the contents are
    // unchanged, and world-switch bookkeeping stays with the selection it edits.
    private var tabContent: some View {
        TabView(selection: $selection) {
            // Claude  Date 07/21/2026
            // Each tab is hosted by .agilTab, which hides the native tab bar and
            // applies the item's tabItem/tag. Icons + titles live on AgilTabItem (see
            // AgilTabBar.swift) so our bar and the (hidden) native items can't drift
            // apart. Neither bottom bar is mounted here — both are siblings of this
            // TabView in the VStack above, which is what keeps pages from scrolling
            // underneath them.
            if mode == .lifting {
                WorkoutsListView()
                    .agilTab(.workouts)

                // Claude  Date 06/16/2026 last changed: 07/21/2026 by: Claude
                // The "Build" hub: workout presets (templates), with the exercise
                // library reachable from its top-left link. (Icon: custom template
                // asset "hammer", replacing plus.square.on.square.)
                PresetsListView()
                    .agilTab(.build)

                // Claude  Date 07/13/2026
                // Icon: custom template asset "chart-scatter" (was chart.bar.xaxis).
                ProgressDashboardView()
                    .agilTab(.progress)

                // Claude  Date 07/13/2026
                // Icon: custom template asset "user-circle-dashed" (was
                // person.crop.circle). Shared by both worlds' Profile tab.
                ProfileView()
                    .agilTab(.liftingProfile)
            } else {
                // Claude  Date 06/16/2026 Edited 6/16/26 Bryce Hart last changed: 07/21/2026 by: Claude
                // Nutrition world: per-day food Journal, the food library, and the
                // shared profile. Goals are reached from the Journal's toolbar.
                // (Icons: custom template assets "notepad"/"orange", replacing
                // fork.knife/carrot.)
                NutritionJournalView()
                    .agilTab(.journal)

                FoodLibraryView()
                    .agilTab(.foods)

                // Claude  Date 07/13/2026
                // Icon: custom template asset "user-circle-dashed" (was
                // person.crop.circle). Shared by both worlds' Profile tab.
                ProfileView()
                    .agilTab(.nutritionProfile)
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

    // Claude  Date 09/03/2026
    // Landing spot for a tapped supplement reminder: the Nutrition world's Journal,
    // where the checklist is actually ticked off. nutritionTab is pre-set for the same
    // reason openActiveWorkout pre-sets liftingTab — the onChange(of: modeRaw) restore
    // would otherwise drop us on whatever nutrition tab was last used.
    private func openSupplements() {
        if mode != .nutrition {
            nutritionTab = AgilTabItem.journal.tag
            modeRaw = AppMode.nutrition.rawValue
        }
        selection = AgilTabItem.journal.tag
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
        .environmentObject(NotificationRouter.shared)
}
