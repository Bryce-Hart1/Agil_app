import SwiftUI

// CLAUDE  Date 09/27/2026
// "Building a preset": the Build tab and preset editor on sample data. Walks through a
// blank preset's name, icon, notes, adaptive progression, one lift's plan, and finishing.
// Never touches AppStore, and nothing here takes keyboard focus.

// MARK: - Script

enum PresetDemoRoute: Hashable {
    case editor
}

struct PresetDemoItem: Identifiable {
    let exercise: Exercise
    var repRange = RepRange(min: 8, max: 12)
    var targetSets: Int?
    var restSeconds: Int?
    var weightIncrement: Double?

    var id: UUID { exercise.id }
}

struct PresetDemoState {
    var tab = AgilTabItem.workouts.tag
    var path: [PresetDemoRoute] = []
    var showingPicker = false
    var name = "New Preset"
    var icon = "dumbbell.fill"
    var isAdaptive = false
    var items: [PresetDemoItem] = []
    var isSaved = false
}

enum PresetDemoAction: Equatable {
    case selectTab(Int)
    case blankPreset
    case fillName
    case pickIcon(String)
    case setAdaptive(Bool)
    case openPicker
    case pickExercise(Exercise)
    case setSets(Int?)
    case setRest(Int?)
    case finish
}

enum PresetDemoTarget: Hashable {
    case buildTab, addButton, nameField, iconGrid, notesField, adaptiveToggle
    case addExercise, pickerRow, setsPicker, repRange, restPicker, finish, newPreset
}

struct PresetDemoScript: DemoScript {
    typealias Step = DemoStep<PresetDemoAction, PresetDemoTarget>

    let initialState = PresetDemoState()

    let steps: [Step] = [
        Step(text: "Tap Build in the tab bar.",
             target: .buildTab, action: .selectTab(AgilTabItem.build.tag)),
        Step(text: "Tap + at the top right, then Blank Preset. Browse Premade starts you from a ready-made plan instead.",
             target: .addButton, action: .blankPreset),
        Step(text: "Here you'd name your preset. Tap the name to fill it in.",
             target: .nameField, effect: .fillName),
        Step(text: "Pick an icon for it.",
             target: .iconGrid, action: .pickIcon("flame.fill")),
        Step(text: "Notes here show on every workout you start from this preset.",
             target: .notesField),
        Step(text: "Turn on Adaptive progression to get a suggested weight each time, based on your last session.",
             target: .adaptiveToggle, action: .setAdaptive(true)),
        Step(text: "Tap Add Exercise.",
             target: .addExercise, action: .openPicker),
        Step(text: "Pick a lift.",
             target: .pickerRow, action: .pickExercise(DemoSamples.benchPress)),
        Step(text: "Pick how many sets. They're filled in for you when you start the preset.",
             target: .setsPicker, action: .setSets(3)),
        Step(text: "The target rep range starts at 8 to 12. Here you'd type your own.",
             target: .repRange),
        Step(text: "Pick a rest time. With adaptive on, you can also set how much the weight goes up.",
             target: .restPicker, action: .setRest(120)),
        Step(text: "Tap Finish Preset. Changes save as you go.",
             target: .finish, action: .finish),
        Step(text: "Start it anytime from the preset button on the Workouts tab.",
             target: .newPreset)
    ]

    func apply(_ action: PresetDemoAction, to state: inout PresetDemoState) {
        switch action {
        case .selectTab(let tag):
            state.tab = tag
        case .blankPreset:
            state.path = [.editor]
        case .fillName:
            state.name = "Upper Body"
        case .pickIcon(let icon):
            state.icon = icon
        case .setAdaptive(let on):
            state.isAdaptive = on
        case .openPicker:
            state.showingPicker = true
        case .pickExercise(let exercise):
            state.items.append(PresetDemoItem(exercise: exercise))
            state.showingPicker = false
        case .setSets(let count):
            if !state.items.isEmpty { state.items[0].targetSets = count }
        case .setRest(let seconds):
            if !state.items.isEmpty { state.items[0].restSeconds = seconds }
        case .finish:
            state.path = []
            state.isSaved = true
        }
    }

    // Any icon or lift counts; the set count and rest need a real value; adaptive must go on.
    func matches(_ attempted: PresetDemoAction, expected: PresetDemoAction) -> Bool {
        switch (attempted, expected) {
        case (.pickIcon, .pickIcon), (.pickExercise, .pickExercise):
            return true
        case let (.setSets(count), .setSets):
            return count != nil
        case let (.setRest(seconds), .setRest):
            return seconds != nil
        default:
            return attempted == expected
        }
    }
}

// MARK: - Shell

struct PresetDemoShell: View {
    @ObservedObject var runner: DemoRunner<PresetDemoScript>

    private var state: PresetDemoState { runner.state }

    var body: some View {
        VStack(spacing: 0) {
            if state.tab == AgilTabItem.build.tag {
                NavigationStack(path: Binding(get: { state.path }, set: { _ in })) {
                    PresetDemoList(runner: runner)
                        .navigationDestination(for: PresetDemoRoute.self) { _ in
                            PresetDemoEditor(runner: runner)
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
            DemoSheet(isPresented: state.showingPicker) {
                DemoExercisePicker(title: "Add Exercise",
                                   highlighted: runner.isTarget(.pickerRow) ? DemoSamples.benchPress.id : nil,
                                   nudges: runner.nudges,
                                   onPick: { runner.attempt(.pickExercise($0)) },
                                   onNudge: { runner.nudge() })
            }
        }
    }
}

// MARK: - Presets list

private struct PresetDemoList: View {
    @ObservedObject var runner: DemoRunner<PresetDemoScript>

    var body: some View {
        DemoPresetsScreen(newPreset: runner.state.isSaved ? newRow : nil,
                          highlightNewPreset: runner.isTarget(.newPreset),
                          nudges: runner.nudges,
                          onNudge: { runner.nudge() }) {
            DemoExercisesLink { runner.nudge() }
        } trailing: {
            Menu {
                Button {
                    runner.attempt(.blankPreset)
                } label: {
                    Label("Blank Preset", systemImage: "square.and.pencil")
                }
                Button {
                    runner.nudge()
                } label: {
                    Label("Browse Premade", systemImage: "square.stack")
                }
            } label: {
                Image(systemName: "plus")
            }
            .demoHighlight(runner.isTarget(.addButton), nudges: runner.nudges,
                           cornerRadius: 8, inset: -8)
        }
    }

    private var newRow: DemoSamples.PresetRow {
        let names = runner.state.items.map(\.exercise.name)
        return DemoSamples.PresetRow(name: runner.state.name, icon: runner.state.icon,
                                     summary: names.isEmpty ? "No exercises yet" : names.joined(separator: ", "))
    }
}

// MARK: - Preset editor

// CLAUDE  Date 09/27/2026
// Copy of the preset editor. Name and notes are display-only fields (tapping fills or
// explains them); the icon grid, pickers and toggle are the real controls over demo state.
private struct PresetDemoEditor: View {
    @ObservedObject var runner: DemoRunner<PresetDemoScript>

    @EnvironmentObject private var theme: ThemeManager

    private var state: PresetDemoState { runner.state }
    private var accent: Color { theme.current.accent }

    var body: some View {
        Form {
            Section("Name") {
                DemoFieldText(value: state.name, placeholder: "Preset name")
                    .onTapGesture { runner.acknowledge(.nameField) }
                    .demoHighlight(runner.isTarget(.nameField), nudges: runner.nudges, inset: -4)
            }

            Section("Icon") {
                IconGrid(selected: Binding(get: { state.icon },
                                           set: { runner.attempt(.pickIcon($0)) }),
                         accent: accent)
                    .demoHighlight(runner.isTarget(.iconGrid), nudges: runner.nudges, inset: -2)
            }

            Section("Notes") {
                DemoFieldText(value: nil, placeholder: "Notes for this preset")
                    .onTapGesture { runner.acknowledge(.notesField) }
                    .demoHighlight(runner.isTarget(.notesField), nudges: runner.nudges, inset: -4)
            }

            Section {
                Toggle(isOn: Binding(get: { state.isAdaptive },
                                     set: { runner.attempt(.setAdaptive($0)) })) {
                    HStack(spacing: 6) {
                        Text("Adaptive progression")
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .demoHighlight(runner.isTarget(.adaptiveToggle), nudges: runner.nudges, inset: -4)
            }

            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                itemSection(item, index: index)
            }

            Section {
                Button {
                    runner.attempt(.openPicker)
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .demoHighlight(runner.isTarget(.addExercise), nudges: runner.nudges)
            }

            Section {
                Button {
                    runner.attempt(.finish)
                } label: {
                    Text("Finish Preset")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .demoHighlight(runner.isTarget(.finish), nudges: runner.nudges,
                               cornerRadius: 12, inset: -5)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(state.name.isEmpty ? "Preset" : state.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DemoBackButton(title: "Presets") { runner.nudge() }
            }
        }
        .themed(theme.current)
    }

    private func itemSection(_ item: PresetDemoItem, index: Int) -> some View {
        Section {
            RepRangeRow(targetRepRange: .constant(item.repRange))
                .demoInert { runner.acknowledge(.repRange) }
                .demoHighlight(runner.isTarget(.repRange), nudges: runner.nudges, inset: -4)

            Picker(selection: Binding(get: { item.targetSets },
                                      set: { runner.attempt(.setSets($0)) })) {
                Text("Don't specify").tag(Int?.none)
                ForEach(1...8, id: \.self) { count in
                    Text("\(count)").tag(Int?.some(count))
                }
            } label: {
                Label("Sets", systemImage: "number")
            }
            .retintOnThemeChange(theme.current, salt: "demo-sets-\(index)")
            .demoHighlight(runner.isTarget(.setsPicker), nudges: runner.nudges, inset: -4)

            DemoNoteRow(icon: "pin.fill", tint: accent,
                        placeholder: "Exercise note (always shows for this lift)")
                .onTapGesture { runner.nudge() }

            Picker(selection: Binding(get: { item.restSeconds },
                                      set: { runner.attempt(.setRest($0)) })) {
                Text("None").tag(Int?.none)
                ForEach(RestDuration.options, id: \.self) { seconds in
                    Text(RestDuration.label(seconds)).tag(Int?.some(seconds))
                }
            } label: {
                Label("Rest timer", systemImage: "timer")
            }
            .retintOnThemeChange(theme.current, salt: "demo-rest-\(index)")
            .demoHighlight(runner.isTarget(.restPicker), nudges: runner.nudges, inset: -4)

            // Free to change: it isn't a step, and it's the same menu the real editor shows.
            if state.isAdaptive {
                Picker(selection: weightStep(index)) {
                    Text("Default (5 lb)").tag(Double?.none)
                    ForEach([2.5, 5, 10, 15], id: \.self) { step in
                        Text(Self.incrementLabel(step)).tag(Double?.some(step))
                    }
                } label: {
                    Label("Weight step", systemImage: "plus.forwardslash.minus")
                }
                .retintOnThemeChange(theme.current, salt: "demo-step-\(index)")
            }

            ExerciseActionsRow(onSwap: { runner.nudge() }, onRemove: { runner.nudge() })
        } header: {
            HStack {
                Text(item.exercise.displayLabel)
                EquipmentBadge(type: item.exercise.equipmentType)
                Button {
                    runner.nudge()
                } label: {
                    Image(systemName: "pencil")
                        .fontWeight(.bold)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
            }
        }
    }

    // Bounds-checked: going back a step can remove the lift while this picker still exists.
    private func weightStep(_ index: Int) -> Binding<Double?> {
        Binding(
            get: { state.items.indices.contains(index) ? state.items[index].weightIncrement : nil },
            set: { value in
                guard runner.state.items.indices.contains(index) else { return }
                runner.state.items[index].weightIncrement = value
            })
    }

    private static func incrementLabel(_ value: Double) -> String {
        let number = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        return "\(number) lb"
    }
}
