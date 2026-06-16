import Foundation

// Claude  Date 06/16/2026
// A read-through view of one calendar day's nutrition — the diary's data model for
// a given date. Built from the full logs (it filters to the day itself), it totals
// macros, groups food entries by meal, and sums water. Pure derived data, like
// ProfileStats: nothing here is persisted; rebuild it whenever the logs change.
struct NutritionDay {
    let date: Date
    let entries: [FoodEntry]          // this day's food entries, newest first
    let totals: Nutrients             // Σ consumed across all entries
    let water: Double                 // ml drunk this day

    // Claude  Date 06/16/2026
    // Build the day from the whole food/water logs. `date` is normalized to the
    // start of its calendar day; an entry belongs to the day if its loggedAt falls
    // on the same day. Entries are sorted newest-first for display.
    init(date: Date, foodLog: [FoodEntry], waterLog: [WaterEntry],
         calendar: Calendar = .current) {
        self.date = calendar.startOfDay(for: date)
        let dayEntries = foodLog
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }
            .sorted { $0.loggedAt > $1.loggedAt }
        self.entries = dayEntries
        self.totals = dayEntries.reduce(.zero) { $0 + $1.consumed }
        self.water = waterLog
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.milliliters }
    }

    // Claude  Date 06/16/2026
    // This day's entries for one meal section (newest first, already sorted).
    func entries(for meal: MealType) -> [FoodEntry] {
        entries.filter { $0.mealType == meal }
    }

    // Claude  Date 06/16/2026
    // Σ consumed for one meal — drives each meal section's subtotal.
    func totals(for meal: MealType) -> Nutrients {
        entries(for: meal).reduce(.zero) { $0 + $1.consumed }
    }

    // Whether anything (food or water) was logged this day.
    var isEmpty: Bool { entries.isEmpty && water == 0 }
}
