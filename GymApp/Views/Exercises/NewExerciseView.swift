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
    // Claude  Date 07/20/2026
    // Bodyweight lift flag (pull-up, dip…). When on, logged sets record ADDED weight
    // and the workout editor shows it as "+N lb" rather than a raw load.
    @State private var isBodyweight: Bool
    // Claude  Date 08/18/2026
    // How the lift is loaded — the nameplate, and the gate on whether the Brand field
    // below is offered at all (a barbell is a barbell whoever made it).
    @State private var equipmentType: EquipmentType?
    // Claude  Date 08/18/2026
    // The machine's manufacturer, e.g. "Hammer Strength". Blank = the generic lift.
    // Normalized against the library on save, so casing can't split one brand in two.
    @State private var brand: String
    // Claude  Date 09/07/2026
    // Which cardio machine this is, offered only when Region is Cardio and cleared when it
    // isn't — this sheet is the one place both fields can be set, so keeping them agreed
    // here is what stops a "cardio" lift that logs reps or a leg press that logs miles.
    @State private var cardioMachine: CardioMachine?
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
        _isBodyweight = State(initialValue: editing?.isBodyweight ?? false)
        _equipmentType = State(initialValue: editing?.equipmentType)
        _brand = State(initialValue: editing?.brand ?? "")
        _cardioMachine = State(initialValue: editing?.cardioMachine)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    // Claude  Date 08/18/2026
    // Branding is only offered for equipment where the manufacturer actually changes how
    // the lift behaves. Unknown equipment stays permissive (see Exercise.canBeBranded) —
    // every lift created before this field existed is nil.
    private var canBeBranded: Bool { equipmentType?.isBrandable ?? true }

    private var canonicalBrand: String {
        canBeBranded ? store.normalizedBrand(brand) : ""
    }

    // Claude  Date 08/18/2026
    // Whether this name + brand pair already exists on some OTHER lift. addBrandVariant
    // guards its own path, but this form can reach the same collision, and two identical
    // rows in the library would be impossible to tell apart afterwards.
    private var duplicateExists: Bool {
        guard !trimmedName.isEmpty else { return false }
        return store.exercises.contains {
            $0.id != editing?.id
                && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
                && $0.brand.caseInsensitiveCompare(canonicalBrand) == .orderedSame
        }
    }

    private var canSave: Bool { !trimmedName.isEmpty && !duplicateExists }

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
                    // Claude  Date 09/07/2026
                    // Cardio replaces the muscle-group cascade with the machine picker: the
                    // machine is what decides how this lift LOGS (duration + distance rather
                    // than reps x weight), and no cardio machine drives one muscle group
                    // worth graphing. Region Cardio without a machine would be the worst of
                    // both — filed under Cardio but still logging reps — so the picker always
                    // has a value and `resolvedCardioMachine` defaults it to Treadmill.
                    if region == .cardio {
                        Picker("Machine", selection: cardioMachineSelection) {
                            ForEach(CardioMachine.allCases, id: \.self) { machine in
                                Text(machine.title).tag(machine)
                            }
                        }
                    }
                    // Region = Other: free-text group (the sole "uncategorized" path).
                    // Any real region: a picker of that region's sub-groups + Custom…
                    else if region == .other {
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

                if region != .cardio {
                    moverSection
                }

                // Claude  Date 08/18/2026
                // Equipment drives the nameplate chip beside the lift's name and gates the
                // Brand field below it. "Unspecified" is a real option, not an oversight:
                // it's what every lift created before this field existed reads as.
                Section {
                    Picker("Equipment", selection: $equipmentType) {
                        Text("Unspecified").tag(EquipmentType?.none)
                        ForEach(EquipmentType.allCases, id: \.self) { type in
                            Text(type.title).tag(EquipmentType?.some(type))
                        }
                    }
                } header: {
                    Text("Equipment")
                } footer: {
                    Text("How the lift is loaded. Machines, cables and Smith machines can carry a brand, since the same movement can feel completely different from one manufacturer to another.")
                }

                if canBeBranded {
                    brandSection
                }

                // Claude  Date 09/07/2026 — neither flag means anything for a bout: cardio
                // is never logged per-side, and its "weight" field doesn't exist at all.
                if region != .cardio {
                    Section {
                        Toggle("Unilateral", isOn: $isUnilateral)
                    } footer: {
                        Text("Turn on for movements done one side at a time (e.g. single-arm row, lunges) so they can be tracked separately on graphs. Leave off for two-sided lifts like bench press.")
                    }
                }

                // Claude  Date 07/20/2026
                // Bodyweight lift toggle: when on, a set's weight is treated as ADDED load
                // on top of bodyweight, shown as "+N lb" in the workout editor.
                if region != .cardio {
                    Section {
                        Toggle("Bodyweight", isOn: $isBodyweight)
                    } footer: {
                        Text("Turn on for movements loaded by your own bodyweight (e.g. pull-up, dip, chin-up). Weights you log then count as added weight — shown with a “+”, like +25 lb — with just “+” for no added weight.")
                    }
                }

                // Claude  Date 07/13/2026
                // When editing an existing lift, make the outcome of the edit explicit
                // rather than implicit: "Save" tweaks THIS lift in place (every workout and
                // preset using it updates), while "Save as New Lift" leaves the original as-is
                // and adds a separate copy carrying these changes. Creating a brand-new lift
                // has no such ambiguity, so it keeps the single toolbar "Save" above.
                if editing != nil {
                    Section {
                        Button(action: saveInPlace) {
                            Text("Save")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                        .listRowBackground(Color.clear)

                        Button(action: saveAsNew) {
                            Text("Save as New Lift")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canSave)
                        .listRowBackground(Color.clear)
                    } footer: {
                        Text("“Save” updates this lift everywhere it's used. “Save as New Lift” keeps the original and adds a separate copy with these changes.")
                    }
                }
            }
            .navigationTitle(editing == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                // Claude  Date 07/13/2026
                // Creating a new lift keeps the one-tap toolbar Save. When editing, the
                // save choice ("Save" vs "Save as New Lift") lives in the bottom section
                // instead, so it's a deliberate pick rather than a single ambiguous button.
                if editing == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: saveAsNew).disabled(!canSave)
                    }
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

    // Claude  Date 08/18/2026
    // The brand field. Typing here and hitting "Save" re-labels THIS lift (its history
    // follows its id); "Save as New Lift" is the way to start a separate branded one —
    // which is what the Add Brand sheet does in one step from the library and picker.
    @ViewBuilder private var brandSection: some View {
        Section {
            TextField("Brand (optional)", text: $brand)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            // Brands already in the library — one tap, and no second spelling of one.
            ForEach(store.brandSuggestions(matching: brand), id: \.self) { suggestion in
                Button {
                    brand = suggestion
                } label: {
                    Label(suggestion, systemImage: "arrow.up.left.circle")
                        .font(.subheadline)
                }
            }
        } header: {
            Text("Brand")
        } footer: {
            Text(brandFooter)
        }
    }

    private var brandFooter: String {
        if duplicateExists {
            return "You already have this lift. Pick a different brand, or use the one you have."
        }
        if editing != nil, canonicalBrand != (editing?.brand ?? "") {
            return "“Save” re-labels this lift, and its existing history comes with it. To keep the original and track this machine separately, use “Save as New Lift”."
        }
        return "The manufacturer of the machine — or the gym's name, if you don't know it. A branded lift tracks its own history."
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

    // Resolve the muscle group + primary mover from the current form state. Shared by
    // every save path so in-place and new-lift saves normalize identically.
    // Claude  Date 06/09/2026 last changed: 07/13/2026 by: Claude
    // Region = Other keeps the free-text "Other" fallback; a real region is always a real
    // sub-group (custom-but-blank falls back to a known one), never "Other". Free-typed
    // movers get snapped to canonical spelling; picked/auto ones are already canonical.
    // (07/13) Factored out of the old save() so "Save" and "Save as New Lift" share it.
    // Claude  Date 09/07/2026
    // Always offers a machine (Treadmill by default) so the picker can't sit empty, and
    // writes straight back to the state the save paths read.
    private var cardioMachineSelection: Binding<CardioMachine> {
        Binding(get: { cardioMachine ?? .treadmill },
                set: { cardioMachine = $0 })
    }

    private func resolvedFields() -> (category: String, mover: String) {
        // Claude  Date 09/07/2026 — cardio files under one flat "Cardio" group with no
        // primary mover, matching the seed machines, so it can never land a bar in the
        // sets-per-muscle-group chart under a stale group the user had picked before.
        if region == .cardio { return ("Cardio", "") }
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
        let resolvedMover = (showsMoverFreeText || moverIsCustom)
            ? Exercise.normalizedPrimaryMover(primaryMover)
            : primaryMover
        return (resolvedCategory, resolvedMover)
    }

    // Claude  Date 07/13/2026 last changed: 08/04/2026 by: Claude
    // "Save" while editing — update THIS lift in place, preserving its id, liftType, and
    // quality (not shown in this form). Every workout/preset that references it updates.
    // Falls back to creating one if somehow called without an edit target.
    // (08/04) Re-read the lift from the store before applying the form's fields.
    // `editing` is a snapshot taken when this sheet opened, and the perma note
    // (Exercise.note) is now editable from the workout and preset editors — i.e. from
    // the screen sitting directly behind this sheet. Writing back the stale snapshot
    // would silently revert a note typed there.
    // Claude  Date 09/07/2026
    // The machine to save: only when the region is Cardio, and defaulting to Treadmill if
    // the user picked the region but never touched the machine picker. A cardio-region lift
    // with no machine would render as cardio in the library but still log reps x weight.
    private var resolvedCardioMachine: CardioMachine? {
        region == .cardio ? (cardioMachine ?? .treadmill) : nil
    }

    private func saveInPlace() {
        guard let target = editing else { return saveAsNew() }
        var existing = store.exercise(for: target.id) ?? target
        let fields = resolvedFields()
        existing.name = trimmedName
        existing.region = region
        existing.category = fields.category
        existing.isUnilateral = isUnilateral
        existing.primaryMover = fields.mover
        existing.isBodyweight = isBodyweight
        existing.equipmentType = equipmentType
        // Cleared when the equipment can't be branded, so a lift switched from Machine to
        // Free Weight doesn't keep a stale manufacturer no field is showing any more.
        existing.brand = canBeBranded ? brand : ""
        // Claude  Date 09/07/2026 — resolvedCardioMachine, not the raw state: switching a
        // lift's region away from Cardio has to drop the machine, or it keeps logging bouts.
        existing.cardioMachine = resolvedCardioMachine
        store.updateExercise(existing)
        onCreate(existing)
        dismiss()
    }

    // Claude  Date 07/13/2026 last changed: 08/18/2026 by: Claude
    // "Save as New Lift" (and the create flow) — add a brand-new, separate exercise from
    // the current form, leaving any edited original untouched.
    // (08/18) When there IS an edit target, its liftType/quality now ride along. This is
    // the main way to make a branded copy of a curated lift, and stripping those tags
    // silently cost a copy of Barbell Back Squat its big-3 badge credit and its Optimal
    // tag. A lift created from scratch still passes nil for both — custom lifts aren't
    // big-3 — because `editing` is nil there.
    private func saveAsNew() {
        let fields = resolvedFields()
        let created = store.addExercise(
            name: trimmedName,
            region: region,
            category: fields.category,
            isUnilateral: isUnilateral,
            liftType: editing?.liftType,
            primaryMover: fields.mover,
            quality: editing?.quality,
            isBodyweight: isBodyweight,
            note: editing?.note,
            brand: canBeBranded ? brand : "",
            equipmentType: equipmentType,
            cardioMachine: resolvedCardioMachine
        )
        onCreate(created)
        dismiss()
    }
}

#Preview {
    NewExerciseView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
