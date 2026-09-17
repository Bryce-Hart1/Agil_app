import SwiftUI

/// Resolves a preset by id into a stable binding and hands it to the editor.
struct PresetEditorView: View {
    @EnvironmentObject private var store: AppStore
    let presetID: UUID

    var body: some View {
        if let binding = store.presetBinding(for: presetID) {
            PresetEditor(preset: binding)
        } else {
            Text("This preset no longer exists.")
                .foregroundStyle(.secondary)
        }
    }
}

/// Edits a preset: name, icon, and the exercises (each with a target rep range).
private struct PresetEditor: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Binding var preset: WorkoutPreset
    @State private var showingExercisePicker = false
    @State private var showingReorder = false
    // Claude  Date 07/01/2026
    // Drives the "?" explainer alert for the adaptive-progression toggle.
    @State private var showingAdaptiveHelp = false
    // Claude  Date 08/25/2026
    // The other saved preset this one has become identical to (nil = none), found when
    // "Finish Preset" is tapped. Both ways out are offered — keep editing, or throw this
    // copy away — because the editor saves live, so refusing to let the user leave would
    // trap them on this screen.
    @State private var duplicate: WorkoutPreset?
    // Claude  Date 07/09/2026
    // The library exercise being edited from a section's pencil (nil = none) — same
    // in-place edit affordance the workout editor has.
    @State private var editingExercise: Exercise?
    // Claude  Date 07/19/2026
    // The preset item whose "Swap" button was tapped (nil = none). Held at the editor
    // level rather than per-row because the rows are built inline in this Form's body
    // and so can't own @State of their own.
    @State private var swappingItemID: UUID?
    // CLAUDE  Date 09/17/2026
    // The rep-range bound that has the keyboard (nil = none, or the name/notes field), as
    // reported by each RepRangeRow. Drives the same keyboard bar the workout editor uses.
    @State private var repRangeFocus: SetEntryField?

    /// The lift currently being swapped out, if any — what the picker ranks against.
    private var swappingExercise: Exercise? {
        guard let id = swappingItemID,
              let item = preset.items.first(where: { $0.id == id }) else { return nil }
        return store.exercise(for: item.exerciseId)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Preset name", text: $preset.name)
            }

            Section("Icon") {
                IconGrid(selected: $preset.symbolName, accent: theme.current.accent)
            }

            // Claude  Date 08/04/2026
            // Notes for the template as a whole — standing instructions that apply
            // every time it's run ("warm up on the bar", "superset 2 and 3"). Copied
            // onto each workout started from this preset, and overwritten by that
            // workout's notes if it's later saved back over this template. Sits with
            // Name and Icon because, like them, it describes the preset itself rather
            // than any one lift in it.
            Section("Notes") {
                TextField("Notes for this preset",
                          text: Binding($preset.notes, replacingNilWith: ""),
                          axis: .vertical)
                    .lineLimit(1...5)
            }

            // Bryce Hart Jul 25 26
            // Adaptive-progression toggle for the whole preset, with a "?" explainer
            // (mirrors the info-button pattern in NewExerciseView). When on, each
            // exercise below gains a weight-step picker, and workouts started from this
            // preset arrive with history-based weight suggestions (see AppStore).
            Section {
                Toggle(isOn: $preset.isAdaptive) {
                    HStack(spacing: 6) {
                        Text("Adaptive progression")
                        Button {
                            showingAdaptiveHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("What is adaptive progression?")
                    }
                }
            } footer: {
                
            }

            ForEach($preset.items) { $item in
                Section {
                    RepRangeRow(targetRepRange: $item.targetRepRange) { bound in
                        switch bound {
                        case .min: repRangeFocus = .repRangeMin(item.id)
                        case .max: repRangeFocus = .repRangeMax(item.id)
                        case nil:
                            // Only clear if focus didn't already move to another row.
                            if repRangeFocus?.setID == item.id { repRangeFocus = nil }
                        }
                    }
                    // Claude  Date 07/13/2026 last changed: 08/07/2026 by: Claude
                    // Planned set count, picked up front. Starting a workout from this
                    // preset pre-fills this many empty sets (see AppStore.workout(from:)).
                    // (08/07) "Don't specify" is the default and the first option — plenty
                    // of training doesn't commit to a set count in advance, and guessing
                    // three on the user's behalf put a number in the plan they never chose.
                    // Choosing it pre-fills nothing and you add sets as you do them.
                    Picker(selection: $item.targetSets) {
                        Text("Don't specify").tag(Int?.none)
                        ForEach(1...8, id: \.self) { count in
                            Text("\(count)").tag(Int?.some(count))
                        }
                    } label: {
                        Label("Sets", systemImage: "number")
                    }
                    // Claude  Date 07/16/2026
                    // retintOnThemeChange (here + the two pickers below): menu pickers
                    // resolve their tint once, at creation — rebuild them on theme swap
                    // so the value labels pick up the new accent instead of keeping the
                    // old theme's color.
                    .retintOnThemeChange(theme.current, salt: "sets-\(item.id)")
                    // Claude  Date 08/04/2026 last changed: 08/11/2026 by: Claude
                    // The perma note on the lift itself — edited here, it changes
                    // everywhere that lift appears. Shared with the workout editor so
                    // the row looks identical in both.
                    // (08/07) The session row is off here: you're designing a template,
                    // not living a session. (08/11) It's now a note to your NEXT session,
                    // which only exists once you're actually running the preset — so it's
                    // authored from the workout, never from here. Preset-wide standing
                    // instructions go in the Notes section at the top of this form.
                    ExerciseNoteFields(exerciseId: item.exerciseId,
                                       sessionNote: .constant(nil),
                                       accent: theme.current.accent,
                                       showsSessionNote: false)
                    // Claude  Date 06/12/2026
                    // Rest duration carried into workouts started from this preset.
                    Picker(selection: $item.restSeconds) {
                        Text("None").tag(Int?.none)
                        ForEach(RestDuration.options, id: \.self) { seconds in
                            Text(RestDuration.label(seconds)).tag(Int?.some(seconds))
                        }
                    } label: {
                        Label("Rest timer", systemImage: "timer")
                    }
                    .retintOnThemeChange(theme.current, salt: "rest-\(item.id)")
                    // Claude  Date 07/01/2026
                    // Adaptive only: per-exercise weight-step override. "Default" uses the
                    // smart increment (10 lb for legs/deadlift, else 5 lb) and clears the
                    // override; the numbered options pin an explicit jump.
                    if preset.isAdaptive {
                        Picker(selection: $item.weightIncrement) {
                            Text("Default (\(incrementLabel(store.smartIncrement(for: item.exerciseId))))")
                                .tag(Double?.none)
                            ForEach([2.5, 5, 10, 15], id: \.self) { step in
                                Text(incrementLabel(step)).tag(Double?.some(step))
                            }
                        } label: {
                            Label("Weight step", systemImage: "plus.forwardslash.minus")
                        }
                        .retintOnThemeChange(theme.current, salt: "step-\(item.id)")
                    }
                    // Claude  Date 07/19/2026
                    // Swap beside Remove (see ExerciseActionsRow). Swap points this item
                    // at a different lift while keeping its slot and its planning — rep
                    // range, set count and rest all carry over, since they describe the
                    // preset's structure. The note (form cues) and the adaptive weight-step
                    // override are lift-specific, so they're cleared.
                    ExerciseActionsRow {
                        swappingItemID = item.id
                    } onRemove: {
                        // Claude  Date 08/07/2026 — animated so the section visibly
                        // collapses out; a Remove that just blinked the row away read
                        // as "did that work?". Same curve as the workout editor.
                        withAnimation(.easeInOut(duration: 0.25)) {
                            preset.items.removeAll { $0.id == item.id }
                        }
                    }
                } header: {
                    HStack {
                        // Claude  Date 08/18/2026
                        // displayLabel + nameplate, matching the workout editor: a preset
                        // built on a specific branded machine has to say which one.
                        Text(store.exercise(for: item.exerciseId)?.displayLabel ?? "Exercise")
                        EquipmentBadge(type: store.exercise(for: item.exerciseId)?.equipmentType)
                        // Claude  Date 07/09/2026
                        // Pencil → edit the underlying library exercise's details in place
                        // while designing the preset, exactly like the workout editor.
                        // Saving updates the shared library, so every preset/workout using
                        // it relabels.
                        if let exercise = store.exercise(for: item.exerciseId) {
                            Button {
                                editingExercise = exercise
                            } label: {
                                Image(systemName: "pencil")
                                    .fontWeight(.bold)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.current.accent)
                            .accessibilityLabel("Edit \(exercise.displayLabel)")
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

            // Claude  Date 06/18/2026
            // Done button at the bottom. The preset saves live through its binding, so
            // this is purely navigation — it pops back to the presets list (mirrors the
            // workout editor's "Finish Edit").
            Section {
                Button {
                    hideKeyboard()
                    // Claude  Date 08/25/2026
                    // The editor writes live through its binding, so this is the only
                    // commit point it has — check here whether editing has turned this
                    // preset into a copy of another one, and say so before it's left
                    // sitting in the list as a twin.
                    if let existing = store.duplicatePreset(of: preset) {
                        duplicate = existing
                        return
                    }
                    dismiss()
                } label: {
                    Text("Finish Preset")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(preset.name.isEmpty ? "Preset" : preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .toolbar {
            if preset.items.count > 1 {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingReorder = true
                    } label: {
                        Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
        }
        // CLAUDE  Date 09/17/2026
        // The workout editor's keyboard bar (Bryce, 9/17/26 — faster preset setup): ±1
        // steppers on a rep-range field, Done alone on the name and notes fields.
        .setEntryKeyboardBar(SetEntryAccessoryBar(field: repRangeFocus,
                                                  accent: theme.current.accent,
                                                  surface: theme.current.surface,
                                                  onAdjust: { adjustRepRange(by: $0) },
                                                  onDone: hideKeyboard))
        // CLAUDE  Date 09/17/2026 — as in the workout editor: tapping a rep field selects
        // its number, so typing replaces it instead of appending.
        .selectAllWhenEditingNumberFields()
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { exercise in
                // New preset items default to an 8–12 range since rep targets are
                // the whole point of a preset; it can be cleared or changed.
                // Claude  Date 07/13/2026 last changed: 08/07/2026 by: Claude
                // Sets start UNSPECIFIED (see PresetItem.defaultTargetSets) — the set
                // count is the one number a plan often shouldn't commit to up front.
                withAnimation(.easeInOut(duration: 0.25)) {
                    preset.items.append(
                        PresetItem(exerciseId: exercise.id, targetRepRange: RepRange(min: 8, max: 12),
                                   targetSets: PresetItem.defaultTargetSets)
                    )
                }
            }
        }
        // Claude  Date 07/19/2026
        // Swap picker for the item whose "Swap" button was tapped — replaces that item's
        // lift in place (see the ExerciseActionsRow above for what carries over).
        .sheet(isPresented: Binding(get: { swappingItemID != nil },
                                    set: { if !$0 { swappingItemID = nil } })) {
            // Claude  Date 08/16/2026
            // `relatedTo` floats plausible substitutes for the outgoing lift to the top
            // of the picker (see Exercise.related); a typed search cancels it.
            ExercisePickerView(relatedTo: swappingExercise) { exercise in
                guard let id = swappingItemID,
                      let index = preset.items.firstIndex(where: { $0.id == id }) else { return }
                // Claude  Date 08/04/2026 last changed: 08/11/2026 by: Claude
                // The weight-step override described the old lift, so it's cleared. The
                // perma note isn't touched: it lives on the Exercise and resolves by
                // exerciseId, so the row simply starts showing the new lift's.
                // (08/11) `note` is no longer cleared — it's a retired field nothing reads;
                // session notes live on workouts now (see PresetItem.note).
                preset.items[index].exerciseId = exercise.id
                preset.items[index].weightIncrement = nil
                swappingItemID = nil
            }
        }
        .sheet(isPresented: $showingReorder) {
            ReorderExercisesSheet(title: "Reorder", items: $preset.items) {
                store.exercise(for: $0.exerciseId)?.displayLabel ?? "Exercise"
            }
        }
        // Claude  Date 07/09/2026
        // Edit the tapped exercise's library details (name, region, mover, …). Saving
        // updates the shared library, so this preset and any workout using it relabel.
        .sheet(item: $editingExercise) { exercise in
            NewExerciseView(editing: exercise)
        }
        // Claude  Date 07/01/2026
        // Plain-language explainer for adaptive progression (double progression).
        .alert("Adaptive progression", isPresented: $showingAdaptiveHelp) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("""
            When this is on, each workout you start from this preset suggests a weight based on last time.
            Hit the top of the rep range on every working set, and the weight goes up next time. 
            Fall below the bottom two sessions in a row, and it eases back down. 
            The jump defaults to 5 lb (10 lb for anything legs, and deadlifts) and can be set per exercise. 
            Suggestions are always editable.
            """)
        }
        // Claude  Date 08/25/2026
        // This preset now matches another one exactly. "Delete This Copy" removes the one
        // being edited (never the original named in the message) and pops back; "Keep
        // Editing" returns to the form to change something — a rename is enough.
        .alert("Preset Already Exists", isPresented: duplicateAlertBinding,
               presenting: duplicate) { existing in
            Button("Delete This Copy", role: .destructive) {
                // Pop first, delete after: removing the preset invalidates the binding
                // this editor is built on, and PresetEditorView would flash its "no
                // longer exists" fallback on the way out.
                let id = preset.id
                dismiss()
                DispatchQueue.main.async { store.deletePreset(id: id) }
            }
            Button("Keep Editing", role: .cancel) {}
        } message: { existing in
            let name = existing.name.isEmpty ? "Untitled Preset" : existing.name
            Text("This is now identical to “\(name)” — same name, exercises, and plan. Change something to keep both, or delete this copy.")
        }
    }

    // Claude  Date 08/25/2026
    // Bool binding over `duplicate` for the alert above (the presenting overload needs
    // both); dismissing clears it so a later Finish can raise it again.
    private var duplicateAlertBinding: Binding<Bool> {
        Binding(get: { duplicate != nil }, set: { if !$0 { duplicate = nil } })
    }

    // CLAUDE  Date 09/17/2026
    // A keyboard-bar stepper on the focused rep-range bound. Held to 1...999 — the fields
    // take three digits, and a zero-rep target means nothing. RepRangeRow re-shows the value.
    private func adjustRepRange(by delta: Double) {
        guard let field = repRangeFocus,
              let index = preset.items.firstIndex(where: { $0.id == field.setID }),
              var range = preset.items[index].targetRepRange else { return }
        let step = Int(delta)
        switch field {
        case .repRangeMin: range.min = min(999, max(1, range.min + step))
        case .repRangeMax: range.max = min(999, max(1, range.max + step))
        default: return
        }
        preset.items[index].targetRepRange = range
    }

    // Claude  Date 07/01/2026
    // Format a weight step for the picker, dropping a trailing ".0" (5.0 → "5 lb",
    // 2.5 → "2.5 lb").
    private func incrementLabel(_ value: Double) -> String {
        let number = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(value)
        return "\(number) lb"
    }
}

// Claude  Date 07/25/2026
// IconGrid moved to Views/Components/IconGrid.swift — the premade-workout detail
// screen needs the same picker. The Section("Icon") call site above is unchanged.

#Preview {
    let store = AppStore()
    let preset = WorkoutPreset(name: "Push Day", symbolName: "figure.strengthtraining.traditional",
        items: [PresetItem(exerciseId: store.exercises[0].id,
        targetRepRange: RepRange(min: 8, max: 12))])
    store.addPreset(preset)
    return NavigationStack {
        PresetEditorView(presetID: preset.id)
            .environmentObject(store)
            .environmentObject(ThemeManager())
    }
}
