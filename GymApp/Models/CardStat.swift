import Foundation

// CLAUDE  Date 09/05/2026
// The catalogue of stats that can be placed on the BACK of the profile card. Modeled on
// ProgressWidgetKind: a String-raw registry so ids can persist in profile.json and an
// id this build no longer knows is dropped rather than failing the decode.
enum CardStat: String, CaseIterable, Identifiable {
    // Ledger-backed — derived from the append-only ActivityEvent log, so these are the
    // numbers that stay honest when the card is shared.
    case daysActive
    case weekStreak
    case totalVolume
    case setsLogged
    case heaviestSet
    case bestSquat
    case bestBench
    case bestDeadlift
    case bestCurl
    case topPersonalRecord

    // Display-path — ProfileStats(events:) deliberately leaves these neutral, so they
    // come from the editable workouts instead. Flavour, never a leaderboard number.
    case workouts
    case lastWorkout
    case topMuscleGroup
    case favoriteLift

    // Nutrition world.
    case daysOnCalorieGoal

    var id: String { rawValue }

    // CLAUDE  Date 09/05/2026
    // Which ProfileStats init a stat reads from. This is the whole hybrid rule in one
    // property: anything comparable between friends comes off the tamper-resistant
    // ledger; the rest is flavour the ledger init zeroes on purpose.
    enum Source { case ledger, display }

    var source: Source {
        switch self {
        case .workouts, .lastWorkout, .topMuscleGroup, .favoriteLift: return .display
        default: return .ledger
        }
    }

    // CLAUDE  Date 09/05/2026
    // True when the rendered value embeds a string the USER typed — an exercise name,
    // a brand, or a custom muscle group (all three are free TextFields with no
    // validation beyond non-empty). These tiles render locally but must never leave the
    // device until the backend screens them; see docs/card_contract.md.
    var carriesUserText: Bool {
        switch self {
        case .topPersonalRecord, .topMuscleGroup, .favoriteLift: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .daysActive:        return "Days Active"
        case .weekStreak:        return "Week Streak"
        case .totalVolume:       return "Volume Lifted"
        case .setsLogged:        return "Sets Logged"
        case .heaviestSet:       return "Heaviest Set"
        case .bestSquat:         return "Best Squat"
        case .bestBench:         return "Best Bench"
        case .bestDeadlift:      return "Best Deadlift"
        case .bestCurl:          return "Best Curl"
        case .topPersonalRecord: return "Top PR"
        case .workouts:          return "Workouts"
        case .lastWorkout:       return "Last Workout"
        case .topMuscleGroup:    return "Top Muscle Group"
        case .favoriteLift:      return "Favorite Lift"
        case .daysOnCalorieGoal: return "Days On Goal"
        }
    }

    var detail: String {
        switch self {
        case .daysActive:        return "Distinct days you completed a set."
        case .weekStreak:        return "Consecutive weeks with a workout."
        case .totalVolume:       return "Every rep times every pound, added up."
        case .setsLogged:        return "Total sets completed in real time."
        case .heaviestSet:       return "The single heaviest set you have logged."
        case .bestSquat:         return "Your confirmed best squat."
        case .bestBench:         return "Your confirmed best bench press."
        case .bestDeadlift:      return "Your confirmed best deadlift."
        case .bestCurl:          return "Your confirmed best bicep curl."
        case .topPersonalRecord: return "Your strongest set across every lift."
        case .workouts:          return "Sessions you have finished."
        case .lastWorkout:       return "How long since your last session."
        case .topMuscleGroup:    return "The muscle group you train most."
        case .favoriteLift:      return "Your most-trained lift lately."
        case .daysOnCalorieGoal: return "Days the food diary landed on goal."
        }
    }

    var systemImage: String {
        switch self {
        case .daysActive:        return "calendar"
        case .weekStreak:        return "flame.fill"
        case .totalVolume:       return "scalemass.fill"
        case .setsLogged:        return "list.bullet.rectangle.fill"
        case .heaviestSet:       return "dumbbell.fill"
        case .bestSquat:         return "figure.strengthtraining.functional"
        case .bestBench:         return "figure.strengthtraining.traditional"
        case .bestDeadlift:      return "figure.strengthtraining.functional"
        case .bestCurl:          return "figure.arms.open"
        case .topPersonalRecord: return "trophy.fill"
        case .workouts:          return "checkmark.seal.fill"
        case .lastWorkout:       return "clock.arrow.circlepath"
        case .topMuscleGroup:    return "chart.pie.fill"
        case .favoriteLift:      return "heart.fill"
        case .daysOnCalorieGoal: return "fork.knife"
        }
    }

    // The most number of tiles the back's grid holds, beside the hero. Mirrors
    // AchievementShowcase.maxFeatured so both faces train the same "4 slots" idea.
    static let maxTiles = 4
}

// CLAUDE  Date 09/05/2026
// Resolves persisted raw ids back into stats, dropping anything unknown or duplicated
// — the same defensive shape as ProgressWidgetLayout.widgets(from:mode:), minus the
// comma-string encoding (profile.json stores a real array).
enum CardStatLayout {
    static func stats(from ids: [String], limit: Int = CardStat.maxTiles) -> [CardStat] {
        var seen = Set<String>()
        return ids.compactMap { raw in
            guard seen.insert(raw).inserted else { return nil }
            return CardStat(rawValue: raw)
        }
        .prefix(limit)
        .map { $0 }
    }

    static func ids(for stats: [CardStat]) -> [String] { stats.map(\.rawValue) }
}
