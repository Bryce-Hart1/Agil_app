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

// Claude  Date 07/16/2026
// The user's display unit for water (Settings → Water). Storage stays canonical
// milliliters everywhere (WaterEntry, NutritionGoals.water); this converts at the
// display/input edge only, so flipping the setting never rewrites history. Views
// read it via @AppStorage(WaterUnit.storageKey) on the raw value.
enum WaterUnit: String, CaseIterable, Identifiable {
    case milliliters
    case fluidOunces

    static let storageKey = "waterUnit"
    // US fluid ounce (same constant family as FoodDetailView's volume conversions).
    static let mlPerFluidOunce = 29.5735

    var id: String { rawValue }

    var label: String {
        switch self {
        case .milliliters: return "Milliliters (ml)"
        case .fluidOunces: return "Fluid ounces (fl oz)"
        }
    }

    var abbreviation: String {
        switch self {
        case .milliliters: return "ml"
        case .fluidOunces: return "fl oz"
        }
    }

    func fromMilliliters(_ ml: Double) -> Double {
        self == .milliliters ? ml : ml / Self.mlPerFluidOunce
    }

    func toMilliliters(_ value: Double) -> Double {
        self == .milliliters ? value : value * Self.mlPerFluidOunce
    }

    // Whole-number display amount ("2150", "73") — water isn't measured finer than
    // this in either unit.
    func text(fromMilliliters ml: Double) -> String {
        String(Int(fromMilliliters(ml).rounded()))
    }
}
