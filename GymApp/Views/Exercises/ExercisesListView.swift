import SwiftUI

/// Browse and manage the exercise library. Add via the + button, swipe to delete.
// Claude  Date 06/16/2026 last changed: 06/16/2026 by: Claude
// No longer a tab root — it's pushed from the Build (Presets) screen's top-left
// link, so it relies on the host NavigationStack instead of owning one.
struct ExercisesListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var showingAdd = false
    // Claude  Date 07/13/2026
    // The library exercise being edited via a row's swipe action (nil = none). Drives
    // the same NewExerciseView editor the workout/preset pencils use.
    @State private var editingExercise: Exercise?
    // Claude  Date 08/18/2026
    // The lift being branded via the row's context menu (nil = none) — drives the
    // Add Brand sheet, which adds a separate branded copy rather than editing this one.
    @State private var brandingBase: Exercise?

    var body: some View {
        // Claude  Date 06/14/2026 last changed: 07/13/2026 by: Claude
        // Grouped by body region (primary) → muscle sub-group (secondary): each
        // region is a section, its rows clustered by sub-group. Swipe left on a row to
        // Edit or Delete (Delete stays the full-swipe action).
        List {
            ForEach(store.exercisesByRegion(), id: \.region) { group in
                Section(group.region.title) {
                    ForEach(group.exercises) { exercise in
                        ExerciseRow(exercise: exercise, accent: theme.current.accent)
                            // Claude  Date 08/18/2026
                            // Branding lives in the context menu, not a third swipe button:
                            // the trailing rack is already at Delete + Edit, and a third
                            // action shrinks all three past comfortable tapping. Hidden for
                            // free weights and bodyweight movements, where the manufacturer
                            // doesn't change how the lift behaves.
                            .contextMenu {
                                if exercise.canBeBranded {
                                    Button {
                                        brandingBase = exercise
                                    } label: {
                                        Label("Add Brand…", systemImage: "tag")
                                    }
                                }
                                Button {
                                    editingExercise = exercise
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.deleteExercise(exercise)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingExercise = exercise
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(theme.current.accent)
                            }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NewExerciseView()
        }
        // Claude  Date 07/13/2026
        // Edit the swiped exercise in place. Saving updates the shared library (or, via
        // "Save as New Lift", adds a separate copy), so every workout/preset relabels.
        .sheet(item: $editingExercise) { exercise in
            NewExerciseView(editing: exercise)
        }
        // Claude  Date 08/18/2026
        // Nothing to navigate to afterwards: the new branded lift lands in this same
        // list, directly under the generic (exercisesByRegion sorts on brand last).
        .sheet(item: $brandingBase) { exercise in
            AddBrandVariantView(base: exercise)
        }
    }
}

// Claude  Date 06/09/2026 last changed: 08/18/2026 by: Claude
// One exercise row: name (+ brand) with its equipment nameplate, muscle subtitle
// (sub-group · primary mover), and a small "Unilateral" badge when set.
private struct ExerciseRow: View {
    let exercise: Exercise
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Claude  Date 08/18/2026
            // displayLabel + the equipment nameplate. Branded versions of one lift sit
            // together in this list, so the brand is what tells them apart. The
            // "Unilateral" capsule stays on the subtitle line below so the two don't
            // read as one run-on tag row.
            HStack(spacing: 6) {
                Text(exercise.displayLabel)
                EquipmentBadge(type: exercise.equipmentType)
            }
            HStack(spacing: 6) {
                Text(exercise.muscleSubtitle)
                if exercise.isUnilateral {
                    Text("Unilateral")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.18), in: Capsule())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { ExercisesListView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
