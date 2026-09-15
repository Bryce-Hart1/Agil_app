import SwiftUI

// Claude  Date 06/18/2026 last changed: 08/02/2026 by: Claude
// Renders a friend's shared card from a fetched SharedCard, reusing the exact same
// ProfileShowcaseCard the owner sees. The viewer's app already has the Achievement
// catalogue locally, so the ≤4 pinned ids are enough to draw the featured badges.
// We pass the pinned ids as the "unlocked" set too, since this build doesn't sync the
// full earned set — so the badge shelf shows just the featured ones (intentional).
// (The old paste-a-code FriendLookupView that lived here was replaced by the full
// friends manager in FriendsView; this card renderer is now used by that screen.)
//
// CLAUDE  Date 09/05/2026
// No back face here, deliberately. SharedCard carries no card-back fields yet, and a
// friend's device holds none of their training data — so the ONLY way to draw their back
// is from values they sent. Never fall back to the local user's stats to fill it: that
// would render YOUR numbers on THEIR card. Phase 2 adds the fields to SharedCard, maps
// them to [CardStatValue], and wraps this in CardFlipView; nothing else changes.
struct FriendCardView: View {
    let card: SharedCard
    // CLAUDE  Date 09/03/2026
    // The AGIL mark on a friend's card is the VIEWER's themed logo, not theirs — the theme
    // is what the local user owns, and SharedCard carries no theme.
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        ProfileShowcaseCard(
            name: card.displayName,
            style: CardStyle.style(for: card.cardStyleID),
            logoAsset: ThemeIcon.logoAsset(for: theme.current),
            unlockedIDs: Set(card.showcasedAchievementIDs),
            pinnedIDs: card.showcasedAchievementIDs,
            memberSince: card.memberSince,
            rank: card.showsRankOnCard ? card.rank : nil,
            rankProgress: card.rankProgress,
            // Claude  Date 09/14/2026 — honour the friend's own switch; nil (older card) shows.
            showsBadgeNames: card.showsBadgeNames ?? true
        )
    }
}
