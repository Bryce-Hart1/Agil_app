import SwiftUI

// CLAUDE  Date 09/27/2026
// "Adding a custom exercise": the Build tab, the Exercises library and the New Exercise
// form on sample data, then how to edit, delete or brand a lift. Never touches AppStore,
// and nothing here takes keyboard focus.

// MARK: - Script

enum ExerciseDemoRoute: Hashable {
    case library
}

struct ExerciseDemoState {
    var tab = AgilTabItem.workouts.tag
    var path: [ExerciseDemoRoute] = []
    var showingNew = false
    var name: String?
    var region: MuscleRegion = .other
    var category = ""
    var cardioMachine: CardioMachine = .treadmill
    var equipment: EquipmentType?
    var isUnilateral = false
    var isBodyweight = false
    var saved: Exercise?
}

enum ExerciseDemoAction: Equatable {
    case selectTab(Int)
    case openLibrary
    case openNew
    case fillName
    case setRegion(MuscleRegion)
    case setEquipment(EquipmentType?)
    case save
}

enum ExerciseDemoTarget: Hashable {
    case buildTab, exercisesLink, addButton, nameField, regionPicker, equipmentPicker
    case toggles, save, newRow
}

struct ExerciseDemoScript: DemoScript {
    typealias Step = DemoStep<ExerciseDemoAction, ExerciseDemoTarget>

    let initialState = ExerciseDemoState()

    let steps: [Step] = [
        Step(text: "Tap Build in the tab bar.",
             target: .buildTab, action: .selectTab(AgilTabItem.build.tag)),
        Step(text: "Tap Exercises at the top left to open your lift library.",
             target: .exercisesLink, action: .openLibrary),
        Step(text: "Tap + at the top right.",
             target: .addButton, action: .openNew),
        Step(text: "Here you'd type the lift's name. Tap to fill it in.",
             target: .nameField, effect: .fillName),
        Step(text: "Pick its body region. The muscle group and primary mover fill in for you.",
             target: .regionPicker, action: .setRegion(.chest)),
        Step(text: "Pick the equipment. Machines, cables, and Smith machines can also carry a brand.",
             target: .equipmentPicker, action: .setEquipment(.cable)),
        Step(text: "Turn on Unilateral for lifts done one side at a time, or Bodyweight for lifts like pull-ups.",
             target: .toggles),
        Step(text: "Tap Save.",
             target: .save, action: .save),
        Step(text: "Swipe a lift left to edit or delete it.",
             target: .newRow),
        Step(text: "Hold a lift to edit it or add a brand, like the machine's maker or your gym. Each brand tracks its own history.",
             target: .newRow),
        Step(text: "Your lift is ready to add to any workout or preset.")
    ]

    func apply(_ action: ExerciseDemoAction, to state: inout ExerciseDemoState) {
        switch action {
        case .selectTab(let tag):
            state.tab = tag
        case .openLibrary:
            state.path = [.library]
        case .openNew:
            state.showingNew = true
        case .fillName:
            state.name = "Cable Fly"
        case .setRegion(let region):
            state.region = region
            state.category = ExerciseDemoMuscles.groups(for: region).first ?? ""
        case .setEquipment(let equipment):
            state.equipment = equipment
        case .save:
            let isCardio = state.region == .cardio
            state.saved = Exercise(
                name: state.name ?? "Cable Fly", region: state.region,
                category: state.category.isEmpty ? (isCardio ? "Cardio" : "Other") : state.category,
                isUnilateral: !isCardio && state.isUnilateral,
                primaryMover: ExerciseDemoMuscles.mover(for: state.category) ?? "",
                isBodyweight: !isCardio && state.isBodyweight,
                equipmentType: state.equipment,
                cardioMachine: isCardio ? state.cardioMachine : nil)
            state.showingNew = false
        }
    }

    // Any region counts; the equipment step needs a real type, not Unspecified.
    func matches(_ attempted: ExerciseDemoAction, expected: ExerciseDemoAction) -> Bool {
        switch (attempted, expected) {
        case (.setRegion, .setRegion):
            return true
        case let (.setEquipment(equipment), .setEquipment):
            return equipment != nil
        default:
            return attempted == expected
        }
    }
}

// CLAUDE  Date 09/27/2026
// Sample muscle groups per region and the one primary mover each auto-assigns, standing in
// for the library's lookups (the real form offers a picker when a group has several).
enum ExerciseDemoMuscles {
    static func groups(for region: MuscleRegion) -> [String] {
        switch region {
        case .legs:      return ["Quads", "Hamstrings", "Glutes", "Calves"]
        case .chest:     return ["Chest", "Upper Chest"]
        case .back:      return ["Lats", "Upper Back", "Lower Back", "Traps"]
        case .shoulders: return ["Front Delts", "Side Delts", "Rear Delts"]
        case .arms:      return ["Biceps", "Triceps", "Forearms"]
        case .core:      return ["Abs", "Obliques"]
        case .cardio, .other: return []
        }
    }

    static func mover(for group: String) -> String? {
        [
            "Quads": "Quadriceps", "Hamstrings": "Hamstrings", "Glutes": "Gluteus Maximus",
            "Calves": "Gastrocnemius", "Chest": "Pectoralis Major", "Upper Chest": "Pectoralis Major",
            "Lats": "Latissimus Dorsi", "Upper Back": "Rhomboids", "Lower Back": "Erector Spinae",
            "Traps": "Trapezius", "Front Delts": "Anterior Deltoid", "Side Delts": "Lateral Deltoid",
            "Rear Delts": "Posterior Deltoid", "Biceps": "Biceps Brachii", "Triceps": "Triceps Brachii",
            "Forearms": "Brachioradialis", "Abs": "Rectus Abdominis", "Obliques": "Obliques"
        ][group]
    }
}

// MARK: - Shell

struct ExerciseDemoShell: View {
    @ObservedObject var runner: DemoRunner<ExerciseDemoScript>

    private var state: ExerciseDemoState { runner.state }

    var body: some View {
        VStack(spacing: 0) {
            if state.tab == AgilTabItem.build.tag {
                NavigationStack(path: Binding(get: { state.path }, set: { _ in })) {
                    DemoPresetsScreen(onNudge: { runner.nudge() }) {
                        DemoExercisesLink { runner.attempt(.openLibrary) }
                            .demoHighlight(runner.isTarget(.exercisesLink), nudges: runner.nudges,
                                           cornerRadius: 8, inset: -6)
                    } trailing: {
                        Button { runner.nudge() } label: { Image(systemName: "plus") }
                    }
                    .navigationDestination(for: ExerciseDemoRoute.self) { _ in
                        ExerciseDemoLibrary(runner: runner)
                    }
                }
            } else {
                NavigationStack {
                    DemoWorkoutsScreen(onNudge: { runner.nudge() })
                }
            }
            DemoTabBar(mode: .lifting, selectedTag: state.tab,
                       highlightedTag: runner.isTarget(.buildTab) ? AgilTabItem.build.tag : nil,
                       nudges: runner.nudges) { runner.attempt(.selectTab($0)) }
        }
        .overlay {
            DemoSheet(isPresented: state.showingNew) {
                ExerciseDemoForm(runner: runner)
            }
        }
    }
}

// MARK: - Exercises library

// CLAUDE  Date 09/27/2026
// Copy of ExercisesListView: the sample library by region, with the new lift slotted into
// its region. Every row has the real swipe and hold menus; only the new lift's advance.
private struct ExerciseDemoLibrary: View {
    @ObservedObject var runner: DemoRunner<ExerciseDemoScript>

    @EnvironmentObject private var theme: ThemeManager

    private var groups: [DemoSamples.LiftGroup] {
        var groups = DemoSamples.library
        guard let saved = runner.state.saved else { return groups }
        if let index = groups.firstIndex(where: { $0.region == saved.region }) {
            groups[index].exercises.append(saved)
        } else {
            groups.append(DemoSamples.LiftGroup(region: saved.region, exercises: [saved]))
            let order = MuscleRegion.allCases
            groups.sort { order.firstIndex(of: $0.region)! < order.firstIndex(of: $1.region)! }
        }
        return groups
    }

    var body: some View {
        List {
            ForEach(groups) { group in
                Section(group.region.title) {
                    ForEach(group.exercises) { exercise in
                        row(exercise)
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .navigationBarBackButtonHidden(true)
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DemoBackButton(title: "Presets") { runner.nudge() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    runner.attempt(.openNew)
                } label: {
                    Image(systemName: "plus")
                }
                .demoHighlight(runner.isTarget(.addButton), nudges: runner.nudges,
                               cornerRadius: 8, inset: -8)
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let isNew = exercise.id == runner.state.saved?.id
        let tap = { if isNew { runner.acknowledge(.newRow) } else { runner.nudge() } }
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(exercise.displayLabel)
                EquipmentBadge(type: exercise.equipmentType)
            }
            HStack(spacing: 6) {
                Text(exercise.muscleSubtitle)
                if exercise.isUnilateral {
                    Text("Unilateral")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.current.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.current.accent.opacity(0.18), in: Capsule())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            if exercise.canBeBranded {
                Button(action: tap) { Label("Add Brand…", systemImage: "tag") }
            }
            Button(action: tap) { Label("Edit", systemImage: "pencil") }
        }
        .swipeActions(edge: .trailing) {
            Button(action: tap) { Label("Delete", systemImage: "trash") }
                .tint(.red)
            Button(action: tap) { Label("Edit", systemImage: "pencil") }
                .tint(theme.current.accent)
        }
        .demoHighlight(isNew && runner.isTarget(.newRow), nudges: runner.nudges, inset: -4)
    }
}

// MARK: - New Exercise form

// CLAUDE  Date 09/27/2026
// Copy of NewExerciseView. Name, brand and free-text fields are display only; the region
// and equipment pickers are steps, while muscle group and the two toggles stay free.
private struct ExerciseDemoForm: View {
    @ObservedObject var runner: DemoRunner<ExerciseDemoScript>

    @EnvironmentObject private var theme: ThemeManager

    private var state: ExerciseDemoState { runner.state }
    private var isCardio: Bool { state.region == .cardio }
    private var canBeBranded: Bool { state.equipment?.isBrandable ?? true }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    DemoFieldText(value: state.name, placeholder: "Name")
                        .onTapGesture { runner.acknowledge(.nameField) }
                        .demoHighlight(runner.isTarget(.nameField), nudges: runner.nudges, inset: -4)

                    Picker("Region", selection: Binding(get: { state.region },
                                                        set: { runner.attempt(.setRegion($0)) })) {
                        ForEach(MuscleRegion.allCases, id: \.self) { region in
                            Text(region.title).tag(region)
                        }
                    }
                    .demoHighlight(runner.isTarget(.regionPicker), nudges: runner.nudges, inset: -4)

                    groupRow
                }

                if !isCardio {
                    moverSection
                }

                Section {
                    Picker("Equipment", selection: Binding(get: { state.equipment },
                                                           set: { runner.attempt(.setEquipment($0)) })) {
                        Text("Unspecified").tag(EquipmentType?.none)
                        ForEach(EquipmentType.allCases, id: \.self) { type in
                            Text(type.title).tag(EquipmentType?.some(type))
                        }
                    }
                    .demoHighlight(runner.isTarget(.equipmentPicker), nudges: runner.nudges, inset: -4)
                } header: {
                    Text("Equipment")
                } footer: {
                    Text("How the lift is loaded. Machines, cables and Smith machines can carry a brand, since the same movement can feel completely different from one manufacturer to another.")
                }

                if canBeBranded {
                    Section {
                        DemoFieldText(value: nil, placeholder: "Brand (optional)")
                            .onTapGesture { runner.nudge() }
                    } header: {
                        Text("Brand")
                    } footer: {
                        Text("The manufacturer of the machine, or the gym's name if you don't know it. A branded lift tracks its own history.")
                    }
                }

                if !isCardio {
                    Section {
                        Toggle("Unilateral", isOn: $runner.state.isUnilateral)
                            .demoHighlight(runner.isTarget(.toggles), nudges: runner.nudges, inset: -4)
                    } footer: {
                        Text("Turn on for movements done one side at a time (e.g. single-arm row, lunges) so they can be tracked separately on graphs. Leave off for two-sided lifts like bench press.")
                    }
                    Section {
                        Toggle("Bodyweight", isOn: $runner.state.isBodyweight)
                            .demoHighlight(runner.isTarget(.toggles), nudges: runner.nudges, inset: -4)
                    } footer: {
                        Text("Turn on for movements loaded by your own bodyweight (e.g. pull-up, dip, chin-up). Weights you log then count as added weight, shown with a “+”, like +25 lb.")
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { runner.nudge() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { runner.attempt(.save) }
                        .demoHighlight(runner.isTarget(.save), nudges: runner.nudges,
                                       cornerRadius: 8, inset: -6)
                }
            }
        }
    }

    // The row under Region, which depends on it: a machine for cardio, free text for Other,
    // otherwise that region's muscle groups.
    @ViewBuilder private var groupRow: some View {
        if isCardio {
            Picker("Machine", selection: $runner.state.cardioMachine) {
                ForEach(CardioMachine.allCases, id: \.self) { machine in
                    Text(machine.title).tag(machine)
                }
            }
        } else if state.region == .other {
            DemoFieldText(value: nil, placeholder: "Muscle group (e.g. Quads, Chest, Biceps)")
                .onTapGesture { runner.nudge() }
        } else {
            Picker("Muscle group", selection: $runner.state.category) {
                ForEach(ExerciseDemoMuscles.groups(for: state.region), id: \.self) { Text($0).tag($0) }
            }
        }
    }

    // Free text while the group is unknown, otherwise the mover the group assigns.
    private var moverSection: some View {
        Section {
            if let mover = ExerciseDemoMuscles.mover(for: state.category) {
                LabeledContent("Primary mover", value: mover)
            } else {
                HStack {
                    DemoFieldText(value: nil, placeholder: "Primary mover (optional)")
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
                .onTapGesture { runner.nudge() }
            }
        } header: {
            Text("Primary mover")
        } footer: {
            Text(ExerciseDemoMuscles.mover(for: state.category) == nil
                 ? "The main muscle this lift drives. Optional. Leave it blank if you're not sure."
                 : "Set automatically from the muscle group.")
        }
    }
}
