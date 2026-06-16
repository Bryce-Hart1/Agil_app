import SwiftUI

// Claude  Date 06/16/2026
// Edit the daily nutrition targets the diary fills toward. Edits commit live to the
// store (which auto-persists), so there's no separate save step — mirrors how the
// theme/profile editors write straight through. Reached from the Diary's target
// button.
struct NutritionGoalsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        Form {
            Section("Daily targets") {
                goalField("Calories (kcal)", value: $store.nutritionGoals.calories)
                goalField("Protein (g)", value: $store.nutritionGoals.protein)
                goalField("Carbs (g)", value: $store.nutritionGoals.carbs)
                goalField("Fat (g)", value: $store.nutritionGoals.fat)
            }

            Section {
                goalField("Water (ml)", value: $store.nutritionGoals.water)
            } header: {
                Text("Water")
            } footer: {
                // Claude  Date 06/16/2026
                // Macro grams aren't auto-derived from the calorie goal yet — set
                // them independently for now (a "calculate from calories" helper is
                // a natural later addition).
                Text("Set protein, carbs, and fat to match your calorie goal as you like.")
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
    }

    private func goalField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack { NutritionGoalsView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
