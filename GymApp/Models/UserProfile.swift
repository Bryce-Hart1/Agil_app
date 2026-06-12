import Foundation

// Claude  Date 06/09/2026 last changed: 06/12/2026 by: Claude
// The local user profile. Drives onboarding, the profile card, and (later) the
// online/shareable profile. Codable so it can sync to the backend.
struct UserProfile: Codable, Hashable {
    var displayName: String
    // Whether first-run onboarding (the welcome name prompt) has been completed.
    var hasOnboarded: Bool
    // The profile card's color (hex). Customizable via "Edit Profile Card".
    var cardColorHex: String

    init(displayName: String = "", hasOnboarded: Bool = false, cardColorHex: String = "#EA0F8B") {
        self.displayName = displayName
        self.hasOnboarded = hasOnboarded
        self.cardColorHex = cardColorHex
    }

    // Claude  Date 06/12/2026
    // Custom decode so profiles saved before these fields existed still load. If
    // hasOnboarded is absent, treat an already-named user as onboarded so we
    // don't re-show the welcome prompt to existing users.
    enum CodingKeys: String, CodingKey { case displayName, hasOnboarded, cardColorHex }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? !displayName.isEmpty
        cardColorHex = try c.decodeIfPresent(String.self, forKey: .cardColorHex) ?? "#EA0F8B"
    }

    /// Name to show in the UI, falling back to a placeholder when unset.
    var resolvedName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Your Name" : trimmed
    }
}
