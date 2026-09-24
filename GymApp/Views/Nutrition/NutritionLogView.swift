import SwiftUI

/// The Food world's meal log. Journal owns the daily overview; this tab keeps
/// adding and editing food close to the four mealtime sections.
struct NutritionLogView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @Binding var selectedDate: Date
    @State private var addingToMeal: MealType?
    @State private var editingEntry: FoodEntry?
    @State private var showingFocusGoals = false
    @State private var showingScanner = false
    @State private var scannedBarcode: String?
    @State private var showingNewFood = false
    @State private var scannedFood: FoodDetail?

    private var day: NutritionDay { store.nutritionDay(for: selectedDate) }

    var body: some View {
        NavigationStack {
            List {
                NutritionDayPickerSection(selectedDate: $selectedDate)
                ForEach(MealType.allCases) { meal in
                    // Keep the catch-all accessible when it has entries, without
                    // adding a fifth empty section to the everyday four-meal layout.
                    if meal != .other || !day.entries(for: meal).isEmpty {
                        mealSection(meal)
                    }
                }
            }
            .navigationTitle("Log")
            .themed(theme.current)
            .modeNotchToolbar(tab: AgilTabItem.log.tag)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        scannedBarcode = nil
                        showingScanner = true
                    } label: {
                        Image("barcode")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                    .accessibilityLabel("Scan barcode")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFocusGoals = true
                        store.markNutritionSetup(\.focusGoalsOpened)
                    } label: {
                        Image(systemName: "scope")
                    }
                    .accessibilityLabel("Focus goals")
                }
            }
            .sheet(item: $addingToMeal) { meal in
                FoodPickerView(meal: meal, date: selectedDate)
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntryView(entry: entry)
            }
            .sheet(isPresented: $showingFocusGoals) {
                FocusGoalsView()
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScanSheet(
                    onResolved: { food in
                        let cached = store.cacheFood(food)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            scannedFood = FoodDetail(from: cached)
                        }
                    },
                    onManualEntry: { code in
                        scannedBarcode = code
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showingNewFood = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingNewFood, onDismiss: { scannedBarcode = nil }) {
                NewFoodView(initialBarcode: scannedBarcode)
            }
            .sheet(item: $scannedFood) { food in
                NavigationStack {
                    FoodDetailView(food: food,
                                   initialMeasurement: store.lastMeasurements[food.id],
                                   onLog: { meal, consumed, measurement in
                        store.logFoodDetail(food, consumed: consumed,
                                            measurement: measurement, meal: meal,
                                            on: selectedDate)
                    })
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { scannedFood = nil }
                        }
                    }
                }
                .themed(theme.current)
            }
        }
    }

    private func mealSection(_ meal: MealType) -> some View {
        let entries = day.entries(for: meal)
        let mealKcal = Int(day.totals(for: meal).calories.rounded())
        return Section {
            ForEach(entries) { entry in
                FoodEntryRow(entry: entry)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.deleteFoodEntry(id: entry.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editingEntry = entry
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                        }
                        .tint(theme.current.accent)
                    }
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

// One logged food row: amount, macro breakdown, and entry calories.
private struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        let c = entry.consumed
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName).font(.subheadline).fontWeight(.medium)
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
        if let text = entry.amountText { return text }
        let s = entry.servings
        let n = s.rounded() == s ? String(Int(s)) : String(format: "%.2g", s)
        return "\(n)× serving"
    }

    private func g(_ value: Double) -> String { "\(Int(value.rounded()))g" }
}

#Preview {
    NutritionLogView(selectedDate: .constant(Date()))
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
