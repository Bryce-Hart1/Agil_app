import Foundation

// CLAUDE  Date 10/19/2026
// The best set a lift last had in a finished workout, kept on the LoggedExercise so a new set
// starts at a believable weight instead of 0. estimate(forReps:) rescales it to the set's rep
// count with Epley (BestSetScoring.e1RM). Pure: AppStore.savedWeight(for:) finds the anchor.
struct SavedWeight: Codable, Hashable {
    var weight: Double
    var reps: Int
    // Bodyweight lifts log ADDED load, and Epley on added load alone is not a real 1RM, so
    // they keep the last added weight at every rep count.
    var scalesWithReps: Bool

    /// Estimates snap to the plates a gym actually has.
    static let step = 2.5

    init(weight: Double, reps: Int, scalesWithReps: Bool = true) {
        self.weight = weight
        self.reps = reps
        self.scalesWithReps = scalesWithReps
    }

    /// The weight that should feel like the anchor set, done for `reps` reps. The anchor's own
    /// rep count returns the anchor weight untouched (no rounding), and anything unusable
    /// (zero or negative reps) falls back to it too.
    func estimate(forReps reps: Int) -> Double {
        guard scalesWithReps, reps > 0, reps != self.reps, self.reps > 0 else { return weight }
        let oneRepMax = BestSetScoring.e1RM(weight: weight, reps: self.reps)
        let raw = oneRepMax / (1 + Double(reps) / 30)
        return max(0, (raw / SavedWeight.step).rounded() * SavedWeight.step)
    }

    /// Whether `set` still carries the untouched estimate for its own reps, i.e. nobody has
    /// typed a weight over it. This is what lets a rep edit move the weight with it.
    func isUntouchedEstimate(_ set: ExerciseSet) -> Bool {
        set.completedAt == nil && abs(set.weight - estimate(forReps: set.reps)) < 0.001
    }

    /// Call after an edit has been written to `sets` (`before` = the same array just ahead of
    /// it). Any open set whose reps changed, whose weight did not, and whose old weight was
    /// still the untouched estimate gets the estimate for its new reps. Covers the edited set
    /// and a unilateral partner whose reps were filled along with it.
    func reestimate(_ sets: inout [ExerciseSet], after before: [ExerciseSet]) {
        guard sets.count == before.count else { return }
        for index in sets.indices
        where sets[index].reps != before[index].reps
            && sets[index].weight == before[index].weight
            && sets[index].reps > 0
            && isUntouchedEstimate(before[index]) {
            sets[index].weight = estimate(forReps: sets[index].reps)
        }
    }
}

extension LoggedExercise {
    // CLAUDE  Date 10/19/2026
    // Adaptive presets own their weight (double progression is not a rep estimate), so the
    // saved-weight estimate only drives a lift that has no adaptive suggestion.
    var weightEstimator: SavedWeight? { adaptive == nil ? savedWeight : nil }

    /// Where a new set of `reps` starts when the lift has no earlier set in this workout.
    func seedWeight(forReps reps: Int) -> Double {
        adaptive?.weight ?? savedWeight?.estimate(forReps: reps) ?? 0
    }
}
