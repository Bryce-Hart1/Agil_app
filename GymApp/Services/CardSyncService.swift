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
//  - Switching back to Ghost Mode deletes the server copy, so opting out really removes it.
//
// It deliberately does NOT hold a reference to AppStore (which would couple two app-wide
// objects); callers pass `store` into the sync methods. Pushes are debounced + deduped
// so rapid edits coalesce into one request and unchanged cards never hit the network.
@MainActor
final class CardSyncService: ObservableObject {
    // The device identity: the UUID used as X-User-Id and in card URLs. nil until the
    // user first opts into Friends mode. (This is NOT the human-shareable code — see
    // `friendCode` below.)
    @Published private(set) var identity: DeviceIdentity?
    // Claude  Date 07/14/2026
    // The short, server-owned friend code (5-char Crockford base-32) the user shares.
    // Populated from our own card after the first successful push (the server assigns
    // it), persisted, and shown wherever the user needs to hand it out.
    @Published private(set) var friendCode: String?

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
    private static let friendCodeFile = "friend_code.json"
    private static let keychainKey = "agil.cardKey"
    private static let pushDebounce: UInt64 = 800_000_000   // 0.8s

    /// The user's shareable friend code, once Friends mode has synced at least once.
    var myFriendCode: String? { friendCode }

    init(backend: CardBackend = BackendClient(),
         persistence: PersistenceService = PersistenceService(),
         keychain: KeychainStore = .standard) {
        self.backend = backend
        self.persistence = persistence
        self.keychain = keychain
        self.identity = persistence.load(Self.identityFile, default: DeviceIdentity?.none)
        self.lastPushed = persistence.load(Self.lastPushedFile, default: SharedCard?.none)
        self.friendCode = persistence.load(Self.friendCodeFile, default: String?.none)
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
    // card; Ghost → tear the server copy down.
    func handleModeChange(to mode: DataMode, store: AppStore) {
        switch mode {
        case .friends: sync(from: store)
        case .ghost: deleteMyCard()
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
                // Claude  Date 07/14/2026
                // The server assigns/owns our short friend code; learn it by reading
                // back our own card after the push. Cheap and only when it's unknown.
                if self.friendCode == nil,
                   let mine = try? await backend.fetchCard(id: id),
                   let code = mine.friendCode {
                    self.friendCode = code
                    persistence.save(code as String?, to: Self.friendCodeFile)
                }
            } catch {
                print("⚠️ card sync push failed: \(error)")
            }
        }
    }

    // Claude  Date 07/14/2026
    // Make sure we know our own friend code before showing the Friends screen, in
    // case a push hasn't captured it yet this session. No-op once known.
    func ensureFriendCode() async {
        guard friendCode == nil, let id = identity?.userID else { return }
        if let mine = try? await backend.fetchCard(id: id), let code = mine.friendCode {
            friendCode = code
            persistence.save(code as String?, to: Self.friendCodeFile)
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
            // Claude  Date 08/02/2026
            // Always true now: the profile picture is a two-sided coin whose heads face IS
            // the rank (see RankCoinView), so the ring is structural rather than optional
            // and the old "Show rank on card" toggle is gone. The wire field stays so the
            // backend contract is unchanged, and so a future client could opt out again.
            showsRankOnCard: true,
            rank: store.strategistRank,
            rankProgress: store.strategistProgress,
            showcasedAchievementIDs: store.profile.showcasedAchievementIDs,
            memberSince: stats.memberSince,
            // Claude  Date 08/02/2026
            // Characters-off sends nil rather than a disabled config, so turning them off
            // actually withdraws the face from the payload. Note the first launch after this
            // shipped re-pushes once for free: the cached last_pushed_card.json decodes with
            // character == nil and so won't match the new snapshot in the Equatable dedupe.
            character: store.profile.character.isEnabled ? store.profile.character : nil,
            updatedAt: nil,
            // Server-owned — never sent from the client (ignored on PUT).
            friendCode: nil
        )
    }

    // MARK: - Friends graph

    // Claude  Date 07/14/2026
    // The outcome of trying to add a friend, shaped for direct display. `.sent` and
    // `.autoAccepted` are the two success shapes; `.failed` carries a user-facing
    // message — the 429 (rate-limit) message is passed through VERBATIM per the
    // backend contract, the others are friendly translations of the status codes.
    enum AddFriendResult: Equatable {
        case sent
        case autoAccepted
        case failed(String)
    }

    // Send a friend request BY short code. See AddFriendResult for the mapping.
    func sendFriendRequest(code: String) async -> AddFriendResult {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failed("Enter a friend code first.") }
        guard let auth = auth() else { return .failed("Turn on Friends mode first.") }
        do {
            let outcome = try await backend.sendFriendRequest(code: trimmed, auth: auth)
            return outcome == .autoAccepted ? .autoAccepted : .sent
        } catch let BackendError.rateLimited(message) {
            return .failed(message)   // shown verbatim
        } catch BackendError.badRequest {
            return .failed("That's your own code — you can't add yourself.")
        } catch BackendError.forbidden {
            return .failed("You can't send a request to this person.")
        } catch BackendError.notFound {
            return .failed("No one found for that code. Double-check it and try again.")
        } catch BackendError.conflict {
            return .failed("You're already friends, or a request is already pending.")
        } catch {
            return .failed("Couldn't send the request. Check your connection and try again.")
        }
    }

    /// Cards of everyone with a pending incoming request to us.
    func loadIncomingRequests() async -> [SharedCard] { await load { try await backend.incomingRequests(auth: $0) } }
    /// Cards of our accepted friends.
    func loadFriends() async -> [SharedCard] { await load { try await backend.friends(auth: $0) } }
    /// Cards of everyone we've blocked.
    func loadBlocked() async -> [SharedCard] { await load { try await backend.blocks(auth: $0) } }

    // Mutations. All key off the other user's UUID (`otherId`), never their code —
    // the caller pulls that UUID from the SharedCard.userId in the loaded lists.
    @discardableResult func acceptRequest(_ otherId: String) async -> Bool { await act { try await backend.acceptRequest(otherId: otherId, auth: $0) } }
    @discardableResult func declineRequest(_ otherId: String) async -> Bool { await act { try await backend.declineRequest(otherId: otherId, auth: $0) } }
    @discardableResult func unfriend(_ otherId: String) async -> Bool { await act { try await backend.unfriend(otherId: otherId, auth: $0) } }
    @discardableResult func block(userId otherId: String) async -> Bool { await act { try await backend.block(userId: otherId, code: nil, auth: $0) } }
    @discardableResult func unblock(_ otherId: String) async -> Bool { await act { try await backend.unblock(otherId: otherId, auth: $0) } }

    // MARK: - Delete

    // Remove our card from the server and clear the push cache (so re-enabling Friends
    // re-uploads from scratch). Keeps the id + secret so the same identity returns; the
    // short friend code is server-owned, so we drop our cached copy and re-learn it on
    // the next push.
    private func deleteMyCard() {
        pushTask?.cancel()
        lastPushed = nil
        friendCode = nil
        persistence.save(SharedCard?.none, to: Self.lastPushedFile)
        persistence.save(String?.none, to: Self.friendCodeFile)
        guard let id = identity?.userID, let key = keychain.get(Self.keychainKey) else { return }
        Task { [backend] in
            do { try await backend.deleteCard(id: id, key: key) }
            catch { print("⚠️ card delete failed: \(error)") }
        }
    }

    // MARK: - Friends plumbing

    // Claude  Date 06/18/2026 last changed: 08/04/2026 by: Claude
    // Our credentials for an authenticated backend call, or nil if Friends mode was
    // never enabled (no identity/secret yet). Exposed (was private) because food
    // submission — `POST /foods/submit` — needs the same card auth /friends does, and
    // this type is the only owner of the Keychain secret. Read-only: callers get the
    // credentials to make a call, never the ability to mint or change them.
    var backendAuth: BackendAuth? {
        guard let id = identity?.userID, let key = keychain.get(Self.keychainKey) else { return nil }
        return BackendAuth(userId: id, key: key)
    }

    private func auth() -> BackendAuth? { backendAuth }

    // Run a list-returning call, swallowing errors to an empty list (the UI treats
    // "couldn't load" and "nothing here" the same — an empty section).
    private func load(_ call: (BackendAuth) async throws -> [SharedCard]) async -> [SharedCard] {
        guard let auth = auth() else { return [] }
        do { return try await call(auth) }
        catch { print("⚠️ friends load failed: \(error)"); return [] }
    }

    // Run a mutation, returning whether it succeeded.
    private func act(_ call: (BackendAuth) async throws -> Void) async -> Bool {
        guard let auth = auth() else { return false }
        do { try await call(auth); return true }
        catch { print("⚠️ friends action failed: \(error)"); return false }
    }
}
