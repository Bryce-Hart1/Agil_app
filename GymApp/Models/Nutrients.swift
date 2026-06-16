import Foundation

// Claude  Date 06/16/2026
// The macro/micro payload shared by every nutrition type: it describes the
// nutrients in "one serving" of a FoodItem, and — scaled and summed — the totals
// for a logged entry or a whole day. Kept as one reusable value type (rather than
// loose fields) so addition and serving-scaling live in one place.
//
// Canonical units (matching Open Food Facts, the external food source):
//   calories  kcal
//   protein / carbs / fat / fiber / sugar  grams (g)
//   sodium  milligrams (mg)
struct Nutrients: Codable, Hashable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double

    /// An all-zero payload — the additive identity used when summing a day's entries.
    static let zero = Nutrients()

    init(calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0,
         fiber: Double = 0, sugar: Double = 0, sodium: Double = 0) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
    }

    // Claude  Date 06/16/2026
    // Per-serving values multiplied by a serving count, e.g. 2.5 servings logged.
    // This is how a FoodEntry turns its frozen per-serving snapshot into what was
    // actually consumed.
    func scaled(by factor: Double) -> Nutrients {
        Nutrients(calories: calories * factor, protein: protein * factor,
                  carbs: carbs * factor, fat: fat * factor, fiber: fiber * factor,
                  sugar: sugar * factor, sodium: sodium * factor)
    }

    // Claude  Date 06/16/2026
    // Field-wise sum, so a day's total is `entries.reduce(.zero, +)`.
    static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        Nutrients(calories: lhs.calories + rhs.calories, protein: lhs.protein + rhs.protein,
                  carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat,
                  fiber: lhs.fiber + rhs.fiber, sugar: lhs.sugar + rhs.sugar,
                  sodium: lhs.sodium + rhs.sodium)
    }

    static func += (lhs: inout Nutrients, rhs: Nutrients) {
        lhs = lhs + rhs
    }

    // Claude  Date 06/16/2026
    // Forgiving decode: any nutrient missing from the JSON (older saves, or an
    // Open Food Facts entry that simply omits e.g. fiber) loads as 0 rather than
    // failing the whole record. encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey {
        case calories, protein, carbs, fat, fiber, sugar, sodium
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calories = try c.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        protein  = try c.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        carbs    = try c.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        fat      = try c.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        fiber    = try c.decodeIfPresent(Double.self, forKey: .fiber) ?? 0
        sugar    = try c.decodeIfPresent(Double.self, forKey: .sugar) ?? 0
        sodium   = try c.decodeIfPresent(Double.self, forKey: .sodium) ?? 0
    }
}
