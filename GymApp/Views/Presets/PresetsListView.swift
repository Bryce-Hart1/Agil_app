import SwiftUI

/// Lists workout presets (reusable templates). Tap to edit; + creates a new one
/// and opens it; swipe to delete.
struct PresetsListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var path: [UUID] = []
    // Claude  Date 07/25/2026
    // Drives the premade-workout browser raised from the + menu. A sheet rather than a
    // push because `path` is typed to preset ids; the empty state, which isn't inside a
    // Menu, uses a plain NavigationLink instead.
    @State private var showingPremade = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.presets.isEmpty {
                    // Claude  Date 07/25/2026 last changed: 07/25/2026 by: Claude
                    // The empty state now offers a way out instead of just describing
                    // one: browse the shipped templates, or build a blank preset from
                    // the + menu. (Was a lone line of explanatory text.)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No presets yet. Start from a premade workout, or tap + to build a reusable template of your own.")
                            .foregroundStyle(.secondary)
                            .supportingTextFont()
                        NavigationLink {
                            PremadeWorkoutsView()
                        } label: {
                            Label("Browse Premade Workouts", systemImage: "square.stack")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 4)
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
            .sheet(isPresented: $showingPremade) {
                NavigationStack {
                    PremadeWorkoutsView(isModal: true)
                }
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
                    // Claude  Date 07/25/2026
                    // Two ways to get a preset, mirroring the Workouts tab's + menu:
                    // a blank one to fill in, or one lifted from the shipped catalog.
                    // Blank Preset is the old + button's behavior, unchanged.
                    Menu {
                        Button {
                            let preset = WorkoutPreset(name: "New Preset")
                            store.addPreset(preset)
                            path.append(preset.id)
                        } label: {
                            Label("Blank Preset", systemImage: "square.and.pencil")
                        }
                        Button {
                            showingPremade = true
                        } label: {
                            Label("Browse Premade", systemImage: "square.stack")
                        }
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
                    .supportingTextFont()
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
