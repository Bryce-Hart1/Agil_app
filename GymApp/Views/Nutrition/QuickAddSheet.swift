import SwiftUI

// CLAUDE  Date 09/30/2026
// Quick calories: log a bare kcal/macro amount with no food behind it, for eating out or
// estimating. Opened from the ⚡︎ beside a meal's Add food on the Log. Writes through
// AppStore.logQuickAdd; the entry stays editable in EditFoodEntryView's same fields.
struct QuickAddSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let date: Date
    @State private var meal: MealType
    @State private var time = Date()
    @State private var draft = QuickNutrientDraft()
    @State private var label = ""

    init(meal: MealType, date: Date) {
        self.date = date
        _meal = State(initialValue: meal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    QuickNutrientFields(draft: $draft, autofocus: true)
                } footer: {
                    Text("Leave calories blank to count them from the macros.")
                }
                Section {
                    TextField("Label (optional)", text: $label)
                    MealTimePicker(meal: $meal, time: $time, accent: theme.current.accent) { meal in
                        store.suggestedLogTime(for: meal, on: date)
                    }
                }
            }
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .fontWeight(.semibold)
                        .disabled(!draft.isLoggable)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        let name = label.trimmingCharacters(in: .whitespaces)
        store.logQuickAdd(name: name.isEmpty ? "quick add" : name, nutrients: draft.nutrients,
                          meal: meal, on: date, at: time)
        Haptics.success()
        dismiss()
    }
}

// CLAUDE  Date 09/30/2026
// The four quick-add numbers as typed text (so every keystroke counts, unlike a formatted
// TextField that only commits on return). Calories left blank are counted from the macros
// at 4/4/9 kcal per gram. Shared by QuickAddSheet and the entry editor.
struct QuickNutrientDraft: Equatable {
    var calories = ""
    var protein = ""
    var carbs = ""
    var fat = ""

    init() {}

    // Seed from a logged quick add; zeros stay blank so the fields read as untouched.
    init(_ n: Nutrients) {
        calories = Self.text(n.calories)
        protein = Self.text(n.protein)
        carbs = Self.text(n.carbs)
        fat = Self.text(n.fat)
    }

    var macroCalories: Double {
        4 * Self.parse(protein) + 4 * Self.parse(carbs) + 9 * Self.parse(fat)
    }

    var resolvedCalories: Double {
        let typed = calories.trimmingCharacters(in: .whitespaces)
        return typed.isEmpty ? macroCalories : Self.parse(typed)
    }

    var nutrients: Nutrients {
        Nutrients(calories: resolvedCalories, protein: Self.parse(protein),
                  carbs: Self.parse(carbs), fat: Self.parse(fat))
    }

    var isLoggable: Bool { resolvedCalories > 0 }

    // Accepts a comma decimal ("12,5") since the decimal pad types one in many locales.
    private static func parse(_ text: String) -> Double {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return max(0, Double(cleaned) ?? 0)
    }

    private static func text(_ value: Double) -> String {
        value > 0 ? FoodMeasurement.number(value, decimals: 1) : ""
    }
}

// CLAUDE  Date 09/30/2026
// Calories, protein, carbs and fat as right-aligned number rows (one Form row each). The
// calories placeholder shows the macro estimate once any macro is typed. `autofocus` puts
// the cursor in Calories when the sheet opens, since that's usually all a quick add needs.
struct QuickNutrientFields: View {
    @Binding var draft: QuickNutrientDraft
    var autofocus = false

    @FocusState private var caloriesFocused: Bool

    var body: some View {
        row("Calories", text: $draft.calories, unit: "kcal", placeholder: caloriesPlaceholder)
            .focused($caloriesFocused)
            .task {
                guard autofocus else { return }
                // A sheet ignores focus requests until its presentation settles.
                try? await Task.sleep(for: .milliseconds(450))
                caloriesFocused = true
            }
        row("Protein", text: $draft.protein, unit: "g", placeholder: "0")
        row("Carbs", text: $draft.carbs, unit: "g", placeholder: "0")
        row("Fat", text: $draft.fat, unit: "g", placeholder: "0")
    }

    private var caloriesPlaceholder: String {
        let estimate = draft.macroCalories
        return estimate > 0 ? "≈ \(Int(estimate.rounded()))" : "0"
    }

    private func row(_ title: String, text: Binding<String>, unit: String,
                     placeholder: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 110)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}
