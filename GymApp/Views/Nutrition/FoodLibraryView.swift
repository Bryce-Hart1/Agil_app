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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.displayLabel).font(.subheadline).fontWeight(.medium)
                                Text("\(Int(food.nutrients.calories.rounded())) kcal · \(food.servingLabel)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
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
            // Claude  Date 06/18/2026
            // Scan-to-Recents: a found product is cached into the library (no logging,
            // since there's no meal context here); a miss opens "New Food" with the code.
            .sheet(isPresented: $showingScanner) {
                BarcodeScanSheet(
                    onResolved: { food in store.cacheFood(food) },
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
}

#Preview {
    FoodLibraryView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
