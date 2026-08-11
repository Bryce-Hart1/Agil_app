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

// Claude  Date 08/07/2026
// Whether the diary shows the water tracker at all (Settings → Water). Plenty of people
// track food without tracking water, and for them the section is dead weight in the middle
// of the journal. Off only HIDES the tracker — logged water and the daily goal are left
// untouched, so turning it back on restores the history rather than starting over.
enum WaterTracking {
    static let storageKey = "trackWater"
    static let defaultValue = true

    // The current setting, for the non-View code that has to agree with it (see
    // NutritionSetup). Reads through `object(forKey:)` because `bool(forKey:)` reports
    // false for a key that was never written, which would read as "off" for every user
    // who has never opened Settings.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: storageKey) as? Bool ?? defaultValue
    }
}

// Claude  Date 08/07/2026
// A one-tap water quick-add. Logging water is the diary's most repeated action, so the
// chips are named rather than numeric ("Bottle", "Mug") — a name is unit-agnostic, which
// keeps the row honest whether the user reads ml or fl oz, and it's what makes a custom
// pour memorable. Amounts stay canonical milliliters like everything else water-related.
//
// `useCount` drives "most used first". The ORDER IS DELIBERATELY NOT LIVE — the diary
// snapshots it when the screen appears (see NutritionJournalView.freezeWaterOrder) so
// chips never rearrange under a finger that's mid-tap.
struct WaterPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var milliliters: Double
    var useCount: Int
    // Only user-made presets can be deleted, and only they count toward the cap.
    var isCustom: Bool

    // Short enough that a chip stays a chip; enforced at the input edge.
    static let maxNameLength = 8
    static let maxCustomCount = 3
    // The standard single-serve bottle: 16.9 fl oz (≈500 ml), deferred to FoodUnit so
    // water and food keep agreeing on what a fluid ounce is.
    static let bottleMilliliters = 16.9 * FoodUnit.fluidOunce.perBase

    init(id: UUID = UUID(), name: String, milliliters: Double,
         useCount: Int = 0, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.milliliters = milliliters
        self.useCount = useCount
        self.isCustom = isCustom
    }

    // What ships before the user makes any of their own: a glass and the 16.9 oz bottle.
    static let defaults: [WaterPreset] = [
        WaterPreset(name: "Glass", milliliters: 250),
        WaterPreset(name: "Bottle", milliliters: bottleMilliliters),
    ]
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
    // Claude  Date 08/06/2026
    // US fluid ounce — deferred to FoodUnit, which owns every volume/weight constant
    // in the app now. Same value it was declared with here; the point is that food and
    // water can't drift apart (they already had two spellings of the fluid ounce).
    static let mlPerFluidOunce = FoodUnit.fluidOunce.perBase

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
