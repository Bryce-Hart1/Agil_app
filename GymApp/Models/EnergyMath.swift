import Foundation

// CLAUDE  Date 09/19/2026
// The energy model: resting burn, the three-part expenditure split, and the calorie target.
// Pure arithmetic with no storage and no UI, so it can be exercised from a swiftc harness.
// Every limit it obeys lives in BodySafety; every number it produces is an ESTIMATE, and the
// surfaces that show them say so.
enum EnergyMath {

    // MARK: - Resting metabolism

    // CLAUDE  Date 09/19/2026
    // Katch-McArdle when a body-fat estimate exists, Mifflin-St Jeor otherwise. Katch is the
    // better formula AND the sex-independent one, which is why the planner pushes body fat at
    // users who'd rather not state a sex — it buys back most of the precision they gave up.
    static func bmr(sex: BiologicalSex, weightLb: Double, heightCm: Double,
                    age: Int, bodyFatPct: Double? = nil) -> Double {
        if let bodyFatPct, bodyFatPct > 0, bodyFatPct < 100 {
            return katchMcArdle(leanMassLb: weightLb * (1 - bodyFatPct / 100))
        }
        return mifflinStJeor(sex: sex, weightLb: weightLb, heightCm: heightCm, age: age)
    }

    /// 370 + 21.6 × lean kg. No sex term at all — lean mass already carries that information.
    static func katchMcArdle(leanMassLb: Double) -> Double {
        370 + 21.6 * (leanMassLb / CardioPolicy.lbPerKilogram)
    }

    // CLAUDE  Date 09/19/2026
    // 10·kg + 6.25·cm − 5·age + s. The undisclosed constant is the midpoint of the male and
    // female terms: the least wrong single answer when we genuinely don't know, and the
    // check-ins correct it from real results within a few weeks.
    static func mifflinStJeor(sex: BiologicalSex, weightLb: Double,
                              heightCm: Double, age: Int) -> Double {
        let kg = weightLb / CardioPolicy.lbPerKilogram
        let base = 10 * kg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male:        return base + 5
        case .female:      return base - 161
        case .undisclosed: return base - 78
        }
    }

    // MARK: - Expenditure

    // CLAUDE  Date 09/19/2026
    // TDEE as three separable parts: resting, measured training burn, and everything else as a
    // learned multiplier on BMR. Keeping them apart is what lets the plan drop training burn
    // when the session data can't be trusted, and what makes expenditure fall on its own when
    // someone stops training, instead of holding a stale total.
    static func tdee(bmr: Double, trainingBurnPerDay: Double, everydayFactor: Double) -> Double {
        bmr + trainingBurnPerDay + bmr * (everydayFactor - 1)
    }

    static func tdee(bmr: Double, model: EnergyModel) -> Double {
        tdee(bmr: bmr, trainingBurnPerDay: model.trainingBurnPerDay,
             everydayFactor: model.everydayFactor)
    }

    /// The inverse: what everyday factor an observed expenditure implies. Clamped by the caller.
    static func impliedEverydayFactor(observedTDEE: Double, bmr: Double,
                                      trainingBurnPerDay: Double) -> Double? {
        guard bmr > 0 else { return nil }
        return (observedTDEE - trainingBurnPerDay) / bmr
    }

    // CLAUDE  Date 09/19/2026
    // Before any session has been logged there is nothing to measure, so the training days the
    // user typed stand in: a 45-minute lifting session at their bodyweight, spread over the
    // week. Replaced by measured burn as soon as real sessions exist.
    static func coldStartTrainingBurn(trainingDaysPerWeek: Int, weightLb: Double) -> Double {
        let perSession = WorkoutEnergy.liftingNetCalories(weightLb: weightLb, minutes: 45)
        return perSession * Double(max(0, min(7, trainingDaysPerWeek))) / 7
    }

    // MARK: - Calorie target

    /// Daily kcal a weekly pound rate costs or buys, at 3500 kcal per pound.
    static func dailyKcal(weeklyRateLb: Double) -> Double {
        weeklyRateLb * BodySafety.energyPerLb / 7
    }

    /// Weekly pounds a daily surplus or deficit works out to — the inverse of the above.
    static func weeklyLb(dailyKcal: Double) -> Double {
        dailyKcal * 7 / BodySafety.energyPerLb
    }

    // CLAUDE  Date 09/19/2026
    // The target, floored. Side effect: the returned flags are what the UI must show — hitting
    // the floor changes the pace the user was promised, so the caller re-derives the projected
    // date from `effectiveWeeklyLb` rather than from the pace they picked.
    struct CalorieTarget {
        let calories: Double
        let effectiveWeeklyLb: Double
        let flags: [SafetyFlag]
    }

    static func calorieTarget(tdee: Double, weeklyRateLb: Double,
                              floor: Double, phase: PlanPhase) -> CalorieTarget {
        var flags: [SafetyFlag] = []
        let wanted = tdee + dailyKcal(weeklyRateLb: weeklyRateLb)
        var calories = BodySafety.roundedTarget(wanted, floor: floor)

        if phase.direction < 0 {
            if tdee <= floor {
                // No safe deficit exists: maintenance is the honest answer.
                calories = BodySafety.roundedTarget(tdee, floor: floor)
                flags.append(.cutBlocked)
            } else if wanted < floor {
                flags.append(.calorieFloorReached)
            }
        }
        return CalorieTarget(calories: calories,
                             effectiveWeeklyLb: weeklyLb(dailyKcal: calories - tdee),
                             flags: flags)
    }

    // MARK: - Goals

    // CLAUDE  Date 09/19/2026
    // Goal weight from a target body-fat percentage, assuming lean mass is held — which is the
    // point of the whole protein/pace design, but is still an assumption the UI states.
    static func targetWeight(leanMassLb: Double, targetBodyFatPct: Double) -> Double? {
        guard targetBodyFatPct > 0, targetBodyFatPct < 100 else { return nil }
        return leanMassLb / (1 - targetBodyFatPct / 100)
    }

    /// Weeks to travel from one weight to another at a weekly rate. nil when the rate can't
    /// get there (a zero pace, or one pointed the wrong way).
    static func weeksToGoal(currentLb: Double, targetLb: Double, weeklyRateLb: Double) -> Double? {
        let gap = targetLb - currentLb
        guard abs(weeklyRateLb) > 0.001, gap != 0, (gap > 0) == (weeklyRateLb > 0) else { return nil }
        return abs(gap / weeklyRateLb)
    }
}

// CLAUDE  Date 09/19/2026
// The four numbers the plan writes into NutritionGoals. A plain value so a target can be
// snapshotted, compared, and previewed without touching the store.
struct PlanTargets: Codable, Hashable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    var snapshot: TargetSnapshot {
        TargetSnapshot(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
}

// CLAUDE  Date 09/19/2026
// Turns a calorie target into grams. Protein is set first and defended hardest — it's what
// keeps muscle on a deficit — then fat down to its hormonal floor, and carbs take whatever is
// left plus the rounding. Every floor here is BodySafety's.
enum MacroPlanner {

    // CLAUDE  Date 09/19/2026
    // Protein and fat scale with bodyweight, which over-feeds both at a very high bodyweight,
    // so they use the weight a BMI of 30 would be instead. Capping rather than switching at a
    // threshold keeps it continuous — no jump in protein for one pound of bodyweight.
    static func referenceWeightLb(weightLb: Double, heightCm: Double) -> Double {
        let meters = heightCm / 100
        guard meters > 0 else { return weightLb }
        let capLb = BodySafety.referenceBMI * meters * meters * CardioPolicy.lbPerKilogram
        return min(weightLb, capLb)
    }

    static func proteinGramsPerLb(track: PlanTrack, phase: PlanPhase, usingLeanMass: Bool) -> Double {
        switch (track, usingLeanMass, phase) {
        case (.general, _, _):              return 0.7
        case (.bodybuilding, true, .cut):      return 1.2
        case (.bodybuilding, true, .maintain): return 1.1
        case (.bodybuilding, true, .leanBulk): return 1.0
        case (.bodybuilding, false, .cut):      return 1.0
        case (.bodybuilding, false, .maintain): return 0.9
        case (.bodybuilding, false, .leanBulk): return 0.8
        }
    }

    static func fatShareOfCalories(track: PlanTrack) -> Double {
        track == .bodybuilding ? 0.25 : 0.30
    }

    struct Result {
        let targets: PlanTargets
        let flags: [SafetyFlag]
        /// The fewest calories that fits protein plus the fat floor, for the UI to explain.
        let minimumCalories: Double
    }

    // CLAUDE  Date 09/19/2026
    // Side effect worth knowing: when the calories can't hold protein plus the fat floor,
    // `allowCalorieRaise` decides which promise breaks. Building a plan raises the calories
    // (strictly safer). A check-in can't — its number is already clamped — so it trims protein
    // and flags it, which is the only path that ever lowers protein.
    static func targets(calories: Double, track: PlanTrack, phase: PlanPhase,
                        weightLb: Double, heightCm: Double, leanMassLb: Double?,
                        style: MacroStyle = .recommended,
                        allowCalorieRaise: Bool = true) -> Result {
        let reference = referenceWeightLb(weightLb: weightLb, heightCm: heightCm)

        // CLAUDE  Date 09/20/2026
        // A chosen percentage split takes over the grams — except the fat floor, which is a
        // health guardrail rather than a preference and survives any split. Carbs take the
        // remainder so the three always add back up to the calorie target.
        if let pct = style.percentages {
            let fatFloorGrams = (BodySafety.fatFloorGramsPerLb * reference).rounded()
            let fat = max(fatFloorGrams,
                          (calories * pct.fat / 100 / NutritionGoals.kcalPerGramFat).rounded())
            let protein = (calories * pct.protein / 100 / NutritionGoals.kcalPerGramProtein).rounded()
            let remaining = calories
                - protein * NutritionGoals.kcalPerGramProtein
                - fat * NutritionGoals.kcalPerGramFat
            let carbs = max(0, (remaining / NutritionGoals.kcalPerGramCarbs).rounded())
            return Result(targets: PlanTargets(calories: calories, protein: protein,
                                               carbs: carbs, fat: fat),
                          flags: [],
                          minimumCalories: fatFloorGrams * NutritionGoals.kcalPerGramFat)
        }

        let usingLeanMass = track == .bodybuilding && (leanMassLb ?? 0) > 0
        let proteinBasis = usingLeanMass ? (leanMassLb ?? reference) : reference

        var flags: [SafetyFlag] = []
        var protein = (proteinGramsPerLb(track: track, phase: phase, usingLeanMass: usingLeanMass)
                       * proteinBasis).rounded()
        let fatFloorGrams = (BodySafety.fatFloorGramsPerLb * reference).rounded()

        let proteinKcal = protein * NutritionGoals.kcalPerGramProtein
        let minimumCalories = proteinKcal + fatFloorGrams * NutritionGoals.kcalPerGramFat

        var workingCalories = calories
        if workingCalories < minimumCalories {
            if allowCalorieRaise {
                workingCalories = (minimumCalories / 10).rounded(.up) * 10
            } else {
                // The one place protein comes down, and it says so.
                let affordable = max(0, workingCalories - fatFloorGrams * NutritionGoals.kcalPerGramFat)
                protein = (affordable / NutritionGoals.kcalPerGramProtein).rounded(.down)
                flags.append(.proteinTrimmed)
            }
        }

        let fatFromShare = workingCalories * fatShareOfCalories(track: track) / NutritionGoals.kcalPerGramFat
        let fat = max(fatFloorGrams, fatFromShare.rounded())
        let remaining = workingCalories
            - protein * NutritionGoals.kcalPerGramProtein
            - fat * NutritionGoals.kcalPerGramFat
        let carbs = max(0, (remaining / NutritionGoals.kcalPerGramCarbs).rounded())

        return Result(targets: PlanTargets(calories: workingCalories, protein: protein,
                                           carbs: carbs, fat: fat),
                      flags: flags,
                      minimumCalories: minimumCalories)
    }
}
