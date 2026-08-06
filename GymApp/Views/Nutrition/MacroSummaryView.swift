import SwiftUI

// Claude  Date 06/16/2026 last changed: 07/26/2026 by: Claude
// The diary's at-a-glance daily summary: a big calorie ring (eaten vs goal, with
// remaining in the center) beside three macro progress bars, plus an expandable
// "More nutrients" footer for fiber/sugar/sodium. Pure presentation — it's handed
// a day's totals and the goals and draws them; no store access.
// (Ring redesign this change: the app-wide monospaced font widened every digit
// and the center text no longer fit the old 104pt ring. The macro bars gave up
// their icon chips to free horizontal room, the ring grew to 136pt, its filled
// arc is now split into carbs/protein/fat segments in MacroPalette colors, its
// unfilled remainder is staged green → light grey → grey, and the center leads
// with calories *remaining*. All iOS 16-safe; values/goals math untouched.)
struct MacroSummaryView: View {
    let totals: Nutrients
    let goals: NutritionGoals
    let accent: Color

    @State private var showExtras = false
    // Claude  Date 07/12/2026
    // Drives the ring's grow-in: progress reads as 0 until onAppear flips this,
    // so the arc sweeps up on first show (same trick as onboarding's CoinLadder).
    @State private var ringShown = false

    // Claude  Date 07/26/2026
    // Ring geometry in one place. The progress dot used to hardcode `offset(y: -52)`
    // against a 104pt frame; everything now derives from these two so a resize can't
    // leave the dot floating off the arc.
    private let ringSize: CGFloat = 136
    private let ringLineWidth: CGFloat = 14

    var body: some View {
        VStack(spacing: 14) {
            // Spacing stays at 20 even though the ring grew: the 14pt stroke is
            // centered on the path, so it renders ~7pt outside the declared frame
            // on each side and needs that back to keep clear of the bars.
            HStack(spacing: 20) {
                calorieRing
                VStack(spacing: 10) {
                    MacroBar(label: "Protein", value: totals.protein, goal: goals.protein,
                             tint: MacroPalette.protein, delay: 0)
                    MacroBar(label: "Carbs", value: totals.carbs, goal: goals.carbs,
                             tint: MacroPalette.carbs, delay: 0.08)
                    MacroBar(label: "Fat", value: totals.fat, goal: goals.fat,
                             tint: MacroPalette.fat, delay: 0.16)
                }
            }

            // Claude  Date 07/12/2026
            // Expandable extra-nutrient facts. Goal-less value rows (fiber/sugar/
            // sodium have no targets in NutritionGoals, so no progress bars) that
            // slide in staggered under the bars when expanded.
            if showExtras {
                VStack(spacing: 8) {
                    extraRow(index: 0, label: "Fiber", icon: "leaf.fill",
                             tint: MacroPalette.fiber, value: totals.fiber, unit: "g")
                    extraRow(index: 1, label: "Sugar", icon: "cube.fill",
                             tint: MacroPalette.sugar, value: totals.sugar, unit: "g")
                    extraRow(index: 2, label: "Sodium", icon: "circle.grid.3x3.fill",
                             tint: MacroPalette.sodium, value: totals.sodium, unit: "mg")
                }
            }

            // Claude  Date 07/12/2026
            // Expand toggle as a small accent capsule chip; one chevron that spins
            // 180° with a spring instead of swapping between two symbols.
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showExtras.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Text(showExtras ? "Show less" : "More nutrients")
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .rotationEffect(.degrees(showExtras ? 180 : 0))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accent.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { ringShown = true }
        }
    }

    // MARK: - Calorie ring

    // Claude  Date 06/16/2026 last changed: 08/06/2026 by: Claude
    // Calorie ring: fills toward the goal, showing kcal remaining (or "over" when
    // the day exceeds the goal). Clamped so the arc never overshoots a full circle.
    // (Redesigned 07/26: the single accent arc became three stacked macro segments —
    // carbs, protein, fat — sized by each one's share of the calories eaten, and the
    // flat track became a staged remainder that reads green while there's room, then
    // greys down as the day fills up. The dot riding the tip is now stroke-width, so
    // it doubles as the arc's one rounded cap.)
    //
    // Claude  Date 08/06/2026 — every arc now animates in ONE transaction, keyed on
    // the whole drawn geometry. Two bugs came out of the old arrangement:
    //
    //  • The remainder carried its own `.animation(_:value: stage)`. A scoped
    //    animation modifier governs its subtree outright, so the remainder ignored
    //    the outer spring and snapped whenever `stage` happened not to change —
    //    which is most changes. Deleting a food therefore moved the remainder
    //    instantly while the macro arcs, drawn ON TOP of it, spent the better part of
    //    a second springing down. The stale arc sitting over the already-correct
    //    remainder is what read as "the yellow didn't go away."
    //  • Keying on `sweep` alone meant a change that moved the macro split without
    //    moving the calorie total (swap 100 kcal of carbs for 100 kcal of fat) redrew
    //    the segments with no animation at all.
    //
    // The spring is also critically damped now (was 0.85). An overshooting spring
    // interpolates the trim PAST its target, and `trim(from:to:)` with from > to
    // renders the wrapped path — a full-circle flash every time the day crossed its
    // goal. Clamping the inputs can't prevent that; only a curve that doesn't
    // overshoot can.
    private var calorieRing: some View {
        let goal = max(goals.calories, 1)
        let progress = min(totals.calories / goal, 1)
        // Grow-in gate: every arc is scaled by this, so the ring sweeps up from
        // empty on first show and the remainder shrinks back to meet it.
        let sweep = ringShown ? progress : 0
        let remaining = goals.calories - totals.calories
        let segments = macroSegments(scaledTo: sweep)
        let stage = RemainderStage(remainingFraction: 1 - progress)

        return ZStack {
            // Unfilled remainder — how much room is left in the day.
            Circle()
                .trim(from: sweep, to: 1)
                .stroke(stage.color,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            // Filled portion, one arc per macro. Butt caps so neighbouring
            // segments meet cleanly instead of overlapping into mud.
            ForEach(segments) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(segment.color,
                            style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: segment.color.opacity(0.3), radius: 3)
            }

            // Glowing dot at the tip of the arc, tinted by whichever macro owns
            // the leading segment. Sized to the stroke so it also rounds the end.
            if let tip = segments.last, sweep > 0.005 {
                Circle()
                    .fill(tip.color)
                    .frame(width: ringLineWidth, height: ringLineWidth)
                    .shadow(color: tip.color.opacity(0.8), radius: 3)
                    .offset(y: -ringSize / 2)
                    .rotationEffect(.degrees(sweep * 360))
            }

            centerReadout(remaining: remaining)
        }
        .frame(width: ringSize, height: ringSize)
        .animation(.spring(response: 0.7, dampingFraction: 1),
                   value: CalorieRingGeometry(sweep: sweep, segments: segments, stage: stage))
        // The frame is fixed, so an accessibility text size would otherwise push
        // the readout straight through the stroke.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    // Claude  Date 07/26/2026
    // The ring's center: calories *remaining* as the headline (that's the number
    // the user actually acts on), with eaten/goal as a quiet second line. Both
    // lines shrink to fit and are width-capped inside the stroke — the old
    // subtitle had neither, which is why the monospaced font overflowed it.
    private func centerReadout(remaining: Double) -> some View {
        let over = remaining < 0
        let overStyle = AnyShapeStyle(MacroPalette.fat)
        return VStack(spacing: 1) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(accent)
            Text("\(Int(abs(remaining).rounded()))")
                .font(.title2).fontWeight(.bold)
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(over ? overStyle : AnyShapeStyle(Color.primary))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5, dampingFraction: 0.9), value: remaining)
            Text(over ? "over" : "left")
                .font(.caption2.weight(.medium))
                .foregroundStyle(over ? overStyle : AnyShapeStyle(.secondary))
            Text("\(Int(totals.calories.rounded())) / \(Int(goals.calories))")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: ringSize - ringLineWidth * 2 - 12)
    }

    // Claude  Date 07/26/2026
    // Splits the filled arc into carbs → protein → fat, proportioned by each
    // macro's share of the calories eaten (Atwater densities from NutritionGoals).
    // The three are normalized to `sweep` rather than drawn at their own kcal
    // length: totals.calories is tracked separately and won't exactly equal the
    // macro sum (rounding, alcohol, half-filled entries), and the arc's *length*
    // has to stay honest against the calorie goal even when the proportions come
    // from the macros. A day with calories but no macros logged falls back to a
    // single accent arc so the ring doesn't read as empty.
    private func macroSegments(scaledTo sweep: Double) -> [RingSegment] {
        guard sweep > 0 else { return [] }
        let carbKcal    = totals.carbs   * NutritionGoals.kcalPerGramCarbs
        let proteinKcal = totals.protein * NutritionGoals.kcalPerGramProtein
        let fatKcal     = totals.fat     * NutritionGoals.kcalPerGramFat
        let macroKcal = carbKcal + proteinKcal + fatKcal
        guard macroKcal > 0 else {
            return [RingSegment(id: 0, color: accent, start: 0, end: sweep)]
        }

        let parts: [(color: Color, kcal: Double)] = [
            (MacroPalette.carbs, carbKcal),
            (MacroPalette.protein, proteinKcal),
            (MacroPalette.fat, fatKcal)
        ]
        var cursor: Double = 0
        var result: [RingSegment] = []
        for (index, part) in parts.enumerated() where part.kcal > 0 {
            let end = cursor + sweep * (part.kcal / macroKcal)
            result.append(RingSegment(id: index, color: part.color, start: cursor, end: end))
            cursor = end
        }
        return result
    }

    // MARK: - Extra nutrients

    // Claude  Date 07/12/2026
    // One goal-less nutrient fact line with a tinted icon chip, matching the macro
    // bars' look. Each row's transition is delayed by its index so the group
    // cascades in rather than appearing as one block.
    private func extraRow(index: Int, label: String, icon: String, tint: Color,
                          value: Double, unit: String) -> some View {
        HStack(spacing: 10) {
            iconChip(icon, tint: tint)
            Text(label).font(.caption).fontWeight(.medium)
            Spacer()
            Text("\(Int(value.rounded())) \(unit)")
                .font(.caption2).foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .transition(
            .opacity.combined(with: .move(edge: .top))
                .animation(.spring(response: 0.35, dampingFraction: 0.8)
                    .delay(Double(index) * 0.06))
        )
    }
}

// Claude  Date 07/26/2026 last changed: 08/06/2026 by: Claude
// One colored slice of the calorie ring's filled arc. `start`/`end` are fractions
// of the full circle, already scaled for the grow-in, so the view just trims to them.
// `id` is the macro's fixed position (0 carbs, 1 protein, 2 fat), NOT the index in
// the emitted array — a macro that drops to zero leaves the array, and reusing array
// indices would slide the survivors onto each other's views.
// (Equatable so the ring can key one animation on its whole geometry.)
private struct RingSegment: Identifiable, Equatable {
    let id: Int
    let color: Color
    let start: Double
    let end: Double
}

// Claude  Date 08/06/2026
// Everything the ring draws, as one comparable value. The ring's arcs have to move
// together or not at all — see the note on `calorieRing` — so they hang off a single
// `.animation(_:value:)` keyed on this rather than on the calorie sweep alone.
// (Named for the calorie ring specifically: `RingGeometry` is already the rank
// ring's layout constants over in RankRing.swift.)
private struct CalorieRingGeometry: Equatable {
    let sweep: Double
    let segments: [RingSegment]
    let stage: RemainderStage
}

// Claude  Date 07/26/2026
// How much of the calorie goal is still unspent, as the three bands that color the
// ring's unfilled remainder. Only `plenty` is a signal — the other two are grey
// tones of different weight, deliberately, so a new user doesn't read the middle
// band as a warning. All three sit far below the macro segments in saturation so
// the remainder never competes with the part that's actually filled in.
private enum RemainderStage {
    case plenty     // more than half the day's calories still available
    case moderate   // 10–50% left
    case low        // under 10% left

    init(remainingFraction: Double) {
        if remainingFraction > 0.5 { self = .plenty }
        else if remainingFraction >= 0.1 { self = .moderate }
        else { self = .low }
    }

    var color: Color {
        switch self {
        case .plenty:   return MacroPalette.fiber.opacity(0.18)
        case .moderate: return Color.secondary.opacity(0.12)
        case .low:      return Color.secondary.opacity(0.25)
        }
    }
}

// Claude  Date 07/12/2026 last changed: 07/12/2026 by: Claude
// Small tinted rounded-square icon chip shared by the macro bars and extra rows
// (same treatment as onboarding's choice cards). (Made internal so the diary's
// Focus card and FocusGoalsView reuse the exact same chip.)
func iconChip(_ systemImage: String, tint: Color) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 7)
            .fill(tint.opacity(0.15))
            .frame(width: 26, height: 26)
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
    }
}

// Claude  Date 06/16/2026 last changed: 07/26/2026 by: Claude
// One labeled macro progress bar (e.g. "Protein 80 / 150 g"). Bar fills toward the
// goal and turns subtly darker past 100% so going over reads at a glance.
// (Now with a gradient fill, a goal-met checkmark, and a staggered grow-in on
// appear — `delay` offsets each bar's entrance. The tinted icon chip came off
// this change: the ring identifies each macro by color now, so the chips were
// redundant, and dropping them gave the ring the ~36pt it needed to grow.)
struct MacroBar: View {
    let label: String
    let value: Double
    let goal: Double
    let tint: Color
    var delay: Double = 0

    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(label).font(.caption).fontWeight(.medium)
                Spacer()
                if goal > 0 && value >= goal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(tint)
                        .transition(.scale.combined(with: .opacity))
                }
                Text("\(Int(value.rounded())) / \(Int(goal)) g")
                    .font(.caption2).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                let fraction = goal > 0 ? min(value / goal, 1) : 0
                let shownFraction = shown ? fraction : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(
                            colors: value > goal
                                ? [tint.opacity(0.85), tint.opacity(0.6)]
                                : [tint, tint.opacity(0.65)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * shownFraction)
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.8),
                           value: shownFraction)
            }
            .frame(height: 8)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: value >= goal)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay)) {
                shown = true
            }
        }
    }
}
