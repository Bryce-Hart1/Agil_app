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
    // Whether the water tracker shows at all (Settings → Water). See WaterTracking.
    @AppStorage(WaterTracking.storageKey) private var trackWater = WaterTracking.defaultValue

    // Claude  Date 08/07/2026
    // Custom-water state. Everyday logging is a one-tap quick-add; this backs the sheet
    // behind the small slider button, where a drink can be dialed in cup / fl oz / mL with
    // the same MeasurementEditor food uses. `unit == nil` never happens here — the water
    // basis has no Serving tab, so the editor stays in volume mode. The amount added is
    // persisted and resurfaces as the first quick-add chip (per-drink memory).
    @State private var waterMeasurement = FoodMeasurement(amount: 250, unit: .milliliter)
    @State private var showingCustomWater = false
    // Name for the chip being saved from the custom sheet ("" = log once, save nothing).
    @State private var customWaterName = ""
    @AppStorage("waterLastUnit") private var waterLastUnitRaw = ""
    @AppStorage("waterLastAmount") private var waterLastAmount = 0.0

    // Claude  Date 08/07/2026
    // The quick-add row's display order, snapshotted when the diary appears. Chips are
    // ranked most-used-first, but ranking LIVE would slide a chip out from under the
    // user's finger the instant they tapped it — so taps update the counts and this
    // frozen order only catches up on the next appear. Ids not in the snapshot (a chip
    // created this session) sort to the end rather than jumping the queue.
    @State private var waterOrder: [UUID] = []

    // A volume-only "food" shape: no serving tab, no count — just the volume unit family.
    private static let waterBasis = MeasurementBasis(per100: .zero, basisUnit: "ml")

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
                if trackWater { waterSection }
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

    // Claude  Date 07/16/2026 last changed: 08/07/2026 by: Claude
    // The water tracker: amount label in the user's display unit (with animated digits and
    // a checkmark once the goal is met), the animated WaterBarView fill, and one-tap
    // quick-adds. Logging water is the most repeated action in the diary, so the everyday
    // path is a SINGLE tap — the full unit editor lives behind the small slider button and
    // opens as a sheet. (Was: the MeasurementEditor inline, which was accurate but far too
    // much furniture for a "+1 glass" gesture.) All storage stays canonical ml.
    private var waterSection: some View {
        Section("Water") {
            let goal = max(store.nutritionGoals.water, 1)
            let goalMet = day.water >= goal
            VStack(alignment: .leading, spacing: 10) {
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
                HStack(spacing: 8) {
                    // The chips scroll horizontally and pass under the pinned custom
                    // button, so any number of presets fits without the row growing.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(orderedWaterPresets) { preset in
                                Button(preset.name) {
                                    store.logWater(preset: preset, on: selectedDate)
                                }
                                .buttonStyle(.bordered)
                                .contextMenu {
                                    if preset.isCustom {
                                        Button(role: .destructive) {
                                            store.deleteWaterPreset(id: preset.id)
                                        } label: {
                                            Label("Delete \(preset.name)", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        // Bordered buttons draw a hair outside their frame; without this
                        // the first and last chips clip against the scroll view's edges.
                        .padding(.horizontal, 2)
                    }
                    // The escape hatch for an amount the chips don't cover. Icon-sized on
                    // purpose: it must not compete with the one-tap adds beside it.
                    Button {
                        seedWaterMeasurement()
                        customWaterName = ""
                        showingCustomWater = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Custom water amount")
                }
                .font(.caption)
            }
            .onAppear(perform: freezeWaterOrder)
        }
        .sheet(isPresented: $showingCustomWater) { customWaterSheet }
    }

    // Claude  Date 08/07/2026
    // The chips in the order they're drawn: whatever `waterOrder` froze on appear, with
    // anything it doesn't know about (a chip added since) appended, most-used first.
    private var orderedWaterPresets: [WaterPreset] {
        let rank = Dictionary(uniqueKeysWithValues: waterOrder.enumerated().map { ($1, $0) })
        return store.waterPresets.enumerated().sorted { lhs, rhs in
            let l = rank[lhs.element.id], r = rank[rhs.element.id]
            switch (l, r) {
            case let (l?, r?) where l != r: return l < r
            case (_?, nil):                 return true
            case (nil, _?):                 return false
            default: break
            }
            // Unranked (new this session) or tied: most-used first, then insertion order
            // so the sequence is deterministic across launches.
            if lhs.element.useCount != rhs.element.useCount {
                return lhs.element.useCount > rhs.element.useCount
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    // Claude  Date 08/07/2026
    // Snapshot the most-used-first ranking. Called on appear only — never in response to a
    // tap — so the row the user is looking at holds still (see WaterPreset).
    private func freezeWaterOrder() {
        waterOrder = store.waterPresets.enumerated()
            .sorted {
                $0.element.useCount != $1.element.useCount
                    ? $0.element.useCount > $1.element.useCount
                    : $0.offset < $1.offset
            }
            .map(\.element.id)
    }

    // Claude  Date 08/07/2026
    // The custom-amount sheet: the same MeasurementEditor food uses, in volume mode
    // (cup / fl oz / mL). Naming the amount is optional — leave it blank to log a one-off,
    // or name it to keep it as a chip (up to WaterPreset.maxCustomCount of them).
    private var customWaterSheet: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    MeasurementEditor(basis: Self.waterBasis,
                                      measurement: $waterMeasurement,
                                      accent: theme.current.accent)
                        .padding(.vertical, 4)
                }
                Section {
                    TextField("Name", text: $customWaterName)
                        .disabled(!store.canAddWaterPreset)
                        // Clip at the source: a chip has to stay chip-sized, and trimming
                        // only on save would let the user type past the limit unaware.
                        .onChange(of: customWaterName) { value in
                            if value.count > WaterPreset.maxNameLength {
                                customWaterName = String(value.prefix(WaterPreset.maxNameLength))
                            }
                        }
                } header: {
                    Text("Keep as a chip (optional)")
                } footer: {
                    Text(store.canAddWaterPreset
                         ? "\(store.customWaterPresetCount) of \(WaterPreset.maxCustomCount) custom chips used. Up to \(WaterPreset.maxNameLength) characters."
                         : "All \(WaterPreset.maxCustomCount) custom chips used. Press and hold a chip to delete one.")
                }
            }
            .navigationTitle("Add water")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCustomWater = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addDialedWater()
                        showingCustomWater = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // Claude  Date 08/07/2026
    // Restore the last drink the user logged (unit + amount) so a repeat pour is one tap.
    // With no usable memory yet, open in their display unit at a sensible default. Only a
    // volume unit is accepted back — the setting could have been some stale/other value.
    private func seedWaterMeasurement() {
        if let unit = FoodUnit(rawValue: waterLastUnitRaw), unit.isVolume, waterLastAmount > 0 {
            waterMeasurement = FoodMeasurement(amount: waterLastAmount, unit: unit)
        } else {
            let unit: FoodUnit = waterUnit == .fluidOunces ? .fluidOunce : .milliliter
            waterMeasurement = FoodMeasurement(amount: unit == .fluidOunce ? 8 : 250, unit: unit)
        }
    }

    // Claude  Date 08/07/2026
    // Convert the dialed volume to canonical ml, log it on the selected day, remember the
    // unit+amount so the sheet reopens where it was left, and — when the user named it —
    // keep it as a chip. A new chip lands at the END of the row this session (it has no
    // frozen rank yet); it takes its most-used place on the next appear. `unit` is never
    // nil here (volume-only basis), but fall back to raw ml rather than trust that.
    private func addDialedWater() {
        let unit = waterMeasurement.unit ?? .milliliter
        let ml = waterMeasurement.amount * unit.perBase
        guard ml > 0 else { return }
        store.logWater(milliliters: ml, on: selectedDate)
        waterLastUnitRaw = unit.rawValue
        waterLastAmount = waterMeasurement.amount
        let name = customWaterName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            store.addWaterPreset(name: name, milliliters: ml)
        }
    }

    // MARK: - Meals

    // Claude  Date 06/16/2026 last changed: 08/06/2026 by: Claude
    // One meal's logged entries. Rows are swipe-actioned, not tappable: a whole row
    // that opens an editor is an easy thing to hit by accident while scrolling, and it
    // hid Delete behind a gesture that gave no hint it existed. Both actions are on the
    // trailing edge (the iOS convention), Delete first so a full swipe still deletes.
    private func mealSection(_ meal: MealType) -> some View {
        let entries = day.entries(for: meal)
        let mealKcal = Int(day.totals(for: meal).calories.rounded())
        return Section {
            ForEach(entries) { entry in
                FoodEntryRow(entry: entry)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.deleteFoodEntry(id: entry.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editingEntry = entry
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                        }
                        .tint(theme.current.accent)
                    }
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
