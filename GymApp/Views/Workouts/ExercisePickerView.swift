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
                // Claude  Date 06/14/2026
                // Grouped by body region → muscle sub-group, mirroring the Exercises
                // tab. Search filters first, then the remaining matches are sectioned.
                ForEach(store.exercisesByRegion(filtered), id: \.region) { group in
                    Section(group.region.title) {
                        ForEach(group.exercises) { exercise in
                            Button {
                                onPick(exercise)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 6) {
                                        Text(exercise.muscleSubtitle)
                                        if exercise.isUnilateral {
                                            Text("Unilateral").fontWeight(.semibold)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Quick "create the typed name" shortcut when it isn't found.
                let query = search.trimmingCharacters(in: .whitespaces)
                if !query.isEmpty,
                   !store.exercises.contains(where: { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }) {
                    Section {
                        Button {
                            createExercise(named: query)
                        } label: {
                            Label("Add \"\(query)\"", systemImage: "plus")
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            // Claude  Date 06/13/2026
            // QoL: when the search matches no exercises, the Return key creates the
            // typed exercise instead of just dismissing the keyboard. (With matches
            // present, Return behaves as a normal search submit.)
            .onSubmit(of: .search) {
                if filtered.isEmpty { createExercise(named: search) }
            }
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

    // Claude  Date 06/13/2026
    // Create an exercise from a typed name (category "Other"), pick it, and close.
    // Shared by the inline "Add …" row and the no-results Return shortcut.
    private func createExercise(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let created = store.addExercise(name: trimmed, category: "Other")
        onPick(created)
        dismiss()
    }
}

#Preview {
    ExercisePickerView { _ in }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
