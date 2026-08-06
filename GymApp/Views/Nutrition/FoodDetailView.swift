import SwiftUI
import UIKit

// Claude  Date 07/14/2026 last changed: 08/06/2026 Peer reviewed Bryce Hart 08-06-26
// The food detail page that pops when you scan an item or tap one in Foods. Shows the
// backend DTO: name/brand, a category chip and a provenance (source) badge, a
// serving/unit selector with quick-amount chips, the macro block, and the sparse
// micronutrients grouped into Fats / Vitamins / Minerals, then the correction card.
//
// Contract rules it honors:
//  • Everything is per 100 g/ml; a serving scales by servingQuantity / 100. When
//    servingQuantity is nil there's no serving option — per-100 only, nothing fabricated.
//  • Units are fixed per field (from MicroField), never derived.
//  • A nil micro is NOT SHOWN at all; a real 0 renders "0". (Was: nil rendered as "—".
//    A typical Open Food Facts row fills 2–4 of the 32 fields, so the honest read-out
//    was three cards of dashes the user had to scroll past to reach the real numbers.
//    What's missing is now stated once, as a count, on the correction card.)
//
// The barcode used to print under the badges; it's internal plumbing (a dedupe key),
// not something the user reads, so it's gone from the header — `food.barcode` itself
// stays, since submissions and correction requests both travel with it.
//
// Store-free: the view never touches AppStore directly. A caller opts into logging by
// passing `onLog` — the page then shows a meal picker + "Add" bar and, on tap, hands
// back the chosen meal, the consumed nutrients for the dialed-in amount, and the
// measurement the user expressed, so the caller does the actual diary write. Without
// `onLog` (and without a primary action) the page is pure info. The last-used
// measurement likewise comes IN as `initialMeasurement` rather than being read from
// the store here.
//
// (Reworked for speed: no NavigationStack of its own anymore, so it can be pushed from
// the diary picker or wrapped in a stack for sheets. Quick chips cover common amounts
// without the keyboard, and the typed amount commits live on every keystroke — see
// `amountText`.)
//
// Claude  Date 08/06/2026 — the amount system: two tabs (Serving | Weight, or
// Serving | Volume for a liquid) with tappable unit chips inside the unit tab
// (g · oz · lb / cup · fl oz · mL). Tapping a chip converts the amount in place, so
// switching units never costs the user their number. Weight and volume never mix:
// crossing them needs a density the food data doesn't carry. See EntryMode/FoodUnit.
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

    // Claude  Date 08/06/2026
    // The amount this food was logged at last time, from AppStore.lastMeasurements.
    // When it still fits the food (see FoodMeasurement.isValid) the page opens on it
    // instead of the 1-serving default, so a food you eat every day is two taps to
    // re-log. nil = no history, or a stale one — fall back to the defaults.
    var initialMeasurement: FoodMeasurement? = nil

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // Logging hook. When non-nil the page shows a meal picker + "Add to <meal>" bar; on
    // tap it fires with the selected meal, the nutrients consumed for the current
    // amount (per-100 already scaled by `factor`), and the measurement the user dialed
    // in — the caller writes all three. Nil = no logging affordance.
    // (Declared last so call sites can keep passing it as a trailing closure.)
    var onLog: ((MealType, Nutrients, FoodMeasurement) -> Void)? = nil

    // Which meal the "Add" bar logs into. Seeded on appear (see `initialMeal`).
    @State private var selectedMeal: MealType = .snack

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // How the amount is being expressed: as a count of the food's own servings, or as
    // a quantity of a real unit (`selectedUnit`). Both carry a user-chosen
    // `unitQuantity`, reduced to a per-100 scale factor by `factor`.
    //
    // (Was a 7-case ServingBasis — per100/serving/gram/cup/milliliter/ounce/
    // servingCount — that conflated "which tab" with "which unit", so adding oz and lb
    // to the weight side would have meant four more top-level segments. The unit is
    // its own axis now: two tabs, and chips inside the unit tab. `per100` is gone
    // outright; it was the gram tab with the amount frozen at 100. A count-based food
    // has no unit tab at all — `.serving` counts its opaque servings, and per-100
    // already IS one serving there.)
    private enum EntryMode: Hashable { case serving, unit }

    @State private var mode: EntryMode = .serving
    // Which unit the amount is in while `mode == .unit`. Always from this food's
    // family (weight for solids, volume for liquids) — see FoodUnit.family.
    @State private var selectedUnit: FoodUnit = .gram
    // How many of the selected unit (or how many servings in `.serving` mode).
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

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // The tabs offered for this food. A count-based food gets none (its only amount is
    // a count of its own opaque servings, so a picker with one option is noise); a food
    // with a known serving size gets both; one without gets the unit tab alone.
    //
    // (The unit conversion constants that used to live here — mlPerCup/mlPerOunce —
    // moved to FoodUnit.perBase, which is now the app's one set. The weight family
    // g/oz/lb is new; there was no way to log ounces or pounds before.)
    private var availableModes: [EntryMode] {
        if food.isCountBased { return [] }
        return food.servingQuantity != nil ? [.serving, .unit] : [.unit]
    }

    // The unit chips this food offers — weight for solids, volume for liquids. Never
    // both: converting between them needs a density we don't have.
    private var unitFamily: [FoodUnit] { FoodUnit.family(forBasisUnit: food.basisUnit) }

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // Scale factor applied to every per-100 reference value. A unit amount converts
    // through its base (g or ml) — `perBase` is 1 for the base unit itself, so grams
    // and mL fall out as amount/100. A serving is `unitQuantity` servings of
    // `servingQuantity` g/ml each. For a count food per-100 already IS one serving, so
    // the factor is just the count.
    private var factor: Double {
        if food.isCountBased { return max(0, unitQuantity) }
        switch mode {
        case .serving: return max(0, unitQuantity) * (food.servingQuantity ?? 100) / 100
        case .unit:    return max(0, unitQuantity) * selectedUnit.perBase / 100
        }
    }

    // Claude  Date 08/06/2026
    // The amount as the user expressed it, for the log record. A count food and the
    // serving tab both record a serving count (no unit); the unit tab records the
    // chip. This is what the diary row renders and what gets cached for next time.
    private var currentMeasurement: FoodMeasurement {
        if food.isCountBased {
            return FoodMeasurement(amount: unitQuantity, unit: nil,
                                   servingNoun: food.servingUnit ?? "serving")
        }
        switch mode {
        case .serving: return FoodMeasurement(amount: unitQuantity, unit: nil,
                                              servingNoun: "serving")
        case .unit:    return FoodMeasurement(amount: unitQuantity, unit: selectedUnit,
                                              servingNoun: nil)
        }
    }

    private var accent: Color { theme.current.accent }
    private var surface: Color { theme.current.surface }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                amountSelector
                macrosCard
                // Claude  Date 07/14/2026 last changed: 08/06/2026 by: Claude
                // A group with nothing reported is dropped entirely rather than drawn
                // as an empty card — see `reportedFields(in:)`.
                ForEach(MicroGroup.allCases) { group in
                    let fields = reportedFields(in: group)
                    if !fields.isEmpty { microCard(fields, group: group) }
                }
                // Claude  Date 08/06/2026
                // The one place the page admits what it doesn't know, and the user's
                // way out: send the food back for review. Self-contained (it owns the
                // network call and the card credentials) so this view stays store-free.
                FoodCorrectionCard(food: food)
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
        .onAppear(perform: seed)
    }

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // What the page opens on. The user's last measurement for this food wins when it
    // still fits (a re-log of a daily food should need no dialing at all); otherwise
    // the food's natural default — 1 serving when a size is known, a count for count
    // foods, else the base unit's default amount.
    private func seed() {
        // Preselect the meal: the caller's context wins, else the time of day.
        selectedMeal = initialMeal ?? Self.mealForNow()
        selectedUnit = FoodUnit.baseUnit(forBasisUnit: food.basisUnit)

        if let last = initialMeasurement, last.isValid(for: food) {
            if let unit = last.unit {
                mode = .unit
                selectedUnit = unit
            } else {
                mode = .serving
            }
            setQuantity(last.amount)
            return
        }
        mode = availableModes.first ?? .serving
        setQuantity(defaultQuantity())
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
            // Claude  Date 07/14/2026 last changed: 08/06/2026 by: Claude
            // Category, then provenance. The source badge (and its stacked verification
            // badge, for generic/restaurant foods) comes from the shared FoodSourceBadge
            // so the detail page and every list row agree.
            //
            // (The two used to share one HStack. A long source label — "Open Food Facts"
            // wraps to two lines — starved the chip of width and truncated the category
            // to "Peanut butte…". Each gets its own row now, so neither can squeeze the
            // other no matter how long the strings get.)
            categoryChip
            HStack(spacing: 8) {
                FoodSourceBadge(source: food.source,
                                verification: food.verification,
                                style: .detail)
                Spacer(minLength: 0)
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
            // Claude  Date 08/06/2026
            // Now that the chip owns a full row it can afford to wrap instead of
            // truncate — a long leading term ("Peanut butter and chocolate spreads")
            // stays readable. fixedSize lets the capsule grow to the wrapped height.
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    // MARK: - Amount selector

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // The amount block: a two-tab picker (Serving | Weight, or Serving | Volume for a
    // liquid) over the amount controls. The picker hides itself when there's only one
    // tab — a count food, or a food with no known serving size.
    //
    // (Was a segment per unit. Tabs and units are separate axes now: the tab picks
    // servings-vs-real-units and the unit chips inside pick which one, so g/oz/lb fit
    // without a five-segment control. The tab binding is custom rather than
    // `$mode` + `.onChange` because that onChange would fire when `seed()` restores a
    // cached measurement and immediately overwrite the restored amount with a default.)
    @ViewBuilder private var amountSelector: some View {
        VStack(spacing: 10) {
            if availableModes.count > 1 {
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
    }

    // Claude  Date 08/06/2026
    // Tab switch. The amount CARRIES ACROSS rather than resetting: opening a 170 g
    // yogurt's Weight tab should show 170 g, not a generic 100. Both directions are
    // always defined — the Serving tab only exists when servingQuantity is known.
    private func switchMode(to newMode: EntryMode) {
        guard newMode != mode else { return }
        amountFocused = false
        let per = food.servingQuantity ?? 100
        switch newMode {
        case .unit:
            let base = unitQuantity * per                 // servings → g/ml
            mode = .unit
            setQuantity(Self.rounded(base / selectedUnit.perBase,
                                     places: selectedUnit.displayPrecision))
        case .serving:
            let base = unitQuantity * selectedUnit.perBase // units → g/ml
            mode = .serving
            setQuantity(Self.rounded(base / per, places: 2))
        }
    }

    // Claude  Date 08/06/2026
    // Chip tap: switch unit and convert the amount in place, so 100 g becomes 3.5 oz
    // rather than a meaningless 100 oz. Rounded to the unit's display precision —
    // this is the ONLY place amounts get rounded; typed input never is.
    private func selectUnit(_ newUnit: FoodUnit) {
        guard newUnit != selectedUnit else { return }
        let converted = selectedUnit.convert(unitQuantity, to: newUnit) ?? unitQuantity
        selectedUnit = newUnit
        setQuantity(Self.rounded(converted, places: newUnit.displayPrecision))
        amountFocused = false
    }

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // The amount controls: quick chips for the common amounts (one tap, no keyboard),
    // then an editable field (type an exact value, e.g. 173 g off a label) paired with
    // a +/- stepper. The field parses live — see `amountText`. Below, a small "≈ …"
    // note shows the equivalent in the base unit where it isn't obvious (cup/oz → ml,
    // lb → g, servings → g/ml).
    //
    // (In unit mode a row of tappable unit chips sits under the field, sharing the line
    // with the "≈" note — chips leading, note trailing. They're deliberately NOT inline
    // with the field: TextField + 3 chips + stepper overflows an SE-width screen, and
    // this way the row costs no extra vertical space on the foods that show the note.)
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
                        if let v = Self.parseAmount(newValue) { unitQuantity = v }
                    }
                Text(unitNoun)
                    .fontWeight(.medium)
                Spacer(minLength: 4)
                Stepper("", value: Binding(get: { unitQuantity },
                                           set: { setQuantity($0) }),
                        in: quantityRange, step: quantityStep)
                    .labelsHidden()
            }
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
    private var showsUnitChips: Bool { mode == .unit && !food.isCountBased }

    // Claude  Date 08/06/2026
    // The unit family as small tappable capsules (g · oz · lb, or cup · fl oz · mL).
    // Sized below the quick-amount chips so the row reads as "amount, then its unit"
    // rather than two competing controls.
    private var unitChips: some View {
        HStack(spacing: 4) {
            ForEach(unitFamily, id: \.self) { unit in
                let selected = unit == selectedUnit
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

    // Claude  Date 07/16/2026
    // One-tap presets for the current unit. Tapping sets the amount and dismisses the
    // keyboard; the chip matching the current amount fills with the accent color.
    private var quickChips: some View {
        HStack(spacing: 8) {
            ForEach(quickAmounts, id: \.self) { amount in
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

    // Claude  Date 07/16/2026 last changed: 08/06/2026 by: Claude
    // The preset amounts for the current unit — the values people actually eat/pour, so
    // most logs are a single tap. Serving counts and the new weight units (oz in
    // kitchen sizes, lb in quarter steps) get their own sets; 50/100/150/200 would be
    // absurd chips for pounds.
    private var quickAmounts: [Double] {
        if food.isCountBased || mode == .serving { return [0.5, 1, 1.5, 2] }
        switch selectedUnit {
        case .gram:       return [50, 100, 150, 200]
        case .ounce:      return [1, 2, 4, 8]
        case .pound:      return [0.25, 0.5, 1, 2]
        case .cup:        return [0.25, 0.5, 1, 2]
        case .fluidOunce: return [8, 12, 16]
        case .milliliter: return [100, 250, 330, 500]
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

    // Claude  Date 07/16/2026 last changed: 08/06/2026 by: Claude
    // "≈ …" conversion note under the amount: a derived unit (oz/lb, cup/fl oz) shows
    // its equivalent in the food's base unit, and a serving shows its weight/volume
    // (from servingQuantity). Grams and mL ARE the base unit, so they need none.
    private var equivalentNote: String? {
        if food.isCountBased { return nil }
        switch mode {
        case .unit:
            guard selectedUnit.perBase != 1 else { return nil }
            let base = max(0, unitQuantity) * selectedUnit.perBase
            return "≈ \(Self.number(base, decimals: 1)) \(food.basisUnit)"
        case .serving:
            guard let per = food.servingQuantity else { return nil }
            return "≈ \(Self.number(max(0, unitQuantity) * per)) \(food.basisUnit)"
        }
    }

    // Segment titles. The unit tab is named for the FAMILY, not a unit — it used to say
    // "Grams", which was wrong the moment the tab could also hold oz and lb.
    private func modeTitle(_ m: EntryMode) -> String {
        switch m {
        case .serving: return "Serving"
        case .unit:    return food.basisUnit == "ml" ? "Volume" : "Weight"
        }
    }

    // Singular/plural unit word beside the amount field, for the modes that don't show
    // tappable unit chips (serving counts, and a count food's own noun).
    private var unitNoun: String {
        if food.isCountBased {
            return FoodMeasurement.pluralize(food.servingUnit ?? "serving", count: unitQuantity)
        }
        switch mode {
        case .serving: return FoodMeasurement.pluralize("serving", count: unitQuantity)
        case .unit: return selectedUnit.label(count: unitQuantity)
        }
    }

    // Claude  Date 07/16/2026 last changed: 08/06/2026 by: Claude
    // Starting quantity for the current mode/unit when there's no cached measurement
    // to restore. The gram default is one serving's weight when known — the closest
    // thing to "what you probably meant" without a history.
    private func defaultQuantity() -> Double {
        if food.isCountBased || mode == .serving { return 1 }
        switch selectedUnit {
        case .gram:       return food.servingQuantity ?? 100
        case .ounce:      return 4
        case .pound:      return 0.5
        case .cup:        return 1
        case .fluidOunce: return 8
        case .milliliter: return food.servingQuantity ?? 250
        }
    }

    private var quantityStep: Double {
        if food.isCountBased || mode == .serving { return 0.25 }
        switch selectedUnit {
        case .gram:       return 5
        case .ounce:      return 0.5
        case .pound:      return 0.25
        case .cup:        return 0.25
        case .fluidOunce: return 1
        case .milliliter: return 10
        }
    }

    private var quantityRange: ClosedRange<Double> {
        if food.isCountBased || mode == .serving { return 0.25...50 }
        switch selectedUnit {
        case .gram:       return 1...2000
        case .ounce:      return 0.25...70
        case .pound:      return 0.05...10
        case .cup:        return 0.25...20
        case .fluidOunce: return 1...64
        case .milliliter: return 10...2000
        }
    }

    // Claude  Date 08/06/2026
    // Round to a fixed number of places — used only when an amount ARRIVES via a
    // conversion, so 100 g reads as "3.5 oz" and not "3.5274 oz".
    static func rounded(_ value: Double, places: Int) -> Double {
        let scale = pow(10.0, Double(places))
        return (value * scale).rounded() / scale
    }

    // MARK: - Macros

    private var macrosCard: some View {
        let n = food.per100.scaled(by: factor)
        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Claude  Date 08/06/2026
                // Whole kcal, always. `Self.number` keeps up to 2 decimals, which is
                // right for micros (0.9 µg is a real quantity) and meaningless here —
                // nobody acts on half a calorie, and at 40pt "428.57" was wide enough
                // to wrap onto a second line and collide with the rows below. The
                // line limit is the belt to that fix's braces: a four-digit total
                // ("1429") is still wide, so it scales down rather than wrapping.
                Text("\(Int(n.calories.rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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

    // Caption under the calorie number describing the current reference amount —
    // always the dialed-in measurement now that the fixed per-100 view is gone.
    private var basisCaption: String {
        "per \(currentMeasurement.displayText)"
    }

    private func macroRow(_ label: String, _ value: Double, _ unit: String, tint: Color, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                iconChip(macroIcon(label), tint: tint)
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Self.number(value, decimals: 1)) \(unit)").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
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

    // Claude  Date 08/06/2026
    // The fields in a group this food actually reports. A nil micro means "not
    // available" (see Micros), and there's nothing to say about it row by row — the
    // page shows what IS known and states the size of the gap once, on the correction
    // card. Callers use an empty result to drop the whole card.
    private func reportedFields(in group: MicroGroup) -> [MicroField] {
        MicroField.fields(in: group).filter { $0.value(food.micros) != nil }
    }

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // One group's card. Only reported fields render, so the divider run and the
    // `last:` flag both follow the filtered list. (Was: every field always drew, and
    // an all-blank group collapsed to a single "None" line. Now an all-blank group
    // never gets here at all — `body` skips it.)
    private func microCard(_ fields: [MicroField], group: MicroGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.rawValue)
                .font(.headline)
                .padding(.bottom, 8)
            ForEach(Array(fields.enumerated()), id: \.element.id) { idx, field in
                microRow(field, last: idx == fields.count - 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // Claude  Date 07/14/2026 last changed: 08/06/2026 by: Claude
    // One nutrient. Only reported fields reach here, so the label is always full-weight
    // (it used to grey out for a nil value — that state no longer renders at all).
    private func microRow(_ field: MicroField, last: Bool) -> some View {
        let raw = field.value(food.micros)
        return VStack(spacing: 0) {
            HStack {
                Text(field.label)
                    .font(.subheadline)
                Spacer()
                Text(microValueString(raw, unit: field.unit))
                    .font(.subheadline).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 7)
            if !last { Divider() }
        }
    }

    // Claude  Date 07/14/2026 last changed: 08/06/2026 by: Claude
    // A value scaled by the current basis factor and shown with its fixed unit. A
    // genuine 0 stays "0 <unit>" — that's a measured zero, not a gap.
    //
    // The nil → "—" branch is unreachable now that unreported fields are filtered out
    // upstream; it stays because the Double? signature is what makes the 0-vs-missing
    // distinction explicit at the call site, and a silent "0" would be a lie if a
    // future caller ever skipped the filter.
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

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // The log affordance: pick a meal, then add the dialed-in amount to the diary. Hands
    // the caller the consumed nutrients (per-100 scaled by the current factor) AND the
    // measurement the user expressed, so the store write — and the per-food memory of
    // what they picked — stay outside this view. Disabled when the amount rounds to
    // nothing. (The button shows the live calorie total so what you're about to log is
    // never a guess, drops the keyboard before reading the amount, and confirms with a
    // success haptic.)
    private func logBar(_ onLog: @escaping (MealType, Nutrients, FoodMeasurement) -> Void) -> some View {
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
                onLog(selectedMeal, food.per100.scaled(by: factor), currentMeasurement)
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

    // Claude  Date 07/14/2026 last changed: 08/06/2026 by: Claude
    // Compact number: integers show whole; fractional values keep up to `decimals`
    // places with trailing zeros trimmed. Keeps a real 0 as "0".
    //
    // The default of 2 is for micros, which are genuinely tiny (0.9 µg) and need the
    // precision. Macros pass 1 — a gram of fat to two decimals ("30.36 g") is false
    // precision on a number the source rounded before we ever saw it.
    static func number(_ value: Double, decimals: Int = 2) -> String {
        if value == value.rounded() && abs(value) < 1e12 {
            return String(Int(value.rounded()))
        }
        var s = String(format: "%.\(decimals)f", value)
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

// Claude  Date 07/14/2026 last changed: 08/06/2026 by: Claude
// Previews wrap the page in a NavigationStack now that the view no longer owns one
// (so it can be pushed by the diary picker or sheeted by the Foods tab).
// (CardSyncService joins the environment because the correction card reads the card
// credentials from it — a preview without one traps at runtime.)
#Preview("Populated · logging") {
    NavigationStack {
        FoodDetailView(food: .sample, onLog: { meal, consumed, _ in
            print("log \(meal.title): \(consumed.calories) kcal")
        })
    }
    .environmentObject(ThemeManager())
    .environmentObject(CardSyncService())
}

// Claude  Date 07/14/2026 last changed: 08/06/2026 by: Claude
// No micros at all — every group card should be absent, leaving header → basis →
// macros → correction card ("32 of 32 nutrients aren't reported").
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
    .environmentObject(CardSyncService())
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
            micros: Micros(vC: 50, potassium: 200)), onLog: { _, _, _ in })
    }
    .environmentObject(ThemeManager())
    .environmentObject(CardSyncService())
}

// Claude  Date 08/06/2026
// Cache seeding: a food the user last logged as 6 oz. The page must open on the Weight
// tab with the oz chip lit and 6 in the field — not the 1-serving default — and the
// "≈ 170 g" note underneath.
#Preview("Seeded from last measurement") {
    NavigationStack {
        FoodDetailView(food: .sample,
                       initialMeasurement: FoodMeasurement(amount: 6, unit: .ounce),
                       onLog: { _, _, _ in })
    }
    .environmentObject(ThemeManager())
    .environmentObject(CardSyncService())
}

// Claude  Date 08/06/2026
// The header case that used to truncate: a long category term next to a long source
// label, on a food that reports almost nothing. Confirms the chip wraps on its own row
// instead of becoming "Peanut butte…", that the empty Fats/Minerals cards are gone
// entirely, and that the correction card names the size of the gap.
#Preview("Long category · sparse micros") {
    NavigationStack {
        FoodDetailView(food: FoodDetail(
            name: "Natural Jif Creamy Peanut Butter Spread",
            brand: "Jif",
            barcode: "0051500243220",
            category: "Peanut butter and chocolate spreads, Spreads",
            source: .openFoodFacts,
            servingQuantity: 33,
            per100: Nutrients(calories: 594, protein: 21, carbs: 21, fat: 51,
                              fiber: 6, sugar: 6, sodium: 152),
            micros: Micros(vE: 3.1)), onLog: { _, _, _ in })
    }
    .environmentObject(ThemeManager())
    .environmentObject(CardSyncService())
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
            source: .custom)), onLog: { _, _, _ in })
    }
    .environmentObject(ThemeManager())
}
#endif
