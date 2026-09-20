import Foundation
import SwiftUI

// CLAUDE  Date 09/19/2026
// The body feature's store, and its privacy boundary. Deliberately NOT part of AppStore: one
// object, one encrypted file, one contract — nothing in here may be added to SharedCard,
// CardSyncService, WidgetSnapshot, CloudWalletSync, or any export. It reads AppStore (food,
// workouts, goals) but AppStore never reads it, except through the bodyweight provider.
@MainActor
final class BodyStore: ObservableObject {

    // CLAUDE  Date 09/19/2026
    // Why a state rather than a Bool: a missing key and a locked device look identical through
    // the Keychain's `get`, and offering "start fresh" for the second one would invite a user
    // to erase perfectly good data. `.temporarilyUnavailable` retries instead.
    enum State: Equatable {
        case loading
        case ready
        /// Key gone, file present — the data can't be read. Only here is erasing offered.
        case unreadable
        /// The Keychain couldn't answer yet. Nothing saves; it retries on unlock.
        case temporarilyUnavailable
    }

    /// Which body screen the app should present, relayed through the store so it survives the
    /// world switch that rebuilds the Journal (same idea as WorkoutSession.requestedWorkoutID).
    enum Flow: String, Identifiable {
        case setup, checkIn
        var id: String { rawValue }
    }

    @Published private(set) var data = BodyData()
    @Published private(set) var state: State = .loading
    @Published var requestedFlow: Flow?

    private let vault: BodyVault
    private var hasLoaded = false

    init(vault: BodyVault = BodyVault()) {
        self.vault = vault
    }

    // MARK: - Loading

    // CLAUDE  Date 09/19/2026
    // Lazy on purpose: the first read happens when a body screen appears, which is always in
    // the foreground with the device unlocked — the one moment the Keychain is certain to
    // answer. Side effect: nothing saves until a successful load, so a bad read can't be
    // written back over good data.
    func loadIfNeeded() {
        guard !hasLoaded else { return }
        do {
            data = try vault.load() ?? BodyData()
            hasLoaded = true
            state = .ready
        } catch BodyVault.VaultError.keyUnavailable {
            state = .temporarilyUnavailable
        } catch BodyVault.VaultError.keyMissing, BodyVault.VaultError.decryptionFailed {
            state = .unreadable
        } catch {
            state = .unreadable
        }
    }

    /// Called when the device unlocks or the app becomes active, to retry a locked read.
    func retryIfUnavailable() {
        guard state == .temporarilyUnavailable else { return }
        loadIfNeeded()
    }

    // CLAUDE  Date 09/19/2026
    // The only escape from `.unreadable`, and always the user's choice. The old file is parked
    // rather than deleted: a key can still come back with a restore from an encrypted backup.
    func startFresh() {
        vault.moveAside()
        data = BodyData()
        hasLoaded = true
        state = .ready
        save()
    }

    private func save() {
        guard state == .ready else { return }
        do {
            try vault.save(data)
        } catch BodyVault.VaultError.keyUnavailable {
            state = .temporarilyUnavailable
        } catch {
            state = .unreadable
        }
    }

    // MARK: - Consent and metrics

    var hasConsented: Bool { data.consent?.isCurrent ?? false }

    func recordConsent() {
        data.consent = HealthConsent(version: BodySafety.consentVersion, acceptedAt: Date())
        save()
    }

    func updateMetrics(_ metrics: BodyMetrics) {
        data.metrics = metrics
        save()
    }

    func dismissPromo() {
        data.promoDismissed = true
        save()
    }

    // MARK: - Weigh-ins

    var latestWeightLb: Double? { WeightTrend.latest(data.weighIns)?.weightLb }
    var trendWeightLb: Double? { WeightTrend.trendWeight(data.weighIns) }
    var latestBodyFat: WeighIn? { WeightTrend.latestBodyFat(data.weighIns) }

    // CLAUDE  Date 09/19/2026
    // One weigh-in per day: logging the same day again replaces it, because two readings from
    // one morning are the same measurement, and averaging them would quietly weight that day
    // double in the trend.
    func logWeighIn(weightLb: Double, bodyFatPct: Double? = nil, on dayKey: String = DayKey.key()) {
        guard weightLb > 0 else { return }
        data.weighIns.removeAll { $0.dayKey == dayKey }
        data.weighIns.append(WeighIn(dayKey: dayKey, weightLb: weightLb, bodyFatPct: bodyFatPct))
        data.weighIns.sort { $0.dayKey < $1.dayKey }
        save()
    }

    func deleteWeighIn(_ id: UUID) {
        data.weighIns.removeAll { $0.id == id }
        save()
    }

    /// The weight on a given day, for scoring a session that happened back then.
    func weight(on dayKey: String) -> Double? {
        data.weighIns.filter { $0.dayKey <= dayKey }.max { $0.dayKey < $1.dayKey }?.weightLb
            ?? latestWeightLb
    }

    // MARK: - The plan

    var plan: BodyPlan? { data.plan }

    // CLAUDE  Date 09/19/2026
    // Starting a plan writes the user's goals — the one moment this store reaches into
    // AppStore. Water is deliberately preserved: the plan owns calories and macros, nothing
    // else. Also ticks the Journal's setup checklist, since a calorie goal was just set.
    func startPlan(_ plan: BodyPlan, targets: PlanTargets, applyingTo store: AppStore) {
        data.plan = plan
        data.checkIns.removeAll()
        apply(targets, to: store)
        resyncReminder()
    }

    func apply(_ targets: PlanTargets, to store: AppStore) {
        var goals = store.nutritionGoals
        goals.calories = targets.calories
        goals.protein = targets.protein
        goals.carbs = targets.carbs
        goals.fat = targets.fat
        store.nutritionGoals = goals
        store.markNutritionSetup(\.calorieGoalSet)

        data.targetHistory.removeAll { $0.fromDayKey == DayKey.key() }
        data.targetHistory.append(targets.snapshot)
        data.targetHistory.sort { $0.fromDayKey < $1.fromDayKey }
        save()
    }

    /// Switching phase restarts the two-week warm-up — a new phase's first fortnight is water.
    func changePhase(to phase: PlanPhase, pace: Pace, targetBodyFatPct: Double?,
                     targetWeightLb: Double?, macroStyle: MacroStyle,
                     targets: PlanTargets, applyingTo store: AppStore) {
        guard var plan = data.plan else { return }
        plan.phase = phase
        plan.pace = pace
        plan.targetBodyFatPct = targetBodyFatPct
        plan.targetWeightLb = targetWeightLb
        plan.macroStyle = macroStyle
        plan.phaseStartedDayKey = DayKey.key()
        plan.lastCheckInDayKey = nil
        data.plan = plan
        apply(targets, to: store)
        resyncReminder()
    }

    // CLAUDE  Date 09/19/2026
    // Turning the reminder on asks for notification permission first — iOS only ever shows
    // that dialog once, so asking at the moment the user opted in is the one place it reads
    // as an answer to something they did. Side effect: resyncs the scheduled reminder.
    func updateCheckInSchedule(weekday: Int, remindersOn: Bool) {
        guard var plan = data.plan else { return }
        let turningOn = remindersOn && !plan.remindersOn
        plan.checkInWeekday = weekday
        plan.remindersOn = remindersOn
        data.plan = plan
        save()

        if turningOn {
            Task {
                if await WorkoutNotifications.authorizationStatus() == .notDetermined {
                    _ = await WorkoutNotifications.requestAuthorization()
                }
                resyncReminder()
            }
        } else {
            resyncReminder()
        }
    }

    /// Keeps the one-shot reminder pointed at the real next due date. Cheap and idempotent,
    /// so every path that can move that date just calls it.
    func resyncReminder() {
        BodyCheckInNotifications.resync(plan: data.plan)
    }

    /// Ending a plan leaves the goals exactly where they are — they're the user's now.
    func endPlan() {
        data.plan = nil
        save()
        BodyCheckInNotifications.cancel()
    }

    // MARK: - Check-ins

    var isCheckInDue: Bool {
        guard let plan = data.plan else { return false }
        return BodyCheckInEngine.isDue(plan: plan)
    }

    // CLAUDE  Date 09/19/2026
    // Builds the check-in's inputs in ONE pass over each log and hands the engine plain values.
    // nutritionDay(for:) re-filters the whole food log per call, so a fortnight of days would
    // walk it fourteen times; a view body doing that on every redraw would be worse still.
    func checkInInput(store: AppStore, adherence: BodyCheckInInput.Adherence? = nil,
                      today: String = DayKey.key()) -> BodyCheckInInput? {
        guard let plan = data.plan, let metrics = data.metrics else { return nil }

        let windowKeys = DayKey.window(endingOn: today, length: BodySafety.windowLength * 2)
        let keySet = Set(windowKeys)

        var loggedKcal: [String: Double] = [:]
        for entry in store.foodLog {
            let key = DayKey.key(for: entry.loggedAt)
            guard keySet.contains(key) else { continue }
            loggedKcal[key, default: 0] += entry.consumed.calories
        }

        var targetsByDay: [String: Double] = [:]
        for key in windowKeys {
            targetsByDay[key] = data.target(on: key)?.calories ?? store.nutritionGoals.calories
        }

        let goals = store.nutritionGoals
        return BodyCheckInInput(
            today: today,
            metrics: metrics,
            plan: plan,
            weighIns: data.weighIns,
            loggedKcal: loggedKcal,
            targetsByDay: targetsByDay,
            sessions: sessionSamples(store: store, days: keySet),
            currentTargets: PlanTargets(calories: goals.calories, protein: goals.protein,
                                        carbs: goals.carbs, fat: goals.fat),
            adherence: adherence)
    }

    func evaluateCheckIn(store: AppStore,
                         adherence: BodyCheckInInput.Adherence? = nil) -> BodyCheckInStatus? {
        guard let input = checkInInput(store: store, adherence: adherence) else { return nil }
        return BodyCheckInEngine.evaluate(input)
    }

    // CLAUDE  Date 09/19/2026
    // Recording a check-in always updates the learned model and the cadence, whether or not
    // the user took the new numbers: a declined proposal is still evidence about what their
    // body did. Only `accepted` writes the goals.
    func record(_ proposal: BodyCheckInProposal, accepted: Bool, store: AppStore) {
        guard var plan = data.plan else { return }
        plan.energy = proposal.updatedModel
        plan.lastCheckInDayKey = proposal.dayKey
        data.plan = plan
        data.checkIns.append(proposal.record(accepted: accepted))

        if accepted {
            apply(proposal.targets, to: store)
        } else {
            save()
        }
        resyncReminder()
    }

    // MARK: - Training burn

    // CLAUDE  Date 09/19/2026
    // Turns finished workouts into the samples the energy model reads: net calories, whether
    // the session is plausible (CardioPolicy / AchievementPolicy), and whether it was logged
    // live. A session with no usable bodyweight is skipped rather than guessed at.
    func sessionSamples(store: AppStore, days: Set<String>) -> [SessionSample] {
        let machines = Dictionary(uniqueKeysWithValues: store.exercises.map { ($0.id, $0.cardioMachine) })
        let ledgerSetIds = Set(store.activityLog.map(\.setId))
        var samples: [SessionSample] = []

        for workout in store.workouts where workout.isFinished {
            let dayKey = DayKey.key(for: workout.date)
            guard days.contains(dayKey), let weightLb = weight(on: dayKey) else { continue }

            var net = 0.0
            var liftingSets = 0
            var volume = 0.0
            var plausible = true
            var sawLiveTimestamp = false
            var sawLedgerEvent = false

            for logged in workout.exercises {
                for set in logged.sets where set.completedAt != nil || ledgerSetIds.contains(set.id) {
                    if set.completedAt != nil { sawLiveTimestamp = true }
                    if ledgerSetIds.contains(set.id) { sawLedgerEvent = true }

                    if let seconds = set.durationSeconds {
                        guard let machine = machines[logged.exerciseId] ?? nil else { continue }
                        if let kcal = WorkoutEnergy.cardioNetCalories(machine: machine,
                                                                     seconds: seconds,
                                                                     meters: set.distanceMeters,
                                                                     weightLb: weightLb) {
                            net += kcal
                        } else {
                            plausible = false
                        }
                        continue
                    }

                    liftingSets += 1
                    volume += Double(set.reps) * set.weight
                    if set.reps > AchievementPolicy.maxPlausibleReps
                        || set.weight > AchievementPolicy.maxPlausibleWeight {
                        plausible = false
                    }
                }
            }

            if volume > AchievementPolicy.dailyVolumeCap { plausible = false }

            if let minutes = WorkoutEnergy.liftingMinutes(elapsedSeconds: workout.elapsed,
                                                          completedSets: liftingSets) {
                net += WorkoutEnergy.liftingNetCalories(weightLb: weightLb, minutes: minutes)
            }
            guard net > 0 else { continue }

            samples.append(SessionSample(dayKey: dayKey, netKcal: net, isPlausible: plausible,
                                         isRealTime: sawLiveTimestamp || sawLedgerEvent))
        }
        return samples
    }

    /// Distinct training days over the last four weeks ÷ 4 — the wizard's pre-filled answer.
    func recentTrainingDaysPerWeek(store: AppStore) -> Int {
        let recent = Set(DayKey.window(endingOn: DayKey.key(), length: 28))
        let days = Set(store.workouts
            .filter { $0.isFinished }
            .map { DayKey.key(for: $0.date) }
            .filter { recent.contains($0) })
        return max(1, min(7, Int((Double(days.count) / 4).rounded())))
    }

    // MARK: - Debug

    #if DEBUG
    // CLAUDE  Date 09/19/2026
    // Back-dates the current phase so a seeded history is immediately checkable (DevToolsView).
    // Debug-only: shifting a phase start in a real plan would skip its two-week warm-up.
    func debugBackdatePhase(days: Int, weekday: Int, remindersOn: Bool) {
        guard var plan = data.plan else { return }
        plan.phaseStartedDayKey = DayKey.offset(DayKey.key(), byDays: -days) ?? plan.phaseStartedDayKey
        plan.lastCheckInDayKey = nil
        plan.checkInWeekday = weekday
        plan.remindersOn = remindersOn
        data.plan = plan
        save()
        resyncReminder()
    }
    #endif

    // MARK: - Erase

    // CLAUDE  Date 09/19/2026
    // Wipes the vault, its parked copy and the Keychain key. AccountDeletion must call this:
    // PersistenceService.removeAll only sweeps *.json, so the vault would otherwise survive a
    // "delete everything". Side effect: the plan's calorie goals stay in NutritionGoals — they
    // are the user's targets now, and silently resetting them would be its own surprise.
    func eraseAll() {
        BodyCheckInNotifications.cancel()
        vault.erase()
        data = BodyData()
        hasLoaded = true
        state = .ready
        requestedFlow = nil
    }
}
