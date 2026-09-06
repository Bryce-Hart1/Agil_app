import Foundation

// CLAUDE  Date 09/05/2026
// One resolved stat, ready to draw. The card back takes THESE, never an AppStore — a
// friend's device holds none of your training data (see SharedCard's privacy contract),
// so the back is a display payload, not a query. Building it this way now is what makes
// the eventual friend-card path additive.
struct CardStatValue: Identifiable, Hashable {
    let stat: CardStat
    let value: String
    let caption: String?
    // CLAUDE  Date 09/05/2026
    // Set only by wall-clock-derived stats (.lastWorkout). `value` renders it for the
    // local card, but the DATE is what a future sync must send: a baked "2d ago" would
    // change with no data change, defeating CardSyncService's lastPushed dedupe, and
    // would go stale on a friend's screen.
    let relativeDate: Date?

    var id: String { stat.rawValue }
    var hasData: Bool { value != Self.noData }

    static let noData = "—"
}

// CLAUDE  Date 09/05/2026
// The back's full contents: one hero stat above a grid of up to CardStat.maxTiles.
struct CardBackStats: Hashable {
    var hero: CardStatValue?
    var tiles: [CardStatValue]

    var isEmpty: Bool { hero == nil && tiles.isEmpty }

    static let empty = CardBackStats(hero: nil, tiles: [])
}

// CLAUDE  Date 09/05/2026
// The expensive half, built ONCE per data change and held in @State by the card's
// owner (the MonthlyRecap precedent in ProgressDashboardView). Takes primitives with
// defaults — the same shape as ProfileStats.init(events:...) — so Models never imports
// Persistence and this stays unit-testable.
struct CardStatInputs {
    let ledger: ProfileStats
    let display: ProfileStats
    let topRecord: PersonalRecord?
    let lastWorkoutDate: Date?
    let now: Date

    init(workouts: [Workout], exercises: [Exercise], activityLog: [ActivityEvent] = [],
         foodLog: [FoodEntry] = [], nutritionGoals: NutritionGoals = NutritionGoals(),
         now: Date = Date()) {
        display = ProfileStats(workouts: workouts, exercises: exercises)
        ledger = ProfileStats(events: activityLog, exercises: exercises,
                              foodLog: foodLog, nutritionGoals: nutritionGoals)
        // Highest estimated 1RM across every lift — bests() sorts by recency, not strength.
        topRecord = PersonalRecord.bests(from: activityLog, exercises: exercises)
            .max { $0.estOneRepMax < $1.estOneRepMax }
        // Only FINISHED sessions count; an open draft is not a workout you did.
        lastWorkoutDate = workouts.filter(\.isFinished).map { $0.finishedAt ?? $0.date }.max()
        self.now = now
    }
}

// CLAUDE  Date 09/05/2026
// Turns picked stats into drawable values. Pure formatting once CardStatInputs is
// built, so the card can call it on every render while the inputs stay cached.
enum CardStatResolver {
    static func backStats(hero: CardStat?, tiles: [CardStat],
                          inputs: CardStatInputs) -> CardBackStats {
        CardBackStats(hero: hero.map { value(for: $0, inputs: inputs) },
                      tiles: tiles.map { value(for: $0, inputs: inputs) })
    }

    static func value(for stat: CardStat, inputs: CardStatInputs) -> CardStatValue {
        let ledger = inputs.ledger
        let display = inputs.display

        switch stat {
        // CLAUDE  Date 09/05/2026
        // Days come off the LEDGER, not display.daysLogged — the latter counts
        // unfinished drafts, which must not inflate a number other people can see.
        case .daysActive:
            return make(stat, count(ledger.daysLogged))
        case .weekStreak:
            return make(stat, count(ledger.weekStreak),
                        caption: ledger.weekStreak > 0 ? "in a row" : nil)
        case .totalVolume:
            return make(stat, poundsText(ledger.totalVolume, abbreviating: true))
        case .setsLogged:
            return make(stat, count(ledger.totalSets))
        case .heaviestSet:
            return make(stat, poundsText(ledger.heaviestLift))
        case .bestSquat:
            return make(stat, poundsText(ledger.bestSquatLift))
        case .bestBench:
            return make(stat, poundsText(ledger.bestBenchLift))
        case .bestDeadlift:
            return make(stat, poundsText(ledger.bestDeadliftLift))
        case .bestCurl:
            return make(stat, poundsText(ledger.bestCurlLift))

        // The number is ledger-backed; only the NAME is user-authored. That split is
        // exactly why this stat is carriesUserText and cannot sync yet.
        case .topPersonalRecord:
            guard let record = inputs.topRecord else { return make(stat, CardStatValue.noData) }
            return make(stat, poundsText(record.weight),
                        caption: "\(record.displayName) · \(record.reps) reps")

        case .workouts:
            return make(stat, count(display.totalWorkouts))
        case .lastWorkout:
            guard let date = inputs.lastWorkoutDate else { return make(stat, CardStatValue.noData) }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return make(stat, formatter.localizedString(for: date, relativeTo: inputs.now),
                        relativeDate: date)
        case .topMuscleGroup:
            return make(stat, display.topMuscleGroup ?? CardStatValue.noData)
        case .favoriteLift:
            return make(stat, display.favoriteCurrentExercise ?? CardStatValue.noData)

        // The 75%–100%-of-goal band ProfileStats already uses for the Days Tracked
        // badge — deliberately the badge's definition, not the Progress widget's
        // looser ±200 kcal one, so a shared number matches an earned badge.
        case .daysOnCalorieGoal:
            return make(stat, count(ledger.daysNutritionOnGoal))
        }
    }

    // MARK: - Formatting

    private static func make(_ stat: CardStat, _ value: String,
                             caption: String? = nil,
                             relativeDate: Date? = nil) -> CardStatValue {
        CardStatValue(stat: stat, value: value, caption: caption, relativeDate: relativeDate)
    }

    private static func count(_ n: Int) -> String {
        n > 0 ? "\(n)" : CardStatValue.noData
    }

    /// Pounds for a card tile. Volume abbreviates past 10k (12,480 → "12.5k lb") — the
    /// same rule PerformanceCardView uses so the two card surfaces read alike.
    static func poundsText(_ pounds: Double, abbreviating: Bool = false) -> String {
        let rounded = pounds.rounded()
        guard rounded > 0 else { return CardStatValue.noData }
        if abbreviating && rounded >= 10_000 {
            return String(format: "%.1fk lb", rounded / 1_000)
        }
        return "\(Int(rounded)) lb"
    }
}
