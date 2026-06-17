import Foundation
import SwiftUI

// Claude  Date 06/13/2026
// What's drawn behind the profile card's content. Designed as a small enum so
// the look is *scalable*: a solid color today, a PNG asset today, and an
// animated background later — each new kind is one extra case here plus one
// branch in CardBackgroundView (the only place that knows how to render it).
enum CardBackground: Hashable {
    case color(hex: String)                 // a solid color (rendered as a subtle gradient)
    case gradient(from: String, to: String) // a two-color diagonal gradient (no asset needed)
    case image(asset: String)               // a PNG in Assets.xcassets, drawn full-bleed
    case animated(AnimatedCard)             // a code-drawn live animation (see AnimatedCardBackground)
}

// Claude  Date 06/16/2026
// The premium, coin-only animated card looks. Each case is rendered by
// AnimatedCardBackground; `accent` is a representative colour used for the
// card's drop shadow and the small swatch tint. Add a case here + a branch in
// AnimatedCardBackground + a CardStyle entry to ship a new animated card.
enum AnimatedCard: Hashable {
    case shootingStars
    case galaxy
    case molten
    case cherryBlossom

    var accent: Color {
        switch self {
        case .shootingStars: return Color(red: 0.55, green: 0.20, blue: 0.85)
        case .galaxy:        return Color(red: 0.40, green: 0.55, blue: 0.95)
        case .molten:        return Color(red: 1.0,  green: 0.42, blue: 0.10)
        case .cherryBlossom: return Color(red: 0.96, green: 0.55, blue: 0.72)
        }
    }
}

// Claude  Date 06/16/2026
// Rarity tier of a profile card. The tier sets the price (one place to retune
// the economy) and a label/colour for the Shop badge. Loosely: Common = the free
// base, Rare = solid colours, Epic = static gradients, Legendary = live
// animations. Prices are provisional — change them here and every card follows.
enum CardTier: Hashable {
    case common
    case rare
    case epic
    case legendary

    var price: Int {
        switch self {
        case .common:    return 0
        case .rare:      return 1000
        case .epic:      return 2000
        case .legendary: return 3000
        }
    }

    // Shown as a badge in the picker (nil for the free base).
    var label: String? {
        switch self {
        case .common:    return nil
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        }
    }

    // Loot-style rarity colour for the badge.
    var color: Color {
        switch self {
        case .common:    return .gray
        case .rare:      return Color(red: 0.30, green: 0.55, blue: 0.95)   // blue
        case .epic:      return Color(red: 0.64, green: 0.35, blue: 0.92)   // purple
        case .legendary: return Color(red: 0.98, green: 0.72, blue: 0.20)   // gold
        }
    }
}

// Claude  Date 06/13/2026 last changed: 06/16/2026 by: Claude
// A purchasable look for the profile card. The chosen style's *id* is stored on
// UserProfile.cardStyleID; which paid styles are owned lives in ThemeManager
// (unlockedCardStyleIDs) so all coin spending is tracked in one place. The price
// is derived from the card's rarity `tier` (see CardTier).
//
// To add a new card: drop a PNG imageset into Assets.xcassets (e.g. "card_foo")
// and append one CardStyle(id:name:background:.image(asset:"card_foo"),tier:) here.
struct CardStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let background: CardBackground
    let tier: CardTier

    // Cost to unlock = the tier's price (Common = free).
    var price: Int { tier.price }

    static let all: [CardStyle] = [
        CardStyle(id: "default", name: "Classic Pink", background: .color(hex: "#EA0F8B"), tier: .common),
        // Rare — solid-colour cards.
        CardStyle(id: "black",       name: "Black",       background: .color(hex: "#000000"), tier: .rare),
        CardStyle(id: "dark_green",  name: "Dark Green",  background: .color(hex: "#15351F"), tier: .rare),
        CardStyle(id: "dark_purple", name: "Dark Purple", background: .color(hex: "#2C1250"), tier: .rare),
        // Epic — gradient cards (PNG art, or a two-colour gradient).
        CardStyle(id: "aurora",  name: "Aurora",       background: .image(asset: "card_aurora"), tier: .epic),
        CardStyle(id: "ember",   name: "Ember",        background: .image(asset: "card_ember"),  tier: .epic),
        CardStyle(id: "cherry",  name: "Cherry",       background: .gradient(from: "#C21F3A", to: "#5E1A4E"), tier: .epic),
        CardStyle(id: "shadow",  name: "Shadow",       background: .gradient(from: "#0A0A0C", to: "#3A3A40"), tier: .epic),
        // Legendary — live, code-drawn animations (see AnimatedCardBackground).
        CardStyle(id: "nebula",  name: "Shooting Stars", background: .animated(.shootingStars), tier: .legendary),
        CardStyle(id: "galaxy",  name: "Galaxy",         background: .animated(.galaxy),        tier: .legendary),
        CardStyle(id: "molten",  name: "Molten Core",    background: .animated(.molten),        tier: .legendary),
        CardStyle(id: "cherry_blossom", name: "Cherry Blossom", background: .animated(.cherryBlossom), tier: .legendary),
    ]

    /// The free default style — its color matches UserProfile's default.
    static var defaultStyle: CardStyle { all[0] }

    /// Resolve a stored style id back to a CardStyle, falling back to the default.
    static func style(for id: String) -> CardStyle {
        all.first { $0.id == id } ?? defaultStyle
    }

    /// Migration helper: map a legacy `cardColorHex` value to a style id.
    static func id(forLegacyHex hex: String?) -> String? {
        guard let hex else { return nil }
        return all.first {
            if case .color(let h) = $0.background {
                return h.caseInsensitiveCompare(hex) == .orderedSame
            }
            return false
        }?.id
    }
}
