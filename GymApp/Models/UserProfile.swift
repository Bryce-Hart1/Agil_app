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
// flag for the first-boot spotlight tour.)
//
// Claude  Date 08/07/2026 — `avatarID` and `character` are gone with the profile-face
// feature (stock avatars, the customizable character, and the coin flip that revealed it).
// The card's picture is the rank emblem now. Old profiles still carry both keys on disk;
// the decoder simply ignores unknown keys, so nothing needs migrating.
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
    // CLAUDE  Date 09/05/2026
    // The card's BACK face. cardBackStyleID nil means "Match front" — the back tracks
    // whatever the front is set to, rather than a copied id that would strand the back
    // on a stale style. The stat ids are ordered CardStat raw values (hero is separate,
    // and may repeat in neither list); unknown ids are dropped at render, not decode.
    var cardBackStyleID: String?
    var cardBackHeroStat: String?
    var cardBackStatIDs: [String]
    // Claude  Date 09/07/2026
    // Bodyweight in pounds, asked for once when cardio is first logged and skippable.
    // ON-DEVICE ONLY, like `gender`: it feeds exactly one thing — the MET calorie estimate
    // in CardioPolicy — and is absent from SharedCard/CardSyncService per the privacy
    // contract in SharedCard.swift, which already names future bodyweight fields. nil means
    // "not given", and every calorie surface shows nothing rather than guessing.
    var bodyweightLb: Double?
    // Claude  Date 09/14/2026
    // Whether the front's featured badges print their titles under the icons. Switched in
    // Edit Profile Card and shared with friends (SharedCard.showsBadgeNames), so turning it
    // off hides the names on YOUR card everywhere, including on friends' screens.
    var showsBadgeNamesOnCard: Bool

    init(displayName: String = "", hasOnboarded: Bool = false,
         cardStyleID: String = CardStyle.defaultStyle.id,
         dataMode: DataMode = .ghost,
         showcasedAchievementIDs: [String] = [],
         gender: Gender = .unspecified, hasSeenTour: Bool = false,
         nutritionSetup: NutritionSetup = NutritionSetup(),
         tookFirstStep: Bool = false,
         cardBackStyleID: String? = nil, cardBackHeroStat: String? = nil,
         cardBackStatIDs: [String] = [], bodyweightLb: Double? = nil,
         showsBadgeNamesOnCard: Bool = true) {
        self.displayName = displayName
        self.hasOnboarded = hasOnboarded
        self.cardStyleID = cardStyleID
        self.dataMode = dataMode
        self.showcasedAchievementIDs = showcasedAchievementIDs
        self.gender = gender
        self.hasSeenTour = hasSeenTour
        self.nutritionSetup = nutritionSetup
        self.tookFirstStep = tookFirstStep
        self.cardBackStyleID = cardBackStyleID
        self.cardBackHeroStat = cardBackHeroStat
        self.cardBackStatIDs = cardBackStatIDs
        self.bodyweightLb = bodyweightLb
        self.showsBadgeNamesOnCard = showsBadgeNamesOnCard
    }

    // Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
    // Custom decode so profiles saved before these fields existed still load. If
    // hasOnboarded is absent, treat an already-named user as onboarded so we don't
    // re-show the welcome prompt. dataMode defaults to .ghost. cardStyleID is
    // new: if absent, migrate from the legacy cardColorHex (#000000 → "black",
    // anything else → the default style).
    // (08/07/2026: `avatarID` and `character` removed with the profile-face feature. They
    // stay in older files on disk and are simply ignored — unknown keys never fail a decode.)
    enum CodingKeys: String, CodingKey {
        case displayName, hasOnboarded, cardStyleID, dataMode, showcasedAchievementIDs,
             gender, hasSeenTour, nutritionSetup, tookFirstStep,
             cardBackStyleID, cardBackHeroStat, cardBackStatIDs, bodyweightLb,
             showsBadgeNamesOnCard
    }
    private enum LegacyKeys: String, CodingKey { case cardColorHex }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? !displayName.isEmpty
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
        // CLAUDE  Date 09/05/2026 — new fields; a profile saved before the card back
        // existed gets a back that matches the front and carries no stats yet.
        cardBackStyleID = try c.decodeIfPresent(String.self, forKey: .cardBackStyleID)
        cardBackHeroStat = try c.decodeIfPresent(String.self, forKey: .cardBackHeroStat)
        cardBackStatIDs = try c.decodeIfPresent([String].self, forKey: .cardBackStatIDs) ?? []
        // Claude  Date 09/07/2026 — new field; a profile saved before cardio existed has no
        // bodyweight, so calorie estimates stay hidden until it's given.
        bodyweightLb = try c.decodeIfPresent(Double.self, forKey: .bodyweightLb)
        // Claude  Date 09/14/2026 — new field; older profiles keep showing badge names.
        showsBadgeNamesOnCard = try c.decodeIfPresent(Bool.self, forKey: .showsBadgeNamesOnCard) ?? true
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
