import Foundation

// CLAUDE  Date 09/19/2026
// Every limit the calorie planner obeys, in one file — the sibling of AchievementPolicy and
// CardioPolicy, and like them the ONE place these numbers live. Tune here only; EnergyMath
// and BodyCheckInEngine apply them. Deliberately conservative: a plan that is slightly too
// slow costs a user a week, one that is too aggressive costs them muscle or worse.
enum BodySafety {

    // MARK: - Consent

    /// Bump this when the health disclaimer's wording changes; users then re-accept.
    static let consentVersion = 1
    static let minimumAge = 18

    /// Old enough for a plan. Birth year alone can be a year off, so the 18+ checkbox does
    /// the real work — this only refuses someone who cannot possibly be an adult.
    static func meetsMinimumAge(birthYear: Int, on date: Date = Date(),
                                calendar: Calendar = .current) -> Bool {
        guard birthYear > 1900 else { return false }
        return calendar.component(.year, from: date) - birthYear >= minimumAge
    }

    // MARK: - Calorie floors

    // CLAUDE  Date 09/19/2026
    // The lowest daily target Agil will ever set. Undisclosed takes the HIGHER floor on
    // purpose: without a sex we can't tailor, so we err upward rather than risk a female-sized
    // user being fed a male-sized deficit.
    static func sexCalorieFloor(_ sex: BiologicalSex) -> Double {
        switch sex {
        case .male:        return 1500
        case .female:      return 1200
        case .undisclosed: return 1500
        }
    }

    /// Never eat below resting metabolism, and never below the sex floor.
    static func calorieFloor(sex: BiologicalSex, bmr: Double) -> Double {
        max(sexCalorieFloor(sex), bmr)
    }

    /// Targets land on a round number; at the floor we round UP so rounding never breaks it.
    static func roundedTarget(_ kcal: Double, floor: Double, step: Double = 10) -> Double {
        let rounded = (kcal / step).rounded() * step
        return rounded < floor ? (floor / step).rounded(.up) * step : rounded
    }

    // MARK: - Pace

    static let maxLossPctPerWeek = 1.0
    static let maxGainPctPerMonth = 1.5
    /// Months → weeks. 12 months over 52 weeks, not the 4-week month people assume.
    static let weeksPerMonth = 52.0 / 12.0

    static func maxWeeklyLossLb(bodyweightLb: Double) -> Double {
        bodyweightLb * maxLossPctPerWeek / 100
    }

    static func maxWeeklyGainLb(bodyweightLb: Double) -> Double {
        bodyweightLb * maxGainPctPerMonth / 100 / weeksPerMonth
    }

    // MARK: - Targets

    static let minimumBMI = 18.5

    static func targetBodyFatFloor(_ sex: BiologicalSex) -> Double {
        switch sex {
        case .male:        return 8
        case .female:      return 15
        case .undisclosed: return 15
        }
    }

    /// The lightest weight a target may aim at, from BMI 18.5.
    static func minimumHealthyWeightLb(heightCm: Double) -> Double {
        let meters = heightCm / 100
        return minimumBMI * meters * meters * CardioPolicy.lbPerKilogram
    }

    static func bmi(weightLb: Double, heightCm: Double) -> Double? {
        let meters = heightCm / 100
        guard meters > 0 else { return nil }
        return (weightLb / CardioPolicy.lbPerKilogram) / (meters * meters)
    }

    // MARK: - Macro floors

    /// Hormonal-health floor for fat, per lb of reference weight.
    static let fatFloorGramsPerLb = 0.3
    /// Reference weight caps protein at the weight a BMI of 30 would be (see EnergyMath).
    static let referenceBMI = 30.0

    // MARK: - Check-in cadence

    static let checkInIntervalDays = 7
    /// No adjustment until a phase has run this long — week one is water, not fat.
    static let phaseWarmupDays = 14
    static let windowLength = 7
    static let minimumWeighInsPerWindow = 3
    /// A diary day counts only when it logged at least this share of that day's target.
    static let completeDayThreshold = 0.8
    static let minimumCompleteDays = 4
    /// On a cut, a logged average below this share of target is treated as under-logging.
    static let cutAdherenceThreshold = 0.85

    // MARK: - The learned model

    static let everydayFactorDefault = 1.30
    static let everydayFactorRange = 1.10...1.80
    /// Most the learned factor may move in one check-in, so one odd week can't reprice a plan.
    static let maxEverydayFactorStep = 0.05
    static let everydayLearningWeight = 0.4
    /// A weaker weight for observations built on an ASSUMED intake rather than a logged one.
    static let assumedIntakeLearningWeight = 0.25
    /// Most net training kcal a single day may contribute.
    static let dailyTrainingBurnCap = 1200.0
    /// Below this, a trust score means the input is dropped from the estimate entirely.
    static let trustFloor = 0.5

    // MARK: - Adjustments

    static let maxCheckInAdjustment = 200.0
    /// Under this, the check-in reports "on track" instead of nudging the numbers.
    static let noChangeThreshold = 50.0
    /// Rate difference (% bodyweight/week) inside which the plan holds rather than adjusts.
    static let directionDeadbandPct = 0.15

    // MARK: - Flags

    static let rapidLossSingleWindowPct = 2.0
    static let rapidLossSustainedPct = 1.5
    static let longCutWeeks = 16

    static let energyPerLb = 3500.0
}

// CLAUDE  Date 09/19/2026
// A condition the plan hit that the user has to be told about, with the copy it shows. Kept
// beside the limits so a threshold and its explanation can never drift apart. Everything here
// is written to inform, never to scold — and `needsSupportLink` marks the ones that also
// surface the health & safety page.
enum SafetyFlag: String, Codable, CaseIterable {
    case calorieFloorReached
    case cutBlocked
    case rapidLoss
    case belowHealthyWeight
    case longCut
    case proteinTrimmed

    var title: String {
        switch self {
        case .calorieFloorReached: return "You're at Agil's minimum"
        case .cutBlocked:          return "A deficit isn't safe here"
        case .rapidLoss:           return "That's faster than planned"
        case .belowHealthyWeight:  return "This is below a healthy weight"
        case .longCut:             return "You've been cutting a while"
        case .proteinTrimmed:      return "Protein had to come down"
        }
    }

    var message: String {
        switch self {
        case .calorieFloorReached:
            return "Agil won't set a target below your estimated resting needs. If progress has stalled here, a couple of weeks at maintenance does more than eating less."
        case .cutBlocked:
            return "Your estimated daily burn is already at the lowest target Agil will set, so there's no safe deficit to give you. Maintenance is the honest answer — a dietitian can help if you want to go further."
        case .rapidLoss:
            return "You're losing faster than your plan intends. Your calories have gone up, not down. Fast loss costs muscle, and that's the opposite of the point."
        case .belowHealthyWeight:
            return "Your goal sits below a healthy weight for your height, so Agil won't plan a deficit toward it."
        case .longCut:
            return "Long deficits get harder as they go. A week or two at maintenance usually makes the next block work better."
        case .proteinTrimmed:
            return "Your target is at Agil's minimum, so protein came down to fit. It's the last thing to move, not the first."
        }
    }

    var needsSupportLink: Bool {
        switch self {
        case .rapidLoss, .belowHealthyWeight, .calorieFloorReached, .cutBlocked: return true
        case .longCut, .proteinTrimmed: return false
        }
    }
}
