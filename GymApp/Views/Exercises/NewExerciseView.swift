import SwiftUI

// Claude  Date 06/09/2026 last changed: 07/09/2026 by: Claude
// A form sheet for creating OR editing an exercise: name, region, muscle group, primary
// mover, and the unilateral toggle. Shared by the Exercises tab (+), the workout
// exercise picker ("Create New"), and the pencil in the workout editor's exercise
// header. Pass `editing:` to edit an existing exercise in place (its liftType/quality
// are preserved); otherwise it creates one. Calls `onCreate` with the saved exercise.
//
// The three muscle fields cascade, each sourced from the existing library so they can't
// drift: Region → Muscle group (a picker of that region's sub-groups) → Primary mover
// (auto-set + hidden when a group has a single mover, a picker when it has several, and
// free-text when the group is new/unknown). Region = Other is the one place free-text
// muscle entry lives, so you never pick "Other" twice.
struct NewExerciseView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    /// Pre-fills the name field (e.g. from the picker's search text).
    let initialName: String
    /// The existing exercise being edited, or nil to create a new one.
    let editing: Exercise?
    /// Called with the saved (created or updated) exercise after saving.
    let onCreate: (Exercise) -> Void

    @State private var name: String
    // Claude  Date 06/14/2026 last changed: 06/18/2026 by: Claude
    // Body region (primary grouping). Initialized in init — from the edited exercise,
    // or Other for a new one so a quick custom add isn't forced to classify.
    @State private var region: MuscleRegion
    @State private var category: String
    // Claude  Date 06/14/2026
    // The muscle this lift primarily drives — mirrors the curated library's primaryMover.
    @State private var primaryMover: String
    @State private var isUnilateral: Bool
    @State private var showingMoverHelp = false

    // Claude  Date 07/09/2026
    // Whether the muscle group / primary mover are a typed custom value rather than a
    // picked library option, and a one-shot flag to reconcile these against the library on
    // first appear (store isn't available in init).
    @State private var categoryIsCustom = false
    @State private var moverIsCustom = false
    @State private var primed = false

    // Picker tag standing in for the "Custom…" row; the actual typed value lives in
    // `category` / `primaryMover` while the matching *IsCustom flag is set.
    private let customTag = "__custom__"

    init(initialName: String = "", editing: Exercise? = nil,
         onCreate: @escaping (Exercise) -> Void = { _ in }) {
        self.initialName = initialName
        self.editing = editing
        self.onCreate = onCreate
        _name = State(initialValue: editing?.name ?? initialName)
        _region = State(initialValue: editing?.region ?? .other)
        _category = State(initialValue: editing?.category ?? "")
        _primaryMover = State(initialValue: editing?.primaryMover ?? "")
        _isUnilateral = State(initialValue: editing?.isUnilateral ?? false)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    // MARK: - Cascading options (all derived from the library)

    // Muscle sub-groups for the current region, keeping an edited exercise's own category
    // selectable even if it's a one-off not otherwise in the library.
    private var categoryOptions: [String] {
        var opts = store.categories(in: region)
        if let existing = editing, existing.region == region,
           existing.category != "Other", !opts.contains(existing.category) {
            opts.insert(existing.category, at: 0)
        }
        return opts
    }

    // Known primary movers for the chosen group (empty for a custom/unknown group), again
    // keeping an edited exercise's own mover selectable.
    private var moverOptions: [String] {
        guard region != .other, !categoryIsCustom else { return [] }
        var opts = store.movers(in: category, region: region)
        if let existing = editing, existing.category == category,
           !existing.primaryMover.isEmpty, !opts.contains(existing.primaryMover) {
            opts.insert(existing.primaryMover, at: 0)
        }
        return opts
    }

    // Free-text mover entry: Region = Other, a custom group, or a group with no known
    // movers. Otherwise the mover is a picker (2+) or auto-assigned + hidden (exactly 1).
    private var showsMoverFreeText: Bool {
        region == .other || categoryIsCustom || moverOptions.isEmpty
    }

    // Canonical movers matching what's typed (case-insensitive), for the free-text path.
    private var moverSuggestions: [String] {
        let q = primaryMover.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let matches = Exercise.commonPrimaryMovers.filter { $0.lowercased().contains(q) }
        if matches.count == 1 && matches[0].lowercased() == q { return [] }
        return Array(matches.prefix(6))
    }

    // MARK: - Picker bindings (map the "Custom…" sentinel to the *IsCustom flags)

    private var categorySelection: Binding<String> {
        Binding(
            get: {
                if categoryIsCustom { return customTag }
                return categoryOptions.contains(category) ? category : (categoryOptions.first ?? customTag)
            },
            set: { newValue in
                if newValue == customTag {
                    categoryIsCustom = true
                    category = ""
                    primaryMover = ""
                    moverIsCustom = false
                } else {
                    categoryIsCustom = false
                    category = newValue
                    autofillMover()
                }
            })
    }

    private var moverSelection: Binding<String> {
        Binding(
            get: {
                if moverIsCustom { return customTag }
                return moverOptions.contains(primaryMover) ? primaryMover : (moverOptions.first ?? customTag)
            },
            set: { newValue in
                if newValue == customTag {
                    moverIsCustom = true
                    primaryMover = ""
                } else {
                    moverIsCustom = false
                    primaryMover = newValue
                }
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                    Picker("Region", selection: $region) {
                        ForEach(MuscleRegion.allCases, id: \.self) { region in
                            Text(region.title).tag(region)
                        }
                    }
                    // Region = Other: free-text group (the sole "uncategorized" path).
                    // Any real region: a picker of that region's sub-groups + Custom…
                    if region == .other {
                        TextField("Muscle group (e.g. Quads, Chest, Biceps)", text: $category)
                    } else {
                        Picker("Muscle group", selection: categorySelection) {
                            ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                            Text("Custom…").tag(customTag)
                        }
                        if categoryIsCustom {
                            TextField("New muscle group", text: $category)
                        }
                    }
                }

                moverSection

                Section {
                    Toggle("Unilateral", isOn: $isUnilateral)
                } footer: {
                    Text("Turn on for movements done one side at a time (e.g. single-arm row, lunges) so they can be tracked separately on graphs. Leave off for two-sided lifts like bench press.")
                }
            }
            .navigationTitle(editing == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty)
                }
            }
            .onChange(of: region) { newRegion in
                guard newRegion != .other else {
                    categoryIsCustom = false
                    moverIsCustom = false
                    return
                }
                // Autofill a sub-group for the new region (unless the current one already
                // fits, e.g. mid-edit), then cascade the mover.
                if !categoryOptions.contains(category) {
                    categoryIsCustom = false
                    category = categoryOptions.first ?? newRegion.title
                }
                autofillMover()
            }
            .onAppear(perform: primeCustomFlags)
            .alert("Primary mover", isPresented: $showingMoverHelp) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("The primary mover is the main muscle a lift drives — e.g. Quadriceps for a squat, or Latissimus Dorsi for a lat pulldown. It's shown under each exercise in your library. It's optional: leave it blank if you're unsure, or start typing to pick a muscle from the suggestions.")
            }
        }
    }

    // Claude  Date 07/09/2026
    // Primary mover, cascaded from the muscle group: free-text (with canonical
    // suggestions) when the group is unknown, a picker when the group works several
    // muscles, or read-only auto-assigned when there's only one.
    @ViewBuilder private var moverSection: some View {
        Section {
            if showsMoverFreeText {
                HStack {
                    TextField("Primary mover (optional)", text: $primaryMover)
                    Button {
                        showingMoverHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("What is a primary mover?")
                }
                ForEach(moverSuggestions, id: \.self) { suggestion in
                    Button {
                        primaryMover = suggestion
                    } label: {
                        Label(suggestion, systemImage: "arrow.up.left.circle")
                            .font(.subheadline)
                    }
                }
            } else if moverOptions.count >= 2 {
                Picker("Primary mover", selection: moverSelection) {
                    ForEach(moverOptions, id: \.self) { Text($0).tag($0) }
                    Text("Custom…").tag(customTag)
                }
                if moverIsCustom {
                    TextField("New primary mover", text: $primaryMover)
                }
            } else {
                // Exactly one known mover for this group — assigned automatically.
                LabeledContent("Primary mover", value: primaryMover)
            }
        } header: {
            Text("Primary mover")
        } footer: {
            Text(moverFooter)
        }
    }

    private var moverFooter: String {
        if showsMoverFreeText {
            return "The main muscle this lift drives. Optional — leave blank if you're not sure."
        } else if moverOptions.count >= 2 {
            return "This muscle group works more than one muscle — pick the one this lift emphasizes."
        } else {
            return "Set automatically from the muscle group."
        }
    }

    // Set primaryMover to the group's first known mover (or clear it if the group has
    // none). Called when the group changes via the picker or a region switch.
    private func autofillMover() {
        moverIsCustom = false
        primaryMover = store.movers(in: category, region: region).first ?? ""
    }

    // Reconcile the custom flags against the library once, on first appear (store isn't
    // available in init). A new exercise starts at Region = Other → nothing to reconcile.
    private func primeCustomFlags() {
        guard !primed else { return }
        primed = true
        guard region != .other else { return }
        categoryIsCustom = !store.categories(in: region).contains(category)
        if !categoryIsCustom {
            let opts = store.movers(in: category, region: region)
            moverIsCustom = !opts.isEmpty && !primaryMover.isEmpty && !opts.contains(primaryMover)
        }
    }

    private func save() {
        // Resolve the muscle group: Region = Other keeps the free-text "Other" fallback;
        // a real region is always a real sub-group (custom-but-blank falls back to a known
        // one), never "Other".
        let resolvedCategory: String
        if region == .other {
            let t = category.trimmingCharacters(in: .whitespaces)
            resolvedCategory = t.isEmpty ? "Other" : t
        } else if categoryIsCustom {
            let t = category.trimmingCharacters(in: .whitespaces)
            resolvedCategory = t.isEmpty ? (store.categories(in: region).first ?? region.title) : t
        } else {
            resolvedCategory = category
        }

        // Free-typed movers get snapped to canonical spelling; picked/auto ones are already canonical.
        let resolvedMover = (showsMoverFreeText || moverIsCustom)
            ? Exercise.normalizedPrimaryMover(primaryMover)
            : primaryMover

        let saved: Exercise
        if var existing = editing {
            // Edit in place — preserve id, liftType, and quality (not shown in this form).
            existing.name = trimmedName
            existing.region = region
            existing.category = resolvedCategory
            existing.isUnilateral = isUnilateral
            existing.primaryMover = resolvedMover
            store.updateExercise(existing)
            saved = existing
        } else {
            // Create — no liftType is passed; custom lifts are never big-3 (stays nil).
            saved = store.addExercise(
                name: trimmedName,
                region: region,
                category: resolvedCategory,
                isUnilateral: isUnilateral,
                primaryMover: resolvedMover
            )
        }
        onCreate(saved)
        dismiss()
    }
}

#Preview {
    NewExerciseView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
