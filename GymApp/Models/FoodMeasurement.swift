import Foundation

// Claude  Date 08/06/2026 Peer reviewed 08/06/2026
// The measurement vocabulary for logging food amounts, in one place. Two families:
// weight (g/oz/lb) for solids and volume (cup/fl oz/mL) for liquids — which family a
// food gets is decided by its per-100 basis unit ("g" vs "ml"). There is deliberately
// NO conversion across families: weight↔volume needs a density we don't have, and a
// silently-wrong cup of oil is worse than no cup at all.
//
// ⚠️ Codable contract: the raw values below are stored in nutrition_log.json (on every
// FoodEntry's measurement) and food_measurements.json. They are FROZEN — an unknown
// raw value fails the decode of the whole file and PersistenceService silently resets
// it to empty. Only ever ADD cases; never rename or remove one.
enum FoodUnit: String, Codable, Hashable, CaseIterable {
    // Weight family (basis unit "g")
    case gram = "g"
    case ounce = "oz"
    case pound = "lb"
    // Volume family (basis unit "ml")
    case cup = "cup"
    case fluidOunce = "floz"
    case milliliter = "ml"

    // Claude  Date 08/06/2026
    // Grams (weight) or milliliters (volume) in ONE of this unit — the bridge to the
    // app's per-100 nutrient basis. These are also the app's canonical conversion
    // constants: before this file, three slightly different cup/fl-oz values lived in
    // FoodDetailView, WaterEntry and the diary's quick-adds. The cup is the US "legal"
    // 240 ml nutrition labels use, not the customary 236.588.
    var perBase: Double {
        switch self {
        case .gram:       return 1
        case .ounce:      return 28.3495
        case .pound:      return 453.592
        case .cup:        return 240
        case .fluidOunce: return 29.5735
        case .milliliter: return 1
        }
    }

    var isVolume: Bool {
        switch self {
        case .cup, .fluidOunce, .milliliter: return true
        case .gram, .ounce, .pound:          return false
        }
    }

    // Display form — the raw value is the wire form ("floz" has no space so it stays
    // a stable identifier; the label is what humans read).
    var abbreviation: String {
        switch self {
        case .gram:       return "g"
        case .ounce:      return "oz"
        case .pound:      return "lb"
        case .cup:        return "cup"
        case .fluidOunce: return "fl oz"
        case .milliliter: return "mL"
        }
    }

    // The unit word next to an amount. Only "cup" is a countable English noun; the
    // rest are symbols that never pluralize.
    func label(count: Double) -> String {
        self == .cup && count != 1 ? "cups" : abbreviation
    }

    // Claude  Date 08/06/2026
    // Decimal places an amount is rounded to when it ARRIVES in this unit via a
    // conversion (chip tap / tab switch). Typed input is never rounded — this only
    // keeps 100 g from becoming 3.5274 oz. Coarser units need more places to stay
    // honest (0.25 lb is a real amount; 0 oz of precision would make 100 g "4 oz").
    var displayPrecision: Int {
        switch self {
        case .gram, .milliliter:  return 0
        case .ounce, .fluidOunce: return 1
        case .pound, .cup:        return 2
        }
    }

    // The unit family a food offers, from its per-100 basis unit.
    static func family(forBasisUnit unit: String) -> [FoodUnit] {
        unit == "ml" ? [.cup, .fluidOunce, .milliliter] : [.gram, .ounce, .pound]
    }

    // The family's base unit — what the per-100 values are actually measured in.
    static func baseUnit(forBasisUnit unit: String) -> FoodUnit {
        unit == "ml" ? .milliliter : .gram
    }

    // Claude  Date 08/06/2026
    // In-family conversion; nil across families (no density). Exact — rounding is the
    // caller's job via `displayPrecision`.
    func convert(_ amount: Double, to other: FoodUnit) -> Double? {
        guard isVolume == other.isVolume else { return nil }
        return amount * perBase / other.perBase
    }

    // Claude  Date 08/07/2026
    // Resolve a free-typed serving unit ("grams", "OZ", "fl. oz.", "Cups") to a canonical
    // weight/volume FoodUnit. Used when a hand-entered food's unit is free text: without
    // this, anything but the two literals "g"/"ml" silently became a count food, so typing
    // "oz" produced a countable-servings food instead of a weight one. Returns nil for a
    // genuine count unit ("bar", "slice", "scoop") — the caller keeps that as an opaque
    // serving noun. Case/space/period-insensitive; covers the common spellings and plurals,
    // not every conceivable one.
    init?(userInput raw: String) {
        let key = raw.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespaces)
        switch key {
        case "g", "gram", "grams", "gramme", "grammes":
            self = .gram
        case "oz", "ounce", "ounces":
            self = .ounce
        case "lb", "lbs", "pound", "pounds":
            self = .pound
        case "cup", "cups":
            self = .cup
        case "floz", "fl oz", "fluid ounce", "fluid ounces", "fluidounce", "fluidounces":
            self = .fluidOunce
        case "ml", "mls", "milliliter", "milliliters", "millilitre", "millilitres", "cc":
            self = .milliliter
        default:
            return nil
        }
    }
}

// Claude  Date 08/06/2026
// One dialed-in amount, as the user expressed it: "200 g", "2 cups", "1.5 servings".
// Lives in two places —
//  • on FoodEntry, so the diary can show what was actually logged instead of the old
//    hardcoded "1× serving";
//  • in AppStore.lastMeasurements keyed by food id, so re-opening a food seeds the
//    detail page with the user's last amount+unit (tracking speed: the second log of
//    a food should be two taps).
// `unit == nil` means serving/count mode; `servingNoun` then carries the noun the
// food counts in ("serving", "bar"). In unit mode the noun is nil.
struct FoodMeasurement: Codable, Hashable {
    var amount: Double
    var unit: FoodUnit?
    var servingNoun: String?

    // "200 g" / "2 cups" / "1.5 servings" / "2 bars".
    var displayText: String {
        let n = Self.compactNumber(amount)
        if let unit { return "\(n) \(unit.label(count: amount))" }
        return "\(n) \(Self.pluralize(servingNoun ?? "serving", count: amount))"
    }

    // Same unit/noun, scaled amount — how EditFoodEntryView's servings multiplier
    // stays honest ("1.5× of 200 g" displays as "300 g").
    func scaled(by factor: Double) -> FoodMeasurement {
        FoodMeasurement(amount: amount * factor, unit: unit, servingNoun: servingNoun)
    }

    // Claude  Date 08/06/2026
    // Whether a cached measurement still makes sense for this food — the food's
    // definition can change under the cache (a re-scan flips it to ml, a serving
    // size disappears). A mismatch silently falls back to defaults; never crash,
    // never show a wrong-family unit.
    func isValid(for basis: MeasurementBasis) -> Bool {
        guard amount > 0 else { return false }
        if let unit {
            guard !basis.isCountBased else { return false }
            return unit.isVolume == (basis.basisUnit == "ml")
        }
        return basis.servingQuantity != nil || basis.isCountBased
    }

    // Claude  Date 08/06/2026
    // The scale factor from a food's per-100 reference values to this amount — the one
    // piece of arithmetic that turns "2 cups" into nutrients. A unit converts through
    // its base (perBase is 1 for g/mL themselves); a serving is N × the serving's
    // weight; and for a count food per-100 already IS one serving, so the count is the
    // factor. Lives here rather than in a view so the detail page and the diary editor
    // can't disagree about what an amount means.
    func per100Factor(in basis: MeasurementBasis) -> Double {
        let amount = max(0, self.amount)
        if basis.isCountBased { return amount }
        if let unit { return amount * unit.perBase / 100 }
        return amount * (basis.servingQuantity ?? 100) / 100
    }

    // Claude  Date 08/06/2026
    // Naive pluralization for a serving noun ("bar" → "bars"); leaves an
    // already-plural noun alone. (Moved from FoodDetailView, which now calls this.)
    static func pluralize(_ noun: String, count: Double) -> String {
        guard count != 1, !noun.isEmpty, !noun.hasSuffix("s") else { return noun }
        return noun + "s"
    }

    // Claude  Date 08/06/2026 (was FoodDetailView.number, which now forwards here)
    // Compact amount: whole numbers show whole, fractional values keep up to
    // `decimals` places with trailing zeros trimmed. Keeps a real 0 as "0".
    // The default of 2 suits micros (0.9 µg is a real quantity); macros pass 1.
    static func number(_ value: Double, decimals: Int = 2) -> String {
        if value == value.rounded() && abs(value) < 1e12 {
            return String(Int(value.rounded()))
        }
        var s = String(format: "%.\(decimals)f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    private static func compactNumber(_ value: Double) -> String { number(value) }
}

// Claude  Date 08/06/2026
// A food's shape for the purposes of dialing an amount: its per-100 nutrients plus
// the three facts that decide which units and tabs it offers. Snapshotted onto a
// FoodEntry at log time so the diary's editor can re-dial the amount with the same
// controls the detail page used — without it, an edit can only multiply a frozen
// nutrient blob, which is how the old editor ended up calling a whole 250 g portion
// "one serving".
//
// `per100` holds ONE SERVING's nutrients in count mode, mirroring FoodDetail.per100.
struct MeasurementBasis: Codable, Hashable {
    var per100: Nutrients
    // "g" or "ml" — picks the weight or volume unit family.
    var basisUnit: String
    // Grams/ml in one serving; nil = no Serving tab (never fabricate one).
    var servingQuantity: Double?
    // Non-nil for a food measured in opaque servings ("bar", "cup") with no g/ml
    // weight — the only amount it can offer is a count.
    var servingUnit: String?

    var isCountBased: Bool { servingUnit != nil }

    init(per100: Nutrients, basisUnit: String, servingQuantity: Double? = nil,
         servingUnit: String? = nil) {
        self.per100 = per100
        self.basisUnit = basisUnit
        self.servingQuantity = servingQuantity
        self.servingUnit = servingUnit
    }

    init(_ food: FoodDetail) {
        self.init(per100: food.per100, basisUnit: food.basisUnit,
                  servingQuantity: food.servingQuantity, servingUnit: food.servingUnit)
    }

    // The amount a food opens on with no history to restore: one serving whenever that
    // means something, else a sensible amount of the base unit — the food has no
    // serving size to borrow, so 100 g / 250 ml it is.
    var defaultMeasurement: FoodMeasurement {
        if isCountBased {
            return FoodMeasurement(amount: 1, unit: nil, servingNoun: servingUnit)
        }
        if servingQuantity != nil {
            return FoodMeasurement(amount: 1, unit: nil, servingNoun: "serving")
        }
        return FoodMeasurement(amount: basisUnit == "ml" ? 250 : 100,
                               unit: FoodUnit.baseUnit(forBasisUnit: basisUnit))
    }
}
