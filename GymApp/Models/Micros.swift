import Foundation

// Claude  Date 07/14/2026
// The micronutrient payload from the food backend's FoodItemDto. Every key is
// always present in the JSON but almost all values are null (Open Food Facts rarely
// carries micros), so every field is optional: nil means "not available" (render as
// "—"), while a real 0.0 is a genuine measured zero.
//
// Like the macro Nutrients, these are measured PER 100 g/ml. For a "1 serving" view,
// scale each value by servingQuantity / 100.
//
// Units are FIXED PER FIELD (not uniform) — hardcoded on each MicroField below, never
// derived. (08/18: the new-food form can DISPLAY a field in another unit — see
// MicroUnit — but what lands in this struct is always the field's canonical unit.)
//   grams: saturFat, transFat, monosatFat
//   mg:    cholesterolMg, vC, choline, vE, calcium, chloride, fluoride, magnesium,
//          phosphorus, potassium, zinc
//   µg:    vA, vBOne, vBTwo, vBThree, vBFive, vBSix, vBSeven, vBNine, vD, vK,
//          chromium, copper, iodine, iron, manganese, molybdenum, selenium
//   ng:    vBTwelve
struct Micros: Codable, Hashable {
    // Fats & cholesterol
    var saturFat: Double?
    var transFat: Double?
    var monosatFat: Double?
    var cholesterolMg: Double?
    // Vitamins
    var vA: Double?
    var vC: Double?
    var vD: Double?
    var vE: Double?
    var vK: Double?
    var vBOne: Double?
    var vBTwo: Double?
    var vBThree: Double?
    var vBFive: Double?
    var vBSix: Double?
    var vBSeven: Double?
    var vBNine: Double?
    var vBTwelve: Double?
    var choline: Double?
    // Minerals
    var calcium: Double?
    var chloride: Double?
    var chromium: Double?
    var copper: Double?
    var fluoride: Double?
    var iodine: Double?
    var iron: Double?
    var magnesium: Double?
    var manganese: Double?
    var molybdenum: Double?
    var phosphorus: Double?
    var potassium: Double?
    var selenium: Double?
    var zinc: Double?

    // Claude  Date 07/14/2026
    // All-nil payload — used for foods that carry no micro data yet (e.g. the current
    // FoodItem library, which predates this field) so the detail page can still render
    // everything as "not available".
    static let empty = Micros()

    // Explicit defaults so `Micros()` / `.empty` and hand-built samples compile without
    // spelling out all 31 fields. Synthesized Codable decodes any missing/null key to nil.
    init(saturFat: Double? = nil, transFat: Double? = nil, monosatFat: Double? = nil,
         cholesterolMg: Double? = nil, vA: Double? = nil, vC: Double? = nil,
         vD: Double? = nil, vE: Double? = nil, vK: Double? = nil, vBOne: Double? = nil,
         vBTwo: Double? = nil, vBThree: Double? = nil, vBFive: Double? = nil,
         vBSix: Double? = nil, vBSeven: Double? = nil, vBNine: Double? = nil,
         vBTwelve: Double? = nil, choline: Double? = nil, calcium: Double? = nil,
         chloride: Double? = nil, chromium: Double? = nil, copper: Double? = nil,
         fluoride: Double? = nil, iodine: Double? = nil, iron: Double? = nil,
         magnesium: Double? = nil, manganese: Double? = nil, molybdenum: Double? = nil,
         phosphorus: Double? = nil, potassium: Double? = nil, selenium: Double? = nil,
         zinc: Double? = nil) {
        self.saturFat = saturFat; self.transFat = transFat; self.monosatFat = monosatFat
        self.cholesterolMg = cholesterolMg
        self.vA = vA; self.vC = vC; self.vD = vD; self.vE = vE; self.vK = vK
        self.vBOne = vBOne; self.vBTwo = vBTwo; self.vBThree = vBThree; self.vBFive = vBFive
        self.vBSix = vBSix; self.vBSeven = vBSeven; self.vBNine = vBNine; self.vBTwelve = vBTwelve
        self.choline = choline
        self.calcium = calcium; self.chloride = chloride; self.chromium = chromium
        self.copper = copper; self.fluoride = fluoride; self.iodine = iodine; self.iron = iron
        self.magnesium = magnesium; self.manganese = manganese; self.molybdenum = molybdenum
        self.phosphorus = phosphorus; self.potassium = potassium; self.selenium = selenium
        self.zinc = zinc
    }
}

// Claude  Date 07/14/2026
// The three display buckets the detail page groups micros into.
// Claude  Date 08/18/2026
// A mass unit a micronutrient can be written in. Nutrition labels are inconsistent —
// the same vitamin shows up as mg on one package and µg on another — so the entry form
// lets each row be typed in whichever unit the label in your hand uses, and converts.
//
// Shaped after FoodUnit: the unit owns its own factor and does its own conversion, so
// nothing outside this enum hardcodes a 1000. Note the app spells micrograms "µg"
// (U+00B5) everywhere, never "mcg".
//
// This is a DISPLAY unit only. What's stored in Micros is always MicroField.unit — the
// wire mapping (offFactor) is pinned to that, so a converted value has to land back in
// the canonical unit before it's saved.
enum MicroUnit: String, Codable, CaseIterable, Identifiable {
    case g = "g"
    case mg = "mg"
    case mcg = "µg"
    case ng = "ng"

    var id: String { rawValue }
    var abbreviation: String { rawValue }

    /// How many grams one of this unit is — the shared base every conversion goes through.
    var gramsPerUnit: Double {
        switch self {
        case .g:   return 1
        case .mg:  return 1e-3
        case .mcg: return 1e-6
        case .ng:  return 1e-9
        }
    }

    func convert(_ value: Double, to other: MicroUnit) -> Double {
        guard self != other else { return value }
        return value * gramsPerUnit / other.gramsPerUnit
    }

    // Claude  Date 08/18/2026
    // Float noise control: 0.9 µg → mg is 0.0009000000000000001 in binary floating point,
    // and that would land in a text field the user is looking at. Rounded to 9 decimals,
    // which is finer than any real nutrition label and coarse enough to kill the fuzz.
    // Values too small to survive that rounding keep their exact conversion rather than
    // collapsing to 0 — a nanogram written in grams is still a real quantity.
    func rounded(_ value: Double) -> Double {
        let scaled = (value * 1e9).rounded() / 1e9
        return scaled == 0 && value != 0 ? value : scaled
    }
}

enum MicroGroup: String, CaseIterable, Identifiable {
    case fats = "Fats & cholesterol"
    case vitamins = "Vitamins"
    case minerals = "Minerals"
    var id: String { rawValue }
}

// Claude  Date 07/14/2026 last changed: 08/04/2026 by: Claude
// One displayable micro: its human label, its hardcoded unit, which group it lives in,
// and the key path to the raw per-100 value. The cryptic keys (vBOne, vBTwelve, …) get
// their real names here so the view never has to know the mapping. Order within `all`
// is the render order.
//
// (The read-only getter became a WritableKeyPath so the same table can drive the
// new-food FORM as well as the detail page's read-out — one list of 32 nutrients, not
// two that can drift. `offKey`/`offFactor` describe how the field crosses the wire on
// submission: the backend's MICRO_MAP takes Open Food Facts keys in OFF's own base
// unit, so the value we display is DIVIDED by `offFactor` on the way out and the
// server multiplies it back. E.g. vitamin C displays in mg, travels as grams ×1/1000.)
struct MicroField: Identifiable {
    let label: String
    // The CANONICAL unit: what's stored in Micros and what offFactor is pinned to. The
    // entry form can display a field in another unit (see MicroUnit) but always converts
    // back to this one before storing, so the wire mapping below never has to move.
    let unit: MicroUnit
    let group: MicroGroup
    let key: WritableKeyPath<Micros, Double?>
    let offKey: String          // Open Food Facts nutriment key, e.g. "vitamin-c_100g"
    let offFactor: Double       // display unit = OFF value × offFactor (mirrors MICRO_MAP)
    var id: String { label }

    /// The per-100 value for this field, in `unit`.
    func value(_ micros: Micros) -> Double? { micros[keyPath: key] }

    // Claude  Date 08/07/2026
    // Whether this micro counts as reported for the user. A nil value is "not available",
    // and a genuine 0 (backend/OFF foods routinely send `trans-fat: 0`, `cholesterol: 0`)
    // is treated the same way — the detail page hides both rather than printing "0 g",
    // which reads as noise, not information. Single source of truth so the detail page's
    // show filter and the correction card's "N not reported" count can't disagree.
    func isReported(in micros: Micros) -> Bool {
        guard let v = value(micros) else { return false }
        return v > 0
    }

    static let all: [MicroField] = [
        // Fats & cholesterol
        .init(label: "Saturated fat",        unit: .g,  group: .fats, key: \.saturFat,
              offKey: "saturated-fat_100g", offFactor: 1),
        .init(label: "Trans fat",            unit: .g,  group: .fats, key: \.transFat,
              offKey: "trans-fat_100g", offFactor: 1),
        .init(label: "Monounsaturated fat",  unit: .g,  group: .fats, key: \.monosatFat,
              offKey: "monounsaturated-fat_100g", offFactor: 1),
        .init(label: "Cholesterol",          unit: .mg, group: .fats, key: \.cholesterolMg,
              offKey: "cholesterol_100g", offFactor: 1_000),
        // Vitamins
        .init(label: "Vitamin A",            unit: .mcg, group: .vitamins, key: \.vA,
              offKey: "vitamin-a_100g", offFactor: 1_000_000),
        .init(label: "Vitamin C",            unit: .mg, group: .vitamins, key: \.vC,
              offKey: "vitamin-c_100g", offFactor: 1_000),
        .init(label: "Vitamin D",            unit: .mcg, group: .vitamins, key: \.vD,
              offKey: "vitamin-d_100g", offFactor: 1_000_000),
        .init(label: "Vitamin E",            unit: .mg, group: .vitamins, key: \.vE,
              offKey: "vitamin-e_100g", offFactor: 1_000),
        .init(label: "Vitamin K",            unit: .mcg, group: .vitamins, key: \.vK,
              offKey: "vitamin-k_100g", offFactor: 1_000_000),
        .init(label: "B1 · Thiamin",         unit: .mcg, group: .vitamins, key: \.vBOne,
              offKey: "vitamin-b1_100g", offFactor: 1_000_000),
        .init(label: "B2 · Riboflavin",      unit: .mcg, group: .vitamins, key: \.vBTwo,
              offKey: "vitamin-b2_100g", offFactor: 1_000_000),
        .init(label: "B3 · Niacin",          unit: .mcg, group: .vitamins, key: \.vBThree,
              offKey: "vitamin-pp_100g", offFactor: 1_000_000),
        .init(label: "B5 · Pantothenic acid", unit: .mcg, group: .vitamins, key: \.vBFive,
              offKey: "pantothenic-acid_100g", offFactor: 1_000_000),
        .init(label: "B6",                   unit: .mcg, group: .vitamins, key: \.vBSix,
              offKey: "vitamin-b6_100g", offFactor: 1_000_000),
        .init(label: "B7 · Biotin",          unit: .mcg, group: .vitamins, key: \.vBSeven,
              offKey: "biotin_100g", offFactor: 1_000_000),
        .init(label: "B9 · Folate",          unit: .mcg, group: .vitamins, key: \.vBNine,
              offKey: "vitamin-b9_100g", offFactor: 1_000_000),
        .init(label: "B12",                  unit: .ng, group: .vitamins, key: \.vBTwelve,
              offKey: "vitamin-b12_100g", offFactor: 1_000_000_000),
        .init(label: "Choline",              unit: .mg, group: .vitamins, key: \.choline,
              offKey: "choline_100g", offFactor: 1_000),
        // Minerals
        .init(label: "Calcium",              unit: .mg, group: .minerals, key: \.calcium,
              offKey: "calcium_100g", offFactor: 1_000),
        .init(label: "Chloride",             unit: .mg, group: .minerals, key: \.chloride,
              offKey: "chloride_100g", offFactor: 1_000),
        .init(label: "Chromium",             unit: .mcg, group: .minerals, key: \.chromium,
              offKey: "chromium_100g", offFactor: 1_000_000),
        .init(label: "Copper",               unit: .mcg, group: .minerals, key: \.copper,
              offKey: "copper_100g", offFactor: 1_000_000),
        .init(label: "Fluoride",             unit: .mg, group: .minerals, key: \.fluoride,
              offKey: "fluoride_100g", offFactor: 1_000),
        .init(label: "Iodine",               unit: .mcg, group: .minerals, key: \.iodine,
              offKey: "iodine_100g", offFactor: 1_000_000),
        .init(label: "Iron",                 unit: .mcg, group: .minerals, key: \.iron,
              offKey: "iron_100g", offFactor: 1_000_000),
        .init(label: "Magnesium",            unit: .mg, group: .minerals, key: \.magnesium,
              offKey: "magnesium_100g", offFactor: 1_000),
        .init(label: "Manganese",            unit: .mcg, group: .minerals, key: \.manganese,
              offKey: "manganese_100g", offFactor: 1_000_000),
        .init(label: "Molybdenum",           unit: .mcg, group: .minerals, key: \.molybdenum,
              offKey: "molybdenum_100g", offFactor: 1_000_000),
        .init(label: "Phosphorus",           unit: .mg, group: .minerals, key: \.phosphorus,
              offKey: "phosphorus_100g", offFactor: 1_000),
        .init(label: "Potassium",            unit: .mg, group: .minerals, key: \.potassium,
              offKey: "potassium_100g", offFactor: 1_000),
        .init(label: "Selenium",             unit: .mcg, group: .minerals, key: \.selenium,
              offKey: "selenium_100g", offFactor: 1_000_000),
        .init(label: "Zinc",                 unit: .mg, group: .minerals, key: \.zinc,
              offKey: "zinc_100g", offFactor: 1_000),
    ]

    // Claude  Date 08/04/2026
    // The micros block as the backend's `nutrimentsJson` blob: Open Food Facts keys in
    // OFF's own base unit (hence ÷ offFactor — the server multiplies it back through
    // MICRO_MAP). Only fields the user actually filled in are included; an absent key
    // reads back as "not available", which is meaningfully different from a stored 0.
    static func nutrimentsJSON(from micros: Micros) -> [String: Double] {
        var out: [String: Double] = [:]
        for field in all {
            guard let value = field.value(micros), field.offFactor > 0 else { continue }
            out[field.offKey] = value / field.offFactor
        }
        return out
    }

    // Claude  Date 08/18/2026
    // Every reported value multiplied by `factor`, nil kept as nil. Used to move a whole
    // Micros block between bases — per-serving as typed into the form, per-100 as stored
    // and as the backend expects. nil MUST survive: it means "not available", which is a
    // different statement from a measured 0 (see isReported).
    static func scaled(_ micros: Micros, by factor: Double) -> Micros {
        guard factor != 1 else { return micros }
        var out = micros
        for field in all {
            if let value = field.value(micros) {
                out[keyPath: field.key] = value * factor
            }
        }
        return out
    }

    static func fields(in group: MicroGroup) -> [MicroField] {
        all.filter { $0.group == group }
    }
}
