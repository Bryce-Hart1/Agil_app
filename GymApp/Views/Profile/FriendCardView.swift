import SwiftUI

// Claude  Date 06/18/2026 last changed: 07/14/2026 by: Claude
// Renders a friend's shared card from a fetched SharedCard, reusing the exact same
// ProfileShowcaseCard the owner sees. The viewer's app already has the Achievement
// catalogue locally, so the ≤4 pinned ids are enough to draw the featured badges.
// We pass the pinned ids as the "unlocked" set too, since this build doesn't sync the
// full earned set — so the badge shelf shows just the featured ones (intentional).
// (The old paste-a-code FriendLookupView that lived here was replaced by the full
// friends manager in FriendsView; this card renderer is now used by that screen.)
struct FriendCardView: View {
    let card: SharedCard

    var body: some View {
        ProfileShowcaseCard(
            name: card.displayName,
            style: CardStyle.style(for: card.cardStyleID),
            unlockedIDs: Set(card.showcasedAchievementIDs),
            pinnedIDs: card.showcasedAchievementIDs,
            memberSince: card.memberSince,
            rank: card.showsRankOnCard ? card.rank : nil,
            rankProgress: card.rankProgress
        )
    }
}
