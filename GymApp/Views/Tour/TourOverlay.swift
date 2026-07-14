import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 07/14/2026
// The spotlight tour overlay: dims the whole app and cuts a glowing rounded-rect
// hole around the current step's target, with a caption card that leapfrogs the
// cutout (below it when the target is up top, above it when it's down bottom).
// Tap anywhere (or Next) to advance; Skip ends it early — both mark the tour as
// seen via onFinish. Follows the celebration-overlay conventions: self-contained
// ZStack, spring animations, light haptic per step. Rendered by RootTabView in
// full-screen coordinates (its GeometryReader ignores safe area), which is also
// the space `frameFor` resolves target frames in.
struct TourOverlay: View {
    let steps: [TourStep]
    /// Resolves a target to its on-screen frame (preference anchor first, then the
    /// synthesized chrome fallback). nil = no frame; the step renders centered.
    let frameFor: (TourTarget) -> CGRect?
    /// Called BEFORE each step appears so RootTabView can switch mode/tab under us.
    let onApply: (TourStep) -> Void
    let onFinish: () -> Void

    /// The full-screen size and safe-area insets, passed by RootTabView.
    let size: CGSize
    let insets: EdgeInsets

    @State private var index = 0
    @State private var appear = false

    private var step: TourStep { steps[index] }
    private var isLast: Bool { index == steps.count - 1 }

    // The padded cutout rect for the current step, nil for free-floating steps.
    private var cutout: CGRect? {
        guard let target = step.target, let frame = frameFor(target) else { return nil }
        // Claude  Date 07/14/2026
        // Generous padding: the chrome frames are synthesized approximations
        // (see TourTarget.fallbackFrame), so the halo hides small inaccuracies.
        return frame.insetBy(dx: -8, dy: -8)
    }

    var body: some View {
        ZStack {
            dimLayer
            captionCard
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: advance)
        .onAppear {
            onApply(steps[0])
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appear = true }
        }
    }

    // MARK: - Dim + spotlight

    private var dimLayer: some View {
        ZStack {
            Color.black.opacity(0.65)
                .mask(
                    SpotlightShape(rect: cutout ?? offscreenRect)
                        .fill(style: FillStyle(eoFill: true))
                )
            // Accent halo around the hole so the highlighted control pops.
            if let cutout {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.85), lineWidth: 2)
                    .frame(width: cutout.width, height: cutout.height)
                    .position(x: cutout.midX, y: cutout.midY)
                    .shadow(color: .white.opacity(0.5), radius: 8)
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: cutout)
    }

    // Claude  Date 07/14/2026
    // Free-floating steps still use SpotlightShape (so the hole glides off/on
    // screen instead of popping) — just with the hole parked far offscreen.
    private var offscreenRect: CGRect {
        CGRect(x: -400, y: size.height / 2, width: 1, height: 1)
    }

    // MARK: - Caption card

    private var captionCard: some View {
        VStack(spacing: 14) {
            Text(step.title)
                .font(.system(.title3, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(step.message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            progressDots

            HStack(spacing: 12) {
                if !isLast {
                    Button("Skip tour") { finish() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .buttonStyle(.plain)
                }
                Spacer()
                Button(action: advance) {
                    HStack(spacing: 6) {
                        Text(isLast ? "Done" : "Next").fontWeight(.semibold)
                        if !isLast {
                            Image(systemName: "arrow.right").font(.subheadline.bold())
                        }
                    }
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 22))
        .background(Color.black.opacity(0.35),
                    in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22)
            .stroke(.white.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 24)
        .scaleEffect(appear ? 1 : 0.94)
        .opacity(appear ? 1 : 0)
        .position(cardPosition)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: index)
    }

    // Claude  Date 07/14/2026
    // Card placement: opposite half of the screen from the cutout (below a top
    // target, above a bottom one), pulled toward the middle so it never collides
    // with the nav band or tab bar. Free-floating steps sit dead center.
    private var cardPosition: CGPoint {
        let centerX = size.width / 2
        guard let cutout else {
            return CGPoint(x: centerX, y: size.height / 2)
        }
        if cutout.midY < size.height / 2 {
            return CGPoint(x: centerX, y: min(cutout.maxY + 170, size.height * 0.55))
        } else {
            return CGPoint(x: centerX, y: max(cutout.minY - 170, size.height * 0.45))
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? .white : .white.opacity(0.3))
                    .frame(width: i == index ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
    }

    // MARK: - Navigation

    private func advance() {
        tick()
        guard !isLast else { finish(); return }
        let next = steps[index + 1]
        // Apply the app-state change FIRST so the target exists (right mode/tab)
        // when the spotlight glides over to it on the next layout pass.
        onApply(next)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { index += 1 }
    }

    private func finish() {
        // Land the user on the outro's home state (Lifting → Workouts) even when
        // skipping from the middle of the Food-world step.
        onApply(steps[steps.count - 1])
        onFinish()
    }

    private func tick() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// Claude  Date 07/14/2026
// Full-screen rect with a rounded-rect hole, filled even-odd so the inner rect
// masks to transparency. The rect is animatable, which is what makes the
// spotlight glide smoothly from one target to the next.
struct SpotlightShape: Shape {
    var rect: CGRect
    var cornerRadius: CGFloat = 16

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>,
                                       AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(AnimatablePair(rect.minX, rect.minY),
                           AnimatablePair(rect.width, rect.height))
        }
        set {
            rect = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first, height: newValue.second.second)
        }
    }

    func path(in bounds: CGRect) -> Path {
        var path = Path()
        path.addRect(bounds)
        path.addRoundedRect(in: rect,
                            cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}
