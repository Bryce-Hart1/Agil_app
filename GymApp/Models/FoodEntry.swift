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

    // Claude  Date 08/06/2026
    // The source food's per-100 values and unit shape, snapshotted at log time. This is
    // what lets the diary's editor RE-DIAL an amount — pick 250 g instead of 200 g and
    // get the right nutrients — rather than only multiplying a frozen total. Without
    // it an edit can't do anything but scale, which is how the old editor came to call
    // a whole 250 g portion "1 serving" and let you double it by accident.
    //
    // Snapshotted rather than looked up through `foodId`: the same reason `nutrients`
    // is. A one-off search result was never saved to the library, and a food that was
    // can still be edited or deleted afterwards.
    var basis: MeasurementBasis?

    init(id: UUID = UUID(), foodId: UUID? = nil, name: String,
         nutrients: Nutrients, servings: Double = 1, mealType: MealType = .other,
         loggedAt: Date = Date(), measurement: FoodMeasurement? = nil,
         basis: MeasurementBasis? = nil) {
        self.id = id
        self.foodId = foodId
        self.name = name
        self.nutrients = nutrients
        self.servings = servings
        self.mealType = mealType
        self.loggedAt = loggedAt
        self.measurement = measurement
        self.basis = basis
    }

    // Claude  Date 08/06/2026
    // Whether this entry can have its amount re-dialed with the full unit controls.
    // Requires both halves of the redesign: what the user picked, and what the food's
    // numbers mean. Entries logged before either existed fall back to the old
    // servings stepper.
    var isRedialable: Bool { measurement != nil && basis != nil }

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
