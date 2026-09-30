import SwiftUI

// CLAUDE  Date 09/26/2026
// The engine behind Help & Demos' interactive demos: a script of steps over a plain value
// State, so the fake screens never touch AppStore or any saved data. Back rebuilds a step
// by replaying the steps before it; forward and real taps apply to the live state.

/// One stop in a demo: what the guide panel says, what's highlighted, and what finishes it.
struct DemoStep<Action, Target> {
    let text: String
    /// The control the step points at. nil = nothing highlighted.
    var target: Target? = nil
    /// The tap that completes the step. nil = explain-only, so forward just moves on.
    var action: Action? = nil
    /// Applied when an explain-only step is passed, e.g. filling in sample numbers.
    var effect: Action? = nil
}

// CLAUDE  Date 09/26/2026
// What a demo supplies: its starting state, its steps, and how an action changes the
// state. `apply` must be pure, since back replays it from the start.
protocol DemoScript {
    associatedtype State
    associatedtype Action
    associatedtype Target: Hashable

    var initialState: State { get }
    var steps: [DemoStep<Action, Target>] { get }
    func apply(_ action: Action, to state: inout State)
    /// Whether a tap counts as the step's action. Lets a step accept any pick from a list.
    func matches(_ attempted: Action, expected: Action) -> Bool
}

extension DemoScript where Action: Equatable {
    func matches(_ attempted: Action, expected: Action) -> Bool { attempted == expected }
}

extension DemoScript {
    /// The state at the start of step `index`: every earlier step's change, replayed.
    func state(at index: Int) -> State {
        var state = initialState
        for step in steps.prefix(index) {
            if let change = step.action ?? step.effect { apply(change, to: &state) }
        }
        return state
    }
}

// CLAUDE  Date 09/26/2026
// Drives one running demo. Wrong taps only bump `nudges`, which shakes the highlight; the
// state never moves off the script. Side effect: light haptics on every step change.
@MainActor
final class DemoRunner<Script: DemoScript>: ObservableObject {
    let script: Script
    @Published private(set) var index = 0
    @Published var state: Script.State
    @Published private(set) var nudges = 0

    init(script: Script) {
        self.script = script
        self.state = script.initialState
    }

    var step: DemoStep<Script.Action, Script.Target> { script.steps[index] }
    var stepCount: Int { script.steps.count }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index == script.steps.count - 1 }

    func isTarget(_ target: Script.Target) -> Bool { step.target == target }

    /// A tap on the fake screen. The step's own action advances; anything else nudges.
    func attempt(_ action: Script.Action) {
        guard let expected = step.action, script.matches(action, expected: expected) else {
            nudge()
            return
        }
        advance(applying: action)
    }

    /// A tap on a control an explain-only step is pointing at reads as "got it".
    func acknowledge(_ target: Script.Target) {
        if step.action == nil && isTarget(target) && !isLast { forward() } else { nudge() }
    }

    func forward() {
        guard !isLast else { return }
        advance(applying: step.action ?? step.effect)
    }

    func back() {
        guard !isFirst else { return }
        Haptics.tap()
        withAnimation(Self.move) {
            index -= 1
            state = script.state(at: index)
        }
    }

    func nudge() {
        Haptics.soften()
        nudges += 1
    }

    private func advance(applying change: Script.Action?) {
        Haptics.tap()
        withAnimation(Self.move) {
            if let change { script.apply(change, to: &state) }
            index += 1
        }
    }

    private static var move: Animation { .spring(response: 0.4, dampingFraction: 0.85) }
}

// CLAUDE  Date 09/26/2026
// The "tap here" ring around a demo's current target: a softly pulsing accent outline
// that shakes on a wrong tap. Decoration only, never hit-testable. One is live at a time,
// so its 30fps timeline is cheap.
private struct DemoHighlight: ViewModifier {
    let active: Bool
    let nudges: Int
    let cornerRadius: CGFloat
    let inset: CGFloat

    @EnvironmentObject private var theme: ThemeManager
    @State private var shake: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    ring
                        .padding(inset)
                        .modifier(ShakeEffect(travel: shake))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onChange(of: nudges) { _ in
                guard active else { return }
                withAnimation(.linear(duration: 0.4)) { shake += 1 }
            }
    }

    private var ring: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack {
                shape.stroke(theme.current.accent.opacity(0.45), lineWidth: 6).blur(radius: 4)
                shape.stroke(theme.current.accent, lineWidth: 2)
            }
            .opacity(0.55 + 0.45 * (sin(time * 3.2) + 1) / 2)
        }
    }
}

// Whole-number `travel` values sit at rest, so each nudge (+1) plays one full shake.
private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(travel * .pi * 6), y: 0))
    }
}

extension View {
    // CLAUDE  Date 09/27/2026
    // Shows a real input control (a text field, or a view holding one) without letting it
    // take focus, so a demo never raises the keyboard. A tap on it calls `onTap` instead.
    func demoInert(onTap: @escaping () -> Void) -> some View {
        allowsHitTesting(false)
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
            }
    }

    // CLAUDE  Date 09/26/2026
    // Rings this view while `active`. `inset` is how far the ring sits outside the view.
    func demoHighlight(_ active: Bool, nudges: Int,
                       cornerRadius: CGFloat = 10, inset: CGFloat = -6) -> some View {
        modifier(DemoHighlight(active: active, nudges: nudges,
                               cornerRadius: cornerRadius, inset: inset))
    }
}
