import Foundation

// CLAUDE  Date 10/02/2026
// The arithmetic behind quick add: macro calories at 4/4/9 kcal per gram, the over-check
// that scales macros down when they add up to more than the calories typed, and the carbs
// step's "fill the rest". Pure (no SwiftUI) so it can be checked with a swiftc harness.
enum QuickAddMath {
    // Overs this small are label rounding, not a mistake, so they're left alone.
    static let overTolerance = 0.05

    static func macroCalories(protein: Double, fat: Double, carbs: Double) -> Double {
        4 * protein + 9 * fat + 4 * carbs
    }

    static func macroCalories(of n: Nutrients) -> Double {
        macroCalories(protein: n.protein, fat: n.fat, carbs: n.carbs)
    }

    // CLAUDE  Date 10/02/2026
    // What the over-check would log, plus what the typed macros came to (for the notice).
    struct Fit: Equatable {
        let nutrients: Nutrients
        let typedMacroCalories: Double
        let wasScaled: Bool
    }

    static func isOver(macroCalories: Double, calories: Double) -> Bool {
        calories > 0 && macroCalories > calories * (1 + overTolerance)
    }

    // CLAUDE  Date 10/02/2026
    // Calories are the truth: when the macros come to more than overTolerance past them,
    // protein, fat and carbs all shrink by the same ratio (to 0.1 g) so they fit. Calories
    // and everything else on the payload are left as given.
    static func fit(_ n: Nutrients) -> Fit {
        let macroKcal = macroCalories(of: n)
        guard isOver(macroCalories: macroKcal, calories: n.calories) else {
            return Fit(nutrients: n, typedMacroCalories: macroKcal, wasScaled: false)
        }
        let ratio = n.calories / macroKcal
        var scaled = n
        scaled.protein = tenths(n.protein * ratio)
        scaled.fat = tenths(n.fat * ratio)
        scaled.carbs = tenths(n.carbs * ratio)
        return Fit(nutrients: scaled, typedMacroCalories: macroKcal, wasScaled: true)
    }

    // CLAUDE  Date 10/02/2026
    // The carbs that would use up the calories protein and fat leave over, in whole grams
    // (rounded down so it never tips the total over). nil when less than a gram is left.
    static func fillRestCarbs(calories: Double, protein: Double, fat: Double) -> Double? {
        let left = calories - macroCalories(protein: protein, fat: fat, carbs: 0)
        let grams = (left / 4).rounded(.down)
        return grams >= 1 ? grams : nil
    }

    private static func tenths(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
