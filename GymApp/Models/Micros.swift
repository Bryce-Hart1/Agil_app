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
// derived:
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
enum MicroGroup: String, CaseIterable, Identifiable {
    case fats = "Fats & cholesterol"
    case vitamins = "Vitamins"
    case minerals = "Minerals"
    var id: String { rawValue }
}

// Claude  Date 07/14/2026
// One displayable micro: its human label, its hardcoded unit, which group it lives in,
// and a getter onto the raw per-100 value. The cryptic keys (vBOne, vBTwelve, …) get
// their real names here so the view never has to know the mapping. Order within `all`
// is the render order.
struct MicroField: Identifiable {
    let label: String
    let unit: String            // "g" | "mg" | "µg" | "ng" — fixed per field, never derived
    let group: MicroGroup
    let value: (Micros) -> Double?
    var id: String { label }

    static let all: [MicroField] = [
        // Fats & cholesterol
        .init(label: "Saturated fat",        unit: "g",  group: .fats, value: { $0.saturFat }),
        .init(label: "Trans fat",            unit: "g",  group: .fats, value: { $0.transFat }),
        .init(label: "Monounsaturated fat",  unit: "g",  group: .fats, value: { $0.monosatFat }),
        .init(label: "Cholesterol",          unit: "mg", group: .fats, value: { $0.cholesterolMg }),
        // Vitamins
        .init(label: "Vitamin A",            unit: "µg", group: .vitamins, value: { $0.vA }),
        .init(label: "Vitamin C",            unit: "mg", group: .vitamins, value: { $0.vC }),
        .init(label: "Vitamin D",            unit: "µg", group: .vitamins, value: { $0.vD }),
        .init(label: "Vitamin E",            unit: "mg", group: .vitamins, value: { $0.vE }),
        .init(label: "Vitamin K",            unit: "µg", group: .vitamins, value: { $0.vK }),
        .init(label: "B1 · Thiamin",         unit: "µg", group: .vitamins, value: { $0.vBOne }),
        .init(label: "B2 · Riboflavin",      unit: "µg", group: .vitamins, value: { $0.vBTwo }),
        .init(label: "B3 · Niacin",          unit: "µg", group: .vitamins, value: { $0.vBThree }),
        .init(label: "B5 · Pantothenic acid", unit: "µg", group: .vitamins, value: { $0.vBFive }),
        .init(label: "B6",                   unit: "µg", group: .vitamins, value: { $0.vBSix }),
        .init(label: "B7 · Biotin",          unit: "µg", group: .vitamins, value: { $0.vBSeven }),
        .init(label: "B9 · Folate",          unit: "µg", group: .vitamins, value: { $0.vBNine }),
        .init(label: "B12",                  unit: "ng", group: .vitamins, value: { $0.vBTwelve }),
        .init(label: "Choline",              unit: "mg", group: .vitamins, value: { $0.choline }),
        // Minerals
        .init(label: "Calcium",              unit: "mg", group: .minerals, value: { $0.calcium }),
        .init(label: "Chloride",             unit: "mg", group: .minerals, value: { $0.chloride }),
        .init(label: "Chromium",             unit: "µg", group: .minerals, value: { $0.chromium }),
        .init(label: "Copper",               unit: "µg", group: .minerals, value: { $0.copper }),
        .init(label: "Fluoride",             unit: "mg", group: .minerals, value: { $0.fluoride }),
        .init(label: "Iodine",               unit: "µg", group: .minerals, value: { $0.iodine }),
        .init(label: "Iron",                 unit: "µg", group: .minerals, value: { $0.iron }),
        .init(label: "Magnesium",            unit: "mg", group: .minerals, value: { $0.magnesium }),
        .init(label: "Manganese",            unit: "µg", group: .minerals, value: { $0.manganese }),
        .init(label: "Molybdenum",           unit: "µg", group: .minerals, value: { $0.molybdenum }),
        .init(label: "Phosphorus",           unit: "mg", group: .minerals, value: { $0.phosphorus }),
        .init(label: "Potassium",            unit: "mg", group: .minerals, value: { $0.potassium }),
        .init(label: "Selenium",             unit: "µg", group: .minerals, value: { $0.selenium }),
        .init(label: "Zinc",                 unit: "mg", group: .minerals, value: { $0.zinc }),
    ]

    static func fields(in group: MicroGroup) -> [MicroField] {
        all.filter { $0.group == group }
    }
}
