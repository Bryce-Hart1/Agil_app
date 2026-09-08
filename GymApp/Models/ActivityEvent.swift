import Foundation

// Claude  Date 06/14/2026
// Append-only activity ledger entry — the tamper-resistant source of truth for
// achievements. Written ONLY when a set is explicitly marked complete
// (AppStore.completeSet), stamped with the real wall-clock time at that moment.
//
// Why this exists: badges used to be computed straight from editable workout
// numbers, so you could type weights / backdate workouts all in one session and
// unlock everything without ever performing a set. Ledger events are never
// rewritten when a workout is later edited, and days/streak are measured from
// `loggedAt` (real time) — so a whole history can't be fabricated at once.
//
// Notes:
//  - `countsAsBig3` is captured at log time, so renaming an exercise afterward
//    can't retroactively change earned credit.
//  - `setId` keys the event to its source set, making completion idempotent:
//    re-completing the same set logs nothing new (no double-counting volume).
struct ActivityEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let setId: UUID          // the ExerciseSet this came from (idempotency key)
    let exerciseId: UUID     // references an Exercise in the library
    let reps: Int
    let weight: Double       // pounds (lb), the canonical unit
    let loggedAt: Date       // real wall-clock time the set was completed
    // Claude  Date 06/14/2026
    // Which big-3 lift this was (squat/bench/deadlift), resolved at log time; nil for
    // any non-big-3 lift. Stored per-lift (not just a Bool) so each lift earns its
    // own badges. Frozen here so renaming/retagging an exercise can't change credit.
    let liftType: LiftType?
    // The exercise's region at completion time. New region-based achievements use
    // this frozen value so later library edits cannot rewrite earned progress.
    // Optional keeps activity logs from older app versions decodable.
    let muscleRegion: MuscleRegion?
    // Claude  Date 09/07/2026
    // A CARDIO BOUT's frozen numbers: `durationSeconds != nil` marks the event as cardio,
    // and such an event carries reps = 0 / weight = 0 so ProfileStats' plausibility filter
    // drops it from volume and lift credit on its own. Both are Optional because this type
    // uses SYNTHESIZED Codable — a non-optional would fail to decode every existing ledger.
    // Calories are deliberately NOT frozen here: they derive from an editable bodyweight, so
    // a stored value would go stale. If calories ever gate a badge, freeze them then.
    let durationSeconds: Int?
    let distanceMeters: Double?

    // Convenience: was this a big-3 lift at all.
    var countsAsBig3: Bool { liftType != nil }

    /// Whether this event came from a cardio bout rather than a loaded set.
    var isCardio: Bool { durationSeconds != nil }

    init(id: UUID = UUID(), setId: UUID, exerciseId: UUID,
         reps: Int, weight: Double, loggedAt: Date = Date(), liftType: LiftType? = nil,
         muscleRegion: MuscleRegion? = nil,
         durationSeconds: Int? = nil, distanceMeters: Double? = nil) {
        self.id = id
        self.setId = setId
        self.exerciseId = exerciseId
        self.reps = reps
        self.weight = weight
        self.loggedAt = loggedAt
        self.liftType = liftType
        self.muscleRegion = muscleRegion
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
    }
}
