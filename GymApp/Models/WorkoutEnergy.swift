import Foundation

// CLAUDE  Date 09/19/2026
// What a logged session costs the plan, in NET calories — the energy planner's sibling of
// CardioPolicy, which it defers to for cardio METs and plausibility. Tune the numbers here
// only. Pure: callers hand it plain samples, so nothing in this file knows about Workout,
// the store, or the UI.
enum WorkoutEnergy {

    // CLAUDE  Date 09/19/2026
    // Resistance training, Compendium 02054 territory. 4.5 sits between its "light/moderate"
    // and "vigorous" entries, because a logged session is a mix of hard sets and standing
    // around, and over-crediting training is how a plan quietly stops working.
    static let liftingMET = 4.5

    /// Gross → net. Gross MET calories include the resting burn BMR already counts; adding
    /// them on top would double-count roughly 60–90 kcal an hour.
    static func netFromGross(_ gross: Double, met: Double) -> Double {
        guard met > 1 else { return 0 }
        return gross * (met - 1) / met
    }

    // CLAUDE  Date 09/19/2026
    // Cardio, straight through CardioPolicy so the plan and the workout card can never
    // disagree about a bout — including its plausibility gate, which returns nil (and so
    // earns nothing here) for a speed no human produces.
    static func cardioNetCalories(machine: CardioMachine, seconds: Int, meters: Double?,
                                  weightLb: Double) -> Double? {
        guard let gross = CardioPolicy.calories(machine: machine, seconds: seconds,
                                                meters: meters, bodyweightLb: weightLb)
        else { return nil }
        return netFromGross(gross, met: CardioPolicy.met(machine: machine, seconds: seconds,
                                                         meters: meters))
    }

    /// ACSM's form, the same one CardioPolicy uses, at the lifting MET and already net.
    static func liftingNetCalories(weightLb: Double, minutes: Double) -> Double {
        guard weightLb > 0, minutes > 0 else { return 0 }
        let kg = weightLb / CardioPolicy.lbPerKilogram
        return (liftingMET - 1) * 3.5 * kg / 200 * minutes
    }

    // CLAUDE  Date 09/19/2026
    // Working minutes for a lifting session — deliberately double-capped. `elapsed` can come
    // from a session the user forgot to finish (Workout.idleFinishLimit auto-finishes at an
    // hour of no sets), so the set count bounds it; and a real session's clock includes rest,
    // so the clock bounds the set estimate. nil when nothing was completed.
    static let minimumMinutes = 10.0
    static let maximumMinutes = 180.0

    static func liftingMinutes(elapsedSeconds: TimeInterval?, completedSets: Int) -> Double? {
        guard completedSets > 0 else { return nil }
        let fromSets = Double(completedSets) * 4 + 10
        let fromClock = (elapsedSeconds ?? 0) / 60
        let minutes = fromClock > 0 ? min(fromClock, fromSets) : fromSets
        return min(maximumMinutes, max(minimumMinutes, minutes))
    }

    /// Most net kcal one day may contribute, however much was logged.
    static func cappedDay(_ kcal: Double) -> Double {
        min(kcal, BodySafety.dailyTrainingBurnCap)
    }
}

// CLAUDE  Date 09/19/2026
// One logged session, reduced to what the energy model and the trust scoring need. BodyStore
// builds these from Workout + activityLog; keeping the shape plain is what lets the engine
// stay pure and testable. `isRealTime` records whether the sets were checked off live — the
// app's existing anti-backdating signal.
struct SessionSample: Hashable {
    var dayKey: String
    var netKcal: Double
    /// False when a bout failed CardioPolicy or a set failed AchievementPolicy's limits.
    var isPlausible: Bool
    /// False when the session carried no live timestamps and no matching ledger events.
    var isRealTime: Bool

    init(dayKey: String, netKcal: Double, isPlausible: Bool = true, isRealTime: Bool = true) {
        self.dayKey = dayKey
        self.netKcal = netKcal
        self.isPlausible = isPlausible
        self.isRealTime = isRealTime
    }
}
