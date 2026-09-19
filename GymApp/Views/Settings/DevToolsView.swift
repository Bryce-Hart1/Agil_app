import SwiftUI

// Claude  Date 09/19/2026
// Settings › Dev: every beta/debug tool, moved out of the main Settings list so it stays
// short. Pushed from the last row of SettingsView. Achievement + shop tools ship in beta;
// coins, rank lab, barcode cache and ask screens stay #if DEBUG (see notes on each).
struct DevToolsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    // Claude  Date 08/13/2026 last changed: 09/19/2026 by: Claude
    // The review and notification asks have no real trigger yet; these preview them.
    @State private var showReviewAsk = false
    @State private var showNotificationAsk = false

    var body: some View {
        List {
            // Claude  Date 06/13/2026 last changed: 09/19/2026 by: Claude
            // Achievement testing: gallery, per-badge forcing, bulk unlock/unopen/reset,
            // and the Founders unlock celebration (preview of the future IAP moment).
            Section {
                NavigationLink {
                    BadgeGalleryView()
                } label: {
                    Label("Badge gallery", systemImage: "square.grid.3x3.fill")
                }
                NavigationLink {
                    AchievementForceView()
                } label: {
                    Label("Force achievements", systemImage: "switch.2")
                }
                Button("Unlock all achievements") {
                    store.unlockAllAchievements()
                }
                Button("Mark all achievements unopened") {
                    store.markAllUnopened()
                }
                Button("Unlock Founders cards") {
                    theme.grantFoundersCards()
                    store.celebrateFoundersUnlock()
                }
                Button("Reset achievements", role: .destructive) {
                    store.resetAchievements()
                }
            } header: {
                Text("Achievements")
            } footer: {
                Text("Try out badges and their celebrations. Reset rebuilds your badges from your workout history.")
            }

            // Claude  Date 08/24/2026 last changed: 09/19/2026 by: Claude
            // The full catalogue. Players only see the daily/weekly rotation in the Shop.
            Section {
                NavigationLink {
                    ShopCatalogView()
                } label: {
                    Label("Browse all shop items", systemImage: "bag")
                }
            } header: {
                Text("Shop")
            } footer: {
                Text("See every theme and card, not just today's picks.")
            }

            // Claude  Date 06/16/2026 last changed: 09/19/2026 by: Claude
            // #if DEBUG: coins are sold for real money, so free grants must never ship.
            // Reset also clears the wallet, since the earned high-water mark would
            // otherwise keep the balance up. Check-in reset replays the daily reward toast.
            #if DEBUG
            Section {
                LabeledContent("Coins") {
                    Text("\(theme.balance)")
                        .monospacedDigit()
                        .foregroundStyle(theme.current.accent)
                }
                Button("Add 500 coins") { store.grantDevCoins(500) }
                Button("Add 2,000 coins") { store.grantDevCoins(2_000) }
                Button("Reset dev coins", role: .destructive) {
                    store.resetDevCoins()
                    theme.debugResetWallet()
                }
                LabeledContent("Check-ins this week") {
                    Text("\(store.checkInWeek.claimed) / \(store.checkInWeek.cap)")
                        .monospacedDigit()
                        .foregroundStyle(theme.current.accent)
                }
                Button("Reset daily check-ins", role: .destructive) {
                    store.debugResetCheckIns()
                }
            } header: {
                Text("Coins")
            } footer: {
                Text("Free coins for testing the Shop. Resetting check-ins lets the daily bonus show again.")
            }

            // Claude  Date 07/09/2026
            // Live playground for the rank ring + promotion animations (see RankRingLabView).
            Section {
                NavigationLink { RankRingLabView() } label: {
                    Label("Rank ring lab", systemImage: "circle.hexagongrid.fill")
                }
            } header: {
                Text("Rank ring")
            } footer: {
                Text("Play with every rank and its promotion animation.")
            }

            // Claude  Date 06/17/2026
            // Temporary check for the barcode cache: resolves a known barcode twice
            // through CachedFoodService and prints the paths to the Xcode console.
            Section {
                LabeledContent("Cached barcodes", value: "\(store.barcodeCache.entries.count)")
                Button("Test barcode cache") { runBarcodeCacheTest() }
            } header: {
                Text("Barcode cache")
            } footer: {
                Text("Looks up Nutella twice. Results print in the Xcode console.")
            }

            // Claude  Date 08/13/2026
            // #if DEBUG on purpose: a button that fires the App Store review prompt on
            // demand is exactly what App Review objects to. Both fire the real actions.
            Section {
                Button("Show review ask") { showReviewAsk = true }
                Button("Show notification ask") { showNotificationAsk = true }
            } header: {
                Text("Ask screens")
            } footer: {
                Text("These use the real prompts. iOS only asks about notifications once per install.")
            }
            #endif

            Section("Stored data") {
                LabeledContent("Exercises", value: "\(store.exercises.count)")
                LabeledContent("Workouts", value: "\(store.workouts.count)")
                LabeledContent("Presets", value: "\(store.presets.count)")
            }
        }
        .navigationTitle("Dev")
        .themed(theme.current)
        // Attached outside #if DEBUG so release still compiles the ask pages; they're
        // no-ops while the bindings are false.
        .reviewAsk(isPresented: $showReviewAsk)
        .notificationAsk(isPresented: $showNotificationAsk)
    }

    #if DEBUG
    // Claude  Date 06/17/2026
    // A cold lookup should hit the network and grow the cache by one; the second
    // should resolve from cache.
    private func runBarcodeCacheTest() {
        let service = CachedFoodService(base: BackendFoodClient(), store: store)
        let barcode = "3017620422003" // Nutella: well-populated on Open Food Facts.
        print("🔖 [barcode cache] \(BarcodeCache.debugRunLRUCheck())")
        Task { @MainActor in
            let before = store.barcodeCache.entries.count
            let wasCached = store.barcodeCache.contains(barcode)
            let first = try? await service.lookup(barcode: barcode)
            print("🔖 [barcode cache] 1st lookup (\(wasCached ? "already cached" : "cold → network")): \(first?.name ?? "nil") · entries \(before)→\(store.barcodeCache.entries.count)")
            let second = try? await service.lookup(barcode: barcode)
            print("🔖 [barcode cache] 2nd lookup (from cache): \(second?.name ?? "nil") · entries \(store.barcodeCache.entries.count)")
        }
    }
    #endif
}
