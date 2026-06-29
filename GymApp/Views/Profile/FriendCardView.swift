import SwiftUI

// Claude  Date 06/18/2026
// Renders a friend's shared card from a fetched SharedCard, reusing the exact same
// ProfileShowcaseCard the owner sees. The viewer's app already has the Achievement
// catalogue locally, so the ≤4 pinned ids are enough to draw the featured badges.
// We pass the pinned ids as the "unlocked" set too, since this build doesn't sync the
// full earned set — so the badge shelf shows just the featured ones (intentional).
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

// Claude  Date 06/18/2026
// Paste a friend code → fetch and show their card. The plumbing-only friends feature:
// no stored friend list yet, just look one up on demand. Pushed from Settings.
struct FriendLookupView: View {
    @EnvironmentObject private var cardSync: CardSyncService
    @EnvironmentObject private var theme: ThemeManager

    @State private var code = ""
    @State private var card: SharedCard?
    @State private var phase: Phase = .idle

    private enum Phase { case idle, loading, notFound, loaded }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    TextField("Paste a friend code", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit(lookup)
                    Button("View", action: lookup)
                        .buttonStyle(.borderedProminent)
                        .tint(theme.current.accent)
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                switch phase {
                case .idle:
                    hint("Ask a friend for their code (Settings → Friends) and paste it here to see their card.")
                case .loading:
                    ProgressView().padding(.top, 24)
                case .notFound:
                    hint("No card found for that code. Double-check it, or make sure your friend has Friends mode on.")
                case .loaded:
                    if let card {
                        FriendCardView(card: card)
                            .frame(height: 460)
                    }
                }
            }
            .padding(16)
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle("Friend's Card")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 24)
            .padding(.horizontal)
    }

    private func lookup() {
        let query = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        phase = .loading
        Task {
            let result = await cardSync.fetchFriendCard(id: query)
            card = result
            phase = (result == nil) ? .notFound : .loaded
        }
    }
}
