import SwiftUI

// Claude  Date 06/10/2026
// Navigation target for the workout editor. `isNew` distinguishes logging a
// brand-new workout ("Finish Workout") from editing an existing one ("Finish Edit").
struct WorkoutRoute: Hashable {
    let id: UUID
    let isNew: Bool
}

/// Lists past workouts (newest first). Tap a row to open the editor; the +
/// button creates a new workout and navigates straight into it.
struct WorkoutsListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var path: [WorkoutRoute] = []

    private var sortedWorkouts: [Workout] {
        store.workouts.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.workouts.isEmpty {
                    Text("No workouts yet. Tap + to log one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedWorkouts) { workout in
                        NavigationLink(value: WorkoutRoute(id: workout.id, isNew: false)) {
                            WorkoutRow(workout: workout)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { sortedWorkouts[$0].id }.forEach(store.deleteWorkout)
                    }
                }
            }
            .navigationTitle("Workouts")
            .themed(theme.current)
            .navigationDestination(for: WorkoutRoute.self) { route in
                WorkoutDetailView(workoutID: route.id, isNew: route.isNew)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            start(Workout())
                        } label: {
                            Label("Empty Workout", systemImage: "square.and.pencil")
                        }

                        if !store.presets.isEmpty {
                            Menu {
                                ForEach(store.presets) { preset in
                                    Button {
                                        start(store.workout(from: preset))
                                    } label: {
                                        Label(preset.name.isEmpty ? "Untitled Preset" : preset.name,
                                              systemImage: preset.symbolName)
                                    }
                                }
                            } label: {
                                Label("From Preset", systemImage: "square.stack")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    /// Adds a new workout to the store and navigates into its editor (as new).
    private func start(_ workout: Workout) {
        store.addWorkout(workout)
        path.append(WorkoutRoute(id: workout.id, isNew: true))
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(workout.date, format: .dateTime.weekday().month().day())
                .font(.headline)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        let exerciseCount = workout.exercises.count
        let setCount = workout.totalSets
        let exercisePart = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
        let setPart = "\(setCount) set\(setCount == 1 ? "" : "s")"
        return "\(exercisePart) • \(setPart)"
    }
}

#Preview {
    WorkoutsListView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
