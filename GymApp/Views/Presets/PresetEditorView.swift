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

    var body: some View {
        Form {
            Section("Name") {
                TextField("Preset name", text: $preset.name)
            }

            Section("Icon") {
                IconGrid(selected: $preset.symbolName, accent: theme.current.accent)
            }

            ForEach($preset.items) { $item in
                Section {
                    RepRangeRow(targetRepRange: $item.targetRepRange)
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
                    Button(role: .destructive) {
                        preset.items.removeAll { $0.id == item.id }
                    } label: {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } header: {
                    Text(store.exercise(for: item.exerciseId)?.name ?? "Exercise")
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
                preset.items.append(
                    PresetItem(exerciseId: exercise.id, targetRepRange: RepRange(min: 8, max: 12))
                )
            }
        }
        .sheet(isPresented: $showingReorder) {
            ReorderExercisesSheet(title: "Reorder", items: $preset.items) {
                store.exercise(for: $0.exerciseId)?.name ?? "Exercise"
            }
        }
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
