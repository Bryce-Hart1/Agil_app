import Foundation

// CLAUDE  Date 09/19/2026
// Builds the plan the setup wizard previews and the hub re-derives: BMR, the three-part
// expenditure, the calorie target, the macros and the projected goal, from inputs the user
// has just typed. Pure — the wizard can call it on every keystroke, and the harness can
// check its numbers without a store.
enum BodyPlanBuilder {

    struct Preview {
        var bmr: Double
        var trainingBurnPerDay: Double
        var everydayCalories: Double
        var tdee: Double
        /// The pace the plan asked for, and the one the floors actually allow.
        var requestedWeeklyLb: Double
        var effectiveWeeklyLb: Double
        var targets: PlanTargets
        var goalWeightLb: Double?
        var weeksToGoal: Double?
        var model: EnergyModel
        var flags: [SafetyFlag]
        /// True while the plan is still running on formulas rather than the user's own results.
        var isEstimateOnly: Bool { model.observations == 0 }
    }

    // CLAUDE  Date 09/19/2026
    // `sessions` are the last 28 days of logged training; when there aren't enough, the
    // training days the user typed stand in. Everything else starts at its default and is
    // learned from the check-ins — there is no activity question to get wrong.
    static func preview(track: PlanTrack, phase: PlanPhase, pace: Pace,
                        metrics: BodyMetrics, weightLb: Double, bodyFatPct: Double?,
                        targetBodyFatPct: Double?, targetWeightLb: Double?,
                        style: MacroStyle = .recommended,
                        sessions: [SessionSample] = [], windowKeys: [String] = [],
                        previousModel: EnergyModel? = nil) -> Preview {
        var model = previousModel ?? EnergyModel()

        let measuredBurn = DataTrust.trainingBurnPerDay(samples: sessions, windowKeys: windowKeys,
                                                        trust: model.activityTrust)
        model.trainingBurnPerDay = measuredBurn > 0
            ? measuredBurn
            : EnergyMath.coldStartTrainingBurn(trainingDaysPerWeek: metrics.trainingDaysPerWeek,
                                               weightLb: weightLb)

        let bmr = EnergyMath.bmr(sex: metrics.sex, weightLb: weightLb,
                                 heightCm: metrics.heightCm, age: metrics.age(),
                                 bodyFatPct: bodyFatPct)
        let tdee = EnergyMath.tdee(bmr: bmr, model: model)
        let floor = BodySafety.calorieFloor(sex: metrics.sex, bmr: bmr)
        let requested = pace.signedWeeklyLb(bodyweightLb: weightLb, phase: phase)
        let target = EnergyMath.calorieTarget(tdee: tdee, weeklyRateLb: requested,
                                              floor: floor, phase: phase)

        let leanMassLb = bodyFatPct.map { weightLb * (1 - $0 / 100) }
        let macros = MacroPlanner.targets(calories: target.calories, track: track, phase: phase,
                                          weightLb: weightLb, heightCm: metrics.heightCm,
                                          leanMassLb: leanMassLb, style: style,
                                          allowCalorieRaise: true)

        var flags = target.flags + macros.flags
        let goal = goalWeight(phase: phase, weightLb: weightLb, leanMassLb: leanMassLb,
                              targetBodyFatPct: targetBodyFatPct, targetWeightLb: targetWeightLb)
        if let goal, goal < BodySafety.minimumHealthyWeightLb(heightCm: metrics.heightCm) {
            flags.append(.belowHealthyWeight)
        }
        if phase == .cut, plannedIsBelowFloor(target: target) { flags.append(.calorieFloorReached) }

        let weeks = goal.flatMap {
            EnergyMath.weeksToGoal(currentLb: weightLb, targetLb: $0,
                                   weeklyRateLb: target.effectiveWeeklyLb)
        }

        return Preview(bmr: bmr,
                       trainingBurnPerDay: model.trainingBurnPerDay,
                       everydayCalories: bmr * (model.everydayFactor - 1),
                       tdee: tdee,
                       requestedWeeklyLb: requested,
                       effectiveWeeklyLb: target.effectiveWeeklyLb,
                       targets: macros.targets,
                       goalWeightLb: goal,
                       weeksToGoal: weeks,
                       model: model,
                       flags: dedupe(flags))
    }

    // CLAUDE  Date 09/19/2026
    // Where the phase is headed: a body-fat target becomes a weight by holding lean mass
    // (stated in the UI as an assumption), and everything else uses the weight the user set.
    static func goalWeight(phase: PlanPhase, weightLb: Double, leanMassLb: Double?,
                           targetBodyFatPct: Double?, targetWeightLb: Double?) -> Double? {
        if let targetBodyFatPct, let leanMassLb, phase != .maintain {
            return EnergyMath.targetWeight(leanMassLb: leanMassLb, targetBodyFatPct: targetBodyFatPct)
        }
        return targetWeightLb
    }

    // MARK: - Validation the wizard shows inline

    /// Body-fat goals below the floor aren't offered — that territory is contest prep, which
    /// Agil deliberately doesn't plan.
    static func isTargetBodyFatAllowed(_ target: Double, sex: BiologicalSex) -> Bool {
        target >= BodySafety.targetBodyFatFloor(sex)
    }

    static func isTargetWeightAllowed(_ target: Double, heightCm: Double) -> Bool {
        target >= BodySafety.minimumHealthyWeightLb(heightCm: heightCm)
    }

    private static func plannedIsBelowFloor(target: EnergyMath.CalorieTarget) -> Bool {
        target.flags.contains(.calorieFloorReached)
    }

    private static func dedupe(_ flags: [SafetyFlag]) -> [SafetyFlag] {
        var seen = Set<SafetyFlag>()
        return flags.filter { seen.insert($0).inserted }
    }
}
