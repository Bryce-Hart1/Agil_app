import SwiftUI

// Claude  Date 06/16/2026
// The animated profile-card backgrounds — the premium, coin-only card looks.
// Each kind is drawn entirely in code (Canvas + TimelineView), so there are no
// PNG assets to ship and the motion stays crisp at any card size. This file is
// the single place that knows how an animated background is painted; everything
// else (CardBackgroundView, the Edit/Shop swatches) just hands it an
// `AnimatedCard` and lets it render.
//
// To add another animated card: add a case to AnimatedCard (in CardStyle.swift),
// give it an `accent`, add a `case` here, and register a CardStyle for it.

// Claude  Date 06/16/2026
// Renders the live animation for a given AnimatedCard. A built-in dark scrim
// (matching the image-card treatment) keeps the card's white text legible over
// the moving art.
struct AnimatedCardBackground: View {
    let kind: AnimatedCard

    var body: some View {
        ZStack {
            switch kind {
            case .shootingStars: ShootingStarsBackground()
            case .galaxy:        GalaxyBackground()
            case .molten:        MoltenBackground()
            case .cherryBlossom: CherryBlossomBackground()
            }
        }
        .overlay(
            LinearGradient(colors: [.black.opacity(0.10), .black.opacity(0.40)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - Shooting Stars

// Claude  Date 06/16/2026 last changed: 06/16/2026 by: Claude
// "Shooting Stars": deep-space card. Big blurred colour clouds drift on slow sine
// paths over an indigo void, a field of stars twinkles, and a flurry of shooting
// stars streak across — each on its own staggered loop, angle, and speed so the
// sky is busy. Cloud blur is done in a drawLayer so the stars on top stay sharp.
private struct ShootingStarsBackground: View {
    // Stable, seeded star field so stars don't jump every redraw.
    private let stars: [Star] = {
        var rng = SeededGenerator(seed: 7)
        return (0..<70).map { _ in
            Star(x: .random(in: 0...1, using: &rng),
                 y: .random(in: 0...1, using: &rng),
                 radius: .random(in: 0.4...1.6, using: &rng),
                 phase: .random(in: 0...(2 * .pi), using: &rng),
                 speed: .random(in: 0.6...2.2, using: &rng))
        }
    }()

    // The drifting colour clouds: base position (unit), colour, size, drift.
    private let clouds: [Cloud] = [
        Cloud(x: 0.25, y: 0.30, color: Color(red: 0.55, green: 0.20, blue: 0.85), size: 0.95, phase: 0.0,        speed: 0.18),
        Cloud(x: 0.78, y: 0.35, color: Color(red: 0.16, green: 0.42, blue: 0.92), size: 0.85, phase: 1.7,        speed: 0.14),
        Cloud(x: 0.55, y: 0.72, color: Color(red: 0.92, green: 0.22, blue: 0.62), size: 0.80, phase: 3.1,        speed: 0.20),
        Cloud(x: 0.18, y: 0.78, color: Color(red: 0.10, green: 0.70, blue: 0.72), size: 0.70, phase: 4.4,        speed: 0.16),
    ]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let rect = CGRect(origin: .zero, size: size)

                // Deep-space base.
                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.05, green: 0.03, blue: 0.16),
                                      Color(red: 0.02, green: 0.01, blue: 0.06)]),
                    startPoint: .zero, endPoint: CGPoint(x: w, y: h)))

                // Drifting nebula clouds (blurred as one layer).
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: min(w, h) * 0.16))
                    for c in clouds {
                        let dx = CGFloat(sin(t * c.speed + c.phase)) * w * 0.08
                        let dy = CGFloat(cos(t * c.speed * 0.8 + c.phase)) * h * 0.06
                        let d = min(w, h) * c.size
                        let r = CGRect(x: c.x * w - d / 2 + dx,
                                       y: c.y * h - d / 2 + dy,
                                       width: d, height: d)
                        layer.fill(Path(ellipseIn: r), with: .color(c.color.opacity(0.55)))
                    }
                }

                // Twinkling stars.
                for s in stars {
                    let tw = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
                    let r = s.radius
                    let rect = CGRect(x: s.x * w - r, y: s.y * h - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(tw)))
                }

                // A flurry of shooting stars: each streaks during the "active"
                // slice of its own loop, then waits — staggered so several can be
                // mid-flight at once without ever marching in lockstep.
                for m in meteors {
                    let local = ((t + m.offset) / m.period).truncatingRemainder(dividingBy: 1) // 0…1
                    guard local < m.activeFraction else { continue }
                    let p: CGFloat = CGFloat(local / m.activeFraction)   // 0…1 across the streak
                    let travel: CGFloat = (w + h) * 0.6                  // diagonal distance covered
                    let dx: CGFloat = CGFloat(cos(m.angle))
                    let dy: CGFloat = CGFloat(sin(m.angle))
                    let headX: CGFloat = w * CGFloat(m.startX) + dx * travel * p
                    let headY: CGFloat = h * CGFloat(m.startY) + dy * travel * p
                    let head = CGPoint(x: headX, y: headY)
                    let len: CGFloat = CGFloat(m.length)
                    let tail = CGPoint(x: headX - dx * len, y: headY - dy * len)
                    let fade: CGFloat = CGFloat(sin(Double(p) * .pi))    // fade in then out
                    var trail = Path()
                    trail.move(to: head)
                    trail.addLine(to: tail)
                    ctx.stroke(trail, with: .linearGradient(
                        Gradient(colors: [.white.opacity(0.95 * fade), .clear]),
                        startPoint: head, endPoint: tail),
                        style: StrokeStyle(lineWidth: CGFloat(m.width), lineCap: .round))
                    // Bright head spark.
                    let hr: CGFloat = CGFloat(m.width) * 0.9
                    ctx.fill(Path(ellipseIn: CGRect(x: headX - hr, y: headY - hr, width: hr * 2, height: hr * 2)),
                             with: .color(.white.opacity(fade)))
                }
            }
        }
        .drawingGroup()   // composite the canvas on the GPU
    }

    // Seeded flurry of shooting stars, each with its own loop/angle/speed.
    private let meteors: [Meteor] = {
        var rng = SeededGenerator(seed: 41)
        return (0..<9).map { _ in
            Meteor(startX: .random(in: -0.1...0.7, using: &rng),
                   startY: .random(in: 0.0...0.5, using: &rng),
                   angle: .random(in: 0.32...0.62, using: &rng),   // radians, down-right
                   length: .random(in: 60...130, using: &rng),
                   width: .random(in: 1.3...2.4, using: &rng),
                   period: .random(in: 3.0...6.5, using: &rng),
                   offset: .random(in: 0...6.5, using: &rng),
                   activeFraction: .random(in: 0.16...0.26, using: &rng))
        }
    }()

    private struct Star { let x, y, radius, phase, speed: Double }
    private struct Cloud { let x, y: Double; let color: Color; let size, phase, speed: Double }
    private struct Meteor { let startX, startY, angle, length, width, period, offset, activeFraction: Double }
}

// MARK: - Galaxy

// Claude  Date 06/16/2026
// "Galaxy": a slowly rotating spiral galaxy. Two logarithmic-spiral arms of stars
// wind out from a glowing core and turn as one; a soft core glow pulses and a
// sparse field of background stars twinkles behind. The whole disc rotates, so
// it reads as a living galaxy rather than a static starfield.
private struct GalaxyBackground: View {
    // Stars laid along the spiral arms (seeded once). `arm` offsets the angle so
    // we get two opposing arms; `t01` is the position along the arm (0 core → 1 rim).
    private let armStars: [ArmStar] = {
        var rng = SeededGenerator(seed: 73)
        return (0..<220).map { _ in
            let t01 = pow(Double.random(in: 0...1, using: &rng), 0.7)   // bias outward
            return ArmStar(t01: t01,
                           arm: Bool.random(using: &rng) ? 0 : Double.pi,
                           jitter: .random(in: -0.18...0.18, using: &rng),
                           radius: .random(in: 0.5...1.7, using: &rng),
                           phase: .random(in: 0...(2 * .pi), using: &rng),
                           twinkle: .random(in: 0.8...2.4, using: &rng))
        }
    }()

    // Dense cluster packed into the galactic core, so the middle reads as a
    // bright bulge of stars rather than empty glow. Radius biased toward 0.
    private let coreStars: [CoreStar] = {
        var rng = SeededGenerator(seed: 57)
        return (0..<140).map { _ in
            CoreStar(r01: pow(Double.random(in: 0...1, using: &rng), 1.8),  // bias inward
                     angle: .random(in: 0...(2 * .pi), using: &rng),
                     radius: .random(in: 0.4...1.5, using: &rng),
                     phase: .random(in: 0...(2 * .pi), using: &rng),
                     twinkle: .random(in: 0.9...2.6, using: &rng))
        }
    }()

    // Sparse background field behind the disc.
    private let bgStars: [BgStar] = {
        var rng = SeededGenerator(seed: 91)
        return (0..<60).map { _ in
            BgStar(x: .random(in: 0...1, using: &rng),
                   y: .random(in: 0...1, using: &rng),
                   radius: .random(in: 0.4...1.2, using: &rng),
                   phase: .random(in: 0...(2 * .pi), using: &rng),
                   speed: .random(in: 0.6...2.0, using: &rng))
        }
    }()

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: w * 0.5, y: h * 0.46)
                let maxR = min(w, h) * 0.52
                let spin = t * 0.06                          // slow disc rotation
                let twist = 3.4                              // how tightly the arms wind

                // Deep-space base, faintly blue-violet toward the core.
                ctx.fill(Path(rect), with: .radialGradient(
                    Gradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.26),
                                      Color(red: 0.02, green: 0.02, blue: 0.07)]),
                    center: center, startRadius: 0, endRadius: maxR * 1.6))

                // Background twinkle field.
                for s in bgStars {
                    let tw = 0.25 + 0.45 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
                    let r = s.radius
                    ctx.fill(Path(ellipseIn: CGRect(x: s.x * w - r, y: s.y * h - r, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(tw)))
                }

                // Pulsing core glow.
                let pulse = 0.5 + 0.5 * sin(t * 0.8)
                let coreR = maxR * (0.42 + 0.05 * pulse)
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: coreR * 0.5))
                    layer.fill(
                        Path(ellipseIn: CGRect(x: center.x - coreR, y: center.y - coreR,
                                               width: coreR * 2, height: coreR * 2)),
                        with: .radialGradient(
                            Gradient(colors: [Color(red: 0.85, green: 0.80, blue: 1.0).opacity(0.95),
                                              Color(red: 0.45, green: 0.55, blue: 0.95).opacity(0.35),
                                              .clear]),
                            center: center, startRadius: 0, endRadius: coreR))
                }

                // Dense core cluster (rotates with the disc, squashed for tilt).
                for s in coreStars {
                    let r = s.r01 * maxR * 0.45
                    let angle = s.angle + spin
                    let x = center.x + cos(angle) * r
                    let y = center.y + sin(angle) * r * 0.62
                    let tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * s.twinkle + s.phase))
                    let rad = s.radius
                    ctx.fill(Path(ellipseIn: CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)),
                             with: .color(Color(red: 0.95, green: 0.92, blue: 1.0).opacity(tw)))
                }

                // Spiral-arm stars (slightly squashed to fake a disc tilt).
                for s in armStars {
                    let r = s.t01 * maxR
                    let angle = s.arm + spin + s.t01 * twist + s.jitter
                    let x = center.x + cos(angle) * r
                    let y = center.y + sin(angle) * r * 0.62     // vertical squash = tilt
                    let tw = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * s.twinkle + s.phase))
                    // Bluer at the rim, warm-white near the core.
                    let warmth = 1.0 - s.t01
                    let color = Color(red: 0.70 + 0.25 * warmth,
                                      green: 0.75 + 0.10 * warmth,
                                      blue: 1.0)
                    let rad = s.radius * (1.0 - 0.3 * s.t01)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)),
                             with: .color(color.opacity(tw)))
                }
            }
        }
        .drawingGroup()
    }

    private struct ArmStar { let t01, arm, jitter, radius, phase, twinkle: Double }
    private struct CoreStar { let r01, angle, radius, phase, twinkle: Double }
    private struct BgStar { let x, y, radius, phase, speed: Double }
}

// MARK: - Molten

// Claude  Date 06/16/2026 last changed: 06/16/2026 by: Claude
// "Molten Core": a forge card. A pulsing magma glow breathes at the base over a
// thick bed of lava that ripples along the bottom edge, while a dense swarm of
// embers rise, sway, and burn out near the top — pure particle motion over a
// near-black-to-crimson gradient.
private struct MoltenBackground: View {
    private let embers: [Ember] = {
        var rng = SeededGenerator(seed: 19)
        return (0..<48).map { _ in
            Ember(x: .random(in: 0.02...0.98, using: &rng),
                  size: .random(in: 1.3...4.2, using: &rng),
                  speed: .random(in: 0.08...0.30, using: &rng),
                  offset: .random(in: 0...1, using: &rng),
                  sway: .random(in: 0.02...0.07, using: &rng),
                  swayPhase: .random(in: 0...(2 * .pi), using: &rng))
        }
    }()

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let rect = CGRect(origin: .zero, size: size)

                // Dark forge base.
                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.10, green: 0.02, blue: 0.02),
                                      Color(red: 0.02, green: 0.01, blue: 0.01)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

                // Pulsing magma glow at the bottom.
                let pulse = 0.5 + 0.5 * sin(t * 0.9)
                let glowR = max(w, h) * (1.05 + 0.14 * pulse)
                let center = CGPoint(x: w * 0.5, y: h * 1.04)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: center.x - glowR, y: center.y - glowR * 0.8,
                                           width: glowR * 2, height: glowR * 1.6)),
                    with: .radialGradient(
                        Gradient(colors: [Color(red: 1.0, green: 0.50, blue: 0.12).opacity(0.65 + 0.2 * pulse),
                                          Color(red: 0.88, green: 0.14, blue: 0.04).opacity(0.32),
                                          .clear]),
                        center: center, startRadius: 0, endRadius: glowR))

                // Thick lava bed: a molten band hugging the bottom edge with a
                // rippling, glowing top surface (two offset sine waves).
                let bedTop = h * (0.74 - 0.02 * pulse)
                var bed = Path()
                bed.move(to: CGPoint(x: 0, y: h))
                bed.addLine(to: CGPoint(x: 0, y: bedTop))
                let steps = 24
                for i in 0...steps {
                    let fx = CGFloat(i) / CGFloat(steps)
                    let x = fx * w
                    let ripple = sin(Double(fx) * 7.0 + t * 1.1) * 0.5
                                 + sin(Double(fx) * 3.0 - t * 0.7) * 0.5
                    let y = bedTop + CGFloat(ripple) * h * 0.05
                    bed.addLine(to: CGPoint(x: x, y: y))
                }
                bed.addLine(to: CGPoint(x: w, y: h))
                bed.closeSubpath()
                ctx.fill(bed, with: .linearGradient(
                    Gradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.18),
                                      Color(red: 0.92, green: 0.20, blue: 0.04),
                                      Color(red: 0.45, green: 0.05, blue: 0.02)]),
                    startPoint: CGPoint(x: 0, y: bedTop), endPoint: CGPoint(x: 0, y: h)))
                // Bright molten lip riding the lava surface.
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 2))
                    var lip = Path()
                    for i in 0...steps {
                        let fx = CGFloat(i) / CGFloat(steps)
                        let x = fx * w
                        let ripple = sin(Double(fx) * 7.0 + t * 1.1) * 0.5
                                     + sin(Double(fx) * 3.0 - t * 0.7) * 0.5
                        let y = bedTop + CGFloat(ripple) * h * 0.05
                        if i == 0 { lip.move(to: CGPoint(x: x, y: y)) }
                        else { lip.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    layer.stroke(lip, with: .color(Color(red: 1.0, green: 0.85, blue: 0.45).opacity(0.85)),
                                 style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                // Rising, swaying embers (glowing dots).
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 0.6))
                    for e in embers {
                        let prog = (t * e.speed + e.offset).truncatingRemainder(dividingBy: 1) // 0 bottom → 1 top
                        let y = h * (1.0 - prog)
                        let x = w * (e.x + e.sway * sin(t * 1.3 + e.swayPhase))
                        let fade = sin(prog * .pi)        // dim at birth and death
                        let r = e.size * (1.0 - 0.3 * prog)
                        let color = Color(red: 1.0, green: 0.55 + 0.3 * fade, blue: 0.18)
                        layer.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                   with: .color(color.opacity(0.9 * fade)))
                    }
                }
            }
        }
        .drawingGroup()
    }

    private struct Ember { let x, size, speed, offset, sway, swayPhase: Double }
}

// MARK: - Cherry Blossom

// Claude  Date 06/16/2026 last changed: 06/17/2026 by: Claude
// "Cherry Blossom": a twilight orchard card, reframed as a CLOSE-UP. Rather than a
// whole little tree centred in frame, a couple of thick boughs push in from off the
// left/bottom edges and arc up across the card — so it reads like you're standing
// right beside the branch. Limbs are heavier, blossom tips are full overlapping
// puffs, and pink petals drift, sway, and tumble down the foreground over a dusk
// gradient. Everything is built in normalised [0,1] coords so it scales to any card.
private struct CherryBlossomBackground: View {
    private struct Branch { let a, b: CGPoint; let depth: Int }
    private struct Blossom { let p: CGPoint; let r, shade: Double }
    private struct Petal { let x, size, speed, offset, sway, swayPhase, spin, spinPhase, shade: Double }

    private let branches: [Branch]
    private let blossoms: [Blossom]
    private let petals: [Petal]

    init() {
        var rng = SeededGenerator(seed: 31)
        var branches: [Branch] = []
        var blossoms: [Blossom] = []
        // Claude  Date 06/17/2026
        // Close-up framing: grow one thick main bough in from the bottom-left corner
        // (origin off-frame) arcing up and to the right, plus a shorter offshoot from
        // the left edge, so only part of the tree is visible — the macro "right next
        // to the branch" look. Off-frame origins + longer lengths push the trunk past
        // the edges instead of sitting as a small complete tree in the middle.
        Self.grow(from: CGPoint(x: -0.08, y: 1.06), angle: -.pi / 3.1, length: 0.46, depth: 5,
                  branches: &branches, blossoms: &blossoms, rng: &rng)
        Self.grow(from: CGPoint(x: -0.06, y: 0.60), angle: -.pi / 9, length: 0.30, depth: 4,
                  branches: &branches, blossoms: &blossoms, rng: &rng)
        self.branches = branches
        self.blossoms = blossoms
        self.petals = (0..<46).map { _ in
            Petal(x: .random(in: 0...1, using: &rng),
                  size: .random(in: 3.5...8.0, using: &rng),
                  speed: .random(in: 0.05...0.13, using: &rng),
                  offset: .random(in: 0...1, using: &rng),
                  sway: .random(in: 0.4...1.1, using: &rng),
                  swayPhase: .random(in: 0...(2 * .pi), using: &rng),
                  spin: .random(in: -1.6...1.6, using: &rng),
                  spinPhase: .random(in: 0...(2 * .pi), using: &rng),
                  shade: .random(in: 0...1, using: &rng))
        }
    }

    // Recursively build the tree: each branch spawns 2–3 shorter, angled children
    // until depth 0, where a small cluster of blossoms is dropped at the tip.
    private static func grow(from: CGPoint, angle: Double, length: Double, depth: Int,
                             branches: inout [Branch], blossoms: inout [Blossom],
                             rng: inout SeededGenerator) {
        let end = CGPoint(x: from.x + CGFloat(cos(angle)) * CGFloat(length),
                          y: from.y + CGFloat(sin(angle)) * CGFloat(length))
        branches.append(Branch(a: from, b: end, depth: depth))
        if depth == 0 {
            // Claude  Date 06/17/2026
            // Fuller tip cluster for the close-up: more blossoms, bigger, spread over a
            // wider patch so each branch end reads as a dense puff rather than a few dots.
            let count = Int.random(in: 5...9, using: &rng)
            for _ in 0..<count {
                blossoms.append(Blossom(
                    p: CGPoint(x: end.x + CGFloat.random(in: -0.05...0.05, using: &rng),
                               y: end.y + CGFloat.random(in: -0.05...0.05, using: &rng)),
                    r: .random(in: 0.018...0.040, using: &rng),
                    shade: .random(in: 0...1, using: &rng)))
            }
            return
        }
        let children = depth >= 4 ? 2 : Int.random(in: 2...3, using: &rng)
        for _ in 0..<children {
            let spread = Double.random(in: 0.30...0.70, using: &rng)
            let newAngle = angle + .random(in: -spread...spread, using: &rng)
            let newLength = length * Double.random(in: 0.66...0.80, using: &rng)
            grow(from: end, angle: newAngle, length: newLength, depth: depth - 1,
                 branches: &branches, blossoms: &blossoms, rng: &rng)
        }
    }

    // Pinks for blossoms / petals, interpolated by a 0…1 shade.
    private func pink(_ shade: Double) -> Color {
        Color(red: 0.98 - 0.06 * shade, green: 0.62 - 0.14 * shade, blue: 0.76 - 0.08 * shade)
    }

    // Circle path centred at (cx, cy) with radius r.
    private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    // A simple pointed-oval petal centred on the origin (2*s tall, s wide).
    private func petalPath(_ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -s))
        p.addQuadCurve(to: CGPoint(x: 0, y: s), control: CGPoint(x: s * 0.8, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0, y: -s), control: CGPoint(x: -s * 0.8, y: 0))
        return p
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let rect = CGRect(origin: .zero, size: size)
                let scale = min(w, h)

                // Dusk sky.
                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.20, green: 0.13, blue: 0.30),
                                      Color(red: 0.47, green: 0.26, blue: 0.42),
                                      Color(red: 0.80, green: 0.48, blue: 0.58)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

                // Soft moon/horizon glow behind the tree.
                let glowC = CGPoint(x: w * 0.70, y: h * 0.26)
                let glowR = scale * 0.5
                ctx.fill(Path(ellipseIn: CGRect(x: glowC.x - glowR, y: glowC.y - glowR,
                                                width: glowR * 2, height: glowR * 2)),
                         with: .radialGradient(
                            Gradient(colors: [Color(red: 1.0, green: 0.92, blue: 0.85).opacity(0.45), .clear]),
                            center: glowC, startRadius: 0, endRadius: glowR))

                // Wind offset for a point, stronger higher up the tree (smaller y).
                func wind(_ p: CGPoint) -> CGFloat {
                    let height = 1.0 - Double(p.y)                       // 0 at base → ~1 at canopy
                    return CGFloat(sin(t * 0.6 + height * 3.0) * height * height * 0.018) * w
                }

                // Claude  Date 06/17/2026
                // The boughs: heavier, woody limbs (thicker line weight + warmer brown
                // than the old near-black silhouette) so the close-up reads as bark, with
                // only a touch of blur for depth.
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 0.5))
                    for br in branches {
                        var path = Path()
                        path.move(to: CGPoint(x: br.a.x * w + wind(br.a), y: br.a.y * h))
                        path.addLine(to: CGPoint(x: br.b.x * w + wind(br.b), y: br.b.y * h))
                        let lw = max(1.0, CGFloat(br.depth + 1) * scale * 0.0085)
                        layer.stroke(path, with: .color(Color(red: 0.22, green: 0.13, blue: 0.13).opacity(0.95)),
                                     style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
                    }
                    // Claude  Date 06/17/2026
                    // Blossom puffs: a soft halo, a solid body, and a small bright highlight
                    // so each blossom has a little dimension instead of reading as a flat dot.
                    for bl in blossoms {
                        let cx = bl.p.x * w + wind(bl.p)
                        let cy = bl.p.y * h
                        let r = CGFloat(bl.r) * scale
                        layer.fill(circle(cx, cy, r * 1.7), with: .color(pink(bl.shade).opacity(0.28)))
                        layer.fill(circle(cx, cy, r), with: .color(pink(bl.shade).opacity(0.93)))
                        layer.fill(circle(cx - r * 0.28, cy - r * 0.28, r * 0.36),
                                   with: .color(Color(red: 1.0, green: 0.96, blue: 0.98).opacity(0.55)))
                    }
                }

                // Foreground: falling, swaying, tumbling petals.
                let margin: CGFloat = scale * 0.1
                for pe in petals {
                    let prog = CGFloat((t * pe.speed + pe.offset).truncatingRemainder(dividingBy: 1))
                    let y = prog * (h + margin * 2) - margin
                    let swayX = CGFloat(sin(t * pe.sway + pe.swayPhase)) * w * 0.06
                    let x = CGFloat(pe.x) * w + swayX
                    let rot = t * pe.spin + pe.spinPhase
                    let fade = min(1, Double(prog) * 6)                  // quick fade-in at the top
                    ctx.drawLayer { layer in
                        layer.translateBy(x: x, y: y)
                        layer.rotate(by: .radians(rot))
                        layer.fill(petalPath(CGFloat(pe.size)),
                                   with: .color(pink(pe.shade).opacity(0.9 * fade)))
                    }
                }
            }
        }
        .drawingGroup()
    }
}

// MARK: - Seeded RNG

// Claude  Date 06/16/2026
// A tiny deterministic generator so star/ember layouts are fixed per card
// (seeded once) instead of reshuffling on every view rebuild.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 2862933555777941757 &+ 3037000493 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
