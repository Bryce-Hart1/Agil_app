import SwiftUI
import Charts

// CLAUDE  Date 09/19/2026
// Weigh-ins as faint points with the 7-day average drawn through them, plus a dashed goal
// line. The average is the story: individual mornings swing several pounds on water alone,
// and a chart that only drew them would make a steady cut look like noise.
// iOS 16-safe — no chart selection, no scrollable axes.
struct WeightTrendChart: View {
    let weighIns: [WeighIn]
    var goalWeightLb: Double?
    let units: BodyUnits
    let accent: Color
    var days: Int = 90

    private struct Point: Identifiable {
        let id: String
        let date: Date
        let value: Double
    }

    var body: some View {
        if points.count < 2 {
            Text("Log a few days and your trend appears here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .supportingTextFont()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        } else {
            Chart {
                ForEach(points) { point in
                    PointMark(x: .value("Day", point.date),
                              y: .value("Weight", point.value))
                        .foregroundStyle(accent.opacity(0.3))
                        .symbolSize(16)
                }
                ForEach(trend) { point in
                    LineMark(x: .value("Day", point.date),
                             y: .value("Trend", point.value),
                             series: .value("Series", "trend"))
                        .foregroundStyle(accent)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
                if let goal = goalWeightLb.map({ units.fromPounds($0) }) {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            // Bodyweight never starts at zero, and forcing it there would flatten every
            // change worth seeing.
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(String(format: "%.0f", number))
                        }
                    }
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Weight trend over the last \(days) days, in \(units.weightAbbreviation)")
        }
    }

    // MARK: - Data

    private var windowKeys: [String] {
        DayKey.window(endingOn: DayKey.key(), length: days)
    }

    private var inWindow: [WeighIn] {
        let keys = Set(windowKeys)
        return weighIns.filter { keys.contains($0.dayKey) }.sorted { $0.dayKey < $1.dayKey }
    }

    private var points: [Point] {
        inWindow.compactMap { weighIn in
            DayKey.date(from: weighIn.dayKey).map {
                Point(id: weighIn.dayKey, date: $0, value: units.fromPounds(weighIn.weightLb))
            }
        }
    }

    // CLAUDE  Date 09/19/2026
    // The rolling 7-day average, computed at each logged day over the days behind it — the
    // same window the check-in compares, so the line on screen and the number in the plan
    // are the same measurement.
    private var trend: [Point] {
        inWindow.compactMap { weighIn in
            let window = DayKey.window(endingOn: weighIn.dayKey, length: 7)
            guard let average = WeightTrend.window(weighIns, keys: window)?.average,
                  let date = DayKey.date(from: weighIn.dayKey) else { return nil }
            return Point(id: "trend-" + weighIn.dayKey, date: date,
                         value: units.fromPounds(average))
        }
    }
}
