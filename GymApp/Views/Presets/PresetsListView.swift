import SwiftUI

/// Lists workout presets (reusable templates). Tap to edit; + creates a new one
/// and opens it; swipe to delete.
struct PresetsListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.presets.isEmpty {
                    Text("No presets yet. Tap + to create a reusable workout template, then start workouts from it.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.presets) { preset in
                        NavigationLink(value: preset.id) {
                            PresetRow(preset: preset, accent: theme.current.accent)
                        }
                        // Claude  Date 07/13/2026
                        // Swipe left to Edit (opens the preset editor, same as tapping) or
                        // Delete. Explicit swipeActions replace the old .onDelete so both
                        // live on the same trailing swipe; Delete stays the full-swipe action.
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deletePreset(id: preset.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                path.append(preset.id)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(theme.current.accent)
                        }
                    }
                }
            }
            .navigationTitle("Presets")
            .themed(theme.current)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            .modeNotchToolbar()
            .navigationDestination(for: UUID.self) { id in
                PresetEditorView(presetID: id)
            }
            .toolbar {
                // Claude  Date 06/16/2026
                // Exercises moved off the tab bar (freeing a slot for the eventual
                // nutrition tab) to a top-left link here, since the exercise library
                // is a building block alongside presets.
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ExercisesListView()
                    } label: {
                        // Show the text too — an icon alone here reads as unclear to
                        // a new user.
                        Label("Exercises", systemImage: "list.bullet")
                            .labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let preset = WorkoutPreset(name: "New Preset")
                        store.addPreset(preset)
                        path.append(preset.id)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

private struct PresetRow: View {
    @EnvironmentObject private var store: AppStore
    let preset: WorkoutPreset
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            PresetIconView(name: preset.symbolName, size: 24)
                .foregroundStyle(accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name.isEmpty ? "Untitled Preset" : preset.name)
                    .font(.headline)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summary: String {
        let count = preset.items.count
        if count == 0 { return "No exercises yet" }
        let names = preset.items.prefix(3).compactMap { store.exercise(for: $0.exerciseId)?.name }
        let suffix = count > 3 ? " +\(count - 3) more" : ""
        return names.joined(separator: ", ") + suffix
    }
}

#Preview {
    PresetsListView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
