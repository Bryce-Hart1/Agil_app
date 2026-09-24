import SwiftUI

// Bryce Hart  Date 09/02/2026 last changed: 09/05/2026 by: Bryce Hart
// Shared by the workout and food sections. Day counts are rolling inclusive windows; all time
// intentionally has no fixed start and expands to the first qualifying activity day.
enum ProgressTimeRange: String, CaseIterable, Identifiable {
    case thirtyDays
    case threeMonths
    case sixMonths
    case oneYear
    case allTime

    var id: Self { self }

    var title: String {
        switch self {
        case .thirtyDays: return "Last 30 Days"
        case .threeMonths: return "Last 3 Months"
        case .sixMonths: return "Last 6 Months"
        case .oneYear: return "Last Year"
        case .allTime: return "All Time"
        }
    }

    var recapTitle: String {
        switch self {
        case .thirtyDays: return "Last 30 days"
        case .threeMonths: return "Last 3 months"
        case .sixMonths: return "Last 6 months"
        case .oneYear: return "Last year"
        case .allTime: return "All time"
        }
    }

    var days: Int? {
        switch self {
        case .thirtyDays: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .allTime: return nil
        }
    }
}

// One reusable title row prevents the workout and food headers from drifting. The
// compact chart tile and soft range capsule add hierarchy without sacrificing the
// single horizontal line the dashboard needs on smaller phones.
struct ProgressPageHeader: View {
    @Binding var selectedRange: ProgressTimeRange
    let accent: Color
    var title = "Progress"

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))

                Text(title)
                    // A fixed compact title is more reliable than asking the large
                    // title to scale after the range capsule claims its width.
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.primary, accent],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Menu {
                Picker("Time range", selection: $selectedRange) {
                    ForEach(ProgressTimeRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selectedRange.title)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(accent.opacity(0.11), in: Capsule())
                .overlay(Capsule().stroke(accent.opacity(0.24), lineWidth: 0.5))
            }
            .accessibilityLabel("Progress time range")
            .accessibilityValue(selectedRange.title)
        }
    }
}
