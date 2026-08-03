import Foundation
import SwiftUI

// Claude  Date 07/12/2026
// A user-created "focus goal" for one of the nutrients the diary tracks but
// NutritionGoals doesn't target (fiber/sugar/sodium). Created from the diary's
// top-left Focus button and shown as a progress card under the Summary. Each
// goal is either a floor ("at least 30 g fiber") or a ceiling ("stay under
// 2300 mg sodium"); one goal per nutrient. Persisted by AppStore in
// nutrient_focus_goals.json.
struct NutrientFocusGoal: Codable, Hashable, Identifiable {

    // Claude  Date 07/12/2026
    // The focusable nutrients. Carries all per-nutrient presentation (label, unit,
    // icon, tint — matching the Summary card's "More nutrients" rows) and data
    // plumbing (value(from:)) so views stay dumb. Macros aren't focusable — they
    // already have goals and bars in the Summary.
    enum Nutrient: String, Codable, CaseIterable, Identifiable {
        case fiber, sugar, sodium
        var id: String { rawValue }

        var label: String {
            switch self {
            case .fiber:  return "Fiber"
            case .sugar:  return "Sugar"
            case .sodium: return "Sodium"
            }
        }

        var unit: String { self == .sodium ? "mg" : "g" }

        var systemImage: String {
            switch self {
            case .fiber:  return "leaf.fill"
            case .sugar:  return "cube.fill"
            case .sodium: return "circle.grid.3x3.fill"
            }
        }

        // Claude  Date 07/26/2026
        // Resolves through MacroPalette so the focus card, the focus-goals
        // editor and the widget all pick up a palette change for free.
        var tint: Color {
            switch self {
            case .fiber:  return MacroPalette.fiber
            case .sugar:  return MacroPalette.sugar
            case .sodium: return MacroPalette.sodium
            }
        }

        func value(from nutrients: Nutrients) -> Double {
            switch self {
            case .fiber:  return nutrients.fiber
            case .sugar:  return nutrients.sugar
            case .sodium: return nutrients.sodium
            }
        }

        // Claude  Date 07/12/2026
        // Sensible starting points for a new goal: fiber is something to reach
        // (~30 g/day guidance), sugar and sodium are ceilings (~50 g added sugar,
        // 2300 mg sodium — common daily guidelines). All editable.
        var defaultDirection: Direction { self == .fiber ? .atLeast : .atMost }
        var defaultTarget: Double {
            switch self {
            case .fiber:  return 30
            case .sugar:  return 50
            case .sodium: return 2300
            }
        }
    }

    enum Direction: String, Codable, CaseIterable {
        case atLeast, atMost
        var label: String { self == .atLeast ? "At least" : "Stay under" }
    }

    var id: UUID
    var nutrient: Nutrient
    var direction: Direction
    var target: Double

    init(nutrient: Nutrient, direction: Direction? = nil, target: Double? = nil,
         id: UUID = UUID()) {
        self.id = id
        self.nutrient = nutrient
        self.direction = direction ?? nutrient.defaultDirection
        self.target = target ?? nutrient.defaultTarget
    }

    // Claude  Date 07/12/2026
    // Shared status wording so the diary's Focus card (and a future daily reminder
    // notification) phrase progress identically.
    func isMet(consumed: Double) -> Bool {
        direction == .atLeast ? consumed >= target : consumed <= target
    }

    func progressText(consumed: Double) -> String {
        switch direction {
        case .atLeast:
            let toGo = target - consumed
            return toGo > 0 ? "\(Int(toGo.rounded())) \(unitLabel) to go" : "Goal met"
        case .atMost:
            let left = target - consumed
            return left >= 0 ? "\(Int(left.rounded())) \(unitLabel) left"
                             : "\(Int((-left).rounded())) \(unitLabel) over"
        }
    }

    private var unitLabel: String { nutrient.unit }
}
