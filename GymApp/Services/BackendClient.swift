import Foundation

// Claude  Date 06/18/2026 last changed: 07/14/2026 by: Claude
// The app's client for the Agil backend (Rust/Axum, see the backend repo). Two
// resources now: the shared profile card (/cards) and the friends graph (/friends).
// Modeled on OpenFoodFactsClient: a protocol so views/services depend on the
// abstraction (and can be mocked), an injected URLSession, a typed error, and a
// single response check that also parses the server's {"error": "..."} body.
//
// Auth model: anonymous id + secret key.
//  - /cards/{id}: GET is public; PUT/DELETE carry the secret in `X-Card-Key`, which
//    the server binds to the id on first write (trust-on-first-use).
//  - /friends/*: EVERY call needs BOTH `X-User-Id` (the UUID) and `X-Card-Key`.
//
// The friend-request gotcha the backend contract calls out: you SEND a request by
// short `code`, but accept/decline/unfriend/unblock all take the other user's UUID
// (`otherId`, read from SharedCard.userId in the returned lists) — never the code.

// Claude  Date 07/14/2026
// The credentials every /friends call needs. Bundled so the many endpoints don't
// each grow two positional string params.
struct BackendAuth {
    let userId: String   // X-User-Id (our UUID / DeviceIdentity.userID)
    let key: String      // X-Card-Key (Keychain secret)
}

// Claude  Date 07/14/2026
// The two success shapes of POST /friends/requests: 201 = a request was created and
// is pending the other person, 200 = they had already requested us so the server
// auto-accepted and we're now friends.
enum FriendRequestOutcome {
    case sent
    case autoAccepted
}

/// Abstraction the sync layer depends on, so the network client is swappable.
protocol CardBackend {
    // Cards
    /// Fetch a card by its public id. `nil` when the server has none (404).
    func fetchCard(id: String) async throws -> SharedCard?
    /// Create or update the caller's own card; `key` authorizes the write.
    func putCard(_ card: SharedCard, key: String) async throws
    /// Remove the caller's own card (e.g. when switching back to Offline).
    func deleteCard(id: String, key: String) async throws

    // Friends
    /// Send a friend request by the other person's short code. 201 → sent, 200 →
    /// auto-accepted. Throws `.rateLimited` (verbatim message) on 429.
    func sendFriendRequest(code: String, auth: BackendAuth) async throws -> FriendRequestOutcome
    /// Cards of everyone who has an incoming request waiting on us.
    func incomingRequests(auth: BackendAuth) async throws -> [SharedCard]
    func acceptRequest(otherId: String, auth: BackendAuth) async throws
    func declineRequest(otherId: String, auth: BackendAuth) async throws
    /// Cards of our accepted friends.
    func friends(auth: BackendAuth) async throws -> [SharedCard]
    func unfriend(otherId: String, auth: BackendAuth) async throws
    /// Block someone by their UUID or their short code (exactly one is non-nil).
    func block(userId: String?, code: String?, auth: BackendAuth) async throws
    func unblock(otherId: String, auth: BackendAuth) async throws
    /// Cards of everyone we've blocked.
    func blocks(auth: BackendAuth) async throws -> [SharedCard]
}

// Claude  Date 06/18/2026 last changed: 07/14/2026 by: Claude
// Typed backend failures. Every non-2xx response carries the server's parsed
// {"error": "..."} string where present (`message`), so callers can surface it —
// `.rateLimited` in particular is meant to be shown to the user VERBATIM.
enum BackendError: Error {
    case badURL
    case unauthorized              // 401 — missing/blank credentials
    case forbidden(String?)        // 403 — blocked, or wrong card key
    case notFound(String?)         // 404 — no such code / request / friend
    case conflict(String?)         // 409 — already friends / duplicate request
    case badRequest(String?)       // 400 — e.g. requesting yourself
    case rateLimited(String)       // 429 — message shown verbatim
    case http(Int, String?)        // any other non-2xx
}

struct BackendClient: CardBackend {
    // Claude  Date 06/18/2026 last changed: 06/30/2026 by: Claude
    // One place to point the app at a backend (used by both BackendClient and
    // BackendFoodClient). The host is config-driven: it comes from the
    // AGIL_BACKEND_BASE_URL build setting (project.yml, per build configuration) via the
    // AgilBackendBaseURL Info.plist key, so LAN <-> prod is a config change, not a code
    // edit. Falls back to the LAN dev host if the value is missing, empty, or wasn't
    // substituted, so a bad config can never crash the app at launch.
    static let baseURL: URL = {
        let fallback = URL(string: "http://192.168.12.159:8080")!
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "AgilBackendBaseURL") as? String else {
            return fallback
        }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        // Reject empty or an unsubstituted "$(…)" placeholder before trusting it.
        guard !trimmed.isEmpty, !trimmed.contains("$("), let url = URL(string: trimmed) else {
            return fallback
        }
        return url
    }()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601   // matches the backend's ISO-8601 Z strings
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Cards

    func fetchCard(id: String) async throws -> SharedCard? {
        var request = URLRequest(url: cardURL(id))
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        if status(response) == 404 { return nil }
        try Self.check(data, response)
        return try decoder.decode(SharedCard.self, from: data)
    }

    func putCard(_ card: SharedCard, key: String) async throws {
        var request = URLRequest(url: cardURL(card.userId))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Card-Key")
        request.httpBody = try encoder.encode(card)
        let (data, response) = try await session.data(for: request)
        try Self.check(data, response)
    }

    func deleteCard(id: String, key: String) async throws {
        var request = URLRequest(url: cardURL(id))
        request.httpMethod = "DELETE"
        request.setValue(key, forHTTPHeaderField: "X-Card-Key")
        let (data, response) = try await session.data(for: request)
        try Self.check(data, response)
    }

    // MARK: - Friends

    func sendFriendRequest(code: String, auth: BackendAuth) async throws -> FriendRequestOutcome {
        let (_, response) = try await friendsRequest(
            "friends/requests", method: "POST", auth: auth, body: CodeBody(code: code))
        // 201 → newly sent, 200 → auto-accepted (they'd already requested us).
        return status(response) == 200 ? .autoAccepted : .sent
    }

    func incomingRequests(auth: BackendAuth) async throws -> [SharedCard] {
        try await getCards("friends/requests", auth: auth)
    }

    func acceptRequest(otherId: String, auth: BackendAuth) async throws {
        _ = try await friendsRequest(
            "friends/requests/\(otherId)/accept", method: "POST", auth: auth)
    }

    func declineRequest(otherId: String, auth: BackendAuth) async throws {
        _ = try await friendsRequest(
            "friends/requests/\(otherId)/decline", method: "POST", auth: auth)
    }

    func friends(auth: BackendAuth) async throws -> [SharedCard] {
        try await getCards("friends", auth: auth)
    }

    func unfriend(otherId: String, auth: BackendAuth) async throws {
        _ = try await friendsRequest("friends/\(otherId)", method: "DELETE", auth: auth)
    }

    func block(userId: String?, code: String?, auth: BackendAuth) async throws {
        _ = try await friendsRequest(
            "friends/blocks", method: "POST", auth: auth,
            body: BlockBody(userId: userId, code: code))
    }

    func unblock(otherId: String, auth: BackendAuth) async throws {
        _ = try await friendsRequest("friends/blocks/\(otherId)", method: "DELETE", auth: auth)
    }

    func blocks(auth: BackendAuth) async throws -> [SharedCard] {
        try await getCards("friends/blocks", auth: auth)
    }

    // MARK: - Helpers

    // `…/cards/{id}` off the base URL. appendingPathComponent percent-escapes the id.
    private func cardURL(_ id: String) -> URL {
        Self.baseURL.appendingPathComponent("cards").appendingPathComponent(id)
    }

    private struct CodeBody: Encodable { let code: String }
    // Synthesized encode uses encodeIfPresent for optionals, so the nil side is
    // omitted — the server sees exactly {"userId": …} OR {"code": …}.
    private struct BlockBody: Encodable { let userId: String?; let code: String? }

    // Claude  Date 07/14/2026
    // One authed /friends round-trip: sets both required headers, encodes an optional
    // JSON body, checks the response. `appending(path:)` (iOS 16+) keeps the "/"
    // separators in multi-segment paths rather than percent-escaping them.
    @discardableResult
    private func friendsRequest(_ path: String, method: String, auth: BackendAuth,
                                body: Encodable? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: Self.baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue(auth.userId, forHTTPHeaderField: "X-User-Id")
        request.setValue(auth.key, forHTTPHeaderField: "X-Card-Key")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        let (data, response) = try await session.data(for: request)
        try Self.check(data, response)
        return (data, response)
    }

    private func getCards(_ path: String, auth: BackendAuth) async throws -> [SharedCard] {
        let (data, _) = try await friendsRequest(path, method: "GET", auth: auth)
        return try decoder.decode([SharedCard].self, from: data)
    }

    private func status(_ response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? -1
    }

    // Claude  Date 07/14/2026
    // Maps a non-2xx response to a typed error, threading through the server's
    // {"error": "..."} message. 429's message is preserved for verbatim display.
    private static func check(_ data: Data, _ response: URLResponse) throws {
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard !(200...299).contains(code) else { return }
        let message = errorMessage(from: data)
        switch code {
        case 400: throw BackendError.badRequest(message)
        case 401: throw BackendError.unauthorized
        case 403: throw BackendError.forbidden(message)
        case 404: throw BackendError.notFound(message)
        case 409: throw BackendError.conflict(message)
        case 429: throw BackendError.rateLimited(
            message ?? "You've sent too many friend requests today. Try again tomorrow.")
        default:  throw BackendError.http(code, message)
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        struct ServerError: Decodable { let error: String }
        return (try? JSONDecoder().decode(ServerError.self, from: data))?.error
    }
}

// Claude  Date 07/14/2026
// Type-erased Encodable so friendsRequest can take a heterogeneous optional body
// (Encodable existentials can't be handed straight to JSONEncoder.encode).
private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeClosure = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}
