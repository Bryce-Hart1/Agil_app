import SwiftUI

// Claude  Date 06/16/2026
// The animated profile-card backgrounds — the premium, coin-only card looks.
// Each kind is drawn entirely in code (Canvas + TimelineView), so there are no
// PNG assets to ship and the motion stays crisp at any card size. This file is
// the single place that knows how an animated background is painted; everything
// else (CardBackgroundView, the Edit/Shop swatches) just hands it an
// `AnimatedCard` and lets it render.







// To add another animated card: add a case to AnimatedCard (in CardStyle.swift),
// give it an `accent`, add a `case` here, and register a CardStyle for it.
struct AnimatedCardBackground: View {
    let kind: AnimatedCard

    var body: some View {
        ZStack {
            switch kind {
            case .shootingStars:         ShootingStarsBackground()
            case .galaxy:                GalaxyBackground()
            case .molten:                MoltenBackground()
            case .cherryBlossom:         CherryBlossomBackground()
            case .thunderstorm:          ThunderstormBackground()
            case .coralReef:             CoralReefBackground()
            case .foundersShootingStars: FoundersShootingStarsBackground()
            case .foundersGalaxy:        FoundersGalaxyBackground()
            case .foundersConstellation: FoundersConstellationBackground()
            case .diamondGem:            GemCardBackground(tier: .diamond)
            case .emeraldGem:            GemCardBackground(tier: .emerald)
            case .legendGem:             GemCardBackground(tier: .legend)
            }
        }
        .overlay(
            LinearGradient(colors: [.black.opacity(0.10), .black.opacity(0.40)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - Gemstone (earned Diamond / Emerald cards)

// Claude  Date 07/23/2026
// The gemstone profile-card background for the achievement-earned Diamond / Emerald
// cards. Reuses the badge GemFacetOverlay full-bleed over the tier's material
// gradient — sized to the card's diagonal so the triangular facets cover the
// corners — with a slow diagonal gloss sweeping across so the cut-gem surface feels
// alive. The dark scrim applied by AnimatedCardBackground keeps white text legible.
struct GemCardBackground: View {
    let tier: BadgeTier

    var body: some View {
        GeometryReader { geo in
            let diag = hypot(geo.size.width, geo.size.height)
            ZStack {
                Rectangle().fill(tier.fillGradient)
                GemFacetOverlay(diameter: diag, sides: 14, highlight: tier.glimmerColor)
                    .frame(width: diag, height: diag)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                GemCardGloss(size: geo.size, highlight: tier.glimmerColor)
            }
        }
    }
}

// Claude  Date 07/23/2026 
// A soft diagonal highlight that sweeps across the gem card on a slow loop, so the
// faceted surface catches a traveling glint instead of sitting static. plusLighter
// so it reads as light on the gem, not a grey wash; purely decorative (no hits).
private struct GemCardGloss: View {
    let size: CGSize
    // Claude  Date 07/23/2026
    // The sweep glint color — white for diamond/emerald, gold for the Legend card.
    var highlight: Color = .white

    var body: some View {
        let span = hypot(size.width, size.height)
        TimelineView(.animation) { ctx in
            let period = 5.5
            let phase = ctx.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: period) / period      // 0…1
            let x = (phase * 2 - 0.5) * size.width                     // travel edge→edge
            Rectangle()
                .fill(LinearGradient(colors: [.clear, highlight.opacity(0.32), .clear],
                 startPoint: .leading, endPoint: .trailing))
                .frame(width: size.width * 0.34, height: span)
                .rotationEffect(.degrees(18))
                .position(x: x, y: size.height / 2)
                .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
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

    // The drifting color clouds: base position (unit), color, size, drift.
    private let clouds: [Cloud] = [
        Cloud(x: 0.25, y: 0.30, color: Color(red: 0.55, green: 0.20, blue: 0.85),
         size: 0.95, phase: 0.0, speed: 0.18),
        Cloud(x: 0.78, y: 0.35, color: Color(red: 0.16, green: 0.42, blue: 0.92),
         size: 0.85, phase: 1.7, speed: 0.14),
        Cloud(x: 0.55, y: 0.72, color: Color(red: 0.92, green: 0.22, blue: 0.62),
         size: 0.80, phase: 3.1, speed: 0.20),
        Cloud(x: 0.18, y: 0.78, color: Color(red: 0.10, green: 0.70, blue: 0.72),
         size: 0.70, phase: 4.4, speed: 0.16),
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

    // Bryce (Claude) 07/13/2026 last changed: 07/23/2026 by: Claude
    // Three plum pools that drift very slowly on two frequencies each (a slow
    // base sway plus a smaller faster wobble) — visible depth without noise.
    private let haze: [Haze] = [
        Haze(x: 0.30, y: 0.35, color: Color(red: 0.45, green: 0.08, blue: 0.28), size: 0.95, phase: 0.0, speed: 0.05, phase2: 1.3, speed2: 0.11),
        Haze(x: 0.78, y: 0.70, color: Color(red: 0.36, green: 0.06, blue: 0.17), size: 0.85, phase: 2.6, speed: 0.04, phase2: 0.7, speed2: 0.09),
        Haze(x: 0.55, y: 0.20, color: Color(red: 0.40, green: 0.10, blue: 0.30), size: 0.70, phase: 4.1, speed: 0.06, phase2: 2.2, speed2: 0.13),
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

    // Bryce (Claude) Date 07/23/2026
    // The mapped centre of the "A" figure (mean of the anchor points) — used to
    // pool the figure aura and to aim the grazing meteor at the letter.
    private func figureCentroid(size: CGSize) -> CGPoint {
        var sx: CGFloat = 0, sy: CGFloat = 0
        for a in anchors { let p = anchorPoint(a, size: size); sx += p.x; sy += p.y }
        let n = CGFloat(anchors.count)
        return CGPoint(x: sx / n, y: sy / n)
    }

    // Bryce (Claude) Date 07/23/2026
    // Pull a segment's two endpoints back by `gap` at each end — the chart-style
    // gap the atlas lines leave short of each star. Shared by the line glow and
    // the crisp line so both trim identically.
    private func trimmedEnds(_ a: CGPoint, _ b: CGPoint, gap: CGFloat) -> (CGPoint, CGPoint) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        let ux = dx / len, uy = dy / len
        return (CGPoint(x: a.x + ux * gap, y: a.y + uy * gap),
                CGPoint(x: b.x - ux * gap, y: b.y - uy * gap))
    }

    // Bryce (Claude) 07/13/2026 last changed: 07/23/2026 by: Claude
    // Layers, back to front. Added since the shine was removed: a pink aura
    // pooled behind the "A" (drawFigureAura), a bead of light tracing the figure
    // (drawLinkPulse), and a meteor aimed to graze the letter (drawGrazingMeteor).
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawBase(ctx, size: size)
                drawHaze(ctx, size: size, t: t)
                drawFigureAura(ctx, size: size, t: t)
                drawStars(ctx, size: size, t: t)
                drawLinks(ctx, size: size, t: t)
                drawLinkPulse(ctx, size: size, t: t)
                drawAnchors(ctx, size: size, t: t)
                drawMeteors(ctx, size: size, t: t)
                drawGrazingMeteor(ctx, size: size, t: t)
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

    // Bryce (Claude) 07/13/2026 last changed: 07/23/2026 by: Claude
    // The plum pools, blurred to a faint glow behind everything. Each drifts on
    // two frequencies (slow base sway + a smaller faster wobble) and is a touch
    // brighter (0.22 vs 0.16) so the depth actually reads under the global dark
    // scrim — still quiet, but no longer nearly invisible.
    private func drawHaze(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: min(w, h) * 0.18))
            for p in haze {
                let dx = CGFloat(sin(t * p.speed + p.phase)) * w * 0.05
                       + CGFloat(sin(t * p.speed2 + p.phase2)) * w * 0.02
                let dy = CGFloat(cos(t * p.speed * 0.8 + p.phase)) * h * 0.04
                       + CGFloat(cos(t * p.speed2 * 1.1 + p.phase2)) * h * 0.018
                let d = min(w, h) * CGFloat(p.size)
                layer.fill(Path(ellipseIn: CGRect(x: CGFloat(p.x) * w - d / 2 + dx,
                                                  y: CGFloat(p.y) * h - d / 2 + dy,
                                                  width: d, height: d)),
                           with: .color(p.color.opacity(0.22)))
            }
        }
    }

    // Bryce (Claude) Date 07/23/2026
    // A soft pink glow pooled behind the "A" so the eye lands on the figure —
    // the same blurred radial-gradient treatment as the anchor halos and the
    // Galaxy core, kept low and slowly breathing so it reads as light, not a
    // spotlight.
    private func drawFigureAura(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let c = figureCentroid(size: size)
        let scale = min(size.width, size.height)
        let breathe = 0.10 + 0.03 * sin(t * 0.5)
        let auraR = scale * 0.55
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: auraR * 0.5))
            layer.fill(
                Path(ellipseIn: CGRect(x: c.x - auraR, y: c.y - auraR,
                                       width: auraR * 2, height: auraR * 2)),
                with: .radialGradient(
                    Gradient(colors: [pink.opacity(breathe),
                                      pink.opacity(breathe * 0.35),
                                      .clear]),
                    center: c, startRadius: 0, endRadius: auraR))
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

    // Bryce (Claude) 07/13/2026 last changed: 07/23/2026 by: Claude
    // The sky-atlas strokes: pink lines joining the anchors, each end pulled
    // back short of its star (charts leave that gap), breathing slowly. Now each
    // line rides on a wider blurred under-glow, and the crisp stroke carries a
    // gradient (brighter mid, dimmer at the gaps), so the "A" reads as the lit
    // hero of the sky rather than a printed hairline.
    private func drawLinks(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let breathe = 0.30 + 0.08 * sin(t * 0.30)
        let gap: CGFloat = min(size.width, size.height) * 0.025

        // Soft wide under-glow behind every line.
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: min(size.width, size.height) * 0.02))
            for (i, j) in links {
                let (p0, p1) = trimmedEnds(anchorPoint(anchors[i], size: size),
                                           anchorPoint(anchors[j], size: size), gap: gap)
                var line = Path(); line.move(to: p0); line.addLine(to: p1)
                layer.stroke(line, with: .color(pink.opacity(breathe * 0.5)),
                             style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            }
        }

        // Crisp top line with a bright-middle gradient.
        for (i, j) in links {
            let (p0, p1) = trimmedEnds(anchorPoint(anchors[i], size: size),
                                       anchorPoint(anchors[j], size: size), gap: gap)
            var line = Path(); line.move(to: p0); line.addLine(to: p1)
            ctx.stroke(line, with: .linearGradient(
                Gradient(colors: [pink.opacity(breathe * 0.6),
                                  pink.opacity(breathe),
                                  pink.opacity(breathe * 0.6)]),
                startPoint: p0, endPoint: p1),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
    }

    // Bryce (Claude) Date 07/23/2026
    // The signature move: a bead of light traces the "A" as if the chart is
    // being drawn in the sky. It walks an ordered path over the real
    // constellation edges (up the left leg to the apex, down the right leg, then
    // back across the crossbar), mapped by arc length so it moves at a steady
    // pace, and fades in and out each cycle so the loop never snaps.
    private func drawLinkPulse(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        // Ordered anchor indices; every consecutive pair is a real link.
        let route = [3, 1, 0, 2, 4, 2, 1]
        let pts = route.map { anchorPoint(anchors[$0], size: size) }
        guard pts.count > 1 else { return }

        var segLen = [CGFloat](); var total: CGFloat = 0
        for k in 0..<(pts.count - 1) {
            let dx = pts[k + 1].x - pts[k].x, dy = pts[k + 1].y - pts[k].y
            let d = sqrt(dx * dx + dy * dy)
            segLen.append(d); total += d
        }
        guard total > 0 else { return }

        let period = 4.5
        let prog = (t / period).truncatingRemainder(dividingBy: 1)
        let env = sin(prog * .pi)            // 0 at the ends, 1 mid-cycle
        guard env > 0.02 else { return }

        // Walk the polyline to the point at arc-length `target`.
        var target = CGFloat(prog) * total
        var head = pts[0]
        for k in 0..<segLen.count {
            if target <= segLen[k] || k == segLen.count - 1 {
                let f = segLen[k] > 0 ? target / segLen[k] : 0
                head = CGPoint(x: pts[k].x + (pts[k + 1].x - pts[k].x) * f,
                               y: pts[k].y + (pts[k + 1].y - pts[k].y) * f)
                break
            }
            target -= segLen[k]
        }

        // Blurred glow head + a small bright core, so it reads as light.
        let glowR = min(size.width, size.height) * 0.05
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: glowR * 0.7))
            layer.fill(Path(ellipseIn: CGRect(x: head.x - glowR, y: head.y - glowR,
                                              width: glowR * 2, height: glowR * 2)),
                       with: .color(pink.opacity(0.55 * CGFloat(env))))
        }
        let coreR = min(size.width, size.height) * 0.012
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - coreR, y: head.y - coreR,
                                        width: coreR * 2, height: coreR * 2)),
                 with: .color(Color(red: 1.0, green: 0.9, blue: 0.95).opacity(env)))
    }

    // Bryce (Claude) 07/13/2026 last changed: 07/23/2026 by: Claude
    // The figure's stars: larger and warmer than the field, each on its own slow
    // twinkle. Now two-layer — a soft wide halo plus a tighter bright inner glow
    // (the Galaxy-core look) — and at each twinkle peak the star throws a 4-point
    // sparkle cross, the premium flourish the card was missing.
    private func drawAnchors(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        for a in anchors {
            let p = anchorPoint(a, size: size)
            let tw = 0.70 + 0.30 * (0.5 + 0.5 * sin(t * a.speed + a.phase))
            let r = CGFloat(a.radius)

            // Soft outer halo.
            let haloR = r * 4.5
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: haloR * 0.55))
                layer.fill(Path(ellipseIn: CGRect(x: p.x - haloR, y: p.y - haloR,
                                                  width: haloR * 2, height: haloR * 2)),
                           with: .color(pink.opacity(0.28 * tw)))
            }
            // Tighter, brighter inner glow.
            let innerR = r * 2.0
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: innerR * 0.5))
                layer.fill(Path(ellipseIn: CGRect(x: p.x - innerR, y: p.y - innerR,
                                                  width: innerR * 2, height: innerR * 2)),
                           with: .color(Color(red: 1.0, green: 0.78, blue: 0.88).opacity(0.5 * tw)))
            }
            // Warm-white core.
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                     with: .color(Color(red: 1.0, green: 0.82, blue: 0.90).opacity(tw)))

            // Sparkle cross — flares up only near the twinkle peak, then fades.
            let peak = max(0, (tw - 0.85) / 0.15)   // 0 until near peak, →1 at peak
            if peak > 0.01 {
                let armLen = r * (2.2 + 3.0 * CGFloat(peak))
                let armColor = Color(red: 1.0, green: 0.9, blue: 0.95).opacity(0.8 * peak)
                var cross = Path()
                cross.move(to: CGPoint(x: p.x - armLen, y: p.y)); cross.addLine(to: CGPoint(x: p.x + armLen, y: p.y))
                cross.move(to: CGPoint(x: p.x, y: p.y - armLen)); cross.addLine(to: CGPoint(x: p.x, y: p.y + armLen))
                ctx.stroke(cross, with: .color(armColor),
                           style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
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

    // Bryce (Claude) Date 07/23/2026
    // One meteor aimed at the figure: its path is built at draw time to cross
    // the "A" centroid at mid-streak, so every so often a streak visibly grazes
    // the letter. Same streak look as the ambient meteors, on its own long
    // period so the sky still stays mostly quiet.
    private func drawGrazingMeteor(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let period = 11.0, activeFraction = 0.13, offset = 3.5
        let local = ((t + offset) / period).truncatingRemainder(dividingBy: 1)
        guard local < activeFraction else { return }
        let p = CGFloat(local / activeFraction)

        let c = figureCentroid(size: size)
        let angle = 0.62
        let dir = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
        let span = (size.width + size.height) * 0.75
        let length: CGFloat = min(size.width, size.height) * 0.7
        // Head crosses the centroid at p = 0.5.
        let head = CGPoint(x: c.x + dir.x * (p - 0.5) * span,
                           y: c.y + dir.y * (p - 0.5) * span)
        let tail = CGPoint(x: head.x - dir.x * length, y: head.y - dir.y * length)
        let fade = CGFloat(sin(Double(p) * .pi))
        let streak = Color(red: 1.0, green: 0.88, blue: 0.93)
        var trail = Path(); trail.move(to: head); trail.addLine(to: tail)
        ctx.stroke(trail, with: .linearGradient(
            Gradient(colors: [streak.opacity(0.9 * fade), .clear]),
            startPoint: head, endPoint: tail),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        let hr: CGFloat = 1.4
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - hr, y: head.y - hr, width: hr * 2, height: hr * 2)),
                 with: .color(streak.opacity(fade)))
    }

    private struct Star { let x, y, radius, phase, speed: Double }
    private struct Anchor { let x, y, radius, phase, speed: Double }
    // Bryce (Claude) 07/13/2026 last changed: 07/23/2026 by: Claude
    // phase2/speed2 drive each pool's second (faster) drift frequency.
    private struct Haze { let x, y: Double; let color: Color; let size, phase, speed, phase2, speed2: Double }
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

// MARK: - Thunderstorm

// Claude  Date 08/24/2026
// "Thunderstorm": the view from *inside* the storm cloud rather than under it.
// A bank of slow-drifting violet cloud puffs fills the frame, lit from within by
// in-cloud flashes that bloom and stutter behind the vapour, with a few small,
// distant bolts breaking through high up. Deliberately no full-canvas white
// flash and no near strike — every light source is buried in the cloud, so the
// card glows and flickers instead of strobing. Each flash and bolt runs on its
// own loop and only fires during a slice of it (the Shooting Stars meteor
// trick), so nothing ever pulses in lockstep.
private struct ThunderstormBackground: View {
    // The cloud bank: lighter violet through the middle (the lit vapour you're
    // sitting inside), heavy near-black masses below to give the frame a floor.
    private let puffs: [Puff] = [
        Puff(x: 0.20, y: 0.28, size: 1.05, color: Color(red: 0.30, green: 0.26, blue: 0.44),
             phase: 0.0, speed: 0.10),
        Puff(x: 0.72, y: 0.22, size: 0.95, color: Color(red: 0.24, green: 0.21, blue: 0.38),
             phase: 1.9, speed: 0.08),
        Puff(x: 0.48, y: 0.52, size: 1.15, color: Color(red: 0.35, green: 0.30, blue: 0.50),
             phase: 3.3, speed: 0.12),
        Puff(x: 0.12, y: 0.72, size: 0.90, color: Color(red: 0.14, green: 0.12, blue: 0.22),
             phase: 4.7, speed: 0.09),
        Puff(x: 0.85, y: 0.78, size: 1.00, color: Color(red: 0.12, green: 0.11, blue: 0.20),
             phase: 2.4, speed: 0.11),
        Puff(x: 0.55, y: 0.92, size: 0.85, color: Color(red: 0.07, green: 0.06, blue: 0.13),
             phase: 5.6, speed: 0.07),
    ]

    // Lightning buried in the cloud — each one is just a soft radial bloom that
    // lights the vapour around it. Heavily blurred, so you read the glow and
    // never the shape.
    //
    // Claude  Date 08/24/2026
    // Pushed harder (Bryce, 8/24/26 — "make the lightning a little more prominent"):
    // six cells instead of five, larger radii so a flash washes further across the
    // cloud, and shorter periods so the sky is rarely fully dark. Brightness comes
    // from spread and frequency rather than a full-canvas flash, which is what keeps
    // it reading as in-cloud instead of overhead.
    private let glows: [Glow] = {
        var rng = SeededGenerator(seed: 211)
        return (0..<6).map { _ in
            Glow(x: .random(in: 0.10...0.90, using: &rng),
                 y: .random(in: 0.16...0.64, using: &rng),
                 radius: .random(in: 0.52...0.98, using: &rng),
                 strength: .random(in: 0.72...1.0, using: &rng),
                 period: .random(in: 2.8...6.0, using: &rng),
                 offset: .random(in: 0...6.0, using: &rng),
                 activeFraction: .random(in: 0.12...0.24, using: &rng),
                 flicker: .random(in: 5...11, using: &rng),
                 phase: .random(in: 0...(2 * .pi), using: &rng))
        }
    }()

    // The bolts that actually show. Seeded once into unit-space polylines so a given
    // card always throws the same shapes; still kept high in the frame and veiled by
    // the halo pass so they read as far off through the murk — six of them now, firing
    // roughly twice as often as the first pass (Bryce, 8/24/26). Prominence comes from
    // count and cadence, not from bringing them closer.
    private let bolts: [Bolt] = {
        var rng = SeededGenerator(seed: 283)
        return (0..<6).map { _ in
            let startX = Double.random(in: 0.14...0.86, using: &rng)
            let startY = Double.random(in: 0.05...0.26, using: &rng)
            let length = Double.random(in: 0.22...0.40, using: &rng)
            let segments = Int.random(in: 6...9, using: &rng)

            // Main channel: walks straight down, jittering side to side.
            var x = startX
            var points: [CGPoint] = []
            for i in 0...segments {
                let f = Double(i) / Double(segments)
                x += Double.random(in: -0.035...0.035, using: &rng)
                points.append(CGPoint(x: x, y: startY + length * f))
            }

            // One or two short forks off a middle joint, so the bolt branches
            // like the real thing instead of reading as a scratch.
            var branches: [[CGPoint]] = []
            for _ in 0..<Int.random(in: 1...2, using: &rng) {
                let joint = Int.random(in: 2...(segments - 2), using: &rng)
                let dir: Double = Bool.random(using: &rng) ? 1 : -1
                var bx = Double(points[joint].x)
                var by = Double(points[joint].y)
                var fork: [CGPoint] = [points[joint]]
                for _ in 0..<Int.random(in: 2...4, using: &rng) {
                    bx += dir * Double.random(in: 0.012...0.032, using: &rng)
                    by += Double.random(in: 0.018...0.040, using: &rng)
                    fork.append(CGPoint(x: bx, y: by))
                }
                branches.append(fork)
            }

            return Bolt(points: points, branches: branches,
                        width: .random(in: 1.3...2.2, using: &rng),
                        period: .random(in: 4.2...7.5, using: &rng),
                        offset: .random(in: 0...7.5, using: &rng),
                        activeFraction: .random(in: 0.050...0.080, using: &rng),
                        flicker: .random(in: 7...13, using: &rng),
                        phase: .random(in: 0...(2 * .pi), using: &rng))
        }
    }()

    // A thin veil of rain drawn over everything — present, but faint enough that
    // the cloud stays the subject.
    private let rain: [Drop] = {
        var rng = SeededGenerator(seed: 419)
        return (0..<90).map { _ in
            Drop(x: .random(in: -0.10...1.10, using: &rng),
                 speed: .random(in: 0.55...1.15, using: &rng),
                 offset: .random(in: 0...1, using: &rng),
                 length: .random(in: 0.05...0.12, using: &rng),
                 width: .random(in: 0.5...1.1, using: &rng),
                 alpha: .random(in: 0.05...0.16, using: &rng))
        }
    }()

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let rect = CGRect(origin: .zero, size: size)
                let minDim = min(w, h)

                // Storm base: bruised violet up top falling away to near-black.
                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.13, green: 0.11, blue: 0.22),
                                      Color(red: 0.08, green: 0.07, blue: 0.15),
                                      Color(red: 0.04, green: 0.03, blue: 0.08)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

                // The cloud bank, drifting on slow sine paths. Blurred as one
                // layer so the puffs melt together into vapour.
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: minDim * 0.22))
                    for p in puffs {
                        let dx = CGFloat(sin(t * p.speed + p.phase)) * w * 0.06
                        let dy = CGFloat(cos(t * p.speed * 0.7 + p.phase)) * h * 0.03
                        let d = minDim * p.size
                        let r = CGRect(x: p.x * w - d / 2 + dx,
                                       y: p.y * h - d / 2 + dy,
                                       width: d, height: d * 0.78)
                        layer.fill(Path(ellipseIn: r), with: .color(p.color.opacity(0.62)))
                    }
                }

                // In-cloud lightning: soft blooms lighting the vapour from behind.
                // plusLighter so they add light to the cloud rather than paint a
                // grey disc over it.
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: minDim * 0.14))
                    layer.blendMode = .plusLighter
                    for g in glows {
                        let local = ((t + g.offset) / g.period).truncatingRemainder(dividingBy: 1)
                        guard local < g.activeFraction else { continue }
                        let i = pulse(local / g.activeFraction, flicker: g.flicker, phase: g.phase)
                        guard i > 0.001 else { continue }
                        let amp = i * g.strength
                        let cx = g.x * w, cy = g.y * h
                        let rad = minDim * g.radius
                        layer.fill(
                            Path(ellipseIn: CGRect(x: cx - rad, y: cy - rad * 0.82,
                                                   width: rad * 2, height: rad * 1.64)),
                            with: .radialGradient(
                                Gradient(colors: [Color(red: 0.88, green: 0.85, blue: 1.0).opacity(0.66 * amp),
                                                  Color(red: 0.56, green: 0.48, blue: 0.90).opacity(0.30 * amp),
                                                  .clear]),
                                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: rad))
                    }
                }

                // Distant bolts. Drawn twice: a wide blurred halo so the channel
                // looks like it's glowing *through* cloud, then a thin core on
                // top. Both stay dim — nothing here is meant to be close.
                for b in bolts {
                    let local = ((t + b.offset) / b.period).truncatingRemainder(dividingBy: 1)
                    guard local < b.activeFraction else { continue }
                    let i = pulse(local / b.activeFraction, flicker: b.flicker, phase: b.phase)
                    guard i > 0.001 else { continue }

                    var channel = Path()
                    channel.addLines(b.points.map { CGPoint(x: $0.x * w, y: $0.y * h) })
                    var forks = Path()
                    for f in b.branches {
                        forks.addLines(f.map { CGPoint(x: $0.x * w, y: $0.y * h) })
                    }

                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: minDim * 0.040))
                        layer.blendMode = .plusLighter
                        layer.stroke(channel,
                                     with: .color(Color(red: 0.70, green: 0.63, blue: 0.98).opacity(0.78 * i)),
                                     style: StrokeStyle(lineWidth: b.width * 6.5, lineCap: .round, lineJoin: .round))
                        layer.stroke(forks,
                                     with: .color(Color(red: 0.70, green: 0.63, blue: 0.98).opacity(0.52 * i)),
                                     style: StrokeStyle(lineWidth: b.width * 4.0, lineCap: .round, lineJoin: .round))
                    }
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: 0.7))
                        layer.blendMode = .plusLighter
                        layer.stroke(channel,
                                     with: .color(Color(red: 0.96, green: 0.95, blue: 1.0).opacity(0.95 * i)),
                                     style: StrokeStyle(lineWidth: b.width, lineCap: .round, lineJoin: .round))
                        layer.stroke(forks,
                                     with: .color(Color(red: 0.96, green: 0.95, blue: 1.0).opacity(0.68 * i)),
                                     style: StrokeStyle(lineWidth: b.width * 0.70, lineCap: .round, lineJoin: .round))
                    }
                }

                // Rain veil, falling on a loop and slanting slightly with the drift.
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 0.4))
                    for d in rain {
                        let prog = (t * d.speed + d.offset).truncatingRemainder(dividingBy: 1)
                        let len = CGFloat(d.length) * h
                        let headY = CGFloat(prog) * (h + len) - len
                        let headX = CGFloat(d.x) * w + CGFloat(sin(t * 0.2 + d.offset * 6)) * w * 0.01
                        var streak = Path()
                        streak.move(to: CGPoint(x: headX, y: headY))
                        streak.addLine(to: CGPoint(x: headX - len * 0.26, y: headY - len))
                        layer.stroke(streak,
                                     with: .color(Color(red: 0.80, green: 0.78, blue: 0.95).opacity(d.alpha)),
                                     style: StrokeStyle(lineWidth: CGFloat(d.width), lineCap: .round))
                    }
                }
            }
        }
        .drawingGroup()   // composite the canvas on the GPU
    }

    // Claude  Date 08/24/2026
    // The brightness curve for one strike, over its 0…1 active slice. Real
    // lightning snaps on and then gutters out in steps, so this is a fast attack
    // into a squared-off decay with a stutter riding on top — never a clean fade,
    // per the "don't let a loop feel exact" rule.
    private func pulse(_ p: Double, flicker: Double, phase: Double) -> Double {
        let attack = 0.10
        let envelope = p < attack ? p / attack : pow(1 - (p - attack) / (1 - attack), 2.2)
        let stutter = 0.62 + 0.38 * sin(p * .pi * flicker + phase)
        return max(0, envelope * stutter)
    }

    private struct Puff { let x, y, size: Double; let color: Color; let phase, speed: Double }
    private struct Glow { let x, y, radius, strength, period, offset, activeFraction, flicker, phase: Double }
    private struct Bolt {
        let points: [CGPoint]
        let branches: [[CGPoint]]
        let width, period, offset, activeFraction, flicker, phase: Double
    }
    private struct Drop { let x, speed, offset, length, width, alpha: Double }
}

// MARK: - Coral Reef

// CLAUDE  Date 09/17/2026
// "Coral Reef", pared back to sit behind the card like a background (Bryce, 9/17/26):
// open water, still light shafts, a low hazy reef silhouette, and a few bubbles rising
// slowly — the only motion. The still scene paints once; only the bubbles repaint.
private struct CoralReefBackground: View {
    // CLAUDE  Date 09/17/2026
    // Reduce Motion freezes the bubbles at a fixed t — a clean still frame, not a
    // disabled card. Nonzero so a few bubbles are caught mid-rise.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let stillT: Double = 8.0

    // Hand-placed: evenly random shafts read as an accident, not light through a surface.
    private let shafts: [Shaft] = [
        Shaft(x: 0.20, width: 0.12, length: 0.80, tilt:  0.12),
        Shaft(x: 0.54, width: 0.15, length: 0.90, tilt: -0.04),
        Shaft(x: 0.84, width: 0.10, length: 0.68, tilt: -0.14),
    ]

    // CLAUDE  Date 09/17/2026
    // The reef as silhouette, not a catalogue of species: staghorn heads and brain-coral
    // domes in two ranks along the bottom edge. `size` is × the card's shorter side.
    private let heads: [ReefHead] = [
        ReefHead(x: 0.09, size: 0.58, branching: true,  near: false),
        ReefHead(x: 0.37, size: 0.22, branching: false, near: false),
        ReefHead(x: 0.66, size: 0.17, branching: false, near: false),
        ReefHead(x: 0.79, size: 0.52, branching: true,  near: false),
        ReefHead(x: 0.24, size: 0.78, branching: true,  near: true),
        ReefHead(x: 0.56, size: 0.22, branching: false, near: true),
        ReefHead(x: 0.94, size: 0.68, branching: true,  near: true),
    ]

    // Arm fan shared by every staghorn head: angle from +x (radians), length × size.
    private static let arms: [(angle: Double, length: Double)] = [
        (0.70, 0.13), (1.10, 0.19), (1.57, 0.22), (2.04, 0.18), (2.44, 0.12),
    ]

    // CLAUDE  Date 09/17/2026
    // Nine bubbles, seeded once. Each rests hidden between trips (period = rise + rest),
    // so only ~6 are on screen at a time. A trip takes 13–27s bottom to top; the far
    // third are smaller and slower, which is what places them deeper in the water.
    private let bubbles: [Bubble] = {
        var rng = SeededGenerator(seed: 619)
        return (0..<9).map { i in
            let far = i % 3 == 0
            let rise = far ? Double.random(in: 20...27, using: &rng)
                           : Double.random(in: 13...19, using: &rng)
            let rest = Double.random(in: 5...14, using: &rng)
            return Bubble(x: .random(in: 0.12...0.88, using: &rng),
                          rise: rise, rest: rest,
                          offset: .random(in: 0...(rise + rest), using: &rng),
                          radius: far ? .random(in: 2.0...3.2, using: &rng)
                                      : .random(in: 4.0...7.0, using: &rng),
                          wobble: .random(in: 0.006...0.014, using: &rng),
                          wobbleSpeed: .random(in: 0.8...1.5, using: &rng),
                          phase: .random(in: 0...(2 * .pi), using: &rng),
                          far: far)
        }
    }()

    // CLAUDE  Date 09/17/2026
    // Two canvases, each with its own drawingGroup, so the still scene (and its blurs)
    // rasterizes once and each frame only strokes the bubbles. Capped at 30fps: bubbles
    // this slow move ~1pt a frame, so 60/120Hz would repaint for no visible gain.
    var body: some View {
        ZStack {
            Canvas { ctx, size in drawStill(ctx, size: size) }
                .drawingGroup()
            Group {
                if reduceMotion {
                    Canvas { ctx, size in drawBubbles(ctx, size: size, t: Self.stillT) }
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                        Canvas { ctx, size in
                            drawBubbles(ctx, size: size, t: tl.date.timeIntervalSinceReferenceDate)
                        }
                    }
                }
            }
            .drawingGroup()
        }
    }

    private func drawStill(_ ctx: GraphicsContext, size: CGSize) {
        drawWater(ctx, size: size)
        drawShafts(ctx, size: size)
        drawReef(ctx, size: size, near: false)
        drawReef(ctx, size: size, near: true)
    }

    // The water column: tropical cyan at the surface falling to near-black navy at the
    // bed, plus an off-center surface bloom that gives the shafts a believable source.
    private func drawWater(_ ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.04,  green: 0.48,  blue: 0.60), location: 0.00),
                .init(color: Color(red: 0.015, green: 0.27,  blue: 0.48), location: 0.28),
                .init(color: Color(red: 0.010, green: 0.105, blue: 0.27), location: 0.67),
                .init(color: Color(red: 0.004, green: 0.025, blue: 0.085), location: 1.00),
            ]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        let glowCenter = CGPoint(x: size.width * 0.42, y: -size.height * 0.04)
        let glowRadius = max(size.width, size.height) * 0.78
        ctx.fill(Path(rect), with: .radialGradient(
            Gradient(colors: [Color(red: 0.42, green: 0.96, blue: 0.91).opacity(0.26),
                              Color(red: 0.12, green: 0.62, blue: 0.74).opacity(0.07),
                              .clear]),
            center: glowCenter, startRadius: 0, endRadius: glowRadius))
    }

    // CLAUDE  Date 09/17/2026
    // Surface light: tapered quads widening as they sink and fading before the bed, in one
    // blurred layer composited plusLighter so they add light instead of pale wedges.
    private func drawShafts(_ ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let light = Color(red: 0.55, green: 0.98, blue: 0.92)
        var glow = ctx
        glow.blendMode = .plusLighter
        glow.addFilter(.blur(radius: min(w, h) * 0.09))   // on the copy: blurs the layer once
        glow.drawLayer { layer in
            for s in shafts {
                let topX = CGFloat(s.x) * w, topY = -0.02 * h
                let botX = topX + CGFloat(s.tilt) * w, botY = CGFloat(s.length) * h
                let topW = CGFloat(s.width) * w, botW = topW * 2.1

                var beam = Path()
                beam.move(to: CGPoint(x: topX - topW / 2, y: topY))
                beam.addLine(to: CGPoint(x: topX + topW / 2, y: topY))
                beam.addLine(to: CGPoint(x: botX + botW / 2, y: botY))
                beam.addLine(to: CGPoint(x: botX - botW / 2, y: botY))
                beam.closeSubpath()

                layer.fill(beam, with: .linearGradient(
                    Gradient(colors: [light.opacity(0.22), light.opacity(0.07), .clear]),
                    startPoint: CGPoint(x: topX, y: topY), endPoint: CGPoint(x: botX, y: botY)))
            }
        }
    }

    // CLAUDE  Date 09/17/2026
    // One rank of reef. Every shape in the rank shares one opaque shading, so overlapping
    // fills merge into a single seamless silhouette; one blur per rank sells the distance
    // (far = hazy blue, near = near-black with a faint warm cast).
    private func drawReef(_ ctx: GraphicsContext, size: CGSize, near: Bool) {
        let w = size.width, h = size.height
        let minDim = min(w, h)
        let floorY = h * (near ? 0.955 : 0.925)
        let shading: GraphicsContext.Shading
        if near {
            shading = .linearGradient(
                Gradient(colors: [Color(red: 0.11, green: 0.07, blue: 0.13),
                                  Color(red: 0.006, green: 0.025, blue: 0.055)]),
                startPoint: CGPoint(x: 0, y: h * 0.80), endPoint: CGPoint(x: 0, y: h))
        } else {
            shading = .color(Color(red: 0.05, green: 0.22, blue: 0.30))
        }

        var hazy = ctx
        hazy.addFilter(.blur(radius: minDim * (near ? 0.004 : 0.012)))   // once, on the merged rank
        hazy.drawLayer { layer in
            var bed = Path()
            bed.move(to: CGPoint(x: 0, y: floorY + h * 0.012))
            bed.addCurve(to: CGPoint(x: w * 0.45, y: floorY - h * 0.006),
                         control1: CGPoint(x: w * 0.15, y: floorY - h * 0.018),
                         control2: CGPoint(x: w * 0.30, y: floorY + h * 0.012))
            bed.addCurve(to: CGPoint(x: w, y: floorY),
                         control1: CGPoint(x: w * 0.62, y: floorY - h * 0.022),
                         control2: CGPoint(x: w * 0.82, y: floorY + h * 0.014))
            bed.addLine(to: CGPoint(x: w, y: h * 1.05))
            bed.addLine(to: CGPoint(x: 0, y: h * 1.05))
            bed.closeSubpath()
            layer.fill(bed, with: shading)

            for head in heads where head.near == near {
                let base = CGPoint(x: head.x * w, y: floorY + h * 0.02)
                if head.branching {
                    drawStaghorn(layer, base: base, scale: head.size * minDim, shading: shading)
                } else {
                    drawDome(layer, base: base, width: head.size * minDim, shading: shading)
                }
            }
        }
    }

    // Staghorn head as pure silhouette: a short trunk, five forked arms, rounded joints/tips.
    private func drawStaghorn(_ ctx: GraphicsContext, base: CGPoint, scale: CGFloat,
                              shading: GraphicsContext.Shading) {
        let crown = CGPoint(x: base.x, y: base.y - scale * 0.07)
        let armW = scale * 0.034
        ctx.fill(taper(from: base, to: crown, w0: armW * 1.7, w1: armW), with: shading)

        for (i, arm) in Self.arms.enumerated() {
            let length = CGFloat(arm.length) * scale
            let kink = i % 2 == 0 ? 0.22 : -0.22
            let mid = step(from: crown, angle: arm.angle, by: length * 0.55)
            let tip = step(from: mid, angle: arm.angle + kink, by: length * 0.45)
            let fork = step(from: mid, angle: arm.angle - kink * 2.4, by: length * 0.32)
            ctx.fill(taper(from: crown, to: mid, w0: armW, w1: armW * 0.70), with: shading)
            ctx.fill(taper(from: mid, to: tip, w0: armW * 0.70, w1: armW * 0.40), with: shading)
            ctx.fill(taper(from: mid, to: fork, w0: armW * 0.60, w1: armW * 0.36), with: shading)
            for (point, radius) in [(mid, armW * 0.35), (tip, armW * 0.20), (fork, armW * 0.18)] {
                ctx.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: shading)
            }
        }
    }

    // Brain-coral dome as a plain silhouette (v1's grooves were detail the eye had to read).
    private func drawDome(_ ctx: GraphicsContext, base: CGPoint, width: CGFloat,
                          shading: GraphicsContext.Shading) {
        let height = width * 0.46
        var dome = Path()
        dome.move(to: CGPoint(x: base.x - width / 2, y: base.y))
        dome.addCurve(to: CGPoint(x: base.x, y: base.y - height),
                      control1: CGPoint(x: base.x - width * 0.48, y: base.y - height * 0.62),
                      control2: CGPoint(x: base.x - width * 0.24, y: base.y - height))
        dome.addCurve(to: CGPoint(x: base.x + width / 2, y: base.y),
                      control1: CGPoint(x: base.x + width * 0.24, y: base.y - height),
                      control2: CGPoint(x: base.x + width * 0.48, y: base.y - height * 0.62))
        dome.closeSubpath()
        ctx.fill(dome, with: shading)
    }

    // CLAUDE  Date 09/17/2026
    // Bubbles: faint glass body, thin rim, and a crescent highlight — three plain draws
    // each, no blur filter, since this is the layer that repaints every frame. Radii
    // shrink on small frames (shop tiles, the 28pt swatch) so bubbles stay in scale.
    private func drawBubbles(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let unit = CGFloat(min(1, max(0.45, min(size.width, size.height) / 320)))
        let rim = Color(red: 0.62, green: 0.95, blue: 1.0)
        for b in bubbles {
            guard let p = place(b, size: size, t: t, unit: unit) else { continue }
            let rect = CGRect(x: p.x - p.r, y: p.y - p.r, width: p.r * 2, height: p.r * 2)
            let shell = Path(ellipseIn: rect)
            ctx.fill(shell, with: .color(rim.opacity(0.10 * p.alpha)))
            ctx.stroke(shell, with: .color(rim.opacity((b.far ? 0.40 : 0.62) * p.alpha)),
                       lineWidth: b.far ? 0.7 : max(0.9, p.r * 0.14))

            var shine = Path()
            shine.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: p.r * 0.62,
                         startAngle: .degrees(195), endAngle: .degrees(260), clockwise: false)
            ctx.stroke(shine, with: .color(.white.opacity((b.far ? 0.50 : 0.85) * p.alpha)),
                       style: StrokeStyle(lineWidth: b.far ? 0.5 : max(0.7, p.r * 0.12),
                                          lineCap: .round))
        }
    }

    // CLAUDE  Date 09/17/2026
    // Where a bubble is at time t, or nil while it rests between trips. Each trip starts
    // from a new x (a hash of the trip number) so the loop never shows; it wobbles on two
    // summed sines, swells slightly as it rises, and fades in/out at the ends.
    private func place(_ b: Bubble, size: CGSize, t: Double,
                       unit: CGFloat) -> (x: CGFloat, y: CGFloat, r: CGFloat, alpha: Double)? {
        let period = b.rise + b.rest
        let clock = t + b.offset
        let local = clock.truncatingRemainder(dividingBy: period)
        guard local < b.rise else { return nil }
        let progress = local / b.rise                       // 0 at the bed → 1 past the top

        let hash = sin((clock / period).rounded(.down) * 12.9898 + b.phase) * 43758.5453
        let shift = (hash - hash.rounded(.down) - 0.5) * 0.20
        let wobble = b.wobble * (sin(t * b.wobbleSpeed + b.phase)
                                 + 0.4 * sin(t * b.wobbleSpeed * 0.43 + b.phase * 1.7))
        let r = CGFloat(b.radius) * unit * CGFloat(0.85 + 0.30 * progress)
        return (CGFloat(b.x + shift + wobble) * size.width,
                size.height + r - CGFloat(progress) * (size.height + r * 2),
                r,
                min(1, progress / 0.15, (1 - progress) / 0.10))
    }

    private func step(from p: CGPoint, angle: Double, by distance: CGFloat) -> CGPoint {
        CGPoint(x: p.x + CGFloat(cos(angle)) * distance, y: p.y - CGFloat(sin(angle)) * distance)
    }

    // Tapered quad, so trunks and arms thin toward their tips instead of being
    // constant-width strokes. (Cherry Blossom keeps its own copy — private by convention.)
    private func taper(from a: CGPoint, to b: CGPoint, w0: CGFloat, w1: CGFloat) -> Path {
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

    private struct Shaft { let x, width, length, tilt: Double }
    private struct ReefHead { let x, size: Double; let branching, near: Bool }
    private struct Bubble {
        let x, rise, rest, offset, radius, wobble, wobbleSpeed, phase: Double
        let far: Bool
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
