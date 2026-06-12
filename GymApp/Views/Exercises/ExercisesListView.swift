import SwiftUI

/// Browse and manage the exercise library. Add via the + button, swipe to delete.
struct ExercisesListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.exercises) { exercise in
                    ExerciseRow(exercise: exercise, accent: theme.current.accent)
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
            .sheet(isPresented: $showingAdd) {
                NewExerciseView()
            }
        }
    }
}

// Claude  Date 06/09/2026
// One exercise row: name, category, and a small "Unilateral" badge when set.
private struct ExerciseRow: View {
    let exercise: Exercise
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
            HStack(spacing: 6) {
                Text(exercise.category)
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
    ExercisesListView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
