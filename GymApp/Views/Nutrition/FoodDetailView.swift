import SwiftUI
import UIKit

// Claude  Date 07/14/2026 last changed: 07/16/2026 by: Claude
// The food detail page that pops when you scan an item or tap one in Foods. Shows the
// backend DTO in full: name/brand, a provenance (source) badge and category chip, a
// serving/unit selector with quick-amount chips, the macro block, and the sparse
// micronutrients grouped into Fats / Vitamins / Minerals.
//
// Contract rules it honors:
//  • Everything is per 100 g/ml; a serving scales by servingQuantity / 100. When
//    servingQuantity is nil there's no serving option — per-100 only, nothing fabricated.
//  • Units are fixed per field (from MicroField), never derived.
//  • A nil micro renders "—" / not available; a real 0 renders "0".
//
// Store-free: the view never touches AppStore directly. A caller opts into logging by
// passing `onLog` — the page then shows a meal picker + "Add" bar and, on tap, hands
// back the chosen meal and the consumed nutrients for the dialed-in amount so the
// caller does the actual diary write. Without `onLog` (and without a primary action)
// the page is pure info.
//
// (Reworked for speed: no NavigationStack of its own anymore, so it can be pushed from
// the diary picker or wrapped in a stack for sheets. Opens on 1 serving, serving counts
// are adjustable, quick chips cover common amounts without the keyboard, and the typed
// amount commits live on every keystroke — see `amountText`.)
struct FoodDetailView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let food: FoodDetail
    // Optional call-to-action shown as a bottom bar button (title + handler). Nil = the
    // page is pure info. Ignored when `onLog` is provided.
    var primaryActionTitle: String? = nil
    var onPrimaryAction: (() -> Void)? = nil

    // Claude  Date 07/16/2026
    // Meal to preselect in the log bar. The diary picker passes the meal the user is
    // adding to; nil (Foods tab / scan) falls back to the time-of-day guess.
    var initialMeal: MealType? = nil

    // Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
    // Logging hook. When non-nil the page shows a meal picker + "Add to <meal>" bar; on
    // tap it fires with the selected meal and the nutrients consumed for the current
    // amount (per-100 already scaled by `factor`). Nil = no logging affordance.
    // (Declared last so call sites can keep passing it as a trailing closure.)
    var onLog: ((MealType, Nutrients) -> Void)? = nil

    // Which meal the "Add" bar logs into. Seeded on appear (see `initialMeal`).
    @State private var selectedMeal: MealType = .snack

    // Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
    // Which reference amount the numbers are shown against. `serving` and `servingCount`
    // are a count of servings; `gram` (log by grams) is offered for solids, the volume
    // units (cup/mL/oz) only for liquids (basisUnit == "ml"); `per100` is the fixed
    // reference view. Every basis except per100 carries a user-chosen `unitQuantity`
    // (how many grams/cups/servings, etc.) — reduced to a per-100 scale factor.
    // (`serving` used to be pinned at exactly 1; it's now quantitative like the rest so
    // "2 servings" is a stepper tap, not gram arithmetic.)
    private enum ServingBasis: Hashable {
        case per100, serving, gram, cup, milliliter, ounce, servingCount
    }

    @State private var basis: ServingBasis = .per100
    // How many of the selected quantitative unit (servings / grams / cups / mL / oz).
    // Ignored for the fixed per100 basis.
    @State private var unitQuantity: Double = 1

    // Claude  Date 07/16/2026
    // The amount field's raw text, parsed into `unitQuantity` on every keystroke. The
    // old value-typed TextField only committed when focus resigned — with a decimal pad
    // (no return key) a typed "173" could get silently dropped by "Add". Text is the
    // source the user edits; `unitQuantity` only moves on a successful parse, so a
    // half-typed or cleared field never logs garbage. Chips/stepper/basis changes write
    // back through `setQuantity` to keep the two in sync.
    @State private var amountText: String = "1"
    @FocusState private var amountFocused: Bool

    // Claude  Date 07/15/2026
    // ml in one of each volume unit. 1 cup ≈ 240 ml; 1 US fluid ounce ≈ 29.574 ml (so
    // oz = ml / 29.574).
    private static let mlPerCup = 240.0
    private static let mlPerOunce = 29.574

    // Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
    // The bases offered for this food. A count-based food (no g/ml basis) offers only a
    // servings count. Otherwise: serving first (the default view) when the DTO gave a
    // size; cup/mL/oz for liquids, an editable gram amount for solids; per-100 last as
    // the reference view.
    private var bases: [ServingBasis] {
        if food.isCountBased { return [.servingCount] }
        var out: [ServingBasis] = []
        if food.servingQuantity != nil { out.append(.serving) }
        if food.basisUnit == "ml" {
            out += [.cup, .milliliter, .ounce]
        } else {
            out.append(.gram)
        }
        out.append(.per100)
        return out
    }

    // Every basis except the fixed per-100 reference lets the user pick how many.
    private func isQuantitative(_ b: ServingBasis) -> Bool { b != .per100 }

    private func mlPerUnit(_ b: ServingBasis) -> Double {
        switch b {
        case .cup:         return Self.mlPerCup
        case .ounce:       return Self.mlPerOunce
        case .milliliter:  return 1
        default:           return 0
        }
    }

    // Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
    // Scale factor applied to every reference value in the current basis. Grams and mL
    // are the per-100 base unit itself (amount / 100); cup/oz convert through ml first;
    // a serving is unitQuantity servings of servingQuantity g/ml each. In count mode
    // `per100` is already one serving, so the factor is just the servings count.
    private var factor: Double {
        switch basis {
        case .per100:  return 1
        case .serving: return max(0, unitQuantity) * (food.servingQuantity ?? 100) / 100
        case .gram, .milliliter:
            return max(0, unitQuantity) / 100
        case .cup, .ounce:
            return max(0, unitQuantity) * mlPerUnit(basis) / 100
        case .servingCount:
            return max(0, unitQuantity)
        }
    }

    private var accent: Color { theme.current.accent }
    private var surface: Color { theme.current.surface }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if bases.count > 1 || isQuantitative(basis) { basisSelector }
                macrosCard
                ForEach(MicroGroup.allCases) { group in
                    microCard(group)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle("Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Claude  Date 07/16/2026
            // The decimal pad has no return key, so give it an explicit Done.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .themed(theme.current)
        .onAppear {
            // Preselect the meal: the caller's context wins, else the time of day.
            selectedMeal = initialMeal ?? Self.mealForNow()
            // Open on the food's natural basis — 1 serving when a size is known,
            // .servingCount for count foods, per-100 otherwise.
            basis = bases.first ?? .per100
            if isQuantitative(basis) { setQuantity(defaultQuantity(basis)) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(food.name)
                .font(.title2).fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)
            if !food.brand.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(food.brand).font(.subheadline).foregroundStyle(.secondary)
            }
            // Claude  Date 07/14/2026 last changed: 08/04/2026 by: Claude
            // Provenance + category. The source badge (and its stacked verification
            // badge, for generic/restaurant foods) now comes from the shared
            // FoodSourceBadge so the detail page and every list row agree.
            HStack(spacing: 8) {
                FoodSourceBadge(source: food.source,
                                verification: food.verification,
                                style: .detail)
                categoryChip
                Spacer(minLength: 0)
            }
            if let code = food.barcode, !code.isEmpty {
                Text(code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var categoryChip: some View {
        // Always show a chip (generic icon when category is nil), per the contract's
        // "always have a fallback/generic icon".
        let lead = food.category?.split(separator: ",").first
            .map { $0.trimmingCharacters(in: .whitespaces) }
        Label(lead ?? "Food", systemImage: food.categoryIcon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    // MARK: - Basis selector

    // Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
    // The segmented unit picker (hidden when there's only one basis, e.g. a count food),
    // plus the amount controls for any quantitative basis. Switching bases seeds a
    // sensible starting amount and drops the keyboard.
    private var basisSelector: some View {
        VStack(spacing: 10) {
            if bases.count > 1 {
                Picker("Amount", selection: $basis) {
                    ForEach(bases, id: \.self) { b in
                        Text(basisShortTitle(b)).tag(b)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: basis) { newValue in
                    amountFocused = false
                    if isQuantitative(newValue) { setQuantity(defaultQuantity(newValue)) }
                }
            }

            if isQuantitative(basis) { quantityControls }
        }
    }

    // Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
    // The amount controls: quick chips for the common amounts (one tap, no keyboard),
    // then an editable field (type an exact value, e.g. 173 g off a label) paired with
    // a +/- stepper. The field parses live — see `amountText`. Below, a small "≈ …"
    // note shows the equivalent in the base unit where it isn't obvious (cup/oz → ml,
    // servings → g/ml).
    private var quantityControls: some View {
        VStack(spacing: 8) {
            if !quickAmounts(basis).isEmpty { quickChips }
            HStack(spacing: 10) {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: amountText) { newValue in
                        if let v = Self.parseAmount(newValue) { unitQuantity = v }
                    }
                Text(unitNoun(basis, count: unitQuantity))
                    .fontWeight(.medium)
                Spacer()
                Stepper("", value: Binding(get: { unitQuantity },
                                           set: { setQuantity($0) }),
                        in: quantityRange(basis), step: quantityStep(basis))
                    .labelsHidden()
            }
            if let note = equivalentNote {
                HStack {
                    Spacer()
                    Text(note)
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    // Claude  Date 07/16/2026
    // One-tap presets for the current unit. Tapping sets the amount and dismisses the
    // keyboard; the chip matching the current amount fills with the accent color.
    private var quickChips: some View {
        HStack(spacing: 8) {
            ForEach(quickAmounts(basis), id: \.self) { amount in
                let selected = abs(unitQuantity - amount) < 0.0001
                Button {
                    setQuantity(amount)
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

    // Claude  Date 07/16/2026
    // The preset amounts per unit — the values people actually eat/pour, so most logs
    // are a single tap. Empty for the fixed per-100 reference view.
    private func quickAmounts(_ b: ServingBasis) -> [Double] {
        switch b {
        case .serving, .servingCount: return [0.5, 1, 1.5, 2]
        case .gram:                   return [50, 100, 150, 200]
        case .milliliter:             return [100, 250, 330, 500]
        case .cup:                    return [0.5, 1, 2]
        case .ounce:                  return [8, 12, 16]
        case .per100:                 return []
        }
    }

    // Claude  Date 07/16/2026
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
        guard let glyph else { return number(value) }
        return whole == 0 ? glyph : "\(whole)\(glyph)"
    }

    // Claude  Date 07/16/2026
    // Sync `unitQuantity` and the field text together (chips, stepper, basis switches).
    private func setQuantity(_ value: Double) {
        unitQuantity = value
        amountText = Self.number(value)
    }

    // Claude  Date 07/16/2026
    // Lenient decimal parse for the amount field: trims, accepts a comma decimal
    // separator, rejects zero/negative/garbage (nil → the last good value stays).
    static func parseAmount(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0, value.isFinite else { return nil }
        return value
    }

    // Claude  Date 07/16/2026
    // "≈ …" conversion note under the amount: cup/oz show their ml equivalent, a
    // serving shows its weight/volume (from servingQuantity). Grams and mL are already
    // the base unit so they need none.
    private var equivalentNote: String? {
        switch basis {
        case .cup, .ounce:
            return "≈ \(Self.number(max(0, unitQuantity) * mlPerUnit(basis))) ml"
        case .serving:
            guard let per = food.servingQuantity else { return nil }
            return "≈ \(Self.number(max(0, unitQuantity) * per)) \(food.basisUnit)"
        default:
            return nil
        }
    }

    // Short label for the segmented control.
    private func basisShortTitle(_ b: ServingBasis) -> String {
        switch b {
        case .per100:       return "100 \(food.basisUnit)"
        case .serving:      return "Serving"
        case .gram:         return "Grams"
        case .cup:          return "Cup"
        case .milliliter:   return "mL"
        case .ounce:        return "oz"
        case .servingCount: return (food.servingUnit ?? "Serving").capitalized
        }
    }

    // Singular/plural unit word for the amount field.
    private func unitNoun(_ b: ServingBasis, count: Double) -> String {
        switch b {
        case .serving:      return Self.pluralize("serving", count: count)
        case .gram:         return "g"
        case .cup:          return count == 1 ? "cup" : "cups"
        case .milliliter:   return "mL"
        case .ounce:        return count == 1 ? "oz" : "oz"
        case .servingCount: return Self.pluralize(food.servingUnit ?? "serving", count: count)
        default:            return ""
        }
    }

    // Claude  Date 07/15/2026
    // Naive pluralization for a count serving noun ("bar" → "bars"), enough for the
    // free-text units a custom food can carry. Leaves an already-plural noun alone.
    static func pluralize(_ noun: String, count: Double) -> String {
        guard count != 1, !noun.isEmpty, !noun.hasSuffix("s") else { return noun }
        return noun + "s"
    }

    // Starting quantity when a quantitative unit is first picked. Grams seed to one
    // serving's weight when known, else 100 g.
    private func defaultQuantity(_ b: ServingBasis) -> Double {
        switch b {
        case .gram:        return food.servingQuantity ?? 100
        case .cup:         return 1
        case .milliliter:  return 250
        case .ounce:       return 8
        default:           return 1
        }
    }

    private func quantityStep(_ b: ServingBasis) -> Double {
        switch b {
        case .serving:     return 0.25
        case .gram:        return 5
        case .cup:         return 0.25
        case .milliliter:  return 10
        case .ounce:       return 1
        default:           return 1
        }
    }

    private func quantityRange(_ b: ServingBasis) -> ClosedRange<Double> {
        switch b {
        case .serving:      return 0.25...50
        case .gram:         return 1...2000
        case .cup:          return 0.25...20
        case .milliliter:   return 10...2000
        case .ounce:        return 1...64
        case .servingCount: return 0.25...50
        default:            return 1...1
        }
    }

    // MARK: - Macros

    private var macrosCard: some View {
        let n = food.per100.scaled(by: factor)
        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Self.number(n.calories))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                Text("kcal").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text(basisCaption).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            VStack(spacing: 0) {
                macroRow("Protein", n.protein, "g", tint: MacroPalette.protein)
                macroRow("Carbs",   n.carbs,   "g", tint: MacroPalette.carbs)
                macroRow("Fat",     n.fat,     "g", tint: MacroPalette.fat)
                macroRow("Fiber",   n.fiber,   "g", tint: MacroPalette.fiber)
                macroRow("Sugar",   n.sugar,   "g", tint: MacroPalette.sugar)
                macroRow("Sodium",  n.sodium, "mg", tint: MacroPalette.sodium, last: true)
            }
        }
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: factor)
    }

    // Caption under the calorie number describing the current reference amount.
    private var basisCaption: String {
        switch basis {
        case .per100:      return "per 100 \(food.basisUnit)"
        case .serving, .gram, .cup, .milliliter, .ounce, .servingCount:
            return "per \(Self.number(unitQuantity)) \(unitNoun(basis, count: unitQuantity))"
        }
    }

    private func macroRow(_ label: String, _ value: Double, _ unit: String,
                          tint: Color, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                iconChip(macroIcon(label), tint: tint)
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Self.number(value)) \(unit)")
                    .font(.subheadline).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            if !last { Divider() }
        }
    }

    private func macroIcon(_ label: String) -> String {
        switch label {
        case "Protein": return "figure.strengthtraining.traditional"
        case "Carbs":   return "bolt.fill"
        case "Fat":     return "drop.fill"
        case "Fiber":   return "leaf.fill"
        case "Sugar":   return "cube.fill"
        case "Sodium":  return "circle.grid.3x3.fill"
        default:        return "circle.fill"
        }
    }

    // MARK: - Micros

    private func microCard(_ group: MicroGroup) -> some View {
        let fields = MicroField.fields(in: group)
        // Claude  Date 07/15/2026
        // When the whole group came up blank (every value nil), collapse the rows into a
        // single "None" line under the header instead of a wall of "—".
        let allEmpty = fields.allSatisfy { $0.value(food.micros) == nil }
        return VStack(alignment: .leading, spacing: 0) {
            Text(group.rawValue)
                .font(.headline)
                .padding(.bottom, 8)
            if allEmpty {
                Text("None")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(fields.enumerated()), id: \.element.id) { idx, field in
                    microRow(field, last: idx == fields.count - 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func microRow(_ field: MicroField, last: Bool) -> some View {
        let raw = field.value(food.micros)
        return VStack(spacing: 0) {
            HStack {
                Text(field.label)
                    .font(.subheadline)
                    .foregroundStyle(raw == nil ? .secondary : .primary)
                Spacer()
                Text(microValueString(raw, unit: field.unit))
                    .font(.subheadline).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 7)
            if !last { Divider() }
        }
    }

    // nil → "—" (not available). A real value is scaled by the current basis factor and
    // shown with its fixed unit. A genuine 0 stays "0 <unit>".
    private func microValueString(_ raw: Double?, unit: String) -> String {
        guard let raw else { return "—" }
        return "\(Self.number(raw * factor)) \(unit)"
    }

    // MARK: - Bottom bar

    // Claude  Date 07/15/2026
    // Logging takes precedence: with an `onLog` handler the bar is a meal picker + an
    // "Add to <meal>" button that logs the current amount and dismisses. Otherwise it
    // falls back to the optional info primary action, or nothing.
    @ViewBuilder private var bottomBar: some View {
        if let onLog {
            logBar(onLog)
        } else if let title = primaryActionTitle, let action = onPrimaryAction {
            Button(action: action) {
                Text(title).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .padding(16)
            .background(.ultraThinMaterial)
        }
    }

    // Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
    // The log affordance: pick a meal, then add the dialed-in amount to the diary. Hands
    // the caller the consumed nutrients (per-100 scaled by the current factor) so the
    // store write stays outside this view. Disabled when the amount rounds to nothing.
    // (The button now shows the live calorie total so what you're about to log is never
    // a guess, drops the keyboard before reading the amount, and confirms with a
    // success haptic.)
    private func logBar(_ onLog: @escaping (MealType, Nutrients) -> Void) -> some View {
        let consumed = food.per100.scaled(by: factor)
        return VStack(spacing: 10) {
            HStack {
                Text("Meal").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Picker("Meal", selection: $selectedMeal) {
                    ForEach(MealType.allCases) { meal in
                        Label(meal.title, systemImage: meal.systemImage).tag(meal)
                    }
                }
                .pickerStyle(.menu)
                .tint(accent)
            }
            Button {
                amountFocused = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onLog(selectedMeal, food.per100.scaled(by: factor))
                dismiss()
            } label: {
                Text("Add to \(selectedMeal.title) · \(Int(consumed.calories.rounded())) kcal")
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .disabled(factor <= 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: factor)
        .padding(16)
        .background(.ultraThinMaterial)
    }

    // Claude  Date 07/15/2026
    // Best-guess meal from the current hour so the picker opens on the likely choice.
    static func mealForNow(_ date: Date = Date()) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<11:  return .breakfast
        case 11..<15: return .lunch
        case 18..<22: return .dinner
        default:      return .snack
        }
    }

    // MARK: - Number formatting

    // Claude  Date 07/14/2026
    // Compact number: integers show whole; fractional values keep up to 2 decimals with
    // trailing zeros trimmed (micros can be tiny, e.g. 0.9 µg). Keeps a real 0 as "0".
    static func number(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e12 {
            return String(Int(value.rounded()))
        }
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}

#if DEBUG
// Claude  Date 07/14/2026
// A rich sample so the full page (populated micros, category icon, serving toggle,
// verified badge) is visible in the Xcode canvas — the running library only produces
// macro-only foods for now.
private extension FoodDetail {
    static let sample = FoodDetail(
        name: "Greek Yogurt, Plain",
        brand: "Chobani",
        barcode: "8180000012345",
        category: "Dairies, Fermented foods, Yogurts",
        source: .openFoodFacts,
        servingQuantity: 170,
        basisUnit: "g",
        per100: Nutrients(calories: 59, protein: 10, carbs: 3.6, fat: 0.4,
                          fiber: 0, sugar: 3.2, sodium: 36),
        micros: Micros(saturFat: 0.1, transFat: 0, cholesterolMg: 5,
                       vBTwo: 233, vBTwelve: 750, calcium: 110, potassium: 141, zinc: 0.5)
    )
}

// Claude  Date 07/14/2026 last changed: 07/16/2026 by: Claude
// Previews wrap the page in a NavigationStack now that the view no longer owns one
// (so it can be pushed by the diary picker or sheeted by the Foods tab).
#Preview("Populated · logging") {
    NavigationStack {
        FoodDetailView(food: .sample, onLog: { meal, consumed in
            print("log \(meal.title): \(consumed.calories) kcal")
        })
    }
    .environmentObject(ThemeManager())
}

#Preview("Per-100 only, verified") {
    NavigationStack {
        FoodDetailView(food: FoodDetail(
            name: "Rolled Oats",
            source: .verified,
            servingQuantity: nil,
            per100: Nutrients(calories: 379, protein: 13, carbs: 67, fat: 6.5,
                              fiber: 10, sugar: 1, sodium: 6)))
    }
    .environmentObject(ThemeManager())
}

// Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
// A liquid (basisUnit "ml") so the cup/mL/oz options + quick chips are visible.
#Preview("Liquid · cup/mL/oz") {
    NavigationStack {
        FoodDetailView(food: FoodDetail(
            name: "Orange Juice",
            brand: "Tropicana",
            category: "Beverages, Fruit juices",
            source: .openFoodFacts,
            servingQuantity: 250,
            basisUnit: "ml",
            per100: Nutrients(calories: 45, protein: 0.7, carbs: 10.4, fat: 0.2,
                              fiber: 0.2, sugar: 8.4, sodium: 1),
            micros: Micros(vC: 50, potassium: 200)), onLog: { _, _ in })
    }
    .environmentObject(ThemeManager())
}

// Claude  Date 07/15/2026 last changed: 07/16/2026 by: Claude
// A count-based food (a custom "1 bar" with no gram weight) — the page runs in
// per-serving mode: no per-100/gram options, just a servings count, built via the
// FoodItem adapter the way a real custom food would flow in.
#Preview("Count · per serving") {
    NavigationStack {
        FoodDetailView(food: FoodDetail(from: FoodItem(
            name: "Protein Bar",
            brand: "Homemade",
            servingSize: 1,
            servingUnit: "bar",
            nutrients: Nutrients(calories: 210, protein: 20, carbs: 22, fat: 7,
                                 fiber: 3, sugar: 5, sodium: 140),
            source: .custom)), onLog: { _, _ in })
    }
    .environmentObject(ThemeManager())
}
#endif
