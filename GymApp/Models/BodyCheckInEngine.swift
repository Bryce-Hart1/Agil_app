import Foundation

// CLAUDE  Date 09/19/2026
// What the weekly check-in is handed. Plain values only — BodyStore walks the food log, the
// workouts and the ledger once and hands the results over, so this engine stays pure and no
// view body ever re-filters those arrays.
struct BodyCheckInInput {
    /// The user's answer when the food log can't carry the estimate on its own.
    enum Adherence: String, Codable, CaseIterable, Identifiable {
        case onTarget, mostly, notReally
        var id: String { rawValue }

        var label: String {
            switch self {
            case .onTarget:  return "On target"
            case .mostly:    return "Mostly"
            case .notReally: return "Not really"
            }
        }
    }

    var today: String
    var metrics: BodyMetrics
    var plan: BodyPlan
    var weighIns: [WeighIn]
    /// kcal logged per day key.
    var loggedKcal: [String: Double]
    /// The calorie target in force on each day — history, not today's number.
    var targetsByDay: [String: Double]
    var sessions: [SessionSample]
    /// The live NutritionGoals, so a hand-edited target is what the check-in adjusts from.
    var currentTargets: PlanTargets
    var adherence: Adherence?
}

// CLAUDE  Date 09/19/2026
// The check-in's answer. `.ready` carries a full proposal the sheet can render and the user
// can accept or decline; everything else is a reason it can't do the maths yet, each with its
// own ask. Nothing here writes: accepting is the caller's job.
enum BodyCheckInStatus {
    case notDue(nextDayKey: String?)
    case needsWeighIns(recent: Int, prior: Int)
    case needsAdherence
    case ready(BodyCheckInProposal)
}

// CLAUDE  Date 09/19/2026
// One proposed adjustment, with the whole derivation attached — the sheet shows the split and
// the flags rather than just a new number, because a plan the user can't see the reasoning of
// is one they stop trusting the first time it surprises them.
struct BodyCheckInProposal {
    var dayKey: String
    var channel: BodyCheckInRecord.Channel
    var recentAverageLb: Double
    var priorAverageLb: Double
    var recentCount: Int
    var rateLbPerWeek: Double
    var ratePctPerWeek: Double
    /// What the plan believes was eaten (logged × the under-logging correction, or the target).
    var believedIntake: Double?
    var reportedIntake: Double?
    var bmr: Double
    var trainingBurnPerDay: Double
    var everydayCalories: Double
    var estimatedTDEE: Double
    var currentCalories: Double
    var proposedCalories: Double
    var targets: PlanTargets
    var updatedModel: EnergyModel
    var flags: [SafetyFlag]
    var isFirstOfPhase: Bool
    var goalReached: Bool

    var delta: Double { proposedCalories - currentCalories }
    var isOnTrack: Bool { abs(delta) < BodySafety.noChangeThreshold }

    /// The record written whether or not the user accepts, so the model keeps learning.
    func record(accepted: Bool) -> BodyCheckInRecord {
        BodyCheckInRecord(dayKey: dayKey, channel: channel,
                          previousCalories: currentCalories,
                          proposedCalories: proposedCalories,
                          accepted: accepted,
                          averageWeightLb: recentAverageLb,
                          previousAverageWeightLb: priorAverageLb,
                          ratePctPerWeek: ratePctPerWeek,
                          estimatedTDEE: estimatedTDEE,
                          flags: flags)
    }
}

// CLAUDE  Date 09/19/2026
// The weekly check-in: compare two rolling 7-day weight averages, work out what the user's
// body actually did, and move one number — the learned everyday-activity factor. Everything
// else (training burn, intake) is measured or corrected, never guessed at. Pure; BodySafety
// owns every limit it applies.
enum BodyCheckInEngine {

    // MARK: - Readiness

    // CLAUDE  Date 09/19/2026
    // Due on the user's chosen weekday once a week has passed — or on any day once it's two
    // days overdue, so missing the weekday doesn't cost them a whole cycle. A new phase waits
    // the full warm-up first: the first fortnight of any phase is water, not fat.
    static func isDue(plan: BodyPlan, today: String = DayKey.key(),
                      calendar: Calendar = .current) -> Bool {
        guard let elapsed = daysSinceLastCycle(plan: plan, today: today) else { return false }
        let required = plan.lastCheckInDayKey == nil
            ? BodySafety.phaseWarmupDays
            : BodySafety.checkInIntervalDays
        guard elapsed >= required else { return false }
        guard let date = DayKey.date(from: today) else { return false }
        let weekday = calendar.component(.weekday, from: date)
        return weekday == plan.checkInWeekday || elapsed >= required + 2
    }

    /// Days since the last check-in, or since the phase started when there hasn't been one.
    static func daysSinceLastCycle(plan: BodyPlan, today: String) -> Int? {
        let from = plan.lastCheckInDayKey ?? plan.phaseStartedDayKey
        return DayKey.days(from: from, to: today)
    }

    /// The first day the next check-in could run, for "next check-in Monday" copy.
    static func nextDueDayKey(plan: BodyPlan, today: String = DayKey.key()) -> String? {
        let from = plan.lastCheckInDayKey ?? plan.phaseStartedDayKey
        let required = plan.lastCheckInDayKey == nil
            ? BodySafety.phaseWarmupDays
            : BodySafety.checkInIntervalDays
        return DayKey.offset(from, byDays: required)
    }

    // MARK: - Evaluation

    static func evaluate(_ input: BodyCheckInInput, calendar: Calendar = .current) -> BodyCheckInStatus {
        let plan = input.plan
        guard isDue(plan: plan, today: input.today, calendar: calendar) else {
            return .notDue(nextDayKey: nextDueDayKey(plan: plan, today: input.today))
        }

        // Two rolling weeks: the week just gone, and the week before it.
        let recentKeys = DayKey.window(endingOn: input.today, length: BodySafety.windowLength)
        guard let priorEnd = DayKey.offset(input.today, byDays: -BodySafety.windowLength) else {
            return .needsWeighIns(recent: 0, prior: 0)
        }
        let priorKeys = DayKey.window(endingOn: priorEnd, length: BodySafety.windowLength)
        let windowKeys = priorKeys + recentKeys

        let recent = WeightTrend.window(input.weighIns, keys: recentKeys,
                                        minimumCount: BodySafety.minimumWeighInsPerWindow)
        let prior = WeightTrend.window(input.weighIns, keys: priorKeys,
                                       minimumCount: BodySafety.minimumWeighInsPerWindow)
        guard let recent, let prior else {
            let recentCount = WeightTrend.window(input.weighIns, keys: recentKeys)?.count ?? 0
            let priorCount = WeightTrend.window(input.weighIns, keys: priorKeys)?.count ?? 0
            return .needsWeighIns(recent: recentCount, prior: priorCount)
        }

        // MARK: What the body did
        let weightLb = recent.average
        let rateLbPerWeek = recent.average - prior.average
        let ratePctPerWeek = weightLb > 0 ? rateLbPerWeek / weightLb * 100 : 0
        let balance = EnergyMath.dailyKcal(weeklyRateLb: rateLbPerWeek)

        let bodyFat = WeightTrend.latestBodyFat(input.weighIns)?.bodyFatPct
        let leanMassLb = bodyFat.map { weightLb * (1 - $0 / 100) }
        let bmr = EnergyMath.bmr(sex: input.metrics.sex, weightLb: weightLb,
                                 heightCm: input.metrics.heightCm,
                                 age: input.metrics.age(), bodyFatPct: bodyFat)

        // MARK: What we're allowed to believe
        var model = plan.energy
        let windowSessions = input.sessions.filter { Set(windowKeys).contains($0.dayKey) }
        model.activityTrust = DataTrust.activityTrust(samples: windowSessions,
                                                      previous: model.activityTrust)
        model.trainingBurnPerDay = DataTrust.trainingBurnPerDay(samples: windowSessions,
                                                                windowKeys: windowKeys,
                                                                trust: model.activityTrust)

        let diary = DataTrust.diaryWindow(loggedKcal: input.loggedKcal,
                                          targets: input.targetsByDay,
                                          windowKeys: windowKeys)
        let diaryUsable = DataTrust.canUseDiary(trust: model.diaryTrust, window: diary,
                                                phase: plan.phase)

        // The model as it stood coming in — the prior the ratio is measured against.
        let modelTDEE = EnergyMath.tdee(bmr: bmr, trainingBurnPerDay: model.trainingBurnPerDay,
                                        everydayFactor: plan.energy.everydayFactor)

        var channel: BodyCheckInRecord.Channel = .noChange
        var believedIntake: Double?
        var learningWeight = 0.0

        if diaryUsable, let reported = diary.averageLoggedKcal, reported > 0 {
            channel = .diary
            // Split the surprise: part of it is intake the log missed, part is expenditure.
            let implied = modelTDEE + balance
            if let observedRatio = DataTrust.observedIntakeRatio(impliedIntake: implied,
                                                                 reportedIntake: reported) {
                let smoothed = DataTrust.smoothedIntakeRatio(observed: observedRatio,
                                                             previous: model.intakeRatio)
                model.diaryTrust = DataTrust.diaryTrust(window: diary, observedRatio: observedRatio,
                                                        smoothedRatio: smoothed,
                                                        previous: model.diaryTrust)
                model.intakeRatio = smoothed
            }
            believedIntake = reported * model.intakeRatio
            learningWeight = BodySafety.everydayLearningWeight
        } else {
            model.diaryTrust = DataTrust.diaryTrust(window: diary, observedRatio: nil,
                                                    smoothedRatio: model.intakeRatio,
                                                    previous: model.diaryTrust)
            switch input.adherence {
            case .none:
                return .needsAdherence
            case .notReally:
                channel = .noChange
            case .onTarget, .mostly:
                channel = .scaleOnly
                believedIntake = input.currentTargets.calories
                learningWeight = BodySafety.assumedIntakeLearningWeight
            }
        }

        // MARK: Learn the one number
        if let believedIntake, learningWeight > 0 {
            let observedTDEE = believedIntake - balance
            if let implied = EnergyMath.impliedEverydayFactor(
                observedTDEE: observedTDEE, bmr: bmr,
                trainingBurnPerDay: model.trainingBurnPerDay) {
                model.everydayFactor = updatedEverydayFactor(previous: plan.energy.everydayFactor,
                                                             observed: implied,
                                                             weight: learningWeight)
                model.observations += 1
            }
        }

        let tdee = EnergyMath.tdee(bmr: bmr, model: model)

        // MARK: Propose
        let current = input.currentTargets.calories
        let weeklyRateLb = plan.pace.signedWeeklyLb(bodyweightLb: weightLb, phase: plan.phase)
        let floor = BodySafety.calorieFloor(sex: input.metrics.sex, bmr: bmr)
        let target = EnergyMath.calorieTarget(tdee: tdee, weeklyRateLb: weeklyRateLb,
                                              floor: floor, phase: plan.phase)
        var flags = target.flags
        var proposed = target.calories

        let isFirstOfPhase = plan.lastCheckInDayKey == nil

        // Safety first: these only ever push calories UP.
        var increaseOnly = isFirstOfPhase
        if ratePctPerWeek <= -BodySafety.rapidLossSingleWindowPct {
            flags.append(.rapidLoss)
            increaseOnly = true
        }
        if let bmi = BodySafety.bmi(weightLb: weightLb, heightCm: input.metrics.heightCm),
           bmi < BodySafety.minimumBMI {
            flags.append(.belowHealthyWeight)
            proposed = max(proposed, BodySafety.roundedTarget(tdee, floor: floor))
            increaseOnly = true
        }
        if plan.phase == .cut, plan.weeksInPhase(on: input.today) >= BodySafety.longCutWeeks {
            flags.append(.longCut)
        }

        // The direction guard: never move calories against what the scale is saying, and hold
        // inside the deadband. This is what stops an under-logger who is on pace being cut.
        if channel == .noChange {
            proposed = current
        } else {
            let targetPct = weightLb > 0 ? weeklyRateLb / weightLb * 100 : 0
            let difference = ratePctPerWeek - targetPct
            if abs(difference) < BodySafety.directionDeadbandPct {
                proposed = current
            } else if difference < 0 {
                proposed = max(proposed, current)   // moving too fast down: only up
            } else {
                proposed = min(proposed, current)   // not moving enough: only down
            }
        }
        if increaseOnly { proposed = max(proposed, current) }

        // Clamp, floor, round — in that order, because the floor outranks the clamp.
        let clamped = min(max(proposed, current - BodySafety.maxCheckInAdjustment),
                          current + BodySafety.maxCheckInAdjustment)
        proposed = BodySafety.roundedTarget(clamped, floor: floor)
        if abs(proposed - current) < BodySafety.noChangeThreshold { proposed = current }

        // The split the user chose sticks: a check-in changes the calorie target, never the
        // shape of the plate underneath it.
        let macros = MacroPlanner.targets(calories: proposed, track: plan.track, phase: plan.phase,
                                          weightLb: weightLb, heightCm: input.metrics.heightCm,
                                          leanMassLb: leanMassLb, style: plan.effectiveMacroStyle,
                                          allowCalorieRaise: false)
        flags.append(contentsOf: macros.flags)

        let proposal = BodyCheckInProposal(
            dayKey: input.today,
            channel: channel,
            recentAverageLb: recent.average,
            priorAverageLb: prior.average,
            recentCount: recent.count,
            rateLbPerWeek: rateLbPerWeek,
            ratePctPerWeek: ratePctPerWeek,
            believedIntake: believedIntake,
            reportedIntake: diary.averageLoggedKcal,
            bmr: bmr,
            trainingBurnPerDay: model.trainingBurnPerDay,
            everydayCalories: bmr * (model.everydayFactor - 1),
            estimatedTDEE: tdee,
            currentCalories: current,
            proposedCalories: proposed,
            targets: macros.targets,
            updatedModel: model,
            flags: dedupe(flags),
            isFirstOfPhase: isFirstOfPhase,
            goalReached: hasReachedGoal(plan: plan, weightLb: weightLb, bodyFatPct: bodyFat))
        return .ready(proposal)
    }

    // MARK: - Helpers

    // CLAUDE  Date 09/19/2026
    // The learned factor moves slowly on purpose: EWMA first, then a hard step cap, then the
    // plausible range. One strange week — a holiday, a stomach bug, a scale battery — can
    // nudge the plan but can never reprice it.
    static func updatedEverydayFactor(previous: Double, observed: Double, weight: Double) -> Double {
        let bounded = min(max(observed, BodySafety.everydayFactorRange.lowerBound),
                          BodySafety.everydayFactorRange.upperBound)
        let blended = previous * (1 - weight) + bounded * weight
        let stepped = min(max(blended, previous - BodySafety.maxEverydayFactorStep),
                          previous + BodySafety.maxEverydayFactorStep)
        return min(max(stepped, BodySafety.everydayFactorRange.lowerBound),
                   BodySafety.everydayFactorRange.upperBound)
    }

    /// Whether the phase has arrived where it was headed, so the sheet can offer the next one.
    static func hasReachedGoal(plan: BodyPlan, weightLb: Double, bodyFatPct: Double?) -> Bool {
        if let targetFat = plan.targetBodyFatPct, let bodyFatPct {
            return bodyFatPct <= targetFat + 0.1
        }
        guard let targetWeight = plan.targetWeightLb else { return false }
        switch plan.phase.direction {
        case -1: return weightLb <= targetWeight
        case 1:  return weightLb >= targetWeight
        default: return false
        }
    }

    private static func dedupe(_ flags: [SafetyFlag]) -> [SafetyFlag] {
        var seen = Set<SafetyFlag>()
        return flags.filter { seen.insert($0).inserted }
    }
}
