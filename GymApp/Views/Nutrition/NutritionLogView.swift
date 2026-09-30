import SwiftUI

/// The Food world's meal log. Journal owns the daily overview; this tab keeps
/// adding and editing food close to the four mealtime sections.
///
/// CLAUDE  Date 09/30/2026 — the meals are now chapters on a time thread: sorted by when
/// they happened, each entry's time in a left gutter, the gap between meals above each
/// header, and the day ribbon on top. Usual foods are one-tap chips (with undo) and ⚡︎
/// opens quick calories.
struct NutritionLogView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @Binding var selectedDate: Date
    @State private var addingToMeal: MealType?
    @State private var quickAddMeal: MealType?
    @State private var editingEntry: FoodEntry?
    @State private var showingFocusGoals = false
    @State private var showingScanner = false
    @State private var scannedBarcode: String?
    @State private var showingNewFood = false
    // CLAUDE  Date 09/30/2026 — a food page to log from: a barcode scan (no meal) or a usuals
    // chip's "Adjust amount…" (its meal preselected). Was a bare FoodDetail for scans only.
    @State private var detailToLog: LoggableDetail?
    @State private var pendingUndo: PendingUndo?

    private var day: NutritionDay { store.nutritionDay(for: selectedDate) }

    var body: some View {
        let day = self.day
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    NutritionDayPickerSection(selectedDate: $selectedDate)
                    Section {
                        DayRibbon(entries: day.entries, date: selectedDate) { id in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    let ordered = chapters(for: day)
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, chapter in
                        mealSection(chapter, after: index > 0 ? ordered[index - 1] : nil)
                    }
                }
            }
            .navigationTitle("Log")
            .themed(theme.current)
            .modeNotchToolbar(tab: AgilTabItem.log.tag)
            .undoToast($pendingUndo, accent: theme.current.accent, surface: theme.current.surface)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        scannedBarcode = nil
                        showingScanner = true
                    } label: {
                        Image("barcode")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                    .accessibilityLabel("Scan barcode")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFocusGoals = true
                        store.markNutritionSetup(\.focusGoalsOpened)
                    } label: {
                        Image(systemName: "scope")
                    }
                    .accessibilityLabel("Focus goals")
                }
            }
            .sheet(item: $addingToMeal) { meal in
                FoodPickerView(meal: meal, date: selectedDate)
            }
            .sheet(item: $quickAddMeal) { meal in
                QuickAddSheet(meal: meal, date: selectedDate)
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntryView(entry: entry)
            }
            .sheet(isPresented: $showingFocusGoals) {
                FocusGoalsView()
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScanSheet(
                    onResolved: { food in
                        let cached = store.cacheFood(food)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            detailToLog = LoggableDetail(food: FoodDetail(from: cached), meal: nil)
                        }
                    },
                    onManualEntry: { code in
                        scannedBarcode = code
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showingNewFood = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingNewFood, onDismiss: { scannedBarcode = nil }) {
                NewFoodView(initialBarcode: scannedBarcode)
            }
            .sheet(item: $detailToLog) { item in
                NavigationStack {
                    FoodDetailView(food: item.food,
                                   initialMeal: item.meal,
                                   initialMeasurement: store.lastMeasurements[item.food.id],
                                   suggestedTimes: store.suggestedLogTimes(on: selectedDate),
                                   onLog: { meal, consumed, measurement, time in
                        store.logFoodDetail(item.food, consumed: consumed,
                                            measurement: measurement, meal: meal,
                                            on: selectedDate, at: time)
                    })
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { detailToLog = nil }
                        }
                    }
                }
                .themed(theme.current)
            }
        }
    }

    // MARK: - Chapters

    // CLAUDE  Date 09/30/2026
    // The day's meals in time order. A meal with entries sits at its first entry's time;
    // an empty one at its usual time, so Add food for dinner is still where dinner goes.
    // Anytime meals (snack, other) split wherever a timed meal falls between two of their
    // entries, so a 10pm snack sits after dinner. `.other` only appears once it holds food.
    private func chapters(for day: NutritionDay) -> [MealChapter] {
        let order = Dictionary(uniqueKeysWithValues: MealType.allCases.enumerated().map { ($1, $0) })
        let timed = MealType.allCases.filter { $0.window != nil }.map { meal in
            let entries = day.chronological(for: meal)
            return MealChapter(meal: meal, part: 0, entries: entries,
                               anchor: anchor(of: entries, meal: meal), order: order[meal] ?? 0)
        }
        // Where a timed meal starts; an anytime run breaks at each one it crosses.
        let breaks = timed.filter { !$0.entries.isEmpty }.map(\.anchor)
        let anytime = MealType.allCases.filter { $0.window == nil }.flatMap { meal -> [MealChapter] in
            let entries = day.chronological(for: meal)
            if entries.isEmpty {
                return meal == .other ? [] : [MealChapter(meal: meal, part: 0, entries: [],
                                                          anchor: anchor(of: [], meal: meal),
                                                          order: order[meal] ?? 0)]
            }
            let runs = MealTiming.runs(of: entries, splitAt: breaks)
            return runs.enumerated().map { part, run in
                MealChapter(meal: meal, part: part, entries: run,
                            anchor: anchor(of: run, meal: meal), order: order[meal] ?? 0,
                            isLastPart: part == runs.count - 1)
            }
        }
        return (timed + anytime)
            .sorted { $0.anchor != $1.anchor ? $0.anchor < $1.anchor : $0.order < $1.order }
    }

    private func anchor(of entries: [FoodEntry], meal: MealType) -> TimeInterval {
        entries.first.map { MealTiming.secondsIntoDay($0.loggedAt) }
            ?? MealTiming.usualSeconds(for: meal, in: store.foodLog)
    }

    private func mealSection(_ chapter: MealChapter, after previous: MealChapter?) -> some View {
        let entries = chapter.entries
        // Excludes what the whole meal already holds today, not just this chapter's part.
        let usuals = chapter.isLastPart
            ? store.usualFoods(for: chapter.meal,
                               excluding: Set(day.chronological(for: chapter.meal).compactMap(\.foodId)))
            : []
        return Section {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                let previousEntry = index > 0 ? entries[index - 1] : nil
                Button { editingEntry = entry } label: {
                    ThreadEntryRow(entry: entry,
                                   showsTime: previousEntry.map {
                                       entry.loggedAt.timeIntervalSince($0.loggedAt) >= ThreadLayout.timeRepeat
                                   } ?? true,
                                   isFirst: index == 0,
                                   isLast: index == entries.count - 1)
                }
                .buttonStyle(.plain)
                .id(entry.id)
                .listRowInsets(ThreadLayout.rowInsets)
                .listRowSeparator(.hidden)
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
            // A split snack offers its chips and Add food once, on its latest piece.
            if chapter.isLastPart {
                if !usuals.isEmpty {
                    usualsRow(usuals, meal: chapter.meal)
                        .listRowSeparator(.hidden)
                }
                ThreadAddRow(meal: chapter.meal,
                             onAdd: { addingToMeal = chapter.meal },
                             onQuickAdd: { quickAddMeal = chapter.meal })
                    .listRowInsets(ThreadAddRow.insets)
            }
        } header: {
            ThreadChapterHeader(meal: chapter.meal, start: entries.first?.loggedAt,
                                anchor: chapter.anchor,
                                kcal: Int(entries.reduce(0) { $0 + $1.consumed.calories }.rounded()),
                                gap: gap(before: chapter, after: previous))
        }
    }

    // How long since the previous chapter ended, when both have food and it's worth saying.
    private func gap(before chapter: MealChapter, after previous: MealChapter?) -> TimeInterval? {
        guard let start = chapter.entries.first?.loggedAt,
              let end = previous?.entries.last?.loggedAt else { return nil }
        let interval = start.timeIntervalSince(end)
        return interval >= ThreadLayout.minGap ? interval : nil
    }

    // CLAUDE  Date 09/30/2026
    // The meal's usual foods as dashed chips. A tap logs the food at its remembered amount
    // and offers undo; press and hold to open the food page and change the amount first.
    private func usualsRow(_ foods: [FoodItem], meal: MealType) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(foods) { food in
                    let portion = store.relogPortion(of: food)
                    Button { logUsual(food, meal: meal) } label: {
                        UsualChip(name: food.displayName,
                                  kcal: Int(portion.consumed.calories.rounded()),
                                  accent: theme.current.accent)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            detailToLog = LoggableDetail(food: portion.detail, meal: meal)
                        } label: {
                            Label("Adjust amount…", systemImage: "slider.horizontal.3")
                        }
                    }
                }
            }
            .padding(.leading, ThreadLayout.contentLeading)
            .padding(.trailing, 16)
            .padding(.vertical, 2)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }

    private func logUsual(_ food: FoodItem, meal: MealType) {
        Haptics.tap()
        let id = withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            store.logUsual(food, meal: meal, on: selectedDate)
        }
        pendingUndo = PendingUndo(message: "Logged \(food.displayName)",
                                  systemImage: "checkmark.circle") {
            store.deleteFoodEntry(id: id)
        }
    }
}

// CLAUDE  Date 09/30/2026
// A food page waiting to be logged from the Log tab, and the meal to open it on (nil = let
// the page guess from the time of day).
private struct LoggableDetail: Identifiable {
    let food: FoodDetail
    let meal: MealType?
    var id: UUID { food.id }
}

// CLAUDE  Date 09/30/2026
// One meal on the thread: its entries oldest first, and the time of day (seconds) it's
// sorted by. `part` numbers the pieces of a split snack; `order` is the meal's place in
// MealType.allCases, the tiebreak.
private struct MealChapter: Identifiable {
    let meal: MealType
    let part: Int
    let entries: [FoodEntry]
    let anchor: TimeInterval
    let order: Int
    var isLastPart = true

    var id: String { "\(meal.rawValue)-\(part)" }
}

// CLAUDE  Date 09/30/2026
// Shared geometry for the thread, so the rows, chips and Add food line up on one column.
// Internal (not private) because the Help demo's copy of the Log draws with these too.
enum ThreadLayout {
    static let gutterWidth: CGFloat = 44
    static let dotSize: CGFloat = 8
    static let spacing: CGFloat = 8
    static let rowInsets = EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 16)
    // Where a row's text starts, measured from the cell's leading edge.
    static let contentLeading = rowInsets.leading + gutterWidth + spacing + dotSize + spacing
    // Add food's plus is centred on the dot column.
    static let addIconWidth: CGFloat = 18
    static let addIconLeading = rowInsets.leading + gutterWidth + spacing + dotSize / 2 - addIconWidth / 2
    // A row repeats the time only when it's this far past the row above.
    static let timeRepeat: TimeInterval = 15 * 60
    // Gaps shorter than this between meals aren't worth a label.
    static let minGap: TimeInterval = 30 * 60
}

// CLAUDE  Date 09/30/2026 (was FoodEntryRow)
// One logged food on the thread: time in the gutter, a daylight dot joined to its
// neighbours by a thin line, then name, amount and macros, with calories on the right.
// Quick adds read "quick add" with a bolt where the amount would be.
struct ThreadEntryRow: View {
    let entry: FoodEntry
    let showsTime: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        let c = entry.consumed
        let tint = DaylightPalette.color(at: entry.loggedAt)
        HStack(spacing: ThreadLayout.spacing) {
            Text(showsTime ? MealTiming.compactTime(entry.loggedAt) : "")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: ThreadLayout.gutterWidth, alignment: .trailing)
            Circle()
                .fill(tint)
                .frame(width: ThreadLayout.dotSize, height: ThreadLayout.dotSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName).font(.subheadline).fontWeight(.medium)
                    .lineLimit(1)
                detailLine(c)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text("\(Int(c.calories.rounded())) kcal")
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(alignment: .leading) { thread(tint) }
    }

    // The line through the dot: up to the row above unless first, down unless last.
    private func thread(_ tint: Color) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(isFirst ? .clear : tint.opacity(0.45))
            Color.clear.frame(height: ThreadLayout.dotSize)
            Rectangle().fill(isLast ? .clear : tint.opacity(0.45))
        }
        .frame(width: 1.5)
        .padding(.leading, ThreadLayout.gutterWidth + ThreadLayout.spacing
                 + (ThreadLayout.dotSize - 1.5) / 2)
    }

    @ViewBuilder
    private func detailLine(_ c: Nutrients) -> some View {
        let macros = "P \(g(c.protein)) · C \(g(c.carbs)) · F \(g(c.fat))"
        if entry.isQuickAdd {
            Text("\(Image(systemName: "bolt.fill")) quick add • \(macros)")
        } else {
            Text("\(servingsText) • \(macros)")
        }
    }

    private var servingsText: String {
        if let text = entry.amountText { return text }
        let s = entry.servings
        let n = s.rounded() == s ? String(Int(s)) : String(format: "%.2g", s)
        return "\(n)× serving"
    }

    private func g(_ value: Double) -> String { "\(Int(value.rounded()))g" }
}

// CLAUDE  Date 09/30/2026
// A meal chapter's section header: meal icon in the daylight tint of its time, the meal's
// start time and calories, and above it how long since the previous meal ("4h 20m later").
struct ThreadChapterHeader: View {
    let meal: MealType
    let start: Date?
    let anchor: TimeInterval
    let kcal: Int
    let gap: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let gap {
                Text("\(MealTiming.gapText(gap)) later")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(nil)
            }
            HStack(spacing: 6) {
                Image(systemName: meal.systemImage)
                    .foregroundStyle(DaylightPalette.color(atSeconds: anchor))
                Text(meal.title)
                if let start {
                    Text("· \(MealTiming.compactTime(start))")
                        .monospacedDigit()
                        .textCase(nil)
                }
                Spacer()
                if kcal > 0 { Text("\(kcal) kcal").monospacedDigit() }
            }
        }
    }
}

// CLAUDE  Date 09/30/2026
// Add food, with its plus sitting on the thread's column and its text lined up with the
// rows above, and ⚡︎ (quick calories) on the far right. Borderless so each is its own
// tap target inside one list row. Callers apply `insets` as the row's insets.
struct ThreadAddRow: View {
    let meal: MealType
    let onAdd: () -> Void
    let onQuickAdd: () -> Void

    static let insets = EdgeInsets(top: 0, leading: ThreadLayout.addIconLeading, bottom: 0, trailing: 16)

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onAdd) {
                HStack(spacing: ThreadLayout.contentLeading - ThreadLayout.addIconLeading
                                - ThreadLayout.addIconWidth) {
                    Image(systemName: "plus.circle.fill")
                        .frame(width: ThreadLayout.addIconWidth)
                    Text("Add food")
                }
                .font(.subheadline)
            }
            Spacer()
            Button(action: onQuickAdd) {
                Image(systemName: "bolt.fill")
                    .font(.subheadline)
            }
            .accessibilityLabel("Quick add calories to \(meal.title)")
        }
        .buttonStyle(.borderless)
    }
}

// CLAUDE  Date 09/30/2026
// A usual food as a dashed "+ greek yogurt · 150" chip: dashed because it isn't logged yet,
// just offered. Name capped so three chips still fit on a small phone.
private struct UsualChip: View {
    let name: String
    let kcal: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(name)
                .lineLimit(1)
                .frame(maxWidth: 130, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
            Text("\(kcal)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(
            Capsule().strokeBorder(accent.opacity(0.55),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        )
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Log \(name), \(kcal) calories")
    }
}

#Preview {
    NutritionLogView(selectedDate: .constant(Date()))
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
