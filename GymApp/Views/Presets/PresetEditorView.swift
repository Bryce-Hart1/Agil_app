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
    // Claude  Date 07/09/2026
    // The library exercise being edited from a section's pencil (nil = none) — same
    // in-place edit affordance the workout editor has.
    @State private var editingExercise: Exercise?
    // Claude  Date 07/19/2026
    // The preset item whose "Swap" button was tapped (nil = none). Held at the editor
    // level rather than per-row because the rows are built inline in this Form's body
    // and so can't own @State of their own.
    @State private var swappingItemID: UUID?

    var body: some View {
        Form {
            Section("Name") {
                TextField("Preset name", text: $preset.name)
            }

            Section("Icon") {
                IconGrid(selected: $preset.symbolName, accent: theme.current.accent)
            }

            // Claude  Date 07/01/2026
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
                if preset.isAdaptive {
                    Text("Hit the top of the rep range and the weight goes up next time; miss the bottom twice and it eases off.")
                }
            }

            ForEach($preset.items) { $item in
                Section {
                    RepRangeRow(targetRepRange: $item.targetRepRange)
                    // Claude  Date 07/13/2026
                    // Planned set count, picked up front. Starting a workout from this
                    // preset pre-fills this many empty sets (see AppStore.workout(from:)).
                    // "None" clears it so no sets are pre-filled for this exercise.
                    Picker(selection: $item.targetSets) {
                        Text("None").tag(Int?.none)
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
                    TextField("Note (form cues…)",
                              text: Binding($item.note, replacingNilWith: ""),
                              axis: .vertical)
                        .lineLimit(1...4)
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
                        preset.items.removeAll { $0.id == item.id }
                    }
                } header: {
                    HStack {
                        Text(store.exercise(for: item.exerciseId)?.name ?? "Exercise")
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
                            .accessibilityLabel("Edit \(exercise.name)")
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { exercise in
                // New preset items default to an 8–12 range since rep targets are
                // the whole point of a preset; it can be cleared or changed.
                // Claude  Date 07/13/2026
                // Also default to 3 planned sets so the preset pre-fills sets out of the
                // box (the picker's "None" clears it). See PresetItem.defaultTargetSets.
                preset.items.append(
                    PresetItem(exerciseId: exercise.id, targetRepRange: RepRange(min: 8, max: 12),
                               targetSets: PresetItem.defaultTargetSets)
                )
            }
        }
        // Claude  Date 07/19/2026
        // Swap picker for the item whose "Swap" button was tapped — replaces that item's
        // lift in place (see the ExerciseActionsRow above for what carries over).
        .sheet(isPresented: Binding(get: { swappingItemID != nil },
                                    set: { if !$0 { swappingItemID = nil } })) {
            ExercisePickerView { exercise in
                guard let id = swappingItemID,
                      let index = preset.items.firstIndex(where: { $0.id == id }) else { return }
                preset.items[index].exerciseId = exercise.id
                preset.items[index].note = nil
                preset.items[index].weightIncrement = nil
                swappingItemID = nil
            }
        }
        .sheet(isPresented: $showingReorder) {
            ReorderExercisesSheet(title: "Reorder", items: $preset.items) {
                store.exercise(for: $0.exerciseId)?.name ?? "Exercise"
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

            Hit the top of the rep range on every working set, and the weight goes up next time. Fall below the bottom two sessions in a row, and it eases back down. The jump defaults to 5 lb (10 lb for legs and deadlifts) and can be set per exercise. Suggestions are always editable.
            """)
        }
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

/// A grid of selectable SF Symbol icons for the preset.
private struct IconGrid: View {
    @Binding var selected: String
    let accent: Color

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PresetIcons.all, id: \.self) { name in
                PresetIconView(name: name, size: 26)
                    .frame(width: 48, height: 48)
                    .foregroundStyle(selected == name ? accent : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selected == name ? accent.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected == name ? accent : Color.gray.opacity(0.25),
                                    lineWidth: selected == name ? 2 : 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { selected = name }
                    .accessibilityLabel(name)
            }
        }
        .padding(.vertical, 4)
    }
}

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
