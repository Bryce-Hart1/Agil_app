import SwiftUI

// Claude  Date 08/06/2026
// The amount control, shared by the food detail page and the diary's entry editor.
//
// Layout, top to bottom: a two-tab picker (Serving | Weight, or Serving | Volume for a
// liquid), a row of one-tap preset amounts, the editable amount field + stepper, and a
// row carrying the unit chips (g · oz · lb / cup · fl oz · mL) with the "≈ …" base-unit
// note on its trailing edge.
//
// Two rules the whole thing is built around:
//  • Switching units or tabs CONVERTS the amount rather than resetting it. Re-dialing a
//    number you already typed is the kind of friction that stops people tracking, so
//    100 g becomes 3.5 oz and 1 serving of a 170 g food becomes 170 g.
//  • Weight and volume never mix. Crossing them needs a density the food data doesn't
//    carry, so a food gets exactly one family (see FoodUnit.family).
//
// It edits a FoodMeasurement binding directly — the measurement IS the state, so which
// tab is showing is derived (`unit == nil` means serving mode) rather than tracked
// separately and kept in sync. The owner reads the same binding back for logging.
struct MeasurementEditor: View {
    // The food's shape: which units it offers, what a serving weighs.
    let basis: MeasurementBasis
    @Binding var measurement: FoodMeasurement
    var accent: Color

    // The field's raw text, parsed into the measurement on every keystroke. A
    // value-typed TextField only commits when focus resigns, and the decimal pad has
    // no return key — so a typed "173" could be silently dropped by the Add button.
    // Text is what the user edits; the amount only moves on a successful parse, so a
    // half-typed or cleared field never logs garbage.
    @State private var amountText: String = "1"
    // The unit to return to when coming back from the Serving tab, so switching
    // Weight → Serving → Weight doesn't forget that you were working in ounces.
    @State private var lastUnit: FoodUnit = .gram
    @FocusState private var amountFocused: Bool

    private enum EntryMode: Hashable { case serving, unit }

    // Derived, not stored: a measurement with no unit IS a serving count.
    private var mode: EntryMode { measurement.unit == nil ? .serving : .unit }

    // A count food gets no tabs (its only amount is a count of its opaque servings, so
    // a one-option picker is noise); a food with a known serving size gets both; one
    // without gets the unit tab alone.
    private var availableModes: [EntryMode] {
        if basis.isCountBased { return [] }
        return basis.servingQuantity != nil ? [.serving, .unit] : [.unit]
    }

    private var unitFamily: [FoodUnit] { FoodUnit.family(forBasisUnit: basis.basisUnit) }

    var body: some View {
        VStack(spacing: 10) {
            if availableModes.count > 1 {
                // The binding is custom rather than a `selection:` + `.onChange` pair:
                // onChange also fires when the OWNER seeds a restored measurement, which
                // would convert (or reset) an amount the user never touched.
                Picker("Amount", selection: Binding(get: { mode },
                                                    set: { switchMode(to: $0) })) {
                    ForEach(availableModes, id: \.self) { m in
                        Text(modeTitle(m)).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }
            quantityControls
        }
        .onAppear {
            amountText = FoodMeasurement.number(measurement.amount)
            lastUnit = measurement.unit ?? FoodUnit.baseUnit(forBasisUnit: basis.basisUnit)
        }
        // The owner can seed a new amount after this view exists (a restored cache, a
        // reset). Only follow it when the field isn't being typed into.
        .onChange(of: measurement.amount) { newValue in
            guard !amountFocused,
                  abs((Self.parseAmount(amountText) ?? -1) - newValue) > 0.0001 else { return }
            amountText = FoodMeasurement.number(newValue)
        }
    }

    // MARK: - Controls

    private var quantityControls: some View {
        VStack(spacing: 8) {
            if !quickAmounts.isEmpty { quickChips }
            HStack(spacing: 10) {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: amountText) { newValue in
                        if let v = Self.parseAmount(newValue) { measurement.amount = v }
                    }
                    .toolbar {
                        // The decimal pad has no return key, so give it an explicit Done.
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { amountFocused = false }
                        }
                    }
                Text(unitNoun)
                    .fontWeight(.medium)
                Spacer(minLength: 4)
                Stepper("", value: Binding(get: { measurement.amount },
                                           set: { setAmount($0) }),
                        in: quantityRange, step: quantityStep)
                    .labelsHidden()
            }
            // Unit chips and the "≈" note share a line — chips leading, note trailing.
            // The chips are deliberately NOT inline with the field: field + 3 chips +
            // stepper overflows an SE-width screen, and sharing this row means they
            // cost no extra vertical space on the foods that show a note anyway.
            if showsUnitChips || equivalentNote != nil {
                HStack(spacing: 8) {
                    if showsUnitChips { unitChips }
                    Spacer(minLength: 4)
                    if let note = equivalentNote {
                        Text(note)
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
    }

    // Chips only exist where there's a choice: the unit tab of a weight/volume food.
    private var showsUnitChips: Bool { mode == .unit && !basis.isCountBased }

    // The unit family as small tappable capsules.
    private var unitChips: some View {
        HStack(spacing: 4) {
            ForEach(unitFamily, id: \.self) { unit in
                let selected = unit == measurement.unit
                Button { selectUnit(unit) } label: {
                    Text(unit.abbreviation)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(selected ? accent : Color.secondary.opacity(0.12),
                                    in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(unit.label(count: 2))
            }
        }
    }

    // One-tap presets for the current unit. The chip matching the current amount fills
    // with the accent color.
    private var quickChips: some View {
        HStack(spacing: 8) {
            ForEach(quickAmounts, id: \.self) { amount in
                let selected = abs(measurement.amount - amount) < 0.0001
                Button {
                    setAmount(amount)
                    amountFocused = false
                } label: {
                    Text(Self.chipLabel(amount))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(selected ? accent : Color.secondary.opacity(0.12),
                                    in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Mutations

    // Keep the amount and the field text in sync (chips, stepper, conversions).
    private func setAmount(_ value: Double) {
        measurement.amount = value
        amountText = FoodMeasurement.number(value)
    }

    // Claude  Date 08/06/2026
    // Tab switch. The amount carries across: opening a 170 g yogurt's Weight tab shows
    // 170 g, not a generic 100. Both directions are always defined — the Serving tab
    // only exists when servingQuantity is known.
    private func switchMode(to newMode: EntryMode) {
        guard newMode != mode else { return }
        amountFocused = false
        let per = basis.servingQuantity ?? 100
        switch newMode {
        case .unit:
            let base = measurement.amount * per                    // servings → g/ml
            measurement.unit = lastUnit
            measurement.servingNoun = nil
            setAmount(Self.rounded(base / lastUnit.perBase, places: lastUnit.displayPrecision))
        case .serving:
            let unit = measurement.unit ?? FoodUnit.baseUnit(forBasisUnit: basis.basisUnit)
            let base = measurement.amount * unit.perBase           // units → g/ml
            lastUnit = unit
            measurement.unit = nil
            measurement.servingNoun = basis.servingUnit ?? "serving"
            setAmount(Self.rounded(base / per, places: 2))
        }
    }

    // Chip tap: switch unit and convert in place, so 100 g becomes 3.5 oz rather than a
    // meaningless 100 oz. Rounded to the unit's display precision — this and the tab
    // switch are the ONLY places amounts get rounded; typed input never is.
    private func selectUnit(_ newUnit: FoodUnit) {
        guard let current = measurement.unit, current != newUnit else { return }
        let converted = current.convert(measurement.amount, to: newUnit) ?? measurement.amount
        measurement.unit = newUnit
        lastUnit = newUnit
        setAmount(Self.rounded(converted, places: newUnit.displayPrecision))
        amountFocused = false
    }

    // MARK: - Per-unit tables

    // The preset amounts for the current unit — the values people actually eat/pour, so
    // most logs are a single tap. Each unit gets its own set: 50/100/150/200 would be
    // absurd chips for pounds.
    private var quickAmounts: [Double] {
        if basis.isCountBased || mode == .serving { return [0.5, 1, 1.5, 2] }
        switch measurement.unit {
        case .gram:       return [50, 100, 150, 200]
        case .ounce:      return [1, 2, 4, 8]
        case .pound:      return [0.25, 0.5, 1, 2]
        case .cup:        return [0.25, 0.5, 1, 2]
        case .fluidOunce: return [8, 12, 16]
        case .milliliter: return [100, 250, 330, 500]
        case nil:         return [0.5, 1, 1.5, 2]
        }
    }

    private var quantityStep: Double {
        if basis.isCountBased || mode == .serving { return 0.25 }
        switch measurement.unit {
        case .gram:       return 5
        case .ounce:      return 0.5
        case .pound:      return 0.25
        case .cup:        return 0.25
        case .fluidOunce: return 1
        case .milliliter: return 10
        case nil:         return 0.25
        }
    }

    private var quantityRange: ClosedRange<Double> {
        if basis.isCountBased || mode == .serving { return 0.25...50 }
        switch measurement.unit {
        case .gram:       return 1...2000
        case .ounce:      return 0.25...70
        case .pound:      return 0.05...10
        case .cup:        return 0.25...20
        case .fluidOunce: return 1...64
        case .milliliter: return 10...2000
        case nil:         return 0.25...50
        }
    }

    // MARK: - Labels

    // The unit tab is named for the FAMILY, not a unit — calling it "Grams" was wrong
    // the moment the tab could also hold oz and lb.
    private func modeTitle(_ m: EntryMode) -> String {
        switch m {
        case .serving: return "Serving"
        case .unit:    return basis.basisUnit == "ml" ? "Volume" : "Weight"
        }
    }

    // The unit word beside the amount field.
    private var unitNoun: String {
        if let unit = measurement.unit { return unit.label(count: measurement.amount) }
        return FoodMeasurement.pluralize(measurement.servingNoun ?? "serving",
                                         count: measurement.amount)
    }

    // "≈ …" note: a derived unit (oz/lb, cup/fl oz) shows its equivalent in the food's
    // base unit, and a serving shows its weight/volume. Grams and mL ARE the base unit,
    // so they need none.
    private var equivalentNote: String? {
        if basis.isCountBased { return nil }
        let amount = max(0, measurement.amount)
        if let unit = measurement.unit {
            guard unit.perBase != 1 else { return nil }
            return "≈ \(FoodMeasurement.number(amount * unit.perBase, decimals: 1)) \(basis.basisUnit)"
        }
        guard let per = basis.servingQuantity else { return nil }
        return "≈ \(FoodMeasurement.number(amount * per)) \(basis.basisUnit)"
    }

    // MARK: - Helpers

    // Chip text: common fractions get real glyphs ("½", "1½") so the row reads like a
    // measuring cup, not a calculator.
    static func chipLabel(_ value: Double) -> String {
        let whole = Int(value.rounded(.down))
        let glyph: String?
        switch value - Double(whole) {
        case 0.25: glyph = "¼"
        case 0.5:  glyph = "½"
        case 0.75: glyph = "¾"
        default:   glyph = nil
        }
        guard let glyph else { return FoodMeasurement.number(value) }
        return whole == 0 ? glyph : "\(whole)\(glyph)"
    }

    // Lenient decimal parse: trims, accepts a comma decimal separator, rejects
    // zero/negative/garbage (nil → the last good value stays).
    static func parseAmount(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0, value.isFinite else { return nil }
        return value
    }

    // Round to a fixed number of places — used only when an amount ARRIVES via a
    // conversion, so 100 g reads as "3.5 oz" and not "3.5274 oz".
    static func rounded(_ value: Double, places: Int) -> Double {
        let scale = pow(10.0, Double(places))
        return (value * scale).rounded() / scale
    }
}

#if DEBUG
private struct MeasurementEditorHarness: View {
    let basis: MeasurementBasis
    @State var measurement: FoodMeasurement

    var body: some View {
        MeasurementEditor(basis: basis, measurement: $measurement, accent: .pink)
            .padding()
    }
}

// Claude  Date 08/06/2026
// The three shapes a food can take, so the tab/chip logic is checkable in the canvas.
#Preview("Solid · 170 g serving") {
    MeasurementEditorHarness(
        basis: MeasurementBasis(per100: .zero, basisUnit: "g", servingQuantity: 170),
        measurement: FoodMeasurement(amount: 1, servingNoun: "serving"))
}

#Preview("Liquid · volume units") {
    MeasurementEditorHarness(
        basis: MeasurementBasis(per100: .zero, basisUnit: "ml", servingQuantity: 240),
        measurement: FoodMeasurement(amount: 1, unit: .cup))
}

#Preview("Count food · no tabs") {
    MeasurementEditorHarness(
        basis: MeasurementBasis(per100: .zero, basisUnit: "g", servingUnit: "bar"),
        measurement: FoodMeasurement(amount: 1, servingNoun: "bar"))
}
#endif
