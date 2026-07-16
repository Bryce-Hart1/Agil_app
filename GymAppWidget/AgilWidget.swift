import WidgetKit
import SwiftUI

// Claude  Date 07/16/2026
// Agil's home-screen widget: today's calories against the daily goal, the
// diary's first Focus goal (if any), and the transparent Agil mark — all tinted
// with the active app theme. Data arrives through WidgetSnapshot (App Group);
// the app rewrites it and reloads this timeline whenever the food log, goals,
// or theme change. This target compiles a handful of the app's files directly
// (WidgetSnapshot, NutrientFocusGoal, Nutrients, NutritionGoals, AppTheme,
// Color+Hex — listed in project.yml) so presentation stays identical to the app.

struct AgilEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct AgilProvider: TimelineProvider {

    func placeholder(in context: Context) -> AgilEntry {
        AgilEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (AgilEntry) -> Void) {
        completion(AgilEntry(date: .now, snapshot: currentSnapshot()))
    }

    // Claude  Date 07/16/2026
    // Two entries: now, and one at the next midnight with the consumed values
    // zeroed — so the widget resets to "0 kcal" for the new day even if the app
    // isn't opened. Real updates come from the app's reloadAllTimelines() calls.
    func getTimeline(in context: Context, completion: @escaping (Timeline<AgilEntry>) -> Void) {
        let snapshot = currentSnapshot()
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)

        var rolled = snapshot
        rolled.dayStart = midnight
        rolled.caloriesToday = 0
        rolled.focusConsumed = 0

        completion(Timeline(entries: [AgilEntry(date: now, snapshot: snapshot),
                                      AgilEntry(date: midnight, snapshot: rolled)],
                            policy: .atEnd))
    }

    // Claude  Date 07/16/2026
    // A snapshot written yesterday means nothing has been logged today — show
    // zeros rather than yesterday's totals. Goal + theme stay valid.
    private func currentSnapshot() -> WidgetSnapshot {
        var snapshot = WidgetSnapshot.load()
        if !Calendar.current.isDateInToday(snapshot.dayStart) {
            snapshot.caloriesToday = 0
            snapshot.focusConsumed = 0
        }
        return snapshot
    }
}

// MARK: - View

struct AgilWidgetView: View {
    var entry: AgilEntry
    @Environment(\.colorScheme) private var colorScheme

    // Claude  Date 07/16/2026
    // Fall back to Classic (the free default) until the app has written a theme.
    private var theme: AppTheme { entry.snapshot.theme ?? .classic }

    // Claude  Date 07/16/2026
    // Readable text color for the theme's background. Adaptive themes follow the
    // system scheme (like the app), so .primary is correct. Fixed themes force
    // one appearance in-app — the widget can't force a scheme, so pick white or
    // black to match the palette's declared mode instead of trusting .primary.
    private var foreground: Color {
        theme.isAdaptive ? .primary : (theme.isDark ? .white : .black)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(foreground.opacity(0.6))
                Spacer()
                // The transparent Agil mark (template image), tinted theme accent.
                Image("AgilMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(theme.accent)
            }

            Spacer(minLength: 0)

            Text("\(Int(entry.snapshot.caloriesToday.rounded()))")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("of \(Int(entry.snapshot.calorieGoal.rounded())) kcal")
                .font(.caption)
                .foregroundStyle(foreground.opacity(0.6))

            // Claude  Date 07/16/2026
            // Focus goal row — same icon, tint, and progress wording as the
            // diary's Focus card. Hidden entirely when no goal exists.
            if let goal = entry.snapshot.focusGoal {
                let consumed = entry.snapshot.focusConsumed
                HStack(spacing: 4) {
                    Image(systemName: goal.isMet(consumed: consumed)
                                      ? "checkmark.circle.fill"
                                      : goal.nutrient.systemImage)
                        .font(.caption2)
                    Text("\(goal.nutrient.label) · \(goal.progressText(consumed: consumed))")
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(goal.nutrient.tint)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackgroundCompat(theme.background)
    }
}

// Claude  Date 07/16/2026
// iOS 17 requires containerBackground(for: .widget) (plain .background renders
// with a system default behind it); iOS 16 — our deployment target — doesn't
// have that API. One modifier, both paths.
private extension View {
    @ViewBuilder
    func widgetBackgroundCompat(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { color }
        } else {
            padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color)
        }
    }
}

// MARK: - Widget

@main
struct AgilWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AgilWidget", provider: AgilProvider()) { entry in
            AgilWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Calories")
        .description("Today's calories and your focus goal, in your Agil theme.")
        .supportedFamilies([.systemSmall])
    }
}
