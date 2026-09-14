import Foundation

// Claude  Date 09/07/2026
// Which cardio machine a lift is performed on — the behavior gate for cardio logging.
// nil on every strength lift; non-nil swaps the editor's set rows for bout rows (duration
// + distance) and routes the entry through CardioPolicy for calories and guardrails.
enum CardioMachine: String, Codable, CaseIterable, Hashable {
    case treadmill, stationaryBike, elliptical, rower, stairClimber

    var title: String {
        switch self {
        case .treadmill:      return "Treadmill"
        case .stationaryBike: return "Stationary Bike"
        case .elliptical:     return "Elliptical"
        case .rower:          return "Rower"
        case .stairClimber:   return "Stair Climber"
        }
    }

    // Claude  Date 09/07/2026
    // Whether the machine reports a distance worth logging. A stair climber counts floors,
    // not distance, so its bout row hides the field rather than inviting a meaningless number.
    var supportsDistance: Bool { self != .stairClimber }

    // Claude  Date 09/07/2026
    // Whether logged distance is honest enough to derive intensity from. Treadmill belt
    // speed and rower meters are real; bike and elliptical "distance" is manufacturer-
    // virtual (a Peloton mile is not a Keiser mile), so those take a fixed MET instead.
    var derivesIntensityFromPace: Bool { self == .treadmill || self == .rower }
}

// Claude  Date 09/07/2026
// The user's display unit for cardio distance (Settings → Cardio). Storage stays canonical
// METERS everywhere (ExerciseSet/ActivityEvent.distanceMeters); this converts at the
// display/input edge only, so flipping the setting never rewrites history. Same contract
// WaterUnit owns for water — views read it via @AppStorage on the raw value.
enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles
    case kilometers

    static let storageKey = "cardioDistanceUnit"
    static let metersPerMile = 1_609.344
    static let metersPerKilometer = 1_000.0

    var id: String { rawValue }

    var label: String {
        switch self {
        case .miles:      return "Miles (mi)"
        case .kilometers: return "Kilometers (km)"
        }
    }

    var abbreviation: String {
        switch self {
        case .miles:      return "mi"
        case .kilometers: return "km"
        }
    }

    var metersPerUnit: Double {
        self == .miles ? Self.metersPerMile : Self.metersPerKilometer
    }

    func fromMeters(_ meters: Double) -> Double { meters / metersPerUnit }
    func toMeters(_ value: Double) -> Double { value * metersPerUnit }

    /// Pace suffix for this unit, e.g. "/mi".
    var paceUnitLabel: String { "/" + abbreviation }

    // Claude  Date 09/07/2026
    // Two decimals, unlike WaterUnit's whole numbers — a tenth of a mile is a meaningful
    // slice of a cardio session, so "3.10 mi" has to survive the round trip.
    func text(fromMeters meters: Double) -> String {
        String(format: "%.2f", fromMeters(meters))
    }
}

// Claude  Date 09/14/2026
// The one entry a cardio exercise logs per workout: time + distance, done once (no sets,
// no "bouts"). Shared by add-exercise, swap and preset start so every path seeds the same
// 20-minute default. reps/weight stay 0 so volume/PR/1RM sums keep ignoring it.
extension ExerciseSet {
    static func cardioEntry(seconds: Int = 20 * 60) -> ExerciseSet {
        ExerciseSet(reps: 0, weight: 0, durationSeconds: seconds)
    }
}

// Claude  Date 09/07/2026
// Display strings for a cardio bout, shared by the bout row, the reorder sheet and the
// post-workout card so they can't drift. Pure formatting — the numbers and the rules that
// judge them live in CardioPolicy.
enum CardioFormat {
    // Claude  Date 09/07/2026
    // Clock-style bout length: "25:00", or "1:05:00" past an hour. Deliberately NOT
    // Workout.durationText ("42 min"), which reads a whole session, not a single bout.
    static func duration(seconds: Int) -> String {
        let total = Swift.max(0, seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }

    /// "3.10 mi", or nil when no distance was logged.
    static func distance(meters: Double?, unit: DistanceUnit) -> String? {
        guard let meters, meters > 0 else { return nil }
        return unit.text(fromMeters: meters) + " " + unit.abbreviation
    }

    // Claude  Date 09/07/2026
    // Pace for the bout row's second line. Rowers read in split (per 500m) by universal
    // convention; every other machine uses the user's distance unit. nil when there is no
    // distance or no time to divide by.
    static func pace(machine: CardioMachine, seconds: Int, meters: Double?,
                     unit: DistanceUnit) -> String? {
        guard let meters, meters > 0, seconds > 0 else { return nil }
        let secondsPerUnit: Double
        let label: String
        if machine == .rower {
            secondsPerUnit = Double(seconds) / (meters / 500)
            label = "/500m"
        } else {
            secondsPerUnit = Double(seconds) / unit.fromMeters(meters)
            label = unit.paceUnitLabel
        }
        guard secondsPerUnit.isFinite, secondsPerUnit > 0, secondsPerUnit < 86_400 else { return nil }
        let whole = Int(secondsPerUnit.rounded())
        return String(format: "%d:%02d %@", whole / 60, whole % 60, label)
    }

    /// "~310 kcal (est.)" — always suffixed, because it always is one.
    static func calories(_ kcal: Double) -> String {
        "~\(Int(kcal.rounded())) kcal (est.)"
    }

    // Claude  Date 09/07/2026
    // One-line bout summary for list rows ("25:00 · 3.10 mi"). Used by the reorder sheet,
    // which would otherwise print a lift's "0 reps × 0 lb" for every bout.
    static func summary(seconds: Int, meters: Double?, unit: DistanceUnit) -> String {
        let time = duration(seconds: seconds)
        guard let dist = distance(meters: meters, unit: unit) else { return time }
        return time + " · " + dist
    }
}
