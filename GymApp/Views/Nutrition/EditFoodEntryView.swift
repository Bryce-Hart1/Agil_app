import SwiftUI

// Claude  Date 06/16/2026
// Edit an already-logged diary entry: change how many servings and which meal, see
// the recomputed totals live, then save — or delete the entry. The food's name and
// per-serving nutrient snapshot are preserved (you're correcting the log, not
// redefining the food), mirroring the add/log flow in FoodPickerView.
struct EditFoodEntryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let entry: FoodEntry

    @State private var servings: Double
    @State private var meal: MealType

    init(entry: FoodEntry) {
        self.entry = entry
        _servings = State(initialValue: entry.servings)
        _meal = State(initialValue: entry.mealType)
    }

    private var consumed: Nutrients { entry.nutrients.scaled(by: servings) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(entry.name).font(.headline)
                    Text(loggedCaption)
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Amount") {
                    Stepper(value: $servings, in: 0.25...50, step: 0.25) {
                        Text(amountLabel)
                    }
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Totals") {
                    LabeledContent("Calories", value: "\(Int(consumed.calories.rounded())) kcal")
                    LabeledContent("Protein", value: "\(Int(consumed.protein.rounded())) g")
                    LabeledContent("Carbs", value: "\(Int(consumed.carbs.rounded())) g")
                    LabeledContent("Fat", value: "\(Int(consumed.fat.rounded())) g")
                }

                Section {
                    Button(role: .destructive) {
                        store.deleteFoodEntry(id: entry.id)
                        dismiss()
                    } label: {
                        Label("Delete entry", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        var updated = entry
        updated.servings = servings
        updated.mealType = meal
        store.updateFoodEntry(updated)
        dismiss()
    }

    // Claude  Date 08/06/2026
    // What was originally logged. For anything logged through the food detail page,
    // `nutrients` is the WHOLE portion and `servings` is 1 — so the old
    // "Per serving: N kcal" was really the total, and reading it as a serving size
    // made the stepper below look like it did something different than it does. With
    // a measurement on the entry we can say what was actually logged.
    private var loggedCaption: String {
        let kcal = Int(entry.nutrients.calories.rounded())
        if let measurement = entry.measurement {
            return "Logged: \(measurement.displayText) · \(kcal) kcal"
        }
        return "Per serving: \(kcal) kcal"
    }

    // Claude  Date 08/06/2026
    // The stepper multiplies whatever was logged, so show the result in the user's own
    // units — stepping a 200 g entry to 1.5 reads "Amount: 300 g", not "Servings: 1.5".
    // Legacy measurement-less entries keep the bare count.
    private var amountLabel: String {
        if let measurement = entry.measurement {
            return "Amount: \(measurement.scaled(by: servings).displayText)"
        }
        return "Servings: \(servingsText)"
    }

    private var servingsText: String {
        servings.rounded() == servings ? String(Int(servings)) : String(format: "%.2f", servings)
    }
}
