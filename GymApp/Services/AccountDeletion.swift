import Foundation
import WidgetKit

// Claude  Date 09/06/2026
// "Delete Account" — the one place that erases everything Agil holds, on the server
// and on the device. Nothing else should reach for the individual erase methods; the
// ORDER below is the whole point of this type existing.
//
// Not to be confused with Ghost Mode's opt-out (CardSyncService.scheduleCardDeletion),
// which only removes the SERVER copy and stays undoable for a day. This is immediate
// and total, gated behind a typed "DELETE" in Settings.
//
// Side effects, in the order they land: the shared card and friends graph are gone
// from the backend; the device identity and its Keychain secret are destroyed (a
// future opt-in mints a brand-new one, so friends cannot re-find this user); every
// workout, meal, badge and coin — including PURCHASED coins — is gone; and the app
// drops back to the onboarding screen because profile.hasOnboarded is false again.
@MainActor
enum AccountDeletion {

    // Runs the full teardown. Server first, because it needs the identity and secret
    // that the local wipe is about to destroy — reversing these two would leave an
    // undeletable row on the backend with no device able to authenticate against it.
    static func eraseEverything(store: AppStore,
                                theme: ThemeManager,
                                cardSync: CardSyncService) async {
        // 1. Backend: delete the card + friends graph, then burn the identity/secret.
        await cardSync.eraseAccount()

        // 2. In-memory app state back to first-launch defaults, so the UI empties out
        //    now rather than at the next launch.
        store.eraseAllData()
        theme.eraseAllData()

        // 3. The copies that live outside this app's sandbox. iCloud must be cleared
        //    or the max/union merge would hand the wallet straight back (see
        //    CloudWalletSync.eraseCloudCopy).
        CloudWalletSync.eraseCloudCopy()
        WidgetSnapshot.erase()
        WidgetCenter.shared.reloadAllTimelines()

        // 4. Preferences (@AppStorage lives in the standard domain) and a final sweep
        //    of the Documents JSON. Both are blunt on purpose — a hand-maintained list
        //    of keys and filenames is how a factory reset quietly leaves data behind.
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        PersistenceService().removeAll()
    }
}
