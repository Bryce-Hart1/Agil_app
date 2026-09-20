import Foundation

// CLAUDE  Date 09/19/2026
// Who the plan is for: the fixed facts an energy estimate needs (sex, age, height) plus a
// training frequency used ONLY as a cold-start stand-in until real sessions accumulate.
// Lives inside the encrypted body vault, never profile.json — nothing here may be sent
// anywhere (see BodyStore's privacy contract).
struct BodyMetrics: Codable, Hashable {
    var sex: BiologicalSex
    /// Birth year alone — the plan needs age to ±1 year, not a birthday.
    var birthYear: Int
    var heightCm: Double
    /// Sessions per week the user expects to train. Replaced by measured burn (WorkoutEnergy).
    var trainingDaysPerWeek: Int

    init(sex: BiologicalSex = .undisclosed, birthYear: Int = 0,
         heightCm: Double = 0, trainingDaysPerWeek: Int = 3) {
        self.sex = sex
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.trainingDaysPerWeek = trainingDaysPerWeek
    }

    // CLAUDE  Date 09/19/2026
    // Age recomputed on every read rather than stored, so a plan left running for a year
    // doesn't keep feeding a stale age into Mifflin-St Jeor.
    func age(on date: Date = Date(), calendar: Calendar = .current) -> Int {
        max(0, calendar.component(.year, from: date) - birthYear)
    }

    /// Everything the planner needs has been answered.
    var isComplete: Bool { birthYear > 1900 && heightCm > 0 }

    // CLAUDE  Date 09/19/2026
    // Forgiving decode, the house pattern: a vault written before a field existed reads it
    // as the default rather than failing the whole load.
    enum CodingKeys: String, CodingKey {
        case sex, birthYear, heightCm, trainingDaysPerWeek
    }
    init(from decoder: Decoder) throws {
        let defaults = BodyMetrics()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sex = try c.decodeIfPresent(BiologicalSex.self, forKey: .sex) ?? defaults.sex
        birthYear = try c.decodeIfPresent(Int.self, forKey: .birthYear) ?? defaults.birthYear
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm) ?? defaults.heightCm
        trainingDaysPerWeek = try c.decodeIfPresent(Int.self, forKey: .trainingDaysPerWeek)
            ?? defaults.trainingDaysPerWeek
    }
}

// CLAUDE  Date 09/19/2026
// Biological sex, used for the metabolism estimate and the conservative safety floors —
// deliberately NOT UserProfile.gender, which is the "Identify as" setting that shapes badge
// thresholds. `.undisclosed` is a first-class answer: the plan still works, it just leans
// harder on the check-ins (see BodySafety and EnergyMath for what it costs).
enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case undisclosed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male:        return "Male"
        case .female:      return "Female"
        case .undisclosed: return "Prefer not to say"
        }
    }
}

// CLAUDE  Date 09/19/2026
// The user's display units for body data (Settings → Body & Plan). Storage stays canonical
// POUNDS and CENTIMETERS; this converts at the display/input edge only, so flipping it never
// rewrites a weigh-in. Same contract WaterUnit and DistanceUnit own, including defaulting to
// US units rather than the locale, so the app doesn't mix systems.
enum BodyUnits: String, CaseIterable, Identifiable {
    case imperial
    case metric

    static let storageKey = "bodyUnits"
    static let defaultValue = BodyUnits.imperial
    static let centimetersPerInch = 2.54
    static let inchesPerFoot = 12.0

    var id: String { rawValue }

    var label: String {
        switch self {
        case .imperial: return "Pounds & feet (lb, ft/in)"
        case .metric:   return "Kilograms & centimeters (kg, cm)"
        }
    }

    var weightAbbreviation: String { self == .imperial ? "lb" : "kg" }

    // MARK: - Weight (canonical: pounds)

    func fromPounds(_ lb: Double) -> Double {
        self == .imperial ? lb : lb / CardioPolicy.lbPerKilogram
    }

    func toPounds(_ value: Double) -> Double {
        self == .imperial ? value : value * CardioPolicy.lbPerKilogram
    }

    // CLAUDE  Date 09/19/2026
    // One decimal, unlike WaterUnit's whole numbers: a tenth of a pound is the resolution a
    // bathroom scale reports and the trend line is built from, so it has to survive display.
    func weightText(fromPounds lb: Double, includeUnit: Bool = false) -> String {
        let value = String(format: "%.1f", fromPounds(lb))
        return includeUnit ? value + " " + weightAbbreviation : value
    }

    // MARK: - Height (canonical: centimeters)

    func fromCentimeters(_ cm: Double) -> Double {
        self == .metric ? cm : cm / Self.centimetersPerInch
    }

    func toCentimeters(_ value: Double) -> Double {
        self == .metric ? value : value * Self.centimetersPerInch
    }

    /// Imperial height as whole feet + inches, for the two-field editor. Metric ignores it.
    static func feetAndInches(fromCentimeters cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = (cm / centimetersPerInch).rounded()
        return (Int(totalInches / inchesPerFoot), Int(totalInches.truncatingRemainder(dividingBy: inchesPerFoot)))
    }

    static func centimeters(feet: Int, inches: Int) -> Double {
        (Double(feet) * inchesPerFoot + Double(inches)) * centimetersPerInch
    }

    /// "5′11″" or "180 cm" — the one-line form for summary rows.
    func heightText(fromCentimeters cm: Double) -> String {
        guard self == .imperial else { return "\(Int(cm.rounded())) cm" }
        let parts = Self.feetAndInches(fromCentimeters: cm)
        return "\(parts.feet)′\(parts.inches)″"
    }
}
