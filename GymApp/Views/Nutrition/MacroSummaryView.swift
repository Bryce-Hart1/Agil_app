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
    // One thick ring split into six arcs — for each macro (protein, carbs, fat) an eaten
    // arc in its solid hue followed by a remaining arc in a faint tint of the same hue.
    // Each macro's whole wedge is its share of the day's macro grams, so the ring reads as
    // three back-to-back mini progress bars wrapped into a circle.
    private let ringLineWidth: CGFloat = 16

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

    // MARK: - Macro ring

    // Claude  Date 06/16/2026 last changed: 08/07/2026 by: Claude
    // One thick ring, six arcs. The eaten arcs come first, beside each other (protein,
    // carbs, fat) in solid hues, so the filled part reads as one progress block; then the
    // remaining arcs (protein, carbs, fat) as faint tints of the same hues. Every arc is
    // sized by grams as a share of the total goal grams, so the whole circle = the day's
    // macro-gram budget, the solid block = how much of it is eaten, and each faint arc =
    // how much of that macro is left. Calories live in the center. Replaces the old
    // Atwater-segment ring (fat's slice loomed large under a glowing tip dot) and the
    // three concentric-ring version.
    private var calorieRing: some View {
        let remaining = goals.calories - totals.calories
        let arcs = macroArcs()
        return ZStack {
            // Faint base so an empty day still reads as a ring, not a gap.
            Circle().stroke(Color.secondary.opacity(0.08),
                            style: StrokeStyle(lineWidth: ringLineWidth))
            ForEach(arcs) { arc in
                Circle()
                    .trim(from: arc.start, to: arc.end)
                    .stroke(arc.color,
                            style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            centerReadout(remaining: remaining)
        }
        .frame(width: ringSize, height: ringSize)
        .animation(.spring(response: 0.7, dampingFraction: 1), value: arcs)
        // The frame is fixed, so an accessibility text size would otherwise push
        // the readout straight through the stroke.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    // Claude  Date 08/07/2026
    // The six arcs, laid contiguously from the top: all the eaten arcs first (protein,
    // carbs, fat) so the solid block sits together as overall progress, then the remaining
    // arcs in the same order as faint tints. Each length is grams over the total goal
    // grams; the eaten portion is scaled by the grow-in gate and the remainder grows to
    // fill the gap, so on first show the ring is all-faint (nothing eaten) and the solids
    // sweep in. Over-goal is clamped to the goal so the circle always stays whole.
    private func macroArcs() -> [MacroArc] {
        let macros: [(color: Color, value: Double, goal: Double)] = [
            (MacroPalette.protein, totals.protein, goals.protein),
            (MacroPalette.carbs,   totals.carbs,   goals.carbs),
            (MacroPalette.fat,     totals.fat,     goals.fat),
        ]
        let totalGoal = macros.reduce(0) { $0 + max($1.goal, 0) }
        guard totalGoal > 0 else { return [] }
        let grow = ringShown ? 1.0 : 0.0
        var cursor = 0.0
        var arcs: [MacroArc] = []
        // Eaten arcs, beside each other.
        for (index, m) in macros.enumerated() where m.goal > 0 {
            let eaten = min(max(m.value, 0), m.goal) / totalGoal * grow
            arcs.append(MacroArc(id: index, color: m.color,
                                 start: cursor, end: cursor + eaten))
            cursor += eaten
        }
        // Remaining arcs, same order, faint — each grows to backfill its macro's uneaten part.
        for (index, m) in macros.enumerated() where m.goal > 0 {
            let left = (m.goal - min(max(m.value, 0), m.goal) * grow) / totalGoal
            arcs.append(MacroArc(id: index + 3, color: m.color.opacity(0.18),
                                 start: cursor, end: cursor + left))
            cursor += left
        }
        return arcs
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

// Claude  Date 08/07/2026
// One arc of the macro ring: a fraction range [start, end] of the full circle in a fixed
// color. `id` is the arc's fixed slot (macro index × 2, +1 for its faint remainder) so a
// macro dropping to a zero-length arc doesn't slide the others onto its view. Equatable so
// the ring animates all six arcs in one transaction.
private struct MacroArc: Identifiable, Equatable {
    let id: Int
    let color: Color
    let start: Double
    let end: Double
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
            // Claude  Date 08/07/2026 — the name and the "left" figure are fixedSize: with
            // three pieces of monospaced text in a column this narrow, SwiftUI's first
            // instinct is to WRAP, which broke "Protein" across two lines mid-word. Pinning
            // those two makes the eaten/goal pair the one flexible element, and it scales
            // down instead of anything wrapping.
            HStack(spacing: 4) {
                Text(label).font(.caption).fontWeight(.medium)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 4)
                if goal > 0 && value >= goal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(tint)
                        .transition(.scale.combined(with: .opacity))
                } else if goal > 0 {
                    // How much of this macro is still left today, in its own hue — the
                    // number that pairs with the ring's faint remaining track.
                    Text("\(Int((goal - value).rounded())) left")
                        .font(.caption2).fontWeight(.medium)
                        .foregroundStyle(tint)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Text("\(Int(value.rounded()))/\(Int(goal)) g")
                    .font(.caption2).foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
