import SwiftUI

/// Resolves a workout by id into a stable binding, then hands it to the editor.
/// If the workout was deleted, shows a fallback message.
struct WorkoutDetailView: View {
    @EnvironmentObject private var store: AppStore
    let workoutID: UUID
    // Claude  Date 06/10/2026
    // True when this was a freshly created workout (vs editing an existing one),
    // which changes the bottom button to "Finish Workout" vs "Finish Edit".
    var isNew: Bool = false

    var body: some View {
        if let binding = store.binding(for: workoutID) {
            WorkoutEditor(workout: binding, isNew: isNew)
        } else {
            Text("This workout no longer exists.")
                .foregroundStyle(.secondary)
        }
    }
}

/// Edits a single workout: its date, the exercises performed, the sets logged
/// for each, and freeform notes. All edits flow through the binding and are
/// persisted automatically by `AppStore`.
private struct WorkoutEditor: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: Workout
    let isNew: Bool
    @State private var showingExercisePicker = false
    @State private var showingReorder = false
    @State private var showingSaveAsPreset = false
    @State private var presetName = ""
    @State private var savedPresetConfirmation = false

    var body: some View {
        Form {
            Section("Date") {
                DatePicker("Date", selection: $workout.date,
                           displayedComponents: [.date, .hourAndMinute])
            }

            ForEach($workout.exercises) { $logged in
                Section {
                    ExerciseLogSection(logged: $logged, accent: theme.current.accent) {
                        workout.exercises.removeAll { $0.id == logged.id }
                    }
                } header: {
                    HStack {
                        Text(store.exercise(for: logged.exerciseId)?.name ?? "Exercise")
                        if let range = logged.targetRepRange {
                            Spacer()
                            Text("\(range.display) reps")
                                .foregroundStyle(theme.current.accent)
                        }
                    }
                }
            }

            Section {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }

            Section("Notes") {
                TextField("Notes", text: $workout.notes, axis: .vertical)
                    .lineLimit(1...5)
            }

            // Claude  Date 06/09/2026
            // Conclude the workout and return to the list. The workout is already
            // saved automatically, so this is just navigation — it can be reopened
            // and edited later from the Workouts tab.
            Section {
                Button {
                    hideKeyboard()
                    dismiss()
                } label: {
                    Text(isNew ? "Finish Workout" : "Finish Edit")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(workout.date.formatted(.dateTime.month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .selectAllWhenEditingNumberFields()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if workout.exercises.count > 1 {
                        Button {
                            showingReorder = true
                        } label: {
                            Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                        }
                    }
                    if !workout.exercises.isEmpty {
                        Button {
                            presetName = ""
                            showingSaveAsPreset = true
                        } label: {
                            Label("Save as Preset", systemImage: "square.stack.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(workout.exercises.isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { exercise in
                workout.exercises.append(LoggedExercise(exerciseId: exercise.id))
            }
        }
        .sheet(isPresented: $showingReorder) {
            ReorderExercisesSheet(title: "Reorder", items: $workout.exercises) {
                store.exercise(for: $0.exerciseId)?.name ?? "Exercise"
            }
        }
        .alert("Save as Preset", isPresented: $showingSaveAsPreset) {
            TextField("Preset name", text: $presetName)
            Button("Save") {
                let name = presetName.trimmingCharacters(in: .whitespaces)
                store.addPreset(store.makePreset(from: workout, name: name.isEmpty ? "New Preset" : name))
                savedPresetConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save these exercises and rep ranges as a reusable preset.")
        }
        .alert("Saved to Presets", isPresented: $savedPresetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Find it on the Presets tab to set an icon or tweak it.")
        }
    }
}

/// The rows for one exercise within a workout: each set, an "add set" button,
/// and a "remove exercise" button.
private struct ExerciseLogSection: View {
    @Binding var logged: LoggedExercise
    let accent: Color
    let onRemove: () -> Void

    var body: some View {
        RepRangeRow(targetRepRange: $logged.targetRepRange)

        TextField("Note (form cues…)",
                  text: Binding($logged.note, replacingNilWith: ""),
                  axis: .vertical)
            .lineLimit(1...4)

        // Claude  Date 06/12/2026
        // Live rest timer, shown only when this exercise carries a rest duration
        // (i.e. it came from a preset). Ad-hoc exercises have no timer for now.
        if let rest = logged.restSeconds {
            RestTimerView(duration: rest, accent: accent)
        }

        ForEach(logged.sets.indices, id: \.self) { index in
            SetRow(number: index + 1, set: $logged.sets[index], targetRange: logged.targetRepRange)
        }
        .onDelete { logged.sets.remove(atOffsets: $0) }

        Button {
            addSet()
        } label: {
            Label("Add Set", systemImage: "plus.circle")
        }

        Button(role: .destructive) {
            onRemove()
        } label: {
            Label("Remove Exercise", systemImage: "trash")
        }
    }

    /// Adds a set, defaulting to the previous set's reps/weight (or the low end
    /// of the target rep range) for fast entry.
    private func addSet() {
        let last = logged.sets.last
        let defaultReps = last?.reps
            ?? logged.targetRepRange.map { Swift.min($0.min, $0.max) }
            ?? 8
        logged.sets.append(ExerciseSet(reps: defaultReps, weight: last?.weight ?? 0))
    }
}

/// A single editable set: "Set N — [reps] reps × [weight] lb".
/// When the exercise has a target rep range, a colored mark and reps color show
/// whether this set landed in range (green) or not (red).
private struct SetRow: View {
    let number: Int
    @Binding var set: ExerciseSet
    let targetRange: RepRange?

    var body: some View {
        HStack {
            Circle()
                .fill(markColor ?? .clear)
                .frame(width: 8, height: 8)

            Text("Set \(number)")
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            TextField("Reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .foregroundStyle(markColor ?? .primary)
                .frame(width: 48)
            Text("reps")
                .foregroundStyle(.secondary)

            Spacer()

            TextField("Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            Text("lb")
                .foregroundStyle(.secondary)
        }
    }

    // Claude  Date 06/09/2026
    // Green when reps land in the target range, yellow when ABOVE it (going over
    // isn't a bad thing), red only when BELOW it. Nil = no target range, no mark.
    private var markColor: Color? {
        guard let range = targetRange else { return nil }
        let low = Swift.min(range.min, range.max)
        let high = Swift.max(range.min, range.max)
        if set.reps < low { return .red }
        if set.reps > high { return .yellow }
        return .green
    }
}

#if canImport(UIKit)
extension View {
    /// Dismisses the keyboard by resigning the first responder app-wide.
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}
#endif

#Preview {
    let store = AppStore()
    let workout = Workout(exercises: [
        LoggedExercise(exerciseId: store.exercises[0].id,
                       sets: [ExerciseSet(reps: 8, weight: 135), ExerciseSet(reps: 6, weight: 155)])
    ])
    store.addWorkout(workout)
    return NavigationStack {
        WorkoutDetailView(workoutID: workout.id)
            .environmentObject(store)
            .environmentObject(ThemeManager())
    }
}
