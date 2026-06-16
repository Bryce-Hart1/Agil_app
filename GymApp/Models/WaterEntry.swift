import Foundation

// Claude  Date 06/16/2026
// A single drink logged toward the daily water goal. Kept separate from food
// entries (it carries no macros) and stored canonically in MILLILITERS — convert
// only for display (oz). The calendar day of `loggedAt` is the diary day, mirroring
// FoodEntry.
struct WaterEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var milliliters: Double
    var loggedAt: Date

    init(id: UUID = UUID(), milliliters: Double, loggedAt: Date = Date()) {
        self.id = id
        self.milliliters = milliliters
        self.loggedAt = loggedAt
    }
}
