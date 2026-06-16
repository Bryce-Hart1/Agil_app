import SwiftUI

// Claude  Date 06/16/2026
// The diary's at-a-glance daily summary: a big calorie ring (eaten vs goal, with
// remaining in the center) beside three macro progress bars. Pure presentation —
// it's handed a day's totals and the goals and draws them; no store access.
struct MacroSummaryView: View {
    let totals: Nutrients
    let goals: NutritionGoals
    let accent: Color

    var body: some View {
        HStack(spacing: 20) {
            calorieRing
            VStack(spacing: 10) {
                MacroBar(label: "Protein", value: totals.protein, goal: goals.protein,
                         tint: .blue)
                MacroBar(label: "Carbs", value: totals.carbs, goal: goals.carbs,
                         tint: .orange)
                MacroBar(label: "Fat", value: totals.fat, goal: goals.fat,
                         tint: .pink)
            }
        }
        .padding(.vertical, 4)
    }

    // Claude  Date 06/16/2026
    // Calorie ring: fills toward the goal, showing kcal remaining (or "over" when
    // the day exceeds the goal). Clamped so the arc never overshoots a full circle.
    private var calorieRing: some View {
        let goal = max(goals.calories, 1)
        let progress = min(totals.calories / goal, 1)
        let remaining = goals.calories - totals.calories
        return ZStack {
            Circle()
                .stroke(accent.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(totals.calories.rounded()))")
                    .font(.title2).fontWeight(.bold)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(remaining >= 0 ? "of \(Int(goals.calories)) kcal"
                                    : "\(Int(-remaining)) over")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 104, height: 104)
        .animation(.easeInOut(duration: 0.3), value: progress)
    }
}

// Claude  Date 06/16/2026
// One labeled macro progress bar (e.g. "Protein 80 / 150 g"). Bar fills toward the
// goal and turns subtly darker past 100% so going over reads at a glance.
struct MacroBar: View {
    let label: String
    let value: Double
    let goal: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.caption).fontWeight(.medium)
                Spacer()
                Text("\(Int(value.rounded())) / \(Int(goal)) g")
                    .font(.caption2).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                let fraction = goal > 0 ? min(value / goal, 1) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.18))
                    Capsule().fill(value > goal ? tint.opacity(0.9) : tint)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 7)
        }
    }
}
