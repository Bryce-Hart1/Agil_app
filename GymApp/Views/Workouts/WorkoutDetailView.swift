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

        // Claude  Date 06/12/2026
        // Live rest timer, shown only when this exercise carries a rest duration
        // (i.e. it came from a preset). Ad-hoc exercises have no timer for now.
        if let rest = logged.restSeconds {
            RestTimerView(duration: rest, accent: accent)
        }

        ForEach(logged.sets.indices, id: \.self) { index in
            SetRow(number: setNumber(at: index),
                   sideLabel: logged.sets[index].side?.title,
                   lagsBehind: lagsBehind(at: index),
                   set: $logged.sets[index],
                   targetRange: logged.targetRepRange, accent: accent,
                   onComplete: { completeSet(at: index) })
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

    // Claude  Date 06/14/2026
    // Log the completed set to the activity ledger using its real values. The
    // SetRow has already stamped `completedAt`; the store dedupes by set id.
    private func completeSet(at index: Int) {
        let set = logged.sets[index]
        store.completeSet(setId: set.id, exerciseId: logged.exerciseId,
                          reps: set.reps, weight: set.weight)
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
    // Called after this set is marked complete so the parent can log it to the
    // activity ledger. Completion is one-way: a completed set locks its fields
    // (the ledger captured these values) and can only be removed via swipe-delete.
    let onComplete: () -> Void

    // Claude  Date 06/14/2026
    // `self.` is required: leading `set` in an accessor body is read as the setter
    // keyword (the binding is named `set`).
    private var isCompleted: Bool { self.set.completedAt != nil }

    var body: some View {
        HStack {
            // Claude  Date 06/14/2026
            // Explicit "complete set" tap — the only thing that earns achievement
            // credit. Filled checkmark once done; tapping an incomplete set stamps
            // it and logs the ledger event.
            Button(action: complete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? accent : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(isCompleted)

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

            TextField("Reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .foregroundStyle(lagsBehind ? .red : (markColor ?? .primary))
                .frame(width: 48)
                .disabled(isCompleted)
            Text("reps")
                .foregroundStyle(.secondary)

            Spacer()

            TextField("Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(lagsBehind ? .red : .primary)
                .frame(width: 64)
                .disabled(isCompleted)
            Text("lb")
                .foregroundStyle(.secondary)
        }
        .opacity(isCompleted ? 0.6 : 1)
    }

    // Claude  Date 06/14/2026
    // Mark the set complete (real wall-clock time) and hand off to the parent to
    // record the ledger event. Guarded so it only ever fires once per set.
    private func complete() {
        guard !isCompleted else { return }
        set.completedAt = Date()
        onComplete()
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
