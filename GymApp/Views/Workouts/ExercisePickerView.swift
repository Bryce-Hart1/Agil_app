import SwiftUI

/// A modal list of the exercise library. Picking one calls `onPick` and
/// dismisses. Includes a search field and the ability to create a new exercise
/// inline if it isn't in the library yet.
struct ExercisePickerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onPick: (Exercise) -> Void

    @State private var search = ""

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
                            Text(exercise.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Offer to create the typed name if it doesn't already exist.
                let query = search.trimmingCharacters(in: .whitespaces)
                if !query.isEmpty,
                   !store.exercises.contains(where: { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }) {
                    Section {
                        Button {
                            store.addExercise(name: query, category: "Other")
                            if let created = store.exercises.last {
                                onPick(created)
                            }
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
            }
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
        .environmentObject(AppStore())
}
