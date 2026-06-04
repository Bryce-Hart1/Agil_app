import SwiftUI

/// Browse and manage the exercise library. Add via the + button, swipe to delete.
struct ExercisesListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newCategory = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                        Text(exercise.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: store.deleteExercises)
            }
            .navigationTitle("Exercises")
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .alert("New Exercise", isPresented: $showingAdd) {
                TextField("Name", text: $newName)
                TextField("Category", text: $newCategory)
                Button("Add", action: addExercise)
                Button("Cancel", role: .cancel, action: resetForm)
            } message: {
                Text("Add a movement to your library.")
            }
        }
    }

    private func addExercise() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let category = newCategory.trimmingCharacters(in: .whitespaces)
        store.addExercise(name: name, category: category.isEmpty ? "Other" : category)
        resetForm()
    }

    private func resetForm() {
        newName = ""
        newCategory = ""
    }
}

#Preview {
    ExercisesListView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
