import Foundation

// Claude  Date 08/06/2026
// Sends a user's "this food is wrong" report to the backend (`POST /foods/corrections`).
// A food we own flips back to `verification = "pending"` and re-enters the same admin
// review queue submissions go through; an Open Food Facts row isn't ours to demote, so
// it only records a correction row for triage. Either way this client's job ends at
// "the report was accepted" — see .docs/user_food_feedback.md for the contract.
//
// Auth: card credentials (`X-User-Id` + `X-Card-Key`), the same gate `/foods/submit`
// uses, for the same reason — an anonymous report endpoint is a free way to flood the
// review queue. A Ghost-mode user has no card and simply can't report; the UI hides the
// affordance rather than letting the call fail (see FoodCorrectionCard).
//
// Rate limit: 3 accepted reports per user per day, enforced SERVER-side. The response
// carries `remainingToday` so the UI can be honest about the quota, but the client
// never gates on its own count — a stale local number must not block a legitimate
// report. Over quota comes back as 429 with user-facing copy in `error`.
struct FoodCorrectionClient {
    private let session: URLSession
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
    }

    // Claude  Date 08/06/2026
    // What the server accepted, echoed back: the queued report's id and how many
    // requests the user has left today.
    struct Receipt: Decodable {
        let status: String
        let remainingToday: Int
    }

    // Claude  Date 08/06/2026
    // One correction request for `food`.
    //
    // On identity, which is easy to get wrong: `food.id` is NOT always the backend's
    // primary key. Verified-vault rows arrive with ids like "verified:{barcode}", which
    // FoodItem hashes into a stable local UUID (see FoodItem.stableID) — that derived
    // value means nothing to the server. `food.remoteId` now preserves the original raw
    // id, so we send it when present and fall back to the (real-UUID) `food.id` otherwise;
    // the backend still resolves foodId → barcode → name+brand, so a stale or missing id
    // degrades gracefully. The payload keeps carrying barcode/name/brand/origin for that
    // fallback chain.
    func report(_ food: FoodDetail, reason: FoodCorrectionReason,
                auth: BackendAuth) async throws -> Receipt {
        let url = BackendClient.baseURL
            .appendingPathComponent("foods")
            .appendingPathComponent("corrections")

        let trimmedBrand = food.brand.trimmingCharacters(in: .whitespaces)
        let body = Payload(
            foodId: food.remoteId ?? food.id.uuidString,
            barcode: food.barcode,
            name: food.name,
            brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
            source: food.source.rawValue,
            reason: reason.rawValue
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
            return try JSONDecoder().decode(Receipt.self, from: data)
        case 401, 403:
            throw FoodCorrectionError.noAccount
        case 409:
            throw FoodCorrectionError.alreadyReported
        case 429:
            // The server writes this copy; it names the actual limit and reset, which
            // this side doesn't know. Shown verbatim, the way /friends' 429 is.
            throw FoodCorrectionError.rateLimited(Self.serverMessage(data))
        default:
            throw FoodCorrectionError.http(code, Self.serverMessage(data))
        }
    }

    // Best-effort extraction of the server's error text for the user-facing message.
    private static func serverMessage(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return String(data: data, encoding: .utf8) }
        return (object["error"] ?? object["message"]) as? String
    }

    // camelCase field names match the backend's serde `rename_all = "camelCase"`.
    // Optional fields are omitted when nil.
    private struct Payload: Encodable {
        let foodId: String
        let barcode: String?
        let name: String
        let brand: String?
        let source: String
        let reason: String
    }
}

// Claude  Date 08/06/2026
// Why a food might be wrong. Deliberately a short, closed list with no free-text field:
// five buckets are enough to route a report to the right part of a record, and typed
// notes would need moderation before anyone could read them. Raw values are the wire
// strings — keep them in sync with .docs/user_food_feedback.md.
enum FoodCorrectionReason: String, CaseIterable, Identifiable {
    case wrongCalories
    case wrongMacros
    case wrongServing
    case missingNutrients
    case wrongName

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wrongCalories:    return "Wrong calories"
        case .wrongMacros:      return "Wrong macros"
        case .wrongServing:     return "Wrong serving size"
        case .missingNutrients: return "Missing nutrients"
        case .wrongName:        return "Wrong name or brand"
        }
    }

    var systemImage: String {
        switch self {
        case .wrongCalories:    return "flame.fill"
        case .wrongMacros:      return "chart.pie.fill"
        case .wrongServing:     return "scalemass.fill"
        case .missingNutrients: return "questionmark.circle.fill"
        case .wrongName:        return "textformat"
        }
    }
}

// Claude  Date 08/06/2026
// The failures the UI distinguishes. Everything else collapses into `.http`, which
// carries the server's message when it sent one.
enum FoodCorrectionError: LocalizedError {
    case noAccount
    case alreadyReported
    case rateLimited(String?)
    case http(Int, String?)

    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "Asking for a correction needs Friends mode turned on."
        case .alreadyReported:
            return "You already asked for a correction on this food. It's in the queue."
        case .rateLimited(let message):
            return message ?? "You've asked for 3 corrections today. Try again tomorrow."
        case .http(let code, let message):
            return message ?? "Couldn't send this correction request (error \(code))."
        }
    }
}
