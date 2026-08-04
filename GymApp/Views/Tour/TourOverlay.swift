import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 07/14/2026 last changed: 07/28/2026 by: Claude
// The spotlight tour overlay: dims the whole app and lights a soft-edged spotlight
// on the current step's target, with a caption card that leapfrogs it (below when
// the target is up top, above when it's down bottom). Tap anywhere (or Next) to
// advance, Back to retrace a step; Skip ends it early — both finishing paths mark
// the tour as seen via onFinish. Follows the
// celebration-overlay conventions: self-contained ZStack, spring animations,
// light haptic per step. Rendered by RootTabView in full-screen coordinates (its
// GeometryReader ignores safe area), which is also the space `frameFor` resolves
// target frames in.
// (07/27) Was a hard-edged rounded-rect hole with a white stroke halo. A rectangle
// makes every point of frame error obvious — a 16pt-radius box around a capsule
// already looked wrong, and a target whose frame was off by 30pt read as a bug. The
// soft falloff says "look over here" instead of "this exact box", so the highlight
// survives the approximation. See `dimLayer` for how it's drawn.
struct TourOverlay: View {
    let steps: [TourStep]
    /// Resolves a target to its on-screen frame (preference anchor, then the global
    /// frame registry, then the synthesized chrome fallback — see RootTabView).
    /// nil = no frame; the step renders centered.
    let frameFor: (TourTarget) -> CGRect?
    /// Called BEFORE each step appears so RootTabView can switch mode/tab under us.
    let onApply: (TourStep) -> Void
    let onFinish: () -> Void

    /// The full-screen size, passed by RootTabView.
    let size: CGSize

    @State private var index = 0
    @State private var appear = false
    // Claude  Date 07/27/2026
    // The last frame we successfully resolved. advance() applies the step's app
    // state and bumps `index` in the same update, so on a step that flips worlds
    // (Journal) the old tab bar unmounts before the new one has reported anchors —
    // for one layout pass the target resolves to nil and the spotlight would snap
    // to the synthesized fallback and back. Holding the previous frame for that
    // pass turns a visible jump into nothing at all.
    @State private var lastCutout: CGRect?

    private var step: TourStep { steps[index] }
    private var isLast: Bool { index == steps.count - 1 }

    // Claude  Date 07/27/2026
    // Blur radius on the spotlight's edge — effectively the "forgiveness" dial. The
    // bright core still lands on the target; this is how far the light feathers out
    // past it, and how much frame error goes unnoticed.
    private static let glowBlur: CGFloat = 22

    // The padded spotlight rect for the current step, nil for free-floating steps.
    private var cutout: CGRect? {
        guard let target = step.target else { return nil }
        // Fall back to the last known frame rather than nil — see lastCutout.
        guard let frame = frameFor(target) ?? lastCutout else { return nil }
        // Claude  Date 07/14/2026 last changed: 07/27/2026 by: Claude
        // Generous padding: some chrome frames are synthesized approximations (see
        // TourTarget.fallbackFrame). (Widened from -8: the blur eats inward from
        // this rect's edge, so the core needs room to still cover the control.)
        return frame.insetBy(dx: -12, dy: -10)
    }

    // Corner radius of the lit area, derived from the target instead of a constant.
    // Short-and-wide things (the notch pill, tab items) come out capsule-ended,
    // which is what they actually are — the old hardcoded 16 drew a rectangle
    // around a Capsule.
    private func glowRadius(for rect: CGRect) -> CGFloat {
        min(rect.height / 2, 22)
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
        // Remember each resolved frame outside the layout pass, never in `body`.
        .onChange(of: index) { _ in captureFrame() }
        .onChange(of: resolvedFrame) { _ in captureFrame() }
    }

    // The raw (unpadded) frame for the current step's target, straight from the
    // resolver — what `lastCutout` tracks.
    private var resolvedFrame: CGRect? {
        step.target.flatMap(frameFor)
    }

    private func captureFrame() {
        if let frame = resolvedFrame { lastCutout = frame }
    }

    // MARK: - Dim + spotlight

    // Claude  Date 07/14/2026 last changed: 07/27/2026 by: Claude
    // The scrim with a soft-edged hole burned through it.
    //
    // A blurred white shape composited with .destinationOut is what produces the
    // gradient falloff: the shape's alpha (feathered by the blur) subtracts from the
    // scrim, so the light fades out instead of ending at an edge. .compositingGroup()
    // is required — without it the blend reaches past the ZStack and eats the app
    // underneath. A RadialGradient would NOT work here: it's circular in points
    // regardless of the frame's aspect, so a wide, short target like the notch pill
    // would have its ends left in the dark.
    //
    // The rim glow is drawn OUTSIDE the group, in normal blend mode — it adds light
    // around the hole rather than subtracting scrim, which is what sells it as a lamp
    // pointed at the screen rather than a hole cut in a mask.
    private var dimLayer: some View {
        let rect = cutout ?? offscreenRect
        let radius = glowRadius(for: rect)
        return ZStack {
            ZStack {
                Rectangle().fill(Color.black.opacity(0.78))
                RoundedRectangle(cornerRadius: radius)
                    .fill(.white)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .blur(radius: Self.glowBlur)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()

            if cutout != nil {
                RoundedRectangle(cornerRadius: radius + 10)
                    .fill(.white.opacity(0.10))
                    .frame(width: rect.width + 40, height: rect.height + 40)
                    .position(x: rect.midX, y: rect.midY)
                    .blur(radius: 30)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: cutout)
    }

    // Claude  Date 07/14/2026
    // Free-floating steps park the light far offscreen rather than removing it, so
    // it glides off and back on instead of popping.
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

            controls
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

    // Claude  Date 07/14/2026 last changed: 07/27/2026 by: Claude
    // Card placement: opposite half of the screen from the spotlight (below a top
    // target, above a bottom one), pulled toward the middle so it never collides
    // with the nav band or tab bar. Free-floating steps sit dead center.
    // (07/27) Measured from the glow's outer extent rather than the bare rect, and
    // the clearance grew to 190 — the light now feathers ~30pt past the cutout, so
    // the old 170 from the hard edge would have put the card inside the falloff.
    private var cardPosition: CGPoint {
        let centerX = size.width / 2
        guard let cutout else {
            return CGPoint(x: centerX, y: size.height / 2)
        }
        let glow = cutout.insetBy(dx: -Self.glowBlur, dy: -Self.glowBlur)
        if glow.midY < size.height / 2 {
            return CGPoint(x: centerX, y: min(glow.maxY + 190, size.height * 0.55))
        } else {
            return CGPoint(x: centerX, y: max(glow.minY - 190, size.height * 0.45))
        }
    }

    // Claude  Date 07/28/2026 last changed: 07/28/2026 by: Claude
    // Two equal capsules — Back and Next — with Skip as a quiet line beneath them.
    // (Was Skip-left / Next-right with no way back; then briefly a small circular
    // chevron, which was a poor tap target on a narrow phone.)
    //
    // Back and Next split the row via maxWidth: .infinity, which is what makes them
    // identical whatever their labels do — the last step's "Done" drops the arrow and
    // would otherwise come out visibly narrower than "Back". It also means they can
    // never overflow: they take what the card has and divide it.
    //
    // Skip sits BELOW rather than between the two. Three across doesn't fit: two
    // full-size capsules plus "Skip tour" plus the gaps runs ~348pt against the
    // ~287pt the card has inside its padding on a 375pt phone — it would collide at
    // DEFAULT type, before Dynamic Type enters the picture. Underneath it also reads
    // as more clearly secondary, which is the point: leaving is not what a new user
    // should be drawn to.
    //
    // Back is a weaker fill than Next (0.10 vs 0.18) — same size, not the same
    // emphasis — and holds its space on step 0 rather than being removed, so Next
    // doesn't resize on the first advance.
    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: goBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.subheadline.bold())
                        Text("Back").fontWeight(.semibold)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.10), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .opacity(index == 0 ? 0 : 1)
                .disabled(index == 0)
                .accessibilityHidden(index == 0)

                Button(action: advance) {
                    HStack(spacing: 6) {
                        Text(isLast ? "Done" : "Next").fontWeight(.semibold)
                        if !isLast {
                            Image(systemName: "arrow.right").font(.subheadline.bold())
                        }
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            if !isLast {
                Button("Skip tour") { finish() }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: index == 0)
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

    // Claude  Date 07/28/2026
    // The mirror of advance(): apply the previous step's app state first so the
    // world/tab it needs is already restored when the spotlight glides back to it.
    private func goBack() {
        guard index > 0 else { return }
        tick()
        onApply(steps[index - 1])
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { index -= 1 }
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
// Claude  Date 07/27/2026
// (SpotlightShape lived here — a full-screen rect with an even-odd rounded-rect
// hole, with animatableData so the hole glided between targets. The soft spotlight
// draws the hole as a blurred shape instead, whose .frame/.position animate on
// their own under dimLayer's .animation(value: cutout), so the shape had no
// remaining users and was deleted rather than left as dead code.)
