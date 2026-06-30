import Foundation

// Claude  Date 06/18/2026
// The app's client for the Agil backend (Rust/Axum, see the backend repo). Scoped,
// for now, to exactly three calls against one resource — the shared profile card —
// because that's the only thing this build syncs. Modeled on OpenFoodFactsClient:
// a protocol so views/services depend on the abstraction (and can be mocked), an
// injected URLSession, a typed error, and a single private response check.
//
// Auth model: anonymous id + secret key. Reads are public (a friend only needs your
// id); writes carry the secret in the `X-Card-Key` header, which the server binds to
// the id on first write (trust-on-first-use) and checks thereafter.

/// Abstraction the sync layer depends on, so the network client is swappable.
protocol CardBackend {
    /// Fetch a card by its public id. `nil` when the server has none (404).
    func fetchCard(id: String) async throws -> SharedCard?
    /// Create or update the caller's own card; `key` authorizes the write.
    func putCard(_ card: SharedCard, key: String) async throws
    /// Remove the caller's own card (e.g. when switching back to Offline).
    func deleteCard(id: String, key: String) async throws
}

enum BackendError: Error {
    case badURL
    case http(Int)
    case unauthorized   // 401/403 — wrong key for this id
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
        try Self.check(response)
        return try decoder.decode(SharedCard.self, from: data)
    }

    func putCard(_ card: SharedCard, key: String) async throws {
        var request = URLRequest(url: cardURL(card.userId))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Card-Key")
        request.httpBody = try encoder.encode(card)
        let (_, response) = try await session.data(for: request)
        try Self.check(response)
    }

    func deleteCard(id: String, key: String) async throws {
        var request = URLRequest(url: cardURL(id))
        request.httpMethod = "DELETE"
        request.setValue(key, forHTTPHeaderField: "X-Card-Key")
        let (_, response) = try await session.data(for: request)
        try Self.check(response)
    }

    // MARK: - Helpers

    // `…/cards/{id}` off the base URL. appendingPathComponent percent-escapes the id.
    private func cardURL(_ id: String) -> URL {
        Self.baseURL.appendingPathComponent("cards").appendingPathComponent(id)
    }

    private func status(_ response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? -1
    }

    private static func check(_ response: URLResponse) throws {
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        if code == 401 || code == 403 { throw BackendError.unauthorized }
        guard (200...299).contains(code) else { throw BackendError.http(code) }
    }
}
