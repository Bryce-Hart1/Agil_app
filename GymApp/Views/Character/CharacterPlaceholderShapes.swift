import SwiftUI

// Claude  Date 08/02/2026 last changed: 08/02/2026 by: Claude
// The code-drawn stand-in art for a character, layer by layer. This is SHIPPING art, not
// scaffolding: it tints from the same colour roles as real artwork, so a character built
// entirely from placeholders is already fully customizable. Bryce replaces it one layer at
// a time by dropping an imageset in (see CharacterOption.assetName) — no code changes, no
// all-or-nothing cutover.
//
// House precedent for drawing rather than shipping PNGs: RankRing ("fully drawn, no art
// assets"), AnimatedCardBackground, GemFacetOverlay.
//
// STYLE: flat fills, no gradients, and deliberately NO outlines — the reference art
// separates shapes by colour contrast alone, and skipping strokes also sidesteps the
// hairline-disappears-at-28pt problem entirely. The one place two same-coloured shapes
// meet (neck against jaw) is separated by shading the neck instead; see .bodyShoulders.
//
// POSE: slight 3/4 turn with the NOSE POINTING RIGHT. That means the face's near side is
// the right, and the back of the skull is the left. Everything below is drawn in a
// normalized 100x100 box (see Canvas100) so geometry scales purely from a 28pt chat row to
// a 120pt editor preview.
//
// (08/02, second pass) Redrawn to read as a PERSON rather than a mask. What changed and
// why, since these are the levers to pull if it needs tuning again:
//   • Jaw softened and the chin rounded — the first version tapered to a point, which is
//     what made it read as a mask more than anything else.
//   • Eyes roughly halved and given a catchlight. Big flat-black ovals read as doll eyes;
//     small almonds with a highlight read as alive.
//   • Brows thinner, lower and gently curved instead of thick and high-arched.
//   • A small smile instead of a flat dash.
//   • Hair given real volume above the skull and a proper hairline that leaves forehead
//     showing, rather than sitting on the head like a bowl.
//   • The visible ear is GONE. Being skin-coloured on top of the back hair, it read as a
//     notch bitten out of the hairline at every size. The reference art has no visible ear
//     either — hair covers it.
//   • Neck narrowed and the collar raised, so less of it shows.
//
// ⚠️ ONE CLOSED SUBPATH PER SHAPE. Claude 08/03/2026
// SwiftUI's `.fill` uses the NON-ZERO winding rule, so where two subpaths of the SAME Path
// overlap while wound in opposite directions, the overlap CANCELS and punches a hole — you
// see the backdrop through the seam between two pieces that were supposed to merge. That is
// exactly what put a notch at the base of every neck and a pale streak down the ponytail,
// and it is invisible until two pieces happen to overlap, so it comes back the moment
// someone nudges a curve. Winding is also not something you can eyeball off these
// coordinates, and `Path.union` is iOS 17+ while this app targets 16.1.
// So: a Shape here draws ONE closed outline. Pieces that merge are separate Shapes stacked
// in a ZStack by the layer renderer, which unions them by painting — order- and
// direction-independent, and correct by construction. (Shapes whose subpaths provably never
// touch — the two eyes, the two lenses — are the one exemption, and are marked as such.)

// Claude  Date 08/02/2026
// Maps the 100x100 design space onto whatever rect the Shape is handed. Keeping every
// coordinate as a plain 0...100 number is what makes the geometry below readable and
// tweakable — nothing in this file deals in points.
struct Canvas100 {
    let rect: CGRect
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x / 100, y: rect.minY + rect.height * y / 100)
    }
    /// Scalar for radii/lengths expressed in design units.
    var u: CGFloat { min(rect.width, rect.height) / 100 }
}

fileprivate extension Path {
    mutating func go(_ x: CGFloat, _ y: CGFloat, _ c: Canvas100) { move(to: c.p(x, y)) }
    mutating func ln(_ x: CGFloat, _ y: CGFloat, _ c: Canvas100) { addLine(to: c.p(x, y)) }
    mutating func cv(_ x: CGFloat, _ y: CGFloat,
                     _ c1x: CGFloat, _ c1y: CGFloat,
                     _ c2x: CGFloat, _ c2y: CGFloat, _ c: Canvas100) {
        addCurve(to: c.p(x, y), control1: c.p(c1x, c1y), control2: c.p(c2x, c2y))
    }
    mutating func qd(_ x: CGFloat, _ y: CGFloat, _ cx: CGFloat, _ cy: CGFloat, _ c: Canvas100) {
        addQuadCurve(to: c.p(x, y), control: c.p(cx, cy))
    }
    /// An ellipse given a centre and radii in design units.
    mutating func oval(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ c: Canvas100) {
        let o = c.p(x - rx, y - ry)
        addEllipse(in: CGRect(x: o.x, y: o.y, width: 2 * rx * c.u, height: 2 * ry * c.u))
    }
}

// MARK: - Head

// Claude  Date 08/02/2026
// The pose-defining layer, and the only one whose silhouette has to be right for the whole
// character to read. Traced clockwise from the crown: forehead down the right, a shallow
// recess at the brow, out over the NOSE, back in under it, then a SOFT jaw sweeping to a
// rounded chin — which sits left of the nose, and that offset is what sells the 3/4 turn —
// then back up the jaw and over the crown.
struct CharacterHeadShape: Shape {
    enum Style { case round, oval, angular }
    var style: Style = .round

    // Per-style dial: overall width/height about the head centre. Angular additionally
    // swaps the jaw curves for straight runs.
    private var widthScale: CGFloat {
        switch style { case .round: return 1.00; case .oval: return 0.93; case .angular: return 1.02 }
    }
    private var heightScale: CGFloat {
        switch style { case .round: return 1.00; case .oval: return 1.06; case .angular: return 0.97 }
    }

    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()

        p.go(48, 12, c)
        p.cv(74.5, 37, 63, 12, 74, 23, c)                  // forehead, down the right
        p.cv(73.8, 45.6, 74.9, 41, 74.4, 43.8, c)          // brow recess into the bridge
        p.cv(76.9, 50.4, 76.0, 46.6, 77.2, 48.4, c)        // out over the nose
        p.cv(72.5, 54.0, 76.6, 52.4, 74.4, 53.6, c)        // back in beneath it

        if style == .angular {
            p.ln(70.3, 60.4, c)                             // squared muzzle
            p.ln(58.6, 71.2, c)                             // straight run to the chin
            p.ln(34.4, 62.4, c)                             // hard jaw back to the hinge
        } else {
            p.cv(70.3, 60.4, 72.1, 56.4, 71.5, 58.4, c)     // upper lip / muzzle
            p.cv(58.6, 71.2, 68.5, 65.4, 64.5, 69.6, c)     // soft jaw into a rounded chin
            p.cv(34.4, 62.4, 50, 72.6, 40.4, 69.2, c)       // jaw back to the hinge
        }

        p.cv(23.2, 39, 29, 56.4, 23.6, 48.4, c)            // up the back of the skull
        p.cv(48, 12, 22.7, 24, 33, 12, c)                  // over the crown
        p.closeSubpath()

        // Scale about the head centre so a style change never shifts the pose.
        let centre = c.p(48, 42)
        let t = CGAffineTransform(translationX: centre.x, y: centre.y)
            .scaledBy(x: widthScale, y: heightScale)
            .translatedBy(x: -centre.x, y: -centre.y)
        return p.applying(t)
    }
}

// MARK: - Body + top

// Claude  Date 08/02/2026 last changed: 08/03/2026 by: Claude
// Neck and shoulders. Drawn in skin, then re-filled with a low black wash by the layer
// renderer — that shade is what separates the neck from the jaw without needing an outline,
// and it's what the reference art does too. The neck tapers slightly inward so it reads as
// a neck rather than a post.
//
// (08/03) Was TWO subpaths — a neck trapezoid and a shoulder hill — wound in opposite
// directions, so the non-zero fill cancelled where they overlapped and cut a notch out of
// the base of the neck. Every top showed it; the tank, whose collar is widest, showed it
// worst. Now ONE outline traced up the left shoulder, up the neck, across under the jaw
// and back down the right — the same silhouette, with nothing left to cancel. See the
// subpath warning at the top of this file.
struct CharacterShouldersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()
        // Shoulders run past the box so the circular clip cuts them cleanly.
        p.go(-6, 112, c)
        p.cv(44.6, 79.5, 0, 92, 26, 80.5, c)          // left shoulder, rising to the neck
        p.cv(45.5, 57, 44.2, 72, 45.2, 64, c)         // up the left side of the neck
        p.ln(55.8, 57, c)                             // across the top, hidden under the jaw
        p.cv(56.6, 79.5, 56.1, 64, 57.0, 72, c)       // down the right side
        p.cv(106, 112, 75, 80.5, 100, 92, c)          // right shoulder, falling away
        p.closeSubpath()
        return p
    }
}

// Claude  Date 08/02/2026
// The shirt: the same shoulder hill sitting slightly ABOVE the skin one (so it covers the
// shoulders completely) with a collar scoop cut around the neck. The scoop is what makes it
// read as clothing rather than as a coloured block — its width and depth are the whole
// difference between a tee, a tank and a hoodie.
struct CharacterTopShape: Shape {
    enum Style { case tee, tank, hoodie }
    var style: Style = .tee

    private var span: CGFloat { style == .tank ? 16 : -6 }        // where the hill starts
    private var crest: CGFloat { style == .hoodie ? 74 : 76 }
    private var collarHalf: CGFloat { style == .tank ? 19 : 11.5 } // scoop half-width
    private var collarDrop: CGFloat { style == .tank ? 95 : (style == .hoodie ? 82 : 85) }

    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()
        let left = 50 - collarHalf, right = 50 + collarHalf

        p.go(span, 112, c)
        p.cv(left, crest, span + 6, 88, left - 14.5, crest - 1, c)     // left shoulder up
        p.qd(right, crest, 50, collarDrop, c)                          // collar scoop
        p.cv(100 - span, 112, right + 14.5, crest - 1, 100 - span, 88, c) // right shoulder down
        p.closeSubpath()
        return p
    }
}

// Claude  Date 08/03/2026
// The hoodie's bunched hood, two masses flanking the neck. Cheap, and unmistakably a
// hoodie. Its own Shape rather than two more subpaths on the tee — the ovals sit on top of
// the shoulder hill, which is precisely the overlap the non-zero fill would cancel; the
// layer renderer stacks it over CharacterTopShape(.hoodie) instead.
struct CharacterHoodShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()
        // Exempt from the one-subpath rule: the two masses are 38 design units apart.
        p.oval(31, 82, 11, 9, c)
        p.oval(69, 82, 11, 9, c)
        return p
    }
}

// MARK: - Hair

// Claude  Date 08/02/2026 last changed: 08/03/2026 by: Claude
// The rim of hair behind the skull (drawn under the body, so a fall tucks behind the
// shoulder). Sits left of and slightly above the head so a rim shows around the back of the
// crown. Every back-hair style has one.
//
// (08/03) Split out of the old CharacterHairBackShape, which drew this oval AND the fall in
// one Path. The two wound oppositely, so the non-zero fill cancelled where the tail crossed
// the rim — that was the pale line down the middle of the ponytail. See the subpath warning
// at the top of this file.
struct CharacterHairRimShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()
        p.oval(46, 37, 27.5, 28.5, c)
        return p
    }
}

// Claude  Date 08/03/2026
// The mass that falls behind the shoulder — the part that distinguishes one back-hair style
// from another. Stacked over CharacterHairRimShape by the layer renderer; `tuck` has no
// fall at all, so it draws nothing and the rim is the whole style.
struct CharacterHairFallShape: Shape {
    enum Style { case tuck, ponytail, long }
    var style: Style = .tuck

    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()

        switch style {
        case .tuck:
            break
        case .ponytail:
            p.go(29, 47, c)                       // tail sweeping back and down-left
            p.cv(14, 83, 20, 59, 13, 69, c)
            p.cv(27.5, 61, 21, 87, 27, 75, c)
            p.closeSubpath()
        case .long:
            p.go(21, 33, c)                       // a full fall down the back
            p.cv(22, 96, 12, 55, 14, 80, c)
            p.cv(48, 88, 34, 100, 46, 96, c)
            p.cv(42, 40, 40, 76, 38, 52, c)
            p.closeSubpath()
        }
        return p
    }
}

// Claude  Date 08/02/2026 last changed: 08/02/2026 by: Claude
// The piece IN FRONT of the skull: the cap, whose lower edge is the hairline. Two things
// matter for it to read as hair at all. The cap must sit ABOVE the head's own crown (the
// head starts at y 12; these start at 5–10.5) or it reads as painted on; and the hairline
// must leave forehead showing, or you get a bowl cut.
//
// (Second pass) The four styles were all the same cap with slightly different edges, which
// is exactly what made them read as generic. Each now owns a DISTINCT SILHOUETTE — the test
// being whether you can tell them apart at 38pt with the colour turned off:
//   crop     — tight to the skull, dropping a small sideburn tab in front of the ear
//   swoop    — lifted volume at the front with a diagonal fringe sweeping down across the
//              brow, the one style that breaks the symmetric-cap outline
//   ponytail — pulled back: tightest cap, hairline high and smooth, no fringe at all
//              (the tail itself lives in CharacterHairBackShape)
//   long     — a curtain falling past the jaw on the near side
struct CharacterHairShape: Shape {
    enum Style { case crop, swoop, ponytail, long }
    var style: Style = .crop

    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()

        switch style {
        case .crop:
            p.go(24, 52, c)                                  // sideburn tab, bottom
            p.cv(21.8, 36, 22.5, 47, 21.5, 42, c)
            p.cv(48, 8.5, 22.6, 20, 33, 8.5, c)              // over the crown, close-cropped
            p.cv(76.2, 37, 64, 8.5, 76, 20, c)
            p.cv(68.6, 27.6, 75, 32, 72.5, 28.6, c)          // hairline, right to left
            p.cv(45.6, 27.4, 61, 25.6, 53, 25.4, c)
            p.cv(28.5, 42, 38, 29.4, 31, 33.5, c)
            p.cv(27.6, 52.5, 28, 45.5, 27.6, 49, c)          // down into the sideburn
            p.cv(24, 52, 26.6, 53.5, 25, 53.5, c)
            p.closeSubpath()

        case .swoop:
            p.go(21.5, 46, c)
            p.cv(48, 5, 19, 24, 29, 5, c)                    // extra lift over the crown
            p.cv(80.5, 41, 68, 5, 81.5, 18, c)               // volume at the front
            p.cv(71.5, 32.5, 79, 34, 76, 30.5, c)
            p.cv(48.5, 36.5, 64, 36, 56, 38.5, c)            // the fringe, sweeping down-left
            p.cv(30, 28.5, 41.5, 34.6, 35.5, 29.5, c)        // and rising back up
            p.cv(22.5, 46, 26, 31, 23.5, 37, c)
            p.closeSubpath()

        case .ponytail:
            // (08/03) The back edge used to cut inside the skull between y 12 and 45,
            // leaving a bare skin sliver behind the hairline that read as a crack in the
            // head. It now runs OUTSIDE CharacterHeadShape's back-of-skull curve the whole
            // way up — the rim behind can't fill that band, because the head is drawn on
            // top of it.
            p.go(23, 45, c)
            p.cv(48, 10.5, 21.5, 26, 27, 9.5, c)             // tightest cap — pulled back
            p.cv(74.2, 35, 63, 10.5, 74.5, 21.5, c)
            p.cv(66, 24.8, 73.4, 29, 70.5, 25.6, c)          // high, smooth hairline, no fringe
            p.cv(43, 25, 58, 23.6, 50, 23.6, c)
            p.cv(26.5, 44, 35, 26.6, 28.5, 31, c)
            p.closeSubpath()

        case .long:
            p.go(18.5, 75, c)                                // curtain, past the jaw
            p.cv(20, 30, 15.5, 56, 16, 40, c)
            p.cv(48, 6.5, 25.5, 15.5, 34, 6.5, c)
            p.cv(78.5, 40, 66, 6.5, 79, 19, c)
            p.cv(69.5, 27, 77, 33, 74, 28, c)
            p.cv(45, 27, 61, 25, 53, 25, c)
            p.cv(27.8, 46, 36, 29, 29.5, 35, c)
            p.cv(29, 75, 27.2, 58, 27.5, 67, c)              // the curtain's inner edge
            p.closeSubpath()
        }
        return p
    }
}

// Claude  Date 08/02/2026 last changed: 08/03/2026 by: Claude
// The jaw/chin mass of a beard, drawn DELIBERATELY OVERSIZE and clipped to the head by the
// layer renderer. That clip is the whole trick, and it replaces the old approach of tracing
// the jaw by hand:
//   • hand-tracing left a hairline of skin outside the beard wherever the two curves
//     disagreed by a fraction of a unit — which is what made the old band read as a chin
//     strap glued on rather than hair growing on a face;
//   • CharacterHeadShape scales itself per style (see widthScale/heightScale), so a
//     hand-traced band fitted the round head and overhung the oval one. Clipping means the
//     beard follows whatever face shape is picked, for free.
// So every coordinate below that runs past the silhouette is intentional; only the UPPER
// edge — the beard line — is real art.
//
// The beard line still dips BENEATH the mouth rather than running through it, even though
// CharacterLayer now draws the face over facial hair: the lips want skin around them, not a
// stroke sitting directly on hair. The z-order is the safety net, not the plan — it is what
// keeps the near corner of an expression legible where CharacterMoustacheShape wraps past
// it.
struct CharacterBeardShape: Shape {
    /// A full beard rides higher on the cheek and carries more mass under the chin.
    var full: Bool = false

    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()
        // The two dials. `rise` is how high the sideburn root starts — it is off the head
        // entirely, and running it that high is what guarantees the beard MEETS the hair
        // instead of leaving a sliver of bare cheek between them. `lip` is the only line a
        // reader actually sees on the back half: the beard line under the cheek.
        let rise: CGFloat = full ? 30 : 41
        let lip: CGFloat  = full ? 64.5 : 66.5

        p.go(14, rise, c)
        p.cv(48, lip, 15, rise + 14, 33, lip + 2, c)      // beard line, down across the cheek
        p.cv(74, 60, 60, lip + 1.5, 69, lip, c)           // under the mouth to the near jaw
        p.cv(56, 90, 82, 76, 72, 90, c)                   // out and around the chin
        p.cv(14, rise + 12, 36, 90, 16, 72, c)            // back up the jaw to the sideburn
        p.closeSubpath()
        return p
    }
}

// Claude  Date 08/03/2026
// The moustache. Its own Shape even though it MERGES with the beard on the near side: as
// one subpath the pair would have to enclose the lips, and an enclosed hole is exactly the
// winding trap this file avoids (see the warning up top). Stacked, they union by painting
// and the bay around the mouth costs nothing. Like the beard it overshoots on the near side
// and is clipped to the head.
struct CharacterMoustacheShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()
        // The philtrum is barely five design units tall — the underside of the nose is at
        // y 54, the mouth stroke starts just under y 59 — so a moustache drawn as a free
        // floating lens in there is necessarily a thin wedge, and a thin wedge reads as a
        // blade stuck on the lip. Instead this JOINS THE BEARD on the near side: it runs
        // down the muzzle until it meets CharacterBeardShape's upper edge at y ≈ 62, which
        // turns the pair into one mass wrapping the mouth, with the lips sitting in a bay
        // that opens toward the far cheek. That is what a full beard actually looks like,
        // and it is the only version of this that survives being 4 units tall.
        p.go(58.5, 57.4, c)
        p.cv(58.5, 55.8, 55.9, 57.0, 55.9, 56.1, c)   // far end, ROUNDED — a point here
                                                      // reads as a blade, not as hair
        p.cv(71.5, 54.6, 62.5, 54.0, 67.5, 53.8, c)   // top edge, stopping UNDER the nose
        p.cv(73.5, 62.5, 74.5, 56.5, 75.0, 60.0, c)   // down the muzzle to meet the beard
        p.cv(58.5, 57.4, 67.0, 59.4, 62.0, 58.0, c)   // back along the lip line
        p.closeSubpath()
        return p
    }
}

// MARK: - Accessories

struct CharacterGlassesShape: Shape {
    var showsBridge: Bool = true

    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()
        let far = CGRect(origin: c.p(47.5, 39.5), size: CGSize(width: 13 * c.u, height: 11 * c.u))
        let near = CGRect(origin: c.p(62.5, 39.5), size: CGSize(width: 13.5 * c.u, height: 11 * c.u))
        p.addRoundedRect(in: far, cornerSize: CGSize(width: 4 * c.u, height: 4 * c.u))
        p.addRoundedRect(in: near, cornerSize: CGSize(width: 4 * c.u, height: 4 * c.u))
        if showsBridge {
            p.go(60.5, 44.5, c)
            p.ln(62.5, 44.5, c)
        }
        return p
    }
}

struct CharacterHeadbandShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = Canvas100(rect: rect)
        var p = Path()
        p.go(22, 38, c)
        p.cv(76.5, 31, 25, 24, 51, 22, c)         // across the forehead, following the skull
        p.cv(75, 40, 76.8, 34, 76, 37, c)
        p.cv(23, 47, 51, 31, 26, 33, c)
        p.closeSubpath()
        return p
    }
}

// MARK: - Layer renderer

// Claude  Date 08/02/2026 last changed: 08/03/2026 by: Claude
// Draws one placeholder layer. Colour is passed in explicitly rather than inherited through
// .foregroundStyle because ShapeStyle.foreground is iOS 17+ and this app targets 16.1.
//
// `showsFineDetail` is the small-size gate, mirroring RankRing.showsOuterDetail: below 36pt
// the brows, mouth, eye catchlights and glasses bridge are dropped. They'd be sub-pixel
// smudges at 28pt, and what a chat row actually needs to read is silhouette + hair + eyes.
//
// (08/03) Several layers are now a ZStack of Shapes rather than one multi-subpath Shape —
// that stacking IS the union, and it is what keeps seams from cancelling into holes. See
// the warning at the top of this file. `headStyle` arrived at the same time, so facial hair
// can be clipped to the face shape the user actually picked.
struct CharacterPlaceholderLayer: View {
    let placeholder: CharacterPlaceholder
    let color: Color
    let ink: Color
    let size: CGFloat
    /// The face shape this character wears, so facial hair can be clipped to it.
    var headStyle: CharacterHeadShape.Style = .round

    private var showsFineDetail: Bool { size >= 36 }
    /// Floor for the few stroked details, following RankRing's `max(0.75, size * …)` idiom.
    private var hairline: CGFloat { max(0.75, size * 0.016) }

    var body: some View {
        switch placeholder {
        case .backdropDisc:
            Circle().fill(color)

        case .bodyShoulders:
            // The black wash is the neck/jaw separation — see CharacterShouldersShape.
            CharacterShouldersShape().fill(color)
                .overlay(CharacterShouldersShape().fill(Color.black.opacity(0.10)))

        case .topTee:    CharacterTopShape(style: .tee).fill(color)
        case .topTank:   CharacterTopShape(style: .tank).fill(color)
        case .topHoodie:
            ZStack {
                CharacterTopShape(style: .hoodie).fill(color)
                CharacterHoodShape().fill(color)
            }

        case .headRound:   CharacterHeadShape(style: .round).fill(color)
        case .headOval:    CharacterHeadShape(style: .oval).fill(color)
        case .headAngular: CharacterHeadShape(style: .angular).fill(color)

        case .hairBackTuck:     CharacterHairRimShape().fill(color)
        case .hairBackPonytail: hairBack(.ponytail)
        case .hairBackLong:     hairBack(.long)

        case .hairCrop:     CharacterHairShape(style: .crop).fill(color)
        case .hairSwoop:    CharacterHairShape(style: .swoop).fill(color)
        case .hairPonytail: CharacterHairShape(style: .ponytail).fill(color)
        case .hairLong:     CharacterHairShape(style: .long).fill(color)

        case .facialHairStubble: facialHair(full: false).opacity(0.5)
        case .facialHairBeard:   facialHair(full: true)

        case .accessoryGlasses:
            CharacterGlassesShape(showsBridge: showsFineDetail)
                .stroke(color, style: StrokeStyle(lineWidth: hairline * 1.5, lineCap: .round))
        case .accessoryHeadband:
            CharacterHeadbandShape().fill(color)

        case .faceNeutral: FaceLayer(expression: .neutral, ink: ink, detail: showsFineDetail, hairline: hairline)
        case .faceSmile:   FaceLayer(expression: .smile,   ink: ink, detail: showsFineDetail, hairline: hairline)
        case .faceFocused: FaceLayer(expression: .focused, ink: ink, detail: showsFineDetail, hairline: hairline)
        }
    }

    /// Rim + fall, stacked. Two Shapes, not two subpaths — see the warning up top.
    private func hairBack(_ style: CharacterHairFallShape.Style) -> some View {
        ZStack {
            CharacterHairRimShape().fill(color)
            CharacterHairFallShape(style: style).fill(color)
        }
    }

    // Claude  Date 08/03/2026
    // Beard + moustache, clipped to the face shape. `.compositingGroup()` is load-bearing
    // for stubble: without it the caller's .opacity(0.5) would be applied to each mass
    // separately and any overlap would double up into a dark patch.
    private func facialHair(full: Bool) -> some View {
        ZStack {
            CharacterBeardShape(full: full).fill(color)
            CharacterMoustacheShape().fill(color)
        }
        .clipShape(CharacterHeadShape(style: headStyle))
        .compositingGroup()
    }
}

// Claude  Date 08/02/2026
// Eyes, brows and mouth — a composite rather than one Shape because it mixes fills with
// strokes. Two things carry the whole face:
//   • The eyes are FORESHORTENED for the 3/4 turn: the far eye (left, toward the back of
//     the skull) is narrower and set closer to the silhouette edge than the near one. Get
//     that wrong and the head reads as facing straight ahead with a lump on its cheek.
//   • The catchlight. A flat black oval reads as a doll; one white dot up and to the right
//     of centre reads as a person. It's the cheapest humanising trick there is.
private struct FaceLayer: View {
    enum Expression { case neutral, smile, focused }
    let expression: Expression
    let ink: Color
    let detail: Bool
    let hairline: CGFloat

    var body: some View {
        ZStack {
            EyesShape(squint: expression == .focused).fill(ink)
            if detail {
                CatchlightShape().fill(Color.white.opacity(0.92))
                BrowsShape(angry: expression == .focused)
                    .stroke(ink.opacity(0.85), style: StrokeStyle(lineWidth: hairline * 1.5, lineCap: .round))
                MouthShape(expression: expression)
                    .stroke(ink.opacity(0.85), style: StrokeStyle(lineWidth: hairline * 1.4, lineCap: .round))
            }
        }
    }

    private struct EyesShape: Shape {
        var squint: Bool
        func path(in rect: CGRect) -> Path {
            let c = Canvas100(rect: rect)
            var p = Path()
            let ry: CGFloat = squint ? 2.9 : 3.9
            p.oval(54, 45, 3.0, ry, c)            // far eye — narrower
            p.oval(68.4, 45, 3.3, ry + 0.3, c)    // near eye
            return p
        }
    }

    private struct CatchlightShape: Shape {
        func path(in rect: CGRect) -> Path {
            let c = Canvas100(rect: rect)
            var p = Path()
            p.oval(55.1, 43.5, 1.05, 1.05, c)
            p.oval(69.6, 43.5, 1.15, 1.15, c)
            return p
        }
    }

    private struct BrowsShape: Shape {
        var angry: Bool
        func path(in rect: CGRect) -> Path {
            let c = Canvas100(rect: rect)
            var p = Path()
            // Angry brows tilt DOWN toward the nose (which is on the right).
            p.go(50, angry ? 36.5 : 38, c)
            p.qd(58.6, angry ? 38.6 : 37, 54.5, angry ? 36 : 35.2, c)
            p.go(64.8, angry ? 38.4 : 37, c)
            p.qd(72.8, angry ? 35.6 : 36.6, 69.2, angry ? 35.6 : 34.6, c)
            return p
        }
    }

    // Claude  Date 08/02/2026 last changed: 08/03/2026 by: Claude
    // (08/03) Moved ~5 design units LEFT. It used to run out to x 72.4, but the head's
    // muzzle is only at x ≈ 70 by the time you are down at mouth height (see the jaw curves
    // in CharacterHeadShape), so the near end of every expression hung off the face. It now
    // sits under the midpoint of the two eyes (54 and 68.4) rather than under the near eye,
    // which is where a mouth belongs in a 3/4 turn anyway. It also dropped ~0.6, which is
    // what buys CharacterMoustacheShape enough philtrum to sit in without touching it.
    private struct MouthShape: Shape {
        var expression: Expression
        func path(in rect: CGRect) -> Path {
            let c = Canvas100(rect: rect)
            var p = Path()
            switch expression {
            case .neutral: p.go(60.4, 60.6, c); p.qd(67.2, 60.4, 63.8, 62.0, c)
            case .smile:   p.go(59.6, 60.0, c); p.qd(67.6, 59.6, 63.8, 64.0, c)
            case .focused: p.go(60.4, 61.0, c); p.ln(67.2, 60.2, c)
            }
            return p
        }
    }
}
