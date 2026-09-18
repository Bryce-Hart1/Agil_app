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

    // Bryce (Claude) Date 07/23/2026
    // Card preview aspect (width:height). The row sizes cards off the available
    // width and derives height from this so proportions hold as cards shrink.
    private let cardAspect: CGFloat = 168.0 / 120.0

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
            // Bryce (Claude) 07/12/2026 last changed: 07/23/2026 by: Claude
            // Vertical padding kept generous; horizontal trimmed to 24 so the
            // card row has more width to fit on narrow phones (was .padding(36),
            // which — with fixed 120pt cards — pushed the outer cards off-screen).
            .padding(.vertical, 36)
            .padding(.horizontal, 24)
            .scaleEffect(appear ? 1 : 0.9)
            .opacity(appear ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear(perform: start)
    }

    // Bryce (Claude) 07/12/2026 last changed: 07/23/2026 by: Claude
    // The founders cards as live mini-previews, side by side, each popping in on a
    // slight per-card delay so the reveal builds. Cards now size off the available
    // width (capped at 120pt) so the row always fits on-screen — the previous
    // hard-fixed 120pt widths overflowed the bezel on every iPhone and clipped the
    // outer two cards. The GeometryReader is given a fixed height (the max card
    // height + caption room) so it doesn't consume the surrounding VStack's space.
    private var cardRow: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 14
            let n = CGFloat(cards.count)
            let cardW = min(120, (geo.size.width - spacing * (n - 1)) / n)
            let cardH = cardW * cardAspect

            HStack(spacing: spacing) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, style in
                    VStack(spacing: 8) {
                        // CLAUDE  Date 09/17/2026
                        // Mini previews, three at once — preview motion budget.
                        CardBackgroundView(background: style.background, cornerRadius: 16)
                            .cardMotionDetail(.preview)
                            .frame(width: cardW, height: cardH)
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
                            .frame(width: cardW)
                    }
                    .scaleEffect(appear ? 1 : 0.4)
                    .opacity(appear ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6)
                        .delay(0.1 + Double(index) * 0.12), value: appear)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Fixed height: tallest possible card (120 × aspect = 168) + caption row.
        .frame(height: 120 * cardAspect + 30)
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
