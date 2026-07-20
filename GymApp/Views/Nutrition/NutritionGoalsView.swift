import SwiftUI

// Claude  Date 06/16/2026 last changed: 07/12/2026 by: Claude
// Edit the daily nutrition targets the diary fills toward. Edits commit live to the
// store (which auto-persists), so there's no separate save step — mirrors how the
// theme/profile editors write straight through. Reached from the Diary's target
// button. (This pass added the macro calculator: pick a preset calorie split or a
// custom one, preview the gram values, and explicitly apply them to the goals —
// manual entry of the gram fields stays fully available.)
struct NutritionGoalsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Claude  Date 07/16/2026
    // Water display unit (Settings → Water). The goal stays stored in ml; the field
    // below edits it through a converting binding.
    @AppStorage(WaterUnit.storageKey) private var waterUnitRaw = WaterUnit.milliliters.rawValue
    private var waterUnit: WaterUnit { WaterUnit(rawValue: waterUnitRaw) ?? .milliliters }

    // Claude  Date 07/12/2026
    // The calculator's split choices. The named presets carry fixed percentages of
    // calories (protein/carbs/fat); .custom reads the slider state instead.
    private enum SplitChoice: String, CaseIterable, Identifiable {
        case balanced, highProtein, lowCarb, custom
        var id: String { rawValue }

        var title: String {
            switch self {
            case .balanced:    return "Balanced"
            case .highProtein: return "High protein"
            case .lowCarb:     return "Low carb"
            case .custom:      return "Custom"
            }
        }

        /// Fixed percentages for presets; nil for .custom (comes from the sliders).
        var percentages: (protein: Double, carbs: Double, fat: Double)? {
            switch self {
            case .balanced:    return (30, 40, 30)
            case .highProtein: return (40, 30, 30)
            case .lowCarb:     return (35, 25, 40)
            case .custom:      return nil
            }
        }
    }

    private enum Macro: Hashable, CaseIterable { case protein, carbs, fat }

    @State private var split: SplitChoice = .balanced
    // Claude  Date 07/12/2026
    // Custom-split slider values, always kept summing to 100 by rebalanceCustom.
    // View-local on purpose: the split is just a helper input, only the resulting
    // grams persist (via applyMacroSplit).
    @State private var customProtein: Double = 30
    @State private var customCarbs: Double = 40
    @State private var customFat: Double = 30
    @State private var justApplied = false

    private var accent: Color { theme.current.accent }

    var body: some View {
        Form {
            Section {
                goalField("Calories (kcal)", value: $store.nutritionGoals.calories)
                goalField("Protein (g)", value: $store.nutritionGoals.protein)
                goalField("Carbs (g)", value: $store.nutritionGoals.carbs)
                goalField("Fat (g)", value: $store.nutritionGoals.fat)
            } header: {
                Text("Daily targets")
            } footer: {
                // Claude  Date 07/12/2026
                // Manual entry stays the primary path; the calculator below is an
                // optional shortcut, not a constraint on these fields.
                Text("Set the gram fields however you like — or use the calculator below to fill them from your calorie goal.")
            }

            macroCalculatorSection

            // Claude  Date 07/16/2026
            // Edited in the user's display unit; stored canonically in ml (the get
            // rounds to a tenth so "3000 ml" reads "101.4", not "101.44201…").
            Section {
                goalField("Water (\(waterUnit.abbreviation))", value: waterGoalBinding)
            } header: {
                Text("Water")
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
    }

    // MARK: - Macro calculator

    // Claude  Date 07/12/2026
    // Opt-in "calculate from calories" helper: choose a preset split (or Custom
    // with sliders), see the resulting grams for the current calorie goal, and
    // press Apply to write them. Nothing here runs automatically — typing in the
    // gram fields above never fights the calculator.
    private var macroCalculatorSection: some View {
        Section {
            ForEach(SplitChoice.allCases) { choice in
                splitRow(choice)
            }

            if split == .custom {
                customSliderRow("Protein", .protein)
                customSliderRow("Carbs", .carbs)
                customSliderRow("Fat", .fat)
            }

            if let grams = previewGrams {
                LabeledContent("At \(Int(store.nutritionGoals.calories)) kcal") {
                    Text("\(grams.protein)g P · \(grams.carbs)g C · \(grams.fat)g F")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: applySplit) {
                HStack {
                    Spacer()
                    if justApplied {
                        Label("Applied", systemImage: "checkmark")
                    } else {
                        Text("Apply to macro goals")
                    }
                    Spacer()
                }
                .fontWeight(.semibold)
            }
            .tint(accent)
            .disabled(store.nutritionGoals.calories <= 0)
        } header: {
            Text("Macro calculator")
        } footer: {
            Text("Splits your calorie goal using 4 kcal/g for protein and carbs and 9 kcal/g for fat, rounded to whole grams. Applying overwrites the protein, carbs, and fat fields above.")
        }
    }

    private func splitRow(_ choice: SplitChoice) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { split = choice }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title)
                        .foregroundStyle(.primary)
                    Text(splitSubtitle(choice))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: split == choice ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(split == choice ? accent : Color.secondary.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }

    private func splitSubtitle(_ choice: SplitChoice) -> String {
        let pct = choice.percentages ?? (customProtein, customCarbs, customFat)
        let base = "\(Int(pct.protein.rounded()))% protein · \(Int(pct.carbs.rounded()))% carbs · \(Int(pct.fat.rounded()))% fat"
        return choice == .custom ? "Set your own split — " + base : base
    }

    // Claude  Date 07/12/2026
    // One labeled slider per macro in custom mode. Moving a slider rebalances the
    // other two proportionally so the three always sum to 100%.
    private func customSliderRow(_ label: String, _ macro: Macro) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(customValue(macro).rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: customSliderBinding(macro), in: 0...100, step: 1)
                .tint(accent)
        }
    }

    // MARK: - Calculator logic

    private var activePercentages: (protein: Double, carbs: Double, fat: Double) {
        split.percentages ?? (customProtein, customCarbs, customFat)
    }

    // Claude  Date 07/12/2026
    // Grams the current split + calorie goal would produce; nil when the calorie
    // goal isn't a usable number (preview and Apply both sit out).
    private var previewGrams: (protein: Int, carbs: Int, fat: Int)? {
        let calories = store.nutritionGoals.calories
        guard calories > 0 else { return nil }
        let pct = activePercentages
        return (
            Int((calories * pct.protein / 100 / NutritionGoals.kcalPerGramProtein).rounded()),
            Int((calories * pct.carbs   / 100 / NutritionGoals.kcalPerGramCarbs).rounded()),
            Int((calories * pct.fat     / 100 / NutritionGoals.kcalPerGramFat).rounded())
        )
    }

    private func customValue(_ macro: Macro) -> Double {
        switch macro {
        case .protein: return customProtein
        case .carbs:   return customCarbs
        case .fat:     return customFat
        }
    }

    private func customSliderBinding(_ macro: Macro) -> Binding<Double> {
        Binding(
            get: { customValue(macro) },
            set: { rebalanceCustom(changing: macro, to: $0) }
        )
    }

    // Claude  Date 07/12/2026
    // Keep the custom split summing to 100: the changed macro takes its new value
    // and the remainder is spread over the other two in proportion to their current
    // sizes (or evenly, if both sit at zero).
    private func rebalanceCustom(changing macro: Macro, to newValue: Double) {
        var values: [Macro: Double] = [.protein: customProtein, .carbs: customCarbs, .fat: customFat]
        let clamped = min(max(newValue, 0), 100)
        let others = Macro.allCases.filter { $0 != macro }
        let otherSum = others.reduce(0) { $0 + values[$1]! }
        for other in others {
            values[other] = otherSum > 0
                ? (100 - clamped) * values[other]! / otherSum
                : (100 - clamped) / Double(others.count)
        }
        values[macro] = clamped
        customProtein = values[.protein]!
        customCarbs = values[.carbs]!
        customFat = values[.fat]!
    }

    // Claude  Date 07/12/2026
    // The one place the calculator writes to the store — explicit user action.
    // Flashes the button label to "Applied" briefly as confirmation, since the
    // gram fields above may be scrolled off screen when this is tapped.
    private func applySplit() {
        let pct = activePercentages
        store.nutritionGoals.applyMacroSplit(
            proteinPct: pct.protein, carbsPct: pct.carbs, fatPct: pct.fat)
        withAnimation { justApplied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { justApplied = false }
        }
    }

    // MARK: - Fields

    // Claude  Date 07/16/2026
    // The water goal seen through the display unit: reads convert ml → unit (rounded
    // to a tenth for a sane field value), writes convert back to canonical ml.
    private var waterGoalBinding: Binding<Double> {
        Binding(
            get: { (waterUnit.fromMilliliters(store.nutritionGoals.water) * 10).rounded() / 10 },
            set: { store.nutritionGoals.water = waterUnit.toMilliliters($0) }
        )
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
