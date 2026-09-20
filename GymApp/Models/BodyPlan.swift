import Foundation

// CLAUDE  Date 09/19/2026
// Which kind of user the plan is written for. The maths is the same either way — the track
// changes how much is shown, how protein is set, and what the phases are called, so a
// bodybuilder gets lean mass and expenditure while someone who just wants to lose weight
// gets calories and a goal.
enum PlanTrack: String, Codable, CaseIterable, Identifiable {
    case bodybuilding
    case general

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bodybuilding: return "Bodybuilding / physique"
        case .general:      return "General weight goals"
        }
    }

    var detail: String {
        switch self {
        case .bodybuilding: return "Body-fat targets, lean mass, protein per pound of muscle, and your real expenditure."
        case .general:      return "A calorie target and a goal weight, without the extra numbers."
        }
    }
}

// CLAUDE  Date 09/19/2026
// One enum for both tracks, because a cut and a weight-loss phase are the same arithmetic —
// only the wording differs. `direction` is what the engine actually uses, so nothing has to
// switch on the phase to know which way calories move.
enum PlanPhase: String, Codable, CaseIterable, Identifiable {
    case cut
    case maintain
    case leanBulk

    var id: String { rawValue }

    /// −1 deficit, 0 maintenance, +1 surplus.
    var direction: Int {
        switch self {
        case .cut:      return -1
        case .maintain: return 0
        case .leanBulk: return 1
        }
    }

    func label(for track: PlanTrack) -> String {
        switch (self, track) {
        case (.cut, .bodybuilding):      return "Cut"
        case (.cut, .general):           return "Lose weight"
        case (.maintain, .bodybuilding): return "Maintain / recomp"
        case (.maintain, .general):      return "Maintain"
        case (.leanBulk, .bodybuilding): return "Lean bulk"
        case (.leanBulk, .general):      return "Gain weight"
        }
    }

    func detail(for track: PlanTrack) -> String {
        switch (self, track) {
        case (.cut, .bodybuilding):      return "Lose fat at a pace that keeps your muscle, with protein held high."
        case (.cut, .general):           return "Lose weight steadily, with enough protein to hold onto muscle."
        case (.maintain, .bodybuilding): return "Hold your weight and let training do the work."
        case (.maintain, .general):      return "Stay where you are."
        case (.leanBulk, .bodybuilding): return "Gain slowly enough that most of it is muscle."
        case (.leanBulk, .general):      return "Put weight on at a controlled pace."
        }
    }
}

// CLAUDE  Date 09/19/2026
// How fast the plan intends to move, stored as the CHOICE rather than a pound figure: a
// percentage target has to re-derive as bodyweight changes, or a cut silently gets more
// aggressive the lighter you get. `weeklyLb` is always a magnitude — PlanPhase.direction
// applies the sign.
struct Pace: Codable, Hashable {
    enum Kind: String, Codable {
        case percentPerWeek
        case percentPerMonth
        case poundsPerWeek
        case none
    }

    var kind: Kind
    var value: Double

    static let hold = Pace(kind: .none, value: 0)

    /// Unsigned pounds per week for a given bodyweight, before the safety caps.
    func weeklyLb(bodyweightLb: Double) -> Double {
        switch kind {
        case .percentPerWeek:  return bodyweightLb * value / 100
        case .percentPerMonth: return bodyweightLb * value / 100 / BodySafety.weeksPerMonth
        case .poundsPerWeek:   return value
        case .none:            return 0
        }
    }

    // CLAUDE  Date 09/19/2026
    // The rate the plan will actually use: signed by the phase and clamped by BodySafety, so
    // a pace a user picked (or one inherited from a heavier bodyweight) can never exceed 1%
    // of bodyweight lost per week or 1.5% gained per month.
    func signedWeeklyLb(bodyweightLb: Double, phase: PlanPhase) -> Double {
        let magnitude = weeklyLb(bodyweightLb: bodyweightLb)
        switch phase.direction {
        case -1: return -min(magnitude, BodySafety.maxWeeklyLossLb(bodyweightLb: bodyweightLb))
        case 1:  return min(magnitude, BodySafety.maxWeeklyGainLb(bodyweightLb: bodyweightLb))
        default: return 0
        }
    }

    /// Whether this choice sits inside the safety caps for this bodyweight, so the picker can
    /// disable an option instead of quietly clamping it.
    func isWithinLimits(bodyweightLb: Double, phase: PlanPhase) -> Bool {
        let magnitude = weeklyLb(bodyweightLb: bodyweightLb)
        switch phase.direction {
        case -1: return magnitude <= BodySafety.maxWeeklyLossLb(bodyweightLb: bodyweightLb) + 0.0001
        case 1:  return magnitude <= BodySafety.maxWeeklyGainLb(bodyweightLb: bodyweightLb) + 0.0001
        default: return true
        }
    }

    // CLAUDE  Date 09/19/2026
    // The options offered per track and phase, in order, with the default listed second where
    // there are three. Bodybuilding paces are percentages of bodyweight (they scale with the
    // user); general paces are plain pounds, which is how people think about weight loss.
    static func options(track: PlanTrack, phase: PlanPhase) -> [Pace] {
        switch (track, phase) {
        case (.bodybuilding, .cut):
            return [Pace(kind: .percentPerWeek, value: 0.5),
                    Pace(kind: .percentPerWeek, value: 0.75),
                    Pace(kind: .percentPerWeek, value: 1.0)]
        case (.bodybuilding, .leanBulk):
            return [Pace(kind: .percentPerMonth, value: 0.5),
                    Pace(kind: .percentPerMonth, value: 1.0),
                    Pace(kind: .percentPerMonth, value: 1.5)]
        case (.general, .cut):
            return [Pace(kind: .poundsPerWeek, value: 0.5),
                    Pace(kind: .poundsPerWeek, value: 1.0),
                    Pace(kind: .poundsPerWeek, value: 1.5)]
        case (.general, .leanBulk):
            return [Pace(kind: .poundsPerWeek, value: 0.25),
                    Pace(kind: .poundsPerWeek, value: 0.5)]
        case (_, .maintain):
            return [.hold]
        }
    }

    // CLAUDE  Date 09/19/2026
    // How a pace reads on the picker. Percentages are stated as the user chose them and then
    // translated into real weight for their bodyweight, because "0.75% a week" means nothing
    // until you see it as pounds.
    func title(units: BodyUnits) -> String {
        switch kind {
        case .percentPerWeek:  return "\(trimmed(value))% of bodyweight a week"
        case .percentPerMonth: return "\(trimmed(value))% of bodyweight a month"
        case .poundsPerWeek:   return "\(units.weightText(fromPounds: value)) \(units.weightAbbreviation) a week"
        case .none:            return "Hold steady"
        }
    }

    func detail(bodyweightLb: Double, units: BodyUnits, phase: PlanPhase) -> String {
        guard kind != .none else { return "Eat at maintenance and let training do the work." }
        let weekly = weeklyLb(bodyweightLb: bodyweightLb)
        let verb = phase.direction < 0 ? "down" : "up"
        let amount = units.weightText(fromPounds: weekly)
        let monthly = units.weightText(fromPounds: weekly * BodySafety.weeksPerMonth)
        return "About \(amount) \(units.weightAbbreviation) a week \(verb), or \(monthly) a month."
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }

    static func `default`(track: PlanTrack, phase: PlanPhase) -> Pace {
        let all = options(track: track, phase: phase)
        return all.count >= 2 ? all[1] : (all.first ?? .hold)
    }
}

// CLAUDE  Date 09/20/2026
// How the calorie target gets divided up. `recommended` is Agil's own rule — protein set
// from lean mass or bodyweight first, then fat, then carbs — and the rest are the percentage
// splits the old standalone macro calculator offered, folded into the plan so there's one
// place that decides macros instead of two that can disagree.
enum MacroChoice: String, Codable, CaseIterable, Identifiable {
    case recommended
    case balanced
    case highProtein
    case lowCarb
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: return "Agil's recommendation"
        case .balanced:    return "Balanced"
        case .highProtein: return "High protein"
        case .lowCarb:     return "Low carb"
        case .custom:      return "Custom"
        }
    }

    var detail: String {
        switch self {
        case .recommended: return "Protein set from your lean mass, fat for hormonal health, carbs take the rest."
        case .balanced:    return "30% protein · 40% carbs · 30% fat"
        case .highProtein: return "40% protein · 30% carbs · 30% fat"
        case .lowCarb:     return "35% protein · 25% carbs · 40% fat"
        case .custom:      return "Set your own split."
        }
    }

    /// Fixed percentages of calories; nil where the grams come from somewhere else.
    var percentages: (protein: Double, carbs: Double, fat: Double)? {
        switch self {
        case .balanced:    return (30, 40, 30)
        case .highProtein: return (40, 30, 30)
        case .lowCarb:     return (35, 25, 40)
        case .recommended, .custom: return nil
        }
    }
}

// CLAUDE  Date 09/20/2026
// The chosen split, with the custom percentages alongside it so switching to Custom and back
// doesn't lose them. The fat floor still applies whatever is picked — that one is a health
// guardrail, not a preference.
struct MacroStyle: Codable, Hashable {
    var choice: MacroChoice
    var proteinPct: Double
    var carbsPct: Double
    var fatPct: Double

    static let recommended = MacroStyle(choice: .recommended, proteinPct: 30,
                                        carbsPct: 40, fatPct: 30)

    /// The percentages in force, or nil when the recommendation drives the grams.
    var percentages: (protein: Double, carbs: Double, fat: Double)? {
        switch choice {
        case .recommended: return nil
        case .custom:      return (proteinPct, carbsPct, fatPct)
        default:           return choice.percentages
        }
    }

    // CLAUDE  Date 09/20/2026
    // Keeps a custom split summing to 100: the moved macro takes its value and the other two
    // share the remainder in proportion (evenly when both sit at zero). Lifted from the old
    // NutritionGoalsView calculator, which this replaces.
    mutating func rebalance(changing macro: Macro, to newValue: Double) {
        let clamped = min(max(newValue, 0), 100)
        let others = Macro.allCases.filter { $0 != macro }
        let otherSum = others.reduce(0) { $0 + value(for: $1) }
        for other in others {
            let share = otherSum > 0
                ? (100 - clamped) * value(for: other) / otherSum
                : (100 - clamped) / Double(others.count)
            set(share, for: other)
        }
        set(clamped, for: macro)
    }

    enum Macro: CaseIterable { case protein, carbs, fat }

    func value(for macro: Macro) -> Double {
        switch macro {
        case .protein: return proteinPct
        case .carbs:   return carbsPct
        case .fat:     return fatPct
        }
    }

    mutating func set(_ value: Double, for macro: Macro) {
        switch macro {
        case .protein: proteinPct = value
        case .carbs:   carbsPct = value
        case .fat:     fatPct = value
        }
    }
}

// CLAUDE  Date 09/19/2026
// What the plan believes about the user's energy, kept as three separable parts so each can
// be measured, learned, or discarded on its own (see EnergyMath). Only `everydayFactor` is
// learned; training burn is measured from logged sessions and the trust scores decide how
// much of either the check-in is allowed to believe.
struct EnergyModel: Codable, Hashable {
    /// Multiplier on BMR for everything outside training: steps, job, fidgeting, adaptation.
    var everydayFactor: Double
    /// Average NET training kcal per day, already scaled by activityTrust.
    var trainingBurnPerDay: Double
    /// How much of the intake the food log appears to capture (1.25 = about 20% unlogged).
    var intakeRatio: Double
    var diaryTrust: Double
    var activityTrust: Double
    /// How many check-ins have taught this model — the UI says "still learning" under 2.
    var observations: Int

    init(everydayFactor: Double = BodySafety.everydayFactorDefault,
         trainingBurnPerDay: Double = 0,
         intakeRatio: Double = 1.0,
         diaryTrust: Double = 1.0,
         activityTrust: Double = 1.0,
         observations: Int = 0) {
        self.everydayFactor = everydayFactor
        self.trainingBurnPerDay = trainingBurnPerDay
        self.intakeRatio = intakeRatio
        self.diaryTrust = diaryTrust
        self.activityTrust = activityTrust
        self.observations = observations
    }

    enum CodingKeys: String, CodingKey {
        case everydayFactor, trainingBurnPerDay, intakeRatio, diaryTrust, activityTrust, observations
    }
    init(from decoder: Decoder) throws {
        let d = EnergyModel()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        everydayFactor = try c.decodeIfPresent(Double.self, forKey: .everydayFactor) ?? d.everydayFactor
        trainingBurnPerDay = try c.decodeIfPresent(Double.self, forKey: .trainingBurnPerDay) ?? d.trainingBurnPerDay
        intakeRatio = try c.decodeIfPresent(Double.self, forKey: .intakeRatio) ?? d.intakeRatio
        diaryTrust = try c.decodeIfPresent(Double.self, forKey: .diaryTrust) ?? d.diaryTrust
        activityTrust = try c.decodeIfPresent(Double.self, forKey: .activityTrust) ?? d.activityTrust
        observations = try c.decodeIfPresent(Int.self, forKey: .observations) ?? d.observations
    }
}

// CLAUDE  Date 09/19/2026
// The running plan. `phaseStartedDayKey` is separate from `startedDayKey` because changing
// phase restarts the two-week warm-up — the first fortnight of any new phase is water weight,
// not fat. Target history lives in BodyData, not here, so a phase change never loses it.
struct BodyPlan: Codable, Hashable {
    var id: UUID
    var track: PlanTrack
    var phase: PlanPhase
    var pace: Pace
    /// Bodybuilding cuts aim at a body-fat percentage; everything else aims at a weight.
    var targetBodyFatPct: Double?
    var targetWeightLb: Double?
    var startedDayKey: String
    var phaseStartedDayKey: String
    var lastCheckInDayKey: String?
    /// 1 = Sunday, matching Calendar's weekday numbering.
    var checkInWeekday: Int
    var remindersOn: Bool
    var energy: EnergyModel
    // CLAUDE  Date 09/20/2026
    // Optional so a plan written before macro styles existed still decodes (the house pattern
    // for new fields); `effectiveMacroStyle` is what callers read.
    var macroStyle: MacroStyle?

    var effectiveMacroStyle: MacroStyle { macroStyle ?? .recommended }

    init(id: UUID = UUID(), track: PlanTrack, phase: PlanPhase, pace: Pace,
         targetBodyFatPct: Double? = nil, targetWeightLb: Double? = nil,
         startedDayKey: String = DayKey.key(), phaseStartedDayKey: String = DayKey.key(),
         lastCheckInDayKey: String? = nil, checkInWeekday: Int = 2,
         remindersOn: Bool = false, energy: EnergyModel = EnergyModel(),
         macroStyle: MacroStyle? = nil) {
        self.id = id
        self.track = track
        self.phase = phase
        self.pace = pace
        self.targetBodyFatPct = targetBodyFatPct
        self.targetWeightLb = targetWeightLb
        self.startedDayKey = startedDayKey
        self.phaseStartedDayKey = phaseStartedDayKey
        self.lastCheckInDayKey = lastCheckInDayKey
        self.checkInWeekday = checkInWeekday
        self.remindersOn = remindersOn
        self.energy = energy
        self.macroStyle = macroStyle
    }

    /// Whole weeks the current phase has been running, for "Week 3" and the long-cut flag.
    func weeksInPhase(on dayKey: String = DayKey.key()) -> Int {
        guard let days = DayKey.days(from: phaseStartedDayKey, to: dayKey), days >= 0 else { return 0 }
        return days / 7
    }
}

// CLAUDE  Date 09/19/2026
// What the plan told the user to eat, from a given day. Kept as history because the check-in
// has to judge each diary day against the target IN FORCE THAT DAY, and because comparing the
// newest snapshot to the live NutritionGoals is how a manual edit is detected.
struct TargetSnapshot: Codable, Hashable, Identifiable {
    var id: UUID
    var fromDayKey: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(id: UUID = UUID(), fromDayKey: String = DayKey.key(),
         calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.id = id
        self.fromDayKey = fromDayKey
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

// CLAUDE  Date 09/19/2026
// One completed check-in, kept whether or not the user accepted the change — a declined
// proposal is still evidence about their expenditure, and the history is what the hub shows.
struct BodyCheckInRecord: Codable, Hashable, Identifiable {
    /// Which evidence the check-in was able to use. Surfaced in the hub, in plain words.
    enum Channel: String, Codable {
        case diary          // the food log matched the scale and was trusted
        case scaleOnly      // intake assumed from the target, weighted lower
        case noChange       // not enough data, or the user said they hadn't followed it
    }

    var id: UUID
    var dayKey: String
    var channel: Channel
    var previousCalories: Double
    var proposedCalories: Double
    var accepted: Bool
    var averageWeightLb: Double
    var previousAverageWeightLb: Double
    var ratePctPerWeek: Double
    var estimatedTDEE: Double
    var flags: [SafetyFlag]

    init(id: UUID = UUID(), dayKey: String = DayKey.key(), channel: Channel,
         previousCalories: Double, proposedCalories: Double, accepted: Bool,
         averageWeightLb: Double, previousAverageWeightLb: Double,
         ratePctPerWeek: Double, estimatedTDEE: Double, flags: [SafetyFlag] = []) {
        self.id = id
        self.dayKey = dayKey
        self.channel = channel
        self.previousCalories = previousCalories
        self.proposedCalories = proposedCalories
        self.accepted = accepted
        self.averageWeightLb = averageWeightLb
        self.previousAverageWeightLb = previousAverageWeightLb
        self.ratePctPerWeek = ratePctPerWeek
        self.estimatedTDEE = estimatedTDEE
        self.flags = flags
    }
}

// CLAUDE  Date 09/19/2026
// Proof the user read and accepted the health disclaimer, versioned so changing that copy
// re-asks. Stored in the vault with everything else; losing it only costs a re-acceptance.
struct HealthConsent: Codable, Hashable {
    var version: Int
    var acceptedAt: Date

    var isCurrent: Bool { version >= BodySafety.consentVersion }
}

// CLAUDE  Date 09/19/2026
// Everything the body feature stores, as one value — it is sealed and written as a single
// encrypted blob (BodyVault), so there is exactly one file and one privacy boundary to reason
// about. NOTHING in here may be added to SharedCard, the widget snapshot, the wallet sync or
// any export.
struct BodyData: Codable, Hashable {
    var metrics: BodyMetrics?
    var weighIns: [WeighIn]
    var plan: BodyPlan?
    var checkIns: [BodyCheckInRecord]
    var targetHistory: [TargetSnapshot]
    var consent: HealthConsent?
    /// The Journal promo card was dismissed before a plan existed.
    var promoDismissed: Bool

    init(metrics: BodyMetrics? = nil, weighIns: [WeighIn] = [], plan: BodyPlan? = nil,
         checkIns: [BodyCheckInRecord] = [], targetHistory: [TargetSnapshot] = [],
         consent: HealthConsent? = nil, promoDismissed: Bool = false) {
        self.metrics = metrics
        self.weighIns = weighIns
        self.plan = plan
        self.checkIns = checkIns
        self.targetHistory = targetHistory
        self.consent = consent
        self.promoDismissed = promoDismissed
    }

    var hasPlan: Bool { plan != nil }

    /// The target in force on a given day — what a diary day is judged against.
    func target(on dayKey: String) -> TargetSnapshot? {
        targetHistory
            .filter { $0.fromDayKey <= dayKey }
            .max { $0.fromDayKey < $1.fromDayKey }
    }

    enum CodingKeys: String, CodingKey {
        case metrics, weighIns, plan, checkIns, targetHistory, consent, promoDismissed
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        metrics = try c.decodeIfPresent(BodyMetrics.self, forKey: .metrics)
        weighIns = try c.decodeIfPresent([WeighIn].self, forKey: .weighIns) ?? []
        plan = try c.decodeIfPresent(BodyPlan.self, forKey: .plan)
        checkIns = try c.decodeIfPresent([BodyCheckInRecord].self, forKey: .checkIns) ?? []
        targetHistory = try c.decodeIfPresent([TargetSnapshot].self, forKey: .targetHistory) ?? []
        consent = try c.decodeIfPresent(HealthConsent.self, forKey: .consent)
        promoDismissed = try c.decodeIfPresent(Bool.self, forKey: .promoDismissed) ?? false
    }
}
