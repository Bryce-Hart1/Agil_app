import Foundation

// Claude  Date 07/21/2026
// Scoring helpers behind the performance card's "Best Set" tile (see WorkoutSummary).
//
// Why this exists: picking the best set by raw estimated 1RM crowned the heaviest
// barbell lift every single session — accessories never surfaced, unilateral lifts
// were structurally excluded (single-arm loads are ~half), and bodyweight lifts read
// "0 lb" because their `weight` is ADDED load. Scoring each set against the user's OWN
// history for that same exercise fixes all three: the ratio is scale-free, so a lift
// only ever competes with its own past.
//
// Everything here is pure (no SwiftUI, no AppStore) and reads from the append-only
// ActivityEvent ledger rather than the editable workout numbers, so a "personal record"
// can't be conjured by retyping an old workout.
enum BestSetScoring {

    // Claude  Date 07/21/2026
    // Epley estimated one-rep max: weight × (1 + reps/30). The single home for this
    // formula — ProgressDashboardView's charts call it too, so the app can't drift into
    // two slightly different 1RM curves.
    static func e1RM(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(reps) / 30)
    }

    // Stand-in load for bodyweight lifts, used for RANKING ONLY and never displayed.
    // A pull-up logs `weight: 0` (the field means added load), and Epley on zero is zero
    // no matter the reps — so every bodyweight set would tie at 0 and rep count would
    // carry no signal. Scoring them as (nominal + added) restores a sensible ordering:
    // +25 × 5 vs bodyweight × 12 now compare on something. The exact constant doesn't
    // matter much because a bodyweight set is only ever measured against its own
    // exercise's history, where the constant sits on both sides of the comparison.
    static let nominalBodyweightLoad = 150.0

    // How many past sessions feed the "your usual" baseline. Short enough to track a
    // bulk/cut or a deload rather than averaging in ancient numbers, long enough that one
    // bad night doesn't make the next session look like a breakthrough.
    static let baselineSessionWindow = 5

    // Score for a single set, in the same units as its exercise's history entries.
    // Bodyweight lifts get the nominal-load treatment above; everything else is plain
    // Epley on the logged weight (which for unilateral lifts is the per-side load — fine,
    // since past unilateral sets were scored the same way).
    static func score(weight: Double, reps: Int, isBodyweight: Bool) -> Double {
        e1RM(weight: isBodyweight ? nominalBodyweightLoad + weight : weight, reps: reps)
    }

    // Claude  Date 07/21/2026
    // What the user has previously done on one exercise. `allTimeBest` decides personal
    // records; `baseline` is the "your usual" yardstick for relative effort. Both nil
    // when there's no prior history — a lift being logged for the first time can't be a
    // PR and has nothing to be relative to.
    struct ExerciseHistory: Hashable {
        let baseline: Double?
        let allTimeBest: Double?
    }

    // Claude  Date 07/21/2026
    // Build per-exercise history from the ledger. Sets are collapsed to one best score
    // per DAY before averaging: the ledger has no session id, and a day is the right
    // proxy (it also stops a high-volume session from dominating the mean with fifteen
    // near-identical entries). `allTimeBest` spans all history; `baseline` averages only
    // the most recent `baselineSessionWindow` days.
    //
    // Callers must pass a ledger that EXCLUDES the session being summarized, or a workout
    // will set a record against itself (see AppStore.finishWorkout).
    static func histories(from events: [ActivityEvent],
                          exercises: [Exercise]) -> [UUID: ExerciseHistory] {
        let bodyweightIds = Set(exercises.filter(\.isBodyweight).map(\.id))
        var result: [UUID: ExerciseHistory] = [:]

        for (exerciseId, exerciseEvents) in Dictionary(grouping: events, by: \.exerciseId) {
            let isBodyweight = bodyweightIds.contains(exerciseId)
            let calendar = Calendar.current

            // Best score per day, newest day first.
            var dayBests: [Date: Double] = [:]
            for event in exerciseEvents {
                let day = calendar.startOfDay(for: event.loggedAt)
                let s = score(weight: event.weight, reps: event.reps, isBodyweight: isBodyweight)
                dayBests[day] = max(dayBests[day] ?? 0, s)
            }
            guard !dayBests.isEmpty else { continue }

            let recent = dayBests.sorted { $0.key > $1.key }
                .prefix(baselineSessionWindow)
                .map(\.value)

            result[exerciseId] = ExerciseHistory(
                baseline: recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count),
                allTimeBest: dayBests.values.max())
        }
        return result
    }
}
