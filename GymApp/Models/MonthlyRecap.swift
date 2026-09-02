import Foundation

// Claude  Date 08/16/2026
// The rolling 30-day recap shown at the top of the Progress tab. Nothing in the app
// aggregated over a WINDOW before — the dashboard's stat cards are lifetime totals and
// its charts are per-week/per-exercise — so there was no answer to "how did my last
// month actually go?" This is that answer: totals, consistency, the standout session,
// personal records, body-part frequency shifts, and per-lift 1RM movement, each paired
// with the same figure for the PRECEDING 30 days so everything can read as a delta.
//
// Rolling (asOf − 30d) rather than a calendar month, deliberately: a calendar recap is
// nearly empty for the first few days of every month and the comparison window keeps
// changing length. A fixed 30/30 split is always fair and always populated.
//
// Data sourcing follows the app's standing rule — anything that "competes" reads the
// append-only ActivityEvent ledger, never the editable workout numbers. So sets, volume,
// training days, streak, region shifts, PRs and strength shifts all come from `events`;
// only the workout COUNT and the best-session pick need `workouts` (the ledger has no
// session id). Window membership for a workout uses `finishedAt ?? date`, since `date`
// is user-editable and the wall-clock finish stamp is not.
//
// Pure Foundation — no SwiftUI, no AppStore — like WorkoutSummary and ProfileStats, so
// it stays previewable and testable.
struct MonthlyRecap {

    /// Default length of the window, and of the comparison window before it.
    static let windowDays = 30

    // Claude  Date 08/16/2026
    // Sets performed for one body REGION (MuscleRegion — Legs, Back…) this window vs
    // last. Region, not the finer `Exercise.category` the sets-per-muscle-group chart
    // uses: at 7 regions the shifts are readable in a four-row card, where the ~20
    // sub-groups would be noise.
    struct RegionShift: Identifiable {
        let region: MuscleRegion
        let sets: Int
        let previousSets: Int

        var id: MuscleRegion { region }

        /// Fractional change vs the previous window. nil when there's no previous
        /// window to divide by — that's "New", not "+∞%".
        var percentChange: Double? {
            guard previousSets > 0 else { return nil }
            return (Double(sets) - Double(previousSets)) / Double(previousSets)
        }

        // Claude  Date 08/16/2026
        // Ranking weight: how far the row moved, damped by how much work backs it. Raw
        // percentage alone puts 2-sets-vs-1 (+100%) above back work going 40 → 70
        // (+75%), which is the opposite of the story. The confidence factor saturates at
        // 10 sets across both windows, so anything genuinely trained ranks on its change
        // and one-off accessory work can't take the top row. A brand-new region counts
        // as a full 100% move.
        var magnitude: Double {
            let change = percentChange.map(abs) ?? 1
            let confidence = min(1, Double(sets + previousSets) / 10)
            return change * confidence
        }
    }

    // Claude  Date 08/16/2026
    // Movement in one lift's best estimated 1RM between the two windows. Only lifts
    // trained in BOTH windows qualify — with nothing to compare against, a number here
    // would just restate the PR list.
    struct StrengthShift: Identifiable {
        let exerciseId: UUID
        let name: String
        let currentBest: Double      // best e1RM in the window (lb)
        let previousBest: Double     // best e1RM in the previous window (lb)

        var id: UUID { exerciseId }
        var deltaPounds: Double { currentBest - previousBest }
    }

    let windowStart: Date
    let windowEnd: Date
    /// False for all-time recaps, where no equally sized earlier period exists.
    let hasComparisonWindow: Bool

    let workouts: Int
    let previousWorkouts: Int
    let totalSets: Int
    let previousSets: Int
    let totalVolume: Double          // Σ reps × weight, lb
    let previousVolume: Double
    let trainingDays: Int
    let previousTrainingDays: Int

    /// Longest run of consecutive calendar days with a logged set, inside the window.
    let longestStreak: Int
    /// Most-trained lift by set count in the window.
    let topExerciseName: String?

    let bestSession: WorkoutSummary?
    let bestSessionDate: Date?
    /// All-time personal records whose winning set was logged inside the window.
    let personalRecords: [PersonalRecord]
    /// Biggest movers by |change|, most-moved first.
    let regionShifts: [RegionShift]
    /// Gains only, largest first.
    let strengthShifts: [StrengthShift]

    /// Whether there's anything worth showing. Set count, not workout count: an
    /// in-progress-only window has workouts but no credited work.
    var hasData: Bool { totalSets > 0 }

    // MARK: - Build

    // Bryce Hart  Date 09/02/2026
    // `days` lets the Progress toolbar expand this same recap to 90/180/365 days.
    // nil means all time; there is deliberately no previous comparison window in that
    // case, so the card shows honest totals without inventing a pre-history baseline.
    init(workouts allWorkouts: [Workout], events: [ActivityEvent],
         exercises: [Exercise], asOf: Date = Date(), days: Int? = Self.windowDays) {
        let calendar = Calendar.current
        let end = asOf
        let finishedStamps = allWorkouts.compactMap { workout -> Date? in
            guard workout.isFinished else { return nil }
            return workout.finishedAt ?? workout.date
        }
        let earliest = (events.map(\.loggedAt) + finishedStamps).min() ?? end
        let start = days.flatMap { calendar.date(byAdding: .day, value: -$0, to: end) } ?? earliest
        let previousStart = days.flatMap { calendar.date(byAdding: .day, value: -($0 * 2), to: end) }

        windowStart = start
        windowEnd = end
        hasComparisonWindow = previousStart != nil

        // One dictionary, built once — the per-event `exercises.first { }` scan this
        // replaces would be O(events × library) on a ledger that only ever grows.
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        // Single pass over the ledger: bucket into current / previous / neither.
        var current: [ActivityEvent] = []
        var previous: [ActivityEvent] = []
        for event in events {
            if event.loggedAt >= start, event.loggedAt <= end {
                current.append(event)
            } else if let previousStart,
                      event.loggedAt >= previousStart, event.loggedAt < start {
                previous.append(event)
            }
        }

        totalSets = current.count
        previousSets = previous.count
        totalVolume = current.reduce(0) { $0 + Double($1.reps) * $1.weight }
        previousVolume = previous.reduce(0) { $0 + Double($1.reps) * $1.weight }

        let currentDays = Set(current.map { calendar.startOfDay(for: $0.loggedAt) })
        trainingDays = currentDays.count
        previousTrainingDays = Set(previous.map { calendar.startOfDay(for: $0.loggedAt) }).count
        longestStreak = Self.longestRun(of: currentDays, calendar: calendar)

        // Most-trained lift by set count. Ties break on name so the card doesn't
        // flip between two equally-trained lifts on every recompute.
        topExerciseName = Dictionary(grouping: current, by: \.exerciseId)
            .compactMap { id, group -> (String, Int)? in
                guard let name = byID[id]?.name else { return nil }
                return (name, group.count)
            }
            .max { ($0.1, $1.0) < ($1.1, $0.0) }?.0

        // Body-part frequency, by region. `.other` catches custom lifts with no region.
        var currentRegions: [MuscleRegion: Int] = [:]
        var previousRegions: [MuscleRegion: Int] = [:]
        for event in current { currentRegions[byID[event.exerciseId]?.region ?? .other, default: 0] += 1 }
        for event in previous { previousRegions[byID[event.exerciseId]?.region ?? .other, default: 0] += 1 }
        regionShifts = currentRegions
            .map { RegionShift(region: $0.key, sets: $0.value,
                               previousSets: previousRegions[$0.key] ?? 0) }
            .sorted { ($0.magnitude, $0.sets) > ($1.magnitude, $1.sets) }

        // Claude  Date 08/16/2026
        // Records are the app-wide all-time bests (PersonalRecord.bests reads the whole
        // ledger) filtered down to the ones STAMPED in this window — i.e. bests that are
        // still standing AND were set recently. Recomputing "best within the window"
        // instead would call a lift a record every month it was trained.
        personalRecords = PersonalRecord.bests(from: events, exercises: exercises)
            .filter { $0.achievedAt >= start && $0.achievedAt <= end }

        strengthShifts = Self.strengthShifts(current: current, previous: previous, byID: byID)

        // Finished sessions in the window, newest first — the workout COUNT plus the
        // pool the best session is picked from.
        let sessions = allWorkouts.filter { workout in
            guard workout.isFinished else { return false }
            let stamp = workout.finishedAt ?? workout.date
            return stamp >= start && stamp <= end
        }
        workouts = sessions.count
        previousWorkouts = previousStart.map { previousStart in
            allWorkouts.filter { workout in
                guard workout.isFinished else { return false }
                let stamp = workout.finishedAt ?? workout.date
                return stamp >= previousStart && stamp < start
            }.count
        } ?? 0

        let best = Self.bestSession(among: sessions, events: events, exercises: exercises)
        bestSession = best
        bestSessionDate = best?.date
    }

    // MARK: - Pieces

    // Claude  Date 08/16/2026
    // The window's standout session. A session whose best set was a personal record
    // always wins — that's the memorable one — and everything else ranks on total
    // volume, which is the honest "how much work was that" measure once no record was
    // set. Ties fall to more completed sets.
    //
    // Each summary is built against the ledger MINUS that session's own events, exactly
    // as AppStore.finishWorkout does; pass the full ledger and every session would set a
    // record against itself and the PR tier would be meaningless.
    private static func bestSession(among sessions: [Workout], events: [ActivityEvent],
                                    exercises: [Exercise]) -> WorkoutSummary? {
        sessions
            .map { workout -> WorkoutSummary in
                let ownSetIds = Set(workout.exercises.flatMap { $0.sets.map(\.id) })
                let history = events.filter { !ownSetIds.contains($0.setId) }
                return WorkoutSummary(workout: workout, exercises: exercises, history: history)
            }
            .filter { $0.completedSets > 0 }
            .max { a, b in
                let aPR = a.bestSet?.isPersonalRecord == true ? 1 : 0
                let bPR = b.bestSet?.isPersonalRecord == true ? 1 : 0
                return (aPR, a.totalVolume, a.completedSets) < (bPR, b.totalVolume, b.completedSets)
            }
    }

    // Claude  Date 08/16/2026
    // Best estimated 1RM per lift this window vs last. Bodyweight lifts and zero-weight
    // sets are excluded for the same reason the PR list excludes them: their `weight` is
    // ADDED load, so Epley on it isn't a one-rep max. Gains only — a card that opens with
    // "Bench −15 lb" after a deload week is a card people stop looking at.
    private static func strengthShifts(current: [ActivityEvent], previous: [ActivityEvent],
                                       byID: [UUID: Exercise]) -> [StrengthShift] {
        func bests(_ events: [ActivityEvent]) -> [UUID: Double] {
            var result: [UUID: Double] = [:]
            for event in events {
                guard let exercise = byID[event.exerciseId],
                      !exercise.isBodyweight, event.weight > 0 else { continue }
                // Shared Epley helper — the app's single 1RM curve.
                let e1RM = BestSetScoring.e1RM(weight: event.weight, reps: event.reps)
                result[event.exerciseId] = max(result[event.exerciseId] ?? 0, e1RM)
            }
            return result
        }

        let now = bests(current)
        let then = bests(previous)
        return now.compactMap { id, currentBest -> StrengthShift? in
            guard let previousBest = then[id], currentBest > previousBest,
                  let name = byID[id]?.name else { return nil }
            return StrengthShift(exerciseId: id, name: name,
                                 currentBest: currentBest, previousBest: previousBest)
        }
        .sorted { $0.deltaPounds > $1.deltaPounds }
    }

    /// Longest run of consecutive calendar days present in `days` (all start-of-day).
    private static func longestRun(of days: Set<Date>, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var run = 1
        let sorted = days.sorted()
        for (previous, day) in zip(sorted, sorted.dropFirst()) {
            if calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }
        return longest
    }
}

// Claude  Date 07/22/2026 last changed: 08/16/2026 by: Claude
// A personal record is one COHERENT best set — the winning set's reps and weight travel
// together (previously bestWeight and est 1RM could come from different sets).
// `achievedAt` (the ledger's real completion time) is what lets us surface the "last 5"
// on the Progress tab, and what MonthlyRecap filters on to find records set this window.
//
// (08/16) Moved here from ProgressDashboardView, where it was private, so the recap card
// and the PR list share one definition of "record" instead of two that can drift.
struct PersonalRecord: Identifiable {
    let id: UUID            // exercise id
    let name: String
    let isUnilateral: Bool
    let reps: Int           // reps of the winning set
    let weight: Double      // weight of the winning set (lb)
    let estOneRepMax: Double
    let achievedAt: Date    // loggedAt of the winning set — drives "last 5"
}

extension PersonalRecord {
    // Claude  Date 07/22/2026 last changed: 08/16/2026 by: Claude
    // Personal records derive from the append-only activity ledger, not the editable
    // workouts, so they're tamper-resistant like achievements and the best-set tile — and
    // only count sets from FINISHED workouts. For each weighted exercise the winning set is
    // the single event with the highest Epley e1RM; its reps/weight/time travel together as
    // one coherent "best set". Bodyweight lifts are excluded (their `weight` is added load,
    // so a 1RM is meaningless). Sorted most-recently-achieved first to feed the "last 5".
    static func bests(from events: [ActivityEvent], exercises: [Exercise]) -> [PersonalRecord] {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        var best: [UUID: ActivityEvent] = [:]
        for event in events {
            guard let exercise = byID[event.exerciseId],
                  !exercise.isBodyweight, event.weight > 0 else { continue }
            // Shared Epley helper — the app's single 1RM curve.
            let e1RM = BestSetScoring.e1RM(weight: event.weight, reps: event.reps)
            if let current = best[event.exerciseId],
               BestSetScoring.e1RM(weight: current.weight, reps: current.reps) >= e1RM {
                continue
            }
            best[event.exerciseId] = event
        }
        return best.compactMap { id, event in
            guard let exercise = byID[id] else { return nil }
            return PersonalRecord(
                // brandedName: PersonalRecord carries isUnilateral as its own field.
                id: id, name: exercise.brandedName, isUnilateral: exercise.isUnilateral,
                reps: event.reps, weight: event.weight,
                estOneRepMax: BestSetScoring.e1RM(weight: event.weight, reps: event.reps),
                achievedAt: event.loggedAt)
        }
        .sorted { $0.achievedAt > $1.achievedAt }
    }
}
