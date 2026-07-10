import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 06/15/2026
// The "Promotion!" moment when the Strategist rank climbs. Mirrors the achievement
// CelebrationOverlay's language (dim backdrop, confetti, expanding pulse rings, a
// spring-in emblem) but for a chess rank — shown over the whole app AFTER the
// badge celebrations drain, so you watch badges pop and then get crowned. Reuses
// ConfettiView from CelebrationOverlay. Tap anywhere to dismiss.
struct RankPromotionOverlay: View {
    let rank: StrategistRank
    let remaining: Int            // how many more promotions are queued behind this
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var ring = false
    // Claude  Date 07/09/2026
    // Drives the newest segment of the RankRing sweeping in (0 → 1) just after the crest
    // springs on — the "you just earned this rank" beat.
    @State private var reveal: Double = 0

    private var color: Color { rank.tier.color }

    private let heroSize: CGFloat = 150

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Promotion")
                    .font(.subheadline.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.9))
                    .textCase(.uppercase)

                emblem

                VStack(spacing: 4) {
                    Text(rank.title)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    Text("Strategist rank")
                        .font(.headline)
                        .foregroundStyle(color)
                }

                Text(remaining > 0 ? "Tap to continue · \(remaining) more" : "Tap to continue")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 10)
            }
            .padding(40)
            .scaleEffect(appear ? 1 : 0.92)
            .opacity(appear ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear(perform: start)
    }

    // Claude  Date 06/15/2026 last changed: 07/09/2026 by: Claude
    // The hero crest. Now the RankRing (segmented rank ring) instead of the bare chess
    // emblem, with the rank's glyph in the core — so the promotion shows the same crest
    // the profile card wears, and the newly-earned segment lights up as you watch.
    private var emblem: some View {
        ZStack {
            ConfettiView(colors: [color, .white, .yellow, color.opacity(0.7)])
                .allowsHitTesting(false)

            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 3)
                    .frame(width: 160, height: 160)
                    .scaleEffect(ring ? 1.6 : 0.7)
                    .opacity(ring ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.8).repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.9),
                        value: ring
                    )
            }

            RankRing(rank: rank, size: heroSize, showsProgress: false, revealProgress: reveal) {
                StrategistEmblem(rank: rank,
                                 size: RingGeometry.coreDiameter(for: heroSize),
                                 showProgress: false)
            }
            .scaleEffect(appear ? 1 : 0.2)
            .rotationEffect(.degrees(appear ? 0 : -30))
        }
        .frame(height: 180)
    }

    private func start() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { appear = true }
        ring = true
        // Let the crest spring in first, then sweep the newly-earned segment closed.
        withAnimation(.easeInOut(duration: 0.8).delay(0.45)) { reveal = 1 }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

#Preview {
    RankPromotionOverlay(rank: .legend, remaining: 0, onDismiss: {})
}
