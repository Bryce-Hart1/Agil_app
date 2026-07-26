import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 07/23/2026
// The "new card unlocked" reveal — shown when the user earns their first diamond /
// emerald achievement and is granted the matching gemstone profile card. Follows
// the app's overlay convention (dimmed backdrop, confetti, spring pop-in, live
// mini-preview) like FoundersUnlockOverlay / CelebrationOverlay, and is presented
// from RootTabView's overlay stack, driven by AppStore.pendingCardUnlock.
//
// Unlike the Founders reveal it offers an explicit choice: the card is NOT
// auto-equipped, so the user keeps whatever card they had — "Equip" swaps to the new
// one, "Not now" just keeps it in their collection (reachable from Edit Profile Card).
struct CardUnlockOverlay: View {
    let style: CardStyle
    let onEquip: () -> Void
    let onDismiss: () -> Void

    @State private var appear = false

    // The card's representative accent, used for the confetti + preview glow.
    private var accent: Color {
        if case .animated(let kind) = style.background { return kind.accent }
        return .white
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ConfettiView(colors: [accent, .white, accent.opacity(0.7), accent])
                .allowsHitTesting(false)

            VStack(spacing: 22) {
                Text("Reward Unlocked")
                    .font(.subheadline.weight(.bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(accent)

                Text("New Card")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)

                cardPreview

                VStack(spacing: 6) {
                    Text("\(style.name) card earned!")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("For reaching a \(style.name)-tier achievement.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button(action: onEquip) {
                        Text("Equip this card")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accent, in: Capsule())
                    }
                    Button("Not now", action: onDismiss)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 2)
                }
                .frame(width: 220)
                .padding(.top, 4)
            }
            .padding(36)
            .scaleEffect(appear ? 1 : 0.9)
            .opacity(appear ? 1 : 0)
        }
        .onAppear(perform: start)
    }

    // The granted card as a live mini-preview (its animated gemstone background).
    private var cardPreview: some View {
        CardBackgroundView(background: style.background)
            .frame(width: 132, height: 184)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.85), lineWidth: 1.5)
            )
            .shadow(color: accent.opacity(0.4), radius: 14, y: 4)
            .scaleEffect(appear ? 1 : 0.4)
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appear)
    }

    private func start() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appear = true }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

#Preview {
    CardUnlockOverlay(
        style: CardStyle.style(for: "gem_diamond"),
        onEquip: {},
        onDismiss: {}
    )
}
