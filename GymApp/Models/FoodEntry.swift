import Foundation

// Claude  Date 06/16/2026
// One logged consumption in the food diary — the nutrition analog of a logged set.
// Like ActivityEvent freezes a lift's type at log time, a FoodEntry SNAPSHOTS the
// food's name and per-serving nutrients when it's logged. So if the source
// FoodItem is later edited, deleted, or was a one-off Open Food Facts result that
// never got cached, this diary record still reads correctly forever.
//
// `foodId` is a soft reference (kept for "log this again" / linking back), but it
// is never required to display or total the entry — `nutrients` × `servings` is
// fully self-contained.
struct FoodEntry: Identifiable, Codable, Hashable {
    let id: UUID
    // Soft link back to the library FoodItem this came from (nil for a pure one-off).
    var foodId: UUID?
    // Snapshot of the food's name at log time (what the diary shows).
    var name: String
    // Snapshot of the food's PER-SERVING nutrients at log time.
    var nutrients: Nutrients
    // How many of the food's reference servings were eaten (e.g. 1.5).
    var servings: Double
    var mealType: MealType
    // Real wall-clock time logged; the calendar day of this is the diary day.
    var loggedAt: Date

    // Claude  Date 08/06/2026
    // How the user expressed the amount ("200 g", "2 cups", "1.5 servings"), for
    // display only — `nutrients` × `servings` remains the arithmetic truth.
    //
    // Optional because it's genuinely absent on two paths: entries logged before this
    // existed, and `FoodEntry.from` (plain servings-count logging, no unit involved).
    // Synthesized Codable decodes a missing key as nil, so old logs keep loading —
    // which matters, since PersistenceService silently RESETS a file it can't decode.
    var measurement: FoodMeasurement?

    init(id: UUID = UUID(), foodId: UUID? = nil, name: String,
         nutrients: Nutrients, servings: Double = 1, mealType: MealType = .other,
         loggedAt: Date = Date(), measurement: FoodMeasurement? = nil) {
        self.id = id
        self.foodId = foodId
        self.name = name
        self.nutrients = nutrients
        self.servings = servings
        self.mealType = mealType
        self.loggedAt = loggedAt
        self.measurement = measurement
    }

    // Claude  Date 06/16/2026
    // What was actually consumed: the per-serving snapshot scaled by serving count.
    // This is the value totaled into a day / meal.
    var consumed: Nutrients {
        nutrients.scaled(by: servings)
    }

    // Claude  Date 08/06/2026
    // The amount to show for this entry, scaled by the servings multiplier so the
    // edit sheet's stepper reads honestly (a 200 g entry stepped to 1.5 shows
    // "300 g"). One definition shared by the diary row and the editor. nil for
    // entries logged without a measurement — callers fall back to the servings count.
    var amountText: String? {
        measurement?.scaled(by: servings).displayText
    }

    // Claude  Date 06/16/2026
    // Convenience for building a logged entry from a library food + serving count,
    // capturing the food's name/nutrients into the snapshot.
    static func from(_ food: FoodItem, servings: Double, mealType: MealType,
                     loggedAt: Date = Date()) -> FoodEntry {
        FoodEntry(foodId: food.id, name: food.displayLabel, nutrients: food.nutrients,
                  servings: servings, mealType: mealType, loggedAt: loggedAt)
    }
}
