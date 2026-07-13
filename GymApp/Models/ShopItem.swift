import SwiftUI

// Claude  Date 06/17/2026
// A single thing the Shop can sell. The Shop now mixes two kinds of cosmetics in
// one rotating "Featured" tab — colour themes and profile-card styles — so this
// enum gives them one shared shape (name / price / rarity / artwork hook) and a
// stable string id. That way the featured grid, the preview sheet and the daily
// rotation engine all speak in ShopItems and never special-case "is this a theme
// or a card" except where the look actually differs.
//
// Outline note: this is a first pass to support the Fortnite-style shop concept.
// Expect the rarity model to grow (themes don't have real tiers yet — see below).
enum ShopItem: Identifiable, Hashable {
    case theme(AppTheme)
    case card(CardStyle)

    // Namespaced so a theme UUID and a card id-string can never collide.
    var id: String {
        switch self {
        case .theme(let t): return "theme:\(t.id.uuidString)"
        case .card(let c):  return "card:\(c.id)"
        }
    }

    var name: String {
        switch self {
        case .theme(let t): return t.name
        case .card(let c):  return c.name
        }
    }

    /// Coin cost (0 = free / always available — e.g. Classic theme, default card).
    var price: Int {
        switch self {
        case .theme(let t): return t.price
        case .card(let c):  return c.price
        }
    }

    // Claude  Date 06/17/2026
    // Short uppercase rarity label shown on the tile badge. Cards already carry a
    // CardTier (Rare/Epic/Legendary); themes have no tier yet so they all read as
    // "THEME" for now. When themes get real rarity, branch here.
    var rarityLabel: String {
        switch self {
        case .theme:        return "THEME"
        case .card(let c):  return (c.tier.label ?? "CARD").uppercased()
        }
    }

    // Loot-style accent colour for the rarity badge + the tile's glow. Themes
    // borrow their own accent so the badge matches the product.
    var rarityColor: Color {
        switch self {
        case .theme(let t): return t.accent
        case .card(let c):  return c.tier.color
        }
    }

    // Claude  Date 06/17/2026
    // Drop weight for the daily rotation — higher = more common, lower = rarer, so
    // legendary cards surface far less often than rares. This is *the* knob that
    // turns "random shop" into "rarity"; tune these to taste. Themes sit at a flat
    // middling weight until they get their own tiers.
    var weight: Double {
        switch self {
        case .theme:
            return 0.7
        case .card(let c):
            switch c.tier {
            case .common:    return 1.0   // (free base — never in the paid pool anyway)
            case .rare:      return 1.0
            case .epic:      return 0.5
            case .legendary: return 0.22
            // Claude  Date 07/12/2026
            // Unreachable via the Shop — Founders cards are excluded from every pool
            // (see ShopView.fullCatalog / DailyShop.cardPool). Value is a placeholder
            // to keep this switch exhaustive.
            case .founders:  return 0
            }
        }
    }
}
