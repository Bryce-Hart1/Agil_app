import SwiftUI

/// Sheet for logging a food into a given meal/day. Search your local library
/// (instant), search Open Food Facts online (on submit), or create a custom food on
/// the fly. Picking anything opens the serving/confirm step. Online foods are cached
/// into the library on pick so they're available offline next time.
///
/// Claude  Date 08/11/2026
/// It has a second mode: passing `onPickIngredient` instead of a meal/date turns the
/// same screen into the recipe builder's ingredient picker — identical search, but a
/// pick returns an amount-dialed RecipeIngredient to the caller rather than writing to
/// the diary. Sharing the view is the point: the local + backend search, the offline
/// prompt, barcode scanning and custom-food creation are all things an ingredient
/// search needs, and a second copy of them would drift.
struct FoodPickerView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var meal: MealType = .other
    var date: Date = Date()
    // Non-nil = ingredient-picking mode (see the note above). Recipes themselves are
    // hidden in this mode: a recipe made of recipes is a nesting problem the frozen
    // ingredient snapshot has no answer for.
    var onPickIngredient: ((RecipeIngredient) -> Void)? = nil

    private var isPickingIngredient: Bool { onPickIngredient != nil }

    // Claude  Date 06/16/2026 last changed: 06/30/2026 by: Claude
    // The food client (protocol-typed so it could be mocked). Owned by the view —
    // networking stays out of AppStore. Now talks to the Agil backend's read-through
    // cache rather than Open Food Facts directly (all upstream traffic is server-side).
    private let foodService: FoodSearchService = BackendFoodClient()

    // Claude  Date 06/18/2026
    // Offline mode: when on, searches don't auto-reach Open Food Facts. A query with no
    // local match is met with a prompt to enter it manually or go online just for that
    // search. Shared with the Foods tab + the barcode scanner via the same key.
    @AppStorage("offlineFoodMode") private var offlineMode = false

    @State private var searchText = ""
    // Claude  Date 08/11/2026
    // Type-erased because the stack now pushes two things: a FoodItem (the serving/
    // confirm step) and a Recipe (its detail page).
    @State private var path = NavigationPath()
    @State private var showingNewFood = false
    @State private var showingNewRecipe = false
    // Claude  Date 06/18/2026
    // Barcode scan state: whether the scanner sheet is up, and the code carried into
    // "Create custom food" when a scan found nothing.
    @State private var showingScanner = false
    @State private var scannedBarcode: String?
    // True once the user has opted into an online search for the current query (in
    // offline mode), so the Open Food Facts section takes over from the offline prompt.
    @State private var startedOnlineSearch = false
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

    // Claude  Date 08/11/2026
    // The user's recipes matching the query, most recently logged first (recipes log
    // through the food pipeline, so `lastLoggedByFood` already knows about them —
    // see Recipe.asFoodItem). These get their own section at the very top of the list:
    // a recipe is something the user deliberately built, so when one matches it's
    // almost certainly what they meant.
    private var matchingRecipes: [Recipe] {
        guard !isPickingIngredient else { return [] }
        let q = trimmedQuery.lowercased()
        let matches = q.isEmpty ? store.recipes : store.recipes.filter {
            $0.name.lowercased().contains(q)
        }
        let lastLogged = store.lastLoggedByFood
        return matches.enumerated().sorted { lhs, rhs in
            switch (lastLogged[lhs.element.id], lastLogged[rhs.element.id]) {
            case let (l?, r?): return l > r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return lhs.offset > rhs.offset
            }
        }.map(\.element)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        scannedBarcode = nil
                        showingScanner = true
                    } label: {
                        Label("Scan barcode", systemImage: "barcode.viewfinder")
                    }
                    Button {
                        scannedBarcode = nil
                        showingNewFood = true
                    } label: {
                        Label("Create custom food", systemImage: "plus.circle")
                    }
                    if !isPickingIngredient {
                        Button { showingNewRecipe = true } label: {
                            Label("Create recipe", systemImage: "list.bullet.rectangle")
                        }
                    }
                }
                // Recipes first — above your own foods, which are themselves above the
                // server-ranked "All foods" list (whose order the client never touches).
                if !matchingRecipes.isEmpty {
                    Section("Recipes") {
                        ForEach(matchingRecipes) { recipe in
                            Button { path.append(recipe) } label: {
                                FoodPickRow(food: recipe.asFoodItem)
                            }
                            .buttonStyle(.plain)
                        }
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
            .navigationTitle(isPickingIngredient ? "Add ingredient" : "Add to \(meal.title)")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            // Claude  Date 07/16/2026 last changed: 08/06/2026 by: Claude
            // The confirm step is the full food detail page now (same one the Foods tab
            // and barcode scans use) — one polished flow instead of the old bare
            // LogFoodView form. It's pushed, pre-seeded with this sheet's target meal
            // AND with the amount this food was last logged at, and hands back the
            // dialed-in nutrients plus that measurement; we write the diary entry onto
            // `date` and drop the whole picker sheet.
            //
            // `FoodDetail(from:)` preserves the FoodItem's id, and the path always holds
            // the item the store actually returned (cacheFood dedupes scans by barcode
            // and can hand back a different row), so `detail.id` is the right cache key.
            //
            // Claude  Date 08/11/2026 — in ingredient-picking mode the same tap leads to
            // the amount step instead, which hands a finished RecipeIngredient back to the
            // builder rather than writing to the diary.
            .navigationDestination(for: FoodItem.self) { food in
                if let onPickIngredient {
                    IngredientAmountView(food: food) { ingredient in
                        onPickIngredient(ingredient)
                        dismiss()
                    }
                } else {
                    let detail = FoodDetail(from: food)
                    FoodDetailView(food: detail, initialMeal: meal,
                                   initialMeasurement: store.lastMeasurements[detail.id]) {
                        chosenMeal, consumed, measurement in
                        store.logFoodDetail(detail, consumed: consumed,
                                            measurement: measurement,
                                            meal: chosenMeal, on: date)
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe, initialMeal: meal, date: date,
                                 onLogged: { dismiss() })
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewFood, onDismiss: { scannedBarcode = nil }) {
                NewFoodView(initialName: scannedBarcode == nil ? searchText : "",
                            initialBarcode: scannedBarcode) { created in
                    // Straight into logging the food just created.
                    path.append(created)
                }
            }
            // Straight into the new recipe's page, same as a freshly created food.
            .sheet(isPresented: $showingNewRecipe) {
                RecipeBuilderView(initialName: trimmedQuery) { created in
                    path.append(created)
                }
            }
            // Claude  Date 06/18/2026 last changed: 07/16/2026 by: Claude
            // Scan-to-log: a found product goes straight to the serving/confirm step
            // (the food detail page, via the path). A miss hands the barcode to "Create
            // custom food", presented just after the scanner closes (avoids a
            // sheet-swap race).
            .sheet(isPresented: $showingScanner) {
                BarcodeScanSheet(
                    onResolved: { food in path.append(store.cacheFood(food)) },
                    onManualEntry: { code in
                        scannedBarcode = code
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showingNewFood = true
                        }
                    }
                )
            }
        }
    }

    // MARK: - Online (Open Food Facts) results

    // Claude  Date 06/16/2026 last changed: 06/18/2026 by: Claude
    // Below the local results: in Offline mode a query with no local match shows a
    // prompt to enter it manually or go online for just that search; otherwise (or once
    // the user has opted online) the normal Open Food Facts section appears.
    @ViewBuilder
    private var onlineSection: some View {
        if !trimmedQuery.isEmpty {
            if offlineMode && !startedOnlineSearch {
                if results.isEmpty { offlinePromptSection }
            } else {
                openFoodFactsSection
            }
        }
    }

    // Claude  Date 06/18/2026
    // Offline-mode nudge when nothing local matched: warn, then offer manual entry or an
    // explicit one-off online search (which flips over to the Open Food Facts section).
    private var offlinePromptSection: some View {
        Section {
            Button {
                scannedBarcode = nil
                showingNewFood = true
            } label: {
                Label("Enter \u{201C}\(trimmedQuery)\u{201D} manually", systemImage: "square.and.pencil")
            }
            Button {
                runOnlineSearch()
            } label: {
                Label("Search online instead", systemImage: "wifi")
            }
        } header: {
            Text("Not in your foods")
        } footer: {
            Text("Food lookups are set to local-only. Add this food yourself, or search online just for this one.")
        }
    }

    // Claude  Date 06/16/2026
    // Before submitting it offers a "search online" button; while running it shows a
    // spinner; then either the mapped results or a friendly error. Picking a result
    // caches it locally, then logs it.
    @ViewBuilder
    private var openFoodFactsSection: some View {
        // Claude  Date 06/16/2026 last changed: 08/04/2026 by: Claude
        // Titled "All foods" rather than "Open Food Facts": the backend's search now
        // spans the curated vault, OFF, generic (USDA) and restaurant foods, so the
        // section name would be wrong for most results. Each row's badge says where
        // that particular food came from.
        Section("All foods") {
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
        startedOnlineSearch = true
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
                searchError = "Couldn't reach the food database. Check your connection."
            }
        }
    }

    // Typing a new query clears the previous online results so they don't linger, and
    // re-arms the offline prompt for the new query.
    private func resetOnlineSearch() {
        searchTask?.cancel()
        isSearching = false
        onlineResults = []
        searchError = nil
        startedOnlineSearch = false
    }
}

// Claude  Date 06/16/2026 last changed: 08/04/2026 by: Claude
// A library row in the picker: name (+ brand) with a per-serving calorie/macro
// caption so you can choose without opening it. (Now also carries the compact
// provenance badge, so a curated food is distinguishable from an unreviewed
// user-submitted one before you tap in.)
private struct FoodPickRow: View {
    let food: FoodItem

    var body: some View {
        let n = food.nutrients
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(food.displayLabel).font(.subheadline).fontWeight(.medium)
                    .lineLimit(1)
                FoodSourceBadge(source: FoodTrust(food.source),
                                verification: food.verification,
                                style: .row)
                Spacer(minLength: 0)
            }
            Text("\(Int(n.calories.rounded())) kcal · \(food.servingLabel)  ·  P \(Int(n.protein.rounded()))g C \(Int(n.carbs.rounded()))g F \(Int(n.fat.rounded()))g")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// Claude  Date 07/16/2026
// (LogFoodView, the old bare confirm form, is gone — FoodDetailView is the single
// serving/confirm step for every path: diary picker, Foods tab, and barcode scans.)
