import Foundation

// Claude  Date 09/07/2026
// Cardio calorie estimation and data guardrails — the cardio sibling of AchievementPolicy,
// and like it, the ONE place these numbers live. Tune here only; the code that applies them
// is the workout editor (hard clamps) and AppStore.finishWorkout (credit).
//
// Two tiers, on purpose:
//   soft band  — warns inline and revokes calories + ledger credit. The bout still SAVES,
//                because a real 6-hour century ride shouldn't be locked out by a guess.
//   hard ceiling — physically impossible. Clamped at the input edge, never stored.
enum CardioPolicy {

    // MARK: - Unit constants

    static let lbPerKilogram = 2.204_622_6
    static let metersPerSecondPerMPH = 0.447_04

    /// mph → m/s, so the tables below can read in the units their sources are published in.
    private static func mps(_ mph: Double) -> Double { mph * metersPerSecondPerMPH }

    // MARK: - Calories

    // Claude  Date 09/07/2026
    // ACSM / Compendium of Physical Activities: kcal = MET × 3.5 × kg / 200 × minutes.
    // Deliberately an ESTIMATE — no heart rate, no machine telemetry — so every surface that
    // shows it labels it one. Returns nil rather than guessing when there's no bodyweight,
    // and nil for an implausible bout, so a bad number can never be dressed up as calories.
    static func calories(machine: CardioMachine, seconds: Int, meters: Double?,
                         bodyweightLb: Double?) -> Double? {
        guard let bodyweightLb, bodyweightLb > 0, seconds > 0,
              isPlausible(machine: machine, seconds: seconds, meters: meters) else { return nil }
        let kg = bodyweightLb / lbPerKilogram
        let minutes = Double(seconds) / 60
        let value = met(machine: machine, seconds: seconds, meters: meters) * 3.5 * kg / 200 * minutes
        return value.isFinite && value > 0 ? value : nil
    }

    // Claude  Date 09/07/2026
    // MET for a bout. Pace-derived only where distance is honest (treadmill, rower); the
    // rest take a fixed conservative value. A pace machine logged without distance falls
    // back to its own mid band rather than to zero.
    static func met(machine: CardioMachine, seconds: Int, meters: Double?) -> Double {
        guard machine.derivesIntensityFromPace,
              let meters, meters > 0, seconds > 0 else { return fixedMET(machine) }
        let metersPerSecond = meters / Double(seconds)
        switch machine {
        case .treadmill: return treadmillMET(mph: metersPerSecond / metersPerSecondPerMPH)
        case .rower:     return rowerMET(secondsPer500m: 500 / metersPerSecond)
        default:         return fixedMET(machine)
        }
    }

    // Claude  Date 09/07/2026
    // Fixed METs, from the Compendium of Physical Activities. Bike and elliptical are here
    // because their reported distance is virtual, so pace can't be trusted to set intensity;
    // both are set below the Compendium's "moderate" entry since resistance is unknown.
    // Treadmill and rower values are their mid bands, used only when distance is absent.
    private static func fixedMET(_ machine: CardioMachine) -> Double {
        switch machine {
        case .treadmill:      return 5.0    // ~3.8 mph
        case .stationaryBike: return 7.0    // Compendium 02010 (moderate/150 W) is 8.8
        case .elliptical:     return 5.0    // Compendium 02048
        case .rower:          return 7.0    // ~2:30 /500m
        case .stairClimber:   return 9.0    // Compendium 02065
        }
    }

    /// Treadmill MET by belt speed, Compendium 12030 (walking) / 17190 (running).
    private static func treadmillMET(mph: Double) -> Double {
        switch mph {
        case ..<2.5: return 2.8
        case ..<3.5: return 3.5
        case ..<4.3: return 5.0
        case ..<5.6: return 8.3
        case ..<6.8: return 9.8
        case ..<8.0: return 11.0
        case ..<9.3: return 12.8
        default:     return 14.5
        }
    }

    /// Rower MET by split, Compendium 02060. Bands are seconds per 500 m.
    private static func rowerMET(secondsPer500m: Double) -> Double {
        switch secondsPer500m {
        case ..<120: return 12.0    // faster than 2:00
        case ..<135: return 8.5     // 2:00–2:15
        case ..<165: return 7.0     // 2:15–2:45
        default:     return 4.8
        }
    }

    // MARK: - Duration bounds

    // Claude  Date 09/07/2026
    // Bouts outside this earn nothing. 1 min – 6 h.
    //
    // The upper bound is deliberately generous, because duration alone is NOT what makes a
    // bout implausible — speed is, and the speed band below already catches that. Six hours
    // clears a 100-mile ride, an ultra-distance row and a marathon walked on a treadmill,
    // all of which are real sessions a 3-hour ceiling would have silently refused credit for.
    static let softDurationRange = 60...(6 * 3600)
    /// Clamped at the input edge — nothing longer is ever stored.
    static let hardMaxSeconds = 8 * 3600
    // Claude  Date 09/07/2026
    // The anti-farming lever, and the only one: a completed bout shorter than this mints no
    // ledger event, so a 30-second treadmill tap can't buy a streak day. Lifting sets in the
    // same session are unaffected — this gates the cardio bout alone.
    static let minimumCreditedSeconds = 300

    // MARK: - Speed bounds

    // Claude  Date 09/07/2026
    // Soft plausibility band in m/s. Inside it a bout is credited normally; outside it the
    // bout saves but earns no calories and no ledger event, and the editor names the derived
    // speed so the user can see which field is wrong. The rower's band is its pace band
    // (4:00 – 1:20 per 500 m) expressed the same way. nil = no distance, nothing to check.
    static func softSpeedRange(for machine: CardioMachine) -> ClosedRange<Double>? {
        switch machine {
        case .treadmill:      return mps(0.9)...mps(13.4)
        case .stationaryBike: return mps(5)...mps(30)
        case .elliptical:     return mps(2)...mps(12)
        case .rower:          return (500.0 / 240)...(500.0 / 80)
        case .stairClimber:   return nil
        }
    }

    // Claude  Date 09/07/2026
    // Physically impossible ceiling in m/s. This is the tier that CLAMPS: a bout has no Save
    // button (every keystroke persists through the workout binding), so refusing a value
    // means bounding it, the same way adjustFocusedField already clamps reps and weight at 0.
    // Rower 500/60 = a 1:00 split; the 500 m world record is about 1:10.
    static func hardMaxSpeed(for machine: CardioMachine) -> Double? {
        switch machine {
        case .treadmill:      return mps(20)
        case .stationaryBike: return mps(60)
        case .elliptical:     return mps(20)
        case .rower:          return 500.0 / 60
        case .stairClimber:   return nil
        }
    }

    // MARK: - Verdicts

    /// Inside the soft band: this bout earns calories and (if long enough) ledger credit.
    static func isPlausible(machine: CardioMachine, seconds: Int, meters: Double?) -> Bool {
        guard softDurationRange.contains(seconds) else { return false }
        guard let meters, meters > 0, let band = softSpeedRange(for: machine) else { return true }
        guard seconds > 0 else { return false }
        return band.contains(meters / Double(seconds))
    }

    // Claude  Date 09/07/2026
    // Inside the hard ceiling. False means the editor clamps what is being typed and refuses
    // to check the bout off, and finishWorkout never mints it. Distance with no time is
    // rejected outright — it's the divide-by-zero case, not a slow bout.
    static func isWithinHardLimits(machine: CardioMachine, seconds: Int, meters: Double?) -> Bool {
        guard seconds >= 0, seconds <= hardMaxSeconds else { return false }
        guard let meters, meters > 0 else { return true }
        guard seconds > 0, let ceiling = hardMaxSpeed(for: machine) else { return seconds > 0 }
        return meters / Double(seconds) <= ceiling
    }

    /// The furthest this machine could physically cover in `seconds` — what the distance
    /// field clamps to on commit. nil when the machine has no distance to clamp.
    static func maxAllowedMeters(machine: CardioMachine, seconds: Int) -> Double? {
        guard seconds > 0, let ceiling = hardMaxSpeed(for: machine) else { return nil }
        return ceiling * Double(seconds)
    }

    // Claude  Date 09/07/2026
    // Whether a completed bout earns a ledger event: long enough to be real training, and
    // inside the soft band. A bout that fails still saves and still shows in history — it
    // just earns no badge credit, no streak day and no calories.
    static func earnsCredit(machine: CardioMachine, seconds: Int, meters: Double?) -> Bool {
        seconds >= minimumCreditedSeconds
            && isPlausible(machine: machine, seconds: seconds, meters: meters)
    }

    // MARK: - Warning copy

    // Claude  Date 09/07/2026
    // The inline warning for an implausible bout, or nil when it's fine. Naming the derived
    // speed is the whole point — a bare "implausible" doesn't tell you which of the two
    // fields you fat-fingered. Rendered as the exercise Section's footer, the app's idiom
    // for a soft warning (see NewExerciseView.brandFooter).
    static func warning(machine: CardioMachine, seconds: Int, meters: Double?,
                        unit: DistanceUnit) -> String? {
        guard seconds > 0 else { return nil }
        guard !isPlausible(machine: machine, seconds: seconds, meters: meters) else { return nil }
        let tail = " That won't count toward calories or your streak — check the numbers."

        if !softDurationRange.contains(seconds) {
            let low = seconds < softDurationRange.lowerBound
            return (low ? "A bout under a minute is too short to score."
                        : "A bout over 6 hours is longer than this can score.") + tail
        }
        guard let meters, meters > 0 else { return nil }
        let derived = machine == .rower
            ? (CardioFormat.pace(machine: machine, seconds: seconds, meters: meters, unit: unit) ?? "")
            : String(format: "%.0f mph", meters / Double(seconds) / metersPerSecondPerMPH)
        let logged = CardioFormat.distance(meters: meters, unit: unit) ?? ""
        return "\(logged) in \(CardioFormat.duration(seconds: seconds)) works out to \(derived)." + tail
    }
}
