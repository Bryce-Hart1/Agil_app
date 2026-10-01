import SwiftUI

// CLAUDE  Date 09/27/2026
// Sample data and look-alike root screens shared by the demos: the Workouts, Build,
// Journal and Foods tabs as a typical user would see them. Plain values only; nothing
// here reads or writes AppStore.

// MARK: - Sample data

enum DemoSamples {
    static let liftingNotchStat = "1240/2200 cal"
    static let foodNotchStat = "3-wk streak"

    // Lifts. Created once per launch, so a step's expected pick is the same lift the
    // picker lists.
    static let benchPress = Exercise(name: "Bench Press", region: .chest, category: "Chest",
                                     liftType: .bench, equipmentType: .freeWeight)
    static let inclinePress = Exercise(name: "Incline Dumbbell Press", region: .chest,
                                       category: "Chest", equipmentType: .freeWeight)
    static let tricepPushdown = Exercise(name: "Tricep Pushdown", region: .arms,
                                         category: "Triceps", equipmentType: .cable)
    static let backSquat = Exercise(name: "Back Squat", region: .legs, category: "Quads",
                                    liftType: .squat, equipmentType: .freeWeight)
    static let legPress = Exercise(name: "Leg Press", region: .legs, category: "Quads",
                                   equipmentType: .machine)

    struct LiftGroup: Identifiable {
        let region: MuscleRegion
        var exercises: [Exercise]
        var id: MuscleRegion { region }
    }

    static let library: [LiftGroup] = [
        LiftGroup(region: .legs, exercises: [backSquat, legPress]),
        LiftGroup(region: .chest, exercises: [benchPress, inclinePress]),
        LiftGroup(region: .back, exercises: [
            Exercise(name: "Deadlift", region: .back, category: "Lower Back",
                     liftType: .deadlift, equipmentType: .freeWeight),
            Exercise(name: "Lat Pulldown", region: .back, category: "Lats", equipmentType: .cable)
        ]),
        LiftGroup(region: .arms, exercises: [
            Exercise(name: "Bicep Curl", region: .arms, category: "Biceps",
                     liftType: .curl, equipmentType: .freeWeight),
            tricepPushdown
        ])
    ]

    struct HistoryRow: Identifiable {
        let id = UUID()
        let daysAgo: Int
        let summary: String
    }

    static let history: [HistoryRow] = [
        HistoryRow(daysAgo: 2, summary: "4 exercises • 14 sets • 52 min"),
        HistoryRow(daysAgo: 4, summary: "5 exercises • 18 sets • 1h 5m"),
        HistoryRow(daysAgo: 6, summary: "Cardio • 1 exercise • 1 bout • 30 min")
    ]

    struct PresetRow: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let summary: String
    }

    static let presetRows: [PresetRow] = [
        PresetRow(name: "Push Day", icon: "dumbbell.fill",
                  summary: "Bench Press, Incline Dumbbell Press, Tricep Pushdown"),
        PresetRow(name: "Leg Day", icon: "figure.strengthtraining.traditional",
                  summary: "Back Squat, Leg Press")
    ]

    // Foods, with real-world per-100 g numbers so every derived total adds up.
    static let greekYogurt = DemoFood(
        name: "Greek Yogurt, Plain", brand: "Fage", category: "Dairy",
        basis: MeasurementBasis(per100: Nutrients(calories: 59, protein: 10.3, carbs: 3.6, fat: 0.4,
                                                  sugar: 3.2, sodium: 36),
                                basisUnit: "g", servingQuantity: 170),
        servingLabel: "1 container (170 g)")
    static let banana = DemoFood(
        name: "Banana", brand: "", category: "Fruit",
        basis: MeasurementBasis(per100: Nutrients(calories: 89, protein: 1.1, carbs: 22.8, fat: 0.3,
                                                  fiber: 2.6, sugar: 12.2, sodium: 1),
                                basisUnit: "g", servingQuantity: 118),
        servingLabel: "1 medium (118 g)")
    static let oats = DemoFood(
        name: "Rolled Oats", brand: "Quaker", category: "Grains",
        basis: MeasurementBasis(per100: Nutrients(calories: 375, protein: 12.5, carbs: 67.5, fat: 6.3,
                                                  fiber: 10, sugar: 2.5),
                                basisUnit: "g", servingQuantity: 40),
        servingLabel: "1/2 cup (40 g)")
    static let chicken = DemoFood(
        name: "Chicken Breast, Cooked", brand: "", category: "Meat",
        basis: MeasurementBasis(per100: Nutrients(calories: 165, protein: 31, fat: 3.6, sodium: 74),
                                basisUnit: "g"),
        servingLabel: "100 g")
    static let rice = DemoFood(
        name: "White Rice, Cooked", brand: "", category: "Grains",
        basis: MeasurementBasis(per100: Nutrients(calories: 130, protein: 2.7, carbs: 28.2, fat: 0.3,
                                                  fiber: 0.4, sodium: 1),
                                basisUnit: "g", servingQuantity: 158),
        servingLabel: "1 cup (158 g)")

    static let foods: [DemoFood] = [greekYogurt, banana, oats, chicken, rice]

    /// What the Journal shows before the demo logs anything.
    static let journalTotals = Nutrients(calories: 1240, protein: 96, carbs: 128, fat: 38)
}

// CLAUDE  Date 09/27/2026
// A food the demos can list and log. The basis feeds the real MeasurementEditor, and all
// the numbers shown are derived from it, so amounts and totals always agree.
struct DemoFood: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let brand: String
    let category: String
    let basis: MeasurementBasis
    let servingLabel: String

    func nutrients(for measurement: FoodMeasurement) -> Nutrients {
        basis.per100.scaled(by: measurement.per100Factor(in: basis))
    }

    var perServing: Nutrients { nutrients(for: basis.defaultMeasurement) }
}

/// A plain two-line list row (name over caption) for foods and recipes the demo adds.
struct DemoListRow: Identifiable {
    let id = UUID()
    let name: String
    let caption: String
}

// MARK: - Rows

// CLAUDE  Date 09/27/2026
// One food as the Foods tab (brand · kcal · serving) or the food picker (kcal · serving ·
// macros) draws it.
struct DemoFoodRow: View {
    enum Style { case library, picker }

    let food: DemoFood
    var style: Style = .picker

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(food.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foodNameFont()
                .lineLimit(1)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var caption: String {
        let n = food.perServing
        let kcal = Int(n.calories.rounded())
        switch style {
        case .library:
            let base = "\(kcal) kcal · \(food.servingLabel)"
            return food.brand.isEmpty ? base : "\(food.brand) · \(base)"
        case .picker:
            return "\(kcal) kcal · \(food.servingLabel)  ·  P \(Int(n.protein.rounded()))g C \(Int(n.carbs.rounded()))g F \(Int(n.fat.rounded()))g"
        }
    }
}

struct DemoPlainRow: View {
    let row: DemoListRow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foodNameFont()
                .lineLimit(1)
            Text(row.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// Same two lines as WorkoutsListView's WorkoutRow, plus the list's disclosure chevron.
private struct DemoHistoryRow: View {
    let date: Date
    let summary: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date, format: .dateTime.weekday().month().day())
                    .font(.headline)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
            }
            Spacer()
            DemoChevron()
        }
        .contentShape(Rectangle())
    }
}

/// The disclosure chevron a NavigationLink row draws.
struct DemoChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Workouts tab

// CLAUDE  Date 09/27/2026
// Copy of the Workouts tab: History list, notch, and the two start buttons (supplied by
// the demo so it can highlight or wire them). `newestSummary` adds today's workout on top.
struct DemoWorkoutsScreen<BlankButton: View, PresetButton: View>: View {
    var newestSummary: String? = nil
    let onNudge: () -> Void
    var onNotch: (() -> Void)? = nil
    var highlightNotch = false
    var nudges = 0
    @ViewBuilder let blankButton: () -> BlankButton
    @ViewBuilder let presetButton: () -> PresetButton

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            Section {
                if let newestSummary {
                    Button(action: onNudge) {
                        DemoHistoryRow(date: Date(), summary: newestSummary)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                ForEach(DemoSamples.history) { row in
                    Button(action: onNudge) {
                        DemoHistoryRow(date: Calendar.current.date(byAdding: .day, value: -row.daysAgo,
                                                                   to: Date()) ?? Date(),
                                       summary: row.summary)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("History")
            }
        }
        .navigationTitle("Workouts")
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DemoNotch(mode: .lifting, stat: DemoSamples.liftingNotchStat,
                          onTap: onNotch ?? onNudge)
                    .demoHighlight(highlightNotch, nudges: nudges, cornerRadius: 22, inset: -4)
            }
            ToolbarItem(placement: .topBarLeading) { blankButton() }
            ToolbarItem(placement: .primaryAction) { presetButton() }
        }
    }
}

extension DemoWorkoutsScreen where BlankButton == DemoWorkoutIconButton,
                                   PresetButton == DemoWorkoutIconButton {
    /// The tab as a backdrop: every control just nudges (or `onNotch` for the pill).
    init(onNudge: @escaping () -> Void, onNotch: (() -> Void)? = nil,
         highlightNotch: Bool = false, nudges: Int = 0) {
        self.init(onNudge: onNudge, onNotch: onNotch,
                  highlightNotch: highlightNotch, nudges: nudges,
                  blankButton: { DemoWorkoutIconButton(asset: "empty_workout", action: onNudge) },
                  presetButton: { DemoWorkoutIconButton(asset: "preset_workout", action: onNudge) })
    }
}

/// One of the Workouts tab's two masked PNG toolbar buttons.
struct DemoWorkoutIconButton: View {
    let asset: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DemoToolbarIcon(asset: asset)
        }
    }
}

// MARK: - Build tab

// CLAUDE  Date 09/27/2026
// Copy of the Build tab's preset list. The Exercises link and + menu come from the demo.
// `newPreset` is a preset the demo just made; it lists last, as the real list does.
struct DemoPresetsScreen<Leading: View, Trailing: View>: View {
    var newPreset: DemoSamples.PresetRow? = nil
    var highlightNewPreset = false
    var nudges = 0
    let onNudge: () -> Void
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            ForEach(DemoSamples.presetRows) { row in
                presetRow(row)
            }
            if let newPreset {
                presetRow(newPreset)
                    .demoHighlight(highlightNewPreset, nudges: nudges, inset: -4)
            }
        }
        .navigationTitle("Presets")
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DemoNotch(mode: .lifting, stat: DemoSamples.liftingNotchStat, onTap: onNudge)
            }
            ToolbarItem(placement: .topBarLeading) { leading() }
            ToolbarItem(placement: .primaryAction) { trailing() }
        }
    }

    private func presetRow(_ row: DemoSamples.PresetRow) -> some View {
        Button(action: onNudge) {
            HStack(spacing: 12) {
                PresetIconView(name: row.icon, size: 24)
                    .foregroundStyle(theme.current.accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.headline)
                    Text(row.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .supportingTextFont()
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                DemoChevron()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The Build tab's top-left "Exercises" link, drawn with its title like the real one.
struct DemoExercisesLink: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Exercises", systemImage: "list.bullet")
                .labelStyle(.titleAndIcon)
        }
    }
}

// MARK: - Journal tab

// CLAUDE  Date 09/27/2026
// Copy of the Journal's top: the day stepper (pinned to today) and the calorie summary.
// Every control nudges; the notch uses `onNotch` when given.
struct DemoJournalScreen: View {
    var totals: Nutrients = DemoSamples.journalTotals
    let onNudge: () -> Void

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            NutritionDayPickerSection(selectedDate: .constant(Date()))
            Section("Summary") {
                MacroSummaryView(totals: totals, goals: NutritionGoals(), accent: theme.current.accent)
            }
        }
        .navigationTitle("Journal")
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DemoNotch(mode: .nutrition, stat: DemoSamples.foodNotchStat, onTap: onNudge)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onNudge) { Image(systemName: "scope") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: onNudge) { Image(systemName: "target") }
            }
        }
    }
}

// MARK: - Foods tab

// CLAUDE  Date 09/27/2026
// Copy of the Foods tab: Recipes, then Recents. The + menu comes from the demo; a recipe
// or food the demo just made leads its section and can carry the highlight.
struct DemoFoodsScreen<AddButton: View>: View {
    var newRecipe: DemoListRow? = nil
    var newFood: DemoListRow? = nil
    var highlightNew = false
    var nudges = 0
    let onNudge: () -> Void
    @ViewBuilder let addButton: () -> AddButton

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            DemoSearchField(prompt: "Search all foods")
                .onTapGesture(perform: onNudge)
            if let newRecipe {
                Section("Recipes") {
                    Button(action: onNudge) { DemoPlainRow(row: newRecipe) }
                        .buttonStyle(.plain)
                        .demoHighlight(highlightNew, nudges: nudges, inset: -4)
                }
            }
            Section("Recents") {
                if let newFood {
                    Button(action: onNudge) { DemoPlainRow(row: newFood) }
                        .buttonStyle(.plain)
                        .demoHighlight(highlightNew, nudges: nudges, inset: -4)
                }
                ForEach(DemoSamples.foods) { food in
                    Button(action: onNudge) { DemoFoodRow(food: food, style: .library) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Foods")
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DemoNotch(mode: .nutrition, stat: DemoSamples.foodNotchStat, onTap: onNudge)
            }
            ToolbarItem(placement: .topBarLeading) {
                DemoAssetButton(asset: "barcode", action: onNudge)
                    .accessibilityLabel("Scan barcode")
            }
            ToolbarItem(placement: .primaryAction) { addButton() }
        }
    }
}

// MARK: - Food picker

// CLAUDE  Date 09/27/2026
// The root of the food picker sheet (logging a meal, or adding a recipe ingredient):
// search, the scan/create shortcuts, then your foods. Only a food row is live.
struct DemoFoodPickerList: View {
    let title: String
    var showsCreateRecipe = true
    let highlighted: DemoFood.ID?
    let nudges: Int
    let onPick: (DemoFood) -> Void
    let onNudge: () -> Void

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            DemoSearchField(prompt: "Search foods")
                .onTapGesture(perform: onNudge)
            Section {
                Button(action: onNudge) {
                    Label("Scan barcode", systemImage: "barcode.viewfinder")
                }
                Button(action: onNudge) {
                    Label("Create custom food", systemImage: "plus.circle")
                }
                if showsCreateRecipe {
                    Button(action: onNudge) {
                        Label("Create recipe", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            Section("My foods") {
                ForEach(DemoSamples.foods) { food in
                    Button {
                        onPick(food)
                    } label: {
                        DemoFoodRow(food: food, style: .picker)
                    }
                    .buttonStyle(.plain)
                    .demoHighlight(food.id == highlighted, nudges: nudges, inset: -4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onNudge)
            }
        }
    }
}

// CLAUDE  Date 09/27/2026
// The kcal-and-macros card under an amount: big calorie number, then protein, carbs, fat.
// Shared by the meal and recipe demos' amount pages.
struct DemoNutritionCard: View {
    let nutrients: Nutrients
    let caption: String

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(nutrients.calories.rounded()))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.current.accent)
                    .contentTransition(.numericText())
                Text("kcal").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                macro("Protein", nutrients.protein, MacroPalette.protein)
                Spacer()
                macro("Carbs", nutrients.carbs, MacroPalette.carbs)
                Spacer()
                macro("Fat", nutrients.fat, MacroPalette.fat)
            }
        }
        .padding(16)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macro(_ label: String, _ value: Double, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(FoodMeasurement.number(value, decimals: 1))g")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
