import SwiftUI

@main
struct GymAppApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var theme = ThemeManager()
    // Claude  Date 06/16/2026
    // Live in-progress-workout state (rest timer + mini-bar navigation), shared app-wide.
    @StateObject private var session = WorkoutSession()
    // Claude  Date 06/18/2026
    // Shared profile-card sync (Friends mode). Owns the device identity + push/fetch;
    // no-ops entirely while the user is in Ghost Mode. See CardSyncService.
    @StateObject private var cardSync = CardSyncService()
    // Claude  Date 08/03/2026
    // Coin packs (StoreKit 2). Owned at app level, not by the Shop screen, because
    // its transaction listener has to be running whether or not the Shop is open —
    // an Ask to Buy approval or an interrupted purchase can land at any time.
    @StateObject private var coinStore = CoinStore()
    // Claude  Date 08/03/2026
    // Keeps the wallet alive across reinstalls and new devices (see CloudWalletSync).
    // Not a @StateObject — it publishes nothing, it just bridges ThemeManager and
    // NSUbiquitousKeyValueStore.
    @State private var cloudWallet = CloudWalletSync()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(theme)
                .environmentObject(session)
                .environmentObject(cardSync)
                .environmentObject(coinStore)
                // Claude  Date 07/16/2026 last changed: 08/03/2026 by: Claude
                // Seed the home-screen widget's shared snapshot on launch. The
                // didSet-driven syncs in AppStore/ThemeManager don't fire during
                // init, so without this the widget would stay stale (or empty)
                // until the user next logs food or changes the theme.
                //
                // 08/03: also brings the wallet up. Order matters — iCloud merges
                // first so a reinstalled device has its purchased coins back before
                // StoreKit starts crediting anything, and noteEarned seeds the
                // earned high-water mark (the migration in ThemeManager.init can't:
                // it has no access to the workout history).
                //
                // Claude  Date 08/23/2026
                // 08/23: the daily check-in is recorded here too, and it has to land
                // BEFORE noteEarned — recording the day raises totalCoinsEarned, and
                // doing it after would leave today's +20 sitting outside the wallet
                // until something else happened to republish the earned total.
                .task {
                    store.syncWidgetSnapshot()
                    theme.syncWidgetSnapshot()
                    cloudWallet.start(theme: theme)
                    store.recordDailyCheckIn()
                    theme.noteEarned(store.totalCoinsEarned)
                    coinStore.start(theme: theme)
                }
        }
    }
}
