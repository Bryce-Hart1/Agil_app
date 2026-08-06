import SwiftUI


/// The Nutrition tab's home: a per-day food diary. A date stepper at the top picks
/// the day; below it sits the daily calorie/macro summary, a water tracker, and one
/// section per meal listing what was logged. The + on each meal opens the food
/// picker to log into that meal on the selected day.
struct NutritionJournalView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Claude  Date 06/16/2026 updated Bryce Hart 6/16/26
    // The day being viewed/edited. Defaults to today; the header steps it.
    @State private var selectedDate = Date()
    // Which meal the food picker is logging into (nil = picker closed).
    @State private var addingToMeal: MealType?
    // Claude  Date 06/16/2026
    // The logged entry being edited (nil = editor closed). Tapping a row opens it.
    @State private var editingEntry: FoodEntry?
    // Claude  Date 07/12/2026
    // Whether the focus-goals editor sheet is up (top-left toolbar button).
    @State private var showingFocusGoals = false
    // Claude  Date 07/16/2026
    // Water display unit (Settings → Water). Logging still writes canonical ml;
    // only labels and quick-add buttons change with this.
    @AppStorage(WaterUnit.storageKey) private var waterUnitRaw = WaterUnit.milliliters.rawValue
    private var waterUnit: WaterUnit { WaterUnit(rawValue: waterUnitRaw) ?? .milliliters }

    private var day: NutritionDay { store.nutritionDay(for: selectedDate) }

    var body: some View {
        NavigationStack {
            List {
                dateSection
                // Claude  Date 07/25/2026
                // First-run setup checklist, directly under the day picker and above
                // Summary — the calorie/water goals it points at are exactly what the
                // Summary card measures against, so it reads in the right order. Once
                // retired (finished or dismissed) it never renders again.
                if !store.profile.nutritionSetup.acknowledged {
                    NutritionSetupCard(onOpenFocus: openFocusGoals)
                }
                summarySection
                if !store.focusGoals.isEmpty {
                    focusSection
                }
                waterSection
                ForEach(MealType.allCases) { meal in
                    mealSection(meal)
                }
            }
            .navigationTitle("Log")
            .themed(theme.current)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            .modeNotchToolbar(tab: AgilTabItem.journal.tag)
            .toolbar {
                // Claude  Date 07/12/2026
                // Top-left: nutrient focus goals ("I want to eat more fiber").
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: openFocusGoals) {
                        Image(systemName: "scope")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        NutritionGoalsView()
                    } label: {
                        Image(systemName: "target")
                    }
                }
            }
            .sheet(item: $addingToMeal) { meal in
                FoodPickerView(meal: meal, date: selectedDate)
            }
            .sheet(isPresented: $showingFocusGoals) {
                FocusGoalsView()
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntryView(entry: entry)
            }
        }
    }

    // Claude  Date 07/25/2026
    // The one way into the focus-goals sheet, so both entry points — the toolbar's
    // scope button and the setup checklist's bonus row — tick the checklist item.
    // markNutritionSetup is guarded, so re-opening the sheet costs nothing.
    private func openFocusGoals() {
        showingFocusGoals = true
        store.markNutritionSetup(\.focusGoalsOpened)
    }

    // MARK: - Date stepper

    private var dateSection: some View {
        Section {
            HStack {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
                VStack(spacing: 1) {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.headline)
                    Text(selectedDate, format: .dateTime.month().day().year())
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { step(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
                    .disabled(Calendar.current.isDateInToday(selectedDate))
            }
            if !Calendar.current.isDateInToday(selectedDate) {
                Button("Jump to Today") { selectedDate = Date() }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func step(_ days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate)
        else { return }
        // Never step past today (no logging into the future).
        if days > 0 && next > Date() { return }
        selectedDate = next
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section("Summary") {
            MacroSummaryView(totals: day.totals, goals: store.nutritionGoals,
                             accent: theme.current.accent)
        }
    }

    // MARK: - Focus goals

    // Claude  Date 07/12/2026
    // The Focus card: one progress row per user-created nutrient focus goal (see
    // NutrientFocusGoal), fed from the selected day's totals so it follows the
    // date stepper. Only rendered when at least one goal exists.
    // TODO: Claude  Date 07/12/2026 — later: optional daily local notification
    // nudging unmet focus goals (UNCalendarNotificationTrigger, added alongside
    // WorkoutNotifications' existing schedule/cancel pairs; reuse
    // NutrientFocusGoal.progressText for the wording).
    private var focusSection: some View {
        Section("Focus") {
            ForEach(store.focusGoals) { goal in
                FocusGoalRow(goal: goal,
                             consumed: goal.nutrient.value(from: day.totals))
            }
        }
    }

    // MARK: - Water

    // Claude  Date 07/16/2026
    // The water tracker: amount label in the user's display unit (with animated
    // digits and a checkmark once the goal is met), the animated WaterBarView fill,
    // and unit-appropriate quick-add buttons. All logging stays canonical ml.
    private var waterSection: some View {
        Section("Water") {
            let goal = max(store.nutritionGoals.water, 1)
            let goalMet = day.water >= goal
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Label("\(waterUnit.text(fromMilliliters: day.water)) / \(waterUnit.text(fromMilliliters: store.nutritionGoals.water)) \(waterUnit.abbreviation)",
                          systemImage: "drop.fill")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(theme.current.accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if goalMet {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(theme.current.accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: goalMet)
                .animation(.spring(response: 0.55, dampingFraction: 0.85), value: day.water)
                WaterBarView(fraction: day.water / goal, accent: theme.current.accent)
                HStack { //added conversions for cups, bottle (even though a bottle is 500ml)
                // Claude  Date 08/06/2026 — the cup is FoodUnit.cup.perBase now (240 ml,
                // the US "legal" cup nutrition labels use) rather than a local 237, so
                // food and water agree on what a cup is. Was the customary 236.588.
                    ForEach(waterQuickAdds, id: \.label) { add in
                        Button(add.label) {
                            store.logWater(milliliters: add.ml, on: selectedDate)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }

    // Claude  Date 07/16/2026
    // Quick-add presets in the display unit (cup/bottle stay in both — they're
    // objects, not numbers). Values are the canonical ml actually logged.
    private var waterQuickAdds: [(label: String, ml: Double)] {
        switch waterUnit {
        case .milliliters:
            return [("+250 ml", 250), ("+500 ml", 500),
                    ("+bottle", 500), ("+cup", FoodUnit.cup.perBase)]
        case .fluidOunces:
            return [("+8 oz", 8 * WaterUnit.mlPerFluidOunce),
                    ("+16 oz", 16 * WaterUnit.mlPerFluidOunce),
                    ("+bottle", 500), ("+cup", FoodUnit.cup.perBase)]
        }
    }

    // MARK: - Meals

    private func mealSection(_ meal: MealType) -> some View {
        let entries = day.entries(for: meal)
        let mealKcal = Int(day.totals(for: meal).calories.rounded())
        return Section {
            ForEach(entries) { entry in
                Button { editingEntry = entry } label: {
                    FoodEntryRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { entries[$0].id }.forEach(store.deleteFoodEntry)
            }
            Button {
                addingToMeal = meal
            } label: {
                Label("Add food", systemImage: "plus.circle.fill")
                    .font(.subheadline)
            }
        } header: {
            HStack {
                Label(meal.title, systemImage: meal.systemImage)
                Spacer()
                if mealKcal > 0 { Text("\(mealKcal) kcal") }
            }
        }
    }
}

// Claude  Date 07/16/2026
// The water tracker's fill bar. Clean-but-alive treatment: a capsule track with a
// water fill that grows in with a spring (and springs on every +add), rendered with
// a top-lit gradient, a soft glow bleeding past its surface, and a gentle ripple on
// the leading surface (the fill's right edge) driven by TimelineView. The ripple
// runs only mid-fill — it pauses at empty and at goal, so a settled bar costs no
// frames. Height 14 so the water reads as water, not a hairline.
private struct WaterBarView: View {
    /// Fill fraction; values past 1 render as a full bar.
    let fraction: Double
    let accent: Color

    // Grow-in flag, same trick as FocusGoalRow: render 0 on first layout, then
    // animate up to the real fraction.
    @State private var shown = false

    private static let wavePeriodSeconds = 2.4

    var body: some View {
        GeometryReader { geo in
            let f = shown ? min(max(fraction, 0), 1) : 0
            let settled = f <= 0 || f >= 1
            ZStack(alignment: .leading) {
                Capsule().fill(accent.opacity(0.15))
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: settled)) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: Self.wavePeriodSeconds)
                    WaterFillShape(fraction: f,
                                   phase: cycle / Self.wavePeriodSeconds * 2 * .pi,
                                   amplitude: settled ? 0 : 2.5)
                        .fill(LinearGradient(colors: [accent.opacity(0.65), accent],
                                             startPoint: .top, endPoint: .bottom))
                        .shadow(color: accent.opacity(0.45), radius: 3)
                }
            }
            .clipShape(Capsule())
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: f)
        }
        .frame(height: 14)
        .onAppear { shown = true }
    }
}

// Claude  Date 07/16/2026
// The filled portion of WaterBarView: a rectangle whose trailing edge is a small
// travelling sine ripple (the "surface" of the water). `fraction` is the animatable
// part so springs interpolate the fill width; phase/amplitude come per-frame from
// the TimelineView. Points are clamped to x ≥ 0 so a near-empty ripple never pokes
// out the left end.
private struct WaterFillShape: Shape {
    var fraction: Double
    var phase: Double
    var amplitude: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard fraction > 0, rect.width > 0 else { return Path() }
        let edge = rect.width * min(fraction, 1)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        let steps = 16
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let ripple = sin(phase + t * .pi * 1.6) * amplitude
            p.addLine(to: CGPoint(x: max(0, edge + ripple), y: rect.height * t))
        }
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

// Claude  Date 06/16/2026
// One logged food row: name, what was eaten (servings + macro breakdown), and the
// calories for the entry on the trailing edge.
private struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        let c = entry.consumed
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.subheadline).fontWeight(.medium)
                    .lineLimit(1)
                Text("\(servingsText) • P \(g(c.protein)) · C \(g(c.carbs)) · F \(g(c.fat))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(c.calories.rounded())) kcal")
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // Claude  Date 06/16/2026 last changed: 08/06/2026 by: Claude
    // What was eaten, in the words the user used: "200 g", "2 cups", "1.5 servings".
    //
    // (Was always the servings count. Everything logged through the detail page is
    // stored as `servings: 1` with the amount folded into the nutrient snapshot, so
    // every row read a uniform, useless "1× serving" whether you'd logged 30 g or a
    // pound. The measurement is recorded on the entry now — `amountText` scales it by
    // the servings multiplier so an edited entry stays consistent. Entries logged
    // before that existed, and any plain servings-count log, keep the old wording.)
    private var servingsText: String {
        if let text = entry.amountText { return text }
        let s = entry.servings
        let n = s.rounded() == s ? String(Int(s)) : String(format: "%.2g", s)
        return "\(n)× serving"
    }

    private func g(_ value: Double) -> String { "\(Int(value.rounded()))g" }
}

// Claude  Date 07/12/2026
// One focus-goal progress row under the Summary: tinted icon chip, a thin bar in
// the Summary card's style (grow-in spring, animated updates), and a status
// caption from NutrientFocusGoal.progressText. For "stay under" goals the bar
// shows budget used and turns orange→red past the ceiling; met goals get a
// checkmark next to the label.
private struct FocusGoalRow: View {
    let goal: NutrientFocusGoal
    let consumed: Double

    @State private var shown = false

    var body: some View {
        let tint = goal.nutrient.tint
        let fraction = goal.target > 0 ? min(consumed / goal.target, 1) : 0
        let over = consumed > goal.target
        let met = goal.isMet(consumed: consumed)
        let barColors: [Color] = (goal.direction == .atMost && over)
            ? [.orange, .red.opacity(0.85)]
            : [tint, tint.opacity(0.65)]

        HStack(spacing: 10) {
            iconChip(goal.nutrient.systemImage, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(goal.nutrient.label).font(.caption).fontWeight(.medium)
                    if met {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(tint)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                    Text("\(Int(consumed.rounded())) / \(Int(goal.target)) \(goal.nutrient.unit) · \(goal.progressText(consumed: consumed))")
                        .font(.caption2).monospacedDigit()
                        .foregroundStyle((goal.direction == .atMost && over)
                                         ? Color.orange : Color.secondary)
                }
                GeometryReader { geo in
                    let shownFraction = shown ? fraction : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.15))
                        Capsule()
                            .fill(LinearGradient(colors: barColors,
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * shownFraction)
                    }
                    .animation(.spring(response: 0.55, dampingFraction: 0.8),
                               value: shownFraction)
                }
                .frame(height: 8)
            }
        }
        .padding(.vertical, 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: met)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { shown = true }
        }
    }
}

#Preview {
    NutritionJournalView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
