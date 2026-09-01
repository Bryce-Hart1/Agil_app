import SwiftUI

/// A modal list of the exercise library. Picking one calls `onPick` and
/// dismisses. Has a search field, an inline "create the typed name" shortcut,
/// and a "Create New" button (top-right) for making one from scratch.
struct ExercisePickerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    // Claude  Date 08/16/2026
    // The lift being swapped OUT, when the picker was opened by a Swap button (nil when
    // it's just adding an exercise). Its only job is to float plausible substitutes into
    // a section above the library — scrolling from Chest down to Chest to trade one press
    // for another was the whole friction. Purely additive: the full grouped library still
    // renders below, unchanged, and a promoted lift also stays in its normal section so
    // nothing goes missing from where you'd expect to find it.
    var relatedTo: Exercise?

    let onPick: (Exercise) -> Void

    @State private var search = ""
    @State private var showingNew = false
    // Claude  Date 08/18/2026
    // The lift being branded via a row's swipe action (nil = none). Saving picks the new
    // branded lift and closes the picker — you're standing at the machine adding it to
    // today's workout, so making you find it again afterwards is the wrong ending.
    @State private var brandingBase: Exercise?

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    private var filtered: [Exercise] {
        guard !query.isEmpty else { return store.exercises }
        return store.exercises.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            // Claude  Date 08/18/2026
            // Brand is searchable too, so typing "hammer" pulls up every Hammer Strength
            // machine in the library at once (same as the food picker does with brands).
            || $0.brand.localizedCaseInsensitiveContains(query)
            || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    // Claude  Date 08/16/2026
    // Suppressed the moment anything is typed: once you're searching you've said what you
    // want, and a "Similar" block above the matches would just push them off screen.
    private var related: [Exercise] {
        guard query.isEmpty, let target = relatedTo else { return [] }
        return Exercise.related(to: target, in: store.exercises)
    }

    // Claude  Date 08/18/2026
    // The other versions of the same lift — generic + every branded one. Their own
    // section, above "Similar", because swapping a Hammer Strength leg press for the
    // Prime one is a different (and far more common) move than swapping it for a hack
    // squat. They're excluded from `related` so four brands can't fill its six slots.
    private var siblings: [Exercise] {
        guard query.isEmpty, let target = relatedTo else { return [] }
        return Exercise.brandSiblings(of: target, in: store.exercises)
    }

    var body: some View {
        NavigationStack {
            List {
                if !siblings.isEmpty, let target = relatedTo {
                    Section("Other versions of \(target.name)") {
                        ForEach(siblings) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                }

                if !related.isEmpty, let target = relatedTo {
                    Section("Similar to \(target.displayLabel)") {
                        ForEach(related) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                }

                // Claude  Date 06/14/2026
                // Grouped by body region → muscle sub-group, mirroring the Exercises
                // tab. Search filters first, then the remaining matches are sectioned.
                ForEach(store.exercisesByRegion(filtered), id: \.region) { group in
                    Section(group.region.title) {
                        ForEach(group.exercises) { exercise in
                            exerciseRow(exercise)
                        }
                    }
                }

                // Quick "create the typed name" shortcut when it isn't found.
                // Claude  Date 08/18/2026
                // Also guards on brandedName, so typing out "Leg Press Hammer Strength"
                // offers to create a junk stub named after a machine you already have.
                if !query.isEmpty,
                   !store.exercises.contains(where: {
                       $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame
                       || $0.brandedName.localizedCaseInsensitiveCompare(query) == .orderedSame
                   }) {
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
            .navigationTitle(relatedTo == nil ? "Add Exercise" : "Swap Exercise")
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
            .sheet(item: $brandingBase) { exercise in
                AddBrandVariantView(base: exercise) { created in
                    onPick(created)
                    dismiss()
                }
            }
        }
    }

    /// One library row — shared by the "Similar to …" section and the grouped library.
    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            onPick(exercise)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.displayLabel)
                        .foregroundStyle(.primary)
                    EquipmentBadge(type: exercise.equipmentType)
                }
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
        // Brand the machine you're looking at without leaving the picker — the moment
        // you notice your gym's leg press isn't the one you've been logging.
        .swipeActions(edge: .trailing) {
            if exercise.canBeBranded {
                Button {
                    brandingBase = exercise
                } label: {
                    Label("Brand", systemImage: "tag")
                }
                .tint(.indigo)
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
