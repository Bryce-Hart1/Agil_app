import SwiftUI

/// A modal list of the exercise library. Picking one calls `onPick` and
/// dismisses. Has a search field, an inline "create the typed name" shortcut,
/// and a "Create New" button (top-right) for making one from scratch.
struct ExercisePickerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onPick: (Exercise) -> Void

    @State private var search = ""
    @State private var showingNew = false

    private var filtered: [Exercise] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.exercises }
        return store.exercises.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { exercise in
                    Button {
                        onPick(exercise)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                Text(exercise.category)
                                if exercise.isUnilateral {
                                    Text("Unilateral").fontWeight(.semibold)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // Quick "create the typed name" shortcut when it isn't found.
                let query = search.trimmingCharacters(in: .whitespaces)
                if !query.isEmpty,
                   !store.exercises.contains(where: { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }) {
                    Section {
                        Button {
                            let created = store.addExercise(name: query, category: "Other")
                            onPick(created)
                            dismiss()
                        } label: {
                            Label("Add \"\(query)\"", systemImage: "plus")
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                // Claude  Date 06/09/2026
                // Create a brand-new exercise (with category + unilateral options)
                // without having to search first.
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNew = true } label: {
                        Label("Create New", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewExerciseView(initialName: search) { created in
                    onPick(created)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
