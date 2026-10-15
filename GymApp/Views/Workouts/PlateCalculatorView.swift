import SwiftUI

// CLAUDE  Date 10/14/2026
// The full-page plate calculator opened from a lift's "Plates" button in the workout editor.
// Opens already loaded with the plates for the set's current weight; tap plates on or off (or
// type a target), then send the total to the set. Side effect: the bar / sled / sides choice is
// saved onto the Exercise when the page closes, so the next session starts from the same setup.
struct PlateCalculatorView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    let mode: PlateCalculatorMode
    /// The open set's number ("Set 3"), or nil when every set is done and Apply adds one.
    let targetSetNumber: Int?
    /// The number a newly added set would get, for the button when targetSetNumber is nil.
    let nextSetNumber: Int
    let onApply: (Double) -> Void

    @State private var setup: PlateSetup
    @State private var load: PlateLoad
    // The weight the load was solved for. Kept while the plates are untouched, so changing the
    // bar re-solves for the same weight; tapping a plate clears it and the plates win from then on.
    @State private var target: Double?
    @State private var note: String?
    @State private var isTypingTarget = false
    @State private var targetText = ""
    @FocusState private var targetFocused: Bool
    // Text behind the bar-weight and resistance fields, parsed into `setup` on every keystroke.
    // A value-formatted field only commits on blur, so Apply could read the number from before.
    @State private var customBarText: String
    @State private var resistanceText: String

    init(exercise: Exercise, mode: PlateCalculatorMode, startingWeight: Double,
         targetSetNumber: Int?, nextSetNumber: Int, onApply: @escaping (Double) -> Void) {
        self.exercise = exercise
        self.mode = mode
        self.targetSetNumber = targetSetNumber
        self.nextSetNumber = nextSetNumber
        self.onApply = onApply
        let initial = exercise.plateSetup ?? .defaultSetup(isUnilateral: exercise.isUnilateral)
        let solution = PlateMath.solve(target: startingWeight, base: initial.base(for: mode),
                                       sides: initial.sides(for: mode))
        _setup = State(initialValue: initial)
        _customBarText = State(initialValue: SetFormat.weight(initial.customBarWeight))
        _resistanceText = State(initialValue: SetFormat.weight(initial.startingResistance))
        _load = State(initialValue: solution.load)
        _target = State(initialValue: startingWeight > 0 ? startingWeight : nil)
        _note = State(initialValue: Self.noteText(for: solution, target: startingWeight, mode: mode))
    }

    private var accent: Color { theme.current.accent }
    private var base: Double { setup.base(for: mode) }
    private var sides: Int { setup.sides(for: mode) }
    private var total: Double { PlateMath.total(base: base, sides: sides, load: load) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 22) {
                    totalReadout
                    PlateStage(mode: mode, bar: setup.bar, load: load, sides: sides,
                               surface: theme.current.surface)
                    setupControls
                    plateGrid
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { applyButton }
        .background(theme.current.background.ignoresSafeArea())
        .selectAllWhenEditingNumberFields()
        .onChange(of: setup) { _ in setupChanged() }
        .onChange(of: customBarText) { setup.customBarWeight = Self.parse($0) }
        .onChange(of: resistanceText) { setup.startingResistance = Self.parse($0) }
        .onChange(of: targetFocused) { focused in
            if !focused { commitTarget() }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                close()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .fontWeight(.semibold)
            }
            Spacer()
            Button("Clear") {
                Haptics.soften()
                load = PlateLoad()
                target = nil
                note = nil
            }
            .disabled(load.isEmpty)
        }
        .overlay {
            Text(exercise.name)
                .font(.headline)
                .lineLimit(1)
                .padding(.horizontal, 90)
        }
        .tint(accent)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Total

    // The big number. Tapping it swaps in a field to type a target weight, which re-solves
    // the plates; the breakdown and any "closest you can load" note sit underneath.
    private var totalReadout: some View {
        VStack(spacing: 6) {
            if isTypingTarget {
                HStack(spacing: 8) {
                    TextField("Target", text: $targetText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40, weight: .bold).monospacedDigit())
                        .focused($targetFocused)
                        .frame(maxWidth: 180)
                        // Focus once the field exists; setting it in the same tap that
                        // creates the field can land before there's anything to focus.
                        .onAppear { targetFocused = true }
                    Text("lb")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Button("Load") { commitTarget() }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                }
            } else {
                Button {
                    targetText = SetFormat.weight(total)
                    isTypingTarget = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(SetFormat.weight(total))
                            .font(.system(size: 56, weight: .bold).monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: total)
                        Text("lb")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Total \(SetFormat.weight(total)) pounds")
                .accessibilityHint("Tap to type a target weight")
            }

            Text(breakdown)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // "45 lb bar + 90 per side", or for a machine "70 start + 90 per side".
    private var breakdown: String {
        let perSleeve = SetFormat.weight(load.perSleeve)
        switch mode {
        case .barbell:
            let bar = SetFormat.weight(base)
            return load.isEmpty ? "Just the \(bar) lb bar" : "\(bar) lb bar + \(perSleeve) per side"
        case .machine:
            let plates = sides == 1 ? "\(perSleeve) on the sleeve" : "\(perSleeve) per side"
            if base == 0 { return load.isEmpty ? "No plates loaded" : plates }
            let start = "\(SetFormat.weight(base)) start"
            return load.isEmpty ? "Just the \(start)" : "\(start) + \(plates)"
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch mode {
            case .barbell:
                Picker("Bar", selection: $setup.bar) {
                    Text("Olympic 45").tag(BarChoice.olympic)
                    Text("EZ 20").tag(BarChoice.ez)
                    Text("Custom").tag(BarChoice.custom)
                }
                .pickerStyle(.segmented)

                if setup.bar == .custom {
                    weightField("Bar weight", text: $customBarText)
                }
            case .machine:
                weightField("Starting resistance", text: $resistanceText)
                Text("The sled or carriage weight. Leave it at 0 to log plates only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Plates go on", selection: $setup.loadedSides) {
                    Text("Both sides").tag(2)
                    Text("One side").tag(1)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(14)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func weightField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text("lb")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Plates

    // One tile per plate size. Tap adds one to each side; the minus badge takes one back off.
    private var plateGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .machine && sides == 1 ? "Plates on the sleeve" : "Plates per side")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                      spacing: 10) {
                ForEach(PlateMath.plates.indices, id: \.self) { index in
                    plateTile(index)
                }
            }
        }
    }

    private func plateTile(_ index: Int) -> some View {
        let plate = PlateMath.plates[index]
        let count = load.counts[index]
        return Button {
            Haptics.tap()
            setPlate(index, count: count + 1)
        } label: {
            VStack(spacing: 2) {
                Text(SetFormat.weight(plate))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text(count == 0 ? "lb" : "× \(count)")
                    .font(.caption.weight(count == 0 ? .regular : .semibold))
                    .foregroundStyle(count == 0 ? Color.secondary : accent)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(theme.current.surface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(count == 0 ? Color.clear : accent, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                Button {
                    Haptics.soften()
                    setPlate(index, count: count - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(accent)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove a \(SetFormat.weight(plate)) pound plate")
            }
        }
        .accessibilityLabel("\(SetFormat.weight(plate)) pound plate")
        .accessibilityValue("\(count) per side")
        .accessibilityHint("Adds one to each side")
    }

    // MARK: - Apply

    private var applyButton: some View {
        Button {
            // A target still being typed counts, so the button never applies the old total.
            commitTarget()
            persistSetupIfChanged()
            onApply(total)
            dismiss()
        } label: {
            Text(applyTitle)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(accent)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(theme.current.background.ignoresSafeArea())
    }

    private var applyTitle: String {
        let weight = "\(SetFormat.weight(total)) lb"
        if let targetSetNumber { return "Use \(weight) on Set \(targetSetNumber)" }
        return "Add Set \(nextSetNumber) at \(weight)"
    }

    // MARK: - Actions

    private func setPlate(_ index: Int, count: Int) {
        load.counts[index] = max(0, count)
        target = nil
        note = nil
    }

    private func commitTarget() {
        guard isTypingTarget else { return }
        isTypingTarget = false
        targetFocused = false
        let trimmed = targetText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        resolve(for: Self.parse(trimmed))
    }

    // Typed number to pounds: a comma decimal works, and blank, junk or negative reads as 0.
    private static func parse(_ text: String) -> Double {
        max(0, Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    private func resolve(for weight: Double) {
        let solution = PlateMath.solve(target: weight, base: base, sides: sides)
        load = solution.load
        target = weight > 0 ? weight : nil
        note = Self.noteText(for: solution, target: weight, mode: mode)
    }

    // A bar or sled change keeps the weight the plates were solved for, if they're untouched;
    // otherwise the plates stay put and the total moves.
    private func setupChanged() {
        if let target { resolve(for: target) }
    }

    private func close() {
        persistSetupIfChanged()
        dismiss()
    }

    // Re-reads the lift so a stale snapshot can't overwrite edits made elsewhere, and writes only
    // when the setup actually differs from what this lift would start with anyway.
    private func persistSetupIfChanged() {
        guard var current = store.exercise(for: exercise.id) else { return }
        let stored = current.plateSetup ?? .defaultSetup(isUnilateral: current.isUnilateral)
        guard setup != stored else { return }
        current.plateSetup = setup
        store.updateExercise(current)
    }

    // The quiet line under the total after a solve: lighter than the bar, or not makeable exactly.
    private static func noteText(for solution: PlateMath.Solution, target: Double,
                                 mode: PlateCalculatorMode) -> String? {
        if solution.belowBase {
            let what = mode == .barbell ? "the bar" : "the starting resistance"
            return "\(SetFormat.weight(target)) lb is lighter than \(what)."
        }
        if solution.shortBy > 0 {
            return "Closest you can load is \(SetFormat.weight(solution.total)) lb, "
                + "\(SetFormat.weight(solution.shortBy)) under \(SetFormat.weight(target))."
        }
        return nil
    }
}
