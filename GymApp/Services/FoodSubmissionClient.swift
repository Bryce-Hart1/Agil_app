import Foundation

// Claude  Date 08/04/2026
// Sends a hand-entered food to the backend's review queue (`POST /foods/submit`). The
// row lands as `status = "pending"` and only enters the verified vault after Bryce
// approves it through the admin endpoints — this client has no part in that.
//
// Auth: the endpoint requires card credentials (`X-User-Id` + `X-Card-Key`), the same
// pair /friends uses, because an anonymous submit endpoint could be looped to fill the
// review queue and the disk. A Ghost-mode user has no card, so they simply can't
// submit — callers must treat that as "saved locally only", not as an error worth
// showing. See `FoodSubmissionError.noAccount`.
//
// Nutrient basis, which is easy to get wrong:
//   • `nutrients` are per `servingSize` — the same convention FoodItem uses.
//   • `nutrimentsJson` micros are per 100 g/ml, in Open Food Facts' own base units.
//     MicroField.nutrimentsJSON handles the unit conversion; the per-serving → per-100
//     conversion happens here, since only this type knows both halves.
struct FoodSubmissionClient {
    private let session: URLSession
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
    }

    // Claude  Date 08/04/2026
    // One submission. `micros` are per SERVING as typed into the form; they're scaled
    // to per-100 here using servingSize before going out.
    func submit(_ food: FoodItem, micros: Micros, isRestaurant: Bool, isGeneric: Bool,
                auth: BackendAuth) async throws -> FoodItem {
        let url = BackendClient.baseURL
            .appendingPathComponent("foods")
            .appendingPathComponent("submit")

        // Per-serving → per-100, through the same factor the stored copy uses
        // (FoodItem.per100Factor), so the food on the device and the food in the review
        // queue can't disagree. nil = a count serving with no gram weight, or an absent
        // serving size: send the values as-is rather than fabricating a basis.
        // (08/18: this used to divide by servingSize alone, which sent a "2 oz" serving
        // scaled ×50 instead of ×1.76.)
        let per100 = MicroField.scaled(micros, by: food.per100Factor ?? 1)

        let body = Payload(
            name: food.name,
            brand: food.brand,
            barcode: food.barcode,
            servingSize: food.servingSize,
            servingUnit: food.servingUnit,
            servingQuantity: food.servingQuantity,
            servingLabel: food.servingLabel,
            category: food.category,
            isRestaurant: isRestaurant,
            isGeneric: isGeneric,
            nutrients: food.nutrients,
            nutrimentsJson: Self.encodeNutriments(MicroField.nutrimentsJSON(from: per100))
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(auth.userId, forHTTPHeaderField: "X-User-Id")
        request.setValue(auth.key, forHTTPHeaderField: "X-Card-Key")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch code {
        case 200...299:
            // The server echoes the stored row; decoding it means the pending food
            // (with its real server id) replaces the local placeholder.
            return try JSONDecoder().decode(FoodItem.self, from: data)
        case 401, 403:
            throw FoodSubmissionError.noAccount
        case 409:
            throw FoodSubmissionError.duplicateBarcode
        default:
            throw FoodSubmissionError.http(code, Self.serverMessage(data))
        }
    }

    // The blob the backend parses with MICRO_MAP. Empty micros send "{}" rather than
    // null so the server's `Option<String>` path stays uniform.
    private static func encodeNutriments(_ values: [String: Double]) -> String {
        guard !values.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: values),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    // Best-effort extraction of the server's error text for the user-facing message.
    private static func serverMessage(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return String(data: data, encoding: .utf8) }
        return (object["error"] ?? object["message"]) as? String
    }

    // camelCase field names match the backend's `FoodSubmission` (serde
    // rename_all = "camelCase"). Optional fields are omitted when nil.
    private struct Payload: Encodable {
        let name: String
        let brand: String
        let barcode: String?
        let servingSize: Double
        let servingUnit: String
        let servingQuantity: Double?
        let servingLabel: String?
        let category: String?
        let isRestaurant: Bool
        let isGeneric: Bool
        let nutrients: Nutrients
        let nutrimentsJson: String
    }
}

// Claude  Date 08/04/2026
// Submission failures the UI actually distinguishes. Everything else collapses into
// `.http`, which carries the server's message when it sent one.
enum FoodSubmissionError: LocalizedError {
    case noAccount
    case duplicateBarcode
    case http(Int, String?)

    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "Sharing foods needs Friends mode turned on. Your food was saved to this device."
        case .duplicateBarcode:
            return "That barcode is already in the food database."
        case .http(let code, let message):
            return message ?? "Couldn't send this food for review (error \(code))."
        }
    }
}
