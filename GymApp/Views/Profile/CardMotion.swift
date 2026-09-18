import SwiftUI

// CLAUDE  Date 09/17/2026
// How much motion an animated card background is allowed to spend. Callers set it on a
// subtree (.cardMotionDetail) and every AnimatedCardBackground below reads it: the hero
// card stays .full, small previews drop frame rate and particle count, and .still draws
// one frozen frame with no TimelineView at all, so nothing ticks.
// Side effect: this is inherited, so setting it on a screen budgets every card on it.
enum CardMotionDetail {
    /// The real card, at real size — everything moves.
    case full
    /// A tile or swatch: still alive, at a fraction of the cost.
    case preview
    /// One frozen frame. No clock, no redraws.
    case still

    /// Frame rate for a layer whose content barely moves — base fills, big blurred
    /// clouds and auras. These drift so slowly that display rate is pure waste.
    var slowFPS: Double { self == .full ? 12 : 6 }

    /// Frame rate for content that moves at a visible but unhurried pace — rising
    /// bubbles, tumbling petals, a rippling lava bed. 30 is film rate; above it nothing
    /// here gains anything.
    var steadyFPS: Double { self == .full ? 30 : 15 }

    /// Frame rate for the layer carrying the fast action — meteors, rain, lightning.
    var fastFPS: Double { self == .full ? 60 : 20 }

    /// Fraction of each seeded particle field to draw. Thinning the star/rain/ember
    /// arrays is invisible at tile size and is most of the per-frame cost there.
    var density: Double { self == .full ? 1.0 : 0.45 }

    // CLAUDE  Date 09/18/2026
    // The same budget, scaled by how big the card is actually being drawn. A field
    // seeded for a full-size card is pure waste in a 28pt swatch: the count follows the
    // square root of the area ratio (linear in the card's edge, which is what the eye
    // reads as "how crowded"), floored at 0.3 so a small preview still looks populated.
    func density(at size: CGSize) -> Double {
        let reference = CGSize(width: 350, height: 500)
        let area = max(size.width * size.height, 1)
        let scale = (area / (reference.width * reference.height)).squareRoot()
        return density * Swift.min(1, Swift.max(0.3, scale))
    }

    var isAnimating: Bool { self != .still }
}

private struct CardMotionDetailKey: EnvironmentKey {
    static let defaultValue: CardMotionDetail = .full
}

extension EnvironmentValues {
    var cardMotionDetail: CardMotionDetail {
        get { self[CardMotionDetailKey.self] }
        set { self[CardMotionDetailKey.self] = newValue }
    }
}

extension View {
    // CLAUDE  Date 09/17/2026
    // Budget the animated card backgrounds in this subtree. Set it on the artwork rather
    // than a whole screen — it is inherited by every card below it.
    func cardMotionDetail(_ detail: CardMotionDetail) -> some View {
        environment(\.cardMotionDetail, detail)
    }
}


// CLAUDE  Date 09/18/2026
// Low Power Mode, as something a View can watch. iOS asks apps to ease off animation
// here, and a card full of Canvas particles is exactly what it means — .full drops to
// the preview budget for as long as the setting is on. One shared instance: the flag is
// global and changes rarely, so every card can observe the same object.
final class PowerMonitor: ObservableObject {
    static let shared = PowerMonitor()

    @Published private(set) var lowPower: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private init() {
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            let now = ProcessInfo.processInfo.isLowPowerModeEnabled
            guard let self, self.lowPower != now else { return }
            self.lowPower = now
        }
    }
}

// CLAUDE  Date 09/18/2026
// Freeze the cards in this subtree while they aren't worth drawing — the tab they live
// on isn't the visible one, a sheet has covered them, and so on. Passing `true` leaves
// whatever budget is already in force alone rather than promoting them to .full.
private struct CardMotionActive: ViewModifier {
    let active: Bool
    @Environment(\.cardMotionDetail) private var detail

    func body(content: Content) -> some View {
        content.cardMotionDetail(active ? detail : .still)
    }
}

extension View {
    func cardMotionActive(_ active: Bool) -> some View {
        modifier(CardMotionActive(active: active))
    }
}
