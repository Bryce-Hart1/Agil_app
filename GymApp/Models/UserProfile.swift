import Foundation

// Claude  Date 06/13/2026
// Where the user wants their data to live (chosen during onboarding). "friends"
// (add others via a friend code, see their profile card) is a stated direction
// but not built yet — for now this just records the preference.
enum DataMode: String, Codable, Hashable {
    case offline   // all data stays on device; can't add other users
    case friends   // can add others via a friend code (future)
}

// Claude  Date 06/09/2026 last changed: 06/13/2026 by: Claude
// The local user profile. Drives onboarding, the profile card, and (later) the
// online/shareable profile. Codable so it can sync to the backend.
// (Added dataMode — the onboarding data-storage choice.)
struct UserProfile: Codable, Hashable {
    var displayName: String
    // Whether first-run onboarding (the welcome name prompt) has been completed.
    var hasOnboarded: Bool
    // The chosen profile-card style (CardStyle.id). Customizable via "Edit Profile Card".
    var cardStyleID: String
    // The data-storage mode chosen during onboarding.
    var dataMode: DataMode
    // Claude  Date 06/13/2026
    // Achievement ids pinned to the profile card's featured row (max 4, ordered).
    var showcasedAchievementIDs: [String]
    // Claude  Date 06/15/2026
    // Whether the Strategist rank emblem is equipped onto the showcase card. Off by
    // default; the rank still always shows in the banner below the card.
    var showsRankOnCard: Bool

    init(displayName: String = "", hasOnboarded: Bool = false,
         cardStyleID: String = CardStyle.defaultStyle.id, dataMode: DataMode = .offline,
         showcasedAchievementIDs: [String] = [], showsRankOnCard: Bool = false) {
        self.displayName = displayName
        self.hasOnboarded = hasOnboarded
        self.cardStyleID = cardStyleID
        self.dataMode = dataMode
        self.showcasedAchievementIDs = showcasedAchievementIDs
        self.showsRankOnCard = showsRankOnCard
    }

    // Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
    // Custom decode so profiles saved before these fields existed still load. If
    // hasOnboarded is absent, treat an already-named user as onboarded so we don't
    // re-show the welcome prompt. dataMode defaults to .offline. cardStyleID is
    // new: if absent, migrate from the legacy cardColorHex (#000000 → "black",
    // anything else → the default style).
    enum CodingKeys: String, CodingKey {
        case displayName, hasOnboarded, cardStyleID, dataMode, showcasedAchievementIDs, showsRankOnCard
    }
    private enum LegacyKeys: String, CodingKey { case cardColorHex }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? !displayName.isEmpty
        dataMode = try c.decodeIfPresent(DataMode.self, forKey: .dataMode) ?? .offline
        showcasedAchievementIDs = try c.decodeIfPresent([String].self, forKey: .showcasedAchievementIDs) ?? []
        showsRankOnCard = try c.decodeIfPresent(Bool.self, forKey: .showsRankOnCard) ?? false
        if let id = try c.decodeIfPresent(String.self, forKey: .cardStyleID) {
            cardStyleID = id
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let hex = try legacy.decodeIfPresent(String.self, forKey: .cardColorHex)
            cardStyleID = CardStyle.id(forLegacyHex: hex) ?? CardStyle.defaultStyle.id
        }
    }

    /// Name to show in the UI, falling back to a placeholder when unset.
    var resolvedName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Your Name" : trimmed
    }
}
