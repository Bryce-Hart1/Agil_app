import SwiftUI

/// Browse the food library — the nutrition analog of the exercise list. Foods are
/// split into your custom foods and the built-in starter set. Add custom foods with
/// the + ; swipe to delete. (Online Open Food Facts search arrives in Phase 2.)
struct FoodLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var searchText = ""
    @State private var showingNewFood = false

    private var filtered: [FoodItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.foods }
        return store.foods.filter {
            $0.name.lowercased().contains(q) || $0.brand.lowercased().contains(q)
        }
    }

    private var customFoods: [FoodItem] {
        filtered.filter { $0.source == .custom }.sorted { $0.name < $1.name }
    }
    private var builtInFoods: [FoodItem] {
        filtered.filter { $0.source != .custom }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.foods.isEmpty {
                    Text("No foods yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
                } else {
                    foodSection("My Foods", customFoods)
                    foodSection("Built-in", builtInFoods)
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .navigationTitle("Foods")
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewFood = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNewFood) {
                NewFoodView()
            }
        }
    }

    @ViewBuilder
    private func foodSection(_ title: String, _ foods: [FoodItem]) -> some View {
        if !foods.isEmpty {
            Section(title) {
                ForEach(foods) { food in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.displayLabel).font(.subheadline).fontWeight(.medium)
                        Text("\(Int(food.nutrients.calories.rounded())) kcal · \(food.servingLabel)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    offsets.map { foods[$0] }.forEach(store.deleteFood)
                }
            }
        }
    }
}

#Preview {
    FoodLibraryView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
