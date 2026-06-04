import Foundation
import SwiftUI

/// The app's single source of truth. Views observe this; it owns the in-memory
/// data and persists every change to JSON via `PersistenceService`.
///
/// Persistence happens automatically: the `didSet` observers save whenever the
/// arrays change (including edits to nested sets/reps via bindings), so feature
/// code never has to remember to call save.
@MainActor
final class AppStore: ObservableObject {
    @Published var exercises: [Exercise] { didSet { persistence.save(exercises, to: Self.exercisesFile) } }
    @Published var workouts: [Workout] { didSet { persistence.save(workouts, to: Self.workoutsFile) } }

    private let persistence: PersistenceService

    private static let exercisesFile = "exercises.json"
    private static let workoutsFile = "workouts.json"

    init(persistence: PersistenceService = PersistenceService()) {
        self.persistence = persistence

        // Note: assignments in init do NOT trigger the didSet observers above,
        // so we save the seed explicitly below on first launch.
        let loadedExercises = persistence.load(Self.exercisesFile, default: [Exercise]())
        self.exercises = loadedExercises.isEmpty ? AppStore.seedExercises : loadedExercises
        self.workouts = persistence.load(Self.workoutsFile, default: [Workout]())

        if loadedExercises.isEmpty {
            persistence.save(self.exercises, to: Self.exercisesFile)
        }
    }

    // MARK: - Exercises

    func addExercise(name: String, category: String) {
        exercises.append(Exercise(name: name, category: category))
    }

    func deleteExercises(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }

    func exercise(for id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }

    // MARK: - Workouts

    func addWorkout(_ workout: Workout) {
        workouts.append(workout)
    }

    func deleteWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
    }

    /// A two-way binding to a workout identified by `id`, resilient to the array
    /// being reordered. Editing through this binding mutates the `workouts`
    /// array, which triggers `didSet` and persists the change.
    func binding(for id: UUID) -> Binding<Workout>? {
        guard workouts.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.workouts.first(where: { $0.id == id }) ?? Workout() },
            set: { newValue in
                if let index = self.workouts.firstIndex(where: { $0.id == id }) {
                    self.workouts[index] = newValue
                }
            }
        )
    }
}

// MARK: - Seed data

extension AppStore {
    /// Common lifts pre-loaded on first launch so the app isn't empty.
    static let seedExercises: [Exercise] = [
        Exercise(name: "Barbell Bench Press", category: "Chest"),
        Exercise(name: "Incline Dumbbell Press", category: "Chest"),
        Exercise(name: "Back Squat", category: "Legs"),
        Exercise(name: "Deadlift", category: "Back"),
        Exercise(name: "Overhead Press", category: "Shoulders"),
        Exercise(name: "Barbell Row", category: "Back"),
        Exercise(name: "Pull-Up", category: "Back"),
        Exercise(name: "Romanian Deadlift", category: "Legs"),
        Exercise(name: "Bicep Curl", category: "Arms"),
        Exercise(name: "Tricep Pushdown", category: "Arms"),
    ]
}
