import SwiftUI
import Charts

// Bryce Hart  Date 09/05/2026
// The Food world's Progress page. Food activity stays the glanceable first row, with
// daily goal-aware charts underneath for macros, focus goals, and optional water.
struct NutritionProgressDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("nutritionProgressTimeRange")
    private var selectedRange: ProgressTimeRange = .thirtyDays
    @AppStorage("nutritionProgressWidgetLayoutV2") private var storedWidgetLayout =
        ProgressCustomizationMode.nutrition.defaultStorageValue
    @AppStorage("nutritionProgressTopFoodsAddedV1") private var addedTopFoodWidgets = false
    @AppStorage(WaterTracking.storageKey) private var trackWater = WaterTracking.defaultValue
    @AppStorage(WaterUnit.storageKey) private var waterUnitRaw = WaterUnit.milliliters.rawValue

    private var waterUnit: WaterUnit {
        WaterUnit(rawValue: waterUnitRaw) ?? .milliliters
    }

    private var selectedWidgets: [ProgressWidgetKind] {
        ProgressWidgetLayout.widgets(from: storedWidgetLayout, mode: .nutrition)
    }

    var body: some View {
        NavigationStack {
            List {
                progressTitleSection
                ForEach(selectedWidgets) { widget in
                    dashboardWidget(widget)
                }
                editProgressSection
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .modeNotchToolbar(tab: AgilTabItem.progress.tag)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ProgressCustomizationView(mode: .nutrition)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 22, height: 22)
                    }
                    .accessibilityLabel("Edit Progress")
                }
                // Same top-right shortcut geometry as lifting's PR button. This is
                // the Journal's goals destination for now; a food-specific Progress
                // destination can replace it later without moving the control.
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        NutritionGoalsView()
                    } label: {
                        Image(systemName: "target")
                            .font(.system(size: 19))
                            .frame(width: 22, height: 22)
                    }
                    .accessibilityLabel("Nutrition goals")
                }
            }
            .onAppear { addTopFoodWidgetsIfNeeded() }
        }
    }

    // Preserve the user's existing food dashboard choices while adding the three new
    // charts once. An intentionally empty dashboard stays empty.
    private func addTopFoodWidgetsIfNeeded() {
        guard !addedTopFoodWidgets else { return }
        addedTopFoodWidgets = true
        guard storedWidgetLayout != "none" else { return }

        var widgets = selectedWidgets
        for widget in [ProgressWidgetKind.proteinFoods, .carbFoods, .fatFoods]
            where !widgets.contains(widget) {
            widgets.append(widget)
        }
        let order = ProgressCustomizationMode.nutrition.availableWidgets
        widgets.sort { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
        storedWidgetLayout = ProgressWidgetLayout.storageValue(for: widgets)
    }

    @ViewBuilder
    private func dashboardWidget(_ widget: ProgressWidgetKind) -> some View {
        switch widget {
        case .foodActivity:
            activitySection
        case .proteinIntake:
            dailyIntakeSection(title: widget.title,
                               points: proteinPoints,
                               goal: store.nutritionGoals.protein,
                               unit: "g",
                               color: MacroPalette.protein)
        case .carbIntake:
            dailyIntakeSection(title: widget.title,
                               points: carbPoints,
                               goal: store.nutritionGoals.carbs,
                               unit: "g",
                               color: MacroPalette.carbs)
        case .fatIntake:
            dailyIntakeSection(title: widget.title,
                               points: fatPoints,
                               goal: store.nutritionGoals.fat,
                               unit: "g",
                               color: MacroPalette.fat)
        case .proteinFoods:
            topFoodsSection(title: widget.title,
                            summary: topFoodContributions { $0.protein },
                            color: MacroPalette.protein)
        case .carbFoods:
            topFoodsSection(title: widget.title,
                            summary: topFoodContributions { $0.carbs },
                            color: MacroPalette.carbs)
        case .fatFoods:
            topFoodsSection(title: widget.title,
                            summary: topFoodContributions { $0.fat },
                            color: MacroPalette.fat)
        case .focusCompletion:
            focusCompletionSection
        case .waterIntake:
            if trackWater {
                dailyIntakeSection(title: widget.title,
                                   points: waterPoints,
                                   goal: waterUnit.fromMilliliters(store.nutritionGoals.water),
                                   unit: waterUnit.abbreviation,
                                   color: theme.current.accent)
            }
        case .workoutActivity, .recap, .summary, .oneRepMax,
                .frequency, .muscleGroups, .personalRecords:
            EmptyView()
        }
    }

    private var progressTitleSection: some View {
        Section {
            ProgressPageHeader(selectedRange: $selectedRange,
                               accent: theme.current.accent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var activitySection: some View {
        Section {
            NutritionActivityBar(foodLog: store.foodLog,
                                 calorieGoal: store.nutritionGoals.calories,
                                 days: selectedRange.days,
                                 surface: theme.current.surface,
                                 accent: theme.current.accent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16,
                                         bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func dailyIntakeSection(title: String,
                                    points: [DailyIntakePoint],
                                    goal: Double,
                                    unit: String,
                                    color: Color) -> some View {
        Section(title) {
            if points.isEmpty {
                Text(title == "Daily water intake"
                     ? "Log water to see your daily intake here."
                     : "Log food to see your daily intake here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                DailyIntakeChart(points: points,
                                 goal: goal,
                                 unit: unit,
                                 color: color,
                                 dateDomain: dateDomain(for: points.map(\.date)))
            }
        }
    }

    @ViewBuilder
    private var focusCompletionSection: some View {
        Section("Focus goal completion") {
            if store.focusGoals.isEmpty {
                Text("Add a focus goal from the Journal to see daily completion here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if focusCompletionPoints.isEmpty {
                Text("Log food to see how often you complete your focus goals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                FocusCompletionChart(points: focusCompletionPoints,
                                     goalCount: store.focusGoals.count,
                                     color: theme.current.accent,
                                     dateDomain: dateDomain(
                                        for: focusCompletionPoints.map(\.date)))
            }
        }
    }

    @ViewBuilder
    private func topFoodsSection(title: String,
                                 summary: FoodContributionSummary,
                                 color: Color) -> some View {
        Section(title) {
            if summary.isEmpty {
                Text("Not enough data for this time frame.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                FoodContributorsChart(summary: summary, color: color)
            }
        }
    }

    private var editProgressSection: some View {
        Section {
            NavigationLink {
                ProgressCustomizationView(mode: .nutrition)
            } label: {
                Label("Edit Progress", systemImage: "slider.horizontal.3")
                    .foregroundStyle(theme.current.accent)
            }
        }
    }

    // MARK: - Chart data

    private var calendar: Calendar { .autoupdatingCurrent }

    private var today: Date { calendar.startOfDay(for: Date()) }

    private var fixedRangeStart: Date? {
        guard let days = selectedRange.days else { return nil }
        return calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today)
    }

    private func isInSelectedRange(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day <= today else { return false }
        return fixedRangeStart.map { day >= $0 } ?? true
    }

    private var visibleFoodEntries: [FoodEntry] {
        store.foodLog.filter { isInSelectedRange($0.loggedAt) }
    }

    // A point exists for each day food was actually tracked. Keeping untracked days as
    // gaps avoids pretending that missing diary data is a measured zero intake.
    private var foodDays: [NutritionProgressDay] {
        Dictionary(grouping: visibleFoodEntries) {
            calendar.startOfDay(for: $0.loggedAt)
        }
        .map { date, entries in
            NutritionProgressDay(date: date,
                                 totals: entries.reduce(.zero) { $0 + $1.consumed })
        }
        .sorted { $0.date < $1.date }
    }

    // CLAUDE  Date 09/12/2026
    // Aggregate the consumed amount across every serving of the same snapshotted food,
    // keeping the five strongest — but also the RANGE-WIDE total and each food's entry
    // count, which is what lets the card show a real share and a remainder rather than
    // five bars measured against each other. Bucket key is still the frozen label.
    private func topFoodContributions(
        nutrientValue: (Nutrients) -> Double
    ) -> FoodContributionSummary {
        var totals: [String: (grams: Double, count: Int)] = [:]
        var overall = 0.0
        for entry in visibleFoodEntries {
            let value = nutrientValue(entry.consumed)
            guard value > 0 else { continue }
            overall += value
            var bucket = totals[entry.displayName] ?? (grams: 0, count: 0)
            bucket.grams += value
            bucket.count += 1
            totals[entry.displayName] = bucket
        }
        guard overall > 0 else { return .empty }

        let ranked = totals.sorted { left, right in
            if left.value.grams == right.value.grams { return left.key < right.key }
            return left.value.grams > right.value.grams
        }
        let top = ranked.prefix(5).map { label, bucket -> FoodContribution in
            let parts = label.foodLabelParts
            return FoodContribution(label: label, name: parts.name, brand: parts.brand,
                                    grams: bucket.grams, entryCount: bucket.count,
                                    share: bucket.grams / overall)
        }
        let counted = top.reduce(0) { $0 + $1.grams }
        return FoodContributionSummary(contributions: top,
                                       totalGrams: overall,
                                       remainderGrams: max(overall - counted, 0))
    }

    private var proteinPoints: [DailyIntakePoint] {
        foodDays.map { DailyIntakePoint(date: $0.date, value: $0.totals.protein) }
    }

    private var carbPoints: [DailyIntakePoint] {
        foodDays.map { DailyIntakePoint(date: $0.date, value: $0.totals.carbs) }
    }

    private var fatPoints: [DailyIntakePoint] {
        foodDays.map { DailyIntakePoint(date: $0.date, value: $0.totals.fat) }
    }

    private var waterPoints: [DailyIntakePoint] {
        let visibleEntries = store.waterLog.filter { isInSelectedRange($0.loggedAt) }
        return Dictionary(grouping: visibleEntries) {
            calendar.startOfDay(for: $0.loggedAt)
        }
        .map { date, entries in
            DailyIntakePoint(
                date: date,
                value: waterUnit.fromMilliliters(
                    entries.reduce(0) { $0 + $1.milliliters }
                )
            )
        }
        .sorted { $0.date < $1.date }
    }

    // Completion is evaluated only on food-tracked days. That distinction matters for
    // ceiling goals: an empty diary should not count as a perfect sugar/sodium day.
    private var focusCompletionPoints: [FocusCompletionPoint] {
        let goals = store.focusGoals
        guard !goals.isEmpty else { return [] }
        return foodDays.map { day in
            let metCount = goals.filter { goal in
                goal.isMet(consumed: goal.nutrient.value(from: day.totals))
            }.count
            return FocusCompletionPoint(date: day.date,
                                        metCount: metCount,
                                        goalCount: goals.count)
        }
    }

    private func dateDomain(for dates: [Date]) -> ClosedRange<Date> {
        let fallback = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let start = fixedRangeStart ?? dates.min() ?? fallback
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return start...end
    }
}

private struct NutritionProgressDay {
    let date: Date
    let totals: Nutrients
}

private struct DailyIntakePoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

private struct FocusCompletionPoint: Identifiable {
    let date: Date
    let metCount: Int
    let goalCount: Int
    var id: Date { date }
    var percentage: Double { Double(metCount) / Double(goalCount) * 100 }
}

// CLAUDE  Date 09/12/2026
// One food's pull on a single macro over the selected range. `label` is the frozen
// "name · brand" diary snapshot and stays the identity; name/brand are split back out
// only so the row can stack them instead of truncating one long string.
private struct FoodContribution: Identifiable {
    let label: String
    let name: String
    let brand: String?
    let grams: Double
    let entryCount: Int
    /// Fraction of every gram of this macro logged in the range, 0...1.
    let share: Double
    var id: String { label }

    var percent: Int { Int((share * 100).rounded()) }

    /// Brand and how often it was logged — what separates a daily staple from one
    /// enormous meal. nil for an unbranded food eaten exactly once.
    var subtitle: String? {
        var parts: [String] = []
        if let brand { parts.append(brand) }
        if entryCount > 1 { parts.append("×\(entryCount)") }
        return parts.isEmpty ? nil : parts.joined(separator: String.foodLabelSeparator)
    }
}

// CLAUDE  Date 09/12/2026
// The five rows plus what they are a share OF, so the header and the "everything else"
// row can frame them honestly. Percentages are taken from the already-rounded rows and
// the remainder absorbs the rounding error, so the column always sums to 100.
private struct FoodContributionSummary {
    let contributions: [FoodContribution]
    let totalGrams: Double
    let remainderGrams: Double

    static let empty = FoodContributionSummary(contributions: [], totalGrams: 0,
                                               remainderGrams: 0)

    var isEmpty: Bool { contributions.isEmpty }
    var topPercent: Int { contributions.reduce(0) { $0 + $1.percent } }
    var remainderPercent: Int { max(100 - topPercent, 0) }
    var remainderShare: Double { totalGrams > 0 ? remainderGrams / totalGrams : 0 }
    var showsRemainder: Bool { remainderGrams.rounded() >= 1 }
}

private struct DailyIntakeChart: View {
    let points: [DailyIntakePoint]
    let goal: Double
    let unit: String
    let color: Color
    let dateDomain: ClosedRange<Date>

    private var average: Double {
        points.reduce(0) { $0 + $1.value } / Double(points.count)
    }

    private var yMaximum: Double {
        max(max(points.map(\.value).max() ?? 0, goal), 1) * 1.15
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Avg \(wholeNumber(average)) \(unit) / tracked day")
                Spacer()
                Text("Goal \(wholeNumber(goal)) \(unit)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Chart {
                ForEach(points) { point in
                    BarMark(x: .value("Date", point.date, unit: .day),
                            y: .value(unit, point.value),
                            width: .ratio(0.72))
                        .foregroundStyle(color.gradient)
                        .accessibilityLabel(point.date.formatted(date: .long,
                                                                 time: .omitted))
                        .accessibilityValue("\(wholeNumber(point.value)) \(unit)")
                }

                if goal > 0 {
                    RuleMark(y: .value("Daily goal", goal))
                        .foregroundStyle(color.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .chartXScale(domain: dateDomain)
            .chartYScale(domain: 0...yMaximum)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        }
                    }
                }
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .frame(height: 210)
        }
        .padding(.vertical, 4)
    }

    private func wholeNumber(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

private struct FocusCompletionChart: View {
    let points: [FocusCompletionPoint]
    let goalCount: Int
    let color: Color
    let dateDomain: ClosedRange<Date>

    private var completedDayCount: Int {
        points.filter { $0.metCount == $0.goalCount }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(completedDayCount) of \(points.count) tracked days completed all \(goalCount) goal\(goalCount == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(points) { point in
                    BarMark(x: .value("Date", point.date, unit: .day),
                            y: .value("Goals completed", point.percentage),
                            width: .ratio(0.72))
                        .foregroundStyle(point.percentage >= 100 ? color : color.opacity(0.45))
                        .accessibilityLabel(point.date.formatted(date: .long,
                                                                 time: .omitted))
                        .accessibilityValue("\(point.metCount) of \(point.goalCount) focus goals completed")
                }

                RuleMark(y: .value("All goals", 100))
                    .foregroundStyle(color.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .chartXScale(domain: dateDomain)
            .chartYScale(domain: 0...105)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0.0, 50.0, 100.0]) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let percentage = value.as(Double.self) {
                            Text("\(Int(percentage))%")
                        }
                    }
                }
            }
            .frame(height: 210)
        }
        .padding(.vertical, 4)
    }
}

// CLAUDE  Date 09/12/2026
// The Top <macro> foods card. Each bar is the food's share of EVERY gram of that macro
// in the range — not of the leader, which made row one always full and told you nothing
// — so protein/carbs/fat now read differently by how concentrated their sources are.
// Side effect: bars are visibly shorter than before, and the card is taller per row.
private struct FoodContributorsChart: View {
    let summary: FoodContributionSummary
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("top \(summary.contributions.count) · \(summary.topPercent)% of \(wholeNumber(summary.totalGrams)) g")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            ForEach(Array(summary.contributions.enumerated()), id: \.element.id) {
                index, contribution in
                row(rank: index + 1,
                    name: contribution.name,
                    subtitle: contribution.subtitle,
                    grams: contribution.grams,
                    percent: contribution.percent,
                    share: contribution.share)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(contribution.brand.map {
                        "\(contribution.name), \($0)"
                    } ?? contribution.name)
                    .accessibilityValue(
                        "\(wholeNumber(contribution.grams)) grams, \(contribution.percent)% of the total, logged \(contribution.entryCount) times")
            }

            // The anchor for the five short bars above: without it a card of 9% rows
            // reads as missing data rather than as genuinely spread-out eating.
            if summary.showsRemainder {
                row(rank: nil,
                    name: "everything else",
                    subtitle: nil,
                    grams: summary.remainderGrams,
                    percent: summary.remainderPercent,
                    share: summary.remainderShare,
                    dimmed: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Everything else")
                    .accessibilityValue(
                        "\(wholeNumber(summary.remainderGrams)) grams, \(summary.remainderPercent)% of the total")
            }
        }
        .padding(.vertical, 6)
    }

    // The name is the only flexible element and carries NO line limit, so a long
    // "name · brand" wraps instead of losing its tail to a "…". It also drops the
    // theme's monospaced face (see supportingTextFont) which fits far more per line;
    // the numbers stay mono so the trailing column keeps its digits aligned.
    private func row(rank: Int?, name: String, subtitle: String?,
                     grams: Double, percent: Int, share: Double,
                     dimmed: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(rank.map(String.init) ?? "")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .trailing)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.caption)
                            .supportingTextFont()
                            .foregroundStyle(dimmed ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .supportingTextFont()
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(wholeNumber(grams)) g")
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                        Text("\(percent)%")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.13))
                        Capsule()
                            .fill(dimmed ? AnyShapeStyle(color.opacity(0.32))
                                         : AnyShapeStyle(color.gradient))
                            // A 1% contributor still gets a visible nub.
                            .frame(width: max(geometry.size.width * min(share, 1), 3))
                    }
                }
                .frame(height: 10)
            }
        }
    }

    private func wholeNumber(_ value: Double) -> String {
        value.rounded().formatted(.number.precision(.fractionLength(0)))
    }
}

private struct NutritionActivityBar: View {
    let foodLog: [FoodEntry]
    let calorieGoal: Double
    let days: Int?
    let surface: Color
    let accent: Color

    // OFF is the more meaningful default: days where eating landed close to the
    // calorie target. ON widens the view to every day with at least one food entry.
    // AppStorage gives the switch memory across tab changes and app launches.
    @AppStorage("nutritionProgressShowsAllTrackedDays")
    private var showsAllTrackedDays = false

    private let calorieTolerance = 200.0
    private var calendar: Calendar { .autoupdatingCurrent }

    private var entriesByDay: [Date: [FoodEntry]] {
        Dictionary(grouping: foodLog) { calendar.startOfDay(for: $0.loggedAt) }
    }

    private var activeDates: [Date] {
        entriesByDay.compactMap { date, entries in
            if showsAllTrackedDays { return date }
            let calories = entries.reduce(0.0) { $0 + $1.consumed.calories }
            return abs(calories - calorieGoal) <= calorieTolerance ? date : nil
        }
    }

    private var modeText: String {
        showsAllTrackedDays ? "tracked" : "±200 kcal"
    }

    private var activityName: String {
        showsAllTrackedDays ? "food tracking" : "calorie-goal"
    }

    var body: some View {
        ActivityDayTrackerBar(title: "Food activity",
                              activeDates: activeDates,
                              activityName: activityName,
                              days: days,
                              surface: surface,
                              accent: accent) { activeDayCount in
            HStack(spacing: 7) {
                Text("\(activeDayCount) · \(modeText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Toggle("Show every tracked day", isOn: $showsAllTrackedDays)
                    .labelsHidden()
                    .tint(accent)
                    .scaleEffect(0.82)
                    .frame(width: 42)
                    .accessibilityLabel("Food activity view")
                    .accessibilityValue(showsAllTrackedDays
                                        ? "All days tracked"
                                        : "Days within 200 calories of goal")
            }
        }
    }
}

#Preview {
    NutritionProgressDashboardView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
