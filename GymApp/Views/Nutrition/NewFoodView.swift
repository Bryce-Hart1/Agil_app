import SwiftUI

// Claude  Date 06/16/2026
// Form sheet for adding a custom food to the library — the nutrition analog of
// NewExerciseView. You define one reference serving and its nutrients; logging
// later multiplies by a serving count. Calls `onCreate` with the saved food (the
// picker uses that to jump straight into logging it), then dismisses.
struct NewFoodView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let initialName: String
    // Claude  Date 06/18/2026
    // When the user creates a food after a barcode scan found nothing, the scanned code
    // is carried here so it's stored on the food (and remembered in the cache, so a
    // future scan of the same product resolves to it).
    let initialBarcode: String?
    let onCreate: (FoodItem) -> Void

    @State private var name: String
    @State private var brand = ""
    @State private var servingSize: Double = 100
    @State private var servingUnit = "g"
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var fiber: Double = 0
    @State private var sugar: Double = 0
    @State private var sodium: Double = 0

    init(initialName: String = "", initialBarcode: String? = nil,
         onCreate: @escaping (FoodItem) -> Void = { _ in }) {
        self.initialName = initialName
        self.initialBarcode = initialBarcode
        self.onCreate = onCreate
        _name = State(initialValue: initialName)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    if let barcode = initialBarcode, !barcode.isEmpty {
                        LabeledContent("Barcode", value: barcode)
                            .font(.footnote)
                    }
                }

                Section("Serving") {
                    LabeledContent("Size") {
                        TextField("Size", value: $servingSize, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    TextField("Unit (g, ml, cup…)", text: $servingUnit)
                }

                Section {
                    macroField("Calories (kcal)", value: $calories)
                    macroField("Protein (g)", value: $protein)
                    macroField("Carbs (g)", value: $carbs)
                    macroField("Fat (g)", value: $fat)
                } header: {
                    Text("Nutrition per serving")
                }

                Section("Extras (optional)") {
                    macroField("Fiber (g)", value: $fiber)
                    macroField("Sugar (g)", value: $sugar)
                    macroField("Sodium (mg)", value: $sodium)
                }
            }
            .navigationTitle("New Food")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    // Claude  Date 06/16/2026
    // A labeled right-aligned decimal field for one nutrient.
    private func macroField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
    }

    private func save() {
        let unit = servingUnit.trimmingCharacters(in: .whitespaces)
        let barcode = initialBarcode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let food = store.addFood(FoodItem(
            name: trimmedName,
            brand: brand.trimmingCharacters(in: .whitespaces),
            barcode: (barcode?.isEmpty == false) ? barcode : nil,
            servingSize: servingSize > 0 ? servingSize : 1,
            servingUnit: unit.isEmpty ? "serving" : unit,
            nutrients: Nutrients(calories: calories, protein: protein, carbs: carbs,
                                 fat: fat, fiber: fiber, sugar: sugar, sodium: sodium),
            source: .custom))
        // Claude  Date 06/18/2026 — remember the scanned barcode so a future scan of the
        // same product resolves straight to this food (no "not found" again).
        if let barcode, !barcode.isEmpty {
            store.rememberScannedFood(food, forBarcode: barcode)
        }
        onCreate(food)
        dismiss()
    }
}

#Preview {
    NewFoodView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
