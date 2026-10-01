import SwiftUI

// CLAUDE  Date 09/27/2026
// "Making a recipe": the Foods tab, the recipe builder, and the ingredient picker and
// amount step on sample foods. Never touches AppStore, and nothing here takes keyboard
// focus (the real amount editor is shown but inert; a tap fills in a sample amount).

// MARK: - Script

enum RecipeDemoRoute: Hashable {
    case amount
}

struct RecipeDemoIngredient: Identifiable {
    let id = UUID()
    let food: DemoFood
    let measurement: FoodMeasurement

    var nutrients: Nutrients { food.nutrients(for: measurement) }
}

struct RecipeDemoState {
    var showingBuilder = false
    var name: String?
    var showingPicker = false
    var pickerPath: [RecipeDemoRoute] = []
    var food: DemoFood?
    var measurement = FoodMeasurement(amount: 1, servingNoun: "serving")
    var ingredients: [RecipeDemoIngredient] = []
    var servings: Double = 1
    var isSaved = false

    var totals: Nutrients { ingredients.reduce(.zero) { $0 + $1.nutrients } }
    var perServing: Nutrients { totals.scaled(by: servings > 0 ? 1 / servings : 1) }
}

enum RecipeDemoAction: Equatable {
    case createRecipe
    case fillName
    case openPicker
    case pickFood(DemoFood)
    case setSampleAmount
    case addIngredient
    case addTheRest
    case setServings(Double)
    case save
}

enum RecipeDemoTarget: Hashable {
    case addButton, nameField, addIngredient, pickerRow, amount, commit, ingredientRow
    case servings, perServing, instructions, save, newRecipe
}

struct RecipeDemoScript: DemoScript {
    typealias Step = DemoStep<RecipeDemoAction, RecipeDemoTarget>

    let initialState = RecipeDemoState()

    let steps: [Step] = [
        Step(text: "On the Foods tab, tap + at the top right, then Create recipe.",
             target: .addButton, action: .createRecipe),
        Step(text: "Here you'd name the recipe. Tap to fill it in.",
             target: .nameField, effect: .fillName),
        Step(text: "Tap Add ingredient.",
             target: .addIngredient, action: .openPicker),
        Step(text: "Pick a food. You can also search, scan a barcode, or create one.",
             target: .pickerRow, action: .pickFood(DemoSamples.oats)),
        Step(text: "Here you'd set how much goes in, in servings or by weight. Tap to fill it in.",
             target: .amount, effect: .setSampleAmount),
        Step(text: "Tap Add ingredient.",
             target: .commit, action: .addIngredient),
        Step(text: "Add the rest the same way. Tap an ingredient to change its amount, or swipe it left to remove it.",
             target: .ingredientRow, effect: .addTheRest),
        Step(text: "Set how many servings it makes.",
             target: .servings, action: .setServings(2)),
        Step(text: "The macros for one serving are worked out for you. That's what gets logged when you add it to a meal.",
             target: .perServing),
        Step(text: "Steps, notes, and cook time are optional.",
             target: .instructions),
        Step(text: "Tap Save.",
             target: .save, action: .save),
        Step(text: "It's under Recipes now. Log a serving from any meal, like any other food.",
             target: .newRecipe)
    ]

    func apply(_ action: RecipeDemoAction, to state: inout RecipeDemoState) {
        switch action {
        case .createRecipe:
            state.showingBuilder = true
        case .fillName:
            state.name = "Overnight Oats"
        case .openPicker:
            state.showingPicker = true
        case .pickFood(let food):
            state.food = food
            state.measurement = food.basis.defaultMeasurement
            state.pickerPath = [.amount]
        case .setSampleAmount:
            state.measurement = state.measurement.scaled(by: 2)
        case .addIngredient:
            if let food = state.food {
                state.ingredients.append(RecipeDemoIngredient(food: food, measurement: state.measurement))
            }
            state.showingPicker = false
            state.pickerPath = []
            state.food = nil
        case .addTheRest:
            let serving = FoodMeasurement(amount: 1, servingNoun: "serving")
            state.ingredients.append(RecipeDemoIngredient(food: DemoSamples.greekYogurt, measurement: serving))
            state.ingredients.append(RecipeDemoIngredient(food: DemoSamples.banana, measurement: serving))
        case .setServings(let servings):
            state.servings = servings
        case .save:
            state.showingBuilder = false
            state.isSaved = true
        }
    }

    // Any food and any number of servings count.
    func matches(_ attempted: RecipeDemoAction, expected: RecipeDemoAction) -> Bool {
        switch (attempted, expected) {
        case (.pickFood, .pickFood), (.setServings, .setServings):
            return true
        default:
            return attempted == expected
        }
    }
}

// MARK: - Shell

struct RecipeDemoShell: View {
    @ObservedObject var runner: DemoRunner<RecipeDemoScript>

    private var state: RecipeDemoState { runner.state }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                DemoFoodsScreen(newRecipe: state.isSaved ? newRow : nil,
                                highlightNew: runner.isTarget(.newRecipe),
                                nudges: runner.nudges,
                                onNudge: { runner.nudge() }) {
                    Menu {
                        Button {
                            runner.nudge()
                        } label: {
                            Label("Create custom food", systemImage: "plus.circle")
                        }
                        Button {
                            runner.attempt(.createRecipe)
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
            }
            DemoTabBar(mode: .nutrition, selectedTag: AgilTabItem.foods.tag) { _ in runner.nudge() }
        }
        .overlay {
            DemoSheet(isPresented: state.showingBuilder) {
                RecipeDemoBuilder(runner: runner)
            }
        }
        .overlay {
            // The picker is a sheet over the builder's sheet, so it sits a little lower.
            DemoSheet(isPresented: state.showingPicker, topInset: 44) {
                NavigationStack(path: Binding(get: { state.pickerPath }, set: { _ in })) {
                    DemoFoodPickerList(title: "Add ingredient",
                                       showsCreateRecipe: false,
                                       highlighted: runner.isTarget(.pickerRow) ? DemoSamples.oats.id : nil,
                                       nudges: runner.nudges,
                                       onPick: { runner.attempt(.pickFood($0)) },
                                       onNudge: { runner.nudge() })
                        .navigationDestination(for: RecipeDemoRoute.self) { _ in
                            RecipeDemoAmountPage(runner: runner)
                        }
                }
            }
        }
    }

    // Same caption the Foods tab gives a recipe: one serving's calories.
    private var newRow: DemoListRow {
        DemoListRow(name: state.name ?? "Overnight Oats",
                    caption: "\(Int(state.perServing.calories.rounded())) kcal · 1 serving")
    }
}

// MARK: - Recipe builder

// CLAUDE  Date 09/27/2026
// Copy of RecipeBuilderView: name, ingredients with the whole-recipe footer, the servings
// stepper with the per-serving footer, and instructions. Name and instructions are
// display only; the stepper is the real control over demo state.
private struct RecipeDemoBuilder: View {
    @ObservedObject var runner: DemoRunner<RecipeDemoScript>

    @EnvironmentObject private var theme: ThemeManager

    private var state: RecipeDemoState { runner.state }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    DemoFieldText(value: state.name, placeholder: "Name")
                        .onTapGesture { runner.acknowledge(.nameField) }
                        .demoHighlight(runner.isTarget(.nameField), nudges: runner.nudges, inset: -4)
                }
                ingredientsSection
                servingsSection
                Section {
                    DemoFieldText(value: nil, placeholder: "Steps, notes, cook time…")
                        .frame(minHeight: 120, alignment: .topLeading)
                        .onTapGesture { runner.acknowledge(.instructions) }
                        .demoHighlight(runner.isTarget(.instructions), nudges: runner.nudges, inset: -4)
                } header: {
                    Text("Instructions (optional)")
                } footer: {
                    Text("Leave this blank if the ingredient list is the whole recipe.")
                }
            }
            .navigationTitle("New Recipe")
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

    private var ingredientsSection: some View {
        Section {
            ForEach(Array(state.ingredients.enumerated()), id: \.element.id) { index, item in
                ingredientRow(item)
                    .swipeActions(edge: .trailing) {
                        Button {
                            runner.acknowledge(.ingredientRow)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                    .demoHighlight(index == 0 && runner.isTarget(.ingredientRow),
                                   nudges: runner.nudges, inset: -4)
            }
            Button {
                runner.attempt(.openPicker)
            } label: {
                Label("Add ingredient", systemImage: "plus.circle")
            }
            .demoHighlight(runner.isTarget(.addIngredient), nudges: runner.nudges)
        } header: {
            Text("Ingredients")
        } footer: {
            if state.ingredients.isEmpty {
                Text("Search for generic or branded foods and set how much of each goes in.")
            } else {
                let t = state.totals
                Text("Whole recipe: \(Int(t.calories.rounded())) kcal · P \(macro(t.protein)) C \(macro(t.carbs)) F \(macro(t.fat)). Tap an ingredient to change its amount.")
            }
        }
    }

    private func ingredientRow(_ item: RecipeDemoIngredient) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.food.name)
                    .font(.subheadline)
                    .foodNameFont()
                Text("\(Int(item.nutrients.calories.rounded())) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(item.measurement.displayText)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { runner.acknowledge(.ingredientRow) }
    }

    private var servingsSection: some View {
        let p = state.perServing
        return Section {
            Stepper(value: Binding(get: { state.servings },
                                   set: { runner.attempt(.setServings($0)) }),
                    in: 1...99, step: 1) {
                Text("Makes \(FoodMeasurement.number(state.servings)) \(FoodMeasurement.pluralize("serving", count: state.servings))")
            }
            .demoHighlight(runner.isTarget(.servings), nudges: runner.nudges, inset: -4)
        } header: {
            Text("Servings")
        } footer: {
            Text("One serving: \(Int(p.calories.rounded())) kcal · P \(macro(p.protein)) C \(macro(p.carbs)) F \(macro(p.fat)). This is what gets logged when you add the recipe to a meal.")
                .demoHighlight(runner.isTarget(.perServing), nudges: runner.nudges, inset: -4)
        }
    }

    private func macro(_ value: Double) -> String {
        "\(FoodMeasurement.number(value, decimals: 1))g"
    }
}

// MARK: - Ingredient amount

// CLAUDE  Date 09/27/2026
// Copy of IngredientAmountView: the food's name, the real MeasurementEditor (inert), the
// calorie and macro card, and Add ingredient pinned to the bottom.
private struct RecipeDemoAmountPage: View {
    @ObservedObject var runner: DemoRunner<RecipeDemoScript>

    @EnvironmentObject private var theme: ThemeManager

    private var state: RecipeDemoState { runner.state }

    var body: some View {
        Group {
            if let food = state.food {
                ScrollView {
                    VStack(spacing: 14) {
                        Text(food.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foodNameFont()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        MeasurementEditor(basis: food.basis,
                                          measurement: Binding(get: { state.measurement }, set: { _ in }),
                                          accent: theme.current.accent)
                            .demoInert { runner.acknowledge(.amount) }
                            .demoHighlight(runner.isTarget(.amount), nudges: runner.nudges, inset: -6)
                        DemoNutritionCard(nutrients: food.nutrients(for: state.measurement),
                                          caption: "per \(state.measurement.displayText)")
                    }
                    .padding(16)
                }
                .background(theme.current.background.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) { commitBar }
            }
        }
        .navigationTitle("Amount")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DemoBackButton(title: "Back") { runner.nudge() }
            }
        }
    }

    private var commitBar: some View {
        Button {
            runner.attempt(.addIngredient)
        } label: {
            Text("Add ingredient")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.current.accent)
        .controlSize(.large)
        .demoHighlight(runner.isTarget(.commit), nudges: runner.nudges, cornerRadius: 12, inset: -4)
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
