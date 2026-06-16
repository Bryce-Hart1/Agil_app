import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 06/13/2026
// The "achievement unlocked" moment — meant to feel earned. Layers, back to front:
// a dimmed backdrop, a slowly rotating ray burst, expanding pulse rings, a confetti
// burst, and the badge popping in with a spring + shine, plus the coins awarded.
// Tap anywhere to dismiss (advances to the next queued unlock).
struct CelebrationOverlay: View {
    let achievement: Achievement
    let remaining: Int            // how many more are queued behind this one
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var spin = false
    @State private var ring = false

    private var tier: BadgeTier { achievement.tier }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Achievement Unlocked")
                    .font(.subheadline.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.9))
                    .textCase(.uppercase)

                badge

                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    Text("\(tier.title) · \(achievement.category.title)")
                        .font(.headline)
                        .foregroundStyle(tier.color)
                }

                Label("+\(achievement.reward)", systemImage: "circle.hexagongrid.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(.white.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))

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

    // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
    // The badge with its ray burst, confetti, and expanding pulse rings — all in the
    // badge's own ZStack so the whole glow radiates FROM the badge (which sits above
    // screen center), rather than from the middle of the screen.
    private var badge: some View {
        ZStack {
            rays
            ConfettiView(colors: [tier.color, .white, .yellow, tier.color.opacity(0.7)])
                .allowsHitTesting(false)

            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(tier.color.opacity(0.5), lineWidth: 3)
                    .frame(width: 150, height: 150)
                    .scaleEffect(ring ? 1.6 : 0.7)
                    .opacity(ring ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.8).repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.9),
                        value: ring
                    )
            }

            BadgeView(icon: achievement.icon, tier: tier, unlocked: true, size: 128, glimmer: true)
                .scaleEffect(appear ? 1 : 0.2)
                .rotationEffect(.degrees(appear ? 0 : -30))
        }
        .frame(height: 170)
    }

    // A slowly rotating starburst of tier-colored rays behind everything.
    private var rays: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(colors: [tier.color.opacity(0.35), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 6, height: 280)
                    .offset(y: -150)
                    .rotationEffect(.degrees(Double(i) / 14 * 360))
            }
        }
        .rotationEffect(.degrees(spin ? 360 : 0))
        .scaleEffect(appear ? 1 : 0.4)
        .opacity(appear ? 1 : 0)
        .blur(radius: 0.5)
        .allowsHitTesting(false)
    }

    private func start() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { appear = true }
        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) { spin = true }
        ring = true
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

// MARK: - Confetti

// Claude  Date 06/13/2026
// A one-shot confetti burst: each piece flies outward from center, tumbles, drifts
// down under "gravity", and fades. Pieces are randomized once at init.
struct ConfettiView: View {
    let colors: [Color]
    var count: Int = 70

    private let pieces: [ConfettiPiece]

    init(colors: [Color], count: Int = 70) {
        self.colors = colors
        self.count = count
        self.pieces = (0..<count).map { _ in ConfettiPiece.random(colors: colors) }
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { ConfettiPieceView(piece: $0) }
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let angle: Double        // launch direction (radians)
    let distance: CGFloat    // outward travel
    let fall: CGFloat        // extra downward drift (gravity)
    let size: CGFloat
    let spin: Double
    let color: Color
    let duration: Double
    let delay: Double

    static func random(colors: [Color]) -> ConfettiPiece {
        ConfettiPiece(
            angle: Double.random(in: 0...(2 * .pi)),
            distance: CGFloat.random(in: 130...320),
            fall: CGFloat.random(in: 120...340),
            size: CGFloat.random(in: 6...12),
            spin: Double.random(in: -540...540),
            color: colors.randomElement() ?? .white,
            duration: Double.random(in: 1.0...1.7),
            delay: Double.random(in: 0...0.12)
        )
    }
}

private struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var go = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 0.55)
            .rotationEffect(.degrees(go ? piece.spin : 0))
            .offset(
                x: go ? cos(piece.angle) * piece.distance : 0,
                y: go ? sin(piece.angle) * piece.distance + piece.fall : 0
            )
            .opacity(go ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: piece.duration).delay(piece.delay)) {
                    go = true
                }
            }
    }
}

#Preview {
    CelebrationOverlay(
        achievement: Achievement.all.first { $0.tier == .legend }!,
        remaining: 2,
        onDismiss: {}
    )
}
