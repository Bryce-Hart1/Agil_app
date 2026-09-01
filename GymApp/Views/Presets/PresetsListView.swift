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
    // Claude  Date 08/25/2026
    // The preset a swipe asked to delete (nil = none), held while the confirmation is
    // up. Deleting a template is one tap away from a full-swipe and can't be undone,
    // so it now asks first — the same guard "Override Preset" has had all along.
    @State private var pendingDelete: WorkoutPreset?
    // Claude  Date 08/25/2026
    // The existing preset a "Blank Preset" tap would have duplicated (nil = none).
    // Tapping + twice makes a second identical, untouched "New Preset"; rather than
    // add it, we point at the one already sitting there and offer to open it.
    @State private var duplicateOfBlank: WorkoutPreset?
    // Claude  Date 08/25/2026
    // Which preset the editor currently has open, and the duplicate found when it
    // popped (nil = none). PresetEditorView writes live through its binding and only
    // checks on "Finish Preset", so backing out — chevron or swipe — used to leave a
    // twin saved with nothing said. Re-checking here catches every way out of the
    // editor, without taking the back gesture away from that screen.
    @State private var openPresetID: UUID?
    @State private var duplicateAfterEdit: DuplicateAfterEdit?

    // The preset just edited and the one it now matches. Two ids would do, but holding
    // the existing preset keeps its name in the message even if it's edited later.
    private struct DuplicateAfterEdit {
        let editedID: UUID
        let existing: WorkoutPreset
    }

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
                                pendingDelete = preset
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
            .modeNotchToolbar(tab: AgilTabItem.build.tag)
            .navigationDestination(for: UUID.self) { id in
                PresetEditorView(presetID: id)
            }
            // Claude  Date 08/25/2026
            // The stack is one level deep (list → editor), so a non-empty path means the
            // editor is open and an empty one means it just closed. On close, re-check the
            // preset that was open.
            .onChange(of: path) { newPath in
                if let id = newPath.last {
                    openPresetID = id
                } else if let id = openPresetID {
                    openPresetID = nil
                    recheckAfterEditing(id)
                }
            }
            .sheet(isPresented: $showingPremade) {
                NavigationStack {
                    PremadeWorkoutsView(isModal: true)
                }
            }
            // Claude  Date 08/25/2026
            // Delete confirmation. `presenting` keeps the preset's name in the message
            // so there's no doubt which row the swipe caught, and the destructive role
            // puts Delete in red with Cancel as the default.
            .alert("Delete Preset?", isPresented: deleteConfirmationBinding,
                   presenting: pendingDelete) { preset in
                Button("Delete", role: .destructive) {
                    store.deletePreset(id: preset.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: { preset in
                Text("“\(preset.name.isEmpty ? "Untitled Preset" : preset.name)” will be removed. Workouts you've already logged from it are kept. This can't be undone.")
            }
            // Claude  Date 08/25/2026
            // The blank-preset duplicate. "Open" navigates to the existing one, which is
            // what the user was reaching for anyway — an empty preset to fill in.
            .alert("Preset Already Exists", isPresented: duplicateAlertBinding,
                   presenting: duplicateOfBlank) { existing in
                Button("Open") { path.append(existing.id) }
                Button("Cancel", role: .cancel) {}
            } message: { existing in
                Text("You already have an identical preset, “\(existing.name.isEmpty ? "Untitled Preset" : existing.name)”. Open that one instead of making a second copy.")
            }
            // Claude  Date 08/25/2026
            // Same two ways out the editor's own alert offers, so leaving by the back
            // chevron lands you in the same place as tapping "Finish Preset": throw the
            // copy away, or go back in and change something.
            .alert("Preset Already Exists", isPresented: duplicateAfterEditBinding,
                   presenting: duplicateAfterEdit) { info in
                Button("Delete This Copy", role: .destructive) {
                    store.deletePreset(id: info.editedID)
                }
                Button("Keep Editing", role: .cancel) {
                    path.append(info.editedID)
                }
            } message: { info in
                let name = info.existing.name.isEmpty ? "Untitled Preset" : info.existing.name
                Text("This is now identical to “\(name)” — same name, exercises, and plan. Change something to keep both, or delete this copy.")
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
                    // Claude  Date 07/25/2026 last changed: 07/28/2026 by: Claude
                    // Two ways to get a preset: a blank one to fill in, or one lifted
                    // from the shipped catalog. Blank Preset is the old + button's
                    // behavior, unchanged. (This used to mirror the Workouts tab's +
                    // menu; that tab now splits its two paths into a pair of nav-bar
                    // buttons instead, so the shapes no longer match.)
                    Menu {
                        Button {
                            addBlankPreset()
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

    // Claude  Date 08/25/2026
    // Create-and-open a blank preset, unless an identical one is already saved — in
    // which case the alert offers to open that one instead. The check runs against the
    // preset that WOULD be added, so it stays honest if the blank's defaults change.
    private func addBlankPreset() {
        let preset = WorkoutPreset(name: "New Preset")
        if let existing = store.duplicatePreset(of: preset) {
            duplicateOfBlank = existing
            return
        }
        store.addPreset(preset)
        path.append(preset.id)
    }

    // Claude  Date 08/25/2026
    // `.alert(_:isPresented:presenting:)` needs a Bool binding alongside the item it
    // presents; these bridge the optional state to one, and clear it on dismiss so the
    // same row can be swiped again.
    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private var duplicateAlertBinding: Binding<Bool> {
        Binding(get: { duplicateOfBlank != nil }, set: { if !$0 { duplicateOfBlank = nil } })
    }

    private var duplicateAfterEditBinding: Binding<Bool> {
        Binding(get: { duplicateAfterEdit != nil }, set: { if !$0 { duplicateAfterEdit = nil } })
    }

    // Claude  Date 08/25/2026
    // Did editing turn this preset into a copy of another? Silent when the preset is
    // gone (deleted from inside the editor) or when nothing matches — this only ever
    // speaks up to report a duplicate.
    //
    // Deferred a turn on purpose. The editor's own "Delete This Copy" dismisses and THEN
    // deletes on the next main-queue hop (it has to: deleting first invalidates the
    // binding the editor is built on). Checking synchronously here would race that hop,
    // find the preset still present, and pop this alert about a preset the user just
    // agreed to throw away. Enqueuing after lets the delete land first, and the guard
    // then finds nothing.
    private func recheckAfterEditing(_ id: UUID) {
        DispatchQueue.main.async {
            guard let edited = store.preset(for: id),
                  let existing = store.duplicatePreset(of: edited) else { return }
            duplicateAfterEdit = DuplicateAfterEdit(editedID: id, existing: existing)
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
