import Foundation

// Claude  Date 06/18/2026 last changed: 08/02/2026 by: Claude
// The ENTIRE payload that leaves the device when a user is in Friends mode — the
// contents of their profile card, nothing else. This is the privacy contract:
// training history, nutrition, water, the full earned-achievement set, and any
// future bodyweight/sex/height fields are deliberately absent and never sent.
// (UserProfile.gender now exists — it is one of those deliberately-absent fields:
// on-device only, used solely for badge-threshold calibration. Never add it here.)
//
// camelCase keys match the backend's serde output and the rest of the app's JSON.
// `rank` is the equipped StrategistRank (Codable as its Int rawValue), present only
// when the user equipped it. Only the ≤4 *pinned* achievement ids ride along — enough
// for a friend's app to draw the featured badge row from its local Achievement
// catalogue — not the whole unlocked set (that's a later build).
//
// `updatedAt` is set at push time and left nil in locally-built snapshots, so it
// stays out of the change-detection compare (see CardSyncService dedupe).
//
// Claude  Date 07/14/2026
// `friendCode` is the short (5-char Crockford base-32) human-shareable code the
// backend assigns and OWNS: the client can never set it (it's ignored on PUT and
// only read from responses), so it's nil in locally-built snapshots and populated
// only on cards fetched from the server. `userId` remains the UUID used everywhere
// as the stable identity — friend requests are sent BY code, but accept/decline/
// unfriend/unblock all key off the other user's `userId`.
//
// Claude  Date 08/07/2026
// `character` is gone with the profile-face feature. Nothing is sent for it any more, and a
// payload that still CARRIES one (a friend on an older build, or a backend that stored the
// field) decodes fine — an unknown key is ignored, never an error — so no coordinated
// release is required. Everyone renders as initials, which is what every friend already
// rendered as in practice. No `avatarID` was ever in this payload.
struct SharedCard: Codable, Equatable {
    var userId: String
    var displayName: String
    var cardStyleID: String
    var showsRankOnCard: Bool
    var rank: StrategistRank?
    var rankProgress: Double
    var showcasedAchievementIDs: [String]
    var memberSince: Date?
    var updatedAt: Date?
    // Server-owned; see note above. Optional + defaulted so local construction and
    // decoding of older/keyless payloads both stay valid.
    var friendCode: String? = nil
    // Claude  Date 09/14/2026
    // Whether badge titles show under the featured badges. Optional so a card from an older
    // build (or a backend that doesn't store it yet) decodes as nil, which renders as SHOWN —
    // the behaviour every card had before this switch existed.
    var showsBadgeNames: Bool? = nil
    // CLAUDE  Date 09/24/2026
    // The owner's header/avatar/progress/text-colour choices. nil (older build, or a backend
    // not storing it yet) renders the default layout. CardLayout's decoder never throws on
    // unknown values, so a newer friend's new avatar can't break this whole card's decode.
    var cardLayout: CardLayout? = nil
}
