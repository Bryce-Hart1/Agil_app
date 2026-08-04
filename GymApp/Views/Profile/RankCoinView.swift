import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 08/02/2026
// The profile picture as a two-sided COIN. The rank ring is the coin's edge and stays put;
// only what sits in its centre changes:
//
//   HEADS (default) — the Strategist chess piece, i.e. your rank
//   TAILS           — your character
//
// Just the circle turns. The card behind it doesn't move, and nothing else on the card is
// interactive, so the tap target is exactly the coin.
//
// Deliberately an EASTER EGG: no chip, arrow or badge hints that it turns over, and the side
// isn't persisted — leave the Profile tab and it's back to heads. That's the character of
// the interaction, so resist adding an affordance later.
//
// Only the read-only card on the Profile tab uses this. The edit-mode card makes the avatar
// a tap-to-edit target, and a friend's card has no character to show most of the time —
// both keep the plain ring.
struct RankCoinView: View {
    let rank: StrategistRank
    var progress: Double = 1
    var size: CGFloat = 120
    var fillMode: RankRingFill = .rankSegments
    // The face for tails, as ProfileFaceView's inputs.
    var character: UserCharacter? = nil
    var avatarID: String? = nil
    var name: String = ""

    @State private var angle: Double = 0
    @State private var showBack = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The ring's central slot — both faces fill exactly this, so neither shifts the layout.
    private var core: CGFloat { RingGeometry.coreDiameter(for: size) }

    var body: some View {
        ZStack {
            ZStack {
                heads.opacity(showBack ? 0 : 1)
                tails.opacity(showBack ? 1 : 0)
                    // Un-mirror the reverse face: without this, tails renders backwards
                    // once the parent has rotated the whole coin 180°.
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            // perspective 0.4 rather than the default 1 — full perspective on a disc this
            // size reads as a lunge rather than a turn.
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .allowsHitTesting(false)

            // Claude  Date 08/02/2026
            // ⚠️ The tap target is a separate, UNTRANSFORMED layer on top, and that is not
            // tidiness — it's the fix. Hit testing through rotation3DEffect means SwiftUI
            // has to invert a perspective projection, which it does not do reliably; a
            // .contentShape + .onTapGesture attached to the rotated view swallows taps and
            // the coin simply never flips. Keeping the catcher outside the transform means
            // the hit region is a plain circle in plain 2D, always. The faces above opt out
            // of hit testing entirely so they can't intercept.
            Color.clear
                .contentShape(Circle())
                .onTapGesture { flip() }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(showBack ? "Your character" : "Strategist rank, \(rank.title)")
        .accessibilityHint("Double tap to turn the coin over")
    }

    private var heads: some View {
        RankRing(rank: rank, progress: progress, size: size, fillMode: fillMode) {
            ZStack {
                // Same backing disc the character sits on, so the two faces read as one
                // object rather than as two unrelated pictures.
                Circle().fill(Color.white.opacity(0.15))
                StrategistGlyph(rank: rank, size: core * 0.62)
            }
            .frame(width: core, height: core)
            .clipShape(Circle())
        }
    }

    private var tails: some View {
        RankRing(rank: rank, progress: progress, size: size, fillMode: fillMode) {
            ProfileFaceView(character: character, avatarID: avatarID, name: name, size: core)
        }
    }

    // Claude  Date 08/02/2026
    // Three details that separate a flip that looks right from one that looks cheap:
    //  • `showBack` is its own @State, not derived from `angle < 90`. Deriving it lets
    //    SwiftUI ANIMATE the opacity, so both faces ghost through each other around 90°. A
    //    near-instant animation delayed to the midpoint gives a true hard swap.
    //  • `angle += 180`, never `angle = flipped ? 180 : 0` — accumulating keeps repeated
    //    taps spinning the same way instead of rubber-banding back and forth.
    //  • Reduce Motion gets the state change with no rotation at all.
    private func flip() {
        tapHaptic()
        let next = !showBack
        guard !reduceMotion else {
            angle += 180
            showBack = next
            return
        }
        withAnimation(.easeInOut(duration: 0.45)) { angle += 180 }
        withAnimation(.linear(duration: 0.01).delay(0.22)) { showBack = next }
    }

    // iOS 16 target, so no .sensoryFeedback (17+).
    private func tapHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// Claude  Date 08/02/2026
// Just the rank's chess piece, with no ring of its own — StrategistEmblem always brings its
// own outline, which would sit inside the RankRing and read as two concentric rings. Same
// asset-or-SF-Symbol fallback as StrategistEmblem/BadgeView/CharacterView.
struct StrategistGlyph: View {
    let rank: StrategistRank
    var size: CGFloat = 60
    var unlocked: Bool = true

    var body: some View {
        glyph
            .foregroundStyle(unlocked ? AnyShapeStyle(rank.tier.fillGradient)
                                      : AnyShapeStyle(Color.gray.opacity(0.5)))
            .shadow(color: unlocked ? .black.opacity(0.18) : .clear,
                    radius: size * 0.03, y: 0.5)
    }

    @ViewBuilder private var glyph: some View {
        #if canImport(UIKit)
        if UIImage(named: rank.iconName) != nil {
            Image(rank.iconName)
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: rank.fallbackSymbol)
                .font(.system(size: size, weight: .semibold))
        }
        #else
        Image(systemName: rank.fallbackSymbol)
            .font(.system(size: size, weight: .semibold))
        #endif
    }
}

// Claude  Date 08/02/2026
// A preview can't be tapped, so both faces are pinned open beside the live coin.
#Preview("Rank coin") {
    VStack(spacing: 28) {
        ForEach([CGFloat(120), CGFloat(92)], id: \.self) { size in
            HStack(spacing: 24) {
                RankRing(rank: .gladiator, progress: 0.45, size: size, fillMode: .rankProgress) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.15))
                        StrategistGlyph(rank: .gladiator,
                                        size: RingGeometry.coreDiameter(for: size) * 0.62)
                    }
                }
                RankRing(rank: .gladiator, progress: 0.45, size: size, fillMode: .rankProgress) {
                    ProfileFaceView(character: .default, name: "Bryce Hart",
                                    size: RingGeometry.coreDiameter(for: size))
                }
                RankCoinView(rank: .gladiator, progress: 0.45, size: size,
                             fillMode: .rankProgress, character: .default,
                             avatarID: "classic", name: "Bryce Hart")
            }
        }
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: "#D4137F"))
}
