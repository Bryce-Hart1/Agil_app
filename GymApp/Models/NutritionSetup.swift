import Foundation

// Claude  Date 07/25/2026
// Progress through the nutrition world's first-run setup checklist (the card at the
// top of the Journal — see NutritionSetupCard). Grouped into one struct rather than
// four loose Bools on UserProfile: it's one stored property, one CodingKey and one
// decodeIfPresent instead of four of each, and the "what counts as finished" rule
// lives next to the flags instead of being re-derived at every call site.
//
// This is the first UI-driven input the achievement system reads — every other stat
// is derived from the activity ledger or the food diary. It's fine here precisely
// because there's nothing to cheat: the reward for setting your own calorie goal is
// a welcome badge, not progress that competes with anyone.
struct NutritionSetup: Codable, Hashable {
    /// The user committed an edit to the calorie goal in NutritionGoalsView.
    var calorieGoalSet = false
    /// The user committed an edit to the water goal in NutritionGoalsView.
    var waterGoalSet = false
    // The bonus item: they opened the focus-goals editor at least once. Tracked so
    // the checklist can tick it off, but deliberately NOT part of isComplete — the
    // item exists to advertise a feature that's otherwise behind an unlabelled
    // toolbar icon, and it shouldn't hold the badge hostage.
    var focusGoalsOpened = false
    // The card has been retired — either auto-hidden a few seconds after the user
    // finished, or dismissed early with the X. Separate from isComplete so tapping
    // X doesn't fake completion (and doesn't grant the achievement).
    var acknowledged = false

    /// The two required items. `focusGoalsOpened` is intentionally excluded.
    var isComplete: Bool { calorieGoalSet && waterGoalSet }

    /// How many required items are done, for the card's "1 of 2" caption.
    var completedRequiredCount: Int {
        (calorieGoalSet ? 1 : 0) + (waterGoalSet ? 1 : 0)
    }

    /// Total required items — the denominator of that caption.
    static let requiredCount = 2
}
