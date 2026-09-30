import SwiftUI

// CLAUDE  Date 09/30/2026
// The food Log's time-of-day tint: night indigo → dawn → midday gold → dusk violet →
// night. Colors the ribbon bars, thread dots and meal icons by WHEN something was eaten,
// echoing the sunrise / sun / moon meal symbols. Static colors only; nothing animates.
enum DaylightPalette {
    // (hour of day, sRGB 0–255). Night holds indigo until 4am so the small hours don't
    // blend into a muddy mauve on the way to dawn. The list wraps: 24h repeats 0h.
    private static let stops: [(hour: Double, rgb: (Double, Double, Double))] = [
        (0,    (79, 91, 213)),    // #4F5BD5 night indigo
        (4,    (79, 91, 213)),
        (6,    (255, 122, 69)),   // #FF7A45 dawn
        (12.5, (230, 184, 0)),    // #E6B800 midday gold
        (17,   (240, 123, 63)),   // #F07B3F late afternoon
        (19.5, (155, 93, 229)),   // #9B5DE5 dusk violet
        (22,   (79, 91, 213)),    // back to night
        (24,   (79, 91, 213)),
    ]

    // CLAUDE  Date 09/30/2026
    // The tint at a time of day (seconds since midnight): straight RGB interpolation
    // between the two surrounding stops. Manual lerp because Color.mix needs iOS 18.
    static func color(atSeconds seconds: TimeInterval) -> Color {
        let hour = (seconds / 3600).truncatingRemainder(dividingBy: 24)
        let h = hour < 0 ? hour + 24 : hour
        guard let upperIndex = stops.firstIndex(where: { $0.hour >= h }), upperIndex > 0 else {
            return rgb(stops[0].rgb)
        }
        let lo = stops[upperIndex - 1], hi = stops[upperIndex]
        let t = (h - lo.hour) / max(hi.hour - lo.hour, .ulpOfOne)
        return rgb((lo.rgb.0 + (hi.rgb.0 - lo.rgb.0) * t,
                    lo.rgb.1 + (hi.rgb.1 - lo.rgb.1) * t,
                    lo.rgb.2 + (hi.rgb.2 - lo.rgb.2) * t))
    }

    static func color(at date: Date, calendar: Calendar = .current) -> Color {
        color(atSeconds: MealTiming.secondsIntoDay(date, calendar: calendar))
    }

    private static func rgb(_ c: (Double, Double, Double)) -> Color {
        Color(.sRGB, red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255, opacity: 1)
    }
}
