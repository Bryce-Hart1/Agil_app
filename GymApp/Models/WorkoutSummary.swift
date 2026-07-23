import Foundation

// Claude  Date 06/16/2026
// A snapshot of how a just-finished workout went, shown on the performance card the
// moment you complete a workout (before any achievement pops). Computed purely from
// the workout's CHECKED-OFF sets (the ones that earn credit), so it mirrors what was
// actually logged. Transient — built on finish, not persisted.
//
// Claude  Date 06/16/2026 last changed: 07/21/2026 by: Claude
// (07/21) `bestSet` no longer means "heaviest set". It's now a RELATIVE-EFFORT pick,
// scored against the user's own history for that same exercise (see BestSetScoring),
// with personal records outranking everything. Raw estimated 1RM crowned the same
// barbell lift every session, hid unilateral work, and read "0 lb" for bodyweight
// lifts. Pass the ledger via `history` to get the smart pick; omit it and the
// selection degrades to the old highest-e1RM behavior.
struct WorkoutSummary: Identifiable, Hashable {
    let id: UUID            // the workout's id (also keys the overlay)
    let date: Date
    let duration: TimeInterval   // span of the checked-off sets (first → last)
    let completedSets: Int
    let totalVolume: Double      // Σ reps × weight, in lb
    let exerciseCount: Int       // exercises with at least one checked set
    let bestSet: BestSet?

    // Claude  Date 06/16/2026 last changed: 07/21/2026 by: Claude
    // The standout set of the session. e1RM is Epley: weight × (1 + reps/30).
    // (07/21) Carries the context the tile needs to explain WHY this set won —
    // whether it beat the user's all-time best for the lift, and how it compares to
    // their usual — plus the exercise flags that change how the load reads.
    struct BestSet: Hashable {
        let exerciseName: String
        let reps: Int
        let weight: Double
        let estimatedOneRepMax: Double
        // Claude  Date 07/21/2026
        // The ranking score (BestSetScoring.score) — identical to `estimatedOneRepMax`
        // for normal lifts, but nominal-load-shifted for bodyweight ones. Kept separate
        // so comparisons against history stay in one space while the DISPLAYED 1RM stays
        // honest. Never shown directly.
        let score: Double
        let isPersonalRecord: Bool
        let previousBest: Double?        // all-time score before this session; nil = new lift
        let relativeToBaseline: Double?  // score ÷ recent baseline; nil = new lift
        let isBodyweight: Bool           // `weight` is ADDED load, not total
        let isUnilateral: Bool           // `weight` is per-side

        // Claude  Date 07/21/2026
        // How the load reads on the card. Bodyweight lifts show their weight as added
        // load ("+25 lb × 8") or name themselves when nothing is added, and unilateral
        // lifts say "per side" so the number isn't mistaken for a two-sided load.
        var loadText: String {
            let count = "\(reps)"
            if isBodyweight {
                return weight > 0 ? "+\(Int(weight)) lb × \(count)" : "Bodyweight × \(count)"
            }
            let load = "\(Int(weight)) lb × \(count)"
            return isUnilateral ? "\(load) per side" : load
        }

        // Claude  Date 07/21/2026
        // Estimated 1RM fragment appended after the load — omitted for bodyweight lifts,
        // where Epley runs on added load only and so isn't a real one-rep max.
        var oneRepMaxText: String? {
            isBodyweight ? nil : "~\(Int(estimatedOneRepMax)) lb 1RM"
        }

        // Claude  Date 07/21/2026
        // The one-line "why this set" under the load. A PR states what it beat; otherwise
        // we show how far above the user's usual it landed, but only past a 3% margin —
        // below that it's noise, and "1% above your usual" reads worse than saying nothing.
        var contextText: String? {
            if isPersonalRecord, let previous = previousBest {
                // Bodyweight PRs skip the number: their score blends added load and reps
                // against a nominal bodyweight, so a "+N lb" reading would be fiction.
                guard !isBodyweight else { return "New personal record" }
                let gain = Int((score - previous).rounded())
                return gain > 0 ? "+\(gain) lb over your best" : "New personal record"
            }
            guard let ratio = relativeToBaseline else { return "First time logging this lift" }
            let percent = Int(((ratio - 1) * 100).rounded())
            return percent >= 3 ? "\(percent)% above your usual" : nil
        }
    }

    // Claude  Date 06/16/2026 last changed: 07/21/2026 by: Claude
    // (07/21) `history` is the activity ledger MINUS this workout's own events — the
    // yardstick every set is scored against. It defaults to empty so previews and any
    // history-less caller still work; with no history the best-set pick simply falls
    // back to the session's highest estimated 1RM (the pre-07/21 behavior).
    init(workout: Workout, exercises: [Exercise], history: [ActivityEvent] = []) {
        id = workout.id
        date = workout.date

        func exercise(_ exerciseId: UUID) -> Exercise? {
            exercises.first { $0.id == exerciseId }
        }

        let histories = BestSetScoring.histories(from: history, exercises: exercises)

        var times: [Date] = []
        var volume = 0.0
        var sets = 0
        var exercisesWithSets = Set<UUID>()
        var candidates: [BestSet] = []

        for logged in workout.exercises {
            let ex = exercise(logged.exerciseId)
            let isBodyweight = ex?.isBodyweight ?? false
            let past = histories[logged.exerciseId]

            for set in logged.sets where set.completedAt != nil {
                sets += 1
                volume += Double(set.reps) * set.weight
                exercisesWithSets.insert(logged.exerciseId)
                if let t = set.completedAt { times.append(t) }

                let score = BestSetScoring.score(weight: set.weight, reps: set.reps,
                                                 isBodyweight: isBodyweight)
                let isPR = past?.allTimeBest.map { score > $0 } ?? false
                candidates.append(BestSet(
                    exerciseName: ex?.name ?? "Exercise",
                    reps: set.reps,
                    weight: set.weight,
                    estimatedOneRepMax: BestSetScoring.e1RM(weight: set.weight, reps: set.reps),
                    score: score,
                    isPersonalRecord: isPR,
                    previousBest: past?.allTimeBest,
                    relativeToBaseline: past?.baseline.map { score / $0 },
                    isBodyweight: isBodyweight,
                    isUnilateral: ex?.isUnilateral ?? false))
            }
        }

        completedSets = sets
        totalVolume = volume
        exerciseCount = exercisesWithSets.count
        bestSet = Self.pickBest(from: candidates)

        // Claude  Date 06/16/2026 last changed: 07/01/2026 by: Claude
        // Elapsed = the real session span (startedAt → finishedAt), so warm-up, rest
        // between sets, the stretch after your last set, and any time the app spent
        // backgrounded all count. The old measure — first checked set to last checked
        // set — undercounted all of that (and read 0 for a single-set session). Falls
        // back to that set-span for workouts finished before these stamps existed.
        if let finished = workout.finishedAt {
            duration = max(0, finished.timeIntervalSince(workout.startedAt))
        } else if let first = times.min(), let last = times.max() {
            duration = last.timeIntervalSince(first)
        } else {
            duration = 0
        }
    }

    // Claude  Date 07/21/2026
    // Crown the session's standout set, in tiers:
    //
    //   1. Personal records — a set that beat the user's all-time best for that exercise.
    //      Always wins, however modest the load; the biggest margin over the old best
    //      takes it. This is the ONLY way a bodyweight lift can claim the tile, since its
    //      score lives in a nominal-load space that isn't comparable to loaded lifts.
    //   2. Relative effort — how far above "your usual" for that exercise the set landed.
    //      Scale-free, so a great single-arm row can finally out-rank a routine squat.
    //   3. Fallback — no history at all (first-ever workout, or all-new lifts): plain
    //      highest estimated 1RM, which is exactly what this used to do.
    //
    // Ties inside a tier go to the higher raw score, then the higher rep count.
    private static func pickBest(from candidates: [BestSet]) -> BestSet? {
        func strongest(_ pool: [BestSet], by rank: (BestSet) -> Double) -> BestSet? {
            pool.max { a, b in
                (rank(a), a.score, a.reps) < (rank(b), b.score, b.reps)
            }
        }

        // 1. Records, by how far they cleared the old best.
        let records = candidates.filter(\.isPersonalRecord)
        if let pr = strongest(records, by: { set in
            guard let previous = set.previousBest, previous > 0 else { return 1 }
            return set.score / previous
        }) { return pr }

        // 2 & 3. Loaded lifts only — a bodyweight score isn't comparable to a barbell one.
        let loaded = candidates.filter { !$0.isBodyweight }
        if let relative = strongest(loaded.filter { $0.relativeToBaseline != nil },
                                    by: { $0.relativeToBaseline ?? 0 }) {
            return relative
        }
        if let heaviest = strongest(loaded, by: \.score) { return heaviest }

        // A session with nothing but bodyweight work: rather than leave the tile blank,
        // show its best set. No cross-type comparison happens here — there's nothing to
        // compare against.
        return strongest(candidates, by: \.score)
    }

    // Claude  Date 06/16/2026
    // "1h 5m" / "42 min" / "<1 min" — compact duration for the card.
    var durationText: String {
        let minutes = Int(duration) / 60
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m) min" }
        return "<1 min"
    }
}
