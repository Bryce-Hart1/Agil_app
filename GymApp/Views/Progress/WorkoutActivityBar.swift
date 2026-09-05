import SwiftUI

// Bryce Hart  Date 09/05/2026
// The workout-flavoured wrapper around the shared contribution grid below. Activity
// is deliberately binary: one or several finished workouts both fill the day, while
// active/draft sessions stay empty until AppStore.finishWorkout marks them complete.
struct WorkoutActivityBar: View {
    let workouts: [Workout]
    let days: Int?
    let surface: Color
    let accent: Color

    private var completedWorkoutDates: [Date] {
        workouts.filter(\.isFinished).map(\.date)
    }

    var body: some View {
        ActivityDayTrackerBar(title: "Workout activity",
                              activeDates: completedWorkoutDates,
                              activityName: "workout",
                              days: days,
                              surface: surface,
                              accent: accent) { activeDayCount in
            Text("\(activeDayCount) active day\(activeDayCount == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// Bryce Hart  Date 09/05/2026
// Shared by lifting and food Progress. Keeping the date geometry in one component is
// what makes the two worlds render in the exact same GitHub-style rhythm.
struct ActivityDayTrackerBar<HeaderAccessory: View>: View {
    let title: String
    let activeDates: [Date]
    let activityName: String
    let days: Int?
    let surface: Color
    let accent: Color
    @ViewBuilder let headerAccessory: (Int) -> HeaderAccessory

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3
    private let monthLabelHeight: CGFloat = 12
    private let quarterCellSize: CGFloat = 17
    private let calendarCellSize: CGFloat = 30
    private let calendarSpacing: CGFloat = 7

    private var calendar: Calendar { .autoupdatingCurrent }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var visibleRangeStart: Date {
        if let days {
            return calendar.date(byAdding: .day,
                                 value: -(max(days, 1) - 1),
                                 to: today) ?? today
        }

        return activeDates
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 <= today }
            .min()
            ?? calendar.date(byAdding: .day, value: -29, to: today)
            ?? today
    }

    private var activityCounts: [Date: Int] {
        activeDates.reduce(into: [:]) { counts, date in
            counts[calendar.startOfDay(for: date), default: 0] += 1
        }
    }

    private var weeks: [WorkoutActivityWeek] {
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let firstWeekStart = calendar.dateInterval(of: .weekOfYear,
                                                         for: visibleRangeStart)?.start else {
            return []
        }

        let elapsedWeeks = calendar.dateComponents([.weekOfYear],
                                                    from: firstWeekStart,
                                                    to: currentWeekStart).weekOfYear ?? 0
        let weekCount = max(1, elapsedWeeks + 1)
        let counts = activityCounts
        return (0..<weekCount).compactMap { weekOffset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear,
                                                value: weekOffset,
                                                to: firstWeekStart) else {
                return nil
            }
            let days = (0..<7).compactMap { dayOffset -> WorkoutActivityDay? in
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                    return nil
                }
                let normalizedDate = calendar.startOfDay(for: date)
                return WorkoutActivityDay(date: normalizedDate,
                                          workoutCount: counts[normalizedDate, default: 0],
                                          isToday: calendar.isDate(normalizedDate, inSameDayAs: today),
                                          isOutsideRange: normalizedDate < visibleRangeStart
                                              || normalizedDate > today)
            }
            return WorkoutActivityWeek(start: weekStart, days: days)
        }
    }

    private var activeDayCount: Int {
        weeks.flatMap(\.days).filter { !$0.isOutsideRange && $0.workoutCount > 0 }.count
    }

    private var activeDayText: String {
        "\(activeDayCount) active day\(activeDayCount == 1 ? "" : "s")"
    }

    private var mostRecentActiveDay: Date? {
        weeks.flatMap(\.days)
            .filter { !$0.isOutsideRange && $0.workoutCount > 0 }
            .map(\.date)
            .max()
    }

    private var rangeDescription: String {
        switch days {
        case 30: return "the last 30 days"
        case 90: return "the last 3 months"
        case 180: return "the last 6 months"
        case 365: return "the last year"
        case nil: return "all time"
        case let value?: return "the last \(value) days"
        }
    }

    private var accessibilitySummary: String {
        guard let mostRecentActiveDay else {
            return "No \(activityName) activity in \(rangeDescription)."
        }
        return "\(activeDayText) in \(rangeDescription). Most recent \(activityName) activity \(mostRecentActiveDay.formatted(date: .long, time: .omitted))."
    }

    private var layout: WorkoutActivityGridLayout {
        switch days {
        case 30: return .calendar
        case 90: return .fittedQuarter
        default: return .scrollable
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(title, systemImage: "square.grid.3x3.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                headerAccessory(activeDayCount)
            }

            gridForSelectedRange
        }
        .padding(14)
        .background(surface, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var gridForSelectedRange: some View {
        switch layout {
        case .calendar:
            calendarActivityGrid
        case .fittedQuarter:
            fittedQuarterActivityGrid
        case .scrollable:
            HStack(alignment: .top, spacing: 6) {
                weekdayLabels(cellSize: cellSize)
                scrollableActivityGrid
            }
        }
    }

    private func weekdayLabels(cellSize: CGFloat) -> some View {
        VStack(spacing: cellSpacing) {
            Color.clear.frame(width: 14, height: monthLabelHeight)
            ForEach(labelDays.indices, id: \.self) { index in
                let day = labelDays[index]
                Text(day.label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: cellSize, alignment: .trailing)
            }
        }
    }

    // A rolling month reads more naturally as a conventional calendar: weekdays run
    // across the top, weeks stack downward, and date numbers make the month boundary
    // clear even when the 30-day window crosses between two months.
    private var calendarActivityGrid: some View {
        VStack(spacing: calendarSpacing) {
            HStack(spacing: calendarSpacing) {
                ForEach(labelDays.indices, id: \.self) { index in
                    Text(labelDays[index].date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 22),
                                                   spacing: calendarSpacing),
                               count: 7),
                spacing: calendarSpacing
            ) {
                ForEach(weeks.flatMap(\.days)) { day in
                    activityCell(for: day,
                                 size: calendarCellSize,
                                 showsDayNumber: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilitySummary)
    }

    // Ninety days stays in the GitHub orientation, but its thirteen or fourteen week
    // columns share the available width. Larger squares remove the dead space without
    // turning a quarter-sized range into another horizontal scroller.
    private var fittedQuarterActivityGrid: some View {
        HStack(alignment: .top, spacing: 6) {
            weekdayLabels(cellSize: quarterCellSize)

            VStack(spacing: cellSpacing) {
                HStack(spacing: 0) {
                    ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                        Text(monthLabel(for: week, at: index))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(height: monthLabelHeight)

                HStack(alignment: .top, spacing: 0) {
                    ForEach(weeks) { week in
                        VStack(spacing: cellSpacing) {
                            ForEach(week.days) { day in
                                activityCell(for: day, size: quarterCellSize)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilitySummary)
    }

    private func monthLabel(for week: WorkoutActivityWeek, at index: Int) -> String {
        if index == 0,
           let firstVisibleDay = week.days.first(where: { !$0.isOutsideRange }) {
            return firstVisibleDay.date.formatted(.dateTime.month(.abbreviated))
        }

        guard let firstOfMonth = week.days.first(where: {
            calendar.component(.day, from: $0.date) == 1 && !$0.isOutsideRange
        }) else {
            return ""
        }
        return firstOfMonth.date.formatted(.dateTime.month(.abbreviated))
    }

    private var labelDays: [WorkoutActivityDayLabel] {
        guard let sampleWeek = weeks.last else { return [] }
        return sampleWeek.days.map { day in
            let weekday = calendar.component(.weekday, from: day.date)
            let isLabeled = weekday == 2 || weekday == 4 || weekday == 6
            return WorkoutActivityDayLabel(
                date: day.date,
                label: isLabeled ? day.date.formatted(.dateTime.weekday(.narrow)) : ""
            )
        }
    }

    private var scrollableActivityGrid: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    monthLabels

                    LazyHStack(alignment: .top, spacing: cellSpacing) {
                        ForEach(weeks) { week in
                            VStack(spacing: cellSpacing) {
                                ForEach(week.days) { day in
                                    activityCell(for: day, size: cellSize)
                                }
                            }
                            .id(week.id)
                        }
                    }
                    .padding(.top, monthLabelHeight + cellSpacing)
                }
                .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
            }
            .onAppear {
                guard let lastWeek = weeks.last else { return }
                proxy.scrollTo(lastWeek.id, anchor: .trailing)
            }
            .onChange(of: visibleRangeStart) { _ in
                guard let lastWeek = weeks.last else { return }
                proxy.scrollTo(lastWeek.id, anchor: .trailing)
            }
        }
        .frame(height: gridHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilitySummary)
    }

    private var monthLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(monthMarkers) { marker in
                Text(marker.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(x: marker.offset)
            }
        }
        .frame(width: gridWidth, height: monthLabelHeight, alignment: .topLeading)
    }

    private var monthMarkers: [WorkoutActivityMonthMarker] {
        guard let firstWeek = weeks.first,
              let firstDay = firstWeek.days.first(where: { !$0.isOutsideRange }) else { return [] }

        var markers = [WorkoutActivityMonthMarker(date: firstDay.date, offset: 0)]
        for (index, week) in weeks.enumerated() where index > 0 {
            guard let firstOfMonth = week.days.first(where: {
                calendar.component(.day, from: $0.date) == 1 && !$0.isOutsideRange
            }) else { continue }

            markers.append(
                WorkoutActivityMonthMarker(
                    date: firstOfMonth.date,
                    offset: CGFloat(index) * (cellSize + cellSpacing)
                )
            )
        }
        return markers
    }

    @ViewBuilder
    private func activityCell(for day: WorkoutActivityDay,
                              size: CGFloat,
                              showsDayNumber: Bool = false) -> some View {
        if day.isOutsideRange {
            Color.clear
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(day.workoutCount > 0 ? accent : Color.primary.opacity(0.09))
                .frame(width: size, height: size)
                .overlay {
                    ZStack {
                        if day.isToday {
                            RoundedRectangle(cornerRadius: 2.5)
                                .stroke(day.workoutCount > 0 ? Color.primary.opacity(0.55) : accent,
                                        lineWidth: 1)
                        }
                        if showsDayNumber {
                            Text(day.date.formatted(.dateTime.day()))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(day.workoutCount > 0
                                                 ? Color.white
                                                 : Color.secondary)
                        }
                    }
                }
        }
    }

    private var gridWidth: CGFloat {
        CGFloat(weeks.count) * cellSize + CGFloat(max(0, weeks.count - 1)) * cellSpacing
    }

    private var gridHeight: CGFloat {
        monthLabelHeight + cellSpacing + 7 * cellSize + 6 * cellSpacing
    }
}

private enum WorkoutActivityGridLayout {
    case calendar
    case fittedQuarter
    case scrollable
}

private struct WorkoutActivityWeek: Identifiable {
    let start: Date
    let days: [WorkoutActivityDay]
    var id: Date { start }
}

private struct WorkoutActivityDay: Identifiable {
    let date: Date
    let workoutCount: Int
    let isToday: Bool
    let isOutsideRange: Bool
    var id: Date { date }
}

private struct WorkoutActivityDayLabel {
    let date: Date
    let label: String
}

private struct WorkoutActivityMonthMarker: Identifiable {
    let date: Date
    let offset: CGFloat
    var id: Date { date }
}
