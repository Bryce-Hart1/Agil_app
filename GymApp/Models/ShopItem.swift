import SwiftUI

// Claude  Date 06/17/2026
// A single thing the Shop can sell. The Shop now mixes two kinds of cosmetics in
// one rotating "Featured" tab — colour themes and profile-card styles — so this
// enum gives them one shared shape (name / price / rarity / artwork hook) and a
// stable string id. That way the featured grid, the preview sheet and the daily
// rotation engine all speak in ShopItems and never special-case "is this a theme
// or a card" except where the look actually differs.
//
// Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
// Themes now carry a real rarity (see `tier`) instead of a flat "THEME" badge, and
// every item carries its own store copy (see `blurb` at the bottom of this file).
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

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // Rarity, shared by both kinds. Themes used to have no tier at all (they read as
    // a flat "THEME"); now every paid theme is Legendary and the free one is Common,
    // derived from price so the two can never disagree. Reusing CardTier rather than
    // adding a parallel theme enum keeps one source of truth for the economy — its
    // .price/.label/.color already define what each tier means.
    var tier: CardTier {
        switch self {
        case .theme(let t): return t.price == 0 ? .common : .legendary
        case .card(let c):  return c.tier
        }
    }

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // Short uppercase rarity label shown on the tile badge. Now straight off `tier`,
    // so a paid theme reads "LEGENDARY" exactly like a legendary card. The free
    // items (Classic theme, Classic Pink card) have no tier label and both read
    // "FREE" instead of the old kind-specific "THEME" / "CARD".
    var rarityLabel: String {
        (tier.label ?? "Free").uppercased()
    }

    // Loot-style accent colour for the rarity badge + the tile's glow — the tier's
    // colour for every item, so gold always means legendary whatever the kind.
    var rarityColor: Color { tier.color }

    // Claude  Date 06/17/2026 last changed: 08/03/2026 by: Claude
    // Drop weight for the daily rotation — higher = more common, lower = rarer, so
    // legendary cards surface far less often than rares. This is *the* knob that
    // turns "random shop" into "rarity"; tune these to taste.
    //
    // The theme value is inert today: DailyShop draws themes and cards from separate
    // pools (themeCount / cardCount), and every paid theme now sits at the same
    // rarity, so the theme weights are uniform within their own pool and cancel out.
    // It only starts to matter if themes ever get mixed tiers.
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
            // Claude  Date 07/12/2026 last changed: 07/23/2026 by: Claude
            // Unreachable via the Shop — Founders and Gem cards are excluded from every
            // pool (see ShopView.fullCatalog's isGrantOnly filter). Values are
            // placeholders to keep this switch exhaustive.
            case .founders:  return 0
            case .gem:       return 0
            }
        }
    }
}

// MARK: - Store copy

// Claude  Date 08/03/2026
// A short line of flavour text per item, shown under the name on the item detail
// screen. Before this, the detail screen printed one of two hard-coded strings
// switched on kind, so every theme read identically and so did every card.
//
// The copy lives here in a lookup table rather than as a field on AppTheme /
// CardStyle for one reason: AppTheme is Codable and gets persisted to theme.json,
// so a `description` field would mean touching CodingKeys plus the custom decoder
// to save marketing text to disk that never changes at runtime. Keying on the
// ShopItem id ("theme:<uuid>" / "card:<id>") keeps both kinds in one editable list.
//
// THE WORDING IS PLACEHOLDER — rewrite freely, this table is the only place it
// lives. An item with no entry falls back to the generic per-kind line, so adding a
// theme or card without touching this table still renders something sensible.
extension ShopItem {
    /// One-line flavour text for the item detail screen.
    var blurb: String { Self.blurbs[id] ?? fallbackBlurb }

    /// Used when an item has no entry in the table above.
    private var fallbackBlurb: String {
        switch self {
        case .theme: return "An app-wide colour theme. Equip it to recolour every screen."
        case .card:  return "A profile-card background. Equip it from your profile card."
        }
    }

    // Keyed by ShopItem.id. Themes use their fixed built-in UUIDs (see AppTheme);
    // cards use their CardStyle id string.

    private static let blurbs: [String: String] = [
        // MARK: Themes and descriptions
        "theme:00000000-0000-0000-0000-000000000001":
            "The original.",
        "theme:00000000-0000-0000-0000-000000000002":
            "Built for late sessions and dim gyms.",
        "theme:00000000-0000-0000-0000-000000000003":
            "Calmer theme for those that like a more modern feel.",
        "theme:00000000-0000-0000-0000-000000000004":
            "Burnt orange and pure black cards. Loud, warm, and impossible to mistake for anything else.",
        "theme:00000000-0000-0000-0000-000000000005":
            "Deep forest greens with a bright signal green accent. ",
        "theme:00000000-0000-0000-0000-000000000006":
            "Bark browns and mossy green. Our teams favorite.",

        // MARK: Cards — Common
        "card:default":
            "The original. pink, clean, and free forever.",

        // MARK: Cards — Rare (solid colors)
        "card:black":
            #"If you are asking "does it come in black? It does."#,
        "card:dark_green":
            "A deep pine green that makes gold badges pop.",
        "card:dark_purple":
            "Rich royal purple for a more medieval feel.",

        // MARK: Cards — Epic (art + gradients)
        "card:aurora":
            "Northern lights over a dark sky.",
        "card:ember":
            "Banked coals, deep reds glowing up out of the dark.",
        "card:cherry":
            "A crimson-to-plum diagonal. Bold at the top, moody at the bottom.",
        "card:shadow":
            "Charcoal fading to graphite. Subtle enough to wear with anything.",

        // MARK: Cards — Legendary (live animations)
        "card:nebula":
            "Live shooting stars streak across a violet nebula.",
        "card:galaxy":
            "A slow-turning spiral galaxy in blue and white.",
        "card:molten":
            "Cracked crust over moving lava. ",
        "card:cherry_blossom":
            "Petals drifting down in front of soft pink light. The calmest of the legendary cards.",

        // MARK: Cards — grant-only
        "card:founders_shooting_stars":
            "Founders Edition. The Shooting Stars card - A special gift for those that really support our team.",
        "card:founders_galaxy":
            "Founders Edition. Galaxy reworked in warm gold.",
        "card:founders_constellation":
            "Founders Edition. An original constellation in pink and gold",
        "card:gem_diamond":
            "Earned, not bought. Cut from the same facets as your first diamond badge.",
        "card:gem_emerald":
            "Earned, not bought. Awarded with your first emerald badge.",
        "card:gem_legend":
            "Earned, not bought. Congrats again on receiving the rarest card.",
    ]
}
