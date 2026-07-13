import SwiftUI

// Claude  Date 06/16/2026 last changed: 07/12/2026 by: Claude
// The diary's at-a-glance daily summary: a big calorie ring (eaten vs goal, with
// remaining in the center) beside three macro progress bars, plus an expandable
// "More nutrients" footer for fiber/sugar/sodium. Pure presentation — it's handed
// a day's totals and the goals and draws them; no store access.
// (Flair pass this change: gradient ring with a glowing progress dot and animated
// entrance, rolling kcal digits, icon chips + gradient fills + staggered grow-in
// on the macro bars, tinted icons on the extra rows, and a capsule expand toggle
// with a rotating chevron. All iOS 16-safe; values/goals math untouched.)
struct MacroSummaryView: View {
    let totals: Nutrients
    let goals: NutritionGoals
    let accent: Color

    @State private var showExtras = false
    // Claude  Date 07/12/2026
    // Drives the ring's grow-in: progress reads as 0 until onAppear flips this,
    // so the arc sweeps up on first show (same trick as onboarding's CoinLadder).
    @State private var ringShown = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                calorieRing
                VStack(spacing: 10) {
                    MacroBar(label: "Protein", icon: "figure.strengthtraining.traditional",
                             value: totals.protein, goal: goals.protein, tint: .blue, delay: 0)
                    MacroBar(label: "Carbs", icon: "bolt.fill",
                             value: totals.carbs, goal: goals.carbs, tint: .orange, delay: 0.08)
                    MacroBar(label: "Fat", icon: "drop.fill",
                             value: totals.fat, goal: goals.fat, tint: .pink, delay: 0.16)
                }
            }

            // Claude  Date 07/12/2026
            // Expandable extra-nutrient facts. Goal-less value rows (fiber/sugar/
            // sodium have no targets in NutritionGoals, so no progress bars) that
            // slide in staggered under the bars when expanded.
            if showExtras {
                VStack(spacing: 8) {
                    extraRow(index: 0, label: "Fiber", icon: "leaf.fill",
                             tint: .green, value: totals.fiber, unit: "g")
                    extraRow(index: 1, label: "Sugar", icon: "cube.fill",
                             tint: .purple, value: totals.sugar, unit: "g")
                    extraRow(index: 2, label: "Sodium", icon: "circle.grid.3x3.fill",
                             tint: .cyan, value: totals.sodium, unit: "mg")
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

    // Claude  Date 06/16/2026 last changed: 07/12/2026 by: Claude
    // Calorie ring: fills toward the goal, showing kcal remaining (or "over" when
    // the day exceeds the goal). Clamped so the arc never overshoots a full circle.
    // (Now drawn with an angular accent gradient + soft glow, a dot riding the
    // progress tip — rotated, not offset, so it follows the arc when animating —
    // a flame in the center, and rolling digits via contentTransition.)
    private var calorieRing: some View {
        let goal = max(goals.calories, 1)
        let progress = min(totals.calories / goal, 1)
        let shownProgress = ringShown ? progress : 0
        let remaining = goals.calories - totals.calories
        return ZStack {
            Circle()
                .stroke(accent.opacity(0.12), lineWidth: 12)
            Circle()
                .trim(from: 0, to: shownProgress)
                .stroke(
                    AngularGradient(colors: [accent.opacity(0.5), accent], center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(0.35), radius: 4)

            // Glowing dot at the tip of the arc (hidden while the ring is empty).
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                .shadow(color: accent.opacity(0.8), radius: 3)
                .offset(y: -52)
                .rotationEffect(.degrees(shownProgress * 360))
                .opacity(shownProgress > 0.01 ? 1 : 0)

            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(accent)
                Text("\(Int(totals.calories.rounded()))")
                    .font(.title2).fontWeight(.bold)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.9),
                               value: totals.calories)
                Text(remaining >= 0 ? "of \(Int(goals.calories)) kcal"
                                    : "\(Int(-remaining)) over")
                    .font(.caption2)
                    .foregroundStyle(remaining >= 0 ? AnyShapeStyle(.secondary)
                                                    : AnyShapeStyle(Color.orange))
            }
        }
        .frame(width: 104, height: 104)
        .animation(.spring(response: 0.9, dampingFraction: 0.85), value: shownProgress)
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

// Claude  Date 06/16/2026 last changed: 07/12/2026 by: Claude
// One labeled macro progress bar (e.g. "Protein 80 / 150 g"). Bar fills toward the
// goal and turns subtly darker past 100% so going over reads at a glance.
// (Now with a tinted icon chip, a gradient fill, a goal-met checkmark, and a
// staggered grow-in on appear — `delay` offsets each bar's entrance.)
struct MacroBar: View {
    let label: String
    let icon: String
    let value: Double
    let goal: Double
    let tint: Color
    var delay: Double = 0

    @State private var shown = false

    var body: some View {
        HStack(spacing: 10) {
            iconChip(icon, tint: tint)
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
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: value >= goal)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay)) {
                shown = true
            }
        }
    }
}
