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
    @Binding var preset: WorkoutPreset
    @State private var showingExercisePicker = false

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
        }
        .navigationTitle(preset.name.isEmpty ? "Preset" : preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .toolbar {
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
                Image(systemName: name)
                    .font(.title2)
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
