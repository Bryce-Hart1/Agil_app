import SwiftUI

/// Sheet for logging a food into a given meal/day. Search your local library
/// (instant), search Open Food Facts online (on submit), or create a custom food on
/// the fly. Picking anything opens the serving/confirm step. Online foods are cached
/// into the library on pick so they're available offline next time.
struct FoodPickerView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let meal: MealType
    let date: Date

    // Claude  Date 06/16/2026
    // The Open Food Facts client (protocol-typed so it could be mocked). Owned by
    // the view — networking stays out of AppStore.
    private let foodService: FoodSearchService = OpenFoodFactsClient()

    @State private var searchText = ""
    @State private var path: [FoodItem] = []
    @State private var showingNewFood = false
    // Claude  Date 06/16/2026
    // Online (OFF) search state: results, an in-flight flag, a user-facing error, and
    // the running task so a new search cancels the previous one.
    @State private var onlineResults: [FoodItem] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    private var trimmedQuery: String { searchText.trimmingCharacters(in: .whitespaces) }

    // Claude  Date 06/16/2026
    // Library filtered by the search text (name or brand), seeds + custom together,
    // alphabetized. Empty search shows the whole library.
    private var results: [FoodItem] {
        let q = trimmedQuery.lowercased()
        let matches = q.isEmpty ? store.foods : store.foods.filter {
            $0.name.lowercased().contains(q) || $0.brand.lowercased().contains(q)
        }
        return matches.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        showingNewFood = true
                    } label: {
                        Label("Create custom food", systemImage: "plus.circle")
                    }
                }
                if !results.isEmpty {
                    Section("My foods") {
                        ForEach(results) { food in
                            Button { path.append(food) } label: { FoodPickRow(food: food) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                onlineSection
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search foods")
            .onSubmit(of: .search) { runOnlineSearch() }
            .onChange(of: searchText) { _ in resetOnlineSearch() }
            .navigationTitle("Add to \(meal.title)")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .navigationDestination(for: FoodItem.self) { food in
                LogFoodView(food: food, meal: meal, date: date) { dismiss() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewFood) {
                NewFoodView(initialName: searchText) { created in
                    // Straight into logging the food just created.
                    path.append(created)
                }
            }
        }
    }

    // MARK: - Online (Open Food Facts) results

    // Claude  Date 06/16/2026
    // Appears once you've typed a query. Before submitting it offers a "search
    // online" button; while running it shows a spinner; then either the mapped
    // results or a friendly error. Picking a result caches it locally, then logs it.
    @ViewBuilder
    private var onlineSection: some View {
        if !trimmedQuery.isEmpty {
            Section("Open Food Facts") {
                if isSearching {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Searching…").foregroundStyle(.secondary)
                    }
                } else if let searchError {
                    Text(searchError).font(.subheadline).foregroundStyle(.secondary)
                } else if onlineResults.isEmpty {
                    Button {
                        runOnlineSearch()
                    } label: {
                        Label("Search online for \u{201C}\(trimmedQuery)\u{201D}",
                              systemImage: "magnifyingglass")
                    }
                } else {
                    ForEach(onlineResults) { food in
                        Button { selectOnline(food) } label: { FoodPickRow(food: food) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // Caching the online food (dedupe by barcode) before logging, so it persists.
    private func selectOnline(_ food: FoodItem) {
        path.append(store.cacheFood(food))
    }

    // Claude  Date 06/16/2026
    // Kick off (or restart) an OFF search for the current query. Cancels any running
    // search first so only the latest query's results land.
    private func runOnlineSearch() {
        let q = trimmedQuery
        guard !q.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        searchError = nil
        onlineResults = []
        searchTask = Task { @MainActor in
            do {
                let found = try await foodService.search(q)
                if Task.isCancelled { return }
                onlineResults = found
                isSearching = false
                if found.isEmpty { searchError = "No results found online." }
            } catch is CancellationError {
                // Superseded by a newer search — leave state to that one.
            } catch {
                if Task.isCancelled { return }
                isSearching = false
                searchError = "Couldn't reach Open Food Facts. Check your connection."
            }
        }
    }

    // Typing a new query clears the previous online results so they don't linger.
    private func resetOnlineSearch() {
        searchTask?.cancel()
        isSearching = false
        onlineResults = []
        searchError = nil
    }
}

// Claude  Date 06/16/2026
// A library row in the picker: name (+ brand) with a per-serving calorie/macro
// caption so you can choose without opening it.
private struct FoodPickRow: View {
    let food: FoodItem

    var body: some View {
        let n = food.nutrients
        VStack(alignment: .leading, spacing: 2) {
            Text(food.displayLabel).font(.subheadline).fontWeight(.medium)
            Text("\(Int(n.calories.rounded())) kcal · \(food.servingLabel)  ·  P \(Int(n.protein.rounded()))g C \(Int(n.carbs.rounded()))g F \(Int(n.fat.rounded()))g")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// Claude  Date 06/16/2026
// The confirm step after picking a food: choose how many servings (and optionally
// re-pick the meal), see the live totals, then log it onto the diary day. Logging
// snapshots the food (see FoodEntry), so it's safe even for one-off foods.
private struct LogFoodView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    let food: FoodItem
    let date: Date
    let onLogged: () -> Void

    @State private var servings: Double
    @State private var meal: MealType

    init(food: FoodItem, meal: MealType, date: Date, onLogged: @escaping () -> Void) {
        self.food = food
        self.date = date
        self.onLogged = onLogged
        _servings = State(initialValue: 1)
        _meal = State(initialValue: meal)
    }

    private var consumed: Nutrients { food.nutrients.scaled(by: servings) }

    var body: some View {
        Form {
            Section("Food") {
                Text(food.displayLabel).font(.headline)
                Text("Per \(food.servingLabel): \(Int(food.nutrients.calories.rounded())) kcal")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Amount") {
                Stepper(value: $servings, in: 0.25...50, step: 0.25) {
                    Text("Servings: \(servingsText)")
                }
                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("This logs") {
                LabeledContent("Calories", value: "\(Int(consumed.calories.rounded())) kcal")
                LabeledContent("Protein", value: "\(Int(consumed.protein.rounded())) g")
                LabeledContent("Carbs", value: "\(Int(consumed.carbs.rounded())) g")
                LabeledContent("Fat", value: "\(Int(consumed.fat.rounded())) g")
            }
        }
        .navigationTitle("Log Food")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    store.logFood(food, servings: servings, meal: meal, on: date)
                    onLogged()
                }
            }
        }
    }

    private var servingsText: String {
        servings.rounded() == servings ? String(Int(servings)) : String(format: "%.2f", servings)
    }
}
