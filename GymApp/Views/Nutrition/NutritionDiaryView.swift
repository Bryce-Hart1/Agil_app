import SwiftUI


/// The Nutrition tab's home: a per-day food diary. A date stepper at the top picks
/// the day; below it sits the daily calorie/macro summary, a water tracker, and one
/// section per meal listing what was logged. The + on each meal opens the food
/// picker to log into that meal on the selected day.
struct NutritionJournalView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Claude  Date 06/16/2026 updated Bryce Hart 6/16/26
    // The day being viewed/edited. Defaults to today; the header steps it.
    @State private var selectedDate = Date()
    // Which meal the food picker is logging into (nil = picker closed).
    @State private var addingToMeal: MealType?
    // Claude  Date 06/16/2026
    // The logged entry being edited (nil = editor closed). Tapping a row opens it.
    @State private var editingEntry: FoodEntry?
    // Claude  Date 07/12/2026
    // Whether the focus-goals editor sheet is up (top-left toolbar button).
    @State private var showingFocusGoals = false

    private var day: NutritionDay { store.nutritionDay(for: selectedDate) }

    var body: some View {
        NavigationStack {
            List {
                dateSection
                summarySection
                if !store.focusGoals.isEmpty {
                    focusSection
                }
                waterSection
                ForEach(MealType.allCases) { meal in
                    mealSection(meal)
                }
            }
            .navigationTitle("Log")
            .themed(theme.current)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            .modeNotchToolbar()
            .toolbar {
                // Claude  Date 07/12/2026
                // Top-left: nutrient focus goals ("I want to eat more fiber").
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFocusGoals = true
                    } label: {
                        Image(systemName: "scope")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        NutritionGoalsView()
                    } label: {
                        Image(systemName: "target")
                    }
                }
            }
            .sheet(item: $addingToMeal) { meal in
                FoodPickerView(meal: meal, date: selectedDate)
            }
            .sheet(isPresented: $showingFocusGoals) {
                FocusGoalsView()
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntryView(entry: entry)
            }
        }
    }

    // MARK: - Date stepper

    private var dateSection: some View {
        Section {
            HStack {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
                VStack(spacing: 1) {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.headline)
                    Text(selectedDate, format: .dateTime.month().day().year())
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { step(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
                    .disabled(Calendar.current.isDateInToday(selectedDate))
            }
            if !Calendar.current.isDateInToday(selectedDate) {
                Button("Jump to Today") { selectedDate = Date() }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func step(_ days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate)
        else { return }
        // Never step past today (no logging into the future).
        if days > 0 && next > Date() { return }
        selectedDate = next
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section("Summary") {
            MacroSummaryView(totals: day.totals, goals: store.nutritionGoals,
                             accent: theme.current.accent)
        }
    }

    // MARK: - Focus goals

    // Claude  Date 07/12/2026
    // The Focus card: one progress row per user-created nutrient focus goal (see
    // NutrientFocusGoal), fed from the selected day's totals so it follows the
    // date stepper. Only rendered when at least one goal exists.
    // TODO: Claude  Date 07/12/2026 — later: optional daily local notification
    // nudging unmet focus goals (UNCalendarNotificationTrigger, added alongside
    // WorkoutNotifications' existing schedule/cancel pairs; reuse
    // NutrientFocusGoal.progressText for the wording).
    private var focusSection: some View {
        Section("Focus") {
            ForEach(store.focusGoals) { goal in
                FocusGoalRow(goal: goal,
                             consumed: goal.nutrient.value(from: day.totals))
            }
        }
    }

    // MARK: - Water

    private var waterSection: some View {
        Section("Water") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(Int(day.water.rounded())) / \(Int(store.nutritionGoals.water)) ml",
                          systemImage: "drop.fill")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(theme.current.accent)
                    Spacer()
                }
                GeometryReader { geo in
                    let goal = max(store.nutritionGoals.water, 1)
                    let fraction = min(day.water / goal, 1)
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.current.accent.opacity(0.18))
                        Capsule().fill(theme.current.accent)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 8)
                HStack { //added conversions for cups, bottle (even though a bottle is 500ml)
                // one cup is approx 236.588 ml rounded up
                    Button("+250 ml") { store.logWater(milliliters: 250, on: selectedDate) }
                    Button("+500 ml") { store.logWater(milliliters: 500, on: selectedDate) }
                    Button("+bottle"){store.logWater(milliliters: 500, on: selectedDate)}
                    Button("+cup"){store.logWater(milliliters: 237, on: selectedDate)}
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }

    // MARK: - Meals

    private func mealSection(_ meal: MealType) -> some View {
        let entries = day.entries(for: meal)
        let mealKcal = Int(day.totals(for: meal).calories.rounded())
        return Section {
            ForEach(entries) { entry in
                Button { editingEntry = entry } label: {
                    FoodEntryRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { entries[$0].id }.forEach(store.deleteFoodEntry)
            }
            Button {
                addingToMeal = meal
            } label: {
                Label("Add food", systemImage: "plus.circle.fill")
                    .font(.subheadline)
            }
        } header: {
            HStack {
                Label(meal.title, systemImage: meal.systemImage)
                Spacer()
                if mealKcal > 0 { Text("\(mealKcal) kcal") }
            }
        }
    }
}

// Claude  Date 06/16/2026
// One logged food row: name, what was eaten (servings + macro breakdown), and the
// calories for the entry on the trailing edge.
private struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        let c = entry.consumed
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.subheadline).fontWeight(.medium)
                    .lineLimit(1)
                Text("\(servingsText) • P \(g(c.protein)) · C \(g(c.carbs)) · F \(g(c.fat))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(c.calories.rounded())) kcal")
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var servingsText: String {
        let s = entry.servings
        let n = s.rounded() == s ? String(Int(s)) : String(format: "%.2g", s)
        return "\(n)× serving"
    }

    private func g(_ value: Double) -> String { "\(Int(value.rounded()))g" }
}

// Claude  Date 07/12/2026
// One focus-goal progress row under the Summary: tinted icon chip, a thin bar in
// the Summary card's style (grow-in spring, animated updates), and a status
// caption from NutrientFocusGoal.progressText. For "stay under" goals the bar
// shows budget used and turns orange→red past the ceiling; met goals get a
// checkmark next to the label.
private struct FocusGoalRow: View {
    let goal: NutrientFocusGoal
    let consumed: Double

    @State private var shown = false

    var body: some View {
        let tint = goal.nutrient.tint
        let fraction = goal.target > 0 ? min(consumed / goal.target, 1) : 0
        let over = consumed > goal.target
        let met = goal.isMet(consumed: consumed)
        let barColors: [Color] = (goal.direction == .atMost && over)
            ? [.orange, .red.opacity(0.85)]
            : [tint, tint.opacity(0.65)]

        HStack(spacing: 10) {
            iconChip(goal.nutrient.systemImage, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(goal.nutrient.label).font(.caption).fontWeight(.medium)
                    if met {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(tint)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                    Text("\(Int(consumed.rounded())) / \(Int(goal.target)) \(goal.nutrient.unit) · \(goal.progressText(consumed: consumed))")
                        .font(.caption2).monospacedDigit()
                        .foregroundStyle((goal.direction == .atMost && over)
                                         ? Color.orange : Color.secondary)
                }
                GeometryReader { geo in
                    let shownFraction = shown ? fraction : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.15))
                        Capsule()
                            .fill(LinearGradient(colors: barColors,
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * shownFraction)
                    }
                    .animation(.spring(response: 0.55, dampingFraction: 0.8),
                               value: shownFraction)
                }
                .frame(height: 8)
            }
        }
        .padding(.vertical, 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: met)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { shown = true }
        }
    }
}

#Preview {
    NutritionJournalView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
