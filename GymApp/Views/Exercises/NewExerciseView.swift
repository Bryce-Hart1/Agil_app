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
    // Claude  Date 06/14/2026
    // Body region (primary grouping). Defaults to Other so a quick custom add isn't
    // forced to classify; the user can pick a region to file it under in the list.
    @State private var region: MuscleRegion = .other
    @State private var category: String = ""
    // Claude  Date 06/14/2026
    // The muscle this lift primarily drives — mirrors the curated library's
    // primaryMover. Optional for custom exercises.
    @State private var primaryMover: String = ""
    @State private var isUnilateral: Bool = false
    @State private var liftType: LiftType? = nil

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
                    Picker("Region", selection: $region) {
                        ForEach(MuscleRegion.allCases, id: \.self) { region in
                            Text(region.title).tag(region)
                        }
                    }
                    TextField("Muscle group (e.g. Quads, Chest, Biceps)", text: $category)
                    TextField("Primary mover (e.g. Quadriceps)", text: $primaryMover)
                }

                Section {
                    Toggle("Unilateral", isOn: $isUnilateral)
                } footer: {
                    Text("Turn on for movements done one side at a time (e.g. single-arm row, lunges) so they can be tracked separately on graphs. Leave off for two-sided lifts like bench press.")
                }

                // Claude  Date 06/13/2026
                // Tag the movement as one of the powerlifting "big 3" so the lift
                // achievements count it exactly (no name guessing).
                Section {
                    Picker("Big-3 lift", selection: $liftType) {
                        Text("None").tag(LiftType?.none)
                        ForEach(LiftType.allCases, id: \.self) { type in
                            Text(type.title).tag(LiftType?.some(type))
                        }
                    }
                } footer: {
                    Text("Mark this as the back squat, bench press, or deadlift to count it toward the big-3 lift achievements.")
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
            region: region,
            category: category.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Other"
                : category.trimmingCharacters(in: .whitespaces),
            isUnilateral: isUnilateral,
            liftType: liftType,
            primaryMover: primaryMover.trimmingCharacters(in: .whitespaces)
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
