import SwiftUI
import Charts

// Bryce Hart  Date 09/02/2026
// The range selected from the Progress tab's leading calendar menu. Day counts are
// rolling windows so every option has a same-length preceding window for the recap;
// all time intentionally has no comparison period.
private enum ProgressTimeRange: String, CaseIterable, Identifiable {
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

private enum ProgressFrequencyInterval {
    case week
    case month
    case year

    var component: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    var sectionTitle: String {
        switch self {
        case .week: return "Workouts per week"
        case .month: return "Workouts per month"
        case .year: return "Workouts per year"
        }
    }

    func axisLabel(for date: Date) -> String {
        switch self {
        case .week:
            return date.formatted(.dateTime.month(.defaultDigits).day())
        case .month:
            return date.formatted(.dateTime.month(.abbreviated))
        case .year:
            return date.formatted(.dateTime.year())
        }
    }
}

// Claude  Date 07/22/2026
// The "Volume over time" chart was dropped here — per-workout total volume swings with
// exercise selection rather than progress, so the line wasn't rewarding to look at. The
// `volume(of:)` helper stays because `totalVolume` (server-sync stat) still needs it.
/// The Progress tab: at-a-glance stat cards, estimated-1RM trend,
/// workouts-per-week, sets-per-muscle-group, and a personal-records list.
struct ProgressDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var selectedExerciseID: UUID?
    @State private var selectedRange: ProgressTimeRange = .thirtyDays
    // Claude  Date 08/16/2026
    // Held in state rather than computed: building the recap summarizes every finished
    // session in the window against the ledger, so it must not re-run on each `body`
    // pass. Refreshed on appear and whenever a workout or ledger event is added — an
    // EDIT to an existing workout won't trigger it, which is fine given how often this
    // tab re-appears.
    @State private var recap: MonthlyRecap?

    var body: some View {
        NavigationStack {
            List {
                if completedWorkouts.isEmpty {
                    Text("Log some workouts to see your progress here.")
                        .foregroundStyle(.secondary)
                } else if filteredWorkouts.isEmpty {
                    Text("No completed workouts in \(selectedRange.title.lowercased()).")
                        .foregroundStyle(.secondary)
                } else {
                    recapSection
                    summarySection
                    oneRepMaxSection
                    frequencySection
                    muscleGroupSection
                    personalRecordsSection
                }
            }
            .navigationTitle("Progress")
            .themed(theme.current)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            .modeNotchToolbar(tab: AgilTabItem.progress.tag)
            // Bryce Hart  Date 09/02/2026
            // A scope control on the left and a destination on the right match the
            // other root tabs while keeping both labels the same fixed width so the
            // ModeNotch remains centered. SF Symbols are temporary until the custom
            // Progress SVGs are ready.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Time range", selection: $selectedRange) {
                            ForEach(ProgressTimeRange.allCases) { range in
                                Text(range.title).tag(range)
                            }
                        }
                    } label: {
                        toolbarIcon("calendar")
                    }
                    .accessibilityLabel("Progress time range")
                    .accessibilityValue(selectedRange.title)
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        AllPersonalRecordsView(records: allPersonalRecords)
                            .themed(theme.current)
                    } label: {
                        toolbarIcon("trophy")
                    }
                    .accessibilityLabel("Personal records")
                }
            }
            .onAppear {
                synchronizeSelectedExercise()
                refreshRecap()
            }
            .onChange(of: store.workouts.count) { _ in refreshRecap() }
            .onChange(of: store.activityLog.count) { _ in refreshRecap() }
            .onChange(of: selectedRange) { _ in
                synchronizeSelectedExercise()
                refreshRecap()
            }
        }
    }

    private func refreshRecap() {
        recap = MonthlyRecap(workouts: store.workouts,
                             events: store.activityLog,
                             exercises: store.exercises,
                             days: selectedRange.days)
    }

    private func synchronizeSelectedExercise() {
        if let selectedExerciseID,
           loggedExercises.contains(where: { $0.id == selectedExerciseID }) {
            return
        }
        selectedExerciseID = loggedExercises.first?.id
    }

    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 19))
            .frame(width: 22, height: 22)
    }

    // MARK: - Sections

    // Claude  Date 08/16/2026
    // The rolling 30-day recap, above the lifetime stat cards: what changed recently is
    // the thing you open this tab to see, and the lifetime figures barely move. Hidden
    // entirely when the window has no credited sets, so a returning user after a long
    // layoff gets the charts rather than a card full of zeros.
    @ViewBuilder
    private var recapSection: some View {
        if let recap, recap.hasData {
            Section {
                MonthlyRecapCard(recap: recap,
                                 title: selectedRange.recapTitle,
                                 surface: theme.current.surface,
                                 accent: theme.current.accent)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
    }

    // Claude  Date 07/22/2026
    // One row of four instead of a 2×2 grid — the summary stats were taking up most of
    // the first screen and pushing the charts below the fold. Titles are shortened
    // ("Total workouts" → "Workouts") because the full wording can't hold one line at
    // quarter width; the section header carries the context that the label drops.
    private var summarySection: some View {
        Section {
            HStack(spacing: 8) {
                StatCard(title: "Workouts", value: "\(filteredWorkouts.count)",
                         systemImage: "calendar", surface: theme.current.surface, accent: theme.current.accent)
                StatCard(title: "Streak", value: "\(currentStreak)",
                         systemImage: "flame", surface: theme.current.surface, accent: theme.current.accent)
                StatCard(title: "This week", value: "\(workoutsThisWeek)",
                         systemImage: "calendar.badge.clock", surface: theme.current.surface, accent: theme.current.accent)
                StatCard(title: "Last", value: lastWorkoutText,
                         systemImage: "clock.arrow.circlepath", surface: theme.current.surface, accent: theme.current.accent)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var oneRepMaxSection: some View {
        Section("Estimated 1RM") {
            Picker("Exercise", selection: $selectedExerciseID) {
                ForEach(loggedExercises) { exercise in
                    Text(exercise.displayLabel).tag(Optional(exercise.id))
                }
            }
            // Claude  Date 07/16/2026
            // Rebuild on theme swap so the menu picker's value label re-reads the
            // accent (it's UIKit-backed and resolves its tint only at creation).
            .retintOnThemeChange(theme.current, salt: "oneRM-exercise")
            if oneRepMaxPoints.count >= 1 {
                TrendChart(points: oneRepMaxPoints, color: theme.current.accent, unit: "lb")
            } else {
                Text("Not enough data for this exercise yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var frequencySection: some View {
        Section(frequencyInterval.sectionTitle) {
            FrequencyChart(periods: frequencyCounts,
                           interval: frequencyInterval,
                           color: theme.current.accent)
        }
    }

    @ViewBuilder
    private var muscleGroupSection: some View {
        if !categorySets.isEmpty {
            Section("Sets per muscle group") {
                MuscleGroupChart(rows: categorySets, color: theme.current.accent)
            }
        }
    }

    // Claude  Date 07/22/2026 last changed: 07/23/2026 by: Claude
    // Only the 5 most recently achieved records show here; the rest stay tracked and are
    // reachable via "See all". `personalRecords` is already sorted most-recent-first.
    @ViewBuilder
    private var personalRecordsSection: some View {
        if !personalRecords.isEmpty {
            Section("Personal records") {
                ForEach(personalRecords.prefix(5)) { pr in
                    PRRow(record: pr)
                }
                if personalRecords.count > 5 {
                    NavigationLink("See all") {
                        AllPersonalRecordsView(records: personalRecords)
                            .themed(theme.current)
                    }
                }
            }
        }
    }

    // MARK: - Derived data

    private func volume(of workout: Workout) -> Double {
        workout.exercises.reduce(0) { total, logged in
            total + logged.sets.reduce(0) { $0 + Double($1.reps) * $1.weight }
        }
    }

    /// Lifetime total volume (Σ reps×weight). Intentionally NOT shown in the UI —
    /// retained so it can be synced to the server later as a profile/"flex" stat.
    private var totalVolume: Double {
        store.workouts.reduce(0) { $0 + volume(of: $1) }
    }

    private var rangeStart: Date? {
        selectedRange.days.flatMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date())
        }
    }

    private var completedWorkouts: [Workout] {
        store.workouts.filter(\.isFinished)
    }

    private var filteredWorkouts: [Workout] {
        completedWorkouts.filter { workout in
            guard let rangeStart else { return true }
            return workout.date >= rangeStart
        }
    }

    /// Number of workouts logged in the current calendar week.
    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return filteredWorkouts.filter { interval.contains($0.date) }.count
    }

    /// Consecutive weeks (ending this week) that contain at least one workout.
    private var currentStreak: Int {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        var weeksWithWorkouts = Set<Date>()
        for workout in filteredWorkouts {
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start {
                weeksWithWorkouts.insert(weekStart)
            }
        }
        var streak = 0
        var cursor = thisWeek
        while weeksWithWorkouts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private var lastWorkoutText: String {
        guard let date = filteredWorkouts.map(\.date).max() else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Exercises that appear in at least one workout, sorted by name.
    private var loggedExercises: [Exercise] {
        let usedIDs = Set(filteredWorkouts.flatMap { $0.exercises.map(\.exerciseId) })
        return store.exercises.filter { usedIDs.contains($0.id) }.sorted { $0.name < $1.name }
    }

    /// Best estimated 1RM per workout date for the selected exercise.
    private var oneRepMaxPoints: [DatedValue] {
        guard let id = selectedExerciseID else { return [] }
        var points: [DatedValue] = []
        for workout in filteredWorkouts.sorted(by: { $0.date < $1.date }) {
            let sets = workout.exercises.filter { $0.exerciseId == id }.flatMap { $0.sets }
            // Claude  Date 07/21/2026
            // Shared Epley helper (was an inline copy of the same formula) so the chart
            // and the performance card's best-set scoring can't drift apart.
            let best = sets.map { BestSetScoring.e1RM(weight: $0.weight, reps: $0.reps) }.max()
            if let best, best > 0 {
                points.append(DatedValue(date: workout.date, value: best))
            }
        }
        return points
    }

    private var frequencyInterval: ProgressFrequencyInterval {
        switch selectedRange {
        case .thirtyDays, .threeMonths:
            return .week
        case .sixMonths, .oneYear:
            return .month
        case .allTime:
            guard let earliest = filteredWorkouts.map(\.date).min()
            else { return .month }
            let months = Calendar.current.dateComponents([.month], from: earliest, to: Date()).month ?? 0
            return months > 24 ? .year : .month
        }
    }

    private var frequencyCounts: [FrequencyBar] {
        let calendar = Calendar.current
        let interval = frequencyInterval
        guard let currentStart = calendar.dateInterval(of: interval.component, for: Date())?.start else {
            return []
        }

        let firstWorkout = filteredWorkouts.map(\.date).min()
        guard let lowerBound = rangeStart ?? firstWorkout,
              let firstStart = calendar.dateInterval(of: interval.component, for: lowerBound)?.start else {
            return []
        }

        var buckets: [Date: Int] = [:]
        for workout in filteredWorkouts {
            if let periodStart = calendar.dateInterval(of: interval.component, for: workout.date)?.start {
                buckets[periodStart, default: 0] += 1
            }
        }

        var result: [FrequencyBar] = []
        var cursor = firstStart
        while cursor <= currentStart {
            result.append(FrequencyBar(start: cursor, count: buckets[cursor] ?? 0))
            guard let next = calendar.date(byAdding: interval.component, value: 1, to: cursor),
                  next > cursor else { break }
            cursor = next
        }
        return result
    }

    private var categorySets: [CategoryBar] {
        var counts: [String: Int] = [:]
        for workout in filteredWorkouts {
            for logged in workout.exercises {
                let category = store.exercise(for: logged.exerciseId)?.category ?? "Other"
                counts[category, default: 0] += logged.sets.count
            }
        }
        return counts
            .map { CategoryBar(category: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
    }

    // Claude  Date 07/22/2026 last changed: 08/16/2026 by: Claude
    // (08/16) The derivation moved to PersonalRecord.bests (MonthlyRecap.swift) so the
    // recap card and this list can't drift into two definitions of "record" — the recap
    // shows the same records, filtered to the selected time range.
    private var allPersonalRecords: [PersonalRecord] {
        PersonalRecord.bests(from: store.activityLog, exercises: store.exercises)
    }

    private var personalRecords: [PersonalRecord] {
        guard let rangeStart else { return allPersonalRecords }
        return allPersonalRecords.filter { $0.achievedAt >= rangeStart }
    }
}

// MARK: - Row models

private struct DatedValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

private struct FrequencyBar: Identifiable {
    let start: Date
    let count: Int
    var id: Date { start }
}

private struct CategoryBar: Identifiable {
    let category: String
    let sets: Int
    var id: String { category }
}

// MARK: - Cards & charts

/// A line+point trend chart over time (used for volume and estimated 1RM).
private struct TrendChart: View {
    let points: [DatedValue]
    let color: Color
    let unit: String

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value(unit, point.value))
                .foregroundStyle(color)
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", point.date), y: .value(unit, point.value))
                .foregroundStyle(color)
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 200)
        .padding(.vertical, 4)
    }
}

private struct FrequencyChart: View {
    let periods: [FrequencyBar]
    let interval: ProgressFrequencyInterval
    let color: Color

    var body: some View {
        Chart(periods) { period in
            BarMark(x: .value("Period", period.start, unit: interval.component),
                    y: .value("Workouts", period.count))
                .foregroundStyle(color.gradient)
                .annotation(position: .top) {
                    if period.count > 0 {
                        Text("\(period.count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(interval.axisLabel(for: date))
                    }
                }
            }
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 200)
        .padding(.vertical, 4)
    }
}

private struct MuscleGroupChart: View {
    let rows: [CategoryBar]
    let color: Color

    var body: some View {
        Chart(rows) { row in
            BarMark(x: .value("Sets", row.sets), y: .value("Group", row.category))
                .foregroundStyle(color.gradient)
                .annotation(position: .trailing) {
                    Text("\(row.sets)").font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: CGFloat(rows.count) * 38 + 20)
        .padding(.vertical, 4)
    }
}

// Claude  Date 07/22/2026 last changed: 07/23/2026 by: Claude
// The best set is now the primary stat ("4 reps @ 135 lb"), with the estimated 1RM
// demoted to a small caption underneath. Unilateral lifts append "/ side" so the
// per-side load isn't mistaken for a two-sided one (this replaces the old name tag).
private struct PRRow: View {
    let record: PersonalRecord

    private var bestSetText: String {
        let base = "\(record.reps) reps @ \(Int(record.weight.rounded())) lb"
        return record.isUnilateral ? base + " / side" : base
    }

    var body: some View {
        HStack {
            Text(record.name)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(bestSetText).font(.subheadline)
                Text("est 1RM \(Int(record.estOneRepMax.rounded())) lb")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// Claude  Date 07/23/2026
// The full personal-records list behind the Progress tab's "See all" link. Every
// weighted exercise's best set, most recently achieved first — the same rows as the
// capped preview, just uncapped.
private struct AllPersonalRecordsView: View {
    let records: [PersonalRecord]

    var body: some View {
        List {
            if records.isEmpty {
                Text("Complete weighted exercises to build your personal-record history.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { pr in
                    PRRow(record: pr)
                }
            }
        }
        .navigationTitle("Personal records")
    }
}

#Preview {
    let store = AppStore()
    let workout = Workout(exercises: [
        LoggedExercise(exerciseId: store.exercises[0].id,
                       sets: [ExerciseSet(reps: 8, weight: 135), ExerciseSet(reps: 5, weight: 165)]),
        LoggedExercise(exerciseId: store.exercises[2].id,
                       sets: [ExerciseSet(reps: 5, weight: 225)])
    ])
    store.addWorkout(workout)
    return ProgressDashboardView()
        .environmentObject(store)
        .environmentObject(ThemeManager())
}
