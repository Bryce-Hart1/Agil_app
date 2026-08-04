import SwiftUI

// Claude  Date 08/04/2026 - Peer reviewed Bryce Hart Aug 4
// The single source of truth for food-provenance tints — the colors behind the
// source badges (Verified / Open Food Facts / Generic / Restaurant / My food) and
// the stacked verification badges that ride along with them.
//
// Same reasoning as MacroPalette: `agilPink` was hardcoded inside FoodDetailView,
// and the badge now renders in four more places (library rows, picker rows, diary
// rows, detail header), so the hexes live here instead of being copy-pasted.
//
// Explicit hexes rather than system colors because these are read side-by-side as a
// set: the badge row can show a source tint and a verification tint touching each
// other, so `verified` (green) is kept clearly distinct from `generic` (warm tan)
// and `restaurant` (purple), and none of them collide with the brand pink that
// means "Agil curated".
enum FoodSourcePalette {
    /// Agil's curated vault. The app's signature pink (Classic accent), pinned
    /// regardless of the active theme — "Verified" always reads in brand pink.
    static let verified = Color(hex: "#EA0F8B")
    /// Open Food Facts. Blue, matching the globe symbol's connotation.
    static let openFoodFacts = Color(hex: "#3B82F6")
    /// USDA-style generic staples. Warm tan — "plain pantry food", deliberately
    /// low-saturation so it never competes with the brand pink.
    static let generic = Color(hex: "#A97142")
    /// Chain-restaurant foods. Purple — distinct from every macro tint and from
    /// `generic`, which it most often appears next to in a mixed result list.
    static let restaurant = Color(hex: "#7C3AED")
    /// Foods the user typed in themselves.
    static let userSubmitted = Color(hex: "#F97316")

    /// Stacked badge: a human has vouched for these numbers. Green, the universal
    /// "checked" color, and never used as a source tint so the two axes stay
    /// visually separable.
    static let verifiedStack = Color(hex: "#34C759")
    /// Stacked badge: submitted, awaiting Bryce's review. Amber = in progress.
    static let pendingStack = Color(hex: "#F5A524")
    /// Stacked badge: reviewed-but-unconfirmed numbers. Deliberately gray — this is
    /// a caveat, not an alarm; a red would imply the food is wrong rather than
    /// merely unchecked.
    static let unverifiedStack = Color(hex: "#8E8E93")
}
