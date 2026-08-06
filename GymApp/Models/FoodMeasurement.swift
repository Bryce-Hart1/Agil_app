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
    func isValid(for food: FoodDetail) -> Bool {
        guard amount > 0 else { return false }
        if let unit {
            guard !food.isCountBased else { return false }
            return unit.isVolume == (food.basisUnit == "ml")
        }
        return food.servingQuantity != nil || food.isCountBased
    }

    // Claude  Date 08/06/2026
    // Naive pluralization for a serving noun ("bar" → "bars"); leaves an
    // already-plural noun alone. (Moved from FoodDetailView, which now calls this.)
    static func pluralize(_ noun: String, count: Double) -> String {
        guard count != 1, !noun.isEmpty, !noun.hasSuffix("s") else { return noun }
        return noun + "s"
    }

    // Compact amount: whole numbers show whole, fractions keep up to 2 decimals with
    // trailing zeros trimmed (0.25 lb, 1.5 servings).
    private static func compactNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e12 {
            return String(Int(value.rounded()))
        }
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
