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

    private var day: NutritionDay { store.nutritionDay(for: selectedDate) }

    var body: some View {
        NavigationStack {
            List {
                dateSection
                summarySection
                waterSection
                ForEach(MealType.allCases) { meal in
                    mealSection(meal)
                }
            }
            .navigationTitle("Log")
            .themed(theme.current)
            .toolbar {
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

#Preview {
    NutritionJournalView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
