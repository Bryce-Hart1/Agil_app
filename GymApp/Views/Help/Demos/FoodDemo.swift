import SwiftUI

// CLAUDE  Date 09/27/2026
// "Adding a custom food": the Foods tab and the New Food form on sample data. Every field
// is display only; tapping one fills in a sample value. Never touches AppStore, the
// camera, or the review queue.

// MARK: - Script

struct FoodDemoState {
    var tab = AgilTabItem.journal.tag
    var showingNew = false
    var name: String?
    var brand: String?
    var barcode: String?
    var servingSize = "100"
    var servingUnit = "g"
    var calories = "0", protein = "0", carbs = "0", fat = "0"
    var sendForReview = true
    var isSaved = false
}

enum FoodDemoAction: Equatable {
    case selectTab(Int)
    case createFood
    case fillName
    case scanBarcode
    case fillServing
    case fillNutrition
    case save
}

enum FoodDemoTarget: Hashable {
    case foodsTab, addButton, nameFields, kindPicker, barcodeRow, serving, nutrition
    case extras, shareToggle, save, newFood
}

struct FoodDemoScript: DemoScript {
    typealias Step = DemoStep<FoodDemoAction, FoodDemoTarget>

    let initialState = FoodDemoState()

    let steps: [Step] = [
        Step(text: "On the Food side, tap Foods in the tab bar.",
             target: .foodsTab, action: .selectTab(AgilTabItem.foods.tag)),
        Step(text: "Tap + at the top right, then Create custom food.",
             target: .addButton, action: .createFood),
        Step(text: "Here you'd type the food's name and brand. Tap to fill them in.",
             target: .nameFields, effect: .fillName),
        Step(text: "Pick Packaged, Restaurant, or Generic. Only packaged food has a barcode.",
             target: .kindPicker),
        Step(text: "Tap the camera to scan the barcode. Without one, the food stays on your phone only.",
             target: .barcodeRow, effect: .scanBarcode),
        Step(text: "Here you'd enter the serving size from the label. Tap to fill it in.",
             target: .serving, effect: .fillServing),
        Step(text: "Then the calories, protein, carbs, and fat per serving. Tap to fill them in.",
             target: .nutrition, effect: .fillNutrition),
        Step(text: "Fiber, sugar, sodium, and micronutrients are optional. Leave out anything the label doesn't list.",
             target: .extras),
        Step(text: "Send for review puts it in line to become a verified food for everyone. It needs Friends mode.",
             target: .shareToggle),
        Step(text: "Tap Save.",
             target: .save, action: .save),
        Step(text: "It's in your foods now, ready to log to any meal.",
             target: .newFood)
    ]

    func apply(_ action: FoodDemoAction, to state: inout FoodDemoState) {
        switch action {
        case .selectTab(let tag):
            state.tab = tag
        case .createFood:
            state.showingNew = true
        case .fillName:
            state.name = "Protein Bar"
            state.brand = "Summit"
        case .scanBarcode:
            state.barcode = "012345678905"
        case .fillServing:
            state.servingSize = "60"
        case .fillNutrition:
            state.calories = "230"
            state.protein = "20"
            state.carbs = "24"
            state.fat = "8"
        case .save:
            state.showingNew = false
            state.isSaved = true
        }
    }
}

// MARK: - Shell

struct FoodDemoShell: View {
    @ObservedObject var runner: DemoRunner<FoodDemoScript>

    private var state: FoodDemoState { runner.state }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                if state.tab == AgilTabItem.foods.tag {
                    DemoFoodsScreen(newFood: state.isSaved ? newRow : nil,
                                    highlightNew: runner.isTarget(.newFood),
                                    nudges: runner.nudges,
                                    onNudge: { runner.nudge() }) {
                        Menu {
                            Button {
                                runner.attempt(.createFood)
                            } label: {
                                Label("Create custom food", systemImage: "plus.circle")
                            }
                            Button {
                                runner.nudge()
                            } label: {
                                Label("Create recipe", systemImage: "list.bullet.rectangle")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add a food or recipe")
                        .demoHighlight(runner.isTarget(.addButton), nudges: runner.nudges,
                                       cornerRadius: 8, inset: -8)
                    }
                } else {
                    DemoJournalScreen(onNudge: { runner.nudge() })
                }
            }
            .id(state.tab)
            DemoTabBar(mode: .nutrition, selectedTag: state.tab,
                       highlightedTag: runner.isTarget(.foodsTab) ? AgilTabItem.foods.tag : nil,
                       nudges: runner.nudges) { runner.attempt(.selectTab($0)) }
        }
        .overlay {
            DemoSheet(isPresented: state.showingNew) {
                FoodDemoForm(runner: runner)
            }
        }
    }

    private var newRow: DemoListRow {
        DemoListRow(name: state.name ?? "Protein Bar",
                    caption: "\(state.brand ?? "Summit") · \(state.calories) kcal · \(state.servingSize) \(state.servingUnit)")
    }
}

// MARK: - New Food form

// CLAUDE  Date 09/27/2026
// Copy of NewFoodView for a packaged food: name and brand, kind, barcode, serving,
// nutrition, extras, and the review toggle. Fields are text, never TextFields; the review
// toggle is free to flip since it's local demo state.
private struct FoodDemoForm: View {
    @ObservedObject var runner: DemoRunner<FoodDemoScript>

    @EnvironmentObject private var theme: ThemeManager

    private var state: FoodDemoState { runner.state }
    private var hasBarcode: Bool { state.barcode != nil }
    private var barcodeTint: Color { hasBarcode ? FoodSourcePalette.verifiedStack : .red }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    field(state.name, "Name", target: .nameFields)
                    field(state.brand, "Brand / restaurant (optional)", target: .nameFields)
                }

                Section {
                    Picker("Kind", selection: .constant("Packaged")) {
                        ForEach(["Packaged", "Restaurant", "Generic"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .demoInert { runner.acknowledge(.kindPicker) }
                    .demoHighlight(runner.isTarget(.kindPicker), nudges: runner.nudges, inset: -4)
                } header: {
                    Text("Kind")
                } footer: {
                    Text("A branded product with a barcode on the package.")
                }

                barcodeSection

                Section("Serving") {
                    LabeledContent("Size") { Text(state.servingSize) }
                        .onTapGesture { runner.acknowledge(.serving) }
                        .demoHighlight(runner.isTarget(.serving), nudges: runner.nudges, inset: -4)
                    Text(state.servingUnit)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { runner.acknowledge(.serving) }
                        .demoHighlight(runner.isTarget(.serving), nudges: runner.nudges, inset: -4)
                }

                Section("Nutrition per serving") {
                    macroRow("Calories (kcal)", state.calories, target: .nutrition)
                    macroRow("Protein (g)", state.protein, target: .nutrition)
                    macroRow("Carbs (g)", state.carbs, target: .nutrition)
                    macroRow("Fat (g)", state.fat, target: .nutrition)
                }

                Section("Extras (optional)") {
                    macroRow("Fiber (g)", "0", target: .extras)
                    macroRow("Sugar (g)", "0", target: .extras)
                    macroRow("Sodium (mg)", "0", target: .extras)
                }

                Section {
                    Toggle("Send for review", isOn: $runner.state.sendForReview)
                        .demoHighlight(runner.isTarget(.shareToggle), nudges: runner.nudges, inset: -4)
                } header: {
                    Text("Agil database")
                } footer: {
                    Text("Your entry joins the review queue. Once it's checked it becomes a verified food for everyone.")
                }
            }
            .navigationTitle("New Food")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { runner.nudge() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { runner.attempt(.save) }
                        .demoHighlight(runner.isTarget(.save), nudges: runner.nudges,
                                       cornerRadius: 8, inset: -6)
                }
            }
        }
    }

    private func field(_ value: String?, _ placeholder: String, target: FoodDemoTarget) -> some View {
        DemoFieldText(value: value, placeholder: placeholder)
            .onTapGesture { runner.acknowledge(target) }
            .demoHighlight(runner.isTarget(target), nudges: runner.nudges, inset: -4)
    }

    // Same layout as NewFoodView.macroField: label left, value right.
    private func macroRow(_ label: String, _ value: String, target: FoodDemoTarget) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(value == "0" ? Color(uiColor: .placeholderText) : Color.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture { runner.acknowledge(target) }
        .demoHighlight(runner.isTarget(target), nudges: runner.nudges, inset: -4)
    }

    // The barcode row: red until scanned, then green with the digits. Tapping the camera
    // (or the row) is the scan step.
    private var barcodeSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: hasBarcode ? "checkmark.circle.fill" : "barcode")
                    .font(.title3)
                    .foregroundStyle(barcodeTint)
                DemoFieldText(value: state.barcode, placeholder: "Barcode digits")
                    .font(.body.monospacedDigit())
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .padding(8)
                    .background(theme.current.accent.opacity(0.15), in: Circle())
                    .foregroundStyle(theme.current.accent)
            }
            .contentShape(Rectangle())
            .onTapGesture { runner.acknowledge(.barcodeRow) }
            .demoHighlight(runner.isTarget(.barcodeRow), nudges: runner.nudges, inset: -4)
            .listRowBackground(barcodeTint.opacity(0.12))
        } header: {
            Text("Barcode")
        } footer: {
            Text(hasBarcode
                 ? "Scanned. This food can be verified into the Agil database once it's reviewed."
                 : "No barcode yet. Tap the camera to scan the package. Without one this food stays on your device only.")
                .foregroundStyle(hasBarcode ? Color.secondary : barcodeTint)
        }
    }
}
