import Foundation

// Claude  Date 06/16/2026
// The app's first networking layer: a thin client over the public Open Food Facts
// API (no key required) that turns text searches and barcode lookups into the
// app's own FoodItem. Protocol-backed (FoodSearchService) so views depend on the
// abstraction and it can be swapped for a mock in tests / previews — the same way
// PersistenceService isolates disk.
//
// Mapping notes:
//  - We import nutrients at OFF's per-100g basis (servingSize 100, unit "g"); the
//    log screen lets the user pick how many servings, so 1.5 = 150 g. Per-100g is
//    the most consistently populated field set across OFF's crowd-sourced data.
//  - OFF reports sodium in GRAMS; our Nutrients.sodium is mg, so we ×1000 (and fall
//    back to salt ÷ 2.5 when sodium is absent).
//  - Numbers occasionally arrive as JSON strings, so every nutrient decodes through
//    OFFNumber, which accepts Double / Int / numeric String.

/// Abstraction the food picker depends on, so the network client is swappable.
protocol FoodSearchService {
    func search(_ query: String) async throws -> [FoodItem]
    func lookup(barcode: String) async throws -> FoodItem?
}

enum FoodSearchError: Error {
    case badURL
    case http(Int)
}

struct OpenFoodFactsClient: FoodSearchService {
    // Claude  Date 06/16/2026
    // OFF asks API clients to identify themselves with a descriptive User-Agent.
    private static let userAgent = "Agil/0.1 (alpha; nutrition tracking; contact bryce.hart23@gmail.com)"
    // Text search is served by the dedicated "search-a-licious" host; single-product
    // barcode lookups by the classic API host. (The legacy cgi/search.pl and the
    // /api/v2/search endpoint are both aggressively rate-limited — they return 503
    // under real use — so search goes through the search service instead.)
    private static let searchHost = "search.openfoodfacts.org"
    private static let productHost = "world.openfoodfacts.org"
    // Fields we request for a barcode lookup, so OFF returns a small payload. (The
    // search host doesn't support projecting `nutriments`, so search omits `fields`.)
    private static let productFields = "code,product_name,brands,serving_size,nutriments"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // Claude  Date 06/16/2026
    // Full-text product search via the search-a-licious service. Returns mapped
    // foods, dropping any result without a name or any usable macro (compactMap via
    // food(from:)). We can't project `nutriments` through the `fields` param on this
    // host, so we request the full hit (heavier payload — a later optimization).
    func search(_ query: String) async throws -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }

        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = Self.searchHost
        comps.path = "/search"
        comps.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "page_size", value: "20"),
        ]
        guard let url = comps.url else { throw FoodSearchError.badURL }

        let data = try await get(url)
        let decoded = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return decoded.hits.compactMap(Self.food(from:))
    }

    // Claude  Date 06/16/2026
    // Single-product lookup by barcode (EAN/UPC). nil when OFF has no usable record.
    func lookup(barcode: String) async throws -> FoodItem? {
        let code = barcode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return nil }

        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = Self.productHost
        comps.path = "/api/v2/product/\(code).json"
        comps.queryItems = [URLQueryItem(name: "fields", value: Self.productFields)]
        guard let url = comps.url else { throw FoodSearchError.badURL }

        let data = try await get(url)
        let decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard let product = decoded.product else { return nil }
        return Self.food(from: product)
    }

    // MARK: - Networking

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw FoodSearchError.http(http.statusCode)
        }
        return data
    }

    // MARK: - Mapping

    // Claude  Date 06/16/2026
    // OFF product → our FoodItem at the per-100g basis. Returns nil for records with
    // no name or no usable macros (so junk/empty entries don't clutter results).
    static func food(from product: OFFProduct) -> FoodItem? {
        let name = (product.product_name ?? "").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let n = product.nutriments else { return nil }

        let nutrients = nutrients(from: n)
        guard nutrients.calories > 0 || nutrients.protein > 0
                || nutrients.carbs > 0 || nutrients.fat > 0 else { return nil }

        // brands is a comma-separated list; take the first as the display brand.
        let brand = (product.brands ?? "")
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""

        return FoodItem(
            name: name, brand: brand, barcode: product.code,
            servingSize: 100, servingUnit: "g",
            nutrients: nutrients, source: .openFoodFacts)
    }

    private static func nutrients(from n: OFFNutriments) -> Nutrients {
        // Sodium: OFF is in grams; ours is mg. Prefer sodium, else derive from salt.
        let sodiumGrams = n.sodium100g?.value ?? (n.salt100g?.value).map { $0 / 2.5 } ?? 0
        return Nutrients(
            calories: n.energyKcal100g?.value ?? 0,
            protein: n.proteins100g?.value ?? 0,
            carbs: n.carbs100g?.value ?? 0,
            fat: n.fat100g?.value ?? 0,
            fiber: n.fiber100g?.value ?? 0,
            sugar: n.sugars100g?.value ?? 0,
            sodium: sodiumGrams * 1000)
    }
}

// MARK: - OFF response DTOs

// Claude  Date 06/16/2026
// Minimal decodable shapes for the two OFF endpoints we use. Only the fields we map
// are modeled; everything is optional because OFF's data is crowd-sourced and sparse.
// Search-a-licious wraps results in `hits` (the v2/cgi endpoints used `products`).
struct OFFSearchResponse: Decodable {
    let hits: [OFFProduct]
}

struct OFFProductResponse: Decodable {
    let product: OFFProduct?
}

struct OFFProduct: Decodable {
    let code: String?
    let product_name: String?
    let brands: String?
    let serving_size: String?
    let nutriments: OFFNutriments?

    // Claude  Date 06/16/2026
    // Custom decode because `brands` differs by endpoint: the product API returns a
    // comma-separated String, while search-a-licious returns a [String]. Accept
    // either (joining an array) so one OFFProduct serves both.
    enum CodingKeys: String, CodingKey { case code, product_name, brands, serving_size, nutriments }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        product_name = try c.decodeIfPresent(String.self, forKey: .product_name)
        serving_size = try c.decodeIfPresent(String.self, forKey: .serving_size)
        nutriments = try c.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
        if let s = try? c.decodeIfPresent(String.self, forKey: .brands) {
            brands = s
        } else if let arr = try? c.decodeIfPresent([String].self, forKey: .brands) {
            brands = arr.joined(separator: ", ")
        } else {
            brands = nil
        }
    }
}

struct OFFNutriments: Decodable {
    let energyKcal100g: OFFNumber?
    let proteins100g: OFFNumber?
    let carbs100g: OFFNumber?
    let fat100g: OFFNumber?
    let fiber100g: OFFNumber?
    let sugars100g: OFFNumber?
    let sodium100g: OFFNumber?
    let salt100g: OFFNumber?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbs100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
        case salt100g = "salt_100g"
    }
}

// Claude  Date 06/16/2026
// OFF returns numbers inconsistently — sometimes a JSON number, sometimes a numeric
// string. This wrapper accepts Double / Int / String so one bad type never fails the
// whole product decode (it just yields a nil value, handled as 0 by the mapping).
struct OFFNumber: Decodable {
    let value: Double?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d }
        else if let i = try? c.decode(Int.self) { value = Double(i) }
        else if let s = try? c.decode(String.self) { value = Double(s) }
        else { value = nil }
    }
}
