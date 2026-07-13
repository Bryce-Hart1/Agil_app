import SwiftUI

// Claude  Date 06/13/2026 last changed: 06/15/2026 by: Claude
// Badge tiers. A first-class, extensible concept: each tier carries a color and
// a coin reward, and adding a tier is just a new case + thresholds. Cases are
// declared low → high so the order matches AchievementShowcase.tierRank.
// (Added diamond / emerald / legend — Legend is the apex, rendered purple with a
// gold glimmer via glimmerColorHex.)
enum BadgeTier: String, CaseIterable {
    case bronze, silver, gold, platinum, diamond, emerald, legend

    var title: String { rawValue.capitalized }

    // Coins granted when an achievement of this tier is unlocked.
    var reward: Int {
        switch self {
        case .bronze:   return 50
        case .silver:   return 150
        case .gold:     return 400
        case .platinum: return 1000
        case .diamond:  return 2000
        case .emerald:  return 4000
        case .legend:   return 8000
        }
    }

    var colorHex: String {
        switch self {
        case .bronze:   return "#C77B30"
        case .silver:   return "#9AA0A6"
        case .gold:     return "#E6B800"
        case .platinum: return "#3FD0E0"
        case .diamond:  return "#8FD3EF"   // icy blue (distinct from platinum/silver)
        case .emerald:  return "#10B981"   // rich green
        case .legend:   return "#5B21B6"   // deep royal purple (gold glimmer on top)
        }
    }

    var color: Color { Color(hex: colorHex) }

    // Claude  Date 06/15/2026
    // A per-tier material gradient for the medallion disc — a lit highlight at the
    // top-left falling to a deep shade at the bottom-right — so each tier reads as
    // its own material (warm copper, cool steel, rich gold, icy platinum,
    // crystalline diamond, deep emerald, royal purple) instead of a flat fill that
    // looks the same under the glint. `color` stays the representative solid used
    // elsewhere (rewards, glow, confetti); this is only the disc fill.
    private var gradientHexes: (light: String, deep: String) {
        switch self {
        case .bronze:   return ("#F6BE7E", "#6B3A12")
        case .silver:   return ("#F4F7FA", "#4A525B")
        case .gold:     return ("#FFE680", "#8A6200")
        case .platinum: return ("#CDF7FB", "#137885")
        case .diamond:  return ("#EAF7FF", "#4F8FCB")
        case .emerald:  return ("#4BE6A6", "#044F38")
        case .legend:   return ("#9B6CFF", "#2E0B5E")
        }
    }

    var fillGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: gradientHexes.light), color, Color(hex: gradientHexes.deep)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Claude  Date 06/15/2026
    // Color of the animated shine sweep on a badge. White for every tier except
    // Legend, whose shine is gold — giving the requested "purple with gold glimmer".
    var glimmerColorHex: String {
        switch self {
        case .legend: return "#FFD479"   // warm gold
        default:      return "#FFFFFF"
        }
    }

    var glimmerColor: Color { Color(hex: glimmerColorHex) }

    // Claude  Date 06/16/2026
    // The top tiers get an extra twinkle (on top of the glint) so they stand out as
    // the prestige badges. Tune the set here.
    var hasPremiumShine: Bool { self == .diamond || self == .emerald || self == .legend }
}

// Claude  Date 06/13/2026
// A single achievement. The catalog is code-defined (like AppTheme.builtIns /
// CardStyle.all) — not Codable; only the unlocked *ids* persist (in AppStore).
// `isUnlocked` is evaluated against derived ProfileStats; AppStore makes the
// result *sticky* (once true, the id is kept forever — you don't un-earn a badge).
struct Achievement: Identifiable {
    let id: String
    let category: Category
    let tier: BadgeTier
    let title: String
    let detail: String
    let icon: String
    let isUnlocked: (ProfileStats) -> Bool

    var reward: Int { tier.reward }

    // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
    // The big-3 lift is now split into three separate categories (squat / bench /
    // deadlift), each with its own tiered badges.
    enum Category: String, CaseIterable {
        case daysLogged, squat, bench, deadlift, totalLifted, streak
        // Claude  Date 07/11/2026
        // Two new categories: curl (Bicep Curl, an isolation lift tracked like the
        // big-3 but not flagged isBig3Lift) and daysTracked (nutrition — distinct
        // days the food diary landed within 75%-100% of the calorie goal).
        case curl, daysTracked

        var title: String {
            switch self {
            case .daysLogged:  return "Days Logged"
            case .squat:       return "Back Squat"
            case .bench:       return "Bench Press"
            case .deadlift:    return "Deadlift"
            case .totalLifted: return "Total Lifted"
            case .streak:      return "Week Streak"
            case .curl:        return "Bicep Curl"
            case .daysTracked: return "Days Tracked"
            }
        }

        // Claude  Date 06/15/2026
        // The single source of truth for each category's badge glyph. Tier is shown
        // by the medallion color/frame, so there's ONE glyph per category (not per
        // tier). These are placeholder SF Symbols — to use dedicated badge art,
        // import each as a custom SF Symbol and swap the string here for its asset
        // name (BadgeView loads custom-symbol assets automatically; see glyphImage).
        var iconName: String {
            switch self {
            case .daysLogged:  return "calendar"
            case .squat:       return "badge_squat"
            case .bench:       return "badge_benchPress"
            case .deadlift:    return "badge_deadlift"
            case .totalLifted: return "scalemass.fill"
            case .streak:      return "flame.fill"
            case .curl:        return "dumbbell.fill"
            case .daysTracked: return "fork.knife"
            }
        }

        // Whether this is one of the big-3 lift categories (for shared UI like the
        // explainer info button).
        var isBig3Lift: Bool { self == .squat || self == .bench || self == .deadlift }
    }

    // Claude  Date 06/13/2026 last changed: 06/15/2026 by: Claude
    // The 42-achievement catalog: 6 categories × 7 tiers. Thresholds map to tiers
    // in order (bronze → legend). Top tiers (diamond/emerald/legend) are tuned so a
    // natural, drug-free lifter can realistically reach them — notably the big-3,
    // where bench has a lower ceiling than squat/deadlift (see big3Specs).
    static let all: [Achievement] = {
        let tiers: [BadgeTier] = [.bronze, .silver, .gold, .platinum, .diamond, .emerald, .legend]
        var result: [Achievement] = []

        // Days Logged — distinct days trained. Claude 07/09/2026: scaled back to
        // 1/5/10/25/50/100/365 (365 = a full year of training days). "Centurion" now
        // correctly lands on the 100-day tier.
        let loggedThresholds = [1, 5, 10, 25, 50, 100, 365]
        let loggedTitles = ["First Day", "Regular", "Dedicated", "Devotee",
                            "Veteran", "Centurion", "Year One"]
        for (i, tier) in tiers.enumerated() {
            let n = loggedThresholds[i]
            result.append(Achievement(
                id: "logged_\(n)", category: .daysLogged, tier: tier,
                title: loggedTitles[i], detail: "Log \(n) \(n == 1 ? "day" : "days")",
                icon: Category.daysLogged.iconName, isUnlocked: { $0.daysLogged >= n }))
        }

        // Big-3 Lifts — each tracked separately (best set weight per lift), and each
        // carries its OWN thresholds + titles: squat/deadlift climb to 7 plates (675
        // lb), while bench tops out at 405 lb — the natural-athlete ceiling for a
        // raw press. Glyphs come from each category's iconName (one per lift).
        let squatDLThresholds = [135, 225, 315, 405, 495, 585, 675]
        let plateTitles = ["One Plate", "Two Plates", "Three Plates", "Four Plates",
                           "Five Plates", "Six Plates", "Seven Plates"]
        let benchThresholds = [135, 185, 225, 275, 315, 365, 405]
        let benchTitles = ["One Plate", "Plate & a Quarter", "Two Plates",
                           "Two & a Quarter", "Three Plates", "Three & a Quarter",
                           "Four Plates"]
        let big3Specs: [(category: Category, id: String, verb: String,
                         thresholds: [Int], titles: [String],
                         best: (ProfileStats) -> Double)] = [
            (.squat,    "squat",    "Squat",    squatDLThresholds, plateTitles, { $0.bestSquatLift }),
            (.bench,    "bench",    "Bench",    benchThresholds,   benchTitles, { $0.bestBenchLift }),
            (.deadlift, "deadlift", "Deadlift", squatDLThresholds, plateTitles, { $0.bestDeadliftLift }),
        ]
        for spec in big3Specs {
            for (i, tier) in tiers.enumerated() {
                let w = spec.thresholds[i]
                result.append(Achievement(
                    id: "\(spec.id)_\(w)", category: spec.category, tier: tier,
                    title: spec.titles[i], detail: "\(spec.verb) \(w) lb",
                    icon: spec.category.iconName, isUnlocked: { spec.best($0) >= Double(w) }))
            }
        }

        // Total Lifted — lifetime volume (Σ reps × weight). The 50k/day credit cap
        // (AchievementPolicy) means the top tiers take real elapsed years.
        let volThresholds = [100_000, 500_000, 2_000_000, 10_000_000,
                             25_000_000, 50_000_000, 100_000_000]
        let volTitles = ["100K Club", "Half Million", "Two Million", "Ten Million",
                         "25 Million", "50 Million", "Nine-Figure"]
        for (i, tier) in tiers.enumerated() {
            let v = volThresholds[i]
            result.append(Achievement(
                id: "volume_\(v)", category: .totalLifted, tier: tier,
                title: volTitles[i], detail: "Lift \(compactNumber(v)) lb total",
                icon: Category.totalLifted.iconName, isUnlocked: { $0.totalVolume >= Double(v) }))
        }

        // Claude  Date 07/11/2026
        // Bicep Curl — a standalone isolation-lift badge (not part of the big-3).
        // Thresholds tuned lower than the compound lifts (single-joint isolation).
        let curlThresholds = [20, 40, 60, 80, 100, 140, 160]
        let curlTitles = ["First Pump", "Building Guns", "Solid Curl", "Strong Arms",
                          "Advanced Curl", "Elite Curl", "Legendary Curl"]
        for (i, tier) in tiers.enumerated() {
            let w = curlThresholds[i]
            result.append(Achievement(
                id: "curl_\(w)", category: .curl, tier: tier,
                title: curlTitles[i], detail: "Curl \(w) lb",
                icon: Category.curl.iconName, isUnlocked: { $0.bestCurlLift >= Double(w) }))
        }

        // Claude  Date 07/11/2026
        // Days Tracked — distinct days the food diary landed within 75%-100% of the
        // calorie goal (ProfileStats.daysNutritionOnGoal). Same day-count scale as
        // Days Logged, since both measure "how many days did you show up."
        // Claude  Date 07/11/2026
        // Gold/Platinum/Diamond titles rotated per request: Gold<-"Consistent"
        // (was Platinum's), Platinum<-"Disciplined" (was Diamond's), Diamond<-"Dialed
        // In" (was Gold's). Thresholds/tiers/rewards unchanged — titles only.
        let nutritionThresholds = [1, 5, 10, 25, 50, 100, 365]
        let nutritionTitles = ["First Bite", "On Track", "Consistent", "Disciplined",
                               "Dialed In", "Nutrition Pro", "Full Year Fueled"]
        for (i, tier) in tiers.enumerated() {
            let n = nutritionThresholds[i]
            result.append(Achievement(
                id: "nutrition_\(n)", category: .daysTracked, tier: tier,
                title: nutritionTitles[i],
                detail: "Track \(n) \(n == 1 ? "day" : "days") within your calorie goal",
                icon: Category.daysTracked.iconName, isUnlocked: { $0.daysNutritionOnGoal >= n }))
        }

        // Week Streak — consecutive weeks trained (sticky once earned). Claude
        // 07/09/2026: reworked to 2/5/10/26/43/52/104 weeks. The upper tiers hit
        // round day-milestones: 26 wk ≈ half year, 43 wk ≈ 300 days, 52 wk = a year,
        // 104 wk = two years (the ceiling).
        let streakThresholds = [2, 5, 10, 26, 43, 52, 104]
        let streakTitles = ["On a Roll", "Committed", "Locked In", "Half Year",
                            "300 Days", "Year-Rounder", "Two-Year"]
        for (i, tier) in tiers.enumerated() {
            let w = streakThresholds[i]
            result.append(Achievement(
                id: "streak_\(w)", category: .streak, tier: tier,
                title: streakTitles[i], detail: "Reach a \(w)-week streak",
                icon: Category.streak.iconName, isUnlocked: { $0.weekStreak >= w }))
        }

        return result
    }()

    private static func compactNumber(_ value: Int) -> String {
        if value >= 1_000_000 { return "\(value / 1_000_000)M" }
        if value >= 1_000 { return "\(value / 1_000)K" }
        return "\(value)"
    }
}

// Claude  Date 06/13/2026
// Resolves which badges appear on the profile card: a "featured" row (the user's
// pinned picks, auto-filled with their best unlocked, padded with locked slots)
// and a "shelf" of the rest of their unlocked badges.
enum AchievementShowcase {
    static let maxFeatured = 4

    // Claude  Date 06/13/2026 last changed: 06/15/2026 by: Claude
    // Tier ordering for sorting (low → high). Diamond sits above platinum, then
    // emerald, with legend as the apex.
    static func tierRank(_ tier: BadgeTier) -> Int {
        switch tier {
        case .bronze:   return 0
        case .silver:   return 1
        case .gold:     return 2
        case .platinum: return 3
        case .diamond:  return 4
        case .emerald:  return 5
        case .legend:   return 6
        }
    }

    /// All unlocked achievements, best (highest tier) first.
    static func unlockedSorted(_ unlockedIDs: Set<String>) -> [Achievement] {
        Achievement.all
            .filter { unlockedIDs.contains($0.id) }
            .sorted { tierRank($0.tier) > tierRank($1.tier) }
    }

    /// The `maxFeatured` slots for the card's top row: EXACTLY the user's picks (in their
    /// chosen order, if still unlocked), then `nil` placeholders (rendered as locked/empty)
    /// to fill the row. No auto-fill — the card shows only what the user explicitly chose
    /// in the Featured Badges picker.
    // Claude  Date 06/13/2026 last changed: 07/01/2026 by: Claude
    static func featured(unlockedIDs: Set<String>, pinnedIDs: [String]) -> [Achievement?] {
        let unlocked = Achievement.all.filter { unlockedIDs.contains($0.id) }
        var slots: [Achievement?] = pinnedIDs
            .compactMap { id in unlocked.first { $0.id == id } }
            .prefix(maxFeatured)
            .map { Optional($0) }
        while slots.count < maxFeatured { slots.append(nil) }
        return slots
    }
}
