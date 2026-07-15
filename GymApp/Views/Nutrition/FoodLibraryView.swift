import SwiftUI

// Claude  Date 06/16/2026 last changed: 06/18/2026 by: Claude
/// The Foods tab: your "Recents" — the foods you've actually used, newest first.
/// There's no built-in starter set anymore; entries here are the ones you create
/// (the +) or pull in from a barcode / Open Food Facts search (cached on use). Add
/// with the + ; swipe to delete.
struct FoodLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var searchText = ""
    @State private var showingNewFood = false
    // Claude  Date 06/18/2026 — barcode scan state (scanner sheet + carried-over code).
    @State private var showingScanner = false
    @State private var scannedBarcode: String?
    // Claude  Date 07/14/2026
    // The food whose detail page is up (tap a row, or a barcode that just resolved).
    // Non-nil drives the FoodDetailView sheet. `item:`-bound so it also carries which
    // food to show.
    @State private var detailFood: FoodDetail?

    // Claude  Date 06/18/2026
    // Recents = the library newest-first (foods are appended on create / first scan, so
    // reverse-insertion order is "most recently added"), filtered by the search text.
    private var recents: [FoodItem] {
        let base = Array(store.foods.reversed())
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(q) || $0.brand.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if recents.isEmpty {
                    Text(searchText.isEmpty
                         ? "No foods yet. Tap + to add one, or log a food from a barcode / Open Food Facts to see it here."
                         : "No matches.")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Recents") {
                        ForEach(recents) { food in
                            // Claude  Date 07/14/2026
                            // Tapping a food opens its detail page (the same view a scan
                            // pops), built from the library FoodItem via the adapter.
                            Button { detailFood = FoodDetail(from: food) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.displayLabel).font(.subheadline).fontWeight(.medium)
                                    Text("\(Int(food.nutrients.calories.rounded())) kcal · \(food.servingLabel)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.map { recents[$0] }.forEach(store.deleteFood)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .navigationTitle("Foods")
            .themed(theme.current)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            .modeNotchToolbar()
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        scannedBarcode = nil
                        showingScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    Button {
                        scannedBarcode = nil
                        showingNewFood = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewFood, onDismiss: { scannedBarcode = nil }) {
                NewFoodView(initialBarcode: scannedBarcode)
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
            // Claude  Date 07/14/2026
            // The food detail page — pops for a tapped recent or a freshly scanned item.
            .sheet(item: $detailFood) { detail in
                FoodDetailView(food: detail)
            }
        }
    }
}

#Preview {
    FoodLibraryView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
