import Foundation

// Claude  Date 06/13/2026
// What's drawn behind the profile card's content. Designed as a small enum so
// the look is *scalable*: a solid color today, a PNG asset today, and an
// animated background later — each new kind is one extra case here plus one
// branch in CardBackgroundView (the only place that knows how to render it).
enum CardBackground: Hashable {
    case color(hex: String)     // a solid color (rendered as a subtle gradient)
    case image(asset: String)   // a PNG in Assets.xcassets, drawn full-bleed
    // case animated(...)        // future: video / Lottie / TimelineView
}

// Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
// A purchasable look for the profile card. The chosen style's *id* is stored on
// UserProfile.cardStyleID; which paid styles are owned lives in ThemeManager
// (unlockedCardStyleIDs) so all coin spending is tracked in one place.
//
// To add a new card: drop a PNG imageset into Assets.xcassets (e.g. "card_foo")
// and append one CardStyle(id:name:background:.image(asset:"card_foo"),price:) here.
struct CardStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let background: CardBackground
    let price: Int

    static let all: [CardStyle] = [
        CardStyle(id: "default", name: "Classic Pink", background: .color(hex: "#EA0F8B"), price: 0),
        CardStyle(id: "black",   name: "Black",        background: .color(hex: "#000000"), price: 500),
        // Example image cards (PNGs generated into Assets.xcassets) — proof of the
        // overlay pipeline; free for now so they're viewable, set any price later.
        CardStyle(id: "aurora",  name: "Aurora",       background: .image(asset: "card_aurora"), price: 0),
        CardStyle(id: "ember",   name: "Ember",        background: .image(asset: "card_ember"),  price: 0),
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
