import SwiftUI

// Claude  Date 06/09/2026
// A form sheet for creating an exercise: name, category, and the unilateral
// toggle. Shared by the Exercises tab (+) and the workout exercise picker
// ("Create New"). Calls `onCreate` with the new exercise, then dismisses.
struct NewExerciseView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    /// Pre-fills the name field (e.g. from the picker's search text).
    let initialName: String
    /// Called with the created exercise after saving.
    let onCreate: (Exercise) -> Void

    @State private var name: String
    @State private var category: String = ""
    @State private var isUnilateral: Bool = false

    init(initialName: String = "", onCreate: @escaping (Exercise) -> Void = { _ in }) {
        self.initialName = initialName
        self.onCreate = onCreate
        _name = State(initialValue: initialName)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                    TextField("Category (e.g. Chest, Legs)", text: $category)
                }

                Section {
                    Toggle("Unilateral", isOn: $isUnilateral)
                } footer: {
                    Text("Turn on for movements done one side at a time (e.g. single-arm row, lunges) so they can be tracked separately on graphs. Leave off for two-sided lifts like bench press.")
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let exercise = store.addExercise(
            name: trimmedName,
            category: category.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Other"
                : category.trimmingCharacters(in: .whitespaces),
            isUnilateral: isUnilateral
        )
        onCreate(exercise)
        dismiss()
    }
}

#Preview {
    NewExerciseView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
