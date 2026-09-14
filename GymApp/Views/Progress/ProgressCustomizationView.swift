import SwiftUI

// Bryce Hart  Date 09/05/2026
// Each world owns its own dashboard selection. The stored values are raw widget ids,
// not positional booleans, so adding new cards later won't scramble an existing page.
enum ProgressCustomizationMode: Equatable {
    case lifting
    case nutrition

    var storageKey: String {
        switch self {
        case .lifting: return "liftingProgressWidgetLayoutV1"
        case .nutrition: return "nutritionProgressWidgetLayoutV2"
        }
    }

    var availableWidgets: [ProgressWidgetKind] {
        switch self {
        case .lifting:
            return [.workoutActivity, .recap, .summary, .oneRepMax,
                    .frequency, .muscleGroups, .personalRecords]
        case .nutrition:
            return [.foodActivity, .proteinIntake, .proteinFoods,
                    .carbIntake, .carbFoods, .fatIntake, .fatFoods,
                    .focusCompletion, .waterIntake]
        }
    }

    var defaultStorageValue: String {
        availableWidgets.map(\.rawValue).joined(separator: ",")
    }
}

enum ProgressWidgetKind: String, Identifiable, Equatable {
    case workoutActivity
    case recap
    case summary
    case oneRepMax
    case frequency
    case muscleGroups
    case personalRecords
    case foodActivity
    case proteinIntake
    case carbIntake
    case fatIntake
    case proteinFoods
    case carbFoods
    case fatFoods
    case focusCompletion
    case waterIntake

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workoutActivity: return "Workout activity"
        case .recap: return "Recent recap"
        case .summary: return "At-a-glance stats"
        case .oneRepMax: return "Estimated 1RM"
        case .frequency: return "Workout frequency"
        case .muscleGroups: return "Muscle groups"
        case .personalRecords: return "Personal records"
        case .foodActivity: return "Food activity"
        case .proteinIntake: return "Daily protein intake"
        case .carbIntake: return "Daily carb intake"
        case .fatIntake: return "Daily fat intake"
        case .proteinFoods: return "Top protein foods"
        case .carbFoods: return "Top carb foods"
        case .fatFoods: return "Top fat foods"
        case .focusCompletion: return "Focus goal completion"
        case .waterIntake: return "Daily water intake"
        }
    }

    var detail: String {
        switch self {
        case .workoutActivity: return "Your completed workout days across 52 weeks."
        case .recap: return "A compact summary of your selected time range."
        case .summary: return "Workouts, streak, this week, and latest session."
        case .oneRepMax: return "Estimated strength progress for each exercise."
        case .frequency: return "Workouts grouped by week, month, or year."
        case .muscleGroups: return "Completed set volume across muscle groups."
        case .personalRecords: return "Your most recently achieved best sets."
        case .foodActivity: return "Days tracked or within 200 calories of your goal."
        case .proteinIntake: return "Protein logged each day compared with your daily goal."
        case .carbIntake: return "Carbs logged each day compared with your daily goal."
        case .fatIntake: return "Fat logged each day compared with your daily goal."
        case .proteinFoods: return "The share of your protein that came from each food."
        case .carbFoods: return "The share of your carbs that came from each food."
        case .fatFoods: return "The share of your fat that came from each food."
        case .focusCompletion: return "The share of your focus goals completed each tracked day."
        case .waterIntake: return "Water logged each day compared with your daily goal."
        }
    }

    var systemImage: String {
        switch self {
        case .workoutActivity, .foodActivity: return "square.grid.3x3.fill"
        case .recap: return "sparkles"
        case .summary: return "rectangle.grid.2x2.fill"
        case .oneRepMax: return "chart.xyaxis.line"
        case .frequency: return "chart.bar.fill"
        case .muscleGroups: return "figure.strengthtraining.traditional"
        case .personalRecords: return "trophy.fill"
        case .proteinIntake: return "chart.bar.fill"
        case .carbIntake: return "chart.bar.fill"
        case .fatIntake: return "chart.bar.fill"
        case .proteinFoods, .carbFoods, .fatFoods: return "fork.knife"
        case .focusCompletion: return "scope"
        case .waterIntake: return "drop.fill"
        }
    }
}

enum ProgressWidgetLayout {
    static func widgets(from storedValue: String,
                        mode: ProgressCustomizationMode) -> [ProgressWidgetKind] {
        guard storedValue != "none" else { return [] }
        let available = Set(mode.availableWidgets.map(\.rawValue))
        var seen = Set<String>()
        return storedValue
            .split(separator: ",")
            .compactMap { raw -> ProgressWidgetKind? in
                let value = String(raw)
                guard available.contains(value), seen.insert(value).inserted else { return nil }
                return ProgressWidgetKind(rawValue: value)
            }
    }

    static func storageValue(for widgets: [ProgressWidgetKind]) -> String {
        widgets.isEmpty ? "none" : widgets.map(\.rawValue).joined(separator: ",")
    }
}

// The dedicated widget gallery reached from either Edit Progress entry point.
struct ProgressCustomizationView: View {
    @EnvironmentObject private var theme: ThemeManager

    let mode: ProgressCustomizationMode
    @AppStorage("liftingProgressWidgetLayoutV1") private var liftingLayout =
        ProgressCustomizationMode.lifting.defaultStorageValue
    @AppStorage("nutritionProgressWidgetLayoutV2") private var nutritionLayout =
        ProgressCustomizationMode.nutrition.defaultStorageValue
    @AppStorage(WaterTracking.storageKey) private var trackWater = WaterTracking.defaultValue

    private var storedValue: String {
        mode == .lifting ? liftingLayout : nutritionLayout
    }

    private var selectedWidgets: [ProgressWidgetKind] {
        ProgressWidgetLayout.widgets(from: storedValue, mode: mode)
    }

    // Water is a dashboard option only while its underlying tracker is enabled. It
    // stays in the persisted layout so switching water back on restores the chart.
    private var availableWidgets: [ProgressWidgetKind] {
        mode.availableWidgets.filter { $0 != .waterIntake || trackWater }
    }

    var body: some View {
        List {
            Section {
                Text("Choose the widgets that appear on your Progress page. Changes apply immediately and stay saved on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Widget gallery") {
                ForEach(availableWidgets) { widget in
                    widgetCard(widget)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16,
                                                 bottom: 8, trailing: 16))
                }
            }
        }
        .navigationTitle("Edit Progress")
        .themed(theme.current)
    }

    private func widgetCard(_ widget: ProgressWidgetKind) -> some View {
        let isSelected = selectedWidgets.contains(widget)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: widget.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.current.accent)
                    .frame(width: 28, height: 28)
                    .background(theme.current.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(widget.title)
                        .font(.subheadline.weight(.semibold))
                    Text(widget.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Button {
                    toggle(widget)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(isSelected ? theme.current.accent : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Remove \(widget.title)" : "Add \(widget.title)")
            }

            ProgressWidgetPreview(kind: widget, accent: theme.current.accent)
                .frame(height: 66)
                .padding(10)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isSelected ? theme.current.accent.opacity(0.45)
                                           : Color.primary.opacity(0.08),
                                lineWidth: isSelected ? 1 : 0.5)
                }
                .opacity(isSelected ? 1 : 0.72)
        }
        .padding(.vertical, 3)
    }

    private func toggle(_ widget: ProgressWidgetKind) {
        var selection = selectedWidgets
        if let index = selection.firstIndex(of: widget) {
            selection.remove(at: index)
        } else {
            selection.append(widget)
            selection.sort { left, right in
                let order = mode.availableWidgets
                return order.firstIndex(of: left)! < order.firstIndex(of: right)!
            }
        }

        let value = ProgressWidgetLayout.storageValue(for: selection)
        if mode == .lifting {
            liftingLayout = value
        } else {
            nutritionLayout = value
        }
    }
}

// Data-free miniatures: recognizable enough to choose a widget without doing the
// dashboard's expensive recap/record calculations inside every gallery card.
private struct ProgressWidgetPreview: View {
    let kind: ProgressWidgetKind
    let accent: Color

    var body: some View {
        switch kind {
        case .workoutActivity, .foodActivity:
            activityPreview
        case .recap:
            recapPreview
        case .summary:
            summaryPreview
        case .oneRepMax:
            linePreview
        case .frequency:
            barPreview
        case .muscleGroups:
            musclePreview
        case .personalRecords:
            recordsPreview
        case .proteinIntake:
            dailyBarsPreview(color: MacroPalette.protein)
        case .carbIntake:
            dailyBarsPreview(color: MacroPalette.carbs)
        case .fatIntake:
            dailyBarsPreview(color: MacroPalette.fat)
        case .proteinFoods:
            foodContributorsPreview(color: MacroPalette.protein)
        case .carbFoods:
            foodContributorsPreview(color: MacroPalette.carbs)
        case .fatFoods:
            foodContributorsPreview(color: MacroPalette.fat)
        case .focusCompletion:
            dailyBarsPreview(color: accent)
        case .waterIntake:
            dailyBarsPreview(color: accent)
        }
    }

    private var activityPreview: some View {
        HStack(alignment: .top, spacing: 3) {
            ForEach(0..<18, id: \.self) { column in
                VStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { row in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill((column + row * 3) % 7 < 2
                                  ? accent : Color.primary.opacity(0.09))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            Spacer(minLength: 0)
            if kind == .foodActivity {
                Capsule()
                    .fill(accent.opacity(0.7))
                    .frame(width: 25, height: 14)
                    .overlay(alignment: .trailing) {
                        Circle().fill(.white).padding(2)
                    }
            }
        }
    }

    private var recapPreview: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent.opacity(0.8 - Double(index) * 0.18))
                            .frame(width: 22, height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.22))
                            .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.16))
                .frame(height: 5)
        }
    }

    private var summaryPreview: some View {
        HStack(spacing: 7) {
            ForEach(0..<4, id: \.self) { index in
                VStack(spacing: 5) {
                    Circle().fill(accent.opacity(0.75)).frame(width: 8, height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.45))
                        .frame(width: 22, height: 7)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 30, height: 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    private var linePreview: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 4, y: geometry.size.height - 8))
                path.addLine(to: CGPoint(x: geometry.size.width * 0.25, y: geometry.size.height * 0.62))
                path.addLine(to: CGPoint(x: geometry.size.width * 0.48, y: geometry.size.height * 0.68))
                path.addLine(to: CGPoint(x: geometry.size.width * 0.72, y: geometry.size.height * 0.28))
                path.addLine(to: CGPoint(x: geometry.size.width - 4, y: 7))
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    private var barPreview: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach([20.0, 38.0, 27.0, 52.0, 34.0, 58.0, 44.0], id: \.self) { height in
                RoundedRectangle(cornerRadius: 3)
                    .fill(accent.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            }
        }
    }

    private func dailyBarsPreview(color: Color) -> some View {
        ZStack(alignment: .top) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach([0.42, 0.68, 0.53, 0.90, 0.75, 0.98, 0.61], id: \.self) { fraction in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.gradient)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54 * fraction)
                }
            }

            Rectangle()
                .fill(color.opacity(0.65))
                .frame(height: 1)
                .overlay {
                    HStack(spacing: 3) {
                        ForEach(0..<20, id: \.self) { _ in
                            Rectangle().fill(color.opacity(0.75)).frame(width: 4, height: 1)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .offset(y: 12)
        }
    }

    // CLAUDE  Date 09/12/2026
    // Share-of-total fractions plus a dimmed remainder, matching what the real card
    // draws now — the old 0.94/0.76/... staircase was the top-relative scale that the
    // card no longer uses, so the thumbnail promised the wrong chart.
    private func foodContributorsPreview(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([0.30, 0.22, 0.15, 0.09], id: \.self) { fraction in
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * fraction, height: 8)
                }
                .frame(height: 8)
            }
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.32))
                    .frame(width: geometry.size.width * 0.24, height: 8)
            }
            .frame(height: 8)
        }
    }

    private var musclePreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach([0.92, 0.72, 0.55, 0.38], id: \.self) { width in
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.20))
                        .frame(width: 42, height: 5)
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accent.opacity(0.82))
                            .frame(width: geometry.size.width * width, height: 7)
                    }
                    .frame(height: 7)
                }
            }
        }
    }

    private var recordsPreview: some View {
        VStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 7) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(index == 0 ? Color.yellow : accent.opacity(0.7))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.26))
                        .frame(width: CGFloat(72 - index * 8), height: 5)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent.opacity(0.48))
                        .frame(width: 38, height: 5)
                }
            }
        }
    }
}
