import SwiftUI

// Claude  Date 07/14/2026 last changed: 08/04/2026 by: Claude
// Display face of a food's ORIGIN — one badge per case, drawn by FoodSourceBadge.
// `verified` (Agil's curated vault) gets the brand-pink Agil mark; the rest get a
// tinted symbol capsule. The second provenance axis (has a human vouched for the
// numbers?) is `FoodVerification`, rendered as a separate stacked badge — a
// `generic` or `restaurant` food shows both. (Was origin-only with three cases;
// `generic`/`restaurant` were added alongside the two-axis model.)
enum FoodTrust: String, Codable, Hashable {
    case verified
    case openFoodFacts
    case generic
    case restaurant
    case userSubmitted
    case recipe

    var label: String {
        switch self {
        case .verified:      return "Verified"
        case .openFoodFacts: return "Open Food Facts"
        case .generic:       return "Generic"
        case .restaurant:    return "Restaurant"
        case .userSubmitted: return "My food"
        case .recipe:        return "Recipe"
        }
    }

    var systemImage: String {
        switch self {
        case .verified:      return "checkmark.seal.fill"
        case .openFoodFacts: return "globe"
        case .generic:       return "basket.fill"
        case .restaurant:    return "fork.knife"
        case .userSubmitted: return "person.crop.circle"
        case .recipe:        return "list.bullet.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .verified:      return FoodSourcePalette.verified
        case .openFoodFacts: return FoodSourcePalette.openFoodFacts
        case .generic:       return FoodSourcePalette.generic
        case .restaurant:    return FoodSourcePalette.restaurant
        case .userSubmitted: return FoodSourcePalette.userSubmitted
        case .recipe:        return FoodSourcePalette.recipe
        }
    }

    // Claude  Date 07/14/2026 last changed: 08/04/2026 by: Claude
    // Bridge from the library's FoodSource. Origin maps 1:1 — verification is NOT
    // folded in here (it's the other axis, carried on FoodDetail.verification), so
    // a verified restaurant food still reads as `restaurant` and stacks its
    // Verified badge rather than masquerading as vault-curated.
    init(_ source: FoodSource) {
        switch source {
        case .seed:          self = .verified
        case .openFoodFacts: self = .openFoodFacts
        case .usda:          self = .generic
        case .restaurant:    self = .restaurant
        case .custom:        self = .userSubmitted
        case .recipe:        self = .recipe
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
    // Claude  Date 08/07/2026
    // The backend's raw id string, carried from FoodItem.remoteId so a correction can
    // name the exact server row rather than the derived local UUID. nil for foods whose
    // id already is a real server UUID, and for hand-entered foods. See FoodItem.remoteId.
    var remoteId: String?
    // Comma-separated, most-general term first, or nil (always nil for verified foods
    // today). Mapped to an icon via `categoryIcon`.
    var category: String?
    var source: FoodTrust
    // Claude  Date 08/04/2026
    // Second provenance axis — see FoodVerification. nil = unknown (no stacked badge).
    var verification: FoodVerification?
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
         remoteId: String? = nil, category: String? = nil, source: FoodTrust,
         verification: FoodVerification? = nil, servingQuantity: Double? = nil,
         basisUnit: String = "g", per100: Nutrients, micros: Micros = .empty,
         servingUnit: String? = nil) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.remoteId = remoteId
        self.category = category
        self.source = source
        self.verification = verification
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
    // Category and micros now come straight off the FoodItem when the backend sent
    // them (they used to be hardcoded empty here, so every networked food showed a
    // blank micronutrient block and a "Food" category chip); a hand-entered food
    // still has neither, which renders as "not available".
    //
    // ⚠️ Basis mismatch to keep straight: FoodItem.nutrients are per `servingSize`
    // (hence the scale to per-100 below), but `micros` are taken as ALREADY per-100
    // — that's what FoodDetail documents and what the backend contract requires.
    // Micros are passed through unscaled; if the backend ever sends them per-serving
    // they'd render wrong, so that requirement is spelled out in
    // backend_food_sources_contract.md rather than guessed at here.
    // (last changed 08/04/2026 by Claude: category/micros/verification passthrough.)
    init(from item: FoodItem) {
        // Resolve the serving unit to a weight/volume FoodUnit when we can. This used to
        // only match the two literals "g"/"ml"; every other spelling ("oz", "grams",
        // "cup", "fl oz") fell through to the count path, which was wrong now that FoodUnit
        // exists. An unrecognized unit ("bar", "slice") is a real count food and still does.
        if let unit = FoodUnit(userInput: item.servingUnit), item.servingSize > 0 {
            // One serving expressed in the family's base unit (g or mL). For g/mL this is
            // just the serving size (perBase 1); for oz/lb/cup/fl oz it converts, so a
            // "2 oz" serving becomes a 56.7 g weight food whose detail page still offers oz.
            let baseAmount = item.servingSize * unit.perBase
            self.init(
                id: item.id, name: item.name, brand: item.brand, barcode: item.barcode,
                remoteId: item.remoteId,
                category: item.category, source: FoodTrust(item.source),
                verification: item.verification,
                servingQuantity: item.servingQuantity ?? baseAmount,
                basisUnit: unit.isVolume ? "ml" : "g",
                per100: item.nutrients.scaled(by: 100 / baseAmount),
                micros: item.micros ?? .empty
            )
        } else {
            self.init(
                id: item.id, name: item.name, brand: item.brand, barcode: item.barcode,
                remoteId: item.remoteId,
                category: item.category, source: FoodTrust(item.source),
                verification: item.verification,
                servingQuantity: nil, basisUnit: "g",
                per100: item.nutrients,           // per one serving in count mode
                micros: item.micros ?? .empty,
                servingUnit: item.servingUnit
            )
        }
    }
}
