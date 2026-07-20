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
    @State private var path: [FoodItem] = []
    @State private var showingNewFood = false
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
            // Claude  Date 07/16/2026
            // The confirm step is the full food detail page now (same one the Foods tab
            // and barcode scans use) — one polished flow instead of the old bare
            // LogFoodView form. It's pushed, pre-seeded with this sheet's target meal,
            // and hands back the dialed-in nutrients; we write the diary entry onto
            // `date` and drop the whole picker sheet.
            .navigationDestination(for: FoodItem.self) { food in
                let detail = FoodDetail(from: food)
                FoodDetailView(food: detail, initialMeal: meal) { chosenMeal, consumed in
                    store.logFoodDetail(detail, consumed: consumed,
                                        meal: chosenMeal, on: date)
                    dismiss()
                }
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
            Text("You're in Offline mode. Add this food yourself, or search Open Food Facts online just for this one.")
        }
    }

    // Claude  Date 06/16/2026
    // Before submitting it offers a "search online" button; while running it shows a
    // spinner; then either the mapped results or a friendly error. Picking a result
    // caches it locally, then logs it.
    @ViewBuilder
    private var openFoodFactsSection: some View {
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
                searchError = "Couldn't reach Open Food Facts. Check your connection."
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

// Claude  Date 07/16/2026
// (LogFoodView, the old bare confirm form, is gone — FoodDetailView is the single
// serving/confirm step for every path: diary picker, Foods tab, and barcode scans.)
