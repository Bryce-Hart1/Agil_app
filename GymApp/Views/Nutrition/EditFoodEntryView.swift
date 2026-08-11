import SwiftUI

// Claude  Date 06/16/2026 last changed: 08/06/2026 by: Claude
// Edit an already-logged diary entry: re-dial the amount with the same controls the
// food detail page uses, change which meal it belongs to, see the totals recompute
// live, then save — or delete it. The food's name is preserved (you're correcting the
// log, not redefining the food).
//
// (Was a bare servings stepper. Every entry logged through the detail page stores
// `servings: 1` with the whole portion folded into `nutrients`, so that stepper was
// multiplying a total it labelled "per serving" — bumping it to 2 silently doubled a
// 250 g portion with nothing on screen saying so, and there was no way to say "actually
// it was 180 g". With the measurement and the food's per-100 basis both on the entry,
// the amount is now genuinely re-dialable: pick 180 g, or switch to ounces, and the
// nutrients are recomputed from the basis exactly the way the detail page computes
// them. Entries logged before those fields existed have no basis to recompute from, so
// they keep the old stepper — see `FoodEntry.isRedialable`.)
struct EditFoodEntryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let entry: FoodEntry

    // The re-dialable path: the amount as the user is now expressing it.
    @State private var measurement: FoodMeasurement
    // The legacy path: a bare multiplier over the frozen nutrient snapshot.
    @State private var servings: Double
    @State private var meal: MealType

    init(entry: FoodEntry) {
        self.entry = entry
        _measurement = State(initialValue: entry.measurement
                             ?? FoodMeasurement(amount: entry.servings,
                                                servingNoun: "serving"))
        _servings = State(initialValue: entry.servings)
        _meal = State(initialValue: entry.mealType)
    }

    // Claude  Date 08/06/2026
    // What the entry would be after the edit. With a basis the nutrients are rebuilt
    // from the food's per-100 values at the new amount — the same arithmetic
    // FoodDetailView does — so changing 200 g to 250 g is a real recompute, not a
    // multiplication of a rounded total. Without one, fall back to scaling the
    // snapshot.
    private var consumed: Nutrients {
        if let basis = entry.basis, entry.measurement != nil {
            return basis.per100.scaled(by: measurement.per100Factor(in: basis))
        }
        return entry.nutrients.scaled(by: servings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(entry.name).font(.headline)
                    Text(loggedCaption)
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Amount") {
                    if let basis = entry.basis, entry.measurement != nil {
                        MeasurementEditor(basis: basis, measurement: $measurement,
                                          accent: theme.current.accent)
                            .padding(.vertical, 4)
                    } else {
                        Stepper(value: $servings, in: 0.25...50, step: 0.25) {
                            Text("Servings: \(servingsText)")
                        }
                    }
                }

                Section("Meal") {
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

    // Claude  Date 08/06/2026
    // What was originally logged. For anything logged through the detail page,
    // `nutrients` is the WHOLE portion and `servings` is 1 — so the old
    // "Per serving: N kcal" was really the total, and reading it as a serving size made
    // the control below look like it did something other than what it does.
    private var loggedCaption: String {
        let kcal = Int(entry.consumed.calories.rounded())
        if let original = entry.measurement {
            return "Logged: \(original.displayText) · \(kcal) kcal"
        }
        return "Per serving: \(Int(entry.nutrients.calories.rounded())) kcal"
    }

    // Claude  Date 06/16/2026 last changed: 08/06/2026 by: Claude
    // Write the edit back. On the re-dialable path the nutrient snapshot is REPLACED
    // with the recomputed portion and `servings` pinned to 1, matching exactly what
    // `logFoodDetail` writes — so an edited entry is indistinguishable from one logged
    // at that amount in the first place. The new amount also updates this food's
    // remembered measurement, since it's the most recent statement of how the user
    // measures it.
    private func save() {
        var updated = entry
        updated.mealType = meal
        if let basis = entry.basis, entry.measurement != nil {
            updated.nutrients = basis.per100.scaled(by: measurement.per100Factor(in: basis))
            updated.servings = 1
            updated.measurement = measurement
        } else {
            updated.servings = servings
        }
        store.updateFoodEntry(updated)
        dismiss()
    }

    private var servingsText: String {
        servings.rounded() == servings ? String(Int(servings)) : String(format: "%.2f", servings)
    }
}
