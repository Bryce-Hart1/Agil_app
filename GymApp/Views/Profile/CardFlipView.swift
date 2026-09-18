import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// CLAUDE  Date 09/05/2026
// Which face of the profile card is showing. Shared by the card itself and by the
// Front/Back selector in Edit Profile Card, so the control and the card can't disagree.
enum CardFace: String, CaseIterable, Identifiable {
    case front, back
    var id: String { rawValue }
    var title: String { self == .front ? "Front" : "Back" }

    // One definition of the turn, so a swipe, a fling in inspect mode and the editor's
    // segmented control all settle with the identical motion.
    static let flipAnimation: Animation = .spring(response: 0.78, dampingFraction: 0.86)
}

// CLAUDE  Date 09/05/2026
// A two-sided card that turns like a physical one. The rotation is a CONTINUOUS angle
// (not a bool), so in interactive mode the card follows the finger, overshoots with
// resistance past one turn, and settles on release using the fling's projected end
// point. Mid-turn the card pulls back from the camera and a light band sweeps across
// its face; the far face is swapped exactly at 90° by the Animatable core below.
// Side effects: haptic ticks when the face changes; the hidden face is made
// non-hit-testable (an .opacity(0) view still eats taps); Reduce Motion swaps the whole
// thing for a cross-dissolve.
struct CardFlipView<Front: View, Back: View>: View {
    @Binding var isFlipped: Bool
    private let interactive: Bool
    private let swipeToFlip: Bool
    private let isEnabled: Bool
    private let cornerRadius: CGFloat
    private let tilt: CGSize
    private let front: Front
    private let back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Degrees about the vertical axis. Multiples of 180 are the rest positions; it is
    // never normalised, so ten flips is 1800 and the maths below takes the remainder.
    @State private var angle: Double = 0
    @State private var dragStartAngle: Double?
    @State private var crossedDuringDrag = false
    // A little pitch from the vertical component of an interactive drag, so pushing
    // the card up or down while turning it reads as handling a real object.
    @State private var dragPitch: Double = 0

    /// - Parameters:
    ///   - interactive: the card follows the finger and settles by fling. Only for hosts
    ///     with no vertical ScrollView (a drag that tracks would fight the scroll).
    ///   - swipeToFlip: whether a horizontal swipe turns the card at all.
    ///   - tilt: an external tilt in degrees — `width` about the vertical axis, `height`
    ///     about the horizontal — from device motion in inspect mode.
    init(isFlipped: Binding<Bool>,
         interactive: Bool = false,
         swipeToFlip: Bool = true,
         isEnabled: Bool = true,
         cornerRadius: CGFloat = 28,
         tilt: CGSize = .zero,
         @ViewBuilder front: () -> Front,
         @ViewBuilder back: () -> Back) {
        _isFlipped = isFlipped
        self.interactive = interactive
        self.swipeToFlip = swipeToFlip
        self.isEnabled = isEnabled
        self.cornerRadius = cornerRadius
        self.tilt = tilt
        self.front = front()
        self.back = back()
    }

    // How far a finger travels for a half turn: ~330pt, a little under a card width, so a
    // full-width swipe always completes the flip with room to spare.
    private static var degreesPerPoint: Double { 0.55 }

    var body: some View {
        Group {
            if reduceMotion {
                crossfade
            } else {
                CardFlipFaces(angle: angle,
                              pitch: dragPitch + Double(tilt.height),
                              yaw: Double(tilt.width),
                              cornerRadius: cornerRadius,
                              front: face(front, isBack: false),
                              back: face(back, isBack: true))
            }
        }
        .contentShape(Rectangle())
        .gesture(drag, including: isEnabled && swipeToFlip ? .all : .subviews)
        .onAppear { angle = isFlipped ? 180 : 0 }
        // An external change (the editor's segmented control) turns the card the short
        // way round to the nearest rest of the requested parity.
        .onChange(of: isFlipped) { flipped in
            guard CardFlipFaces<Front, Back>.showsBack(at: angle) != flipped else { return }
            withAnimation(CardFace.flipAnimation) {
                angle = Self.restAngle(showingBack: flipped, near: angle)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: isFlipped ? "Show card front" : "Show card stats") {
            guard isEnabled else { return }
            commit(to: angle + 180, from: angle)
        }
    }

    // MARK: - Faces

    // Each face is flattened to one layer before the 3D transform so the transform
    // applies to the composite rather than per-leaf — the standard fix for shadows and
    // overlays rendering wrong under rotation3DEffect, and what keeps the per-frame cost
    // of a tilt down to moving a layer.
    private func face<Content: View>(_ content: Content, isBack: Bool) -> some View {
        content.compositingGroup()
    }

    // Reduce Motion: no 3D at all, just a dissolve with the slightest settle.
    private var crossfade: some View {
        ZStack {
            face(front, isBack: false)
                .opacity(isFlipped ? 0 : 1)
                .allowsHitTesting(!isFlipped)
                .accessibilityHidden(isFlipped)
            face(back, isBack: true)
                .opacity(isFlipped ? 1 : 0)
                .allowsHitTesting(isFlipped)
                .accessibilityHidden(!isFlipped)
        }
        .animation(.easeInOut(duration: 0.25), value: isFlipped)
    }

    // MARK: - Gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: interactive ? 6 : 24)
            .onChanged { value in
                guard interactive, !reduceMotion else { return }
                if dragStartAngle == nil {
                    dragStartAngle = angle
                    crossedDuringDrag = false
                }
                let start = dragStartAngle ?? angle
                let proposed = start + value.translation.width * Self.degreesPerPoint
                // One turn per drag, with rubber-band resistance past it.
                let clamped = min(max(proposed, start - 180), start + 180)
                let next = clamped + (proposed - clamped) * 0.18
                if CardFlipFaces<Front, Back>.showsBack(at: angle)
                    != CardFlipFaces<Front, Back>.showsBack(at: next) {
                    crossedDuringDrag = true
                    Self.tick()
                }
                angle = next
                dragPitch = min(max(-value.translation.height * 0.04, -6), 6)
            }
            .onEnded { value in
                let w = value.translation.width
                let h = value.translation.height
                if interactive && !reduceMotion {
                    let start = dragStartAngle ?? angle
                    dragStartAngle = nil
                    // CLAUDE  Date 09/05/2026
                    // Any deliberate swipe completes a full turn the way the finger went —
                    // the card follows the drag for feel, but a swipe is a flip, not a
                    // peek. Only a tiny nudge with no fling settles back where it was.
                    let projected = value.predictedEndTranslation.width
                    let target: Double
                    if abs(w) > 28 || abs(projected) > 90 {
                        let direction: Double = (abs(w) > 28 ? w : projected) > 0 ? 1 : -1
                        target = start + direction * 180
                    } else {
                        target = start
                    }
                    commit(to: target, from: start, alreadyTicked: crossedDuringDrag)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { dragPitch = 0 }
                } else {
                    // Non-interactive hosts (inside a ScrollView): nothing moves until the
                    // finger lifts and the gesture is clearly horizontal. The turn goes
                    // the way the finger went.
                    guard abs(w) > 60, abs(w) > abs(h) else { return }
                    if reduceMotion {
                        isFlipped.toggle()
                        Self.tick()
                    } else {
                        commit(to: angle + (w > 0 ? 180 : -180), from: angle)
                    }
                }
            }
    }

    // Settle on `target` and publish the resulting face. The onChange above sees the
    // angle already matches and stays out of the way.
    private func commit(to target: Double, from start: Double, alreadyTicked: Bool = false) {
        let willShowBack = CardFlipFaces<Front, Back>.showsBack(at: target)
        let changedFace = willShowBack != CardFlipFaces<Front, Back>.showsBack(at: start)
        withAnimation(CardFace.flipAnimation) { angle = target }
        if changedFace && !alreadyTicked { Self.tick() }
        if isFlipped != willShowBack { isFlipped = willShowBack }
    }

    // The nearest rest angle of the requested parity, stepping onward in the direction
    // the card was last travelling when the nearest one has the wrong face.
    private static func restAngle(showingBack: Bool, near angle: Double) -> Double {
        let k = Int((angle / 180).rounded())
        if (k & 1 == 1) == showingBack { return Double(k) * 180 }
        let step = angle >= Double(k) * 180 ? 1 : -1
        return Double(k + step) * 180
    }

    private static func tick() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        #endif
    }
}

// CLAUDE  Date 09/05/2026
// The Animatable core: SwiftUI feeds it the INTERPOLATED angle every frame, so the face
// swap happens at the true 90° of a spring rather than on a timer, and the depth dip and
// light sweep are exact functions of where the card is. The back carries its own 180°
// so that, composed with the container's turn, it reads upright instead of mirrored.
struct CardFlipFaces<Front: View, Back: View>: View, Animatable {
    var angle: Double
    var pitch: Double
    var yaw: Double
    let cornerRadius: CGFloat
    let front: Front
    let back: Back

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { .init(angle, .init(pitch, yaw)) }
        set { angle = newValue.first; pitch = newValue.second.first; yaw = newValue.second.second }
    }

    static func showsBack(at angle: Double) -> Bool {
        let n = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return n > 90 && n < 270
    }

    private var showsBack: Bool { Self.showsBack(at: angle) }

    // CLAUDE  Date 09/18/2026
    // The budget in force for whichever face the card is showing. Both faces are always
    // built — the turn needs them — so the one pointing away would otherwise keep a full
    // animated background running behind an .opacity(0): opacity hides a Canvas, it does
    // not stop its clock. Freezing it halves the cost of a card with an animated style.
    // It thaws at the 90° swap, while the card is edge-on and neither face is legible.
    // (cardMotionActive(true) is a no-op, so a caller's own budget still wins.)

    var body: some View {
        let radians = angle * .pi / 180
        let edgeOn = abs(sin(radians))          // 0 face-on, 1 edge-on
        // CLAUDE  Date 09/05/2026
        // The physical cues, all functions of edgeOn: the card LIFTS toward you and rises
        // on a small arc as it turns (a card flipped in the hand comes closer, it doesn't
        // shrink away), and its face darkens as it turns away from the light. Together
        // with a strong perspective these are what make it read as a solid object.
        let lift = 1 + 0.05 * edgeOn
        let rise = -14 * edgeOn
        let shade = 0.42 * edgeOn

        ZStack {
            front
                .cardMotionActive(!showsBack)
                .opacity(showsBack ? 0 : 1)
                .allowsHitTesting(!showsBack)
                .accessibilityHidden(showsBack)
            back
                .cardMotionActive(showsBack)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1 : 0)
                .allowsHitTesting(showsBack)
                .accessibilityHidden(!showsBack)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(shade))
                .allowsHitTesting(false)
        )
        .overlay(sheen(edgeOn: edgeOn))
        .scaleEffect(lift)
        .offset(y: rise)
        // Pitch (about the horizontal axis) goes inside, without perspective; the turn
        // itself carries the perspective. 0.8 is strong enough that the near edge
        // visibly grows and the far edge shrinks — the shape change that sells a turn.
        .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0)
        .rotation3DEffect(.degrees(angle + yaw), axis: (x: 0, y: 1, z: 0),
                          anchor: .center, perspective: 0.8)
    }

    // CLAUDE  Date 09/05/2026
    // One gradient, no blur: a soft white band that sweeps across the face once per
    // half-turn, and at rest sits wherever the device tilt "reflects" it. Invisible
    // when the card is still and level, so an idle card looks exactly as it always has.
    private func sheen(edgeOn: Double) -> some View {
        let phase = (angle / 180).truncatingRemainder(dividingBy: 1)
        let sweep = 0.5 + ((phase < 0 ? phase + 1 : phase) - 0.5) * 1.8
        let tiltX = 0.5 + yaw / 14
        let tiltY = 0.5 + pitch / 14
        let x = edgeOn * sweep + (1 - edgeOn) * tiltX
        let y = edgeOn * 0.5 + (1 - edgeOn) * tiltY
        let fromTilt = min(1, (abs(pitch) + abs(yaw)) / 10)
        let strength = max(edgeOn, fromTilt)

        return LinearGradient(
            stops: [.init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.16), location: 0.5),
                    .init(color: .clear, location: 1)],
            startPoint: UnitPoint(x: x - 0.35, y: y - 0.35),
            endPoint: UnitPoint(x: x + 0.35, y: y + 0.35))
            .blendMode(.plusLighter)
            .opacity(strength)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
    }
}
