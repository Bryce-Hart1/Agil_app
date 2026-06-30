import Foundation

// Claude  Date 06/30/2026
// Food lookups via the Agil backend instead of calling Open Food Facts directly. The
// server is now a read-through cache over OFF: it answers from its own `foods` table
// when it can, fetches from OFF on a miss, and stores the result for everyone. Keeping
// all upstream/API traffic server-side means no third-party rate limits, keys, or
// outage handling on the device — and one place to observe it.
//
// Conforms to the same FoodSearchService protocol as OpenFoodFactsClient, so it's a
// drop-in for the food picker and the barcode resolver (still wrapped by
// CachedFoodService, whose local cache short-circuits repeat scans before the server).
// The server's response is wire-identical to FoodItem, so it decodes straight through.
struct BackendFoodClient: FoodSearchService {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder() // FoodItem carries no dates — default decoding is fine.
    }

    // GET {base}/foods/search?q=… — the server proxies OFF live and caches what it returns.
    func search(_ query: String) async throws -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }

        let base = BackendClient.baseURL.appendingPathComponent("foods").appendingPathComponent("search")
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw FoodSearchError.badURL
        }
        comps.queryItems = [URLQueryItem(name: "q", value: q)]
        guard let url = comps.url else { throw FoodSearchError.badURL }

        let (data, response) = try await session.data(from: url)
        try Self.check(response)
        return try decoder.decode([FoodItem].self, from: data)
    }

    // GET {base}/foods/barcode/{code} — read-through cache; 404 means OFF had nothing usable.
    func lookup(barcode: String) async throws -> FoodItem? {
        let code = barcode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return nil }

        let url = BackendClient.baseURL
            .appendingPathComponent("foods")
            .appendingPathComponent("barcode")
            .appendingPathComponent(code)

        let (data, response) = try await session.data(from: url)
        if (response as? HTTPURLResponse)?.statusCode == 404 { return nil }
        try Self.check(response)
        return try decoder.decode(FoodItem.self, from: data)
    }

    private static func check(_ response: URLResponse) throws {
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else { throw FoodSearchError.http(code) }
    }
}
