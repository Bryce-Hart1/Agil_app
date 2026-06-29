import SwiftUI

// Claude  Date 06/09/2026 last changed: 06/18/2026 by: Claude
// A form sheet for creating OR editing an exercise: name, region, category, primary
// mover, and the unilateral toggle. Shared by the Exercises tab (+), the workout
// exercise picker ("Create New"), and the pencil in the workout editor's exercise
// header. Pass `editing:` to edit an existing exercise in place (its liftType/quality
// are preserved); otherwise it creates one. Calls `onCreate` with the saved exercise.
struct NewExerciseView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    /// Pre-fills the name field (e.g. from the picker's search text).
    let initialName: String
    /// The existing exercise being edited, or nil to create a new one.
    let editing: Exercise?
    /// Called with the saved (created or updated) exercise after saving.
    let onCreate: (Exercise) -> Void

    @State private var name: String
    // Claude  Date 06/14/2026 last changed: 06/18/2026 by: Claude
    // Body region (primary grouping). Initialized in init — from the edited exercise,
    // or Other for a new one so a quick custom add isn't forced to classify.
    @State private var region: MuscleRegion
    @State private var category: String
    // Claude  Date 06/14/2026
    // The muscle this lift primarily drives — mirrors the curated library's
    // primaryMover. Optional for custom exercises.
    @State private var primaryMover: String
    @State private var isUnilateral: Bool
    // Claude  Date 06/16/2026
    // Drives the "what's a primary mover?" help alert. (The big-3 `liftType` picker
    // was removed — custom lifts can't be tagged big-3; only the seeded canonical
    // squat/bench/deadlift carry that tag, so the lift achievements stay exact.)
    @State private var showingMoverHelp = false

    init(initialName: String = "", editing: Exercise? = nil,
         onCreate: @escaping (Exercise) -> Void = { _ in }) {
        self.initialName = initialName
        self.editing = editing
        self.onCreate = onCreate
        _name = State(initialValue: editing?.name ?? initialName)
        _region = State(initialValue: editing?.region ?? .other)
        _category = State(initialValue: editing?.category ?? "")
        _primaryMover = State(initialValue: editing?.primaryMover ?? "")
        _isUnilateral = State(initialValue: editing?.isUnilateral ?? false)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    // Claude  Date 06/16/2026
    // Canonical movers matching what's typed (case-insensitive), excluding an exact
    // match — shown as tap-to-fill suggestions so spelling stays consistent.
    private var moverSuggestions: [String] {
        let q = primaryMover.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let matches = Exercise.commonPrimaryMovers.filter { $0.lowercased().contains(q) }
        if matches.count == 1 && matches[0].lowercased() == q { return [] }
        return Array(matches.prefix(6))
    }

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
                }

                // Claude  Date 06/16/2026
                // Primary mover is optional (leave blank if unsure) — a "?" explains
                // what it is, and typing offers canonical-spelling suggestions so the
                // library doesn't fill up with variants/typos.
                Section {
                    HStack {
                        TextField("Primary mover (optional)", text: $primaryMover)
                        Button {
                            showingMoverHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("What is a primary mover?")
                    }
                    ForEach(moverSuggestions, id: \.self) { suggestion in
                        Button {
                            primaryMover = suggestion
                        } label: {
                            Label(suggestion, systemImage: "arrow.up.left.circle")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("Primary mover")
                } footer: {
                    Text("The main muscle this lift drives. Optional — leave blank if you're not sure.")
                }

                Section {
                    Toggle("Unilateral", isOn: $isUnilateral)
                } footer: {
                    Text("Turn on for movements done one side at a time (e.g. single-arm row, lunges) so they can be tracked separately on graphs. Leave off for two-sided lifts like bench press.")
                }
            }
            .navigationTitle(editing == nil ? "New Exercise" : "Edit Exercise")
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
            .alert("Primary mover", isPresented: $showingMoverHelp) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("The primary mover is the main muscle a lift drives — e.g. Quadriceps for a squat, or Latissimus Dorsi for a lat pulldown. It's used to group and label exercises. It's optional: leave it blank if you're unsure, or start typing to pick a muscle from the suggestions.")
            }
        }
    }

    private func save() {
        // Claude  Date 06/16/2026 last changed: 06/18/2026 by: Claude
        // Snap the mover to its canonical spelling (no-op if blank or already canonical).
        let resolvedCategory = category.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Other"
            : category.trimmingCharacters(in: .whitespaces)
        let resolvedMover = Exercise.normalizedPrimaryMover(primaryMover)

        let saved: Exercise
        if var existing = editing {
            // Edit in place — preserve id, liftType, and quality (not shown in this form).
            existing.name = trimmedName
            existing.region = region
            existing.category = resolvedCategory
            existing.isUnilateral = isUnilateral
            existing.primaryMover = resolvedMover
            store.updateExercise(existing)
            saved = existing
        } else {
            // Create — no liftType is passed; custom lifts are never big-3 (stays nil).
            saved = store.addExercise(
                name: trimmedName,
                region: region,
                category: resolvedCategory,
                isUnilateral: isUnilateral,
                primaryMover: resolvedMover
            )
        }
        onCreate(saved)
        dismiss()
    }
}

#Preview {
    NewExerciseView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
