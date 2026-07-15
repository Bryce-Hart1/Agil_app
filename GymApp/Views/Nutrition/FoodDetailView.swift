import SwiftUI

// Claude  Date 07/14/2026
// The food detail page that pops when you scan an item or tap one in Foods. Shows the
// backend DTO in full: name/brand, a provenance (source) badge and category chip, a
// per-100 ⇄ per-serving toggle, the macro block, and the sparse micronutrients grouped
// into Fats / Vitamins / Minerals.
//
// Contract rules it honors:
//  • Everything is per 100 g/ml; "1 serving" scales by servingQuantity / 100. When
//    servingQuantity is nil there's no serving toggle — per-100 only, nothing fabricated.
//  • Units are fixed per field (from MicroField), never derived.
//  • A nil micro renders "—" / not available; a real 0 renders "0".
//
// Presentation-only: an optional primary action (e.g. "Log this food") lets a caller
// hang the tracking step off the page, but the view itself never touches the store.
struct FoodDetailView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let food: FoodDetail
    // Optional call-to-action shown as a bottom bar button (title + handler). Nil = the
    // page is pure info (just a "Done").
    var primaryActionTitle: String? = nil
    var onPrimaryAction: (() -> Void)? = nil

    // false = per 100 g/ml (always available); true = per one serving.
    @State private var perServing = false

    // Only offer the serving view when the DTO gave us a serving size.
    private var canPerServe: Bool { food.servingQuantity != nil }

    // Scale factor applied to every per-100 value in the current mode.
    private var factor: Double {
        perServing ? (food.servingQuantity ?? 100) / 100 : 1
    }

    private var accent: Color { theme.current.accent }
    private var surface: Color { theme.current.surface }
    // Claude  Date 07/15/2026
    // The app's signature pink (Classic accent), pinned regardless of the active theme —
    // the "Verified" provenance badge always reads in brand pink.
    private var agilPink: Color { Color(hex: "#EA0F8B") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if canPerServe { basisToggle }
                    macrosCard
                    ForEach(MicroGroup.allCases) { group in
                        microCard(group)
                    }
                }
                .padding(16)
            }
            .background(theme.current.background.ignoresSafeArea())
            .navigationTitle("Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { primaryActionBar }
        }
        .themed(theme.current)
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
            HStack(spacing: 8) {
                sourceBadge
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

    // Claude  Date 07/14/2026 last changed: 07/15/2026 by: Claude
    // Provenance badge. A verified food gets the special brand-pink badge with the Agil
    // kettlebell mark (template-tinted to the pink) instead of an SF Symbol; every other
    // source keeps its plain tinted-symbol capsule.
    @ViewBuilder private var sourceBadge: some View {
        if food.source == .verified {
            HStack(spacing: 5) {
                Image("AgilMark")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 14, height: 14)
                Text("Verified")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(agilPink)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(agilPink.opacity(0.15), in: Capsule())
        } else {
            Label(food.source.label, systemImage: food.source.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(food.source.tint)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(food.source.tint.opacity(0.15), in: Capsule())
        }
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

    // MARK: - Basis toggle

    private var basisToggle: some View {
        Picker("Amount", selection: $perServing) {
            Text("Per 100 \(food.basisUnit)").tag(false)
            Text(servingTabLabel).tag(true)
        }
        .pickerStyle(.segmented)
    }

    private var servingTabLabel: String {
        guard let q = food.servingQuantity else { return "Per serving" }
        return "Per serving · \(Self.number(q)) \(food.basisUnit)"
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
                macroRow("Protein", n.protein, "g", tint: .blue)
                macroRow("Carbs",   n.carbs,   "g", tint: .orange)
                macroRow("Fat",     n.fat,     "g", tint: .pink)
                macroRow("Fiber",   n.fiber,   "g", tint: .green)
                macroRow("Sugar",   n.sugar,   "g", tint: .purple)
                macroRow("Sodium",  n.sodium, "mg", tint: .cyan, last: true)
            }
        }
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: perServing)
    }

    private var basisCaption: String {
        perServing ? "per serving" : "per 100 \(food.basisUnit)"
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

    // MARK: - Primary action

    @ViewBuilder private var primaryActionBar: some View {
        if let title = primaryActionTitle, let action = onPrimaryAction {
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

#Preview("Populated") {
    FoodDetailView(food: .sample, primaryActionTitle: "Log this food") {}
        .environmentObject(ThemeManager())
}

#Preview("Per-100 only, verified") {
    FoodDetailView(food: FoodDetail(
        name: "Rolled Oats",
        source: .verified,
        servingQuantity: nil,
        per100: Nutrients(calories: 379, protein: 13, carbs: 67, fat: 6.5,
                          fiber: 10, sugar: 1, sodium: 6)))
        .environmentObject(ThemeManager())
}
#endif
