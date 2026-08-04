import SwiftUI

// Last peer reviewed: Aug 04 26 Bryce hart

// Claude  Date 07/26/2026
// The single source of truth for nutrient tints — the colors that identify
// protein/carbs/fat on the summary ring and macro bars, and fiber/sugar/sodium
// on the extra-nutrient rows. Before this file the six colors were hardcoded
// system colors duplicated across MacroSummaryView, FoodDetailView and
// NutrientFocusGoal, so a palette change meant editing three files and missing
// one; everything now reads from here.
//
// Explicit hexes rather than system colors: the ring draws protein and (via the
// extras) sodium as two blues, and fat against sugar as warm-vs-deep, so the
// pairs need hues chosen against each other rather than whatever the platform
// ships. Compiled into the widget target too (see project.yml) because
// NutrientFocusGoal.tint resolves through here.
enum MacroPalette {
    /// On the ring. Deep, saturated blue — kept clearly darker than `sodium`.
    static let protein = Color(hex: "#2F6BFF")
    /// On the ring. Pink.
    static let carbs = Color(hex: "#FF5C8A")
    /// On the ring. Warm amber/yellow-orange.
    static let fat = Color(hex: "#F5A524")

    /// Extras only. Green.
    static let fiber = Color(hex: "#34C759")
    /// Extras only. Deep purple.
    static let sugar = Color(hex: "#6B21A8")
    /// Extras only. Light blue — deliberately paler than `protein`.
    static let sodium = Color(hex: "#6FC3F7")
}
