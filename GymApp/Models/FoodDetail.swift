import SwiftUI

// Claude  Date 07/14/2026
// Trust level of a food record, from the backend DTO's `source`. Curated `verified`
// foods outrank auto-cached `openFoodFacts`, which outrank unreviewed `userSubmitted`.
// Drives the little provenance badge on the detail page.
enum FoodTrust: String, Codable, Hashable {
    case verified
    case openFoodFacts
    case userSubmitted

    var label: String {
        switch self {
        case .verified:      return "Verified"
        case .openFoodFacts: return "Open Food Facts"
        case .userSubmitted: return "User submitted"
        }
    }

    var systemImage: String {
        switch self {
        case .verified:      return "checkmark.seal.fill"
        case .openFoodFacts: return "globe"
        case .userSubmitted: return "person.crop.circle.badge.questionmark"
        }
    }

    var tint: Color {
        switch self {
        case .verified:      return .green
        case .openFoodFacts: return .blue
        case .userSubmitted: return .orange
        }
    }

    // Claude  Date 07/14/2026
    // Bridge from the current library's FoodSource until the app fetches the richer DTO
    // end-to-end: shipped seeds read as curated, cached OFF stays OFF, hand-typed foods
    // are treated as user-submitted.
    init(_ source: FoodSource) {
        switch source {
        case .seed:          self = .verified
        case .openFoodFacts: self = .openFoodFacts
        case .custom:        self = .userSubmitted
        }
    }
}

// Claude  Date 07/14/2026
// The view model for the food detail page — a faithful shape of the backend's
// FoodItemDto (GET /foods/barcode/{code} and /foods/search). Macros AND micros are
// per 100 g/ml; `servingQuantity` (grams/ml of one serving) enables the "1 serving"
// view by scaling everything by servingQuantity / 100. `servingQuantity == nil` means
// only per-100 is possible — never fabricate a serving.
//
// Not the same type as the library's FoodItem (which is per-serving, carries no micros,
// and is wired into logging/persistence). This is display-only for now; an adapter from
// FoodItem lets the existing Foods tab present it before the DTO is wired all the way
// through the network layer.
struct FoodDetail: Identifiable, Hashable {
    let id: UUID
    var name: String
    var brand: String
    var barcode: String?
    // Comma-separated, most-general term first, or nil (always nil for verified foods
    // today). Mapped to an icon via `categoryIcon`.
    var category: String?
    var source: FoodTrust
    // Grams/ml in one serving. nil → per-100 only.
    var servingQuantity: Double?
    // "g" or "ml" — what the per-100 basis and serving are measured in.
    var basisUnit: String
    // Per-100 macros — EXCEPT in count mode (see `servingUnit`), where this holds the
    // nutrients of ONE serving instead.
    var per100: Nutrients
    // Per-100 micros (sparse; mostly nil).
    var micros: Micros

    // Claude  Date 07/15/2026
    // Count/opaque serving unit ("cup", "bar", "serving") for a food whose serving is
    // NOT a weight/volume, so no per-100 g/ml basis can be derived. When non-nil the
    // detail page runs in "count mode": `per100` holds one serving's nutrients, the only
    // amount is a servings count, and the per-100/gram options are hidden (they'd be
    // meaningless). nil = the normal weight/volume food where `per100` really is per 100.
    var servingUnit: String?

    // True when this food is measured in opaque servings (see `servingUnit`).
    var isCountBased: Bool { servingUnit != nil }

    init(id: UUID = UUID(), name: String, brand: String = "", barcode: String? = nil,
         category: String? = nil, source: FoodTrust, servingQuantity: Double? = nil,
         basisUnit: String = "g", per100: Nutrients, micros: Micros = .empty,
         servingUnit: String? = nil) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.category = category
        self.source = source
        self.servingQuantity = servingQuantity
        self.basisUnit = basisUnit
        self.per100 = per100
        self.micros = micros
        self.servingUnit = servingUnit
    }

    // Claude  Date 07/14/2026
    // Name with brand appended when present (matches FoodItem.displayLabel).
    var displayLabel: String {
        brand.trimmingCharacters(in: .whitespaces).isEmpty ? name : "\(name) · \(brand)"
    }

    // Claude  Date 07/14/2026
    // The leading (most general) category term → an SF Symbol, with a generic fallback.
    // category is comma-separated most-general-first, so the first token is the coarsest
    // bucket. Conservative symbol choices (all available on the app's min iOS) so nothing
    // renders as a blank box.
    var categoryIcon: String {
        guard let lead = category?.split(separator: ",").first?
            .trimmingCharacters(in: .whitespaces).lowercased(), !lead.isEmpty else {
            return "fork.knife"
        }
        let map: [(match: String, icon: String)] = [
            ("beverage", "cup.and.saucer.fill"), ("drink", "cup.and.saucer.fill"),
            ("water", "drop.fill"),
            ("dairy", "drop.fill"), ("dairies", "drop.fill"), ("milk", "drop.fill"),
            ("cheese", "square.stack.3d.up.fill"),
            ("snack", "takeoutbag.and.cup.and.straw.fill"),
            ("sweet", "birthday.cake.fill"), ("dessert", "birthday.cake.fill"),
            ("chocolate", "birthday.cake.fill"), ("sugar", "cube.fill"),
            ("fruit", "leaf.fill"), ("vegetable", "leaf.fill"), ("plant", "leaf.fill"),
            ("meat", "fork.knife"), ("fish", "fish.fill"), ("seafood", "fish.fill"),
            ("cereal", "square.grid.3x3.fill"), ("grain", "square.grid.3x3.fill"),
            ("bread", "square.grid.3x3.fill"), ("bakery", "square.grid.3x3.fill"),
            ("frozen", "snowflake"),
            ("condiment", "drop.triangle.fill"), ("sauce", "drop.triangle.fill"),
        ]
        for entry in map where lead.contains(entry.match) { return entry.icon }
        return "fork.knife"
    }

    // Claude  Date 07/14/2026 last changed: 07/15/2026 by: Claude
    // Stopgap adapter so the existing Foods tab (which only has FoodItem) can open the
    // detail page today. FoodItem stores nutrients PER its own serving. Two cases:
    //  • Weight/volume serving (g/ml): normalize to per-100 so the per-100 header is
    //    honest, and carry the serving size so the "1 serving" toggle works.
    //  • Count/opaque serving ("cup", "bar", "serving", …): there's no gram weight to
    //    derive per-100 from, so DON'T fabricate one — hand the per-serving nutrients
    //    through as-is and flag the food as count-based (via `servingUnit`) so the page
    //    shows a per-serving view instead of a bogus "per 100 g".
    // Micros are empty (FoodItem doesn't carry them), which renders as "not available".
    init(from item: FoodItem) {
        let unit = item.servingUnit.lowercased()
        let weightBased = (unit == "g" || unit == "ml") && item.servingSize > 0
        if weightBased {
            self.init(
                id: item.id, name: item.name, brand: item.brand, barcode: item.barcode,
                category: nil, source: FoodTrust(item.source),
                servingQuantity: item.servingSize,
                basisUnit: (unit == "ml") ? "ml" : "g",
                per100: item.nutrients.scaled(by: 100 / item.servingSize),
                micros: .empty
            )
        } else {
            self.init(
                id: item.id, name: item.name, brand: item.brand, barcode: item.barcode,
                category: nil, source: FoodTrust(item.source),
                servingQuantity: nil, basisUnit: "g",
                per100: item.nutrients,           // per one serving in count mode
                micros: .empty,
                servingUnit: item.servingUnit
            )
        }
    }
}
