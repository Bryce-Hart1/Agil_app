import Foundation

// CLAUDE  Date 09/19/2026
// How much the plan is allowed to believe what it's been told. Self-reported food and
// training are the two noisiest inputs in any calorie planner, so each is scored, and an
// input that can't be squared with the scale is DROPPED from the estimate rather than
// allowed to skew it. Pure scoring; BodyCheckInEngine decides what to do with the numbers.
enum DataTrust {

    // MARK: - Activity

    // CLAUDE  Date 09/19/2026
    // Per-session score: a bout or set outside CardioPolicy / AchievementPolicy limits is
    // worth nothing, and a session entered after the fact (no live timestamps, no ledger
    // events) is worth half — the real-time ledger is the app's existing anti-backdating
    // signal, and this reuses it rather than inventing a second one.
    static func score(_ sample: SessionSample) -> Double {
        guard sample.isPlausible else { return 0 }
        return sample.isRealTime ? 1.0 : 0.5
    }

    // CLAUDE  Date 09/19/2026
    // The running activity score. With no sessions in the window there is nothing to judge —
    // not training isn't dishonesty — so the previous score stands rather than decaying.
    static func activityTrust(samples: [SessionSample], previous: Double) -> Double {
        guard !samples.isEmpty else { return clampTrust(previous) }
        let observed = samples.reduce(0) { $0 + score($1) } / Double(samples.count)
        return clampTrust(0.6 * previous + 0.4 * observed)
    }

    // CLAUDE  Date 09/19/2026
    // Average net training kcal per day across the window, counting rest days as zero so the
    // figure already reflects training frequency. Implausible sessions never contribute, each
    // day is capped, and the whole thing is scaled by trust — below the floor it becomes 0 and
    // whatever that training really costs lands in the learned everyday factor instead.
    static func trainingBurnPerDay(samples: [SessionSample], windowKeys: [String],
                                   trust: Double) -> Double {
        guard !windowKeys.isEmpty else { return 0 }
        guard trust >= BodySafety.trustFloor else { return 0 }
        let keys = Set(windowKeys)
        var perDay: [String: Double] = [:]
        for sample in samples where sample.isPlausible && keys.contains(sample.dayKey) {
            perDay[sample.dayKey, default: 0] += sample.netKcal
        }
        let total = perDay.values.reduce(0) { $0 + WorkoutEnergy.cappedDay($1) }
        return total / Double(windowKeys.count) * trust
    }

    // MARK: - Diary

    // CLAUDE  Date 09/19/2026
    // What the food log looked like over a window: days that logged enough of that day's
    // target to be worth reading, and the average of those days. Days logged at less than the
    // threshold are treated as "didn't log", not as "ate 300 kcal", which is the single
    // biggest way a naive planner talks itself into cutting someone's calories.
    struct DiaryWindow {
        let completeDays: Int
        let totalDays: Int
        let averageLoggedKcal: Double?
        /// Average over complete days of logged ÷ target, for the cut adherence check.
        let averageShareOfTarget: Double?

        var completeness: Double {
            totalDays > 0 ? Double(completeDays) / Double(totalDays) : 0
        }
    }

    static func diaryWindow(loggedKcal: [String: Double], targets: [String: Double],
                            windowKeys: [String]) -> DiaryWindow {
        var complete: [Double] = []
        var shares: [Double] = []
        for key in windowKeys {
            guard let target = targets[key], target > 0 else { continue }
            let logged = loggedKcal[key] ?? 0
            let share = logged / target
            guard share >= BodySafety.completeDayThreshold else { continue }
            complete.append(logged)
            shares.append(share)
        }
        return DiaryWindow(
            completeDays: complete.count,
            totalDays: windowKeys.count,
            averageLoggedKcal: complete.isEmpty ? nil : complete.reduce(0, +) / Double(complete.count),
            averageShareOfTarget: shares.isEmpty ? nil : shares.reduce(0, +) / Double(shares.count))
    }

    // CLAUDE  Date 09/19/2026
    // How much of what they ate the log appears to capture. Under-logging is ordinary and well
    // documented — most people miss 10–30% — so this is a CORRECTION, not a verdict: a steady
    // 1.25 is used to scale their logged intake, and their calories are left alone.
    static let ratioRange = 0.80...1.60

    static func observedIntakeRatio(impliedIntake: Double, reportedIntake: Double) -> Double? {
        guard reportedIntake > 0, impliedIntake > 0 else { return nil }
        return impliedIntake / reportedIntake
    }

    static func smoothedIntakeRatio(observed: Double, previous: Double) -> Double {
        min(max(0.6 * previous + 0.4 * observed, ratioRange.lowerBound), ratioRange.upperBound)
    }

    // CLAUDE  Date 09/19/2026
    // Diary trust is completeness and CONSISTENCY, not accuracy: logging 25% light every week
    // is a bias the model corrects for, while a ratio that bounces around is noise it can't.
    // Only the second one costs trust. An observation far outside the plausible band scores
    // zero, which is how fabricated logs fall out of the estimate.
    static func diaryTrust(window: DiaryWindow, observedRatio: Double?,
                           smoothedRatio: Double, previous: Double) -> Double {
        let completeness = min(1, window.completeness / 0.6)
        var consistency = 1.0
        if let observedRatio {
            guard ratioRange.contains(observedRatio) else { return clampTrust(0.6 * previous) }
            consistency = max(0, 1 - abs(observedRatio - smoothedRatio) / 0.3)
        }
        // Consistency outweighs completeness: a half-filled but truthful log is still worth
        // reading, while a full one that contradicts the scale every week is not.
        let observed = 0.35 * completeness + 0.65 * consistency
        return clampTrust(0.6 * previous + 0.4 * observed)
    }

    /// Whether this window's food log is worth building the estimate on.
    static func canUseDiary(trust: Double, window: DiaryWindow, phase: PlanPhase) -> Bool {
        guard trust >= BodySafety.trustFloor,
              window.completeDays >= BodySafety.minimumCompleteDays else { return false }
        // On a cut, a log that averages well under target is under-logging, not adherence.
        if phase.direction < 0, let share = window.averageShareOfTarget,
           share < BodySafety.cutAdherenceThreshold {
            return false
        }
        return true
    }

    static func clampTrust(_ value: Double) -> Double { min(1, max(0, value)) }

    // MARK: - Plain-language copy

    // CLAUDE  Date 09/19/2026
    // What the hub says about each input. Rule: describe what the plan is using and what would
    // sharpen it. Never accuse, never imply dishonesty, and never show the ratio as a number —
    // "your log runs lighter than your results" is the whole message.
    static func activityCopy(trust: Double, hasSessions: Bool) -> String {
        guard hasSessions else { return "No sessions logged yet, so training isn't part of the estimate." }
        if trust >= 0.85 { return "Your logged sessions are counted in full." }
        if trust >= BodySafety.trustFloor { return "Some sessions couldn't be verified, so training counts for less." }
        return "Your sessions aren't adding up, so the plan is going by your weigh-ins instead."
    }

    static func diaryCopy(trust: Double, ratio: Double, usable: Bool) -> String {
        if !usable && trust < BodySafety.trustFloor {
            return "Your food log and your weigh-ins don't line up, so the plan is going by the scale."
        }
        if !usable { return "Not enough logged days this time, so the plan is going by the scale." }
        if ratio >= 1.12 { return "Your log runs a little lighter than your results — the plan accounts for that." }
        return "Your food log matches your results, so the plan is using it."
    }
}
