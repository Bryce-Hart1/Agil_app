import Foundation

// Claude  Date 06/16/2026 last changed: 08/04/2026 by: Claude
// Where a food in the library came from — the ORIGIN axis of provenance (the other
// axis is `FoodVerification` below; the two stack independently so a restaurant food
// can also be verified). `seed` = Agil's curated verified vault (rawValue kept as
// "seed" for wire/persistence compat — renaming buys nothing); `custom` = the user
// typed it in; `openFoodFacts` = fetched from the external API and cached locally;
// `usda` = generic staples imported from USDA FoodData Central; `restaurant` =
// user-submitted chain-restaurant foods. Origin is immutable — verification promotes
// the `verification` field, never rewrites `source` (OFF rows must keep their origin
// for ODbL attribution). Frozen on the FoodItem so the diary can show provenance and
// so we can dedupe API results against the cache.
enum FoodSource: String, Codable, Hashable {
    case seed
    case custom
    case openFoodFacts
    case usda
    case restaurant
    // Claude  Date 08/11/2026
    // A user-built recipe surfacing through the food pipeline (see Recipe.asFoodItem).
    // Never produced by `init(wireValue:)` — recipes are local-only and the backend has
    // no notion of them, so a "recipe" string on the wire would be a bug, not a case
    // to honor.
    case recipe

    // Claude  Date 08/04/2026
    // Tolerant wire mapping. The backend has stamped values this enum never had
    // ("verified" on vault hits, "userSubmitted" on submissions), and future values
    // must degrade gracefully rather than fail the whole decode — a food with a
    // misread origin beats no food at all. Unknown strings read as OFF, the least
    // trusted networked origin.
    init(wireValue: String?) {
        switch wireValue {
        case "seed", "verified", "agil":        self = .seed
        case "custom", "userSubmitted", "user": self = .custom
        case "usda", "generic":                 self = .usda
        case "restaurant":                      self = .restaurant
        default:                                self = .openFoodFacts
        }
    }
}

// Claude  Date 08/04/2026
// The VERIFICATION axis of provenance: has a human (Bryce, via the backend's
// pending → verify/reject pipeline) vouched for this record's numbers? Stacks with
// `FoodSource` — e.g. a restaurant food can be pending, then verified. nil (older
// records / backend not yet sending it) means "unknown" and renders no stacked badge.
enum FoodVerification: String, Codable, Hashable {
    case verified
    case pending
    case unverified
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
    // Claude  Date 08/07/2026
    // The backend's RAW id string, kept verbatim. `id` above is a UUID — for vault
    // hits the server sends a non-UUID id ("verified:{barcode}") that stableID hashes
    // into a derived local UUID, losing the original. This passthrough preserves it so
    // a correction can name the exact server row (see FoodCorrectionClient) instead of
    // making the backend re-resolve by barcode. nil for hand-entered foods and for rows
    // whose id already IS a real UUID (there `id` itself matches the server PK).
    var remoteId: String?
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
    // Claude  Date 08/04/2026
    // The stacked verification axis (see FoodVerification). nil = unknown/not sent.
    var verification: FoodVerification?
    // Claude  Date 08/04/2026
    // Wire fields the decoder used to silently drop (the backend has always sent
    // them). All optional — local hand-entered foods have none of these.
    //  • category: comma-separated, most-general term first (drives the detail
    //    page's category chip).
    //  • micros: per-100 micronutrients (sparse).
    //  • servingQuantity: grams/ml in one serving, for foods whose servingUnit is
    //    an opaque count ("cup", "bar") — lets the detail page keep a real basis.
    var category: String?
    var micros: Micros?
    var servingQuantity: Double?

    init(id: UUID = UUID(), name: String, brand: String = "", barcode: String? = nil,
         remoteId: String? = nil, servingSize: Double = 100, servingUnit: String = "g",
         nutrients: Nutrients = .zero, source: FoodSource = .custom,
         verification: FoodVerification? = nil, category: String? = nil,
         micros: Micros? = nil, servingQuantity: Double? = nil) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.remoteId = remoteId
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.nutrients = nutrients
        self.source = source
        self.verification = verification
        self.category = category
        self.micros = micros
        self.servingQuantity = servingQuantity
    }

    // Claude  Date 08/22/2026
    // What to PRINT for this food, as opposed to what's stored. See
    // String.foodDisplayCased at the bottom of this file for why these exist.
    var displayName: String { name.foodDisplayCased }
    var displayBrand: String { brand.foodDisplayCased }

    // Claude  Date 06/16/2026 last changed: 08/22/2026 by: Claude
    // Name with the brand appended when present, for list/search labels. Cased for
    // display — anything PERSISTING a label wants `snapshotLabel` instead.
    var displayLabel: String {
        displayBrand.trimmingCharacters(in: .whitespaces).isEmpty
            ? displayName : "\(displayName) · \(displayBrand)"
    }

    // Claude  Date 08/22/2026
    // The same label with the stored casing left alone, for the three places that FREEZE
    // a label into saved data: the diary entry snapshot, logFoodDetail, and a recipe
    // ingredient. Display casing is a rendering choice and this app's house style today;
    // baking it into nutrition_log.json / recipes.json would make it permanent and
    // un-revisable for every row written from here on. Those files keep what the source
    // actually said, and FoodEntry.displayName / RecipeIngredient.displayName case it on
    // the way out like everything else.
    var snapshotLabel: String {
        brand.trimmingCharacters(in: .whitespaces).isEmpty ? name : "\(name) · \(brand)"
    }

    // Claude  Date 08/18/2026
    // What to multiply PER-SERVING values by to get per-100, or nil when this food has no
    // per-100 basis at all. `nutrients` are stored per serving while `micros` are per-100
    // (see the field docs above), so anything writing micros from a per-serving form has
    // to cross that gap — and both sides of the app have to cross it the same way.
    //
    // The gram weight of a serving, not the serving NUMBER, is the basis: a "2 oz" serving
    // is 56.7 g, so the factor is 100/56.7, not 100/2. That mirrors how FoodDetail derives
    // `baseAmount`. A count serving ("bar", "slice") has no weight to work from — nil, and
    // FoodDetail correspondingly shows that food per serving rather than inventing a
    // per-100 view.
    var per100Factor: Double? {
        Self.per100Factor(servingSize: servingSize, servingUnit: servingUnit)
    }

    /// The same factor from a serving that isn't on a FoodItem yet — the new-food form
    /// needs it while it's still deciding what to save.
    static func per100Factor(servingSize: Double, servingUnit: String) -> Double? {
        guard let unit = FoodUnit(userInput: servingUnit), servingSize > 0 else { return nil }
        let baseAmount = servingSize * unit.perBase
        guard baseAmount > 0 else { return nil }
        return 100 / baseAmount
    }

    // Claude  Date 06/16/2026
    // "100 g" / "1 cup" — the reference serving as a human string.
    var servingLabel: String {
        let size = servingSize.rounded() == servingSize
            ? String(Int(servingSize)) : String(servingSize)
        return "\(size) \(servingUnit)"
    }

    // Claude  Date 06/16/2026 last changed: 08/04/2026 by: Claude
    // Forgiving decode so foods saved before a field existed (or sparse API
    // imports) still load. encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey {
        case id, name, brand, barcode, remoteId, servingSize, servingUnit, nutrients, source
        case verification, category, micros, servingQuantity
    }

    // Claude  Date 08/04/2026
    // The backend's curation flags, read-only on this side: they're folded into
    // `source` on decode (below) rather than stored, so they live in their own key
    // enum — putting them in CodingKeys would break the synthesized encoder, which
    // requires a property per case.
    private enum FlagKeys: String, CodingKey {
        case isRestaurant, isGeneric
    }

    // Claude  Date 08/04/2026
    // Backend ids aren't always UUIDs — verified-vault hits come back as
    // "verified:{barcode}". Decoding those as UUID threw and killed the whole
    // response, so a scan that hit the curated vault failed outright. Map a
    // non-UUID id to a DETERMINISTIC UUID derived from its bytes, so the same
    // remote food keeps the same local identity across searches (which is what
    // barcode/id dedupe and diary `foodId` links depend on). Must stay frozen —
    // changing the derivation duplicates every cached vault food.
    private static func stableID(from raw: String) -> UUID {
        if let real = UUID(uuidString: raw) { return real }
        // FNV-1a over the raw id, twice with different offsets, for 16 bytes.
        func fnv(_ seed: UInt64) -> UInt64 {
            var hash = seed
            for byte in raw.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 1_099_511_628_211
            }
            return hash
        }
        var bytes = withUnsafeBytes(of: fnv(14_695_981_039_346_656_037).bigEndian, Array.init)
        bytes += withUnsafeBytes(of: fnv(1_469_598_103_934_665_603).bigEndian, Array.init)
        // Stamp RFC-4122 version 4 / variant bits so it's a well-formed UUID.
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5],
                           bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id: UUID when it is one, otherwise a stable derivation (see stableID). In the
        // derived case the raw non-UUID string IS the server id, so keep it as remoteId;
        // an explicit remoteId key (our own re-persisted foods) wins when present.
        if let uuid = try? c.decode(UUID.self, forKey: .id) {
            id = uuid
            remoteId = try c.decodeIfPresent(String.self, forKey: .remoteId)
        } else {
            let raw = try c.decode(String.self, forKey: .id)
            id = Self.stableID(from: raw)
            remoteId = try c.decodeIfPresent(String.self, forKey: .remoteId) ?? raw
        }
        name = try c.decode(String.self, forKey: .name)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        barcode = try c.decodeIfPresent(String.self, forKey: .barcode)
        servingSize = try c.decodeIfPresent(Double.self, forKey: .servingSize) ?? 100
        servingUnit = try c.decodeIfPresent(String.self, forKey: .servingUnit) ?? "g"
        nutrients = try c.decodeIfPresent(Nutrients.self, forKey: .nutrients) ?? .zero
        // source/verification decode via raw strings: an unrecognized case must
        // degrade, never throw (see FoodSource.init(wireValue:)).
        //
        // Claude  Date 08/04/2026
        // The backend models "restaurant" and "generic" as BOOLEAN curation flags
        // alongside `source` (a submitted restaurant food is
        // source:"userSubmitted" + isRestaurant:true), not as source values. The
        // client keeps one origin enum for display, so the flags win when set —
        // they're the more specific statement about what the food is.
        let rawSource = try c.decodeIfPresent(String.self, forKey: .source)
        let flags = try decoder.container(keyedBy: FlagKeys.self)
        let isRestaurant = try flags.decodeIfPresent(Bool.self, forKey: .isRestaurant) ?? false
        let isGeneric = try flags.decodeIfPresent(Bool.self, forKey: .isGeneric) ?? false
        if isRestaurant {
            source = .restaurant
        } else if isGeneric {
            source = .usda
        } else {
            source = rawSource == nil ? .custom : FoodSource(wireValue: rawSource)
        }
        verification = (try c.decodeIfPresent(String.self, forKey: .verification))
            .flatMap(FoodVerification.init(rawValue:))
        category = try c.decodeIfPresent(String.self, forKey: .category)
        micros = try c.decodeIfPresent(Micros.self, forKey: .micros)
        servingQuantity = try c.decodeIfPresent(Double.self, forKey: .servingQuantity)
    }
}

// Claude  Date 08/22/2026
// Case normalization for food names, in one place. Names reach the app title-cased from
// the backend ("Chicken Burrito Bowl"), however OFF's contributors felt that day, and
// free-form from the user's own keyboard — so the same shelf can read three ways down
// one list. Lowercase is the house style.
//
// The real fix is normalization in the DB; this is the net for whatever slips through,
// and it is DISPLAY-ONLY. Nothing stored, submitted or corrected goes through here: what
// the user typed is what the server should receive, and keeping the stored value intact
// is what makes this reversible once the DB side lands.
extension String {
    var foodDisplayCased: String { lowercased() }
}
