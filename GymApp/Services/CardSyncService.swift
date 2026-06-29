import Foundation
import Security

// Claude  Date 06/18/2026
// Owns the shared-card connection: the device identity (public id + Keychain secret),
// pushing the user's card up, and fetching a friend's card down. Injected app-wide as
// an @EnvironmentObject like AppStore/ThemeManager.
//
// Privacy rules enforced here:
//  - Nothing is ever sent unless the user chose Friends mode (UserProfile.dataMode).
//  - Only a SharedCard (card cosmetics + featured badges) is sent — built from
//    AppStore in `snapshot(from:)`; no other data is reachable from this type.
//  - Switching back to Offline deletes the server copy, so opting out really removes it.
//
// It deliberately does NOT hold a reference to AppStore (which would couple two app-wide
// objects); callers pass `store` into the sync methods. Pushes are debounced + deduped
// so rapid edits coalesce into one request and unchanged cards never hit the network.
@MainActor
final class CardSyncService: ObservableObject {
    // Public identity (the friend code). nil until the user first opts into Friends mode.
    @Published private(set) var identity: DeviceIdentity?

    private let backend: CardBackend
    private let persistence: PersistenceService
    private let keychain: KeychainStore

    // The last card we successfully pushed (updatedAt normalised to nil), so we can
    // skip re-pushing an unchanged card. Cached to disk to survive relaunches.
    private var lastPushed: SharedCard?
    // In-flight debounced push; cancelled and replaced when a newer change arrives.
    private var pushTask: Task<Void, Never>?

    private static let identityFile = "identity.json"
    private static let lastPushedFile = "last_pushed_card.json"
    private static let keychainKey = "agil.cardKey"
    private static let pushDebounce: UInt64 = 800_000_000   // 0.8s

    /// The user's shareable friend code, once Friends mode has been enabled.
    var myFriendCode: String? { identity?.userID }

    init(backend: CardBackend = BackendClient(),
         persistence: PersistenceService = PersistenceService(),
         keychain: KeychainStore = .standard) {
        self.backend = backend
        self.persistence = persistence
        self.keychain = keychain
        self.identity = persistence.load(Self.identityFile, default: DeviceIdentity?.none)
        self.lastPushed = persistence.load(Self.lastPushedFile, default: SharedCard?.none)
    }

    // MARK: - Identity

    // Create the id + secret on first need (first Friends-mode opt-in), or return the
    // existing one. The public id is persisted; the secret goes to the Keychain only.
    @discardableResult
    private func ensureIdentity() -> DeviceIdentity {
        if let identity { return identity }
        let new = DeviceIdentity()
        keychain.set(Self.makeSecretKey(), for: Self.keychainKey)
        identity = new
        persistence.save(new, to: Self.identityFile)
        return new
    }

    // 256 bits of randomness, base64 — the bearer secret that authorizes card writes.
    private static func makeSecretKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    // MARK: - Mode changes

    // React to the user toggling where their data lives. Friends → push the current
    // card; Offline → tear the server copy down.
    func handleModeChange(to mode: DataMode, store: AppStore) {
        switch mode {
        case .friends: sync(from: store)
        case .offline: deleteMyCard()
        }
    }

    // MARK: - Push

    // Build the current card and push it if (a) we're in Friends mode and (b) it
    // actually changed since the last push. Safe to call liberally (launch, foreground,
    // any profile/achievement change) — it no-ops otherwise. The network write is
    // debounced so a burst of edits sends once.
    func sync(from store: AppStore) {
        guard store.profile.dataMode == .friends else { return }
        let id = ensureIdentity().userID
        guard let key = keychain.get(Self.keychainKey) else { return }

        let snapshot = snapshot(from: store, id: id)
        guard snapshot != lastPushed else { return }

        pushTask?.cancel()
        pushTask = Task { [backend, persistence] in
            try? await Task.sleep(nanoseconds: Self.pushDebounce)
            if Task.isCancelled { return }
            do {
                var wire = snapshot
                wire.updatedAt = Date()
                try await backend.putCard(wire, key: key)
                self.lastPushed = snapshot
                persistence.save(snapshot as SharedCard?, to: Self.lastPushedFile)
            } catch {
                print("⚠️ card sync push failed: \(error)")
            }
        }
    }

    // The card snapshot for the current profile state. updatedAt is left nil so it
    // doesn't perturb change detection (it's stamped only on the wire copy).
    private func snapshot(from store: AppStore, id: String) -> SharedCard {
        let stats = ProfileStats(workouts: store.workouts, exercises: store.exercises)
        return SharedCard(
            userId: id,
            displayName: store.profile.resolvedName,
            cardStyleID: store.profile.cardStyleID,
            showsRankOnCard: store.profile.showsRankOnCard,
            rank: store.profile.showsRankOnCard ? store.strategistRank : nil,
            rankProgress: store.strategistProgress,
            showcasedAchievementIDs: store.profile.showcasedAchievementIDs,
            memberSince: stats.memberSince,
            updatedAt: nil
        )
    }

    // MARK: - Fetch / delete

    /// Fetch a friend's card by their code. Returns nil on 404 or any error.
    func fetchFriendCard(id: String) async -> SharedCard? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            return try await backend.fetchCard(id: trimmed)
        } catch {
            print("⚠️ fetch friend card failed: \(error)")
            return nil
        }
    }

    // Remove our card from the server and clear the push cache (so re-enabling Friends
    // re-uploads from scratch). Keeps the id + secret so the same friend code returns.
    private func deleteMyCard() {
        pushTask?.cancel()
        lastPushed = nil
        persistence.save(SharedCard?.none, to: Self.lastPushedFile)
        guard let id = identity?.userID, let key = keychain.get(Self.keychainKey) else { return }
        Task { [backend] in
            do { try await backend.deleteCard(id: id, key: key) }
            catch { print("⚠️ card delete failed: \(error)") }
        }
    }
}
