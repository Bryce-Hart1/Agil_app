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
    @EnvironmentObject private var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: Workout
    let isNew: Bool
    @State private var showingExercisePicker = false
    // Claude  Date 06/18/2026
    // The library exercise being edited from a section's pencil (nil = none).
    @State private var editingExercise: Exercise?
    @State private var showingReorder = false
    @State private var showingSaveAsPreset = false
    @State private var presetName = ""
    @State private var savedPresetConfirmation = false

    var body: some View {
        Form {
            Section("Date") {
                // Claude  Date 06/14/2026
                // Cap the date at "now" so a workout can't be logged in the future
                // (you can't have trained a session that hasn't happened yet). The
                // open-ended `...Date()` range disables future days/times in the
                // picker; existing dates in the past stay freely editable.
                DatePicker("Date", selection: $workout.date, in: ...Date(),
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
                        // Claude  Date 06/18/2026
                        // Pencil → edit the underlying library exercise's details in place.
                        if let exercise = store.exercise(for: logged.exerciseId) {
                            Button {
                                editingExercise = exercise
                            } label: {
                                // Claude  Date 06/18/2026 — heavier stroke so the edit
                                // affordance reads clearly in the section header.
                                Image(systemName: "pencil")
                                    .fontWeight(.bold)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.current.accent)
                            .accessibilityLabel("Edit \(exercise.name)")
                        }
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

            // Claude  Date 06/09/2026 last changed: 06/16/2026 by: Claude
            // For an in-progress workout this is "Complete Workout" — it marks the
            // session finished (AppStore.finishWorkout), which logs its checked-off
            // sets and awards badges. For an already-finished workout being edited it's
            // just "Finish Edit" (navigation only; edits don't change earned credit).
            Section {
                Button {
                    hideKeyboard()
                    if !workout.isFinished { store.finishWorkout(id: workout.id) }
                    dismiss()
                } label: {
                    Text(workout.isFinished ? "Finish Edit" : "Complete Workout")
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
        // Claude  Date 06/16/2026
        // While this editor is on screen, tell the session so the global mini-bar
        // hides itself for this workout (clearing only our own id on the way out).
        .onAppear { session.viewingWorkoutID = workout.id }
        .onDisappear { if session.viewingWorkoutID == workout.id { session.viewingWorkoutID = nil } }
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
                // Claude  Date 06/18/2026
                // Requeue with a rep range already set — the exercise's history-preferred
                // range (most-used of its last 3), or the 8–12 default. So a lift never
                // lands in the workout without a target.
                workout.exercises.append(
                    LoggedExercise(exerciseId: exercise.id,
                                   targetRepRange: store.defaultRepRange(for: exercise.id)))
            }
        }
        // Claude  Date 06/18/2026
        // Edit the tapped exercise's library details (name, region, mover, …). Saving
        // updates the shared library, so this and any other workout using it relabel.
        .sheet(item: $editingExercise) { exercise in
            NewExerciseView(editing: exercise)
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
    @EnvironmentObject private var store: AppStore
    @Binding var logged: LoggedExercise
    let accent: Color
    let onRemove: () -> Void

    var body: some View {
        RepRangeRow(targetRepRange: $logged.targetRepRange)

        TextField("Note (form cues…)",
                  text: Binding($logged.note, replacingNilWith: ""),
                  axis: .vertical)
            .lineLimit(1...4)

        // Claude  Date 06/12/2026 last changed: 06/16/2026 by: Claude
        // Optional rest timer for ANY exercise — preset items arrive with a duration,
        // but ad-hoc exercises in a non-preset workout can now opt in here too (mirrors
        // the preset editor's picker). Pick a duration and the live countdown appears.
        Picker(selection: $logged.restSeconds) {
            Text("None").tag(Int?.none)
            ForEach(RestDuration.options, id: \.self) { seconds in
                Text(RestDuration.label(seconds)).tag(Int?.some(seconds))
            }
        } label: {
            Label("Rest timer", systemImage: "timer")
        }

        // Live countdown (drives the shared session timer + mini-bar), once set.
        if let rest = logged.restSeconds {
            RestTimerView(duration: rest, accent: accent)
        }

        ForEach(logged.sets.indices, id: \.self) { index in
            SetRow(number: setNumber(at: index),
                   sideLabel: logged.sets[index].side?.title,
                   lagsBehind: lagsBehind(at: index),
                   set: $logged.sets[index],
                   targetRange: logged.targetRepRange, accent: accent)
        }
        .onDelete { deleteSets(at: $0) }

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

    // Claude  Date 06/14/2026
    // Whether the underlying exercise is single-side. Unilateral exercises log each
    // set as a Left/Right pair so both sides are tracked and mismatches surfaced.
    private var isUnilateral: Bool {
        store.exercise(for: logged.exerciseId)?.isUnilateral ?? false
    }

    /// Adds a set, defaulting to the previous set's reps/weight (or the low end of
    /// the target rep range) for fast entry. Unilateral exercises add a matched
    /// Left+Right pair so each logical set covers both sides.
    private func addSet() {
        let last = logged.sets.last
        let defaultReps = last?.reps
            ?? logged.targetRepRange.map { Swift.min($0.min, $0.max) }
            ?? 8
        let defaultWeight = last?.weight ?? 0
        if isUnilateral {
            logged.sets.append(ExerciseSet(reps: defaultReps, weight: defaultWeight, side: .left))
            logged.sets.append(ExerciseSet(reps: defaultReps, weight: defaultWeight, side: .right))
        } else {
            logged.sets.append(ExerciseSet(reps: defaultReps, weight: defaultWeight))
        }
    }

    // Claude  Date 06/14/2026
    // Swipe-delete: for unilateral exercises, removing one side also removes its
    // pair partner so a set never ends up half-deleted. (The activity ledger is
    // append-only, so any already-earned credit for those sides is kept.)
    private func deleteSets(at offsets: IndexSet) {
        guard isUnilateral else {
            logged.sets.remove(atOffsets: offsets)
            return
        }
        var toRemove = Set(offsets)
        for index in offsets {
            if let partner = partnerIndex(of: index) { toRemove.insert(partner) }
        }
        logged.sets.remove(atOffsets: IndexSet(toRemove))
    }

    // Claude  Date 06/14/2026
    // Displayed set number: for unilateral exercises each Left/Right pair shares one
    // number (index 0,1 → Set 1; 2,3 → Set 2); otherwise it's just the position.
    private func setNumber(at index: Int) -> Int {
        isUnilateral ? index / 2 + 1 : index + 1
    }

    // Claude  Date 06/14/2026
    // The paired (other-side) index for a unilateral set — adjacent by parity —
    // but only when it genuinely exists and is the opposite side.
    private func partnerIndex(of index: Int) -> Int? {
        guard isUnilateral else { return nil }
        let partner = index % 2 == 0 ? index + 1 : index - 1
        guard logged.sets.indices.contains(partner),
              let mine = logged.sets[index].side,
              let theirs = logged.sets[partner].side,
              mine != theirs else { return nil }
        return partner
    }

    // Claude  Date 06/14/2026
    // True when this side is the one to push to even out the pair: it's strictly
    // lower on at least one metric (weight or reps) than its partner. A matched pair
    // flags neither; a "mixed" pair (each side ahead on a different metric) flags
    // both, nudging the user to match reps AND weight.
    private func lagsBehind(at index: Int) -> Bool {
        guard let partner = partnerIndex(of: index) else { return false }
        let mine = logged.sets[index]
        let theirs = logged.sets[partner]
        guard mine.reps != theirs.reps || mine.weight != theirs.weight else { return false }
        return mine.weight < theirs.weight || mine.reps < theirs.reps
    }

}

/// A single editable set: "Set N — [reps] reps × [weight] lb".
/// When the exercise has a target rep range, a colored mark and reps color show
/// whether this set landed in range (green) or not (red).
private struct SetRow: View {
    let number: Int
    // Claude  Date 06/14/2026
    // "Left"/"Right" for unilateral sets (nil for normal two-sided sets); `lagsBehind`
    // is true when this side trails its pair and should be flagged to even it out.
    var sideLabel: String? = nil
    var lagsBehind: Bool = false
    @Binding var set: ExerciseSet
    let targetRange: RepRange?
    let accent: Color

    // Claude  Date 06/14/2026
    // `self.` is required: leading `set` in an accessor body is read as the setter
    // keyword (the binding is named `set`).
    private var isCompleted: Bool { self.set.completedAt != nil }

    var body: some View {
        HStack {
            // Claude  Date 06/14/2026 last changed: 06/18/2026 by: Claude
            // Explicit "complete set" tap — the only thing that earns achievement
            // credit. Filled checkmark once done; tapping again un-completes it. (The
            // reps/weight fields stay editable either way, so a typo no longer needs an
            // un-check to fix.)
            Button(action: toggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? accent : .secondary)
            }
            .buttonStyle(.plain)

            Circle()
                .fill(markColor ?? .clear)
                .frame(width: 8, height: 8)

            // Claude  Date 06/14/2026
            // Set number, with the Left/Right side beneath it for unilateral sets.
            // The side label turns red when this side lags its pair.
            VStack(alignment: .leading, spacing: 1) {
                Text("Set \(number)")
                    .foregroundStyle(.secondary)
                if let sideLabel {
                    Text(sideLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(lagsBehind ? .red : .secondary)
                }
            }
            .frame(width: 54, alignment: .leading)

            // Claude  Date 06/18/2026
            // Reps/weight stay editable even after the set is checked off, so a mistyped
            // value can be corrected in place (you no longer have to un-check first).
            // Credit is read from the current values when the workout is completed, so a
            // pre-finish correction is reflected; edits to an already-finished workout
            // don't change earned credit (the ledger is append-only).
            TextField("Reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .foregroundStyle(lagsBehind ? .red : (markColor ?? .primary))
                .frame(width: 48)
            Text("reps")
                .foregroundStyle(.secondary)

            Spacer()

            TextField("Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(lagsBehind ? .red : .primary)
                .frame(width: 64)
            Text("lb")
                .foregroundStyle(.secondary)
        }
        .opacity(isCompleted ? 0.6 : 1)
    }

    // Claude  Date 06/14/2026 last changed: 06/18/2026 by: Claude
    // Toggle completion. This only stamps/clears the set's real check-off time — no
    // ledger write happens here. Credit is granted in one batch when the workout is
    // marked complete (AppStore.finishWorkout), so an unfinished workout never counts.
    // The reps/weight fields are always editable, so a completed set can still be fixed.
    private func toggleComplete() {
        set.completedAt = isCompleted ? nil : Date()
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
            .environmentObject(WorkoutSession())
    }
}
