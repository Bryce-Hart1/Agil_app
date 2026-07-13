import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 07/12/2026
// The Founders Edition unlock celebration — a "thanks for supporting Agil" moment
// shown over the whole app when the founders cards are granted. Wired to
// AppStore.pendingFoundersUnlock and presented from RootTabView's overlay stack,
// matching the CelebrationOverlay / RankPromotionOverlay convention (dimmed
// backdrop, confetti, spring pop-in, tap anywhere to dismiss). Fired by the alpha
// dev tool today; by the real IAP purchase-success flow later. The cards are shown
// as live mini-previews (CardBackgroundView renders their animated backgrounds),
// staggered in so both reveal together but not in lockstep.
struct FoundersUnlockOverlay: View {
    let cards: [CardStyle]
    let onDismiss: () -> Void

    @State private var appear = false

    // Founders gold — matches CardTier.founders.color / the founders accent.
    private let gold = Color(red: 1.0, green: 0.82, blue: 0.25)

    var body: some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()

            ConfettiView(colors: [gold, .white, Color(red: 0.98, green: 0.68, blue: 0.45), gold])
                .allowsHitTesting(false)

            VStack(spacing: 22) {
                Text("Founders Edition")
                    .font(.subheadline.weight(.bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(gold)

                Text("Unlocked")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)

                cardRow

                VStack(spacing: 6) {
                    Text("Thanks for supporting Agil.")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("These cards are yours to keep.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Text("Tap to continue")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
            }
            .padding(36)
            .scaleEffect(appear ? 1 : 0.9)
            .opacity(appear ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear(perform: start)
    }

    // The founders cards as live mini-previews, side by side, each popping in on a
    // slight per-card delay so the reveal builds.
    private var cardRow: some View {
        HStack(spacing: 18) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, style in
                VStack(spacing: 8) {
                    CardBackgroundView(background: style.background)
                        .frame(width: 120, height: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(gold.opacity(0.8), lineWidth: 1.5)
                        )
                        .shadow(color: gold.opacity(0.35), radius: 12, y: 4)

                    Text(cardShortName(style))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: 120)
                }
                .scaleEffect(appear ? 1 : 0.4)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6)
                    .delay(0.1 + Double(index) * 0.12), value: appear)
            }
        }
    }

    // Drop the " — Founders Edition" suffix for the compact caption under each card.
    private func cardShortName(_ style: CardStyle) -> String {
        style.name.components(separatedBy: " — ").first ?? style.name
    }

    private func start() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appear = true }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

#Preview {
    FoundersUnlockOverlay(
        cards: CardStyle.all.filter { $0.isFounders },
        onDismiss: {}
    )
}
