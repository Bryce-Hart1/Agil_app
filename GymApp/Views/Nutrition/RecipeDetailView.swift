import SwiftUI
import UIKit

// Claude  Date 08/11/2026
// The recipe analog of FoodDetailView: what's in the dish, how to make it, what one
// serving costs you, and a bar to log it.
//
// It deliberately reuses the food pipeline rather than reimplementing it. A recipe
// presents itself as a count-based food of "servings" (Recipe.asFoodItem → FoodDetail),
// which means MeasurementEditor drives the servings multiplier for free — a count basis
// offers no unit tabs, just the amount field, stepper and preset chips, which is exactly
// the control a recipe needs. Logging then goes through the ordinary
// AppStore.logFoodDetail, so the diary gets one entry that reads "2 servings" and is
// re-dialable in the entry editor like any other food.
struct RecipeDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    // Meal to preselect (the diary picker passes the section the user tapped into);
    // nil falls back to the time-of-day guess.
    var initialMeal: MealType? = nil
    // The day to log onto. Today for the Foods tab; the diary picker passes its date.
    var date: Date = Date()
    // Opens the builder to edit this recipe. Nil = no edit affordance.
    var onEdit: (() -> Void)? = nil
    // Fired after the diary write. The page pops itself; a caller that presented it
    // inside a sheet (the diary's picker) uses this to close the whole sheet too.
    var onLogged: (() -> Void)? = nil

    @State private var selectedMeal: MealType = .snack
    // How many servings of the recipe are being logged, in the same FoodMeasurement
    // vocabulary every other amount in the app uses.
    @State private var measurement = FoodMeasurement(amount: 1, servingNoun: "serving")

    private var detail: FoodDetail { FoodDetail(from: recipe.asFoodItem) }
    private var basis: MeasurementBasis { MeasurementBasis(detail) }
    // Count basis, so the factor is simply the number of servings.
    private var factor: Double { measurement.per100Factor(in: basis) }

    private var accent: Color { theme.current.accent }
    private var surface: Color { theme.current.surface }

    // Instructions are optional in the real sense: blank means the user had nothing to
    // say, and the page draws no empty card for it (same rule FoodDetailView applies to
    // micronutrient groups with nothing reported).
    private var instructionsText: String? {
        guard let text = recipe.instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                MeasurementEditor(basis: basis, measurement: $measurement, accent: accent)
                macrosCard
                ingredientsCard
                if let instructionsText { instructionsCard(instructionsText) }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { logBar }
        .themed(theme.current)
        .toolbar {
            // Leading, so it never collides with a presenting sheet's Done button.
            if let onEdit {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit", action: onEdit)
                }
            }
        }
        .onAppear {
            selectedMeal = initialMeal ?? FoodDetailView.mealForNow()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipe.displayName)
                .font(.title2).fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)
            Text(yieldCaption)
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                FoodSourceBadge(source: .recipe, style: .detail)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var yieldCaption: String {
        let servings = FoodMeasurement.number(recipe.servingsYield)
        let noun = FoodMeasurement.pluralize("serving", count: recipe.servingsYield)
        let count = recipe.ingredients.count
        return "Makes \(servings) \(noun) · \(count) \(count == 1 ? "ingredient" : "ingredients")"
    }

    // MARK: - Macros

    private var macrosCard: some View {
        let n = detail.per100.scaled(by: factor)
        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(n.calories.rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text("kcal").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text("per \(measurement.displayText)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            VStack(spacing: 0) {
                macroRow("Protein", n.protein, "g", tint: MacroPalette.protein)
                macroRow("Carbs",   n.carbs,   "g", tint: MacroPalette.carbs)
                macroRow("Fat",     n.fat,     "g", tint: MacroPalette.fat)
                macroRow("Fiber",   n.fiber,   "g", tint: MacroPalette.fiber)
                macroRow("Sugar",   n.sugar,   "g", tint: MacroPalette.sugar)
                macroRow("Sodium",  n.sodium, "mg", tint: MacroPalette.sodium, last: true)
            }
        }
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: factor)
    }

    private func macroRow(_ label: String, _ value: Double, _ unit: String,
                          tint: Color, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(FoodMeasurement.number(value, decimals: 1)) \(unit)")
                    .font(.subheadline).monospacedDigit()
                    .foregroundStyle(tint)
            }
            .padding(.vertical, 8)
            if !last { Divider() }
        }
    }

    // MARK: - Ingredients

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ingredients").font(.headline).padding(.bottom, 8)
            if recipe.ingredients.isEmpty {
                Text("No ingredients yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { idx, item in
                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.displayName)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text(item.measurement.displayText)
                                .font(.subheadline).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        if idx != recipe.ingredients.count - 1 { Divider() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func instructionsCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions").font(.headline)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Log bar

    private var logBar: some View {
        let consumed = detail.per100.scaled(by: factor)
        return VStack(spacing: 10) {
            HStack {
                Text("Meal").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Picker("Meal", selection: $selectedMeal) {
                    ForEach(MealType.allCases) { meal in
                        Label(meal.title, systemImage: meal.systemImage).tag(meal)
                    }
                }
                .pickerStyle(.menu)
                .tint(accent)
            }
            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                store.logFoodDetail(detail, consumed: consumed, measurement: measurement,
                                    meal: selectedMeal, on: date)
                onLogged?()
                dismiss()
            } label: {
                Text("Add to \(selectedMeal.title) · \(Int(consumed.calories.rounded())) kcal")
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .disabled(factor <= 0 || recipe.ingredients.isEmpty)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: factor)
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
