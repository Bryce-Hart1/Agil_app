import SwiftUI

// Bryce Hart  Date 09/05/2026
// The Food world's Progress page. It intentionally starts with only the activity
// tracker; the page can grow food-specific summaries beneath it without moving the
// shared Progress tab or changing this first, glanceable row.
struct NutritionProgressDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("nutritionProgressTimeRange")
    private var selectedRange: ProgressTimeRange = .thirtyDays
    @AppStorage("nutritionProgressWidgetLayoutV1") private var storedWidgetLayout =
        ProgressCustomizationMode.nutrition.defaultStorageValue

    private var selectedWidgets: [ProgressWidgetKind] {
        ProgressWidgetLayout.widgets(from: storedWidgetLayout, mode: .nutrition)
    }

    var body: some View {
        NavigationStack {
            List {
                progressTitleSection
                ForEach(selectedWidgets) { widget in
                    if widget == .foodActivity {
                        activitySection
                    }
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
