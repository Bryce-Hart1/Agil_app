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
            case .shootingStars:         ShootingStarsBackground()
            case .galaxy:                GalaxyBackground()
            case .molten:                MoltenBackground()
            case .cherryBlossom:         CherryBlossomBackground()
            case .foundersShootingStars: FoundersShootingStarsBackground()
            case .foundersGalaxy:        FoundersGalaxyBackground()
            case .foundersConstellation: FoundersConstellationBackground()
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

// MARK: - Shooting Stars (Founders Edition)

// Claude  Date 07/12/2026
// "Shooting Stars — Founders Edition": the premium upgrade of the card above,
// exclusive to founding supporters (never sold — see CardStyle.isFounders and
// ThemeManager.grantFoundersCards). Same deep-space idea, turned up:
//  - A broader purple/green/gold/white palette (vs. the original's purple/blue/
//    pink/teal), including a slow-pulsing gold aura for extra depth.
//  - Nebula clouds drift on *two* summed sine frequencies per axis so the
//    motion never quite repeats, instead of one clean loop.
//  - Nearly double the stars (130 vs 70), with a subset that throw a brief
//    four-point sparkle flare at the peak of their twinkle.
//  - Nearly double the meteors (16 vs 9), gold- and white-streaked, with a
//    wider spread of angles so the sky reads busier and more dynamic.
//  - A soft diagonal foil-shine sweep glides across the whole card on a slow
//    loop, like light catching foil on a physical premium trading card.
private struct FoundersShootingStarsBackground: View {
    // Stable, seeded star field — distinct seed from the base card so the two
    // fields don't visually echo each other.
    private let stars: [Star] = {
        var rng = SeededGenerator(seed: 141)
        return (0..<130).map { _ in
            Star(x: .random(in: 0...1, using: &rng),
                 y: .random(in: 0...1, using: &rng),
                 radius: .random(in: 0.4...1.9, using: &rng),
                 phase: .random(in: 0...(2 * .pi), using: &rng),
                 speed: .random(in: 0.6...2.4, using: &rng),
                 sparkles: Bool.random(using: &rng) && Bool.random(using: &rng)) // ~25% flare-capable
        }
    }()

    // The drifting colour clouds — purple/gold/green/white, each with a second
    // slower sine frequency layered in so the drift path never quite repeats.
    private let clouds: [Cloud] = [
        Cloud(x: 0.20, y: 0.26, color: Color(red: 0.62, green: 0.24, blue: 0.92), size: 1.00, phase: 0.0, speed: 0.20, phase2: 0.6,  speed2: 0.11),
        Cloud(x: 0.80, y: 0.22, color: Color(red: 0.98, green: 0.82, blue: 0.35), size: 0.72, phase: 1.4, speed: 0.16, phase2: 2.2,  speed2: 0.09),
        Cloud(x: 0.66, y: 0.68, color: Color(red: 0.20, green: 0.78, blue: 0.48), size: 0.92, phase: 2.6, speed: 0.22, phase2: 4.0,  speed2: 0.13),
        Cloud(x: 0.14, y: 0.74, color: Color(red: 0.90, green: 0.90, blue: 0.98), size: 0.66, phase: 3.8, speed: 0.15, phase2: 1.1,  speed2: 0.10),
        Cloud(x: 0.46, y: 0.42, color: Color(red: 0.45, green: 0.18, blue: 0.80), size: 0.80, phase: 5.0, speed: 0.19, phase2: 3.3,  speed2: 0.08),
        Cloud(x: 0.92, y: 0.60, color: Color(red: 0.16, green: 0.62, blue: 0.42), size: 0.70, phase: 0.9, speed: 0.17, phase2: 5.4,  speed2: 0.12),
    ]

    // A bigger, busier flurry than the base card's — mixed gold/white streaks
    // over a wider angle spread.
    private let meteors: [Meteor] = {
        var rng = SeededGenerator(seed: 233)
        return (0..<16).map { i in
            Meteor(startX: .random(in: -0.15...0.75, using: &rng),
                   startY: .random(in: -0.05...0.55, using: &rng),
                   angle: .random(in: 0.22...0.70, using: &rng),
                   length: .random(in: 70...160, using: &rng),
                   width: .random(in: 1.4...2.8, using: &rng),
                   period: .random(in: 2.2...5.6, using: &rng),
                   offset: .random(in: 0...6.5, using: &rng),
                   activeFraction: .random(in: 0.14...0.24, using: &rng),
                   gold: i % 3 != 0)   // ~2 in 3 gold-tinted, the rest cool white
        }
    }()

    // Claude  Date 07/12/2026
    // Split into one small function per visual layer (base / aura / clouds /
    // stars / meteors / shine) instead of one giant Canvas closure — the combined
    // closure was too large for the type-checker ("unable to type-check this
    // expression in reasonable time"). Each function draws straight into the
    // GraphicsContext it's handed, same as the inline version did.
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawBase(ctx, size: size)
                drawAura(ctx, size: size, t: t)
                drawClouds(ctx, size: size, t: t)
                drawStars(ctx, size: size, t: t)
                drawMeteors(ctx, size: size, t: t)
                drawShine(ctx, size: size, t: t)
            }
        }
        .drawingGroup()   // composite the canvas on the GPU
    }

    // Deep-space base with a faint purple-to-green undertone corner to corner
    // (vs. the base card's flat purple-to-black).
    private func drawBase(_ ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [Color(red: 0.07, green: 0.03,  blue: 0.14),
                              Color(red: 0.02, green: 0.015, blue: 0.05),
                              Color(red: 0.02, green: 0.05,  blue: 0.035)]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
    }

    // Slow pulsing gold aura, drifting gently, for extra depth — the "premium
    // glow" that reads at a glance as a step up from the base card.
    private func drawAura(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let auraPulse: Double = 0.5 + 0.5 * sin(t * 0.35)
        let auraR: CGFloat = min(w, h) * CGFloat(0.34 + 0.05 * auraPulse)
        let auraCenter = CGPoint(x: w * CGFloat(0.5 + 0.06 * sin(t * 0.07)),
                                 y: h * CGFloat(0.46 + 0.05 * cos(t * 0.05)))
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: auraR * 0.45))
            layer.fill(
                Path(ellipseIn: CGRect(x: auraCenter.x - auraR, y: auraCenter.y - auraR,
                                       width: auraR * 2, height: auraR * 2)),
                with: .radialGradient(
                    Gradient(colors: [Color(red: 0.95, green: 0.78, blue: 0.30).opacity(0.10 + 0.06 * auraPulse), .clear]),
                    center: auraCenter, startRadius: 0, endRadius: auraR))
        }
    }

    // Drifting nebula clouds — two summed sine frequencies per axis so the path
    // never quite repeats, unlike a single clean loop.
    private func drawClouds(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: min(w, h) * 0.11))
            for c in clouds {
                let dx: CGFloat = CGFloat(sin(t * c.speed + c.phase) * 0.7 + sin(t * c.speed2 + c.phase2) * 0.3) * w * 0.10
                let dy: CGFloat = CGFloat(cos(t * c.speed * 0.8 + c.phase) * 0.7 + cos(t * c.speed2 * 1.3 + c.phase2) * 0.3) * h * 0.08
                let d = min(w, h) * c.size
                let r = CGRect(x: c.x * w - d / 2 + dx, y: c.y * h - d / 2 + dy, width: d, height: d)
                layer.fill(Path(ellipseIn: r), with: .color(c.color.opacity(0.40)))
            }
        }
    }

    // Twinkling stars — a quarter of them throw a brief four-point sparkle
    // flare at the peak of their twinkle.
    private func drawStars(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for s in stars {
            let twPhase: Double = 0.5 + 0.5 * sin(t * s.speed + s.phase)
            let tw: Double = 0.35 + 0.65 * twPhase
            let r = s.radius
            let center = CGPoint(x: s.x * w, y: s.y * h)
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(tw)))
            guard s.sparkles, twPhase > 0.88 else { continue }
            let flare: CGFloat = CGFloat((twPhase - 0.88) / 0.12)
            let len: CGFloat = r * 5 * flare
            var cross = Path()
            cross.move(to: CGPoint(x: center.x - len, y: center.y))
            cross.addLine(to: CGPoint(x: center.x + len, y: center.y))
            cross.move(to: CGPoint(x: center.x, y: center.y - len))
            cross.addLine(to: CGPoint(x: center.x, y: center.y + len))
            ctx.stroke(cross, with: .color(.white.opacity(0.5 * Double(flare))), lineWidth: 0.6)
        }
    }

    // A busier flurry of shooting stars — gold- and white-streaked, more of
    // them and a wider angle spread than the base card.
    private func drawMeteors(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for m in meteors {
            let local = ((t + m.offset) / m.period).truncatingRemainder(dividingBy: 1)
            guard local < m.activeFraction else { continue }
            let p: CGFloat = CGFloat(local / m.activeFraction)
            let travel: CGFloat = (w + h) * 0.62
            let dx: CGFloat = CGFloat(cos(m.angle))
            let dy: CGFloat = CGFloat(sin(m.angle))
            let headX: CGFloat = w * CGFloat(m.startX) + dx * travel * p
            let headY: CGFloat = h * CGFloat(m.startY) + dy * travel * p
            let head = CGPoint(x: headX, y: headY)
            let len: CGFloat = CGFloat(m.length)
            let tail = CGPoint(x: headX - dx * len, y: headY - dy * len)
            let fade: CGFloat = CGFloat(sin(Double(p) * .pi))
            let streakColor: Color = m.gold ? Color(red: 1.0, green: 0.87, blue: 0.55) : .white
            var trail = Path()
            trail.move(to: head)
            trail.addLine(to: tail)
            ctx.stroke(trail, with: .linearGradient(
                Gradient(colors: [streakColor.opacity(0.95 * fade), .clear]),
                startPoint: head, endPoint: tail),
                style: StrokeStyle(lineWidth: CGFloat(m.width), lineCap: .round))
            let hr: CGFloat = CGFloat(m.width) * 0.95
            ctx.fill(Path(ellipseIn: CGRect(x: headX - hr, y: headY - hr, width: hr * 2, height: hr * 2)),
                     with: .color(streakColor.opacity(fade)))
        }
    }

    // Foil-shine sweep: a soft bright diagonal band glides across the whole
    // card on a slow loop, like light catching foil on a physical premium
    // trading card. Drawn last so it reads as a highlight riding on top of
    // everything else.
    private func drawShine(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        let shinePeriod = 6.5
        let shineProgress: CGFloat = CGFloat((t / shinePeriod).truncatingRemainder(dividingBy: 1))
        let sweepDistance: CGFloat = (w + h) * 0.85
        let travel: CGFloat = (shineProgress - 0.5) * 2 * sweepDistance
        let bandThickness: CGFloat = min(w, h) * 0.16
        let bandLength: CGFloat = (w + h) * 1.6
        var shine = ctx
        shine.clip(to: Path(rect))
        shine.translateBy(x: w * 0.5, y: h * 0.5)
        shine.rotate(by: .radians(-0.5))
        shine.translateBy(x: travel, y: 0)
        let bandRect = CGRect(x: -bandThickness / 2, y: -bandLength / 2,
                               width: bandThickness, height: bandLength)
        shine.fill(Path(bandRect), with: .linearGradient(
            Gradient(colors: [.clear,
                              Color.white.opacity(0.14),
                              Color(red: 1.0, green: 0.86, blue: 0.5).opacity(0.10),
                              .clear]),
            startPoint: CGPoint(x: -bandThickness / 2, y: 0),
            endPoint: CGPoint(x: bandThickness / 2, y: 0)))
    }

    private struct Star { let x, y, radius, phase, speed: Double; let sparkles: Bool }
    private struct Cloud { let x, y: Double; let color: Color; let size, phase, speed, phase2, speed2: Double }
    private struct Meteor { let startX, startY, angle, length, width, period, offset, activeFraction: Double; let gold: Bool }
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

// MARK: - Galaxy (Founders Edition)

// Claude  Date 07/12/2026
// "Galaxy — Founders Edition": the premium upgrade of the card above, exclusive
// to founding supporters (never sold — see CardStyle.isFounders and
// ThemeManager.grantFoundersCards). Same rotating-spiral idea, turned up:
//  - THREE spiral arms instead of two, with 300 arm stars (vs 220) coloured by
//    radius across a much broader palette: warm gold at the core, ice blue
//    through the mid-arm, violet-rose at the rim — plus scattered amber star
//    clusters dotted along the arms.
//  - A warm two-tone core glow (gold heart fading through blue) over a denser
//    160-star bulge, instead of the original's single cool glow.
//  - A small rose-tinted COMPANION galaxy spinning on its own in the corner.
//  - Occasional SUPERNOVA flares that bloom and fade along the arms, riding the
//    disc's rotation.
//  - The disc precesses: its tilt (vertical squash) breathes and the spin axis
//    wobbles a few degrees, so it reads as a living 3D object instead of a flat
//    spinner.
//  - Background stars drift laterally at seeded speeds (parallax) rather than
//    sitting frozen behind the disc.
//  - The same signature foil-shine sweep as the other Founders card, so the
//    Founders line reads as a family.
// Split into one small function per visual layer (same reason as the Founders
// Shooting Stars card: one giant Canvas closure blows the type-checker budget).
private struct FoundersGalaxyBackground: View {
    // Stars along the three spiral arms. `amber` flags the warm cluster stars.
    private let armStars: [ArmStar] = {
        var rng = SeededGenerator(seed: 173)
        return (0..<300).map { _ in
            let t01 = pow(Double.random(in: 0...1, using: &rng), 0.7)   // bias outward
            return ArmStar(t01: t01,
                           arm: Double(Int.random(in: 0..<3, using: &rng)) * 2 * .pi / 3,
                           jitter: .random(in: -0.20...0.20, using: &rng),
                           radius: .random(in: 0.5...1.8, using: &rng),
                           phase: .random(in: 0...(2 * .pi), using: &rng),
                           twinkle: .random(in: 0.8...2.4, using: &rng),
                           amber: Double.random(in: 0...1, using: &rng) < 0.16)
        }
    }()

    // Dense golden bulge packed into the core (radius biased inward).
    private let coreStars: [CoreStar] = {
        var rng = SeededGenerator(seed: 157)
        return (0..<160).map { _ in
            CoreStar(r01: pow(Double.random(in: 0...1, using: &rng), 1.8),
                     angle: .random(in: 0...(2 * .pi), using: &rng),
                     radius: .random(in: 0.4...1.6, using: &rng),
                     phase: .random(in: 0...(2 * .pi), using: &rng),
                     twinkle: .random(in: 0.9...2.6, using: &rng))
        }
    }()

    // Background field with per-star lateral drift for parallax.
    private let bgStars: [BgStar] = {
        var rng = SeededGenerator(seed: 191)
        return (0..<80).map { _ in
            BgStar(x: .random(in: 0...1, using: &rng),
                   y: .random(in: 0...1, using: &rng),
                   radius: .random(in: 0.4...1.3, using: &rng),
                   phase: .random(in: 0...(2 * .pi), using: &rng),
                   speed: .random(in: 0.6...2.0, using: &rng),
                   drift: .random(in: 0.002...0.008, using: &rng))
        }
    }()

    // The little companion galaxy's own star disc.
    private let companionStars: [CompStar] = {
        var rng = SeededGenerator(seed: 99)
        return (0..<30).map { _ in
            CompStar(r01: pow(Double.random(in: 0...1, using: &rng), 1.2),
                     angle: .random(in: 0...(2 * .pi), using: &rng),
                     radius: .random(in: 0.3...0.9, using: &rng),
                     phase: .random(in: 0...(2 * .pi), using: &rng),
                     twinkle: .random(in: 0.9...2.2, using: &rng))
        }
    }()

    // Supernova events: each sits at a fixed spot on an arm (t01/arm/jitter,
    // same placement math as an arm star) and flares on its own long loop.
    private let novae: [Nova] = {
        var rng = SeededGenerator(seed: 61)
        return (0..<5).map { _ in
            Nova(t01: .random(in: 0.35...0.90, using: &rng),
                 arm: Double(Int.random(in: 0..<3, using: &rng)) * 2 * .pi / 3,
                 jitter: .random(in: -0.15...0.15, using: &rng),
                 period: .random(in: 7.0...14.0, using: &rng),
                 offset: .random(in: 0...14.0, using: &rng))
        }
    }()

    // MARK: Shared disc geometry

    // Spin, twist, and the precession terms — one place so every layer of the
    // disc (bulge, arms, novae) moves as a single rigid body.
    private func discSpin(_ t: Double) -> Double { t * 0.075 }
    private let twist: Double = 3.1
    private func discSquash(_ t: Double) -> CGFloat { CGFloat(0.62 + 0.05 * sin(t * 0.09)) }
    private func discWobble(_ t: Double) -> Double { 0.05 * sin(t * 0.13) }

    private func discCenter(_ size: CGSize) -> CGPoint { CGPoint(x: size.width * 0.5, y: size.height * 0.46) }
    private func discMaxR(_ size: CGSize) -> CGFloat { min(size.width, size.height) * 0.55 }

    // A context copy rotated by the precession wobble about the disc centre.
    private func wobbled(_ ctx: GraphicsContext, size: CGSize, t: Double) -> GraphicsContext {
        let center = discCenter(size)
        var disc = ctx
        disc.translateBy(x: center.x, y: center.y)
        disc.rotate(by: .radians(discWobble(t)))
        disc.translateBy(x: -center.x, y: -center.y)
        return disc
    }

    // Position of a point riding the spiral disc (arm-star placement math).
    private func discPoint(t01: Double, arm: Double, jitter: Double,
                           size: CGSize, t: Double) -> CGPoint {
        let center = discCenter(size)
        let r: CGFloat = CGFloat(t01) * discMaxR(size)
        let angle: Double = arm + discSpin(t) + t01 * twist + jitter
        return CGPoint(x: center.x + CGFloat(cos(angle)) * r,
                       y: center.y + CGFloat(sin(angle)) * r * discSquash(t))
    }

    // MARK: Body

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawBase(ctx, size: size)
                drawBackgroundStars(ctx, size: size, t: t)
                drawCompanion(ctx, size: size, t: t)
                drawCoreGlow(ctx, size: size, t: t)
                drawCoreStars(ctx, size: size, t: t)
                drawArmStars(ctx, size: size, t: t)
                drawNovae(ctx, size: size, t: t)
                drawShine(ctx, size: size, t: t)
            }
        }
        .drawingGroup()   // composite the canvas on the GPU
    }

    // Deep-space base: violet toward the core with a whisper of teal along the
    // bottom edge, so even the empty sky carries more colour than the original.
    private func drawBase(_ ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: .radialGradient(
            Gradient(colors: [Color(red: 0.13, green: 0.10, blue: 0.30),
                              Color(red: 0.03, green: 0.02, blue: 0.09)]),
            center: discCenter(size), startRadius: 0, endRadius: discMaxR(size) * 1.7))
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [.clear, Color(red: 0.05, green: 0.30, blue: 0.30).opacity(0.16)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    // Twinkling background field that also drifts sideways (parallax) instead
    // of sitting frozen behind the rotating disc.
    private func drawBackgroundStars(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for s in bgStars {
            let xx: CGFloat = CGFloat((s.x + t * s.drift).truncatingRemainder(dividingBy: 1))
            let tw: Double = 0.25 + 0.45 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
            let r: CGFloat = s.radius
            ctx.fill(Path(ellipseIn: CGRect(x: xx * w - r, y: CGFloat(s.y) * h - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(tw)))
        }
    }

    // The rose-tinted companion dwarf galaxy, spinning on its own in the corner.
    private func drawCompanion(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let c = CGPoint(x: w * 0.82, y: h * 0.13)
        let r: CGFloat = min(w, h) * 0.11
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: r * 0.7))
            layer.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .color(Color(red: 0.95, green: 0.60, blue: 0.55).opacity(0.30)))
        }
        let spin: Double = t * 0.18
        for s in companionStars {
            let rr: CGFloat = CGFloat(s.r01) * r
            let a: Double = s.angle + spin
            let x: CGFloat = c.x + CGFloat(cos(a)) * rr
            let y: CGFloat = c.y + CGFloat(sin(a)) * rr * 0.7
            let tw: Double = 0.40 + 0.50 * (0.5 + 0.5 * sin(t * s.twinkle + s.phase))
            let rad: CGFloat = s.radius
            ctx.fill(Path(ellipseIn: CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)),
                     with: .color(Color(red: 1.0, green: 0.86, blue: 0.78).opacity(tw)))
        }
    }

    // Two-tone core glow: a warm gold heart fading through blue — richer than
    // the original's single cool gradient.
    private func drawCoreGlow(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let center = discCenter(size)
        let pulse: Double = 0.5 + 0.5 * sin(t * 0.7)
        let coreR: CGFloat = discMaxR(size) * CGFloat(0.46 + 0.06 * pulse)
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: coreR * 0.5))
            layer.fill(
                Path(ellipseIn: CGRect(x: center.x - coreR, y: center.y - coreR,
                                       width: coreR * 2, height: coreR * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 1.0,  green: 0.92, blue: 0.72), location: 0.00),
                        .init(color: Color(red: 0.98, green: 0.75, blue: 0.40).opacity(0.55), location: 0.35),
                        .init(color: Color(red: 0.50, green: 0.55, blue: 1.0).opacity(0.30),  location: 0.70),
                        .init(color: .clear, location: 1.00),
                    ]),
                    center: center, startRadius: 0, endRadius: coreR))
        }
    }

    // Golden bulge cluster, rotating and precessing with the disc.
    private func drawCoreStars(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let center = discCenter(size)
        let maxR = discMaxR(size)
        let spin = discSpin(t)
        let squash = discSquash(t)
        let disc = wobbled(ctx, size: size, t: t)
        for s in coreStars {
            let r: CGFloat = CGFloat(s.r01) * maxR * 0.45
            let angle: Double = s.angle + spin
            let x: CGFloat = center.x + CGFloat(cos(angle)) * r
            let y: CGFloat = center.y + CGFloat(sin(angle)) * r * squash
            let tw: Double = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * s.twinkle + s.phase))
            let rad: CGFloat = s.radius
            disc.fill(Path(ellipseIn: CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)),
                      with: .color(Color(red: 1.0, green: 0.93, blue: 0.80).opacity(tw)))
        }
    }

    // Colour along the arm: gold at the core → ice blue mid-arm → violet-rose
    // at the rim, with amber cluster stars breaking the gradient up.
    private func armColor(_ s: ArmStar) -> Color {
        if s.amber { return Color(red: 1.0, green: 0.72, blue: 0.42) }
        if s.t01 < 0.5 {
            let u = s.t01 / 0.5
            return Color(red: 0.98 - 0.26 * u, green: 0.92 - 0.14 * u, blue: 0.80 + 0.20 * u)
        }
        let u = (s.t01 - 0.5) / 0.5
        return Color(red: 0.74 + 0.14 * u, green: 0.78 - 0.30 * u, blue: 1.0)
    }

    // The three spiral arms.
    private func drawArmStars(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let disc = wobbled(ctx, size: size, t: t)
        for s in armStars {
            let p = discPoint(t01: s.t01, arm: s.arm, jitter: s.jitter, size: size, t: t)
            let tw: Double = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * s.twinkle + s.phase))
            let rad: CGFloat = CGFloat(s.radius * (1.0 - 0.25 * s.t01)) * (s.amber ? 1.4 : 1.0)
            disc.fill(Path(ellipseIn: CGRect(x: p.x - rad, y: p.y - rad, width: rad * 2, height: rad * 2)),
                      with: .color(armColor(s).opacity(tw)))
        }
    }

    // Supernova flares: bloom, throw a cross flare, and fade — each riding the
    // rotating disc at its seeded arm position.
    private func drawNovae(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let disc = wobbled(ctx, size: size, t: t)
        for n in novae {
            let local = ((t + n.offset) / n.period).truncatingRemainder(dividingBy: 1)
            guard local < 0.12 else { continue }
            let p: Double = local / 0.12
            let flare: CGFloat = CGFloat(sin(p * .pi))
            let at = discPoint(t01: n.t01, arm: n.arm, jitter: n.jitter, size: size, t: t)
            let glowR: CGFloat = discMaxR(size) * CGFloat(0.04 + 0.06 * p)
            disc.drawLayer { layer in
                layer.addFilter(.blur(radius: glowR * 0.6))
                layer.fill(Path(ellipseIn: CGRect(x: at.x - glowR, y: at.y - glowR,
                                                  width: glowR * 2, height: glowR * 2)),
                           with: .color(Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.85 * flare)))
            }
            let len: CGFloat = glowR * 1.7 * flare
            var cross = Path()
            cross.move(to: CGPoint(x: at.x - len, y: at.y))
            cross.addLine(to: CGPoint(x: at.x + len, y: at.y))
            cross.move(to: CGPoint(x: at.x, y: at.y - len))
            cross.addLine(to: CGPoint(x: at.x, y: at.y + len))
            disc.stroke(cross, with: .color(.white.opacity(0.7 * flare)), lineWidth: 0.8)
            let hr: CGFloat = 1.6 * flare
            disc.fill(Path(ellipseIn: CGRect(x: at.x - hr, y: at.y - hr, width: hr * 2, height: hr * 2)),
                      with: .color(.white.opacity(flare)))
        }
    }

    // The Founders-line signature foil-shine sweep (same treatment as the
    // Founders Shooting Stars card, slightly slower so the two never sync up).
    private func drawShine(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        let shinePeriod = 7.5
        let shineProgress: CGFloat = CGFloat((t / shinePeriod).truncatingRemainder(dividingBy: 1))
        let sweepDistance: CGFloat = (w + h) * 0.85
        let travel: CGFloat = (shineProgress - 0.5) * 2 * sweepDistance
        let bandThickness: CGFloat = min(w, h) * 0.16
        let bandLength: CGFloat = (w + h) * 1.6
        var shine = ctx
        shine.clip(to: Path(rect))
        shine.translateBy(x: w * 0.5, y: h * 0.5)
        shine.rotate(by: .radians(-0.5))
        shine.translateBy(x: travel, y: 0)
        let bandRect = CGRect(x: -bandThickness / 2, y: -bandLength / 2,
                               width: bandThickness, height: bandLength)
        // Quieter than the Shooting Stars version — the galaxy's sky is darker,
        // so the same band opacity reads much louder here.
        shine.fill(Path(bandRect), with: .linearGradient(
            Gradient(colors: [.clear,
                              Color.white.opacity(0.09),
                              Color(red: 1.0, green: 0.86, blue: 0.5).opacity(0.06),
                              .clear]),
            startPoint: CGPoint(x: -bandThickness / 2, y: 0),
            endPoint: CGPoint(x: bandThickness / 2, y: 0)))
    }

    private struct ArmStar { let t01, arm, jitter, radius, phase, twinkle: Double; let amber: Bool }
    private struct CoreStar { let r01, angle, radius, phase, twinkle: Double }
    private struct BgStar { let x, y, radius, phase, speed, drift: Double }
    private struct CompStar { let r01, angle, radius, phase, twinkle: Double }
    private struct Nova { let t01, arm, jitter, period, offset: Double }
}

// MARK: - Constellation (Founders Edition)

// Claude  Date 07/13/2026
// "Constellation — Founders Edition": the third Founders card, and the pink one
// (tying back to the brand's Classic Pink #EA0F8B) where the other two are
// purple/gold and blue-violet. A quiet night sky: ambient white stars twinkle
// over a near-black plum base, and five brighter warm-pink stars — joined by
// thin sky-atlas lines — trace a loose capital "A", the way real constellation
// charts only roughly resemble their namesake. Each anchor is seeded-jittered
// off the true letterform so the figure reads as discovered in the sky, not
// stamped on it. Motion stays deliberately calm (slow twinkle, two lazy
// meteors) so the figure keeps the spotlight, plus the Founders-line signature
// foil-shine sweep on its own period so the three cards never sync up.
// Split into one small function per visual layer (same reason as the other
// Founders cards: one giant Canvas closure blows the type-checker budget).
private struct FoundersConstellationBackground: View {
    // Warm pink-white shared by the figure's stars and their chart lines.
    private let pink = Color(red: 0.98, green: 0.55, blue: 0.75)

    // Ambient background field — cool, dim, and calm next to the pink anchors.
    private let stars: [Star] = {
        var rng = SeededGenerator(seed: 271)
        return (0..<85).map { _ in
            Star(x: .random(in: 0...1, using: &rng),
                 y: .random(in: 0...1, using: &rng),
                 radius: .random(in: 0.35...1.4, using: &rng),
                 phase: .random(in: 0...(2 * .pi), using: &rng),
                 speed: .random(in: 0.4...1.6, using: &rng))
        }
    }()

    // The "A" figure: five anchors in letter-box space (apex, two crossbar/
    // mid-leg points, two feet), each nudged by a seeded jitter (~2-3% of card
    // size once mapped) so the shape reads hand-placed rather than typeset.
    private let anchors: [Anchor] = {
        var rng = SeededGenerator(seed: 307)
        let letterform: [(x: Double, y: Double)] = [
            (0.50, 0.00),   // apex
            (0.32, 0.62),   // left mid-leg / crossbar end
            (0.68, 0.62),   // right mid-leg / crossbar end
            (0.12, 1.00),   // left foot
            (0.88, 1.00),   // right foot
        ]
        return letterform.map { p in
            let jx = Double.random(in: -0.05...0.05, using: &rng)
            let jy = Double.random(in: -0.04...0.04, using: &rng)
            return Anchor(x: p.x + jx, y: p.y + jy,
                          radius: .random(in: 1.9...2.6, using: &rng),
                          phase: .random(in: 0...(2 * .pi), using: &rng),
                          speed: .random(in: 0.35...0.8, using: &rng))
        }
    }()

    // Which anchors the chart lines join (indices into `anchors`): the two
    // legs plus the crossbar.
    private let links: [(Int, Int)] = [(0, 1), (1, 3), (0, 2), (2, 4), (1, 2)]

    // Two barely-there plum pools that drift very slowly — depth without noise.
    private let haze: [Haze] = [
        Haze(x: 0.30, y: 0.35, color: Color(red: 0.45, green: 0.08, blue: 0.28), size: 0.95, phase: 0.0, speed: 0.05),
        Haze(x: 0.78, y: 0.70, color: Color(red: 0.36, green: 0.06, blue: 0.17), size: 0.85, phase: 2.6, speed: 0.04),
    ]

    // Just two meteors, on long lazy loops — this card stays quiet.
    private let meteors: [Meteor] = {
        var rng = SeededGenerator(seed: 353)
        return (0..<2).map { _ in
            Meteor(startX: .random(in: -0.1...0.5, using: &rng),
                   startY: .random(in: 0.0...0.35, using: &rng),
                   angle: .random(in: 0.30...0.50, using: &rng),
                   length: .random(in: 55...95, using: &rng),
                   width: .random(in: 1.1...1.7, using: &rng),
                   period: .random(in: 9.0...14.0, using: &rng),
                   offset: .random(in: 0...14.0, using: &rng),
                   activeFraction: .random(in: 0.10...0.16, using: &rng))
        }
    }()

    // Maps a letter-box point into card space: sized off min(w,h) so the "A"
    // keeps its proportions on any card, centred slightly left/high of true
    // centre (like the Galaxy core) so it doesn't feel machine-placed.
    private func anchorPoint(_ a: Anchor, size: CGSize) -> CGPoint {
        let scale = min(size.width, size.height)
        let c = CGPoint(x: size.width * 0.47, y: size.height * 0.45)
        return CGPoint(x: c.x + CGFloat(a.x - 0.5) * scale * 0.58,
                       y: c.y + CGFloat(a.y - 0.5) * scale * 0.66)
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawBase(ctx, size: size)
                drawHaze(ctx, size: size, t: t)
                drawStars(ctx, size: size, t: t)
                drawLinks(ctx, size: size, t: t)
                drawAnchors(ctx, size: size, t: t)
                drawMeteors(ctx, size: size, t: t)
                drawShine(ctx, size: size, t: t)
            }
        }
        .drawingGroup()   // composite the canvas on the GPU
    }

    // Near-black base with a warm plum/maroon undertone — the "pink family"
    // read, vs. Galaxy's cool blue-black and Shooting Stars' purple-green.
    private func drawBase(_ ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [Color(red: 0.09,  green: 0.025, blue: 0.06),
                              Color(red: 0.035, green: 0.01,  blue: 0.03),
                              Color(red: 0.06,  green: 0.015, blue: 0.045)]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
    }

    // The plum pools, blurred to a faint glow behind everything.
    private func drawHaze(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: min(w, h) * 0.18))
            for p in haze {
                let dx = CGFloat(sin(t * p.speed + p.phase)) * w * 0.05
                let dy = CGFloat(cos(t * p.speed * 0.8 + p.phase)) * h * 0.04
                let d = min(w, h) * CGFloat(p.size)
                layer.fill(Path(ellipseIn: CGRect(x: CGFloat(p.x) * w - d / 2 + dx,
                                                  y: CGFloat(p.y) * h - d / 2 + dy,
                                                  width: d, height: d)),
                           with: .color(p.color.opacity(0.16)))
            }
        }
    }

    // Ambient twinkle field — dimmer than the other cards' so the figure's
    // stars are unmistakably the brightest points in the sky.
    private func drawStars(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for s in stars {
            let tw = 0.22 + 0.48 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
            let r = s.radius
            ctx.fill(Path(ellipseIn: CGRect(x: s.x * w - r, y: s.y * h - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(tw)))
        }
    }

    // The sky-atlas strokes: thin, faint pink lines joining the anchors, each
    // end pulled back short of its star (charts leave that gap), with a slow
    // breathing opacity so the figure feels lit rather than printed.
    private func drawLinks(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let breathe = 0.26 + 0.07 * sin(t * 0.30)
        let gap: CGFloat = min(size.width, size.height) * 0.025
        for (i, j) in links {
            let a = anchorPoint(anchors[i], size: size)
            let b = anchorPoint(anchors[j], size: size)
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(sqrt(dx * dx + dy * dy), 0.0001)
            let ux = dx / len, uy = dy / len
            var line = Path()
            line.move(to: CGPoint(x: a.x + ux * gap, y: a.y + uy * gap))
            line.addLine(to: CGPoint(x: b.x - ux * gap, y: b.y - uy * gap))
            ctx.stroke(line, with: .color(pink.opacity(breathe)), lineWidth: 0.7)
        }
    }

    // The figure's stars: larger and warmer than the field, each on its own
    // slow twinkle, with a soft pink halo so they read as the sky's brightest.
    private func drawAnchors(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        for a in anchors {
            let p = anchorPoint(a, size: size)
            let tw = 0.70 + 0.30 * (0.5 + 0.5 * sin(t * a.speed + a.phase))
            let r = CGFloat(a.radius)
            let haloR = r * 4.5
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: haloR * 0.55))
                layer.fill(Path(ellipseIn: CGRect(x: p.x - haloR, y: p.y - haloR,
                                                  width: haloR * 2, height: haloR * 2)),
                           with: .color(pink.opacity(0.28 * tw)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                     with: .color(Color(red: 1.0, green: 0.82, blue: 0.90).opacity(tw)))
        }
    }

    // The two lazy meteors — same streak math as the other cards, pink-white
    // tinted and far less frequent, so the sky stays quiet between passes.
    private func drawMeteors(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for m in meteors {
            let local = ((t + m.offset) / m.period).truncatingRemainder(dividingBy: 1)
            guard local < m.activeFraction else { continue }
            let p: CGFloat = CGFloat(local / m.activeFraction)
            let travel: CGFloat = (w + h) * 0.6
            let dx: CGFloat = CGFloat(cos(m.angle))
            let dy: CGFloat = CGFloat(sin(m.angle))
            let headX: CGFloat = w * CGFloat(m.startX) + dx * travel * p
            let headY: CGFloat = h * CGFloat(m.startY) + dy * travel * p
            let head = CGPoint(x: headX, y: headY)
            let tail = CGPoint(x: headX - dx * CGFloat(m.length), y: headY - dy * CGFloat(m.length))
            let fade: CGFloat = CGFloat(sin(Double(p) * .pi))
            let streak = Color(red: 1.0, green: 0.88, blue: 0.93)
            var trail = Path()
            trail.move(to: head)
            trail.addLine(to: tail)
            ctx.stroke(trail, with: .linearGradient(
                Gradient(colors: [streak.opacity(0.85 * fade), .clear]),
                startPoint: head, endPoint: tail),
                style: StrokeStyle(lineWidth: CGFloat(m.width), lineCap: .round))
            let hr: CGFloat = CGFloat(m.width) * 0.9
            ctx.fill(Path(ellipseIn: CGRect(x: headX - hr, y: headY - hr, width: hr * 2, height: hr * 2)),
                     with: .color(streak.opacity(fade)))
        }
    }

    // The Founders-line signature foil-shine sweep, on its own period (8.5s vs
    // 6.5 / 7.5 on the other two cards) so the three never sync up. The touch
    // of gold lives here only — the Founders accent over the pink sky.
    private func drawShine(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        let shinePeriod = 8.5
        let shineProgress: CGFloat = CGFloat((t / shinePeriod).truncatingRemainder(dividingBy: 1))
        let sweepDistance: CGFloat = (w + h) * 0.85
        let travel: CGFloat = (shineProgress - 0.5) * 2 * sweepDistance
        let bandThickness: CGFloat = min(w, h) * 0.16
        let bandLength: CGFloat = (w + h) * 1.6
        var shine = ctx
        shine.clip(to: Path(rect))
        shine.translateBy(x: w * 0.5, y: h * 0.5)
        shine.rotate(by: .radians(-0.5))
        shine.translateBy(x: travel, y: 0)
        let bandRect = CGRect(x: -bandThickness / 2, y: -bandLength / 2,
                               width: bandThickness, height: bandLength)
        // Between the other two cards' band opacities — this sky is dark like
        // the Galaxy's, but the sweep still has to read as the family signature.
        shine.fill(Path(bandRect), with: .linearGradient(
            Gradient(colors: [.clear,
                              Color.white.opacity(0.10),
                              Color(red: 1.0, green: 0.86, blue: 0.5).opacity(0.07),
                              .clear]),
            startPoint: CGPoint(x: -bandThickness / 2, y: 0),
            endPoint: CGPoint(x: bandThickness / 2, y: 0)))
    }

    private struct Star { let x, y, radius, phase, speed: Double }
    private struct Anchor { let x, y, radius, phase, speed: Double }
    private struct Haze { let x, y: Double; let color: Color; let size, phase, speed: Double }
    private struct Meteor { let startX, startY, angle, length, width, period, offset, activeFraction: Double }
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

// Claude  Date 07/01/2026
// DROP-IN REPLACEMENT for the `// MARK: - Cherry Blossom` section of
// AnimatedCardBackground.swift. Delete the old CherryBlossomBackground struct
// (and its nested Branch/Blossom/Petal types) and paste this section in its
// place. It relies on SeededGenerator at the bottom of that file, so it must
// live in the same file.

// MARK: - Cherry Blossom

// Claude  Date 07/01/2026 last changed: 07/01/2026 by: Claude
// "Cherry Blossom", take three: a true MACRO shot, modelled on photo references.
// A dark plum limb pushes in from the right edge and carries a handful of BIG
// five-petal blossoms drawn petal-by-petal — notched tips, a radial white-to-pink
// gradient, a magenta heart, and radiating stamens tipped with gold anthers.
// Behind them, heavily blurred bokeh blobs and soft out-of-focus blossoms sell
// the shallow depth of field; burgundy leaves and tight pink buds dress the
// branch. The whole limb flexes on a slow two-frequency sway (pivoting where it
// enters the frame), each blossom bobs on its own phase, and loose petals — plus
// the occasional burgundy leaf — detach and tumble down the foreground.
// Layout is art-directed in normalised [0,1] coords so it scales to any card.
private struct CherryBlossomBackground: View {

    // MARK: Scene description (constants — stable across redraws)

    private struct BokehBlob   { let x, y, r, shade: Double }
    private struct SceneFlower { let x, y, r, rot, shade, bobPhase: Double }
    private struct Bud         { let x, y, r: Double; let stemFrom: CGPoint }
    private struct LeafSpec    { let x, y, len, angle, shade, flutterPhase: Double }
    private struct Limb        { let a, b: CGPoint; let w0, w1: Double }   // widths as fractions of scale
    private struct FallingBit {
        let x0, y0, size, speed, offset, sway, swayPhase, spin, spinPhase, flip, shade: Double
        let isLeaf: Bool
    }

    // Soft out-of-focus colour pools far behind everything.
    private let bokeh: [BokehBlob] = [
        BokehBlob(x: 0.15, y: 0.15, r: 0.30, shade: 0.15),
        BokehBlob(x: 0.85, y: 0.75, r: 0.34, shade: 0.55),
        BokehBlob(x: 0.55, y: 0.45, r: 0.26, shade: 0.00),
        BokehBlob(x: 0.30, y: 0.85, r: 0.28, shade: 0.70),
        BokehBlob(x: 0.95, y: 0.10, r: 0.22, shade: 0.30),
    ]

    // Mid-depth blossoms, drawn simplified and heavily blurred.
    private let backFlowers: [SceneFlower] = [
        SceneFlower(x: 0.80, y: 0.14, r: 0.11, rot: 0.8, shade: 0.55, bobPhase: 0.9),
        SceneFlower(x: 0.96, y: 0.58, r: 0.10, rot: 2.1, shade: 0.75, bobPhase: 2.4),
        SceneFlower(x: 0.55, y: 0.05, r: 0.09, rot: 1.4, shade: 0.40, bobPhase: 4.1),
        SceneFlower(x: 0.12, y: 0.90, r: 0.10, rot: 0.3, shade: 0.85, bobPhase: 5.3),
    ]

    // The hero blossoms — big, detailed, nearly in focus. The third sits half
    // off the left edge so the framing reads as a crop of something larger.
    private let frontFlowers: [SceneFlower] = [
        SceneFlower(x: 0.23,  y: 0.30, r: 0.230, rot: 0.35,  shade: 0.20, bobPhase: 0.0),
        SceneFlower(x: 0.47,  y: 0.69, r: 0.180, rot: -0.55, shade: 0.45, bobPhase: 2.1),
        SceneFlower(x: -0.02, y: 0.56, r: 0.140, rot: 1.15,  shade: 0.65, bobPhase: 3.8),
    ]

    // The limb: tapering segments entering from off the right edge, plus a
    // thin drooping stalk that carries the lower blossom.
    private let limbs: [Limb] = [
        Limb(a: CGPoint(x: 1.08, y: 0.28),  b: CGPoint(x: 0.72, y: 0.37), w0: 0.050, w1: 0.036),
        Limb(a: CGPoint(x: 0.72, y: 0.37),  b: CGPoint(x: 0.40, y: 0.33), w0: 0.036, w1: 0.026),
        Limb(a: CGPoint(x: 0.40, y: 0.33),  b: CGPoint(x: 0.23, y: 0.31), w0: 0.026, w1: 0.016),
        Limb(a: CGPoint(x: 0.58, y: 0.365), b: CGPoint(x: 0.50, y: 0.55), w0: 0.014, w1: 0.009),
        Limb(a: CGPoint(x: 0.50, y: 0.55),  b: CGPoint(x: 0.47, y: 0.68), w0: 0.009, w1: 0.006),
    ]

    // Unopened buds on thin stems, like the reference's magenta droplets.
    private let buds: [Bud] = [
        Bud(x: 0.90, y: 0.47, r: 0.030, stemFrom: CGPoint(x: 0.85, y: 0.345)),
        Bud(x: 0.99, y: 0.16, r: 0.026, stemFrom: CGPoint(x: 0.93, y: 0.295)),
        Bud(x: 0.63, y: 0.50, r: 0.022, stemFrom: CGPoint(x: 0.56, y: 0.40)),
    ]

    // Burgundy leaves clustered where the limb is thickest.
    private let leaves: [LeafSpec] = [
        LeafSpec(x: 0.62, y: 0.34, len: 0.13, angle: -0.9, shade: 0.2, flutterPhase: 0.4),
        LeafSpec(x: 0.68, y: 0.38, len: 0.11, angle: 2.4,  shade: 0.6, flutterPhase: 1.9),
        LeafSpec(x: 0.55, y: 0.30, len: 0.10, angle: -2.2, shade: 0.4, flutterPhase: 3.3),
        LeafSpec(x: 0.74, y: 0.33, len: 0.12, angle: -0.3, shade: 0.8, flutterPhase: 4.6),
    ]

    // Falling petals (and the occasional leaf), seeded once.
    private let fallingBits: [FallingBit]

    init() {
        var rng = SeededGenerator(seed: 31)
        fallingBits = (0..<26).map { i in
            FallingBit(x0: .random(in: 0.02...0.98, using: &rng),
                       y0: .random(in: 0.10...0.55, using: &rng),   // spawn near the canopy band
                       size: .random(in: 0.020...0.042, using: &rng),
                       speed: .random(in: 0.05...0.12, using: &rng),
                       offset: .random(in: 0...1, using: &rng),
                       sway: .random(in: 0.5...1.2, using: &rng),
                       swayPhase: .random(in: 0...(2 * .pi), using: &rng),
                       spin: .random(in: -1.8...1.8, using: &rng),
                       spinPhase: .random(in: 0...(2 * .pi), using: &rng),
                       flip: .random(in: 0.6...1.6, using: &rng),
                       shade: .random(in: 0...1, using: &rng),
                       isLeaf: i % 7 == 3)                          // ~1 in 7 is a leaf
        }
    }

    // MARK: Palette

    // Petal pinks, interpolated by a 0…1 shade so no two blossoms match exactly.
    private func palePink(_ s: Double) -> Color {
        Color(red: 0.99, green: 0.90 - 0.06 * s, blue: 0.93 - 0.03 * s)
    }
    private func midPink(_ s: Double) -> Color {
        Color(red: 0.97, green: 0.66 - 0.10 * s, blue: 0.78 - 0.06 * s)
    }
    private func heartPink(_ s: Double) -> Color {
        Color(red: 0.86 - 0.06 * s, green: 0.30 - 0.08 * s, blue: 0.52 - 0.04 * s)
    }

    // MARK: Shape helpers

    private func disc(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    // One blossom petal: base at the origin, tip at (0, -len), with the shallow
    // notch at the tip that makes it read as cherry rather than a generic oval.
    private func petalShape(len: CGFloat, width: CGFloat) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addCurve(to: CGPoint(x: -width * 0.28, y: -len),
                   control1: CGPoint(x: -width, y: -len * 0.18),
                   control2: CGPoint(x: -width * 0.90, y: -len * 0.78))
        p.addQuadCurve(to: CGPoint(x: width * 0.28, y: -len),
                       control: CGPoint(x: 0, y: -len * 0.86))       // the notch
        p.addCurve(to: .zero,
                   control1: CGPoint(x: width * 0.90, y: -len * 0.78),
                   control2: CGPoint(x: width, y: -len * 0.18))
        p.closeSubpath()
        return p
    }

    // Pointed leaf: base at origin, tip at (0, -len).
    private func leafShape(len: CGFloat, width: CGFloat) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: 0, y: -len), control: CGPoint(x: -width, y: -len * 0.5))
        p.addQuadCurve(to: .zero, control: CGPoint(x: width, y: -len * 0.5))
        return p
    }

    // Tapered quad so limbs thin out toward their tips instead of being
    // constant-width strokes.
    private func taperedLimb(from a: CGPoint, to b: CGPoint, w0: CGFloat, w1: CGFloat) -> Path {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        let nx = -dy / len, ny = dx / len
        var p = Path()
        p.move(to: CGPoint(x: a.x + nx * w0 / 2, y: a.y + ny * w0 / 2))
        p.addLine(to: CGPoint(x: b.x + nx * w1 / 2, y: b.y + ny * w1 / 2))
        p.addLine(to: CGPoint(x: b.x - nx * w1 / 2, y: b.y - ny * w1 / 2))
        p.addLine(to: CGPoint(x: a.x - nx * w0 / 2, y: a.y - ny * w0 / 2))
        p.closeSubpath()
        return p
    }

    // Cheap deterministic 0…1 hash for per-stamen variation (no RNG state needed).
    private func hash(_ x: Double) -> Double {
        let s = sin(x) * 43758.5453
        return s - s.rounded(.down)
    }

    // MARK: Blossom renderer

    // Draws one five-petal blossom. `detail: true` adds the stamen filaments and
    // gold anthers; background blossoms skip them since the blur eats the detail.
    private func drawBlossom(_ ctx: GraphicsContext, center: CGPoint, r: CGFloat,
                             rot: Double, shade: Double, t: Double, bobPhase: Double,
                             detail: Bool) {
        var f = ctx
        let bob = 0.03 * sin(t * 0.7 + bobPhase)     // gentle individual nod
        f.translateBy(x: center.x, y: center.y)
        f.rotate(by: .radians(rot + bob))

        // Five overlapping petals, each shading from deep pink at the heart out
        // to near-white at the notched tip (radial gradient centred on the heart).
        let petal = petalShape(len: r, width: r * 0.64)
        let petalFill = Gradient(stops: [
            .init(color: heartPink(shade), location: 0.00),
            .init(color: midPink(shade),   location: 0.40),
            .init(color: palePink(shade),  location: 1.00),
        ])
        for i in 0..<5 {
            var p = f
            p.rotate(by: .radians(Double(i) * 2 * .pi / 5))
            p.fill(petal, with: .radialGradient(petalFill, center: .zero,
                                                startRadius: r * 0.04, endRadius: r * 1.02))
            // Whisper of an edge so overlapping petals separate.
            p.stroke(petal, with: .color(heartPink(shade).opacity(0.16)),
                     lineWidth: max(0.5, r * 0.012))
        }

        // Magenta heart.
        f.fill(disc(0, 0, r * 0.16), with: .radialGradient(
            Gradient(colors: [Color(red: 0.55, green: 0.07, blue: 0.28),
                              Color(red: 0.78, green: 0.22, blue: 0.44).opacity(0)]),
            center: .zero, startRadius: 0, endRadius: r * 0.22))

        guard detail else { return }

        // Stamens: gently curved filaments radiating from the heart, each capped
        // with a gold anther dot — the detail that makes the close-up land.
        let filament = Color(red: 0.72, green: 0.16, blue: 0.40)
        let anther = Color(red: 0.96, green: 0.73, blue: 0.24)
        for i in 0..<18 {
            let u = hash(Double(i) * 12.9898)
            let v = hash(Double(i) * 78.2330)
            let a = Double(i) / 18 * 2 * .pi + (u - 0.5) * 0.5
            let len = r * CGFloat(0.30 + 0.20 * v)
            let bend = CGFloat((u - 0.5) * 0.3)
            let tip = CGPoint(x: CGFloat(cos(a)) * len, y: CGFloat(sin(a)) * len)
            var s = Path()
            s.move(to: CGPoint(x: CGFloat(cos(a)) * r * 0.05,
                               y: CGFloat(sin(a)) * r * 0.05))
            s.addQuadCurve(to: tip, control: CGPoint(x: tip.x * 0.5 - tip.y * bend,
                                                     y: tip.y * 0.5 + tip.x * bend))
            f.stroke(s, with: .color(filament.opacity(0.9)),
                     style: StrokeStyle(lineWidth: max(0.5, r * 0.016), lineCap: .round))
            f.fill(disc(tip.x, tip.y, max(0.8, r * 0.032)), with: .color(anther.opacity(0.95)))
        }
    }

    // MARK: Body

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let scale = min(w, h)
                let rect = CGRect(origin: .zero, size: size)

                // 1) Dusky mauve backdrop — the out-of-focus "everything else".
                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.42, green: 0.34, blue: 0.44),
                                      Color(red: 0.55, green: 0.42, blue: 0.50),
                                      Color(red: 0.38, green: 0.30, blue: 0.38)]),
                    startPoint: .zero, endPoint: CGPoint(x: w * 0.3, y: h)))

                // 2) Bokeh pools, blurred to mush.
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: scale * 0.10))
                    for b in bokeh {
                        layer.fill(disc(CGFloat(b.x) * w, CGFloat(b.y) * h, CGFloat(b.r) * scale),
                                   with: .color(palePink(b.shade).opacity(0.35)))
                    }
                }

                // 3) Out-of-focus mid-depth blossoms.
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: scale * 0.035))
                    for fl in backFlowers {
                        drawBlossom(layer,
                                    center: CGPoint(x: CGFloat(fl.x) * w, y: CGFloat(fl.y) * h),
                                    r: CGFloat(fl.r) * scale, rot: fl.rot, shade: fl.shade,
                                    t: t, bobPhase: fl.bobPhase, detail: false)
                    }
                }

                // 4) The limb and everything attached, all inside one swaying
                // transform pivoted where the branch enters the frame — so the
                // whole bough flexes as a unit instead of pieces drifting apart.
                let sway = 0.011 * sin(t * 0.5) + 0.006 * sin(t * 0.23 + 1.7)
                var scene = ctx
                let pivot = CGPoint(x: w * 1.05, y: h * 0.30)
                scene.translateBy(x: pivot.x, y: pivot.y)
                scene.rotate(by: .radians(sway))
                scene.translateBy(x: -pivot.x, y: -pivot.y)

                // Dark plum bark, faintly softened, tapering toward the tips.
                let bark = Color(red: 0.23, green: 0.11, blue: 0.14)
                scene.drawLayer { layer in
                    layer.addFilter(.blur(radius: 0.6))
                    for limb in limbs {
                        let a = CGPoint(x: limb.a.x * w, y: limb.a.y * h)
                        let b = CGPoint(x: limb.b.x * w, y: limb.b.y * h)
                        layer.fill(taperedLimb(from: a, to: b,
                                               w0: CGFloat(limb.w0) * scale,
                                               w1: CGFloat(limb.w1) * scale),
                                   with: .color(bark))
                        // Round off the joints.
                        layer.fill(disc(b.x, b.y, CGFloat(limb.w1) * scale * 0.5),
                                   with: .color(bark))
                    }
                }

                // Buds: thin stem + glossy deep-pink droplet.
                for bud in buds {
                    let from = CGPoint(x: bud.stemFrom.x * w, y: bud.stemFrom.y * h)
                    let at = CGPoint(x: CGFloat(bud.x) * w, y: CGFloat(bud.y) * h)
                    var stem = Path()
                    stem.move(to: from)
                    stem.addLine(to: at)
                    scene.stroke(stem, with: .color(Color(red: 0.30, green: 0.14, blue: 0.17)),
                                 style: StrokeStyle(lineWidth: max(1, scale * 0.006), lineCap: .round))
                    let r = CGFloat(bud.r) * scale
                    scene.fill(disc(at.x, at.y, r), with: .radialGradient(
                        Gradient(colors: [Color(red: 0.98, green: 0.55, blue: 0.70),
                                          Color(red: 0.80, green: 0.20, blue: 0.42)]),
                        center: CGPoint(x: at.x - r * 0.3, y: at.y - r * 0.3),
                        startRadius: 0, endRadius: r * 1.4))
                }

                // Burgundy leaves, each fluttering on its own phase.
                for leaf in leaves {
                    var l = scene
                    let flutter = 0.08 * sin(t * 0.9 + leaf.flutterPhase)
                    l.translateBy(x: CGFloat(leaf.x) * w, y: CGFloat(leaf.y) * h)
                    l.rotate(by: .radians(leaf.angle + flutter))
                    let len = CGFloat(leaf.len) * scale
                    let shape = leafShape(len: len, width: len * 0.34)
                    l.fill(shape, with: .linearGradient(
                        Gradient(colors: [Color(red: 0.46 - 0.06 * leaf.shade,
                                                green: 0.16, blue: 0.14),
                                          Color(red: 0.62 - 0.08 * leaf.shade,
                                                green: 0.28, blue: 0.20)]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: -len)))
                    var vein = Path()
                    vein.move(to: .zero)
                    vein.addLine(to: CGPoint(x: 0, y: -len * 0.9))
                    l.stroke(vein, with: .color(Color(red: 0.28, green: 0.09, blue: 0.09).opacity(0.7)),
                             lineWidth: max(0.5, len * 0.02))
                }

                // 5) The hero blossoms — full detail, with just enough blur that
                // they still sit back as a card background rather than clip art.
                scene.drawLayer { layer in
                    layer.addFilter(.blur(radius: max(0.5, scale * 0.004)))
                    for fl in frontFlowers {
                        drawBlossom(layer,
                                    center: CGPoint(x: CGFloat(fl.x) * w, y: CGFloat(fl.y) * h),
                                    r: CGFloat(fl.r) * scale, rot: fl.rot, shade: fl.shade,
                                    t: t, bobPhase: fl.bobPhase, detail: true)
                    }
                }

                // 6) Foreground fall: petals (and the odd leaf) detach near the
                // canopy band, then sway, spin, and "flip" (x-squash fakes the
                // 3D tumble) on their way down. Drawn outside the sway transform
                // so loose petals move independently of the limb.
                let margin = scale * 0.12
                for bit in fallingBits {
                    let prog = (t * bit.speed + bit.offset).truncatingRemainder(dividingBy: 1)
                    let y0 = CGFloat(bit.y0) * h
                    let y = y0 + CGFloat(prog) * (h + margin - y0)
                    let x = CGFloat(bit.x0) * w
                          + CGFloat(sin(t * bit.sway + bit.swayPhase)) * w * 0.05
                    let fade = min(1, prog * 7) * min(1, (1 - prog) * 5)
                    var p = ctx
                    p.translateBy(x: x, y: y)
                    p.rotate(by: .radians(t * bit.spin + bit.spinPhase))
                    p.scaleBy(x: CGFloat(0.35 + 0.65 * abs(sin(t * bit.flip + bit.spinPhase))), y: 1)
                    let s = CGFloat(bit.size) * scale
                    if bit.isLeaf {
                        p.fill(leafShape(len: s * 1.6, width: s * 0.55),
                               with: .color(Color(red: 0.52, green: 0.20, blue: 0.16).opacity(0.9 * fade)))
                    } else {
                        p.fill(petalShape(len: s, width: s * 0.70),
                               with: .color(midPink(bit.shade).opacity(0.92 * fade)))
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
