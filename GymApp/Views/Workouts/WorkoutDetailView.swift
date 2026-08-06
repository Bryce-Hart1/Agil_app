import SwiftUI

/// Resolves a workout by id into a stable binding, then hands it to the editor.
/// If the workout was deleted, shows a fallback message.
struct WorkoutDetailView: View {
    @EnvironmentObject private var store: AppStore
    let workoutID: UUID
    // Claude  Date 06/10/2026 last changed: 08/04/2026 by: Claude
    // (08/04) `isNew` was documented as switching the bottom button between
    // "Finish Workout" and "Finish Edit", but the editor never read it — that
    // button has always keyed off workout.isFinished. Accepted and ignored here so
    // the call site keeps compiling; nothing downstream uses it.
    var isNew: Bool = false

    var body: some View {
        if let binding = store.binding(for: workoutID) {
            WorkoutEditor(workout: binding)
        } else {
            Text("This workout no longer exists.")
                .foregroundStyle(.secondary)
        }
    }
}

/// Edits a single workout: its date, the exercises performed, the sets logged
/// for each, and freeform notes. All edits flow through the binding and are
/// persisted automatically by `AppStore`.
// Claude  Date 08/04/2026
// (08/04) The top of the screen was a `Section("Date")` holding a DatePicker and a
// `Section("Notes")` at the very bottom. Both were form rows for things that
// wanted to be page furniture: the date is almost never edited (you log the
// workout you're doing), and the notes were written but displayed nowhere. They're
// now a header — date and time set in the theme's face, tap to unfold the picker —
// with the notes directly beneath it as read-then-tap-to-edit text.
private struct WorkoutEditor: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: Workout
    // Claude  Date 08/04/2026
    // Header state: whether the date picker is unfolded, and whether the notes row
    // is in its editing shape. `notesFocused` drives the collapse — losing focus
    // (Done, tapping away, the toolbar's global dismiss) puts notes back to display.
    @State private var showingDatePicker = false
    @State private var isEditingNotes = false
    @FocusState private var notesFocused: Bool
    @State private var showingExercisePicker = false
    // Claude  Date 06/18/2026
    // The library exercise being edited from a section's pencil (nil = none).
    @State private var editingExercise: Exercise?
    @State private var showingReorder = false
    @State private var showingSaveAsPreset = false
    @State private var presetName = ""
    @State private var savedPresetConfirmation = false
    // Claude  Date 07/13/2026
    // Drive the confirm + success alerts for "Override Preset" — pushing this workout's
    // current exercises, rep ranges, and set counts back onto its source preset.
    @State private var showingOverrideConfirm = false
    @State private var overridePresetConfirmation = false
    // Claude  Date 07/21/2026
    // Which set's reps/weight field the keyboard is on (nil = focus is elsewhere, or
    // nowhere). Threaded down to each SetRow so the keyboard accessory bar knows which
    // value its steppers should move. Other fields on this screen — the workout note,
    // an exercise's form cue, the rep-range fields — deliberately aren't tracked here;
    // they get the plain Done, which is all they ever had.
    @FocusState private var focusedField: SetEntryField?

    // Claude  Date 07/13/2026
    // The preset this workout was started from, if it still exists (nil for empty/ad-hoc
    // workouts, or if the preset was since deleted). Gates the "Override Preset" affordance.
    private var sourcePreset: WorkoutPreset? {
        workout.presetID.flatMap { store.preset(for: $0) }
    }

    // Claude  Date 07/13/2026
    // Display name for the source preset, with the same "Untitled Preset" fallback the
    // presets list uses for a blank name.
    private var sourcePresetName: String {
        guard let name = sourcePreset?.name else { return "this preset" }
        return name.isEmpty ? "Untitled Preset" : name
    }

    // Claude  Date 08/04/2026
    // Room the nav bar leaves a principal item: the screen less the back button and
    // the ⋯ menu with their margins. Approximate on purpose — the marquee needs a
    // concrete width to decide whether to scroll (a principal item is sized to its
    // intrinsic content, so there's no proxy to ask), and being a few points off
    // only shifts where a long name starts scrolling.
    private var titleMaxWidth: CGFloat {
        #if canImport(UIKit)
        return max(120, UIScreen.main.bounds.width - 160)
        #else
        return 200
        #endif
    }

    // MARK: - Header

    // Claude  Date 08/04/2026
    // The page's masthead: when this workout happened, and the notes that apply to
    // the whole session. Drawn as a Section with a clear row background and no
    // separators so it reads as page furniture rather than the first two rows of a
    // form — while still scrolling with the content and letting the List animate the
    // date picker's insertion, which a safeAreaInset header wouldn't.
    private var headerSection: some View {
        Section {
            dateHeader
            if showingDatePicker { datePicker }
            notesRow
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // Claude  Date 08/04/2026
    // The date/time line. Set in the THEME's face — a deliberate island in a screen
    // that's otherwise on the system face (see systemTypeface at the bottom of body):
    // a nested fontDesign beats the ambient one, and the contrast is what makes this
    // read as a header rather than a row. A Button, not a tap gesture, so it's
    // reachable and describable to VoiceOver.
    private var dateHeader: some View {
        Button {
            hideKeyboard()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showingDatePicker.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.title3.weight(.semibold))
                    Text(workout.date, format: .dateTime.hour().minute())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showingDatePicker ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fontDesign(theme.current.fontDesign.design)
        .accessibilityLabel("Workout date")
        .accessibilityValue(Text(workout.date, format: .dateTime.weekday(.wide).month().day().hour().minute()))
        .accessibilityHint("Tap to change")
    }

    // Claude  Date 06/14/2026 last changed: 08/04/2026 by: Claude
    // Cap the date at "now" so a workout can't be logged in the future (you can't
    // have trained a session that hasn't happened yet). The open-ended `...Date()`
    // range disables future days/times in the picker; existing dates in the past
    // stay freely editable. (08/04) Unfolded from the header rather than always
    // shown, and graphical rather than a compact row — once it's a deliberate
    // disclosure, it may as well be the pleasant version of the control.
    private var datePicker: some View {
        DatePicker("", selection: $workout.date, in: ...Date(),
                   displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.graphical)
            .labelsHidden()
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // Claude  Date 08/04/2026
    // Workout-level notes, directly under the date. Reads as text until tapped —
    // a permanently-open TextField at the top of the page would look like something
    // demanding to be filled in, and most sessions have nothing to say.
    //
    // Focus is what closes it: losing first responder (Done, tapping elsewhere, the
    // toolbar's dismiss) drops back to display, so there's no separate confirm step.
    @ViewBuilder
    private var notesRow: some View {
        if isEditingNotes {
            TextField("Notes for this workout", text: $workout.notes, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...5)
                .focused($notesFocused)
                // Focusing in the same layout pass the field is inserted doesn't take
                // on iOS 16 — the field has to exist first.
                .onAppear { DispatchQueue.main.async { notesFocused = true } }
                .onChange(of: notesFocused) { focused in
                    if !focused { isEditingNotes = false }
                }
        } else {
            Button {
                isEditingNotes = true
            } label: {
                HStack(spacing: 6) {
                    if workout.notes.isEmpty {
                        Image(systemName: "square.and.pencil")
                            .font(.caption)
                        Text("Add notes…")
                    } else {
                        Text(workout.notes)
                    }
                    Spacer(minLength: 0)
                }
                .font(.subheadline)
                .foregroundStyle(workout.notes.isEmpty ? AnyShapeStyle(.tertiary)
                                                       : AnyShapeStyle(.secondary))
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Workout notes")
            .accessibilityValue(workout.notes.isEmpty ? "None" : workout.notes)
            .accessibilityHint("Tap to edit")
        }
    }

    var body: some View {
        Form {
            headerSection

            ForEach($workout.exercises) { $logged in
                Section {
                    // Claude  Date 07/19/2026 last changed: 08/04/2026 by: Claude
                    // onSwap: point this entry at a different lift, in place. The logged
                    // sets, note and adaptive suggestion all describe the OLD lift, so
                    // they're cleared; the rep range is re-derived from the new lift's
                    // history (same rule the picker uses when adding). Rest timer stays —
                    // it's a property of how you're training, not of the lift.
                    // (08/04) `logged.note` is the SESSION note, which is why it clears.
                    // The perma note needs nothing here: it lives on the Exercise and is
                    // looked up by exerciseId, so it re-resolves to the new lift's own.
                    ExerciseLogSection(logged: $logged, accent: theme.current.accent,
                                       focusedField: $focusedField) { exercise in
                        logged.exerciseId = exercise.id
                        logged.targetRepRange = store.defaultRepRange(for: exercise.id)
                        logged.sets.removeAll()
                        logged.note = nil
                        logged.adaptive = nil
                    } onRemove: {
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

                // Claude  Date 07/13/2026
                // "Override Preset" — when this workout was started from a preset, push its
                // current shape (which exercises are kept/removed, their rep ranges, and set
                // counts) back onto that template. Confirmed first, then stays in the editor
                // so the workout keeps going. Only shown when the source preset still exists.
                if sourcePreset != nil && !workout.exercises.isEmpty {
                    Button {
                        hideKeyboard()
                        showingOverrideConfirm = true
                    } label: {
                        Text("Override Preset")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .listRowBackground(Color.clear)
                }

                // Claude  Date 07/01/2026 last changed: 07/13/2026 by: Claude
                // The same "Save as Preset" the ⋯ menu offers, surfaced down here where
                // it's discoverable while building an in-progress workout. Saves the
                // exercises/rep ranges/set counts as a NEW template; the workout itself
                // stays in progress. (07/13) Stays in the editor and confirms, like the
                // menu action — parallel to "Override Preset" beside it.
                if !workout.isFinished && !workout.exercises.isEmpty {
                    Button {
                        hideKeyboard()
                        presetName = ""
                        showingSaveAsPreset = true
                    } label: {
                        Text("Save as New Preset")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle(workout.date.formatted(.dateTime.month().day()))
        .navigationBarTitleDisplayMode(.inline)
        // Claude  Date 08/04/2026
        // A workout started from a preset is "Push Day", not "Aug 4" — the name the
        // user gave it is the more useful identifier, and the date is now spelled
        // out in the header a few points below anyway. Preset names are free text,
        // so a long one scrolls rather than truncating (see MarqueeText); the date
        // fallback for ad-hoc workouts always fits.
        //
        // navigationTitle above is deliberately kept: the principal view supersedes
        // it visually, but it's still what VoiceOver announces for the screen and
        // what a pushed child shows on its back button.
        //
        // The font is set here rather than inherited. This screen runs on the system
        // face (see systemTypeface below) while the nav bar everywhere else is the
        // theme's — ChromeFontAppearance styles UIKit's own title label, which a
        // custom principal view isn't, so it has to match 17pt semibold by hand.
        //
        // Only a preset name gets the marquee. A date is "Aug 4" — it always fits,
        // and running it through a scroller means one more thing that can go wrong
        // for zero benefit on the commonest case, an ad-hoc workout.
        .toolbar {
            ToolbarItem(placement: .principal) {
                Group {
                    if sourcePreset != nil {
                        MarqueeText(sourcePresetName,
                                    font: .system(size: 17, weight: .semibold),
                                    maxWidth: titleMaxWidth)
                    } else {
                        Text(workout.date.formatted(.dateTime.month().day()))
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                .fontDesign(theme.current.fontDesign.design)
            }
        }
        // Claude  Date 07/21/2026
        // This screen opts out of the theme's typeface and stays on the system face.
        // Its set rows are a fixed-width numeric layout ("Set N" in a 54pt column,
        // then reps/weight fields), and monospaced glyphs are wide enough to wrap the
        // labels out of their columns. Everything else — the exercise headers, the
        // notes, the buttons — follows along so the page reads as one piece rather
        // than a patchwork of two faces. (08/04) The date header is the one exception,
        // and re-applies the theme face locally — see headerSection.
        .systemTypeface()
        .themed(theme.current)
        // Claude  Date 06/16/2026
        // While this editor is on screen, tell the session so the global mini-bar
        // hides itself for this workout (clearing only our own id on the way out).
        .onAppear { session.viewingWorkoutID = workout.id }
        .onDisappear { if session.viewingWorkoutID == workout.id { session.viewingWorkoutID = nil } }
        .selectAllWhenEditingNumberFields()
        .toolbar {
            // Claude  Date 07/13/2026 last changed: 08/04/2026 by: Claude
            // Overflow menu: reorder, and the two preset actions mirrored from the
            // buttons at the bottom of the form for discoverability.
            // (08/04) The whole item is now omitted on an empty workout instead of
            // being rendered disabled. Every entry below needs at least one
            // exercise, so on a workout you've only just started it was a button
            // that looked live, did nothing when tapped, and gave no hint why —
            // and it's the first thing you see, since a new workout IS empty.
            if !workout.exercises.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if workout.exercises.count > 1 {
                            Button {
                                showingReorder = true
                            } label: {
                                Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                            }
                        }
                        if sourcePreset != nil {
                            Button {
                                showingOverrideConfirm = true
                            } label: {
                                Label("Override Preset", systemImage: "square.stack.3d.up")
                            }
                        }
                        Button {
                            presetName = ""
                            showingSaveAsPreset = true
                        } label: {
                            Label("Save as New Preset", systemImage: "square.stack.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            // Claude  Date 07/21/2026
            // The bar that rides on top of the keyboard: Done, plus quick steppers for
            // whichever set field is focused (see SetEntryAccessoryBar).
            ToolbarItemGroup(placement: .keyboard) {
                SetEntryAccessoryBar(
                    field: focusedField,
                    accent: theme.current.accent,
                    onAdjust: { adjustFocusedField(by: $0) },
                    onDone: dismissKeyboardBar)
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
        .alert("Save as New Preset", isPresented: $showingSaveAsPreset) {
            TextField("Preset name", text: $presetName)
            Button("Save") {
                let name = presetName.trimmingCharacters(in: .whitespaces)
                let preset = store.makePreset(from: workout, name: name.isEmpty ? "New Preset" : name)
                store.addPreset(preset)
                // Claude  Date 07/13/2026
                // Link the workout to the preset it just spawned, so "Override Preset"
                // now targets it for any further tweaks this session.
                workout.presetID = preset.id
                savedPresetConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save these exercises, rep ranges, and set counts as a reusable preset.")
        }
        .alert("Saved to Presets", isPresented: $savedPresetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Find it on the Presets tab to set an icon or tweak it.")
        }
        // Claude  Date 07/13/2026
        // Confirm before overwriting the source preset — it's an in-place change to a
        // saved template. Applying stays in the editor and shows a brief success alert.
        .alert("Override Preset", isPresented: $showingOverrideConfirm) {
            Button("Override", role: .destructive) {
                if let preset = sourcePreset {
                    store.updatePreset(id: preset.id, from: workout)
                    overridePresetConfirmation = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Update “\(sourcePresetName)” to match this workout. Its exercises, rep ranges, set counts, and notes. This can’t be undone.")
        }
        .alert("Preset Updated", isPresented: $overridePresetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("“\(sourcePresetName)” now matches this workout.")
        }
    }

    // Claude  Date 07/21/2026
    // Done resigns the first responder app-wide rather than only clearing @FocusState:
    // the note and rep-range fields on this screen aren't tracked by `focusedField`, so
    // clearing it alone would leave their keyboards up.
    private func dismissKeyboardBar() {
        focusedField = nil
        hideKeyboard()
    }

    // Claude  Date 07/21/2026
    // Move the focused set field by `delta` (the keyboard bar's steppers). Writes through
    // the same `$workout` binding typing does, so AppStore persists it identically — and
    // as with typing, adjusting an already-checked-off set is allowed and changes no
    // earned credit (the ledger is written once, at finish).
    //
    // Weight is rounded to 2 places so repeated ±2.5 taps can't accumulate binary-float
    // dust into "137.50000000000003", and both fields clamp at 0 — negative reps or a
    // negative load are meaningless.
    private func adjustFocusedField(by delta: Double) {
        guard let field = focusedField else { return }
        for exerciseIndex in workout.exercises.indices {
            guard let setIndex = workout.exercises[exerciseIndex].sets
                .firstIndex(where: { $0.id == field.setID }) else { continue }

            switch field {
            case .reps:
                let updated = workout.exercises[exerciseIndex].sets[setIndex].reps + Int(delta)
                workout.exercises[exerciseIndex].sets[setIndex].reps = max(0, updated)
            case .weight:
                let updated = workout.exercises[exerciseIndex].sets[setIndex].weight + delta
                workout.exercises[exerciseIndex].sets[setIndex].weight =
                    max(0, (updated * 100).rounded() / 100)
            }
            return
        }
    }
}

/// The rows for one exercise within a workout: each set, an "add set" button,
/// and a "remove exercise" button.
private struct ExerciseLogSection: View {
    @EnvironmentObject private var store: AppStore
    // Claude  Date 07/16/2026
    // For retintOnThemeChange below — the menu picker needs the active theme's
    // identity, not just the resolved accent Color passed in by the parent.
    @EnvironmentObject private var theme: ThemeManager
    @Binding var logged: LoggedExercise
    let accent: Color
    // Claude  Date 07/21/2026
    // The editor's set-field focus, passed straight through to each SetRow so the
    // keyboard accessory bar knows which value it's stepping.
    @FocusState.Binding var focusedField: SetEntryField?
    let onSwap: (Exercise) -> Void
    let onRemove: () -> Void

    // Claude  Date 07/19/2026
    // Drives the exercise picker opened by the row's "Swap" button.
    @State private var showingSwapPicker = false

    var body: some View {
        RepRangeRow(targetRepRange: $logged.targetRepRange)

        // Claude  Date 08/04/2026
        // Two note tiers, replacing the single "Note (form cues…)" field: the perma
        // note on the lift itself and the session note on this logged entry. See
        // ExerciseNoteFields — shared with the preset editor so both read the same.
        ExerciseNoteFields(exerciseId: logged.exerciseId,
                           sessionNote: $logged.note,
                           accent: accent)

        // Claude  Date 06/12/2026 last changed: 07/16/2026 by: Claude
        // Optional rest timer for ANY exercise — preset items arrive with a duration,
        // but ad-hoc exercises in a non-preset workout can now opt in here too (mirrors
        // the preset editor's picker). Pick a duration and the live countdown appears.
        // (retintOnThemeChange: rebuild on theme swap so the value label — which is
        // UIKit-backed and resolves its tint only at creation — picks up the new accent.)
        Picker(selection: $logged.restSeconds) {
            Text("None").tag(Int?.none)
            ForEach(RestDuration.options, id: \.self) { seconds in
                Text(RestDuration.label(seconds)).tag(Int?.some(seconds))
            }
        } label: {
            Label("Rest timer", systemImage: "timer")
        }
        .retintOnThemeChange(theme.current, salt: "rest-\(logged.id)")

        // Live countdown (drives the shared session timer + mini-bar), once set.
        if let rest = logged.restSeconds {
            RestTimerView(duration: rest, accent: accent)
        }

        // Claude  Date 07/01/2026
        // Adaptive-preset weight suggestion for this session (from AppStore.workout(from:)).
        // Purely informational + seeds the first added set; the value stays fully editable.
        if let adaptive = logged.adaptive {
            AdaptiveHintRow(suggestion: adaptive, accent: accent)
        }

        ForEach(logged.sets.indices, id: \.self) { index in
            SetRow(number: setNumber(at: index),
                   sideLabel: logged.sets[index].side?.title,
                   lagsBehind: lagsBehind(at: index),
                   isBodyweight: isBodyweight,
                   set: $logged.sets[index],
                   targetRange: logged.targetRepRange, accent: accent,
                   focusedField: $focusedField)
        }
        .onDelete { deleteSets(at: $0) }

        Button {
            addSet()
        } label: {
            Label("Add Set", systemImage: "plus.circle")
        }

        // Claude  Date 07/19/2026
        // Swap sits beside Remove (see ExerciseActionsRow). Swap re-opens the exercise
        // picker and replaces this entry's lift in place, keeping its position in the
        // workout; Remove drops it entirely.
        ExerciseActionsRow(onSwap: { showingSwapPicker = true }, onRemove: onRemove)
            .sheet(isPresented: $showingSwapPicker) {
                ExercisePickerView { onSwap($0) }
            }
    }

    // Claude  Date 06/14/2026
    // Whether the underlying exercise is single-side. Unilateral exercises log each
    // set as a Left/Right pair so both sides are tracked and mismatches surfaced.
    private var isUnilateral: Bool {
        store.exercise(for: logged.exerciseId)?.isUnilateral ?? false
    }

    // Claude  Date 07/20/2026
    // Whether the underlying exercise is a bodyweight lift. When true, each set's
    // weight is ADDED weight, so SetRow prefixes it with a "+".
    private var isBodyweight: Bool {
        store.exercise(for: logged.exerciseId)?.isBodyweight ?? false
    }

    /// Adds a set, defaulting to the previous set's reps/weight (or the low end of
    /// the target rep range) for fast entry. Unilateral exercises add a matched
    /// Left+Right pair so each logical set covers both sides.
    private func addSet() {
        let last = logged.sets.last
        let defaultReps = last?.reps
            ?? logged.targetRepRange.map { Swift.min($0.min, $0.max) }
            ?? 8
        // Claude  Date 07/01/2026
        // Seed the first set's weight from the adaptive suggestion (when present);
        // subsequent sets carry the previous set's weight forward as before.
        let defaultWeight = last?.weight ?? logged.adaptive?.weight ?? 0
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

// Claude  Date 07/01/2026
// Compact, informational lead-in for an adaptive-preset exercise: the suggested
// working weight plus WHY it changed (up after hitting the top of the range, down
// after repeated misses, or held). Purely a hint — the seeded set below stays editable.
private struct AdaptiveHintRow: View {
    let suggestion: AdaptiveSuggestion
    let accent: Color

    var body: some View {
        Label {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }

    private var text: String {
        let weight = "\(SetFormat.weight(suggestion.weight)) lb"
        switch suggestion.outcome {
        case .increased:
            return "Suggested \(weight) · +\(SetFormat.weight(suggestion.deltaFromLast)) from last time"
        case .deloaded:
            return "Suggested \(weight) · −\(SetFormat.weight(abs(suggestion.deltaFromLast))) deload"
        case .held:
            return "Suggested \(weight) · same as last time"
        }
    }

    private var icon: String {
        switch suggestion.outcome {
        case .increased: return "arrow.up.circle.fill"
        case .deloaded:  return "arrow.down.circle.fill"
        case .held:      return "equal.circle.fill"
        }
    }

    private var color: Color {
        switch suggestion.outcome {
        case .increased: return .green
        case .deloaded:  return .orange
        case .held:      return accent
        }
    }
}

// Claude  Date 07/01/2026
// Formatting shared by adaptive weight hints: drop a trailing ".0" (135.0 → "135",
// 2.5 → "2.5") so weights read cleanly.
private enum SetFormat {
    static func weight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(value)
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
    // Claude  Date 07/20/2026
    // When true this is a bodyweight lift, so the weight field is ADDED weight and gets
    // a leading "+" (e.g. "+25 lb", or a bare "+" when 0 added).
    var isBodyweight: Bool = false
    @Binding var set: ExerciseSet
    let targetRange: RepRange?
    let accent: Color
    // Claude  Date 07/21/2026
    // Binds this row's two fields into the editor's focus state, so the keyboard bar's
    // steppers act on whichever one is being edited.
    @FocusState.Binding var focusedField: SetEntryField?

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
                    // Claude  Date 07/21/2026 — the 54pt column below is fixed, so a
                    // label that outgrows it (a wide face, a big Dynamic Type size,
                    // "Set 10"+) must truncate rather than wrap the row open.
                    .lineLimit(1)
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
                .focused($focusedField, equals: .reps(self.set.id))
            Text("reps")
                .foregroundStyle(.secondary)

            Spacer()

            // Claude  Date 07/20/2026
            // Bodyweight lifts show a "+" ahead of the weight to read the value as ADDED
            // load on top of bodyweight (e.g. "+ 25 lb"). Normal lifts omit it.
            if isBodyweight {
                Text("+")
                    .foregroundStyle(.secondary)
            }
            TextField("Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(lagsBehind ? .red : .primary)
                .frame(width: 64)
                .focused($focusedField, equals: .weight(self.set.id))
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
