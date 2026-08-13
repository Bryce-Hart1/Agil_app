import SwiftUI

// Claude  Date 06/16/2026 last changed: 08/04/2026 by: Claude
/// The Foods tab: your "Recents" — the foods you've actually used, newest first —
/// plus one all-in-one search across every food source. Entries under Recents are the
/// ones you create (the +) or pull in from a barcode / search (cached on use); add
/// with the + ; swipe to delete.
///
/// (Search used to be local-only. It now also queries the backend as you type, which
/// returns curated/OFF/generic/restaurant foods in one blended-ranked list — see
/// `searchSection`. Results carry a provenance badge so where a food came from, and
/// whether anyone has vouched for its numbers, is visible before you open it.)
struct FoodLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Claude  Date 08/04/2026
    // The food client, protocol-typed so it can be mocked. Same instance type the
    // diary's picker uses; CachedFoodService isn't wrapped here because its cache is
    // barcode-keyed and text search passes straight through it anyway.
    private let foodService: FoodSearchService = BackendFoodClient()

    // Claude  Date 08/04/2026
    // Offline mode: when on, searches don't auto-reach the network. Shared with the
    // diary picker and the barcode scanner via this same key.
    @AppStorage("offlineFoodMode") private var offlineMode = false

    @State private var searchText = ""
    @State private var showingNewFood = false
    @State private var showingNewRecipe = false
    // Claude  Date 08/11/2026
    // The recipe whose detail page is up, and the one being edited in the builder.
    @State private var detailRecipe: Recipe?
    @State private var editingRecipe: Recipe?
    // Claude  Date 08/04/2026
    // Backend search state: results in SERVER order (ranking is server-side — the
    // blended relevance × trust score — so the client must never re-sort), an
    // in-flight flag, a user-facing error, and whether the user has opted into an
    // online search for this query while in offline mode.
    @State private var onlineResults: [FoodItem] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var startedOnlineSearch = false
    // Bumped by "Try again" to re-fire the search task on an unchanged query (the
    // task id has to actually change for `.task(id:)` to restart).
    @State private var retryToken = 0
    // Claude  Date 06/18/2026 — barcode scan state (scanner sheet + carried-over code).
    @State private var showingScanner = false
    @State private var scannedBarcode: String?
    // Claude  Date 07/14/2026
    // The food whose detail page is up (tap a row, or a barcode that just resolved).
    // Non-nil drives the FoodDetailView sheet. `item:`-bound so it also carries which
    // food to show.
    @State private var detailFood: FoodDetail?

    private var trimmedQuery: String { searchText.trimmingCharacters(in: .whitespaces) }

    // Claude  Date 06/18/2026 last changed: 08/07/2026 by: Claude
    // Recents = the library ordered by most recently LOGGED first, so re-logging a food
    // bumps it back to the top (the old behaviour was reverse-insertion order, which never
    // reordered on re-log). Foods you've never logged have no diary date, so they fall
    // below the logged ones in reverse-insertion order ("most recently added"). Filtered
    // by the search text.
    private var recents: [FoodItem] {
        let lastLogged = store.lastLoggedByFood
        let base = store.foods.enumerated().sorted { lhs, rhs in
            switch (lastLogged[lhs.element.id], lastLogged[rhs.element.id]) {
            case let (l?, r?): return l > r          // both logged → newer first
            case (_?, nil):    return true           // logged sorts above never-logged
            case (nil, _?):    return false
            case (nil, nil):   return lhs.offset > rhs.offset  // reverse-insertion
            }
        }.map(\.element)
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(q) || $0.brand.lowercased().contains(q)
        }
    }

    // Claude  Date 08/11/2026
    // The user's recipes, filtered by the query and ordered by the same "most recently
    // logged first" rule Recents uses — recipes log through the food pipeline, so
    // `lastLoggedByFood` covers them without any extra bookkeeping (see Recipe.asFoodItem).
    private var matchingRecipes: [Recipe] {
        let lastLogged = store.lastLoggedByFood
        let base = store.recipes.enumerated().sorted { lhs, rhs in
            switch (lastLogged[lhs.element.id], lastLogged[rhs.element.id]) {
            case let (l?, r?): return l > r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return lhs.offset > rhs.offset
            }
        }.map(\.element)
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.lowercased().contains(q) }
    }

    // Claude  Date 08/04/2026
    // Backend results minus anything already in your library, so the same food never
    // appears twice in one search. Barcode is the reliable key; id catches cached
    // foods whose barcode is missing (restaurant foods have none at all — a duplicate
    // there is the verifier's problem, not something the client can detect). Server
    // order is preserved exactly.
    private var onlineResultsDeduped: [FoodItem] {
        let localBarcodes = Set(store.foods.compactMap { code -> String? in
            guard let barcode = code.barcode, !barcode.isEmpty else { return nil }
            return barcode
        })
        let localIDs = Set(store.foods.map(\.id))
        return onlineResults.filter { item in
            if let code = item.barcode, !code.isEmpty, localBarcodes.contains(code) {
                return false
            }
            return !localIDs.contains(item.id)
        }
    }

    // Whether the network may be reached for the current query.
    private var canSearchOnline: Bool { !offlineMode || startedOnlineSearch }

    var body: some View {
        NavigationStack {
            List {
                // Claude  Date 06/16/2026 last changed: 08/04/2026 by: Claude
                // Your own foods first (they're instant and they're what you reach for
                // most), then everything the backend found. The empty-library hint only
                // makes sense with no query — mid-search, an empty local section just
                // means "nothing of yours matched", and the search section speaks for
                // itself.
                // Claude  Date 08/11/2026
                // Recipes take the top of the list — a dish the user built themselves
                // outranks anything found for them.
                if !matchingRecipes.isEmpty {
                    Section("Recipes") {
                        ForEach(matchingRecipes) { recipe in
                            Button { detailRecipe = recipe } label: {
                                FoodLibraryRow(food: recipe.asFoodItem)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.map { matchingRecipes[$0] }.forEach(store.deleteRecipe)
                        }
                    }
                }
                if recents.isEmpty && trimmedQuery.isEmpty && matchingRecipes.isEmpty {
                    Text("No foods yet. Tap + to add one, or log a food from a barcode / search to see it here.")
                        .foregroundStyle(.secondary)
                } else if !recents.isEmpty {
                    Section(trimmedQuery.isEmpty ? "Recents" : "My foods") {
                        ForEach(recents) { food in
                            // Claude  Date 07/14/2026
                            // Tapping a food opens its detail page (the same view a scan
                            // pops), built from the library FoodItem via the adapter.
                            Button { detailFood = FoodDetail(from: food) } label: {
                                FoodLibraryRow(food: food)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.map { recents[$0] }.forEach(store.deleteFood)
                        }
                    }
                }
                searchSection
            }
            .searchable(text: $searchText, prompt: "Search all foods")
            // Claude  Date 08/04/2026
            // Debounced backend search. `.task(id:)` cancels and restarts on every
            // keystroke, so the sleep below means only the query the user actually
            // stopped on reaches the network — no per-character requests. The id also
            // carries the offline opt-in so tapping "Search online" re-runs the task.
            .task(id: "\(trimmedQuery)|\(canSearchOnline)|\(retryToken)") {
                await runSearch()
            }
            // A new query re-arms the offline prompt (the previous opt-in was for the
            // previous query only).
            .onChange(of: searchText) { _ in startedOnlineSearch = false }
            .navigationTitle("Foods")
            .themed(theme.current)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            .modeNotchToolbar(tab: AgilTabItem.foods.tag)
            .toolbar {
                // Claude  Date 07/28/2026 last changed: 08/04/2026 by: Claude
                // Scan on the left, add on the right — one real button per side, the
                // same shape every other root tab uses.
                //
                // This replaces a pair of invisible width-reserving stand-ins that used
                // to sit on the leading side purely to keep the ModeNotch pill centered
                // against two trailing buttons. Under the current toolbar style each
                // item group draws its own capsule, so a group holding only invisible
                // content rendered as an empty capsule floating in the corner. A real
                // button on each side removes it and gives scanning its own target.
                //
                // Nothing reserves width now: the two sides differ only by the barcode
                // glyph vs the plus, which shifts the pill by a couple of points.
                // Re-balancing would put a half-empty capsule back on screen, and that
                // reads far worse than a slightly off-center pill.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        scannedBarcode = nil
                        showingScanner = true
                    } label: {
                        scanIcon
                    }
                    .accessibilityLabel("Scan barcode")
                }
                // Claude  Date 08/11/2026 — the + now offers both things you can create
                // here. A menu rather than two buttons: a second toolbar glyph would
                // shift the centered ModeNotch pill again (see the note above).
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            scannedBarcode = nil
                            showingNewFood = true
                        } label: {
                            Label("Create custom food", systemImage: "plus.circle")
                        }
                        Button {
                            showingNewRecipe = true
                        } label: {
                            Label("Create recipe", systemImage: "list.bullet.rectangle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a food or recipe")
                }
            }
            .sheet(isPresented: $showingNewFood, onDismiss: { scannedBarcode = nil }) {
                NewFoodView(initialBarcode: scannedBarcode)
            }
            .sheet(isPresented: $showingNewRecipe) {
                RecipeBuilderView()
            }
            // Claude  Date 08/11/2026
            // The recipe detail page — same sheet shape the food detail page uses here
            // (this view owns the NavigationStack and the Done button). "Edit" swaps to
            // the builder, presented just after this sheet closes to avoid a sheet-swap
            // race, the same trick the scanner paths above use.
            .sheet(item: $detailRecipe) { recipe in
                NavigationStack {
                    RecipeDetailView(recipe: recipe, onEdit: {
                        detailRecipe = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            editingRecipe = recipe
                        }
                    })
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { detailRecipe = nil }
                        }
                    }
                }
                .themed(theme.current)
            }
            .sheet(item: $editingRecipe) { recipe in
                RecipeBuilderView(editing: recipe)
            }
            // Claude  Date 06/18/2026 last changed: 07/14/2026 by: Claude
            // Scan-to-Recents: a found product is cached into the library (no logging,
            // since there's no meal context here); a miss opens "New Food" with the code.
            // (Now also pops the detail page for the resolved food — presented just after
            // the scanner sheet closes to avoid a sheet-swap race, same trick as manual
            // entry below.)
            .sheet(isPresented: $showingScanner) {
                BarcodeScanSheet(
                    onResolved: { food in
                        let cached = store.cacheFood(food)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            detailFood = FoodDetail(from: cached)
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
            // Claude  Date 07/14/2026 last changed: 07/16/2026 by: Claude
            // The food detail page — pops for a tapped recent or a freshly scanned item.
            // (`onLog` writes the dialed-in amount into the diary under the chosen meal,
            // on today. Cached scans / recents carry a real library id, so the snapshot
            // links back via foodId. The page no longer owns a NavigationStack — the
            // diary picker pushes it — so this sheet provides the stack and the Done.)
            .sheet(item: $detailFood) { detail in
                NavigationStack {
                    FoodDetailView(food: detail,
                                   initialMeasurement: store.lastMeasurements[detail.id],
                                   onLog: { meal, consumed, measurement in
                        store.logFoodDetail(detail, consumed: consumed,
                                            measurement: measurement, meal: meal)
                    })
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { detailFood = nil }
                        }
                    }
                }
                .themed(theme.current)
            }
        }
    }

    // MARK: - Toolbar glyphs

    // Claude  Date 08/04/2026
    // The scan button's glyph — the custom barcode mark, template-rendered so it takes
    // the toolbar tint (the SVG ships with a hardcoded black fill). 22×22 matches the
    // custom toolbar icons in WorkoutsListView and ProfileView, so the three tabs'
    // buttons line up at the same optical size.
    private var scanIcon: some View {
        Image("barcode")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
    }

    // MARK: - All-foods search

    // Claude  Date 08/04/2026
    // The one all-in-one search section: curated Agil foods, Open Food Facts, generic
    // (USDA) staples and restaurant foods, blended and ranked server-side. In offline
    // mode it's replaced by a prompt offering manual entry or a one-off online search
    // (same affordance the diary picker uses, so the two behave identically).
    @ViewBuilder private var searchSection: some View {
        if trimmedQuery.count >= 2 {
            if !canSearchOnline {
                offlinePromptSection
            } else {
                Section("All foods") {
                    if isSearching {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching…").foregroundStyle(.secondary)
                        }
                    } else if let searchError {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(searchError).font(.subheadline).foregroundStyle(.secondary)
                            Button("Try again") { retryToken += 1 }
                                .font(.subheadline)
                        }
                    } else {
                        ForEach(onlineResultsDeduped) { food in
                            // Picking an online food caches it into the library first
                            // (dedupe by barcode lives in cacheFood), so the detail
                            // page's log links back to a real library id.
                            Button { detailFood = FoodDetail(from: store.cacheFood(food)) } label: {
                                FoodLibraryRow(food: food)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // Claude  Date 08/04/2026 (mirrors FoodPickerView.offlinePromptSection)
    // Offline-mode nudge: add the food yourself, or go online just for this query.
    private var offlinePromptSection: some View {
        Section {
            Button {
                scannedBarcode = nil
                showingNewFood = true
            } label: {
                Label("Enter \u{201C}\(trimmedQuery)\u{201D} manually", systemImage: "square.and.pencil")
            }
            Button {
                startedOnlineSearch = true
            } label: {
                Label("Search online instead", systemImage: "wifi")
            }
        } header: {
            Text("Not in your foods")
        } footer: {
            Text("Food lookups are set to local-only. Add this food yourself, or search online just for this one.")
        }
    }

    // Claude  Date 08/04/2026
    // Runs one debounced search for the current query. Clears prior results up front so
    // stale hits never sit under a new query, waits out the debounce (cancellation from
    // `.task(id:)` aborts here on the next keystroke, before any request goes out), then
    // fetches. Results are stored in server order — the backend owns ranking.
    @MainActor private func runSearch() async {
        onlineResults = []
        searchError = nil
        let q = trimmedQuery
        guard q.count >= 2, canSearchOnline else {
            isSearching = false
            return
        }
        isSearching = true
        do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
        guard !Task.isCancelled else { return }
        do {
            let found = try await foodService.search(q)
            guard !Task.isCancelled else { return }
            isSearching = false
            onlineResults = found
            if found.isEmpty {
                searchError = "No results for \u{201C}\(q)\u{201D}."
            }
        } catch is CancellationError {
            // Superseded by a newer query — that task owns the state now.
        } catch {
            guard !Task.isCancelled else { return }
            isSearching = false
            searchError = "Couldn't reach the food database. Check your connection."
        }
    }
}

// Claude  Date 08/04/2026
// A food row in the Foods tab: name (+ brand), its provenance badge, and the
// per-serving calorie caption. The badge is the compact icon-only style — at list
// width a full-text badge would push the food's own name out of the way.
private struct FoodLibraryRow: View {
    let food: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(food.name).font(.subheadline).fontWeight(.medium)
                    .lineLimit(1)
                FoodSourceBadge(source: FoodTrust(food.source),
                                verification: food.verification,
                                style: .row)
                Spacer(minLength: 0)
            }
            Text(captionText)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var captionText: String {
        let kcal = Int(food.nutrients.calories.rounded())
        let brand = food.brand.trimmingCharacters(in: .whitespaces)
        let base = "\(kcal) kcal · \(food.servingLabel)"
        return brand.isEmpty ? base : "\(brand) · \(base)"
    }
}

#Preview {
    FoodLibraryView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
