import Foundation

// Claude  Date 07/16/2026
// The data bridge between the app and the home-screen widget. The widget runs in
// a separate process and can't read AppStore/ThemeManager, so the app serializes
// exactly what the widget renders — today's calories, the first Focus goal, and
// the active theme — into the shared App Group container. Compiled into BOTH
// targets (see project.yml): the app writes via update(_:), the widget reads via
// load(). AppStore owns the nutrition fields; ThemeManager owns `theme`; each
// updates only its own part through the read-modify-write helper so neither
// clobbers the other.
struct WidgetSnapshot: Codable {

    // Claude  Date 07/16/2026
    // App Group shared by the app and the widget extension. Must match the
    // com.apple.security.application-groups entitlement on both targets
    // (declared in project.yml).
    static let appGroupID = "group.com.brycehart.gymapp"
    private static let storageKey = "widget_snapshot"

    // Start of the calendar day the nutrition numbers describe. The widget's
    // TimelineProvider compares this to "today" and zeroes the consumed values
    // when the snapshot is stale (nothing has been logged since yesterday).
    var dayStart: Date
    var caloriesToday: Double
    var calorieGoal: Double

    // The diary's first Focus goal (fiber/sugar/sodium floor/ceiling), if the
    // user has created any, plus how much of that nutrient was consumed on
    // dayStart. Reuses NutrientFocusGoal so the widget's icon/tint/progress
    // wording match the diary's Focus card exactly.
    var focusGoal: NutrientFocusGoal?
    var focusConsumed: Double

    // The selected AppTheme, stored whole so the widget gets the same adaptive
    // light/dark color resolution the app has. Optional: nil until the first
    // launch after this feature ships writes it (widget falls back to Classic).
    var theme: AppTheme?

    // Claude  Date 07/16/2026
    // Neutral first-run values (no food logged, default 2000 kcal goal) used
    // before either owner has written its part.
    static var empty: WidgetSnapshot {
        WidgetSnapshot(dayStart: Calendar.current.startOfDay(for: Date()),
                       caloriesToday: 0,
                       calorieGoal: NutritionGoals().calories,
                       focusGoal: nil, focusConsumed: 0, theme: nil)
    }

    // MARK: - App Group persistence

    // Claude  Date 07/16/2026
    // Stored as a JSON blob in the App Group's UserDefaults — one small value,
    // so a defaults key beats managing a file in the shared container.
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    // Claude  Date 07/16/2026
    // Read-modify-write so AppStore and ThemeManager can each update only the
    // fields they own without erasing the other's.
    static func update(_ mutate: (inout WidgetSnapshot) -> Void) {
        var snapshot = load()
        mutate(&snapshot)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults?.set(data, forKey: storageKey)
        }
    }
}
