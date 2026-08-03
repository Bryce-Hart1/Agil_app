import Foundation

// Claude  Date 06/13/2026 last changed: 07/23/2026 by: Claude
// Where the user wants their data to live (chosen during onboarding). "friends"
// (add others via a friend code, see their profile card) is a stated direction
// but not built yet — for now this just records the preference.
// (Renamed the private on-device mode "offline" → "ghost"; it's now surfaced to
// users as "Ghost Mode". Alpha build, no users, so the raw value changed too with
// no migration needed.)
enum DataMode: String, Codable, Hashable {
    case ghost     // "Ghost Mode": all data stays on device; can't add other users
    case friends   // can add others via a friend code (future)
}

// Claude  Date 07/14/2026
// The user's self-identified gender, chosen during onboarding. ON-DEVICE ONLY:
// it is used for exactly one thing — calibrating strength-badge thresholds
// (see Achievement.catalog(for:)) — and is deliberately absent from SharedCard/
// CardSyncService per the privacy contract in SharedCard.swift. .unspecified
// ("prefer not to say") uses the baseline thresholds.
enum Gender: String, Codable, Hashable, CaseIterable {
    case male, female, unspecified
}

// Claude  Date 06/09/2026 last changed: 08/02/2026 by: Claude
// The local user profile. Drives onboarding, the profile card, and (later) the
// online/shareable profile. Codable so it can sync to the backend.
// (Added gender — on-device badge calibration — and hasSeenTour, the one-shot
// flag for the first-boot spotlight tour. Then added `character`, the customizable
// user character that replaces the stock avatars — see the note on that field.)
struct UserProfile: Codable, Hashable {
    var displayName: String
    // Whether first-run onboarding (the welcome name prompt) has been completed.
    var hasOnboarded: Bool
    // The chosen profile-card style (CardStyle.id). Customizable via "Edit Profile Card".
    var cardStyleID: String
    // Claude  Date 06/30/2026 last changed: 08/02/2026 by: Claude
    // The chosen profile avatar (Avatar.id). Customizable via "Edit Profile Card".
    // Still live: it's what `character.isEnabled == false` falls back to, and
    // ThemeManager's unlockedAvatarIDs / coinsSpent key off it, so removing it would
    // orphan past purchases and silently change the coin balance.
    var avatarID: String
    // Claude  Date 08/02/2026
    // The customizable user character — layer option ids + colour tokens, resolved by
    // CharacterView. Coexists with avatarID rather than replacing it: isEnabled == false
    // means "use the stock Avatar catalogue instead", and the config survives that round
    // trip so switching back is lossless. ProfileFaceView is the single place that
    // decides between character, avatar and initials.
    var character: UserCharacter
    // The data-storage mode chosen during onboarding.
    var dataMode: DataMode
    // Claude  Date 06/13/2026
    // Achievement ids pinned to the profile card's featured row (max 4, ordered).
    var showcasedAchievementIDs: [String]
    // Claude  Date 07/14/2026
    // On-device only (never synced/shared): calibrates strength-badge thresholds.
    var gender: Gender
    // Claude  Date 07/14/2026
    // Whether the first-boot spotlight tour has been seen (completed OR skipped).
    var hasSeenTour: Bool
    // Claude  Date 07/25/2026
    // Progress through the nutrition world's setup checklist (Journal → the card
    // above Summary). Drives both that card's state and the First Plan badge.
    var nutritionSetup: NutritionSetup
    // Claude  Date 07/27/2026
    // Whether the user has acted on the Workouts tab's get-started state — either
    // way out of it counts: installing a premade split from the catalog, or starting
    // a workout (empty or from a preset). Drives the First Step badge. Sticky once
    // set; see AppStore.markFirstStep.
    var tookFirstStep: Bool

    init(displayName: String = "", hasOnboarded: Bool = false,
         cardStyleID: String = CardStyle.defaultStyle.id, avatarID: String = Avatar.defaultAvatar.id,
         dataMode: DataMode = .ghost,
         showcasedAchievementIDs: [String] = [],
         gender: Gender = .unspecified, hasSeenTour: Bool = false,
         nutritionSetup: NutritionSetup = NutritionSetup(),
         tookFirstStep: Bool = false,
         character: UserCharacter = .default) {
        self.displayName = displayName
        self.hasOnboarded = hasOnboarded
        self.cardStyleID = cardStyleID
        self.avatarID = avatarID
        self.character = character
        self.dataMode = dataMode
        self.showcasedAchievementIDs = showcasedAchievementIDs
        self.gender = gender
        self.hasSeenTour = hasSeenTour
        self.nutritionSetup = nutritionSetup
        self.tookFirstStep = tookFirstStep
    }

    // Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
    // Custom decode so profiles saved before these fields existed still load. If
    // hasOnboarded is absent, treat an already-named user as onboarded so we don't
    // re-show the welcome prompt. dataMode defaults to .ghost. cardStyleID is
    // new: if absent, migrate from the legacy cardColorHex (#000000 → "black",
    // anything else → the default style).
    enum CodingKeys: String, CodingKey {
        case displayName, hasOnboarded, cardStyleID, avatarID, dataMode, showcasedAchievementIDs,
             gender, hasSeenTour, nutritionSetup, tookFirstStep, character
    }
    private enum LegacyKeys: String, CodingKey { case cardColorHex }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? !displayName.isEmpty
        // Claude  Date 06/30/2026 — new field; older profiles default to the free avatar.
        avatarID = try c.decodeIfPresent(String.self, forKey: .avatarID) ?? Avatar.defaultAvatar.id
        dataMode = try c.decodeIfPresent(DataMode.self, forKey: .dataMode) ?? .ghost
        showcasedAchievementIDs = try c.decodeIfPresent([String].self, forKey: .showcasedAchievementIDs) ?? []
        // Claude  Date 07/14/2026 — new fields; older profiles default to baseline
        // thresholds and get the spotlight tour once on their next launch.
        gender = try c.decodeIfPresent(Gender.self, forKey: .gender) ?? .unspecified
        hasSeenTour = try c.decodeIfPresent(Bool.self, forKey: .hasSeenTour) ?? false
        // Claude  Date 07/25/2026 — new field; a profile saved before the nutrition
        // checklist existed starts it fresh, so the card appears once on next launch.
        nutritionSetup = try c.decodeIfPresent(NutritionSetup.self, forKey: .nutritionSetup) ?? NutritionSetup()
        // Claude  Date 07/27/2026 — new field; a profile saved before it existed
        // starts false and re-earns First Step the next time it starts a workout.
        tookFirstStep = try c.decodeIfPresent(Bool.self, forKey: .tookFirstStep) ?? false
        // Claude  Date 08/02/2026 — new field; a profile saved before characters existed
        // gets the default character, already enabled, so it picks one up on next launch
        // rather than staying on a stock avatar it never chose.
        character = try c.decodeIfPresent(UserCharacter.self, forKey: .character) ?? .default
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
