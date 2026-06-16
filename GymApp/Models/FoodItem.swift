import Foundation

// Claude  Date 06/16/2026
// Where a food in the library came from. `seed` = shipped in the starter library;
// `custom` = the user typed it in; `openFoodFacts` = fetched from the external API
// and cached locally so it works offline next time. Frozen on the FoodItem so the
// diary can show provenance and so we can dedupe API results against the cache.
enum FoodSource: String, Codable, Hashable {
    case seed
    case custom
    case openFoodFacts
}

/// A food (or branded product) in the reusable food library — the nutrition analog
/// of `Exercise`. Logged diary entries (`FoodEntry`) reference it by `id`, but also
/// snapshot its nutrients at log time, so editing or losing this record never
/// rewrites past history.
struct FoodItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    // Claude  Date 06/16/2026
    // Optional brand/manufacturer ("Chobani"), shown as a subtitle in search. Empty
    // for generic foods.
    var brand: String
    // Claude  Date 06/16/2026
    // Product barcode (EAN/UPC) when this came from a scan / Open Food Facts. The
    // dedupe key for cached API foods — nil for hand-entered generics.
    var barcode: String?
    // Claude  Date 06/16/2026
    // The reference serving the `nutrients` are measured against, e.g. size 100,
    // unit "g", or size 1 unit "cup". A logged entry records how many of THIS
    // serving were eaten.
    var servingSize: Double
    var servingUnit: String
    // Per-`servingSize` nutrients (see Nutrients for canonical units).
    var nutrients: Nutrients
    // Whether this was hand-entered or pulled from Open Food Facts.
    var source: FoodSource

    init(id: UUID = UUID(), name: String, brand: String = "", barcode: String? = nil,
         servingSize: Double = 100, servingUnit: String = "g",
         nutrients: Nutrients = .zero, source: FoodSource = .custom) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.nutrients = nutrients
        self.source = source
    }

    // Claude  Date 06/16/2026
    // Name with the brand appended when present, for list/search labels.
    var displayLabel: String {
        brand.trimmingCharacters(in: .whitespaces).isEmpty ? name : "\(name) · \(brand)"
    }

    // Claude  Date 06/16/2026
    // "100 g" / "1 cup" — the reference serving as a human string.
    var servingLabel: String {
        let size = servingSize.rounded() == servingSize
            ? String(Int(servingSize)) : String(servingSize)
        return "\(size) \(servingUnit)"
    }

    // Claude  Date 06/16/2026
    // Forgiving decode so foods saved before a field existed (or sparse API
    // imports) still load. encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey {
        case id, name, brand, barcode, servingSize, servingUnit, nutrients, source
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        barcode = try c.decodeIfPresent(String.self, forKey: .barcode)
        servingSize = try c.decodeIfPresent(Double.self, forKey: .servingSize) ?? 100
        servingUnit = try c.decodeIfPresent(String.self, forKey: .servingUnit) ?? "g"
        nutrients = try c.decodeIfPresent(Nutrients.self, forKey: .nutrients) ?? .zero
        source = try c.decodeIfPresent(FoodSource.self, forKey: .source) ?? .custom
    }
}
