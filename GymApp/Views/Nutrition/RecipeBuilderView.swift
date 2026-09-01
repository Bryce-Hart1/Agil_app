import SwiftUI

// Claude  Date 08/11/2026
// Create or edit a recipe: a name, what goes in it, how many servings it makes, and an
// optional method. The recipe analog of NewFoodView — save is local and immediate, with
// no backend submission step (recipes are the user's own and the server has no concept
// of them).
//
// Ingredients are picked through the SAME food search the diary uses (FoodPickerView in
// its ingredient-picking mode), so a recipe can be built out of anything the app can
// find — generic, branded, restaurant or the user's own foods — without a second search
// implementation to keep in sync.
struct RecipeBuilderView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    // The recipe being edited, or nil to create a new one.
    var editing: Recipe? = nil
    var initialName: String = ""
    var onSave: (Recipe) -> Void = { _ in }

    @State private var name: String
    @State private var instructions: String
    @State private var ingredients: [RecipeIngredient]
    @State private var servingsYield: Double

    @State private var showingIngredientPicker = false
    // The ingredient whose amount is being re-dialed (tapped in the list).
    @State private var editingIngredient: RecipeIngredient?

    init(editing: Recipe? = nil, initialName: String = "",
         onSave: @escaping (Recipe) -> Void = { _ in }) {
        self.editing = editing
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: editing?.name ?? initialName)
        _instructions = State(initialValue: editing?.instructions ?? "")
        _ingredients = State(initialValue: editing?.ingredients ?? [])
        _servingsYield = State(initialValue: editing?.servingsYield ?? 1)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && !ingredients.isEmpty }

    private var totals: Nutrients {
        ingredients.reduce(.zero) { $0 + $1.consumedNutrients }
    }
    private var perServing: Nutrients {
        totals.scaled(by: servingsYield > 0 ? 1 / servingsYield : 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name)
                }

                ingredientsSection
                yieldSection
                instructionsSection
            }
            .navigationTitle(editing == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingIngredientPicker) {
                FoodPickerView(onPickIngredient: { ingredient in
                    ingredients.append(ingredient)
                })
            }
            // Re-dialing an existing ingredient works off its FROZEN basis, not the
            // library food it came from — that food may have been edited or deleted
            // since, and the recipe's numbers are the user's, not the library's.
            .sheet(item: $editingIngredient) { item in
                NavigationStack {
                    IngredientAmountView(editing: item) { updated in
                        if let index = ingredients.firstIndex(where: { $0.id == updated.id }) {
                            ingredients[index] = updated
                        }
                    }
                }
                .themed(theme.current)
            }
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        Section {
            ForEach(ingredients) { item in
                Button { editingIngredient = item } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text("\(Int(item.consumedNutrients.calories.rounded())) kcal")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text(item.measurement.displayText)
                            .font(.subheadline).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in ingredients.remove(atOffsets: offsets) }

            Button {
                showingIngredientPicker = true
            } label: {
                Label("Add ingredient", systemImage: "plus.circle")
            }
        } header: {
            Text("Ingredients")
        } footer: {
            if ingredients.isEmpty {
                Text("Search for generic or branded foods and set how much of each goes in.")
            } else {
                Text("Whole recipe: \(Int(totals.calories.rounded())) kcal · P \(macro(totals.protein)) C \(macro(totals.carbs)) F \(macro(totals.fat)). Tap an ingredient to change its amount.")
            }
        }
    }

    // MARK: - Yield

    private var yieldSection: some View {
        Section {
            Stepper(value: $servingsYield, in: 1...99, step: 1) {
                Text("Makes \(FoodMeasurement.number(servingsYield)) \(FoodMeasurement.pluralize("serving", count: servingsYield))")
            }
        } header: {
            Text("Servings")
        } footer: {
            Text("One serving: \(Int(perServing.calories.rounded())) kcal · P \(macro(perServing.protein)) C \(macro(perServing.carbs)) F \(macro(perServing.fat)). This is what gets logged when you add the recipe to a meal.")
        }
    }

    private func macro(_ value: Double) -> String {
        "\(FoodMeasurement.number(value, decimals: 1))g"
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        Section {
            // Claude  Date 08/11/2026
            // A plain TextEditor has no placeholder, and an empty box with no prompt reads
            // as broken rather than optional — hence the overlay hint, dropped the moment
            // there's text.
            TextEditor(text: $instructions)
                .frame(minHeight: 120)
                .overlay(alignment: .topLeading) {
                    if instructions.isEmpty {
                        Text("Steps, notes, cook time…")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        } header: {
            Text("Instructions (optional)")
        } footer: {
            Text("Leave this blank if the ingredient list is the whole recipe.")
        }
    }

    // MARK: - Save

    private func save() {
        let text = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipe = Recipe(id: editing?.id ?? UUID(),
                            name: trimmedName,
                            instructions: text.isEmpty ? nil : text,
                            ingredients: ingredients,
                            servingsYield: servingsYield)
        if editing == nil {
            store.addRecipe(recipe)
        } else {
            store.updateRecipe(recipe)
        }
        onSave(recipe)
        dismiss()
    }
}

// Claude  Date 08/11/2026
// The amount step for one ingredient — how much of this food goes in the recipe. Drives
// the same MeasurementEditor the food detail page and the diary editor use, so an
// ingredient can be expressed in whatever unit makes sense for it (200 g of chicken,
// 2 cups of stock, 1 bar).
//
// It takes a name + basis rather than a FoodItem so it can also RE-DIAL an ingredient
// that's already in a recipe, where the source food may no longer exist — the frozen
// basis is the whole point of the snapshot.
struct IngredientAmountView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let name: String
    let foodId: UUID?
    let basis: MeasurementBasis
    // Non-nil when re-dialing an existing ingredient, so the rebuilt one keeps its identity.
    var ingredientId: UUID? = nil
    var initialMeasurement: FoodMeasurement? = nil
    let onCommit: (RecipeIngredient) -> Void

    @State private var measurement = FoodMeasurement(amount: 1, servingNoun: "serving")

    init(food: FoodItem, onCommit: @escaping (RecipeIngredient) -> Void) {
        let detail = FoodDetail(from: food)
        self.name = food.snapshotLabel
        self.foodId = food.id
        self.basis = MeasurementBasis(detail)
        self.ingredientId = nil
        self.initialMeasurement = nil
        self.onCommit = onCommit
    }

    init(editing ingredient: RecipeIngredient,
         onCommit: @escaping (RecipeIngredient) -> Void) {
        self.name = ingredient.name
        self.foodId = ingredient.foodId
        self.basis = ingredient.basis
        self.ingredientId = ingredient.id
        self.initialMeasurement = ingredient.measurement
        self.onCommit = onCommit
    }

    private var accent: Color { theme.current.accent }
    private var factor: Double { measurement.per100Factor(in: basis) }
    private var consumed: Nutrients { basis.per100.scaled(by: factor) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(name.foodDisplayCased)
                    .font(.title3).fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                MeasurementEditor(basis: basis, measurement: $measurement, accent: accent)
                summaryCard
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle("Amount")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { commitBar }
        .themed(theme.current)
        .onAppear {
            if let initialMeasurement, initialMeasurement.isValid(for: basis) {
                measurement = initialMeasurement
            } else {
                measurement = basis.defaultMeasurement
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(consumed.calories.rounded()))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                Text("kcal").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text("per \(measurement.displayText)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                macroLabel("Protein", consumed.protein, MacroPalette.protein)
                Spacer()
                macroLabel("Carbs", consumed.carbs, MacroPalette.carbs)
                Spacer()
                macroLabel("Fat", consumed.fat, MacroPalette.fat)
            }
        }
        .padding(16)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: factor)
    }

    private func macroLabel(_ label: String, _ value: Double, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(FoodMeasurement.number(value, decimals: 1))g")
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var commitBar: some View {
        Button {
            onCommit(RecipeIngredient(id: ingredientId ?? UUID(), foodId: foodId,
                                      name: name, measurement: measurement, basis: basis))
            dismiss()
        } label: {
            Text(ingredientId == nil ? "Add ingredient" : "Save amount")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .controlSize(.large)
        .disabled(factor <= 0)
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
