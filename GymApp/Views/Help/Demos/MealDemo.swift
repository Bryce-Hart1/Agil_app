import SwiftUI

// CLAUDE  Date 09/27/2026
// "Logging a meal": flips to the Food side, then the Log tab, food picker and food page
// on sample foods. Never touches AppStore, and nothing here takes keyboard focus (the
// real amount editor is shown but inert; a tap fills in a sample amount).

// MARK: - Script

enum MealDemoRoute: Hashable {
    case detail
}

struct MealDemoEntry: Identifiable {
    let id = UUID()
    let food: DemoFood
    let measurement: FoodMeasurement
    let meal: MealType
    // CLAUDE  Date 09/30/2026 — when it was eaten, as minutes after midnight on today. Fixed
    // rather than "now" so the demo's time thread reads the same whenever it's played.
    let minutes: Int

    var nutrients: Nutrients { food.nutrients(for: measurement) }

    // CLAUDE  Date 09/30/2026
    // The real diary entry this stands for, so the demo draws with the Log's own row and
    // ribbon. A placeholder foodId keeps it from reading as a quick add. Not persisted.
    var foodEntry: FoodEntry {
        FoodEntry(id: id, foodId: food.id, name: food.name, nutrients: nutrients, mealType: meal,
                  loggedAt: MealTiming.placing(seconds: TimeInterval(minutes * 60), on: Date()),
                  measurement: measurement)
    }
}

struct MealDemoState {
    var mode: AppMode = .lifting
    var tab = AgilTabItem.workouts.tag
    /// Non-nil while the food picker sheet is up: the meal it's adding to.
    var pickerMeal: MealType?
    var pickerPath: [MealDemoRoute] = []
    var food: DemoFood?
    var measurement = FoodMeasurement(amount: 1, servingNoun: "serving")
    var meal: MealType = .snack
    var entries: [MealDemoEntry] = MealDemoState.sampleEntries

    // What's already logged today, so the Journal and Log agree with each other.
    static let sampleEntries = [
        MealDemoEntry(food: DemoSamples.oats, measurement: FoodMeasurement(amount: 1, servingNoun: "serving"),
                      meal: .breakfast, minutes: 7 * 60 + 40),
        MealDemoEntry(food: DemoSamples.banana, measurement: FoodMeasurement(amount: 1, servingNoun: "serving"),
                      meal: .breakfast, minutes: 7 * 60 + 42),
        MealDemoEntry(food: DemoSamples.chicken, measurement: FoodMeasurement(amount: 200, unit: .gram),
                      meal: .lunch, minutes: 12 * 60 + 5),
        MealDemoEntry(food: DemoSamples.rice, measurement: FoodMeasurement(amount: 1, servingNoun: "serving"),
                      meal: .lunch, minutes: 12 * 60 + 8)
    ]
}

enum MealDemoAction: Equatable {
    case flip
    case selectTab(Int)
    case addFood(MealType)
    case pickFood(DemoFood)
    case setSampleAmount
    case logFood
}

enum MealDemoTarget: Hashable {
    case notch, logTab, addFood, pickerRow, amount, mealPicker, addButton, entry
}

struct MealDemoScript: DemoScript {
    typealias Step = DemoStep<MealDemoAction, MealDemoTarget>

    let initialState = MealDemoState()

    let steps: [Step] = [
        Step(text: "Tap the pill at the top to flip to the Food side.",
             target: .notch, action: .flip),
        Step(text: "This is the Journal, your day at a glance. Tap Log in the tab bar.",
             target: .logTab, action: .selectTab(AgilTabItem.log.tag)),
        Step(text: "Tap Add food under the meal you ate.",
             target: .addFood, action: .addFood(.snack)),
        Step(text: "Pick a food. You can also search, scan a barcode, or create your own here.",
             target: .pickerRow, action: .pickFood(DemoSamples.greekYogurt)),
        Step(text: "Here you'd set how much you had, in servings or by weight. Tap to fill it in.",
             target: .amount, effect: .setSampleAmount),
        Step(text: "Logging to the wrong meal? Change it here.",
             target: .mealPicker),
        Step(text: "Tap Add to log it.",
             target: .addButton, action: .logFood),
        Step(text: "Swipe an entry left to edit or delete it.",
             target: .entry),
        Step(text: "Your Journal totals update right away. For packaged food, tap the barcode at the top left and scan it to find it fast.")
    ]

    func apply(_ action: MealDemoAction, to state: inout MealDemoState) {
        switch action {
        case .flip:
            state.mode = .nutrition
            state.tab = AgilTabItem.journal.tag
        case .selectTab(let tag):
            state.tab = tag
        case .addFood(let meal):
            state.meal = meal
            state.pickerMeal = meal
        case .pickFood(let food):
            state.food = food
            state.measurement = food.basis.defaultMeasurement
            state.pickerPath = [.detail]
        case .setSampleAmount:
            state.measurement = state.measurement.scaled(by: 2)
        case .logFood:
            if let food = state.food {
                state.entries.append(MealDemoEntry(food: food, measurement: state.measurement,
                                                   meal: state.meal,
                                                   minutes: Int(state.meal.defaultSeconds / 60)))
            }
            state.pickerMeal = nil
            state.pickerPath = []
            state.food = nil
        }
    }

    // Any meal and any food count.
    func matches(_ attempted: MealDemoAction, expected: MealDemoAction) -> Bool {
        switch (attempted, expected) {
        case (.addFood, .addFood), (.pickFood, .pickFood):
            return true
        default:
            return attempted == expected
        }
    }
}

// MARK: - Shell

struct MealDemoShell: View {
    @ObservedObject var runner: DemoRunner<MealDemoScript>

    private var state: MealDemoState { runner.state }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                root
            }
            .id(state.tab)
            DemoTabBar(mode: state.mode, selectedTag: state.tab,
                       highlightedTag: runner.isTarget(.logTab) ? AgilTabItem.log.tag : nil,
                       nudges: runner.nudges) { runner.attempt(.selectTab($0)) }
        }
        .overlay {
            DemoSheet(isPresented: state.pickerMeal != nil) {
                NavigationStack(path: Binding(get: { state.pickerPath }, set: { _ in })) {
                    DemoFoodPickerList(title: "Add to \(state.meal.title)",
                                       highlighted: runner.isTarget(.pickerRow) ? DemoSamples.greekYogurt.id : nil,
                                       nudges: runner.nudges,
                                       onPick: { runner.attempt(.pickFood($0)) },
                                       onNudge: { runner.nudge() })
                        .navigationDestination(for: MealDemoRoute.self) { _ in
                            MealDemoFoodPage(runner: runner)
                        }
                }
            }
        }
    }

    @ViewBuilder private var root: some View {
        if state.mode == .lifting {
            DemoWorkoutsScreen(onNudge: { runner.nudge() }, onNotch: { runner.attempt(.flip) },
                               highlightNotch: runner.isTarget(.notch), nudges: runner.nudges)
        } else if state.tab == AgilTabItem.log.tag {
            MealDemoLog(runner: runner)
        } else {
            DemoJournalScreen(totals: totals, onNudge: { runner.nudge() })
        }
    }

    private var totals: Nutrients {
        state.entries.reduce(.zero) { $0 + $1.nutrients }
    }
}

// MARK: - Log tab

// CLAUDE  Date 09/27/2026 last changed: 09/30/2026 by: CLAUDE
// Copy of NutritionLogView: the day stepper, the day ribbon, then the meals as chapters on
// the time thread, drawn with the Log's own ThreadEntryRow / ThreadChapterHeader /
// ThreadAddRow. The entry the demo just logged carries the swipe step.
private struct MealDemoLog: View {
    @ObservedObject var runner: DemoRunner<MealDemoScript>

    @EnvironmentObject private var theme: ThemeManager

    private let meals: [MealType] = [.breakfast, .lunch, .dinner, .snack]

    var body: some View {
        List {
            NutritionDayPickerSection(selectedDate: .constant(Date()))
            Section {
                DayRibbon(entries: runner.state.entries.map(\.foodEntry), date: Date()) { _ in
                    runner.nudge()
                }
            }
            let ordered = orderedMeals
            ForEach(Array(ordered.enumerated()), id: \.element) { index, meal in
                mealSection(meal, after: index > 0 ? ordered[index - 1] : nil)
            }
        }
        .navigationTitle("Log")
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DemoNotch(mode: .nutrition, stat: DemoSamples.foodNotchStat) { runner.nudge() }
            }
            ToolbarItem(placement: .topBarLeading) {
                DemoAssetButton(asset: "barcode") { runner.nudge() }
                    .accessibilityLabel("Scan barcode")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { runner.nudge() } label: { Image(systemName: "scope") }
                    .accessibilityLabel("Focus goals")
            }
        }
    }

    // A meal's entries oldest first, as the thread reads.
    private func entries(for meal: MealType) -> [MealDemoEntry] {
        runner.state.entries.filter { $0.meal == meal }.sorted { $0.minutes < $1.minutes }
    }

    // Same ordering as the Log: first entry's time, else the meal's default time.
    private func anchor(_ meal: MealType) -> TimeInterval {
        entries(for: meal).first.map { TimeInterval($0.minutes * 60) } ?? meal.defaultSeconds
    }

    private var orderedMeals: [MealType] {
        meals.sorted { anchor($0) < anchor($1) }
    }

    private func mealSection(_ meal: MealType, after previous: MealType?) -> some View {
        let rows = entries(for: meal)
        let kcal = Int(rows.reduce(0) { $0 + $1.nutrients.calories }.rounded())
        let newest = runner.state.entries.count > MealDemoState.sampleEntries.count
            ? runner.state.entries.last?.id : nil
        let gap: TimeInterval? = {
            guard let first = rows.first, let previous,
                  let last = entries(for: previous).last else { return nil }
            let interval = TimeInterval((first.minutes - last.minutes) * 60)
            return interval >= ThreadLayout.minGap ? interval : nil
        }()
        return Section {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                let tap = { if entry.id == newest { runner.acknowledge(.entry) } else { runner.nudge() } }
                ThreadEntryRow(entry: entry.foodEntry,
                               showsTime: index == 0
                                   || entry.minutes - rows[index - 1].minutes >= Int(ThreadLayout.timeRepeat / 60),
                               isFirst: index == 0,
                               isLast: index == rows.count - 1)
                    .listRowInsets(ThreadLayout.rowInsets)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button(action: tap) { Label("Delete", systemImage: "trash") }
                            .tint(.red)
                        Button(action: tap) { Label("Edit", systemImage: "square.and.pencil") }
                            .tint(theme.current.accent)
                    }
                    .demoHighlight(entry.id == newest && runner.isTarget(.entry),
                                   nudges: runner.nudges, inset: -4)
            }
            ThreadAddRow(meal: meal,
                         onAdd: { runner.attempt(.addFood(meal)) },
                         onQuickAdd: { runner.nudge() })
                .listRowInsets(ThreadAddRow.insets)
                .demoHighlight(meal == .snack && runner.isTarget(.addFood), nudges: runner.nudges)
        } header: {
            ThreadChapterHeader(meal: meal,
                                start: rows.first?.foodEntry.loggedAt,
                                anchor: anchor(meal),
                                kcal: kcal,
                                gap: gap)
        }
    }
}

// MARK: - Food page

// CLAUDE  Date 09/27/2026
// Copy of FoodDetailView as the picker pushes it: header card, the real MeasurementEditor
// (inert), the macros, and the meal picker plus Add button pinned to the bottom.
private struct MealDemoFoodPage: View {
    @ObservedObject var runner: DemoRunner<MealDemoScript>

    @EnvironmentObject private var theme: ThemeManager

    private var state: MealDemoState { runner.state }
    private var accent: Color { theme.current.accent }

    var body: some View {
        Group {
            if let food = state.food {
                content(food)
            }
        }
        .navigationTitle("Food")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DemoBackButton(title: "Back") { runner.nudge() }
            }
        }
    }

    private func content(_ food: DemoFood) -> some View {
        let consumed = food.nutrients(for: state.measurement)
        return ScrollView {
            VStack(spacing: 14) {
                header(food)
                MeasurementEditor(basis: food.basis,
                                  measurement: Binding(get: { state.measurement }, set: { _ in }),
                                  accent: accent)
                    .demoInert { runner.acknowledge(.amount) }
                    .demoHighlight(runner.isTarget(.amount), nudges: runner.nudges, inset: -6)
                macrosCard(consumed)
            }
            .padding(16)
        }
        .background(theme.current.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { logBar(consumed) }
    }

    private func header(_ food: DemoFood) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(food.name)
                .font(.title2)
                .fontWeight(.bold)
                .foodNameFont()
            if !food.brand.isEmpty {
                Text(food.brand).font(.subheadline).foregroundStyle(.secondary)
            }
            Label(food.category, systemImage: "fork.knife")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // The big calorie number over the macro rows, as the real food page shows them.
    private func macrosCard(_ n: Nutrients) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(n.calories.rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                Text("kcal").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text("per \(state.measurement.displayText)").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            VStack(spacing: 0) {
                macroRow("Protein", n.protein, "g", MacroPalette.protein)
                macroRow("Carbs", n.carbs, "g", MacroPalette.carbs)
                macroRow("Fat", n.fat, "g", MacroPalette.fat)
                macroRow("Fiber", n.fiber, "g", MacroPalette.fiber)
                macroRow("Sugar", n.sugar, "g", MacroPalette.sugar)
                macroRow("Sodium", n.sodium, "mg", MacroPalette.sodium, last: true)
            }
        }
        .padding(16)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: state.measurement)
    }

    private func macroRow(_ label: String, _ value: Double, _ unit: String, _ tint: Color,
                          last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(label).font(.subheadline)
                Spacer()
                Text("\(FoodMeasurement.number(value, decimals: 1)) \(unit)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            if !last { Divider() }
        }
    }

    private func logBar(_ consumed: Nutrients) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Meal").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Picker("Meal", selection: $runner.state.meal) {
                    ForEach(MealType.allCases) { meal in
                        Label(meal.title, systemImage: meal.systemImage).tag(meal)
                    }
                }
                .pickerStyle(.menu)
                .tint(accent)
            }
            .demoHighlight(runner.isTarget(.mealPicker), nudges: runner.nudges, inset: -4)

            Button {
                runner.attempt(.logFood)
            } label: {
                Text("Add to \(state.meal.title) · \(Int(consumed.calories.rounded())) kcal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .demoHighlight(runner.isTarget(.addButton), nudges: runner.nudges,
                           cornerRadius: 12, inset: -4)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
