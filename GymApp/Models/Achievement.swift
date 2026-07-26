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
        // Claude  Date 06/13/2026 last changed: 07/23/2026 by: Claude
        // Lighter, pearly platinum (was #3FD0E0) — reads as a paler silvery tier so
        // it no longer collides with diamond's icy blue.
        case .platinum: return "#7CE0EC"
        case .diamond:  return "#8FD3EF"   // icy blue (distinct from platinum/silver)
        case .emerald:  return "#10B981"   // rich green
        // Claude  Date 06/13/2026 last changed: 07/23/2026 by: Claude
        // Legend recolored from royal purple (#5B21B6) toward the Agil pink — a
        // pink→purple gem body with a gold facet finish (see gradientHexes +
        // glimmerColorHex). This drives the glow, confetti, and gradient mid-stop.
        case .legend:   return "#CE1C9A"   // magenta-pink (gold finish on top)
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
        case .platinum: return ("#E6FBFD", "#2FA9BA")
        case .diamond:  return ("#EAF7FF", "#4F8FCB")
        case .emerald:  return ("#4BE6A6", "#044F38")
        // Claude  Date 06/15/2026 last changed: 07/23/2026 by: Claude
        // Legend: bright pink highlight → deep royal purple (was purple #9B6CFF →
        // #2E0B5E). The gold reads from the facet finish, not the gem body.
        case .legend:   return ("#FF6FD3", "#3A0B63")
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

    // Claude  Date 07/23/2026 last changed: 07/23/2026 by: Claude
    // The gemstone tiers whose medallion/glyph renders as a faceted, cut-gem surface
    // (the GemFacetOverlay in BadgeView) instead of a plain material gradient. The
    // facet finish (highlight colour) comes from glimmerColor — white for diamond/
    // emerald, gold for Legend. Platinum stays a plain material. (Added Legend.)
    var hasGemFacets: Bool { self == .diamond || self == .emerald || self == .legend }
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
    // Claude  Date 07/24/2026
    // Hidden achievement: it exists in the catalog but its title/detail stay
    // concealed until it's earned, and the Achievement Book collects it on the
    // Secrets page instead of its category page. Deliberately ORTHOGONAL to
    // Category, so a future secret can belong to any category and still surface
    // in the right place. A `var` with a default (not a `let`) so it stays in the
    // memberwise init with all 56 existing call sites untouched. No secrets are
    // authored yet — adding one is a single `isSecret: true` append in build().
    var isSecret: Bool = false
    let isUnlocked: (ProfileStats) -> Bool

    var reward: Int { tier.reward }

    // Claude  Date 07/24/2026
    // Concealment helpers. Every view that shows a name or requirement must go
    // through these — reading `title`/`detail` directly on a locked secret would
    // spoil it, which is the whole point of the feature.
    func displayTitle(unlocked: Bool) -> String {
        isSecret && !unlocked ? "???" : title
    }

    func displayDetail(unlocked: Bool) -> String {
        isSecret && !unlocked ? "A hidden achievement. Keep training." : detail
    }

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

    // Claude  Date 06/13/2026 last changed: 07/14/2026 by: Claude
    // The 56-achievement catalog: 8 categories × 7 tiers. Thresholds map to tiers
    // in order (bronze → legend). Top tiers (diamond/emerald/legend) are tuned so a
    // natural, drug-free lifter can realistically reach them — notably the big-3,
    // where bench has a lower ceiling than squat/deadlift (see big3Specs).
    // (This pass: the catalog is now gender-calibrated — see catalog(for:) below —
    // and the stale "42/6" count in this header was corrected to 56/8.)

    // Claude  Date 07/14/2026
    // Gender-calibrated catalog. Strength categories (squat/bench/deadlift/curl/
    // totalLifted) carry female threshold+title variants tuned to natural female
    // strength ceilings; day/streak categories are identical. .male/.unspecified
    // use the baseline arrays. CRITICAL INVARIANT: achievement ids are ALWAYS
    // derived from the BASELINE threshold arrays, so the same 56 ids exist in
    // every variant — persisted unlock sets (achievements.json), pinned badges,
    // coin rewards, and Strategist rank scoring stay valid when the user changes
    // their identity in Settings. Unlocks are sticky either way (never removed).
    static func catalog(for gender: Gender) -> [Achievement] {
        gender == .female ? femaleCatalog : baselineCatalog
    }

    // Claude  Date 07/14/2026
    // Baseline alias kept for id/tier-only consumers (Coins, StrategistScoring,
    // previews) that don't care about gender-varying thresholds/titles.
    static let all: [Achievement] = baselineCatalog
    private static let baselineCatalog: [Achievement] = build(for: .unspecified)
    private static let femaleCatalog: [Achievement] = build(for: .female)

    private static func build(for gender: Gender) -> [Achievement] {
        let female = gender == .female
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
        // Claude  Date 07/14/2026
        // Female variants: plate-friendly bar loads with legend ≈ the natural female
        // ceiling (405 squat/DL, 225 bench). Ids still come from baselineThresholds
        // (see the invariant on catalog(for:)).
        let squatDLThresholds = [135, 225, 315, 405, 495, 585, 675]
        let plateTitles = ["One Plate", "Two Plates", "Three Plates", "Four Plates",
                           "Five Plates", "Six Plates", "Seven Plates"]
        let squatDLFemaleThresholds = [95, 135, 185, 225, 275, 315, 405]
        let squatDLFemaleTitles = ["Bar & Change", "One Plate", "185 Club", "Two Plates",
                                   "275 Club", "Three Plates", "Four Plates"]
        let benchThresholds = [135, 185, 225, 275, 315, 365, 405]
        let benchTitles = ["One Plate", "Plate & a Quarter", "Two Plates",
                           "Two & a Quarter", "Three Plates", "Three & a Quarter",
                           "Four Plates"]
        let benchFemaleThresholds = [65, 95, 115, 135, 155, 185, 225]
        let benchFemaleTitles = ["First Press", "95 Club", "115 Club", "One Plate",
                                 "155 Club", "185 Club", "Two Plates"]
        let big3Specs: [(category: Category, id: String, verb: String,
                         baselineThresholds: [Int], thresholds: [Int], titles: [String],
                         best: (ProfileStats) -> Double)] = [
            (.squat,    "squat",    "Squat",    squatDLThresholds,
             female ? squatDLFemaleThresholds : squatDLThresholds,
             female ? squatDLFemaleTitles : plateTitles, { $0.bestSquatLift }),
            (.bench,    "bench",    "Bench",    benchThresholds,
             female ? benchFemaleThresholds : benchThresholds,
             female ? benchFemaleTitles : benchTitles, { $0.bestBenchLift }),
            (.deadlift, "deadlift", "Deadlift", squatDLThresholds,
             female ? squatDLFemaleThresholds : squatDLThresholds,
             female ? squatDLFemaleTitles : plateTitles, { $0.bestDeadliftLift }),
        ]
        for spec in big3Specs {
            for (i, tier) in tiers.enumerated() {
                let w = spec.thresholds[i]
                result.append(Achievement(
                    id: "\(spec.id)_\(spec.baselineThresholds[i])", category: spec.category, tier: tier,
                    title: spec.titles[i], detail: "\(spec.verb) \(w) lb",
                    icon: spec.category.iconName, isUnlocked: { spec.best($0) >= Double(w) }))
            }
        }

        // Total Lifted — lifetime volume (Σ reps × weight). The 50k/day credit cap
        // (AchievementPolicy) means the top tiers take real elapsed years.
        // Claude  Date 07/14/2026
        // Female variant scales the lifetime targets (~60-75%) to match the lower
        // per-session tonnage of the calibrated lift thresholds. Ids stay baseline.
        let volBaseline = [100_000, 500_000, 2_000_000, 10_000_000,
                           25_000_000, 50_000_000, 100_000_000]
        let volFemale = [75_000, 300_000, 1_000_000, 6_000_000,
                         15_000_000, 30_000_000, 60_000_000]
        let volThresholds = female ? volFemale : volBaseline
        let volTitles = female
            ? ["75K Club", "300K Club", "First Million", "Six Million",
               "15 Million", "30 Million", "60 Million"]
            : ["100K Club", "Half Million", "Two Million", "Ten Million",
               "25 Million", "50 Million", "Nine-Figure"]
        for (i, tier) in tiers.enumerated() {
            let v = volThresholds[i]
            result.append(Achievement(
                id: "volume_\(volBaseline[i])", category: .totalLifted, tier: tier,
                title: volTitles[i], detail: "Lift \(compactNumber(v)) lb total",
                icon: Category.totalLifted.iconName, isUnlocked: { $0.totalVolume >= Double(v) }))
        }

        // Claude  Date 07/11/2026 last changed: 07/14/2026 by: Claude
        // Bicep Curl — a standalone isolation-lift badge (not part of the big-3).
        // Thresholds tuned lower than the compound lifts (single-joint isolation).
        // (Added the female threshold variant; titles are weight-agnostic and shared.
        // Ids stay derived from the baseline array.)
        let curlBaseline = [20, 40, 60, 80, 100, 140, 160]
        let curlThresholds = female ? [15, 25, 35, 45, 60, 80, 100] : curlBaseline
        let curlTitles = ["First Pump", "Building Guns", "Solid Curl", "Strong Arms",
                          "Advanced Curl", "Elite Curl", "Legendary Curl"]
        for (i, tier) in tiers.enumerated() {
            let w = curlThresholds[i]
            result.append(Achievement(
                id: "curl_\(curlBaseline[i])", category: .curl, tier: tier,
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

        // Claude  Date 07/25/2026
        // First Step — the welcome badge, and the first secret in the catalog (the
        // Secrets page needs no change to pick it up; see AchievementSecretsPage).
        // Fires the moment the user has actually acted on the Workouts tab's
        // get-started state: one completed set. `totalSets` is the ledger count of
        // real-time completed sets, so this stays behind the same anti-cheat boundary
        // as every other badge — note the events-based ProfileStats pins
        // `totalWorkouts` to 0, so "has a workout" is not an available signal here.
        // Category is inert for a secret (the Book routes isSecret entries to the
        // Secrets page and filters them out of the category spreads), so it rides on
        // .daysLogged, the closest "you showed up" grouping. The glyph is its OWN
        // asset rather than the category's, which the per-achievement `icon` allows.
        result.append(Achievement(
            id: "secret_first_step", category: .daysLogged, tier: .bronze,
            title: "First Step", detail: "Complete your first set",
            icon: "badge_firstStep", isSecret: true,
            isUnlocked: { $0.totalSets >= 1 }))

        return result
    }

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

    // Claude  Date 07/24/2026
    // How many slots the Achievement Book's Secrets page draws. Real secrets fill
    // from the front and the remainder are empty "?" mystery slots, so the page
    // reads like unfilled space in a stamp album rather than an empty screen.
    // Drop this to `Achievement.all.filter(\.isSecret).count` once enough secrets
    // are authored that the padding is no longer doing any work.
    static let secretSlotCount = 6

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
    // Claude  Date 07/14/2026
    // Takes the catalog as a parameter so callers can pass the gender-calibrated
    // variant (store.achievementCatalog) and show the right titles/details.
    static func unlockedSorted(_ unlockedIDs: Set<String>,
                               catalog: [Achievement] = Achievement.all) -> [Achievement] {
        catalog
            .filter { unlockedIDs.contains($0.id) }
            .sorted { tierRank($0.tier) > tierRank($1.tier) }
    }

    /// The `maxFeatured` slots for the card's top row: EXACTLY the user's picks (in their
    /// chosen order, if still unlocked), then `nil` placeholders (rendered as locked/empty)
    /// to fill the row. No auto-fill — the card shows only what the user explicitly chose
    /// in the Featured Badges picker.
    // Claude  Date 06/13/2026 last changed: 07/14/2026 by: Claude
    // (Now takes the catalog so the gender-calibrated variant's titles flow through.)
    static func featured(unlockedIDs: Set<String>, pinnedIDs: [String],
                         catalog: [Achievement] = Achievement.all) -> [Achievement?] {
        let unlocked = catalog.filter { unlockedIDs.contains($0.id) }
        var slots: [Achievement?] = pinnedIDs
            .compactMap { id in unlocked.first { $0.id == id } }
            .prefix(maxFeatured)
            .map { Optional($0) }
        while slots.count < maxFeatured { slots.append(nil) }
        return slots
    }
}
