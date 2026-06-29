import Foundation

// Claude  Date 06/18/2026
// The ENTIRE payload that leaves the device when a user is in Friends mode — the
// contents of their profile card, nothing else. This is the privacy contract:
// training history, nutrition, water, the full earned-achievement set, and any
// future bodyweight/sex/height fields are deliberately absent and never sent.
//
// camelCase keys match the backend's serde output and the rest of the app's JSON.
// `rank` is the equipped StrategistRank (Codable as its Int rawValue), present only
// when the user equipped it. Only the ≤4 *pinned* achievement ids ride along — enough
// for a friend's app to draw the featured badge row from its local Achievement
// catalogue — not the whole unlocked set (that's a later build).
//
// `updatedAt` is set at push time and left nil in locally-built snapshots, so it
// stays out of the change-detection compare (see CardSyncService dedupe).
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
}
