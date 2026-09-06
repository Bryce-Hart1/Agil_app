import SwiftUI

// CLAUDE  Date 09/05/2026
// Tapping the Profile tab's card opens this over the whole app (hosted from RootTabView,
// like the celebration overlays). Two stages: a fullscreen SHOWCASE of the card on a
// dimmed backdrop, and from there INSPECT mode — the backdrop goes near-black, the card
// follows the finger to turn over (swipe either way), leans with the phone's tilt, and
// catches light as it moves. Inspect is the only place a card flips outside the editor.
struct CardInspectOverlay: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var isInspecting = false
    @State private var isFlipped = false
    @State private var hasFlippedOnce = false
    @State private var backStats: CardBackStats = .empty
    @StateObject private var motion = CardMotionTilt()

    private var frontStyle: CardStyle { CardStyle.style(for: store.profile.cardStyleID) }
    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    var body: some View {
        ZStack {
            backdrop

            GeometryReader { geo in
                VStack(spacing: 0) {
                    card
                        .frame(width: cardWidth(in: geo.size), height: cardHeight(in: geo.size))
                        .scaleEffect(isInspecting ? 1.02 : 1)
                        .padding(.top, 14)
                    Spacer(minLength: 12)
                    bottomControls
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .scaleEffect(appear ? 1 : 0.92)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            backStats = store.cardBackStats
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { appear = true }
        }
        .onDisappear { motion.stop() }
    }

    // MARK: - Backdrop

    // A dim wash with a soft glow in the card's own accent behind it, so the card sits
    // in a pool of its colour rather than on flat black. No blur — a material backdrop
    // is the one thing here that older GPUs feel.
    private var backdrop: some View {
        ZStack {
            Color.black.opacity(isInspecting ? 0.94 : 0.82)
            RadialGradient(colors: [activeStyle.shadowColor.opacity(isInspecting ? 0.28 : 0.38),
                                    .clear],
                           center: .center, startRadius: 40, endRadius: 420)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // Tapping outside closes the showcase; in inspect a stray tap should not throw
        // you out mid-turn, so the button is the only exit there.
        .onTapGesture { if !isInspecting { dismiss() } }
    }

    private var activeStyle: CardStyle { isFlipped ? store.resolvedBackCardStyle : frontStyle }

    // MARK: - Card

    private var card: some View {
        CardFlipView(isFlipped: $isFlipped,
                     interactive: isInspecting,
                     swipeToFlip: isInspecting,
                     isEnabled: true,
                     tilt: isInspecting && !reduceMotion ? motion.tilt : .zero) {
            ProfileShowcaseCard(
                name: store.profile.resolvedName,
                style: frontStyle,
                logoAsset: ThemeIcon.logoAsset(for: theme.current),
                unlockedIDs: store.unlockedAchievementIDs,
                pinnedIDs: store.profile.showcasedAchievementIDs,
                memberSince: stats.memberSince,
                rank: store.strategistRank,
                rankProgress: store.strategistProgress,
                ringFillMode: .rankProgress,
                catalog: store.achievementCatalog
            )
        } back: {
            ProfileShowcaseCardBack(
                name: store.profile.resolvedName,
                style: store.resolvedBackCardStyle,
                logoAsset: ThemeIcon.logoAsset(for: theme.current),
                stats: backStats,
                memberSince: stats.memberSince
            )
        }
        .onChange(of: isFlipped) { _ in hasFlippedOnce = true }
        // The tilt arrives at 30 Hz already smoothed; a short interactive spring on top
        // hides the steps between samples without adding lag you can feel.
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.9), value: motion.tilt)
    }

    // CLAUDE  Date 09/05/2026
    // The card sits 14pt below the top edge and grows down; whatever is left over falls
    // between it and the controls. The reserved 132 is the controls (a caption, the pill,
    // 28pt bottom pad) plus the top pad and the minimum gap. The 1.65 cap is what the
    // height is usually driven by on a phone — tall enough to feel like a real card
    // without the flip's 5% lift pushing its top edge into the notch. Caps keep it sane
    // on iPad.
    private func cardWidth(in size: CGSize) -> CGFloat {
        min(size.width - 32, 420)
    }

    private func cardHeight(in size: CGSize) -> CGFloat {
        min(size.height - 132, cardWidth(in: size) * 1.65)
    }

    // MARK: - Chrome

    @ViewBuilder private var bottomControls: some View {
        VStack(spacing: 14) {
            if isInspecting {
                Text(hasFlippedOnce ? " " : "Swipe to turn the card over")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .animation(.easeOut(duration: 0.3), value: hasFlippedOnce)
                pill("Exit Inspect", systemImage: "xmark", prominent: false, action: exitInspect)
            } else {
                Text("Tap anywhere to close")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
                pill("Inspect", systemImage: "rotate.3d", prominent: true, action: enterInspect)
            }
        }
        .padding(.bottom, 28)
    }

    private func pill(_ title: String, systemImage: String, prominent: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(prominent ? .black : .white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(prominent ? Color.white : Color.white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transitions

    private func enterInspect() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { isInspecting = true }
        if !reduceMotion { motion.start() }
    }

    // Leaving inspect turns the card back to its front, so the showcase always shows the
    // same face you tapped to open it.
    private func exitInspect() {
        motion.stop()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            isInspecting = false
            isFlipped = false
        }
    }

    private func dismiss() {
        motion.stop()
        withAnimation(.easeIn(duration: 0.18)) { appear = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDismiss() }
    }
}
