import Foundation

// Claude  Date 08/11/2026
// One ingredient inside a recipe: a food, at a chosen amount, FROZEN. Everything the
// recipe needs to total itself and to redisplay the amount is snapshotted here, the
// same contract FoodEntry has with the diary — editing or deleting the library food
// later must never silently rewrite a recipe the user already built.
//
// `foodId` is the same kind of soft link FoodEntry.foodId is: useful for "swap this
// ingredient" and for tracing where a number came from, never required to display or
// total the recipe.
struct RecipeIngredient: Identifiable, Codable, Hashable {
    let id: UUID
    var foodId: UUID?
    // Snapshot of the food's label at add time ("Chicken breast · Perdue").
    var name: String
    // This ingredient's contribution AT `measurement` — already scaled, so totalling a
    // recipe is a plain sum. Computed once at add time via `basis` (see `init`).
    var consumedNutrients: Nutrients
    // The amount as the user expressed it ("200 g", "2 cups"), for display and re-dial.
    var measurement: FoodMeasurement
    // The food's per-100 shape at add time, so the builder can re-dial this ingredient's
    // amount later without the source food still existing. Same role it plays on FoodEntry.
    var basis: MeasurementBasis

    init(id: UUID = UUID(), foodId: UUID? = nil, name: String,
         consumedNutrients: Nutrients, measurement: FoodMeasurement,
         basis: MeasurementBasis) {
        self.id = id
        self.foodId = foodId
        self.name = name
        self.consumedNutrients = consumedNutrients
        self.measurement = measurement
        self.basis = basis
    }

    // Claude  Date 08/11/2026
    // Build an ingredient from a food's shape + a dialed amount, doing the per-100 →
    // consumed scaling in ONE place (the same arithmetic FoodDetailView's log bar runs).
    init(id: UUID = UUID(), foodId: UUID?, name: String,
         measurement: FoodMeasurement, basis: MeasurementBasis) {
        self.init(id: id, foodId: foodId, name: name,
                  consumedNutrients: basis.per100.scaled(by: measurement.per100Factor(in: basis)),
                  measurement: measurement, basis: basis)
    }
}

// Claude  Date 08/11/2026
// A user-built dish: named ingredients, an optional method, and how many servings it
// makes. Local-only — the backend has no notion of recipes, so none of this is ever
// submitted or server-ranked.
//
// A recipe reaches the rest of the app through `asFoodItem`: search rows, the diary
// write, and the per-serving macro caption all run through the existing FoodItem /
// FoodEntry pipeline rather than a parallel one. Logging a recipe therefore produces
// one ordinary diary row (name + per-serving nutrients × the multiplier), which is why
// NutritionDay, the diary rows and the entry editor need no knowledge of recipes at all.
struct Recipe: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    // Freeform method. Optional in the real sense — a recipe that's just a list of
    // ingredients is a legitimate recipe, and the detail page draws no block for nil.
    var instructions: String?
    var ingredients: [RecipeIngredient]
    // How many servings the whole recipe makes — what turns a pot of chili into a
    // per-serving food. Guarded at >= 1 by the builder; the divide below is defensive
    // because a decoded file is not something this type controls.
    var servingsYield: Double

    init(id: UUID = UUID(), name: String, instructions: String? = nil,
         ingredients: [RecipeIngredient] = [], servingsYield: Double = 1) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.ingredients = ingredients
        self.servingsYield = servingsYield
    }

    /// Everything in the pot.
    var totalNutrients: Nutrients {
        ingredients.reduce(.zero) { $0 + $1.consumedNutrients }
    }

    /// One serving of it — the basis a logged entry is measured in.
    var perServingNutrients: Nutrients {
        totalNutrients.scaled(by: servingsYield > 0 ? 1 / servingsYield : 1)
    }

    // Claude  Date 08/11/2026
    // The adapter into the food pipeline. Deliberately count-based ("1 serving"): a
    // recipe has no honest per-gram basis — nobody weighs a portion of chili against
    // the recipe's total mass — so it's logged by the serving, exactly like a
    // restaurant item. Keeping `id` means the diary entry's foodId points back at the
    // recipe, which is what makes recipes participate in AppStore.lastLoggedByFood
    // (and therefore in "most recently used first" ordering) for free.
    var asFoodItem: FoodItem {
        FoodItem(id: id, name: name, servingSize: 1, servingUnit: "serving",
                 nutrients: perServingNutrients, source: .recipe)
    }
}
