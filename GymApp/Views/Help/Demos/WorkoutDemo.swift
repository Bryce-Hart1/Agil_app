import SwiftUI

// CLAUDE  Date 09/27/2026
// Two demos on one copy of the Workouts tab and workout editor: "Starting a new workout"
// (blank) and "Starting from a preset". Sample data only, never AppStore, and nothing
// here takes keyboard focus: typing steps are described and filled in on a tap.

// MARK: - Script

enum WorkoutDemoRoute: Hashable {
    case editor
}

// CLAUDE  Date 09/27/2026
// A preset's "Suggested N lb" line. delta > 0 reads as an increase, 0 as "same as last time".
struct WorkoutDemoAdaptive {
    let weight: Double
    let delta: Double
}

struct WorkoutDemoLift: Identifiable {
    let exercise: Exercise
    var repRange: RepRange? = RepRange(min: 8, max: 12)
    var sets: [ExerciseSet] = []
    var restSeconds: Int?
    var adaptive: WorkoutDemoAdaptive?

    var id: UUID { exercise.id }
}

struct WorkoutDemoState {
    var path: [WorkoutDemoRoute] = []
    var showingPicker = false
    /// Set when the workout was started from a preset.
    var presetName: String?
    var lifts: [WorkoutDemoLift] = []
    var isFinished = false
}

enum WorkoutDemoAction: Equatable {
    case startWorkout
    case startPreset(String)
    case openPicker
    case pickExercise(Exercise)
    case addSet(lift: Int)
    case fillSampleSet
    case deleteSet(lift: Int, set: Int)
    case checkOffSet(lift: Int, set: Int)
    case setRest(lift: Int, seconds: Int?)
    case completeWorkout
}

enum WorkoutDemoTarget: Hashable {
    case blankButton, presetButton, addExercise, pickerRow
    case addSet(lift: Int), setRow(lift: Int, set: Int), restPicker(lift: Int)
    case adaptiveHint(lift: Int), sessionNote(lift: Int), liftActions(lift: Int)
    case saveAsPreset, overridePreset, complete
}

struct WorkoutDemoScript: DemoScript {
    enum Variant { case blank, preset }

    typealias Step = DemoStep<WorkoutDemoAction, WorkoutDemoTarget>

    let initialState = WorkoutDemoState()
    let steps: [Step]

    init(_ variant: Variant) {
        steps = variant == .blank ? Self.blankSteps : Self.presetSteps
    }

    private static let blankSteps: [Step] = [
        Step(text: "Tap the blank page at the top left to start a new workout.",
             target: .blankButton, action: .startWorkout),
        Step(text: "Tap Add Exercise to add a lift.",
             target: .addExercise, action: .openPicker),
        Step(text: "Pick a lift. You can also search, or tap + to make a new one.",
             target: .pickerRow, action: .pickExercise(DemoSamples.benchPress)),
        Step(text: "Tap Add Set to log a set.",
             target: .addSet(lift: 0), action: .addSet(lift: 0)),
        Step(text: "Here you'd type your reps and weight. Tap the set to fill it in.",
             target: .setRow(lift: 0, set: 0), effect: .fillSampleSet),
        Step(text: "The dot shows how your reps compare to the target: green inside the range, yellow above it, red below.",
             target: .setRow(lift: 0, set: 0)),
        Step(text: "Tap Add Set again. A new set copies the one before it.",
             target: .addSet(lift: 0), action: .addSet(lift: 0)),
        Step(text: "Swipe the new set left and tap Delete to remove it.",
             target: .setRow(lift: 0, set: 1), action: .deleteSet(lift: 0, set: 1)),
        Step(text: "Swipe a set right to check it off, or hold it for more options. Only checked sets count when you finish.",
             target: .setRow(lift: 0, set: 0), action: .checkOffSet(lift: 0, set: 0)),
        Step(text: "Pick a rest time, then tap Start to count down between sets.",
             target: .restPicker(lift: 0), action: .setRest(lift: 0, seconds: 90)),
        Step(text: "Swap trades this lift for another in the same spot. Remove takes it out of the workout.",
             target: .liftActions(lift: 0)),
        Step(text: "Save as New Preset turns this workout into a reusable preset. The ⋯ at the top right has it too.",
             target: .saveAsPreset),
        Step(text: "Tap Complete Workout when you're done.",
             target: .complete, action: .completeWorkout),
        Step(text: "After finishing you get a summary, earn coins, and the workout is saved here in History.")
    ]

    private static let presetSteps: [Step] = [
        Step(text: "Tap the preset button at the top right, then pick a preset.",
             target: .presetButton, action: .startPreset(WorkoutDemoPresets.pushDay.name)),
        Step(text: "Its lifts come in with their sets, rep ranges, and rest times already filled in."),
        Step(text: "Adaptive presets suggest a weight based on last time. You can always change it.",
             target: .adaptiveHint(lift: 0)),
        Step(text: "Here you'd leave a note for next time. It shows once, the next time you run this preset.",
             target: .sessionNote(lift: 0)),
        Step(text: "Swipe a set right as you finish it.",
             target: .setRow(lift: 0, set: 0), action: .checkOffSet(lift: 0, set: 0)),
        Step(text: "Changed the plan? Override Preset updates the preset to match: its lifts, rep ranges, set counts, and notes.",
             target: .overridePreset),
        Step(text: "Tap Complete Workout when you're done. If any sets are unchecked, you're asked first.",
             target: .complete, action: .completeWorkout),
        Step(text: "It's saved in History, and the next time you run this preset it builds on this one.")
    ]

    func apply(_ action: WorkoutDemoAction, to state: inout WorkoutDemoState) {
        switch action {
        case .startWorkout:
            state.presetName = nil
            state.lifts = []
            state.path = [.editor]
        case .startPreset(let name):
            let preset = WorkoutDemoPresets.all.first { $0.name == name } ?? WorkoutDemoPresets.pushDay
            state.presetName = preset.name
            state.lifts = preset.lifts
            state.path = [.editor]
        case .openPicker:
            state.showingPicker = true
        case .pickExercise(let exercise):
            state.lifts.append(WorkoutDemoLift(exercise: exercise))
            state.showingPicker = false
        case .addSet(let lift):
            guard state.lifts.indices.contains(lift) else { return }
            // Same defaults as the real editor: copy the last set, else the range's low end.
            let last = state.lifts[lift].sets.last
            let reps = last?.reps ?? state.lifts[lift].repRange.map { Swift.min($0.min, $0.max) } ?? 8
            state.lifts[lift].sets.append(ExerciseSet(reps: reps, weight: last?.weight ?? 0))
        case .fillSampleSet:
            guard let first = state.lifts.first, !first.sets.isEmpty else { return }
            state.lifts[0].sets[0].reps = 10
            state.lifts[0].sets[0].weight = 135
        case .deleteSet(let lift, let set):
            guard state.lifts.indices.contains(lift),
                  state.lifts[lift].sets.indices.contains(set) else { return }
            state.lifts[lift].sets.remove(at: set)
        case .checkOffSet(let lift, let set):
            guard state.lifts.indices.contains(lift),
                  state.lifts[lift].sets.indices.contains(set) else { return }
            if state.lifts[lift].sets[set].completedAt == nil {
                state.lifts[lift].sets[set].completedAt = Date()
            }
        case .setRest(let lift, let seconds):
            guard state.lifts.indices.contains(lift) else { return }
            state.lifts[lift].restSeconds = seconds
        case .completeWorkout:
            state.path = []
            state.isFinished = true
        }
    }

    // Any preset or lift counts as the pick, and any real rest time (not None) as the rest step.
    func matches(_ attempted: WorkoutDemoAction, expected: WorkoutDemoAction) -> Bool {
        switch (attempted, expected) {
        case (.startPreset, .startPreset), (.pickExercise, .pickExercise):
            return true
        case let (.setRest(lift, seconds), .setRest(expectedLift, _)):
            return lift == expectedLift && seconds != nil
        default:
            return attempted == expected
        }
    }
}

// MARK: - Sample presets

// CLAUDE  Date 09/27/2026
// The presets the preset button offers, already expanded the way AppStore.workout(from:)
// expands one: target sets pre-filled at the range's low end and the suggested weight.
enum WorkoutDemoPresets {
    struct Preset {
        let name: String
        let icon: String
        let lifts: [WorkoutDemoLift]
    }

    static let pushDay = Preset(name: "Push Day", icon: "dumbbell.fill", lifts: [
        lift(DemoSamples.benchPress, 8...12, sets: 3, rest: 120, weight: 140, delta: 5),
        lift(DemoSamples.inclinePress, 10...12, sets: 3, rest: 90, weight: 50, delta: 0),
        lift(DemoSamples.tricepPushdown, 12...15, sets: 3, rest: 60, weight: 60, delta: 5)
    ])

    static let legDay = Preset(name: "Leg Day", icon: "figure.strengthtraining.traditional", lifts: [
        lift(DemoSamples.backSquat, 5...8, sets: 4, rest: 180, weight: 225, delta: 10),
        lift(DemoSamples.legPress, 10...12, sets: 3, rest: 120, weight: 320, delta: 0)
    ])

    static let all = [pushDay, legDay]

    private static func lift(_ exercise: Exercise, _ range: ClosedRange<Int>, sets: Int,
                             rest: Int, weight: Double, delta: Double) -> WorkoutDemoLift {
        WorkoutDemoLift(exercise: exercise,
                        repRange: RepRange(min: range.lowerBound, max: range.upperBound),
                        sets: (0..<sets).map { _ in ExerciseSet(reps: range.lowerBound, weight: weight) },
                        restSeconds: rest,
                        adaptive: WorkoutDemoAdaptive(weight: weight, delta: delta))
    }
}

// MARK: - Shell

// CLAUDE  Date 09/27/2026
// The fake app inside the demo frame: a NavigationStack (list, then editor) over the real
// tab bar, with the exercise picker as an in-frame sheet. Navigation only moves when the
// script says so, so the path binding ignores writes.
struct WorkoutDemoShell: View {
    @ObservedObject var runner: DemoRunner<WorkoutDemoScript>

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: Binding(get: { runner.state.path }, set: { _ in })) {
                WorkoutDemoList(runner: runner)
                    .navigationDestination(for: WorkoutDemoRoute.self) { _ in
                        WorkoutDemoEditor(runner: runner)
                    }
            }
            DemoTabBar(mode: .lifting, selectedTag: AgilTabItem.workouts.tag) { _ in runner.nudge() }
        }
        .overlay {
            DemoSheet(isPresented: runner.state.showingPicker) {
                WorkoutDemoPicker(runner: runner)
            }
        }
    }
}

// MARK: - Workouts list

private struct WorkoutDemoList: View {
    @ObservedObject var runner: DemoRunner<WorkoutDemoScript>

    var body: some View {
        DemoWorkoutsScreen(newestSummary: runner.state.isFinished ? finishedSummary : nil,
                           onNudge: runner.nudge) {
            Button {
                runner.attempt(.startWorkout)
            } label: {
                DemoToolbarIcon(asset: "empty_workout")
            }
            .accessibilityLabel("New blank workout")
            .demoHighlight(runner.isTarget(.blankButton), nudges: runner.nudges,
                           cornerRadius: 8, inset: -5)
        } presetButton: {
            Menu {
                ForEach(WorkoutDemoPresets.all, id: \.name) { preset in
                    Button {
                        runner.attempt(.startPreset(preset.name))
                    } label: {
                        Label(preset.name, systemImage: preset.icon)
                    }
                }
            } label: {
                DemoToolbarIcon(asset: "preset_workout")
            }
            .accessibilityLabel("Start from a preset")
            .demoHighlight(runner.isTarget(.presetButton), nudges: runner.nudges,
                           cornerRadius: 8, inset: -5)
        }
    }

    // Same shape as the real History row's summary.
    private var finishedSummary: String {
        let lifts = runner.state.lifts.count
        let sets = runner.state.lifts.reduce(0) { $0 + $1.sets.count }
        return "\(lifts) exercise\(lifts == 1 ? "" : "s") • \(sets) set\(sets == 1 ? "" : "s")"
    }
}

// MARK: - Workout editor

// CLAUDE  Date 09/27/2026
// Copy of the workout editor. Reuses the real leaf views (SetRow, RepRangeRow, the section
// header, Swap/Remove row) over demo state, with every text field made inert so a tap
// never raises the keyboard. Each control completes the current step or nudges.
private struct WorkoutDemoEditor: View {
    @ObservedObject var runner: DemoRunner<WorkoutDemoScript>

    @EnvironmentObject private var theme: ThemeManager
    @FocusState private var focusedField: SetEntryField?

    private var state: WorkoutDemoState { runner.state }
    private var accent: Color { theme.current.accent }
    private var isPresetBacked: Bool { state.presetName != nil }
    private var title: String { state.presetName ?? Date().formatted(.dateTime.month().day()) }

    var body: some View {
        Form {
            header

            ForEach(Array(state.lifts.enumerated()), id: \.element.id) { index, lift in
                liftSection(lift, index: index)
            }

            Section {
                Button {
                    runner.attempt(.openPicker)
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .demoHighlight(runner.isTarget(.addExercise), nudges: runner.nudges)
            }

            bottomButtons
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DemoBackButton(title: "Workouts", action: runner.nudge)
            }
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                    .fontDesign(theme.fontDesign.design)
            }
            if !state.lifts.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        runner.acknowledge(.saveAsPreset)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .systemTypeface()
        .themed(theme.current)
    }

    // Date masthead and the notes line, as the real editor draws them (display only).
    private var header: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date(), format: .dateTime.weekday(.wide).month().day())
                        .font(.title3.weight(.semibold))
                    Text(Date(), format: .dateTime.hour().minute())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .fontDesign(theme.fontDesign.design)

            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.caption)
                Text("Add notes…")
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .foregroundStyle(.tertiary)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func liftSection(_ lift: WorkoutDemoLift, index: Int) -> some View {
        Section {
            RepRangeRow(targetRepRange: .constant(lift.repRange))
                .demoInert(onTap: runner.nudge)
            DemoNoteRow(icon: "pin.fill", tint: accent,
                        placeholder: "Exercise note (always shows for this lift)")
                .onTapGesture(perform: runner.nudge)
            if isPresetBacked {
                DemoNoteRow(icon: "bubble.left", tint: accent.opacity(0.45),
                            placeholder: "Note for next time (shows once, next session)")
                    .onTapGesture { runner.acknowledge(.sessionNote(lift: index)) }
                    .demoHighlight(runner.isTarget(.sessionNote(lift: index)), nudges: runner.nudges,
                                   inset: -4)
            }
            restPicker(lift, index: index)
            if let rest = lift.restSeconds {
                DemoRestTimerRow(duration: rest, accent: accent)
            }
            if let adaptive = lift.adaptive {
                adaptiveRow(adaptive)
                    .demoHighlight(runner.isTarget(.adaptiveHint(lift: index)), nudges: runner.nudges,
                                   inset: -4)
            }

            ForEach(Array(lift.sets.enumerated()), id: \.element.id) { setIndex, set in
                setRow(set, lift: index, index: setIndex)
            }

            Button {
                runner.attempt(.addSet(lift: index))
            } label: {
                Label("Add Set", systemImage: lift.sets.isEmpty ? "plus.circle.fill" : "plus.circle")
                    .fontWeight(lift.sets.isEmpty ? .semibold : .regular)
            }
            .demoHighlight(runner.isTarget(.addSet(lift: index)), nudges: runner.nudges)

            ExerciseActionsRow(onSwap: { runner.acknowledge(.liftActions(lift: index)) },
                               onRemove: { runner.acknowledge(.liftActions(lift: index)) })
                .demoHighlight(runner.isTarget(.liftActions(lift: index)), nudges: runner.nudges,
                               inset: -4)
        } header: {
            ExerciseSectionHeader(exercise: lift.exercise, targetRepRange: lift.repRange,
                                  accent: accent, onEdit: { _ in runner.nudge() })
                .textCase(nil)
        }
    }

    // Same wording, icon and color as the real AdaptiveHintRow.
    private func adaptiveRow(_ adaptive: WorkoutDemoAdaptive) -> some View {
        let weight = "\(Self.weightText(adaptive.weight)) lb"
        let increased = adaptive.delta > 0
        return Label {
            Text(increased ? "Suggested \(weight) · +\(Self.weightText(adaptive.delta)) from last time"
                           : "Suggested \(weight) · same as last time")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: increased ? "arrow.up.circle.fill" : "equal.circle.fill")
                .foregroundStyle(increased ? Color.green : accent)
        }
    }

    private static func weightText(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    private func restPicker(_ lift: WorkoutDemoLift, index: Int) -> some View {
        Picker(selection: Binding(get: { lift.restSeconds },
                                  set: { runner.attempt(.setRest(lift: index, seconds: $0)) })) {
            Text("None").tag(Int?.none)
            ForEach(RestDuration.options, id: \.self) { seconds in
                Text(RestDuration.label(seconds)).tag(Int?.some(seconds))
            }
        } label: {
            Label("Rest timer", systemImage: "timer")
        }
        .retintOnThemeChange(theme.current, salt: "demo-rest-\(index)")
        .demoHighlight(runner.isTarget(.restPicker(lift: index)), nudges: runner.nudges, inset: -4)
    }

    // CLAUDE  Date 09/27/2026
    // The real SetRow, inert (a tap is "fill this in" on the typing step), with the real
    // editor's swipes and long-press menu. Delete uses a red tint, not the destructive
    // role: that role animates the row out before the demo can refuse a wrong swipe.
    private func setRow(_ set: ExerciseSet, lift: Int, index: Int) -> some View {
        let done = set.completedAt != nil
        let target = WorkoutDemoTarget.setRow(lift: lift, set: index)
        return SetRow(number: index + 1, set: .constant(set), targetRange: state.lifts[lift].repRange,
                      accent: accent, focusedField: $focusedField)
            .demoInert { runner.acknowledge(target) }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    runner.attempt(.checkOffSet(lift: lift, set: index))
                } label: {
                    Label(done ? "Undo" : "Done", systemImage: done ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(done ? .gray : accent)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    runner.attempt(.deleteSet(lift: lift, set: index))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
            .contextMenu {
                Button {
                    runner.attempt(.checkOffSet(lift: lift, set: index))
                } label: {
                    Label(done ? "Mark Not Done" : "Mark Done",
                          systemImage: done ? "arrow.uturn.backward" : "checkmark")
                }
                Divider()
                Button(action: runner.nudge) { Label("Move Up", systemImage: "arrow.up") }
                    .disabled(index == 0)
                Button(action: runner.nudge) { Label("Move Down", systemImage: "arrow.down") }
                    .disabled(index == state.lifts[lift].sets.count - 1)
                Divider()
                Button(action: runner.nudge) {
                    Label("Reorder Sets…", systemImage: "arrow.up.arrow.down")
                }
                .disabled(state.lifts[lift].sets.count < 2)
                Divider()
                Button(role: .destructive) {
                    runner.attempt(.deleteSet(lift: lift, set: index))
                } label: {
                    Label("Delete Set", systemImage: "trash")
                }
            }
            .demoHighlight(runner.isTarget(target), nudges: runner.nudges, inset: -4)
    }

    private var bottomButtons: some View {
        Section {
            wideButton("Complete Workout", prominent: true, target: .complete) {
                runner.attempt(.completeWorkout)
            }
            if isPresetBacked && !state.lifts.isEmpty {
                wideButton("Override Preset", prominent: false, target: .overridePreset) {
                    runner.acknowledge(.overridePreset)
                }
            }
            if !state.lifts.isEmpty {
                wideButton("Save as New Preset", prominent: false, target: .saveAsPreset) {
                    runner.acknowledge(.saveAsPreset)
                }
            }
        }
    }

    @ViewBuilder
    private func wideButton(_ title: String, prominent: Bool, target: WorkoutDemoTarget,
                            action: @escaping () -> Void) -> some View {
        let label = Text(title).fontWeight(.semibold).frame(maxWidth: .infinity)
        Group {
            if prominent {
                Button(action: action) { label }.buttonStyle(.borderedProminent)
            } else {
                Button(action: action) { label }.buttonStyle(.bordered)
            }
        }
        .demoHighlight(runner.isTarget(target), nudges: runner.nudges, cornerRadius: 12, inset: -5)
        .listRowBackground(Color.clear)
    }
}

// CLAUDE  Date 09/26/2026
// Looks like RestTimerView, but counts down locally. The real one drives the shared
// WorkoutSession (mini bar, notifications), which a demo must never start.
private struct DemoRestTimerRow: View {
    let duration: Int
    let accent: Color

    @State private var endsAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = endsAt.map { max(0, Int($0.timeIntervalSince(context.date).rounded(.up))) } ?? 0
            let resting = remaining > 0
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(resting ? accent : .secondary)
                Text(resting ? "Resting \(RestDuration.label(remaining))"
                             : "Rest \(RestDuration.label(duration))")
                    .monospacedDigit()
                    .foregroundStyle(resting ? .primary : .secondary)
                Spacer()
                if resting {
                    Button("Skip") { endsAt = nil }
                        .buttonStyle(.bordered)
                } else {
                    Button {
                        endsAt = Date().addingTimeInterval(TimeInterval(duration))
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                }
            }
        }
        .onChange(of: duration) { _ in endsAt = nil }
    }
}

// MARK: - Exercise picker

// CLAUDE  Date 09/27/2026
// Copy of ExercisePickerView over the sample library, with a display-only search bar.
// Any lift completes the step; Cancel and + nudge, since the demo needs a lift picked.
struct DemoExercisePicker: View {
    let title: String
    let highlighted: Exercise.ID?
    let nudges: Int
    let onPick: (Exercise) -> Void
    let onNudge: () -> Void

    var body: some View {
        NavigationStack {
            List {
                DemoSearchField(prompt: "Search exercises")
                    .onTapGesture(perform: onNudge)
                ForEach(DemoSamples.library) { group in
                    Section(group.region.title) {
                        ForEach(group.exercises) { exercise in
                            row(exercise)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onNudge)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onNudge) {
                        Label("Create New", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        Button {
            onPick(exercise)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.displayLabel)
                        .foregroundStyle(.primary)
                    EquipmentBadge(type: exercise.equipmentType)
                }
                Text(exercise.muscleSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .demoHighlight(exercise.id == highlighted, nudges: nudges, inset: -4)
    }
}

private struct WorkoutDemoPicker: View {
    @ObservedObject var runner: DemoRunner<WorkoutDemoScript>

    var body: some View {
        DemoExercisePicker(title: "Add Exercise",
                           highlighted: runner.isTarget(.pickerRow) ? DemoSamples.benchPress.id : nil,
                           nudges: runner.nudges,
                           onPick: { runner.attempt(.pickExercise($0)) },
                           onNudge: runner.nudge)
    }
}
