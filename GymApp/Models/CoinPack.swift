import Foundation

// Claude  Date 08/03/2026
// The coin packs sold through the App Store. Roughly 1,000 coins per dollar, with a
// little extra on the bigger packs — so one legendary item (3,000) is the middle
// pack with change left over, and the top pack is two legendaries.
//
// Deliberately NOT stored here: the price. StoreKit owns that. We ask it for
// `product.displayPrice`, which arrives already localised and already correct for
// the user's storefront — a hardcoded "$2.99" would be wrong in most of the world
// and would silently rot the day a price point changes. The app only knows how many
// coins a product id is worth; App Store Connect knows what it costs.
//
// The ids below must match the products created in App Store Connect *and* the ones
// in Agil.storekit (the local test configuration) exactly.
enum CoinPack: String, CaseIterable, Identifiable {
    case small  = "com.brycehart.gymapp.coins.1000"
    case medium = "com.brycehart.gymapp.coins.3500"
    case large  = "com.brycehart.gymapp.coins.6000"

    var id: String { rawValue }

    /// The product identifier as StoreKit knows it.
    var productID: String { rawValue }

    /// How many coins this pack grants. The one number the app owns, not the Store.
    var coins: Int {
        switch self {
        case .small:  return 1_000
        case .medium: return 3_500
        case .large:  return 6_000
        }
    }

    /// Shop-facing name.
    var name: String {
        switch self {
        case .small:  return "Handful"
        case .medium: return "Stack"
        case .large:  return "Hoard"
        }
    }

    // Claude  Date 08/03/2026
    // A line of context under each pack, anchored to what the coins actually buy —
    // more useful than "best value!" and honest about what you're getting.
    var blurb: String {
        switch self {
        case .small:  return "A rare card, with change."
        case .medium: return "One legendary theme or card."
        case .large:  return "Two legendary items."
        }
    }

    /// Highlighted in the coin shop as the one most people want.
    var isFeatured: Bool { self == .medium }

    static var allProductIDs: [String] { allCases.map(\.productID) }

    /// Resolve a StoreKit product id back to a pack (nil for anything we don't sell).
    static func pack(for productID: String) -> CoinPack? {
        CoinPack(rawValue: productID)
    }
}
