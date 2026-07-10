import Foundation

// Claude  Date 06/30/2026
// A profile-card avatar — a small, GamePigeon-style set of pickable characters, some
// free and some coin-locked. Deliberately mirrors CardStyle so it reuses the same
// economy: the chosen avatar's `id` is stored on UserProfile.avatarID; which paid ones
// are owned lives in ThemeManager (unlockedAvatarIDs), so all coin spending flows through
// ThemeManager.coinsSpent.
//
// Art: `asset` is a full-colour PNG in Assets.xcassets (hand-built later). Until it's
// imported, AvatarView renders `fallbackSymbol` (an SF Symbol) instead — same
// asset-or-fallback trick as the rank emblem / badges — so the whole feature works now.
//
// To add an avatar: drop `avatar_foo` into Assets.xcassets and append one Avatar here.
struct Avatar: Identifiable, Hashable {
    let id: String
    let name: String
    let asset: String           // full-colour art asset name (e.g. "avatar_flex")
    let fallbackSymbol: String  // SF Symbol shown until the art exists
    let price: Int              // coin cost — 0 = free

    static let all: [Avatar] = [
        // Free defaults.
        Avatar(id: "classic", name: "Classic", asset: "avatar_classic", fallbackSymbol: "person.crop.circle.fill", price: 0),
        Avatar(id: "flex",    name: "Flex",    asset: "avatar_flex",    fallbackSymbol: "figure.strengthtraining.traditional", price: 0),
        // 500-coin tier.
        Avatar(id: "champ",   name: "Champ",   asset: "avatar_champ",   fallbackSymbol: "trophy.fill",   price: 500),
        Avatar(id: "blaze",   name: "Blaze",   asset: "avatar_blaze",   fallbackSymbol: "flame.fill",    price: 500),
        Avatar(id: "beast",   name: "Beast",   asset: "avatar_beast",   fallbackSymbol: "pawprint.fill", price: 500),
        // 1000-coin tier.
        Avatar(id: "crown",   name: "Royalty", asset: "avatar_crown",   fallbackSymbol: "crown.fill",       price: 1000),
        Avatar(id: "phantom", name: "Phantom", asset: "avatar_phantom", fallbackSymbol: "theatermasks.fill", price: 1000),
    ]

    /// The free default (a new profile starts here; also the fallback for a missing id).
    static var defaultAvatar: Avatar { all[0] }

    /// Resolve a stored avatar id back to an Avatar, falling back to the default.
    static func avatar(for id: String) -> Avatar {
        all.first { $0.id == id } ?? defaultAvatar
    }
}
