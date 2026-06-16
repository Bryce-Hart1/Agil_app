import Foundation

// Claude  Date 06/16/2026
// The user's daily nutrition targets — what the diary's rings/progress fill toward.
// Calories + the three macros + water are the headline goals; fiber/sugar/sodium
// are tracked by Nutrients but not goaled yet (kept simple, room to add later).
// Persisted on its own (nutrition_goals.json) and Codable for a future server sync.
struct NutritionGoals: Codable, Hashable {
    var calories: Double   // kcal/day
    var protein: Double    // g/day
    var carbs: Double      // g/day
    var fat: Double        // g/day
    var water: Double      // ml/day

    // Claude  Date 06/16/2026
    // Neutral starting targets for a new user (~2000 kcal, a balanced macro split,
    // ~3 L water). Editable in NutritionGoalsView.
    init(calories: Double = 2000, protein: Double = 150, carbs: Double = 200,
         fat: Double = 65, water: Double = 3000) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.water = water
    }

    // Claude  Date 06/16/2026
    // The macro goals expressed as a Nutrients value, so the diary can compare a
    // day's total against the target field-by-field for the rings.
    var nutrientTargets: Nutrients {
        Nutrients(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }

    // Claude  Date 06/16/2026
    // Forgiving decode so goals saved before a field existed fall back to the
    // defaults above. encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey {
        case calories, protein, carbs, fat, water
    }
    init(from decoder: Decoder) throws {
        let defaults = NutritionGoals()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calories = try c.decodeIfPresent(Double.self, forKey: .calories) ?? defaults.calories
        protein  = try c.decodeIfPresent(Double.self, forKey: .protein) ?? defaults.protein
        carbs    = try c.decodeIfPresent(Double.self, forKey: .carbs) ?? defaults.carbs
        fat      = try c.decodeIfPresent(Double.self, forKey: .fat) ?? defaults.fat
        water    = try c.decodeIfPresent(Double.self, forKey: .water) ?? defaults.water
    }
}
