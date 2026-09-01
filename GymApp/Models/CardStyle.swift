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
    // Claude  Date 08/24/2026
    // Thunderstorm — the view from inside the cloud (see ThunderstormBackground).
    case thunderstorm
    // Claude  Date 08/28/2026
    // Coral Reef — looking up from the seabed (see CoralReefBackground).
    case coralReef
    // Claude  Date 07/12/2026 last changed: 07/13/2026 by: Claude
    // The Founders Edition upgrades — not sold anywhere (see CardStyle.isFounders
    // / ThemeManager.grantFoundersCards). Added foundersConstellation alongside
    // foundersShootingStars and foundersGalaxy.
    case foundersShootingStars
    case foundersGalaxy
    case foundersConstellation
    // Claude  Date 07/23/2026
    // Gemstone cards — granted when the user earns their first diamond / emerald
    // achievement (see CardStyle.rewardCardID + RootTabView.syncRewardCards, never
    // sold). Painted by GemCardBackground, which reuses the badge GemFacetOverlay
    // full-bleed over the tier's material gradient.
    case diamondGem
    case emeraldGem
    case legendGem

    var accent: Color {
        switch self {
        case .shootingStars:         return Color(red: 0.55, green: 0.20, blue: 0.85)
        case .galaxy:                return Color(red: 0.40, green: 0.55, blue: 0.95)
        case .molten:                return Color(red: 1.0,  green: 0.42, blue: 0.10)
        case .cherryBlossom:         return Color(red: 0.96, green: 0.55, blue: 0.72)
        case .thunderstorm:          return Color(red: 0.66, green: 0.60, blue: 0.92)
        case .coralReef:             return Color(red: 0.16, green: 0.78, blue: 0.80)
        case .foundersShootingStars: return Color(red: 1.0,  green: 0.82, blue: 0.25)
        case .foundersGalaxy:        return Color(red: 0.98, green: 0.68, blue: 0.45)
        case .foundersConstellation: return Color(red: 0.98, green: 0.55, blue: 0.75)
        case .diamondGem:            return Color(red: 0.56, green: 0.83, blue: 0.94)  // icy blue #8FD3EF
        case .emeraldGem:            return Color(red: 0.06, green: 0.73, blue: 0.51)  // emerald #10B981
        case .legendGem:             return Color(red: 0.81, green: 0.11, blue: 0.60)  // magenta-pink #CE1C9A
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
    // Claude  Date 07/12/2026
    // Above Legendary, but never for sale — granted directly (see
    // CardStyle.isFounders). Price stays 0 since it's never bought with coins.
    case founders
    // Claude  Date 07/23/2026
    // Earned, never sold — the gemstone cards granted by an achievement milestone
    // (first diamond / emerald badge). Like founders, price 0 and excluded from the
    // Shop, but a distinct rarity so the picker labels them "Gem" (see
    // CardStyle.isGrantOnly, which gates ownership the same way founders does).
    case gem

    var price: Int {
        switch self {
        case .common:    return 0
        case .rare:      return 1000
        case .epic:      return 2000
        case .legendary: return 3000
        case .founders:  return 0
        case .gem:       return 0
        }
    }

    // Shown as a badge in the picker (nil for the free base).
    var label: String? {
        switch self {
        case .common:    return nil
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        case .founders:  return "Founders"
        case .gem:       return "Gem"
        }
    }

    // Loot-style rarity colour for the badge.
    var color: Color {
        switch self {
        case .common:    return .gray
        case .rare:      return Color(red: 0.30, green: 0.55, blue: 0.95)   // blue
        case .epic:      return Color(red: 0.64, green: 0.35, blue: 0.92)   // purple
        case .legendary: return Color(red: 0.98, green: 0.72, blue: 0.20)   // gold
        case .founders:  return Color(red: 1.0,  green: 0.82, blue: 0.25)   // brighter gold
        case .gem:       return Color(red: 0.36, green: 0.83, blue: 0.86)   // gem cyan
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
    // Claude  Date 07/12/2026
    // True only for cards granted directly instead of sold through the Shop/coin
    // system (e.g. Founders Edition). Defaults to false so every existing
    // CardStyle(...) call site is unaffected. See ThemeManager.isCardStyleUnlocked
    // and grantFoundersCards, plus the exclusion in ShopCatalogView.fullCatalog.
    let isFounders: Bool

    init(id: String, name: String, background: CardBackground, tier: CardTier, isFounders: Bool = false) {
        self.id = id
        self.name = name
        self.background = background
        self.tier = tier
        self.isFounders = isFounders
    }

    // Cost to unlock = the tier's price (Common = free).
    var price: Int { tier.price }

    // Claude  Date 07/23/2026
    // Cards that are only ever obtained by being granted (never sold in the Shop and
    // never free just because their price is 0): the Founders Edition cards and the
    // achievement-earned gemstone cards. Ownership for these means "explicitly present
    // in unlockedCardStyleIDs" — see ThemeManager.isCardStyleUnlocked and the
    // ShopCatalogView.fullCatalog exclusion.
    var isGrantOnly: Bool { isFounders || tier == .gem }

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
        // Claude  Date 08/28/2026
        // Riptide — teal to navy. The first epic in the blue/teal family; kept as
        // dark as Cherry so the card's white text still reads without a scrim
        // (CardBackgroundView only scrims .image and .animated, never .gradient).
        CardStyle(id: "riptide", name: "Riptide",      background: .gradient(from: "#0B6E78", to: "#132C63"), tier: .epic),
        // Legendary — live, code-drawn animations (see AnimatedCardBackground).
        CardStyle(id: "nebula",  name: "Shooting Stars", background: .animated(.shootingStars), tier: .legendary),
        CardStyle(id: "galaxy",  name: "Galaxy",         background: .animated(.galaxy),        tier: .legendary),
        CardStyle(id: "molten",  name: "Molten Core",    background: .animated(.molten),        tier: .legendary),
        CardStyle(id: "cherry_blossom", name: "Cherry Blossom", background: .animated(.cherryBlossom), tier: .legendary),
        CardStyle(id: "thunderstorm",   name: "Thunderstorm",   background: .animated(.thunderstorm),  tier: .legendary),
        CardStyle(id: "coral_reef",     name: "Coral Reef",     background: .animated(.coralReef),     tier: .legendary),
        // Claude  Date 07/12/2026
        // Founders Edition — the upgraded Shooting Stars variant. Not sold in the
        // Shop (see isFounders); granted directly by ThemeManager instead.
        CardStyle(id: "founders_shooting_stars", name: "Shooting Stars — Founders Edition",
                  background: .animated(.foundersShootingStars), tier: .founders, isFounders: true),
        // Claude  Date 07/12/2026
        // Founders Edition — the upgraded Galaxy variant. Same gating as above.
        CardStyle(id: "founders_galaxy", name: "Galaxy — Founders Edition",
                  background: .animated(.foundersGalaxy), tier: .founders, isFounders: true),
        // Claude  Date 07/13/2026
        // Founders Edition — Constellation, the pink entry in the line (no base
        // card to upgrade; it's an original). Same gating as the two above.
        CardStyle(id: "founders_constellation", name: "Constellation — Founders Edition",
                  background: .animated(.foundersConstellation), tier: .founders, isFounders: true),
        // Claude  Date 07/23/2026
        // Gemstone cards — earned, not sold. Granted the first time the user unlocks a
        // diamond / emerald achievement (see rewardCardID + RootTabView). tier == .gem
        // makes them grant-only (isGrantOnly) without the founders launch-grant, so
        // they stay locked until actually earned.
        CardStyle(id: "gem_diamond", name: "Diamond", background: .animated(.diamondGem), tier: .gem),
        CardStyle(id: "gem_emerald", name: "Emerald", background: .animated(.emeraldGem), tier: .gem),
        CardStyle(id: "gem_legend",  name: "Legend",  background: .animated(.legendGem),  tier: .gem),
    ]

    // Claude  Date 07/23/2026
    // The gemstone card a given badge tier awards, or nil for tiers with no card.
    // Used by RootTabView.syncRewardCards to grant the matching card when the user
    // earns their first achievement of that tier.
    static func rewardCardID(for tier: BadgeTier) -> String? {
        switch tier {
        case .diamond: return "gem_diamond"
        case .emerald: return "gem_emerald"
        case .legend:  return "gem_legend"
        default:       return nil
        }
    }

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
