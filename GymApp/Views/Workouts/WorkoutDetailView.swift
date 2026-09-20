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
    // Claude  Date 09/07/2026
    // The user's distance unit — needed here only so the keyboard bar's distance stepper
    // moves the value the user can actually see. Storage stays canonical meters.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    private var distanceUnit: DistanceUnit { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }
    @State private var isEditingNotes = false
    @FocusState private var notesFocused: Bool
    @State private var showingExercisePicker = false
    // Claude  Date 09/07/2026
    // The one-time "what do you weigh?" sheet, raised from a cardio bout that has no
    // calorie figure to show. Skippable — cardio works fine without it.
    @State private var showingBodyweightPrompt = false
    // Claude  Date 06/18/2026
    // The library exercise being edited from a section's pencil (nil = none).
    @State private var editingExercise: Exercise?
    @State private var showingReorder = false
    @State private var showingSaveAsPreset = false
    @State private var presetName = ""
    @State private var savedPresetConfirmation = false
    // Claude  Date 08/25/2026
    // The saved preset a "Save as New Preset" would have duplicated (nil = none). Set
    // instead of saving, so a second copy of an identical template never lands in the
    // list — the alert names the one that's already there.
    @State private var duplicatePreset: WorkoutPreset?
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
    // Claude  Date 09/16/2026
    // Missed-set review from Complete Workout: the alert, the unchecked sets the user went
    // back for (drawn with a "!" until checked off), and the set to scroll to. Transient —
    // leaving the editor clears them, so the next Complete re-checks from scratch.
    @State private var showingMissedSetsAlert = false
    @State private var flaggedSetIDs: Set<UUID> = []
    @State private var missedSetScrollTarget: UUID?
    // CLAUDE  Date 09/18/2026
    // The last removed exercise, still restorable for ~10s via the undo popup (nil = none).
    @State private var pendingUndo: PendingUndo?

    // Claude  Date 09/16/2026
    // Every set not yet checked off, in on-screen order (exercise, then set), so `.last` is
    // the lowest one on the page. Cardio entries count too — they're finished by swipe as well.
    private var uncheckedSetIDs: [UUID] {
        workout.exercises.flatMap { $0.sets.filter { $0.completedAt == nil }.map(\.id) }
    }

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

    // Claude  Date 08/21/2026
    // A finished session's length, shown after the start time. nil while the workout
    // is still running — a static number next to a session that's still adding to it
    // would just be wrong, and a live one would need a ticking timer up here.
    private var elapsedText: String? {
        workout.isFinished ? workout.elapsedText : nil
    }

    // Claude  Date 08/04/2026 last changed: 08/21/2026 by: Claude
    // The date/time line. Set in the THEME's face — a deliberate island in a screen
    // that's otherwise on the system face (see systemTypeface at the bottom of body):
    // a nested fontDesign beats the ambient one, and the contrast is what makes this
    // read as a header rather than a row. A Button, not a tap gesture, so it's
    // reachable and describable to VoiceOver. (08/21) The secondary line now carries
    // the session's duration alongside its start time — same line rather than a new
    // one, so the masthead doesn't grow a third row for one short fragment.
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
                    HStack(spacing: 4) {
                        Text(workout.date, format: .dateTime.hour().minute())
                        if let elapsedText {
                            Text("·")
                            Text(elapsedText)
                        }
                    }
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
        // Claude  Date 09/18/2026
        // Effective face, not the raw theme's: with "Use system font" on, this island
        // must drop to SF Pro like the rest of the app instead of staying mono.
        .fontDesign(theme.fontDesign.design)
        .accessibilityLabel("Workout date")
        // Claude  Date 08/21/2026
        // The duration rides along in the value — it's drawn inside this button, so
        // leaving it out would make it the one thing on the header VoiceOver skips.
        .accessibilityValue(Text(workout.date, format: .dateTime.weekday(.wide).month().day().hour().minute())
                            + Text(elapsedText.map { ", \($0)" } ?? ""))
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

    // Claude  Date 09/16/2026
    // Wraps the form in a ScrollViewReader so "Go Back" on the missed-set alert can land the
    // user on the set. Delayed past the alert's dismissal, which otherwise swallows the scroll;
    // the target is reset to nil after so a second "Go Back" to the same set still fires.
    var body: some View {
        ScrollViewReader { proxy in
            editorForm
                .onChange(of: missedSetScrollTarget) { target in
                    guard let target else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(target, anchor: .center)
                        }
                        missedSetScrollTarget = nil
                    }
                }
                // Claude  Date 09/16/2026
                // Any focus move ends a unilateral pair's first entry: from here on its Left and
                // Right are edited independently. Settled on ANY change (not just leaving the
                // field) so it holds whether a number field commits per keystroke or on blur.
                .onChange(of: focusedField) { _ in session.unilateralFills.settle() }
        }
        // CLAUDE  Date 09/18/2026 — the "Removed X · Undo" popup after removing an exercise.
        .undoToast($pendingUndo, accent: theme.current.accent, surface: theme.current.surface)
        // Claude  Date 09/16/2026
        // Raised by Complete Workout when sets are unchecked. Go Back is the cancel role, so
        // it's the bold, default choice; Finish Anyway credits only what's checked off.
        .alert(missedSetsTitle, isPresented: $showingMissedSetsAlert) {
            Button("Go Back", role: .cancel) { reviewMissedSets() }
            Button("Finish Anyway") { finishAndDismiss() }
        } message: {
            Text(missedSetsMessage)
        }
    }

    // Claude  Date 09/16/2026
    // The editor's Form and its whole modifier chain, split out of body only so body can wrap
    // it in the ScrollViewReader above. Toolbars, sheets and alerts still reach the nav stack.
    private var editorForm: some View {
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
                                       isPresetBacked: workout.presetID != nil,
                                       isFirst: workout.exercises.first?.id == logged.id,
                                       flaggedSetIDs: flaggedSetIDs,
                                       focusedField: $focusedField,
                                       onNeedsBodyweight: { showingBodyweightPrompt = true }) { exercise in
                        logged.exerciseId = exercise.id
                        logged.targetRepRange = store.defaultRepRange(for: exercise.id)
                        // Claude  Date 09/14/2026 — swapping TO cardio seeds its single entry.
                        logged.sets = exercise.cardioMachine != nil ? [.cardioEntry()] : []
                        logged.note = nil
                        // (08/11) Clear the provenance flag with the note it describes,
                        // or the next note typed here would inherit "expiring".
                        logged.noteIsCarriedForward = nil
                        logged.adaptive = nil
                    } onRemove: {
                        removeExercise(logged.id)
                    }
                } header: {
                    // Claude  Date 09/01/2026
                    // Two lines now (see ExerciseSectionHeader): the lift NAME on top, the
                    // equipment/brand/unilateral chips beneath. .textCase(nil) is required —
                    // the grouped-header default would uppercase the name and every chip.
                    ExerciseSectionHeader(exercise: store.exercise(for: logged.exerciseId),
                                          targetRepRange: logged.targetRepRange,
                                          accent: theme.current.accent,
                                          onEdit: { editingExercise = $0 })
                        .textCase(nil)
                } footer: {
                    // Claude  Date 09/07/2026
                    // The soft guardrail. Naming the derived speed is the whole point — a
                    // bare "implausible" wouldn't say which of the two fields was
                    // fat-fingered. The bout still saves; it just earns no calories and no
                    // ledger event. Same Section-footer idiom as NewExerciseView.brandFooter.
                    if let warning = cardioWarning(for: logged) {
                        Text(warning)
                            .foregroundStyle(.orange)
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
                    completeTapped()
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
                // Claude  Date 09/18/2026 — effective face, so it tracks "Use system font"
                // and keeps matching the ChromeFontAppearance nav titles on other screens.
                .fontDesign(theme.fontDesign.design)
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
        .onDisappear {
            if session.viewingWorkoutID == workout.id { session.viewingWorkoutID = nil }
            // Claude  Date 09/16/2026 — leaving mid-entry still counts as the first entry.
            session.unilateralFills.settle()
        }
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
        }
        // Claude  Date 07/21/2026 last changed: 09/17/2026 by: CLAUDE
        // The bar that rides on top of the keyboard: Done, plus quick steppers for
        // whichever set field is focused (see SetEntryAccessoryBar). (09/17) Mounted via
        // setEntryKeyboardBar so iOS 26's glass container is hidden behind its own ring.
        .setEntryKeyboardBar(SetEntryAccessoryBar(
            field: focusedField,
            accent: theme.current.accent,
            surface: theme.current.surface,
            onAdjust: { adjustFocusedField(by: $0) },
            onDone: dismissKeyboardBar))
        // Claude  Date 09/07/2026
        // Hung on the editor, not on a bout row, so it survives that row being reordered or
        // deleted out from under the presentation (same reasoning as the reorder sheet).
        .sheet(isPresented: $showingBodyweightPrompt) {
            BodyweightPromptView()
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { exercise in
                // Claude  Date 06/18/2026
                // Requeue with a rep range already set — the exercise's history-preferred
                // range (most-used of its last 3), or the 8–12 default. So a lift never
                // lands in the workout without a target.
                // Claude  Date 08/07/2026 — animated in, mirroring the animated removal.
                withAnimation(.easeInOut(duration: 0.25)) {
                    workout.exercises.append(
                        LoggedExercise(exerciseId: exercise.id,
                                       targetRepRange: store.defaultRepRange(for: exercise.id),
                                       // Claude  Date 09/14/2026 — cardio arrives with its one
                                       // time/distance entry ready to fill in.
                                       sets: exercise.cardioMachine != nil ? [.cardioEntry()] : []))
                }
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
                store.exercise(for: $0.exerciseId)?.displayLabel ?? "Exercise"
            }
        }
        .alert("Save as New Preset", isPresented: $showingSaveAsPreset) {
            TextField("Preset name", text: $presetName)
            Button("Save") {
                let name = presetName.trimmingCharacters(in: .whitespaces)
                let preset = store.makePreset(from: workout, name: name.isEmpty ? "New Preset" : name)
                // Claude  Date 08/25/2026
                // Refuse an exact copy of a preset that already exists — same name, same
                // lifts in the same order, same rep ranges, sets, rest, and notes. The
                // workout is still linked to the existing one below, so "Override Preset"
                // keeps working from here as if it had just been saved.
                if let existing = store.duplicatePreset(of: preset) {
                    workout.presetID = existing.id
                    duplicatePreset = existing
                    savedPresetConfirmation = true
                    return
                }
                duplicatePreset = nil
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
        // Claude  Date 08/25/2026
        // What "Save as New Preset" says when the template already exists. Nothing was
        // added; the workout now points at the existing preset, which the copy says so
        // the "Override Preset" button appearing afterwards isn't a surprise.
        // Claude  Date 08/25/2026
        // The outcome of "Save as New Preset": saved, or refused as a duplicate. One
        // alert with two faces rather than two alerts — this body is already a long
        // enough modifier chain that adding another tipped the type-checker over, and
        // the two cases are the same beat in the same flow.
        .alert(savedPresetTitle, isPresented: $savedPresetConfirmation) {
            Button("OK", role: .cancel) { duplicatePreset = nil }
        } message: {
            Text(savedPresetMessage)
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
    // Claude  Date 08/25/2026
    // The two faces of the save-outcome alert. The duplicate case names the preset that
    // already matches and warns that the workout has been linked to it — otherwise
    // "Override Preset" appearing afterwards would look like it came from nowhere.
    private var savedPresetTitle: String {
        duplicatePreset == nil ? "Saved to Presets" : "Preset Already Exists"
    }

    private var savedPresetMessage: String {
        guard let duplicatePreset else {
            return "Find it on the Presets tab to set an icon or tweak it."
        }
        let name = duplicatePreset.name.isEmpty ? "Untitled Preset" : duplicatePreset.name
        return "“\(name)” already matches this workout exactly, so nothing new was saved. "
            + "This workout is now linked to it — use Override Preset to push later changes onto it."
    }

    private func dismissKeyboardBar() {
        focusedField = nil
        hideKeyboard()
    }

    // CLAUDE  Date 09/18/2026
    // Remove a lift (running or history workout) and offer ~10s to take it back. Undo puts
    // the same entry — sets, notes, ids — back in its old slot. Animated so the section
    // visibly collapses; an instant removal left you unsure which entry went (08/07).
    private func removeExercise(_ id: UUID) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == id }) else { return }
        let removed = workout.exercises[index]
        let name = store.exercise(for: removed.exerciseId)?.displayLabel ?? "exercise"
        withAnimation(.easeInOut(duration: 0.25)) {
            workout.exercises.remove(at: index)
            pendingUndo = PendingUndo(message: "Removed \(name)") {
                guard !workout.exercises.contains(where: { $0.id == removed.id }) else { return }
                workout.exercises.insert(removed, at: min(index, workout.exercises.count))
            }
        }
    }

    // MARK: - Missed sets

    // Claude  Date 09/16/2026
    // Complete Workout / Finish Edit. An in-progress workout with unchecked sets the user
    // hasn't already been shown stops at the missed-set alert instead of finishing; ones
    // flagged by an earlier Go Back don't re-trigger it, so a deliberate skip isn't nagged twice.
    private func completeTapped() {
        hideKeyboard()
        if !workout.isFinished && !Set(uncheckedSetIDs).isSubset(of: flaggedSetIDs) {
            showingMissedSetsAlert = true
            return
        }
        finishAndDismiss()
    }

    // Claude  Date 09/16/2026
    // Finish (credits checked-off sets and queues the performance card, see
    // AppStore.finishWorkout) and leave the editor. A no-op finish for an already-finished one.
    private func finishAndDismiss() {
        if !workout.isFinished { store.finishWorkout(id: workout.id) }
        dismiss()
    }

    // Claude  Date 09/16/2026
    // The alert's Go Back: badge every unchecked set with "!" and scroll to the last one on
    // the page. Side effect: those sets stop re-triggering the alert on the next Complete.
    private func reviewMissedSets() {
        let unchecked = uncheckedSetIDs
        flaggedSetIDs.formUnion(unchecked)
        missedSetScrollTarget = unchecked.last.map(rowID(containing:))
    }

    // Claude  Date 09/16/2026
    // The list row a set is drawn in: its own id, or its pair's lead id for a unilateral side
    // (both sides share one row). Used to scroll to a set and to count a pair as one set.
    private func rowID(containing setID: UUID) -> UUID {
        guard let logged = workout.exercises.first(where: { $0.sets.contains { $0.id == setID } })
        else { return setID }
        return SetGroup.groups(from: logged.sets, isUnilateral: isUnilateral(logged))
            .first { $0.setIDs.contains(setID) }?.id ?? setID
    }

    private var uncheckedRowCount: Int {
        Set(uncheckedSetIDs.map(rowID(containing:))).count
    }

    private var missedSetsTitle: String {
        let count = uncheckedRowCount
        return count == 1 ? "1 Set Not Checked Off" : "\(count) Sets Not Checked Off"
    }

    private var missedSetsMessage: String {
        let them = uncheckedRowCount == 1 ? "it" : "them"
        let base = "If you did \(them) and just forgot to track, go back and swipe \(them) right. "
            + "Unchecked sets won't count toward your progress."
        // CLAUDE  Date 09/17/2026
        // With nothing checked off the session isn't kept at all (AppStore.finishWorkout
        // drops it), so say that before they tap Finish Anyway rather than after.
        guard workout.completedSets == 0 else { return base }
        return base + " With none checked off, this workout won't be saved to your history."
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

            // Claude  Date 09/16/2026 — reps/weight go through writeSetEdit, so a stepper on a
            // unilateral pair's first entry fills the other side exactly as typing does.
            var edited = workout.exercises[exerciseIndex].sets[setIndex]
            switch field {
            case .reps:
                edited.reps = max(0, edited.reps + Int(delta))
                applySetEdit(edited, exerciseIndex: exerciseIndex)
            case .weight:
                edited.weight = max(0, ((edited.weight + delta) * 100).rounded() / 100)
                applySetEdit(edited, exerciseIndex: exerciseIndex)
            // Claude  Date 09/07/2026
            // Both halves of a bout's time fold into the one durationSeconds, so a seconds
            // step past 60 carries into the minute for free. Clamped to CardioPolicy's hard
            // ceiling for the same reason reps and weight clamp at 0: there is no Save
            // button on a set, so refusing an impossible value means bounding it.
            case .durationMinutes:
                adjustDuration(exerciseIndex, setIndex, bySeconds: Int(delta) * 60)
            case .durationSeconds:
                adjustDuration(exerciseIndex, setIndex, bySeconds: Int(delta))
            case .distance:
                // The step is in the user's DISPLAY unit; storage is canonical meters.
                let current = workout.exercises[exerciseIndex].sets[setIndex].distanceMeters ?? 0
                let updated = max(0, ((distanceUnit.fromMeters(current) + delta) * 100).rounded() / 100)
                let meters = distanceUnit.toMeters(updated)
                workout.exercises[exerciseIndex].sets[setIndex].distanceMeters = meters > 0 ? meters : nil
            // CLAUDE  Date 09/17/2026 — rep-range bounds are only focus-tracked in the preset
            // editor; they're keyed by a preset item, so no set here ever matches them.
            case .repRangeMin, .repRangeMax:
                break
            }
            return
        }
    }

    // Claude  Date 09/07/2026
    // The first implausible bout in this exercise, phrased for the user. nil for a lift, and
    // nil when everything logged sits inside CardioPolicy's band.
    private func cardioWarning(for logged: LoggedExercise) -> String? {
        guard let machine = store.exercise(for: logged.exerciseId)?.cardioMachine else { return nil }
        for set in logged.sets {
            guard let seconds = set.durationSeconds else { continue }
            if let warning = CardioPolicy.warning(machine: machine, seconds: seconds,
                                                  meters: set.distanceMeters, unit: distanceUnit) {
                return warning
            }
        }
        return nil
    }

    private func isUnilateral(_ logged: LoggedExercise) -> Bool {
        store.exercise(for: logged.exerciseId)?.isUnilateral ?? false
    }

    private func applySetEdit(_ edited: ExerciseSet, exerciseIndex: Int) {
        var sets = workout.exercises[exerciseIndex].sets
        writeSetEdit(edited, into: &sets, isUnilateral: isUnilateral(workout.exercises[exerciseIndex]),
                     fills: &session.unilateralFills)
        workout.exercises[exerciseIndex].sets = sets
    }

    private func adjustDuration(_ exerciseIndex: Int, _ setIndex: Int, bySeconds delta: Int) {
        let current = workout.exercises[exerciseIndex].sets[setIndex].durationSeconds ?? 0
        workout.exercises[exerciseIndex].sets[setIndex].durationSeconds =
            min(max(0, current + delta), CardioPolicy.hardMaxSeconds)
    }
}

/// The rows for one exercise within a workout: each set, an "add set" button,
/// and a "remove exercise" button.
private struct ExerciseLogSection: View {
    @EnvironmentObject private var store: AppStore
    // Claude  Date 09/16/2026 — holds the unilateral first-entry fill state (see setBinding).
    @EnvironmentObject private var session: WorkoutSession
    // Claude  Date 07/16/2026
    // For retintOnThemeChange below — the menu picker needs the active theme's
    // identity, not just the resolved accent Color passed in by the parent.
    @EnvironmentObject private var theme: ThemeManager
    @Binding var logged: LoggedExercise
    let accent: Color
    // Claude  Date 08/11/2026
    // Whether this workout came from a preset. The session note is a message to your next
    // session OF THAT PRESET, so an ad-hoc workout has nowhere to send one and doesn't
    // offer the row at all (see ExerciseNoteFields.showsSessionNote).
    let isPresetBacked: Bool
    // Claude  Date 09/01/2026
    // True for the workout's first exercise only — the one place the one-time
    // swipe/long-press hint row is allowed to appear, so it isn't repeated per section.
    let isFirst: Bool
    // Claude  Date 09/16/2026
    // Sets the user went back for from the missed-set alert; each one's row shows the "!"
    // badge until it's checked off. Empty until that alert's Go Back is tapped.
    let flaggedSetIDs: Set<UUID>
    // Claude  Date 07/21/2026
    // The editor's set-field focus, passed straight through to each SetRow so the
    // keyboard accessory bar knows which value it's stepping.
    @FocusState.Binding var focusedField: SetEntryField?
    // Claude  Date 09/07/2026
    // Raised when a bout can't show calories because no bodyweight is on file.
    let onNeedsBodyweight: () -> Void
    let onSwap: (Exercise) -> Void
    let onRemove: () -> Void

    // Claude  Date 09/07/2026
    // The user's distance unit. Storage is canonical meters; this converts at the edge only,
    // so flipping the setting never rewrites a logged bout.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    private var distanceUnit: DistanceUnit { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }

    // Claude  Date 07/19/2026
    // Drives the exercise picker opened by the row's "Swap" button.
    @State private var showingSwapPicker = false

    // Claude  Date 09/01/2026
    // Drag-reorder sheet for this exercise's sets, opened from a set's long-press menu.
    @State private var showingReorderSets = false

    // Claude  Date 09/01/2026 last changed: 09/18/2026 by: CLAUDE
    // App-wide, one flag per set gesture: each tip drops off once that gesture is used, and ✕
    // hides them all. The finish flag keeps its original key, so anyone who already swiped
    // a set done is only shown delete/reorder — the two that were never taught.
    @AppStorage("hasSeenSetSwipeHint") private var usedSwipeToFinish = false
    @AppStorage("hasUsedSetSwipeDelete") private var usedSwipeToDelete = false
    @AppStorage("hasUsedSetHoldReorder") private var usedHoldToReorder = false
    @AppStorage("setGestureTipsDismissed") private var setTipsDismissed = false

    var body: some View {
        // Claude  Date 09/07/2026 — a bout has no reps, so no range to aim at.
        if !isCardio {
            RepRangeRow(targetRepRange: $logged.targetRepRange)
        }

        // Claude  Date 08/04/2026 last changed: 08/11/2026 by: Claude
        // Two note tiers: the perma note on the lift itself and the session note — a
        // message to your next session of this preset. See ExerciseNoteFields.
        // (08/11) Editing clears the carried-forward flag, which both fills the icon back
        // in and re-arms the note for one more session.
        ExerciseNoteFields(exerciseId: logged.exerciseId,
                           sessionNote: $logged.note,
                           accent: accent,
                           showsSessionNote: isPresetBacked,
                           sessionNoteIsExpiring: logged.noteIsCarriedForward == true,
                           onEditSessionNote: { logged.noteIsCarriedForward = false })

        // Claude  Date 06/12/2026 last changed: 07/16/2026 by: Claude
        // Optional rest timer for ANY exercise — preset items arrive with a duration,
        // but ad-hoc exercises in a non-preset workout can now opt in here too (mirrors
        // the preset editor's picker). Pick a duration and the live countdown appears.
        // (retintOnThemeChange: rebuild on theme swap so the value label — which is
        // UIKit-backed and resolves its tint only at creation — picks up the new accent.)
        // Claude  Date 09/14/2026 — hidden for cardio: it's done once, so there's no
        // between-sets rest to time.
        if !isCardio {
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
        }

        // Claude  Date 07/01/2026
        // Adaptive-preset weight suggestion for this session (from AppStore.workout(from:)).
        // Purely informational + seeds the first added set; the value stays fully editable.
        // Claude  Date 09/07/2026 — `!isCardio` guards a stale suggestion on a workout
        // whose lift was later swapped to cardio; AppStore.adaptiveSuggestion already
        // refuses to make a new one, since a bout has no working weight to progress.
        if let adaptive = logged.adaptive, !isCardio {
            AdaptiveHintRow(suggestion: adaptive, accent: accent)
        }

        // Claude  Date 09/01/2026
        // Keyed by the set's own id, not its position: a reorder has to animate as a row
        // MOVING, and index identity animates it as two rows swapping their contents.
        // Claude  Date 09/14/2026
        // Cardio: one time/distance card, done once. Only the swipe-to-finish survives —
        // no delete, reorder or Add, since there's nothing to have more than one of.
        // (Older workouts logged with several entries still list each one.)
        if isCardio {
            ForEach(Array(logged.sets.enumerated()), id: \.element.id) { index, set in
                cardioRow(at: index)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        completeSwipeButton(for: [set.id])
                    }
                    // CLAUDE  Date 09/18/2026 — long-press fallback for the swipe.
                    .contextMenu { markDoneMenuButton(for: [set.id]) }
                    // Claude  Date 09/16/2026 — scroll anchor for the missed-set alert's Go Back.
                    .id(set.id)
            }
        } else {
            // Claude  Date 09/16/2026
            // One list row per LOGICAL set: a unilateral Left/Right pair shares a single row, so
            // the swipes and long-press below animate across both sides and act on both at once.
            // Keyed by the group's lead set id, which is also the missed-set scroll anchor.
            ForEach(Array(rowGroups.enumerated()), id: \.element.id) { position, group in
                setGroupRow(group, number: position + 1)
                    // Claude  Date 09/01/2026
                    // Swipe RIGHT to check a set off — full swipe finishes it in one flick,
                    // swiping again undoes it. This replaced the ~17pt checkmark button that
                    // used to sit at the row's leading edge.
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        completeSwipeButton(for: group.setIDs)
                    }
                    // Explicit trailing delete replaces the ForEach's old .onDelete so both
                    // edges are declared here; a unilateral pair is one row, so it goes whole.
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            usedSwipeToDelete = true
                            deleteSets(group.setIDs)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    // Claude  Date 09/01/2026 last changed: 09/18/2026 by: CLAUDE
                    // Long-press to reorder: deliberate enough that it can't fire by accident,
                    // and it avoids edit mode, which would disable the reps/weight fields.
                    // (09/18) Also spells out Mark Done and Delete Set for anyone who holds
                    // a row instead of swiping it. Moves carry a unilateral pair as one.
                    .contextMenu {
                        markDoneMenuButton(for: group.setIDs)

                        Divider()

                        Button {
                            moveGroup(group.id, by: -1)
                        } label: {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                        .disabled(!canMove(group.id, by: -1))

                        Button {
                            moveGroup(group.id, by: 1)
                        } label: {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                        .disabled(!canMove(group.id, by: 1))

                        Divider()

                        Button {
                            usedHoldToReorder = true
                            showingReorderSets = true
                        } label: {
                            Label("Reorder Sets…", systemImage: "arrow.up.arrow.down")
                        }
                        .disabled(rowGroups.count < 2)

                        Divider()

                        Button(role: .destructive) {
                            deleteSets(group.setIDs)
                        } label: {
                            Label("Delete Set", systemImage: "trash")
                        }
                    }
                    .id(group.id)
            }
        }

        // Claude  Date 09/01/2026 last changed: 09/18/2026 by: CLAUDE
        // The set-gesture tips, on the first exercise only. (09/18) Lists just the gestures not
        // yet used, so it shrinks as they're learned and is gone once all are; ✕ hides it early.
        if isFirst && !setTipsDismissed && !logged.sets.isEmpty
            && (tipFinish || tipDelete || tipReorder) {
            SetGestureTips(showFinish: tipFinish, showDelete: tipDelete, showReorder: tipReorder,
                           accent: accent) {
                withAnimation(.easeInOut(duration: 0.25)) { setTipsDismissed = true }
            }
        }

        if !isCardio {
            // CLAUDE  Date 09/18/2026 — filled + semibold while the lift has no sets, so the
            // first step on an empty exercise stands out; plain again once there's a set.
            Button {
                addSet()
            } label: {
                Label("Add Set", systemImage: logged.sets.isEmpty ? "plus.circle.fill" : "plus.circle")
                    .fontWeight(logged.sets.isEmpty ? .semibold : .regular)
            }
            // Claude  Date 09/01/2026
            // Hung here rather than on a set row so it survives that row being reordered out
            // from under the presentation (and so only one sheet exists per exercise).
            .sheet(isPresented: $showingReorderSets) {
                ReorderExercisesSheet(title: "Reorder Sets", items: setGroups) { group in
                    let first = group.sets[0]
                    // Claude  Date 09/07/2026 — a legacy cardio entry has no reps or load;
                    // without this branch it would read "0 reps × 0 lb".
                    if let seconds = first.durationSeconds {
                        return CardioFormat.summary(seconds: seconds, meters: first.distanceMeters,
                                                    unit: distanceUnit)
                    }
                    let sides = group.sets.count > 1 ? " · L/R" : ""
                    return "\(first.reps) reps × \(SetFormat.weight(first.weight)) lb\(sides)"
                }
            }
        }

        // Claude  Date 07/19/2026
        // Swap sits beside Remove (see ExerciseActionsRow). Swap re-opens the exercise
        // picker and replaces this entry's lift in place, keeping its position in the
        // workout; Remove drops it entirely.
        ExerciseActionsRow(onSwap: { showingSwapPicker = true }, onRemove: onRemove)
            // Claude  Date 09/01/2026
            // Warm the Taptic Engine as the lift scrolls in, so the FIRST swipe of the
            // session lands with the animation instead of a beat behind it.
            .onAppear {
                Haptics.prepare()
                // Claude  Date 09/14/2026 — fallback for cardio that arrived empty (e.g. an
                // older in-progress workout): give it its single time/distance entry.
                if isCardio && logged.sets.isEmpty { logged.sets = [.cardioEntry()] }
            }
            .sheet(isPresented: $showingSwapPicker) {
                // Claude  Date 08/16/2026
                // Hand the picker the lift being swapped out so plausible substitutes
                // sort to the top (see Exercise.related). Typing a search cancels that.
                ExercisePickerView(relatedTo: store.exercise(for: logged.exerciseId)) { onSwap($0) }
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

    // Claude  Date 09/07/2026
    // The cardio machine behind this entry, and the one gate on cardio behavior: non-nil
    // means log duration + distance instead of reps x weight.
    private var cardioMachine: CardioMachine? {
        store.exercise(for: logged.exerciseId)?.cardioMachine
    }
    private var isCardio: Bool { cardioMachine != nil }

    // Claude  Date 09/07/2026 last changed: 09/16/2026 by: Claude
    // A cardio bout's row. (09/16) Lifts no longer come through here — they render per
    // logical set in setGroupRow — so this is the cardio half of what was entryRow.
    @ViewBuilder
    private func cardioRow(at index: Int) -> some View {
        if let machine = cardioMachine {
            CardioEntryRow(machine: machine,
                           set: $logged.sets[index],
                           accent: accent,
                           unit: distanceUnit,
                           // CLAUDE  Date 09/19/2026 — the latest weigh-in when the user has
                           // one, else the weight typed in Settings (see AppStore).
                           bodyweightLb: store.effectiveBodyweightLb,
                           isMissed: flaggedSetIDs.contains(logged.sets[index].id),
                           focusedField: $focusedField,
                           onMissingBodyweight: onNeedsBodyweight)
        }
    }

    // Claude  Date 09/16/2026
    // This lift's sets as list rows: one per set, or one per Left/Right pair when unilateral.
    private var rowGroups: [SetGroup] {
        SetGroup.groups(from: logged.sets, isUnilateral: isUnilateral)
    }

    // Claude  Date 09/16/2026
    // One logical set's row. A pair stacks its Left and Right lines (divider between) in ONE
    // cell, so a swipe slides both together; a fully-done pair gets one wash across both lines
    // (a half-done legacy pair keeps per-line washes so you can see which side).
    @ViewBuilder
    private func setGroupRow(_ group: SetGroup, number: Int) -> some View {
        if group.indices.count == 2 {
            let lead = group.indices.lowerBound
            let pairDone = isCompleted(group.setIDs)
            VStack(spacing: 10) {
                setLine(at: lead, partner: lead + 1, number: number, drawsCompletedWash: !pairDone)
                Divider()
                setLine(at: lead + 1, partner: lead, number: number, drawsCompletedWash: !pairDone)
            }
            .completedSetStyling(isCompleted: pairDone, accent: accent)
        } else {
            setLine(at: group.indices.lowerBound, partner: nil, number: number, drawsCompletedWash: true)
        }
    }

    private func setLine(at index: Int, partner: Int?, number: Int, drawsCompletedWash: Bool) -> some View {
        SetRow(number: number,
               sideLabel: logged.sets[index].side?.title,
               lagsBehind: lagsBehind(at: index, partner: partner),
               isBodyweight: isBodyweight,
               isMissed: flaggedSetIDs.contains(logged.sets[index].id),
               drawsCompletedWash: drawsCompletedWash,
               set: setBinding(at: index),
               targetRange: logged.targetRepRange, accent: accent,
               focusedField: $focusedField)
    }

    // Claude  Date 09/16/2026
    // A set's binding for SetRow, read by id so a delete can't strand it on a stale index.
    // Writes go through writeSetEdit — side effect: a pair's first reps/weight entry fills the
    // other side once (tracked on the session, see UnilateralFillState).
    private func setBinding(at index: Int) -> Binding<ExerciseSet> {
        let snapshot = logged.sets[index]
        return Binding(
            get: { logged.sets.first { $0.id == snapshot.id } ?? snapshot },
            set: { edited in
                var sets = logged.sets
                writeSetEdit(edited, into: &sets, isUnilateral: isUnilateral,
                             fills: &session.unilateralFills)
                logged.sets = sets
            })
    }

    // Claude  Date 09/14/2026 last changed: 09/16/2026 by: Claude
    // The leading-swipe Done/Undo button, shared by the lift ForEach and the cardio card so
    // both finish the same way. Only toggles completedAt; credit still lands at finishWorkout.
    // (09/16) Takes a row's set ids, so on a unilateral pair it checks off / undoes both sides.
    private func completeSwipeButton(for ids: [UUID]) -> some View {
        let done = isCompleted(ids)
        return Button {
            usedSwipeToFinish = true
            toggleComplete(ids)
        } label: {
            Label(done ? "Undo" : "Done",
                  systemImage: done ? "arrow.uturn.backward" : "checkmark")
        }
        .tint(done ? .gray : accent)
    }

    // CLAUDE  Date 09/18/2026
    // The long-press menu's spelled-out version of the finish swipe. Deliberately leaves the
    // swipe tip up: using the menu means the swipe itself still hasn't been learned.
    private func markDoneMenuButton(for ids: [UUID]) -> some View {
        let done = isCompleted(ids)
        return Button {
            toggleComplete(ids)
        } label: {
            Label(done ? "Mark Not Done" : "Mark Done",
                  systemImage: done ? "arrow.uturn.backward" : "checkmark")
        }
    }

    // CLAUDE  Date 09/18/2026
    // Which gestures the tip row still names. Cardio only finishes; reorder waits until there
    // are two sets to reorder, so the tip never describes something the user can't do yet.
    private var tipFinish: Bool { !usedSwipeToFinish }
    private var tipDelete: Bool { !isCardio && !usedSwipeToDelete }
    private var tipReorder: Bool { !isCardio && !usedHoldToReorder && rowGroups.count >= 2 }

    /// Adds a set, defaulting to the previous set's reps/weight (or the low end of
    /// the target rep range) for fast entry. Unilateral exercises add a matched
    /// Left+Right pair so each logical set covers both sides.
    private func addSet() {
        // Claude  Date 09/07/2026
        // A bout carries reps 0 / weight 0 — that is precisely what keeps it out of every
        // volume, PR and 1RM sum without those sites needing a cardio branch of their own.
        // Duration seeds from the previous bout, or 20 minutes for the first.
        // (09/14) Cardio no longer adds entries — it holds exactly one (.cardioEntry()).
        if isCardio { return }
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

    // Claude  Date 06/14/2026 last changed: 09/16/2026 by: Claude
    // Swipe-delete a row's sets. (The activity ledger is append-only, so any already-earned
    // credit is kept.) (09/16) A unilateral pair is now one row, so the swipe itself animates
    // both sides out together — no partner row left to vanish on its own.
    private func deleteSets(_ ids: [UUID]) {
        withAnimation(.easeInOut(duration: 0.25)) {
            logged.sets.removeAll { ids.contains($0.id) }
        }
    }

    // Claude  Date 06/14/2026 last changed: 09/16/2026 by: Claude
    // True when this side is the one to push to even out the pair: strictly lower on weight
    // or reps than its partner. A matched pair flags neither; a "mixed" pair flags both.
    // (09/16) The partner comes from the row's group instead of index parity.
    private func lagsBehind(at index: Int, partner: Int?) -> Bool {
        guard let partner else { return false }
        let mine = logged.sets[index]
        let theirs = logged.sets[partner]
        guard mine.reps != theirs.reps || mine.weight != theirs.weight else { return false }
        return mine.weight < theirs.weight || mine.reps < theirs.reps
    }

    /// Whether every set in a row is checked off (false for ids that no longer exist).
    private func isCompleted(_ ids: [UUID]) -> Bool {
        let matched = logged.sets.filter { ids.contains($0.id) }
        return !matched.isEmpty && matched.allSatisfy { $0.completedAt != nil }
    }

    // Claude  Date 09/01/2026 last changed: 09/18/2026 by: CLAUDE
    // Check a row off / undo it, from the leading swipe or the long-press menu. Only stamps
    // completedAt — credit is still granted in one batch by AppStore.finishWorkout. Side effect:
    // a graded haptic. (09/16) Acts on every set in the row. (09/18) Tips retire at the swipe.
    private func toggleComplete(_ ids: [UUID]) {
        let indices = logged.sets.indices.filter { ids.contains(logged.sets[$0].id) }
        guard !indices.isEmpty else { return }
        let completing = !isCompleted(ids)
        // Claude  Date 09/07/2026
        // The hard tier's last line of defence: a bout past the physically-possible ceiling
        // cannot be checked off at all, so it can never reach finishWorkout's ledger mint.
        // This catches the one order the input clamp can't — distance typed BEFORE the time,
        // where there was no duration to clamp the distance against yet.
        if completing, let machine = cardioMachine {
            for index in indices {
                guard let seconds = logged.sets[index].durationSeconds else { continue }
                if !CardioPolicy.isWithinHardLimits(machine: machine, seconds: seconds,
                                                    meters: logged.sets[index].distanceMeters) {
                    Haptics.soften()
                    return
                }
            }
        }
        // Three textures, so the gesture tells you WHICH thing happened without looking:
        // the last open row of the lift celebrates, any other row succeeds, undo is soft.
        let openInRow = indices.filter { logged.sets[$0].completedAt == nil }.count
        if !completing {
            Haptics.soften()
        } else if openSetCount == openInRow {
            Haptics.celebrate()
        } else {
            Haptics.success()
        }
        // Written as one array so a pair flips in a single update. A side already done keeps
        // its original timestamp when the other side is checked off.
        var sets = logged.sets
        let now = Date()
        for index in indices {
            sets[index].completedAt = completing ? (sets[index].completedAt ?? now) : nil
        }
        // Underdamped on purpose — the check overshoots and settles, which is what makes
        // finishing a set feel like a physical action instead of a state flag flipping.
        withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
            logged.sets = sets
        }
    }

    /// Sets on this lift still open — drives the "last one" celebration above.
    private var openSetCount: Int {
        logged.sets.filter { $0.completedAt == nil }.count
    }

    // Claude  Date 09/01/2026
    // The sets as logical groups, writable — flattening back through this binding is what
    // persists a reorder (AppStore.binding(for:) → @Published workouts → disk).
    private var setGroups: Binding<[SetGroup]> {
        Binding(get: { rowGroups },
                set: { logged.sets = $0.flatMap(\.sets) })
    }

    private func canMove(_ id: UUID, by delta: Int) -> Bool {
        guard let position = rowGroups.firstIndex(where: { $0.id == id }) else { return false }
        return rowGroups.indices.contains(position + delta)
    }

    // Claude  Date 09/01/2026 last changed: 09/16/2026 by: Claude
    // Swap this row's logical set with its neighbour. Set NUMBERS are positional, so the
    // list renumbers itself top-down afterwards; the ledger keys off setId, so nothing
    // already earned is disturbed. (09/16) Addressed by the row's id rather than a row index.
    private func moveGroup(_ id: UUID, by delta: Int) {
        var all = rowGroups
        guard let position = all.firstIndex(where: { $0.id == id }),
              all.indices.contains(position + delta) else { return }
        all.swapAt(position, position + delta)
        // A crisp detent click, not the generic tap — the set snapped into a new slot.
        Haptics.click()
        usedHoldToReorder = true   // CLAUDE 09/18/2026 — the long-press is learned; drop its tip
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            logged.sets = all.flatMap(\.sets)
        }
    }

}

// CLAUDE  Date 09/18/2026
// The set-gesture tip row: "Swipe → done ← delete · Hold to reorder", naming only what's
// passed in. Kept short enough for one line on small phones; at large text sizes it stacks
// and wraps instead of clipping. ✕ is its own borderless button so the row isn't one tap.
private struct SetGestureTips: View {
    let showFinish: Bool
    let showDelete: Bool
    let showReorder: Bool
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { swipeTip; reorderTip }
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 4) { swipeTip; reorderTip }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenTip)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Hide set tips")
        }
    }

    @ViewBuilder
    private var swipeTip: some View {
        if showFinish || showDelete {
            HStack(spacing: 6) {
                Text("Swipe")
                if showFinish { arrow("arrow.right", "done", accent) }
                if showDelete { arrow("arrow.left", "delete", .red) }
            }
        }
    }

    @ViewBuilder
    private var reorderTip: some View {
        if showReorder { Text("Hold to reorder") }
    }

    private func arrow(_ symbol: String, _ word: String, _ tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(word)
        }
    }

    private var spokenTip: String {
        var parts: [String] = []
        if showFinish { parts.append("swipe right on a set to finish it") }
        if showDelete { parts.append("swipe left to delete it") }
        if showReorder { parts.append("touch and hold to reorder") }
        return "Tip: " + parts.joined(separator: ", ")
    }
}

// Claude  Date 09/01/2026 last changed: 09/16/2026 by: Claude
// One LOGICAL set: a single set normally, a Left+Right pair for a unilateral lift — and, as of
// 09/16, one list row either way. Moved to file scope so the editor can find a set's row too
// (missed-set scroll, stepper auto-fill). Moves must carry groups whole, never split a pair.
private struct SetGroup: Identifiable {
    let id: UUID          // the leading set's id, so identity survives a move
    var sets: [ExerciseSet]
    /// Where these sets sat in the array the group was built from (stale after a move).
    let indices: Range<Int>

    var setIDs: [UUID] { sets.map(\.id) }

    static func groups(from sets: [ExerciseSet], isUnilateral: Bool) -> [SetGroup] {
        var result: [SetGroup] = []
        var index = 0
        while index < sets.count {
            // Pair adjacent OPPOSITE sides; a stray unpaired set stands on its own so
            // legacy/half-deleted data still renders instead of crashing.
            if isUnilateral, index + 1 < sets.count,
               let mine = sets[index].side,
               let theirs = sets[index + 1].side,
               mine != theirs {
                result.append(SetGroup(id: sets[index].id, sets: [sets[index], sets[index + 1]],
                                       indices: index..<(index + 2)))
                index += 2
            } else {
                result.append(SetGroup(id: sets[index].id, sets: [sets[index]],
                                       indices: index..<(index + 1)))
                index += 1
            }
        }
        return result
    }
}

// Claude  Date 09/16/2026
// Writes an edited set. Unilateral first-entry fill: the FIRST time a pair's reps or weight is
// entered (either side), the other side copies it; after that each side is independent. Skipped
// once either side is checked off, or if the sides already differ. Side effect: updates `fills`.
private func writeSetEdit(_ edited: ExerciseSet, into sets: inout [ExerciseSet],
                          isUnilateral: Bool, fills: inout UnilateralFillState) {
    guard let index = sets.firstIndex(where: { $0.id == edited.id }) else { return }
    let old = sets[index]
    sets[index] = edited
    guard let pair = SetGroup.groups(from: sets, isUnilateral: isUnilateral)
            .first(where: { $0.indices.count == 2 && $0.indices.contains(index) }) else { return }
    let partner = index == pair.indices.lowerBound ? index + 1 : index - 1
    guard old.completedAt == nil, sets[partner].completedAt == nil else { return }

    let partnerID = sets[partner].id
    if edited.reps != old.reps && !fills.filled.contains(.reps(old.id)) {
        if sets[partner].reps == old.reps { sets[partner].reps = edited.reps }
        fills.filling.formUnion([.reps(old.id), .reps(partnerID)])
    }
    if edited.weight != old.weight && !fills.filled.contains(.weight(old.id)) {
        if sets[partner].weight == old.weight { sets[partner].weight = edited.weight }
        fills.filling.formUnion([.weight(old.id), .weight(partnerID)])
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
    // Claude  Date 09/16/2026
    // Flagged by the missed-set alert's Go Back: swaps the rep-range dot for the "!" badge
    // until the set is checked off (completion always wins the mark slot).
    var isMissed: Bool = false
    // Claude  Date 09/16/2026
    // False when this line is half of a finished Left/Right pair — the pair's row draws one
    // wash across both lines instead (see ExerciseLogSection.setGroupRow).
    var drawsCompletedWash: Bool = true
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
            CompletionMark(isCompleted: isCompleted, isMissed: isMissed,
                           markColor: markColor, accent: accent)

            // Claude  Date 06/14/2026
            // Set number, with the Left/Right side beneath it for unilateral sets.
            // The side label turns red when this side lags its pair.
            VStack(alignment: .leading, spacing: 1) {
                Text("Set \(number)")
                    .foregroundStyle(.secondary)
                    // Claude  Date 09/01/2026 — reordering renumbers the rows, so roll the
                    // digit rather than swapping it (the app's idiom, see MonthlyRecapCard).
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: number)
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
        .completedSetStyling(isCompleted: isCompleted && drawsCompletedWash, accent: accent)
        // Swipe actions reach VoiceOver through the Actions rotor on their own, but the
        // row still has to say which state it is in.
        .accessibilityElement(children: .contain)
        .accessibilityValue(completionAccessibilityValue(isCompleted: isCompleted, isMissed: isMissed))
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

// Claude  Date 09/07/2026
// The completion indicator, lifted out of SetRow so a cardio bout shows the identical
// mark. One slot, two meanings: the rep-range dot while the entry is open, a filled check
// once it's done, with the overshoot that makes finishing feel physical. Nothing here is
// tappable — completion is a leading swipe, wired up in ExerciseLogSection.
private struct CompletionMark: View {
    let isCompleted: Bool
    // Claude  Date 09/16/2026 — a set flagged by the missed-set alert; shows the "!" badge.
    var isMissed: Bool = false
    var markColor: Color? = nil
    let accent: Color

    @State private var pop: CGFloat = 1

    var body: some View {
        ZStack {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(accent)
                    // Grows in from a dot, so it reads as the mark BECOMING a check.
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else if isMissed {
                MissedSetBadge()
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .fill(markColor ?? .clear)
                    .frame(width: 8, height: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 18)
        .scaleEffect(pop)
        .onChange(of: isCompleted) { done in
            guard done else { return }
            pop = 1.45
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { pop = 1 }
        }
    }
}

// Claude  Date 09/16/2026
// The "!" on a set left unchecked at Complete Workout. Fixed warning-sign colors, not theme
// ones, so it reads on every theme and custom palette: black "!" on yellow inside a black ring
// (the ring carries it on pale rows, the yellow fill on dark and colored ones).
private struct MissedSetBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#FFCC00"))
            Circle()
                .strokeBorder(Color.black, lineWidth: 1.5)
            Text("!")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.black)
        }
        .frame(width: 17, height: 17)
        .accessibilityHidden(true)
    }
}

// Claude  Date 09/16/2026
// The row-level VoiceOver state shared by SetRow and CardioEntryRow. The badge itself is
// hidden from VoiceOver, so "missed" has to be spoken here instead.
private func completionAccessibilityValue(isCompleted: Bool, isMissed: Bool) -> String {
    if isCompleted { return "Completed" }
    return isMissed ? "Not completed, missed" : "Not completed"
}

// Claude  Date 09/07/2026
// The "this row is finished" treatment, lifted out of SetRow for the same reason: an accent
// wash drawn INSIDE the cell (not .listRowBackground, which would replace the theme's own
// row fill) plus a light dim, animated so it cross-fades instead of popping.
private extension View {
    func completedSetStyling(isCompleted: Bool, accent: Color) -> some View {
        self
            .opacity(isCompleted ? 0.75 : 1)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(isCompleted ? 0.12 : 0))
                    .padding(.horizontal, -6)
                    .padding(.vertical, -4)
                    // Deliberately NOT the row's spring: the wash settles calmly underneath
                    // while the check overshoots on top of it.
                    .animation(.easeOut(duration: 0.3), value: isCompleted)
            )
    }
}

// Claude  Date 09/07/2026 last changed: 09/14/2026 by: Claude
// The cardio entry: one thing done once per workout, laid out as labeled lines, not a set:
//     [mark] Time        [ 25 ] min  [ 30 ] sec
//            Distance              [ 3.10 ] mi
//            8:03 /mi                ~310 kcal (est.)
// Min/sec both write durationSeconds (90 sec carries into the minute); distance is stored in
// meters. Calories are an estimate, or the add-your-weight prompt — never a guessed number.
private struct CardioEntryRow: View {
    let machine: CardioMachine
    @Binding var set: ExerciseSet
    let accent: Color
    let unit: DistanceUnit
    let bodyweightLb: Double?
    // Claude  Date 09/16/2026 — flagged by the missed-set alert; see SetRow.isMissed.
    var isMissed: Bool = false
    @FocusState.Binding var focusedField: SetEntryField?
    let onMissingBodyweight: () -> Void

    // `self.` is required throughout: a leading `set` in an accessor body reads as the
    // setter keyword, since the binding is named `set` (same note as SetRow).
    private var isCompleted: Bool { self.set.completedAt != nil }
    private var seconds: Int { self.set.durationSeconds ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                CompletionMark(isCompleted: isCompleted, isMissed: isMissed, accent: accent)

                Text("Time")

                Spacer(minLength: 0)

                TextField("0", value: minutesBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                    .focused($focusedField, equals: .durationMinutes(self.set.id))
                Text("min").foregroundStyle(.secondary)

                TextField("0", value: secondsBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 34)
                    .focused($focusedField, equals: .durationSeconds(self.set.id))
                Text("sec").foregroundStyle(.secondary)
            }

            if machine.supportsDistance {
                HStack(spacing: 4) {
                    Text("Distance")
                    Spacer(minLength: 0)
                    TextField("0", value: distanceBinding, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .focused($focusedField, equals: .distance(self.set.id))
                    Text(unit.abbreviation).foregroundStyle(.secondary)
                }
                .padding(.leading, 22)
            }

            HStack(spacing: 6) {
                if let pace = CardioFormat.pace(machine: machine, seconds: seconds,
                                                meters: self.set.distanceMeters, unit: unit) {
                    Text(pace).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                caloriesLabel
            }
            .font(.footnote)
            // Line up under the first line's label rather than under its mark.
            .padding(.leading, 22)
        }
        .completedSetStyling(isCompleted: isCompleted, accent: accent)
        .accessibilityElement(children: .contain)
        .accessibilityValue(completionAccessibilityValue(isCompleted: isCompleted, isMissed: isMissed))
        // Claude  Date 09/07/2026
        // Re-clamp on BLUR, not on every keystroke. Clamping distance while the duration is
        // half-typed ("3" of "30") would eat a legitimate distance, and typing the distance
        // first and the time second is the order the in-setter clamp below can't catch.
        .onChange(of: focusedField) { field in
            guard field?.setID != self.set.id else { return }
            clampDistance()
        }
    }

    // Claude  Date 09/07/2026
    // The calorie slot, which is never allowed to show a number it can't stand behind:
    // an estimate when there's a bodyweight and the bout is plausible (CardioPolicy.calories
    // returns nil otherwise), and the one-tap prompt to add a weight when that's what's
    // missing. An implausible bout shows neither — its Section footer explains why.
    @ViewBuilder
    private var caloriesLabel: some View {
        if let kcal = CardioPolicy.calories(machine: machine, seconds: seconds,
                                            meters: self.set.distanceMeters,
                                            bodyweightLb: bodyweightLb) {
            Text(CardioFormat.calories(kcal))
                .foregroundStyle(.secondary)
        } else if bodyweightLb == nil, seconds > 0 {
            Button(action: onMissingBodyweight) {
                Text("Add your weight for calories")
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bindings

    private var minutesBinding: Binding<Int> {
        Binding(get: { seconds / 60 },
                set: { setDuration($0 * 60 + seconds % 60) })
    }

    /// Not clamped to 0–59 on purpose: typing 90 here reads back as +1 min 30 sec, which is
    /// what someone entering "1:90" from a machine display means.
    private var secondsBinding: Binding<Int> {
        Binding(get: { seconds % 60 },
                set: { setDuration((seconds / 60) * 60 + $0) })
    }

    /// Edited in the user's unit, stored in meters. 0 reads back as "no distance logged".
    private var distanceBinding: Binding<Double> {
        Binding(get: { unit.fromMeters(self.set.distanceMeters ?? 0) },
                set: { newValue in
                    let meters = unit.toMeters(Swift.max(0, newValue))
                    self.set.distanceMeters = meters > 0 ? meters : nil
                    clampDistance()
                })
    }

    private func setDuration(_ value: Int) {
        self.set.durationSeconds = Swift.min(Swift.max(0, value), CardioPolicy.hardMaxSeconds)
    }

    // Claude  Date 09/07/2026
    // The hard ceiling, applied as a clamp. A bout has no Save button — every keystroke
    // persists straight through the workout binding — so refusing an impossible distance
    // means bounding it, the same idiom adjustFocusedField uses to clamp reps at 0.
    private func clampDistance() {
        guard let meters = self.set.distanceMeters, meters > 0,
              let ceiling = CardioPolicy.maxAllowedMeters(machine: machine, seconds: seconds),
              meters > ceiling else { return }
        self.set.distanceMeters = ceiling
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
