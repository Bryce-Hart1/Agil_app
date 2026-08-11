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
    // The dialed-in amount — the page's one piece of amount state, edited by the shared
    // MeasurementEditor and read straight back out on log.
    //
    // (Was a 7-case ServingBasis — per100/serving/gram/cup/milliliter/ounce/
    // servingCount — that conflated "which tab" with "which unit", so adding oz and lb
    // to the weight side would have meant four more top-level segments. Tabs and units
    // are separate axes now, and both live inside FoodMeasurement, so the detail page
    // and the diary's editor drive identical controls off identical state. `per100` is
    // gone outright; it was the gram tab with the amount frozen at 100.)
    @State private var measurement = FoodMeasurement(amount: 1, servingNoun: "serving")

    // What this food's amounts mean: its per-100 values, unit family, serving weight.
    private var basis: MeasurementBasis { MeasurementBasis(food) }

    // Scale factor from the per-100 reference values to the dialed-in amount.
    private var factor: Double { measurement.per100Factor(in: basis) }

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
        .safeAreaInset(edge: .bottom) { bottomBar }
        .themed(theme.current)
        .onAppear(perform: seed)
    }

    // Claude  Date 07/15/2026 last changed: 08/06/2026 by: Claude
    // What the page opens on. The user's last measurement for this food wins when it
    // still fits (a re-log of a daily food should need no dialing at all); otherwise
    // the food's natural default — 1 serving when a size is known, a count for count
    // foods, else one serving's weight in the base unit.
    private func seed() {
        // Preselect the meal: the caller's context wins, else the time of day.
        selectedMeal = initialMeal ?? Self.mealForNow()

        if let last = initialMeasurement, last.isValid(for: basis) {
            measurement = last
        } else {
            measurement = basis.defaultMeasurement
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
    // The amount block — tabs, preset chips, field, stepper, unit chips — all lives in
    // the shared MeasurementEditor now, because the diary's entry editor needs exactly
    // the same controls. Everything this page has to know is in `basis` (the food's
    // unit family and serving weight) and `measurement` (what the user dialed).
    private var amountSelector: some View {
        MeasurementEditor(basis: basis, measurement: $measurement, accent: accent)
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
        "per \(measurement.displayText)"
    }

    private func macroRow(_ label: String, _ value: Double, _ unit: String,
                          tint: Color, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                iconChip(macroIcon(label), tint: tint)
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Self.number(value, decimals: 1)) \(unit)")
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

    // Claude  Date 08/06/2026 last changed: 08/07/2026 by: Claude
    // The fields in a group this food actually reports. "Not available" now covers both a
    // nil micro AND a genuine 0 (see MicroField.isReported) — a "0 g" row is noise, not a
    // fact worth a line. The page shows what IS known and states the size of the gap once,
    // on the correction card. Callers use an empty result to drop the whole card.
    private func reportedFields(in group: MicroGroup) -> [MicroField] {
        MicroField.fields(in: group).filter { $0.isReported(in: food.micros) }
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onLog(selectedMeal, food.per100.scaled(by: factor), measurement)
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
    //
    // (Body moved to FoodMeasurement, which needs the same formatter for amount text;
    // this forwards so there's one implementation to drift from, not two.)
    static func number(_ value: Double, decimals: Int = 2) -> String {
        FoodMeasurement.number(value, decimals: decimals)
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
