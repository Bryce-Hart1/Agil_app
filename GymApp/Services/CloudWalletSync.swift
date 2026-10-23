import Foundation

// Claude  Date 08/03/2026 last changed: 10/23/2026 by: CLAUDE
// Keeps the coin wallet (earned high-water mark, spend ledger) and the unlocked themes and
// cards alive across app deletion and new devices. Everything else in Agil lives as JSON in
// Documents, which iOS deletes with the app, and there are no accounts to anchor to.
// (10/23) Coins aren't sold any more; the Founders Pack restores through StoreKit itself.
//
// NSUbiquitousKeyValueStore is the cheapest thing that solves it: it's keyed to the
// same Apple ID that made the purchase, it survives reinstall, and it follows the
// user to a new device. It is NOT tamper-proof — a determined user can edit local
// state and it will sync. These are cosmetics in a fitness app; the alternative is
// building accounts and a server wallet, which is a different project.
//
// Requires the iCloud key-value entitlement (com.apple.developer.ubiquity-kvstore-identifier,
// see project.yml). Without it the store silently no-ops, which is why `isAvailable`
// is checked rather than assumed.
@MainActor
final class CloudWalletSync {
    private let store: NSUbiquitousKeyValueStore
    private weak var theme: ThemeManager?
    private var observer: NSObjectProtocol?

    /// One key holding the whole wallet payload as JSON.
    private static let key = "agil.wallet.v1"

    // Claude  Date 08/03/2026
    // What we sync. The wallet and the unlock sets travel TOGETHER and this is not
    // negotiable: restoring earned coins without the ledger of what they were
    // spent on would silently refund every past purchase, and restoring the ledger
    // without the unlocks would charge for items the user no longer owns.
    private struct Payload: Codable {
        var wallet: Wallet
        var unlockedThemeIDs: Set<UUID>
        var unlockedCardStyleIDs: Set<String>
    }

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// True when the iCloud entitlement is in place and the user is signed in.
    var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    // Claude  Date 08/03/2026
    // Wire up two-way sync: pull whatever iCloud has now, push on every local wallet
    // change, and merge again whenever another device writes.
    func start(theme: ThemeManager) {
        self.theme = theme

        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pull() }
        }

        theme.onWalletChanged = { [weak self] manager in
            self?.push(manager)
        }

        store.synchronize()
        pull()
        push(theme)
    }

    // MARK: - Pull

    // Claude  Date 08/03/2026
    // Merge iCloud's copy into the local one. The merge is max/union (see
    // Wallet.merged) rather than last-writer-wins — money must never be decided by a
    // timestamp race between two devices, and every field only grows, so merging is
    // order-independent and always errs toward the user.
    private func pull() {
        guard let theme, !theme.isSafeMode else { return }
        guard let data = store.data(forKey: Self.key) else { return }
        do {
            let remote = try JSONDecoder.walletDecoder.decode(Payload.self, from: data)
            theme.mergeWallet(remote.wallet,
                              unlockedThemes: remote.unlockedThemeIDs,
                              unlockedCards: remote.unlockedCardStyleIDs)
        } catch {
            // A payload we can't read is left completely alone: the next local push
            // overwrites it, and in the meantime nothing local is touched.
            print("⚠️ iCloud wallet payload unreadable: \(error)")
        }
    }

    // Claude  Date 09/06/2026
    // "Delete Account": drop the iCloud copy of the wallet. Static because the live
    // instance is owned by GymAppApp and never reaches Settings — and it doesn't need
    // to, since the key is fixed and the store is a singleton.
    //
    // Without this, wiping locally would be undone on the next pull: the merge is
    // max/union (money only ever grows), so iCloud would hand the balance straight
    // back. KNOWN LIMIT: another signed-in device that hasn't been deleted will push
    // its own copy back — same as any iCloud KVS wipe, and out of this app's reach.
    static func eraseCloudCopy() {
        let store = NSUbiquitousKeyValueStore.default
        store.removeObject(forKey: key)
        store.synchronize()
    }

    // MARK: - Push

    private func push(_ theme: ThemeManager) {
        guard !theme.isSafeMode else { return }
        let payload = Payload(wallet: theme.wallet,
                              unlockedThemeIDs: theme.unlockedThemeIDs,
                              unlockedCardStyleIDs: theme.unlockedCardStyleIDs)
        do {
            store.set(try JSONEncoder.walletEncoder.encode(payload), forKey: Self.key)
            store.synchronize()
        } catch {
            print("⚠️ Failed to encode wallet for iCloud: \(error)")
        }
    }
}

// Claude  Date 08/03/2026
// Dates are ISO-8601 here to match PersistenceService, so a ledger entry means the
// same thing whether it came off disk or out of iCloud.
private extension JSONEncoder {
    static let walletEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let walletDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
