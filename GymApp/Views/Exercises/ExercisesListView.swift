import SwiftUI

/// Browse and manage the exercise library. Add via the + button, swipe to delete.
// Claude  Date 06/16/2026 last changed: 06/16/2026 by: Claude
// No longer a tab root — it's pushed from the Build (Presets) screen's top-left
// link, so it relies on the host NavigationStack instead of owning one.
struct ExercisesListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var showingAdd = false

    var body: some View {
        // Claude  Date 06/14/2026
        // Grouped by body region (primary) → muscle sub-group (secondary): each
        // region is a section, its rows clustered by sub-group. Swipe-delete maps
        // the section-relative offset back to the specific exercise.
        List {
            ForEach(store.exercisesByRegion(), id: \.region) { group in
                Section(group.region.title) {
                    ForEach(group.exercises) { exercise in
                        ExerciseRow(exercise: exercise, accent: theme.current.accent)
                    }
                    .onDelete { offsets in
                        offsets.map { group.exercises[$0] }.forEach(store.deleteExercise)
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
    }
}

// Claude  Date 06/09/2026 last changed: 07/09/2026 by: Claude
// One exercise row: name, muscle subtitle (sub-group · primary mover), and a small
// "Unilateral" badge when set.
private struct ExerciseRow: View {
    let exercise: Exercise
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
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
