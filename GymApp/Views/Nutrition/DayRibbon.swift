import SwiftUI

// CLAUDE  Date 09/30/2026
// The Log's at-a-glance strip: the day from 5a (or earlier, if you ate earlier) to midnight,
// one daylight-tinted bar per 10 minutes you ate in, height by √kcal. A dashed line marks now
// on today. Tapping a bar hands back an entry id so the list can scroll to it. Static once
// drawn; only the first appearance animates.
struct DayRibbon: View {
    let entries: [FoodEntry]
    let date: Date
    var onSelect: (UUID) -> Void = { _ in }

    @State private var shown = false

    private static let barWidth: CGFloat = 5
    private static let barArea: CGFloat = 30
    private static let bucket: TimeInterval = 10 * 60
    private static let dayEnd: TimeInterval = 24 * 3600

    // One bar: the entries eaten inside a 10-minute bucket, summed.
    private struct Bar: Identifiable {
        let id: UUID            // the bucket's first entry, which is where a tap scrolls to
        let seconds: TimeInterval
        let kcal: Double
    }

    private var bars: [Bar] {
        let grouped = Dictionary(grouping: entries) {
            Int(MealTiming.secondsIntoDay($0.loggedAt) / Self.bucket)
        }
        return grouped.values.compactMap { group in
            let sorted = group.sorted { $0.loggedAt < $1.loggedAt }
            guard let first = sorted.first else { return nil }
            let mean = sorted.map { MealTiming.secondsIntoDay($0.loggedAt) }.reduce(0, +) / Double(sorted.count)
            return Bar(id: first.id, seconds: mean,
                       kcal: sorted.reduce(0) { $0 + $1.consumed.calories })
        }
        .sorted { $0.seconds < $1.seconds }
    }

    // The strip starts at 5a, or at the hour of anything eaten before that.
    private var rangeStart: TimeInterval {
        let earliest = entries.map { MealTiming.secondsIntoDay($0.loggedAt) }.min() ?? .infinity
        return min(5 * 3600, (earliest / 3600).rounded(.down) * 3600)
    }

    private var nowSeconds: TimeInterval? {
        Calendar.current.isDateInToday(date) ? MealTiming.secondsIntoDay(Date()) : nil
    }

    var body: some View {
        let bars = self.bars
        let start = rangeStart
        let maxKcal = max(bars.map(\.kcal).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let x = { (s: TimeInterval) -> CGFloat in
                    let f = (s - start) / (Self.dayEnd - start)
                    return min(max(CGFloat(f) * w, 0), w)
                }
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 1)
                    if let now = nowSeconds, now >= start {
                        Path { p in
                            p.move(to: CGPoint(x: x(now), y: 0))
                            p.addLine(to: CGPoint(x: x(now), y: Self.barArea))
                        }
                        .stroke(DaylightPalette.color(atSeconds: now),
                                style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    ForEach(bars) { bar in
                        let height = max(4, Self.barArea * CGFloat((bar.kcal / maxKcal).squareRoot()))
                        Button { onSelect(bar.id) } label: {
                            Capsule()
                                .fill(DaylightPalette.color(atSeconds: bar.seconds))
                                .frame(width: Self.barWidth, height: shown ? height : 2)
                                // A 5pt bar is too thin to hit; widen the target, not the bar.
                                .frame(width: 22, height: Self.barArea, alignment: .bottom)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .offset(x: min(max(x(bar.seconds) - 11, -8), w - 14))
                    }
                }
                .frame(width: w, height: Self.barArea, alignment: .bottomLeading)
            }
            .frame(height: Self.barArea)
            hourLabels(start: start)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { shown = true }
        }
    }

    // 6a · 12p · 6p (or 6 · 12 · 18), placed at their true positions under the strip.
    private func hourLabels(start: TimeInterval) -> some View {
        GeometryReader { geo in
            ForEach([6, 12, 18], id: \.self) { hour in
                let f = (TimeInterval(hour) * 3600 - start) / (Self.dayEnd - start)
                Text(Self.hourText(hour))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
                    .position(x: CGFloat(f) * geo.size.width, y: 6)
            }
        }
        .frame(height: 12)
    }

    private static func hourText(_ hour: Int) -> String {
        if MealTiming.localeUses24Hour { return "\(hour)" }
        return hour == 12 ? "12p" : hour < 12 ? "\(hour)a" : "\(hour - 12)p"
    }

    // "4 foods · 7:40a – 12:06p · 1,035 kcal", or an invitation when nothing's logged.
    private var caption: String {
        let sorted = entries.sorted { $0.loggedAt < $1.loggedAt }
        guard let first = sorted.first, let last = sorted.last else {
            return Calendar.current.isDateInToday(date) ? "Nothing logged yet today" : "Nothing logged this day"
        }
        let count = "\(sorted.count) \(sorted.count == 1 ? "food" : "foods")"
        let span = first.id == last.id || MealTiming.compactTime(first.loggedAt) == MealTiming.compactTime(last.loggedAt)
            ? MealTiming.compactTime(first.loggedAt)
            : "\(MealTiming.compactTime(first.loggedAt)) – \(MealTiming.compactTime(last.loggedAt))"
        let kcal = Int(sorted.reduce(0) { $0 + $1.consumed.calories }.rounded())
        return "\(count) · \(span) · \(kcal.formatted()) kcal"
    }

    private var accessibilityText: String {
        let times = bars.map { bar in
            let clock = MealTiming.placing(seconds: bar.seconds, on: date)
            return "\(Int(bar.kcal.rounded())) calories at \(clock.formatted(date: .omitted, time: .shortened))"
        }
        return (["Day timeline. \(caption)."] + times).joined(separator: " ")
    }
}
