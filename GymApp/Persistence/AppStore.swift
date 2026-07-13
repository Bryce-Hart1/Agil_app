import Foundation
import SwiftUI

/// The app's single source of truth. Views observe this; it owns the in-memory
/// data and persists every change to JSON via `PersistenceService`.
///
/// Persistence happens automatically: the `didSet` observers save whenever the
/// arrays change (including edits to nested sets/reps via bindings), so feature
/// code never has to remember to call save.
@MainActor
final class AppStore: ObservableObject {
    // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
    // Achievements no longer derive from editable workout/exercise data, so these
    // arrays only persist on change — credit now comes solely from the activity
    // ledger (see activityLog / completeSet), which is what blocks one-session
    // fabrication of badges.
    @Published var exercises: [Exercise] {
        didSet { persistence.save(exercises, to: Self.exercisesFile) }
    }
    @Published var workouts: [Workout] {
        didSet { persistence.save(workouts, to: Self.workoutsFile) }
    }
    // Claude  Date 06/14/2026
    // Append-only ledger of completed sets, stamped with real wall-clock time. The
    // sole source of truth for achievements: completing a set appends here, which
    // re-evaluates badges. Editing workout numbers afterward never touches it.
    @Published private(set) var activityLog: [ActivityEvent] {
        didSet {
            persistence.save(activityLog, to: Self.activityLogFile)
            evaluateAchievements()
        }
    }
    @Published var presets: [WorkoutPreset] { didSet { persistence.save(presets, to: Self.presetsFile) } }
    // Claude  Date 06/09/2026
    // Local user profile (display name). Persisted like everything else.
    @Published var profile: UserProfile { didSet { persistence.save(profile, to: Self.profileFile) } }
    // Claude  Date 06/16/2026
    // Nutrition tracking. Mirrors the workouts model: `foods` is the reusable food
    // library (seeded on first launch, like seedExercises; later augmented by the
    // Open Food Facts cache), `foodLog`/`waterLog` are the dated diary entries, and
    // `nutritionGoals` holds the daily targets the diary fills toward. Each auto-
    // saves on change via its own JSON file.
    @Published var foods: [FoodItem] { didSet { persistence.save(foods, to: Self.foodsFile) } }
    // Claude  Date 06/17/2026
    // Local barcode → product cache (see BarcodeCache). Separate from `foods` so it
    // can be evicted freely without touching the curated library; consulted by
    // CachedFoodService before any Open Food Facts barcode lookup. Persists on change.
    @Published private(set) var barcodeCache: BarcodeCache { didSet { persistence.save(barcodeCache, to: Self.barcodeCacheFile) } }
    // Claude  Date 07/11/2026
    // foodLog now also re-evaluates achievements on change (Days Tracked reads it),
    // mirroring the activityLog didSet pattern above.
    @Published var foodLog: [FoodEntry] {
        didSet {
            persistence.save(foodLog, to: Self.foodLogFile)
            evaluateAchievements()
        }
    }
    @Published var waterLog: [WaterEntry] { didSet { persistence.save(waterLog, to: Self.waterLogFile) } }
    @Published var nutritionGoals: NutritionGoals { didSet { persistence.save(nutritionGoals, to: Self.nutritionGoalsFile) } }
    // Claude  Date 07/12/2026
    // User-created nutrient focus goals (fiber/sugar/sodium floors/ceilings shown
    // as the diary's Focus card). Its own file rather than a NutritionGoals field
    // because it's an add/remove list, not a fixed set of daily targets.
    @Published var focusGoals: [NutrientFocusGoal] { didSet { persistence.save(focusGoals, to: Self.focusGoalsFile) } }
    // Claude  Date 06/13/2026
    // Achievement ids the user has unlocked. Sticky — once earned, never removed
    // (so e.g. a streak badge survives a missed week). Recomputed from history by
    // evaluateAchievements(); only AppStore mutates it.
    @Published private(set) var unlockedAchievementIDs: Set<String>
    // Claude  Date 06/13/2026
    // Achievements queued for the unlock celebration (transient — not persisted).
    // RootTabView shows the first one as a full-screen celebration.
    @Published var pendingCelebrations: [Achievement] = []
    // Claude  Date 06/15/2026
    // Strategist rank promotions queued for celebration (transient, like
    // pendingCelebrations). Shown after the badge celebrations drain.
    @Published var pendingPromotions: [StrategistRank] = []
    // Claude  Date 06/16/2026
    // The performance card to show on finishing a workout (transient). Displayed
    // BEFORE any badge/rank celebrations, so you see the session recap first.
    @Published var pendingWorkoutSummary: WorkoutSummary?
    // Claude  Date 07/12/2026
    // The Founders Edition cards to show in the unlock celebration (transient, empty
    // = none). Set by the alpha dev tool today; by the real IAP purchase-success flow
    // later. RootTabView renders FoundersUnlockOverlay from this. The grant of the
    // cards themselves lives in ThemeManager — this only drives the reveal animation.
    @Published var pendingFoundersUnlock: [CardStyle] = []
    // Claude  Date 06/16/2026
    // Alpha dev-only: a flat coin grant folded into totalCoinsEarned, so the dev
    // can top up the wallet to test shop/card purchases without grinding workouts.
    // Persisted like everything else; not part of the real economy.
    @Published private(set) var devBonusCoins: Int = 0 {
        didSet { persistence.save(devBonusCoins, to: Self.devCoinsFile) }
    }

    private let persistence: PersistenceService
    // Ids already celebrated, so we never re-show the same unlock. Persisted.
    private var celebratedAchievementIDs: Set<String> = []
    // Claude  Date 06/15/2026
    // Highest Strategist rank already celebrated, so a promotion fires only once.
    private var celebratedRank: StrategistRank = .initiate
    // Claude  Date 06/15/2026
    // Dev-only: ids currently queued as a *preview* (from the badge gallery), so
    // dismissing them doesn't mark the real badge as celebrated. Transient.
    private var previewCelebrationIDs: Set<String> = []

    private static let exercisesFile = "exercises.json"
    private static let workoutsFile = "workouts.json"
    private static let presetsFile = "presets.json"
    private static let profileFile = "profile.json"
    private static let achievementsFile = "achievements.json"
    private static let celebratedFile = "celebrated_achievements.json"
    private static let activityLogFile = "activity_log.json"
    private static let rankFile = "strategist_rank.json"
    // Claude  Date 06/16/2026 — nutrition data files.
    private static let foodsFile = "foods.json"
    private static let foodLogFile = "nutrition_log.json"
    private static let waterLogFile = "water_log.json"
    private static let nutritionGoalsFile = "nutrition_goals.json"
    // Claude  Date 07/12/2026 — nutrient focus goals (diary Focus card).
    private static let focusGoalsFile = "nutrient_focus_goals.json"
    // Claude  Date 06/16/2026 — alpha dev coin grant.
    private static let devCoinsFile = "dev_coins.json"
    // Claude  Date 06/17/2026 — barcode → product lookup cache.
    private static let barcodeCacheFile = "barcode_cache.json"

    init(persistence: PersistenceService = PersistenceService()) {
        self.persistence = persistence

        // Note: assignments in init do NOT trigger the didSet observers above,
        // so we save the seed explicitly below on first launch.
        let loadedExercises = persistence.load(Self.exercisesFile, default: [Exercise]())
        self.exercises = loadedExercises.isEmpty ? AppStore.seedExercises : loadedExercises
        self.workouts = persistence.load(Self.workoutsFile, default: [Workout]())
        self.presets = persistence.load(Self.presetsFile, default: [WorkoutPreset]())
        self.profile = persistence.load(Self.profileFile, default: UserProfile())
        self.unlockedAchievementIDs = persistence.load(Self.achievementsFile, default: Set<String>())
        self.celebratedAchievementIDs = persistence.load(Self.celebratedFile, default: Set<String>())
        self.celebratedRank = persistence.load(Self.rankFile, default: StrategistRank.initiate)
        self.activityLog = persistence.load(Self.activityLogFile, default: [ActivityEvent]())

        // Claude  Date 06/16/2026 last changed: 06/18/2026 by: Claude
        // Nutrition: the food library is no longer seeded with a built-in starter set —
        // it's now just the user's own foods (custom + barcode/Open Food Facts), shown
        // as "Recents" in the Foods tab. Drop any seed foods left in the file from a
        // previous build's starter set (persisted once below if any were removed). The
        // diary/water logs start empty; goals fall back to defaults.
        let loadedFoods = persistence.load(Self.foodsFile, default: [FoodItem]())
        self.foods = loadedFoods.filter { $0.source != .seed }
        self.foodLog = persistence.load(Self.foodLogFile, default: [FoodEntry]())
        self.waterLog = persistence.load(Self.waterLogFile, default: [WaterEntry]())
        self.nutritionGoals = persistence.load(Self.nutritionGoalsFile, default: NutritionGoals())
        self.focusGoals = persistence.load(Self.focusGoalsFile, default: [NutrientFocusGoal]())
        self.barcodeCache = persistence.load(Self.barcodeCacheFile, default: BarcodeCache())
        self.devBonusCoins = persistence.load(Self.devCoinsFile, default: 0)

        if loadedExercises.isEmpty {
            persistence.save(self.exercises, to: Self.exercisesFile)
        }
        // One-time cleanup: if we stripped any leftover seed foods above, persist it.
        if self.foods.count != loadedFoods.count {
            persistence.save(self.foods, to: Self.foodsFile)
        }

        // Claude  Date 06/13/2026
        // Catch up on achievements already satisfied by existing history (the
        // first-run backdating pass) — silently, so we don't pop a celebration for
        // every past unlock on launch. Live unlocks during the session DO celebrate.
        evaluateAchievements(announce: false)
    }

    // MARK: - Achievements

    // Claude  Date 06/13/2026
    // Add any achievements whose criteria are currently met to the unlocked set.
    // Never removes (unlocks are permanent); persists + publishes only on change.
    // When `announce`, newly-unlocked-and-not-yet-celebrated ones are queued for
    // the celebration overlay (lowest tier first, so it builds to the best).
    func evaluateAchievements(announce: Bool = true) {
        // Claude  Date 06/13/2026 last changed: 07/11/2026 by: Claude
        // Stats come from the activity ledger (completed sets, real timestamps),
        // NOT from editable workout numbers — that's the anti-cheat fix. Now also
        // feeds the food diary + calorie goal for the Days Tracked badges.
        let stats = ProfileStats(events: activityLog, foodLog: foodLog, nutritionGoals: nutritionGoals)
        var updated = unlockedAchievementIDs
        for achievement in Achievement.all where achievement.isUnlocked(stats) {
            updated.insert(achievement.id)
        }
        guard updated != unlockedAchievementIDs else { return }

        let newlyUnlocked = updated.subtracting(unlockedAchievementIDs)
        unlockedAchievementIDs = updated
        persistence.save(updated, to: Self.achievementsFile)

        if announce {
            queueCelebrations(Achievement.all.filter {
                newlyUnlocked.contains($0.id) && !celebratedAchievementIDs.contains($0.id)
            })
        } else {
            // Backdating pass: treat already-satisfied achievements as seen.
            celebratedAchievementIDs.formUnion(newlyUnlocked)
            persistence.save(celebratedAchievementIDs, to: Self.celebratedFile)
        }

        // Claude  Date 06/15/2026
        // Strategist promotions ride on the same evaluation: ranking up from the new
        // badge set queues a promotion (live unlocks announce; the backdating pass
        // updates celebratedRank silently so we don't pop one on launch).
        let newRank = strategistRank
        if newRank > celebratedRank {
            if announce {
                let queued = Set(pendingPromotions)
                let gained = StrategistRank.allCases.filter {
                    $0 > celebratedRank && $0 <= newRank && !queued.contains($0)
                }
                pendingPromotions.append(contentsOf: gained)
            }
            celebratedRank = newRank
            persistence.save(celebratedRank, to: Self.rankFile)
        }
    }

    // MARK: - Strategist rank

    // Claude  Date 06/15/2026
    // Overall rank derived from the unlocked badge set: a tier-weighted score
    // (StrategistScoring) mapped onto the chess ladder. Pure read-throughs.
    var strategistScore: Int { StrategistScoring.score(unlockedIDs: unlockedAchievementIDs) }
    var strategistRank: StrategistRank { StrategistScoring.rank(forScore: strategistScore) }
    var strategistProgress: Double { StrategistScoring.progress(forScore: strategistScore) }

    // Claude  Date 06/15/2026
    // Dismiss the current promotion: advance the queue (rank already persisted).
    func dismissCurrentPromotion() {
        guard !pendingPromotions.isEmpty else { return }
        pendingPromotions.removeFirst()
    }

    // Claude  Date 06/13/2026
    // Append achievements to the celebration queue (skipping any already queued),
    // ordered lowest tier → highest.
    private func queueCelebrations(_ achievements: [Achievement]) {
        let queuedIDs = Set(pendingCelebrations.map(\.id))
        let additions = achievements
            .filter { !queuedIDs.contains($0.id) }
            .sorted { AchievementShowcase.tierRank($0.tier) < AchievementShowcase.tierRank($1.tier) }
        guard !additions.isEmpty else { return }
        pendingCelebrations.append(contentsOf: additions)
    }

    // Claude  Date 06/13/2026
    // Dismiss the current celebration: mark it seen and advance the queue.
    func dismissCurrentCelebration() {
        guard let current = pendingCelebrations.first else { return }
        // A previewed celebration (dev gallery) leaves the real "celebrated" state
        // untouched, so earning the badge for real still pops later.
        if previewCelebrationIDs.remove(current.id) == nil {
            celebratedAchievementIDs.insert(current.id)
            persistence.save(celebratedAchievementIDs, to: Self.celebratedFile)
        }
        pendingCelebrations.removeFirst()
    }

    // Claude  Date 07/12/2026
    // Play the Founders Edition unlock celebration for every founders card. The
    // grant itself is idempotent and lives in ThemeManager; this only fires the
    // reveal overlay, so it can be replayed any time (the dev tool does exactly
    // that). Later, the IAP purchase-success handler will call this after granting.
    func celebrateFoundersUnlock() {
        pendingFoundersUnlock = CardStyle.all.filter { $0.isFounders }
    }

    // Dismiss the Founders unlock celebration.
    func dismissFoundersUnlock() {
        pendingFoundersUnlock = []
    }

    // Claude  Date 06/13/2026
    // Dev/alpha helper: re-show the celebration for every currently-unlocked
    // achievement (non-destructive — coins/unlocks are kept).
    func replayCelebrations() {
        celebratedAchievementIDs = []
        persistence.save(celebratedAchievementIDs, to: Self.celebratedFile)
        pendingCelebrations = []
        queueCelebrations(Achievement.all.filter { unlockedAchievementIDs.contains($0.id) })
    }

    // Claude  Date 06/15/2026
    // Dev/alpha helper: mark every achievement unlocked so the profile card, shelf,
    // achievements list, and Strategist rank all populate for review. Silent (marks
    // everything celebrated, sets the rank as seen) so it doesn't fire a wall of
    // overlays. Use "Reset achievements" to return to history-based progress.
    func unlockAllAchievements() {
        unlockedAchievementIDs = Set(Achievement.all.map(\.id))
        celebratedAchievementIDs = unlockedAchievementIDs
        celebratedRank = strategistRank
        pendingCelebrations = []
        pendingPromotions = []
        persistence.save(unlockedAchievementIDs, to: Self.achievementsFile)
        persistence.save(celebratedAchievementIDs, to: Self.celebratedFile)
        persistence.save(celebratedRank, to: Self.rankFile)
    }

    // Claude  Date 06/15/2026
    // Dev/alpha helper: play a single badge's unlock celebration on demand, without
    // earning it or affecting real progress (see previewCelebrationIDs).
    func previewCelebration(_ achievement: Achievement) {
        previewCelebrationIDs.insert(achievement.id)
        if !pendingCelebrations.contains(where: { $0.id == achievement.id }) {
            pendingCelebrations.append(achievement)
        }
    }

    // Claude  Date 06/15/2026
    // Dev/alpha helper: play a rank promotion overlay on demand. Non-persistent —
    // dismissing it leaves celebratedRank untouched.
    func previewPromotion(_ rank: StrategistRank) {
        if !pendingPromotions.contains(rank) { pendingPromotions.append(rank) }
    }

    // Claude  Date 06/13/2026
    // Dev/alpha helper: wipe all achievement progress, then re-earn from history
    // (this DOES celebrate the re-unlocks). Clears showcased pins too.
    func resetAchievements() {
        unlockedAchievementIDs = []
        celebratedAchievementIDs = []
        pendingCelebrations = []
        profile.showcasedAchievementIDs = []
        persistence.save(unlockedAchievementIDs, to: Self.achievementsFile)
        persistence.save(celebratedAchievementIDs, to: Self.celebratedFile)
        evaluateAchievements(announce: true)
    }

    // Claude  Date 06/13/2026 last changed: 06/16/2026 by: Claude
    // Lifetime coins earned = weekly-consistency coins + achievement rewards
    // (+ any alpha dev grant). This is the "earned" side of the wallet
    // (ThemeManager.balance subtracts spend).
    var totalCoinsEarned: Int {
        Coins.earned(from: workouts)
            + Coins.earnedFromAchievements(unlockedIDs: unlockedAchievementIDs)
            + devBonusCoins
    }

    // Claude  Date 06/16/2026
    // Alpha dev-only: top up / reset the wallet for testing the shop and card
    // purchases. grantDevCoins adds to the persisted grant; resetDevCoins clears it.
    func grantDevCoins(_ amount: Int) { devBonusCoins += amount }
    func resetDevCoins() { devBonusCoins = 0 }

    // Claude  Date 06/13/2026
    // Pin/unpin an achievement to the profile card's featured row. Returns false
    // (without changing anything) when trying to add beyond the 4-badge cap.
    @discardableResult
    func toggleShowcased(_ achievementID: String) -> Bool {
        var ids = profile.showcasedAchievementIDs
        if let index = ids.firstIndex(of: achievementID) {
            ids.remove(at: index)
        } else {
            guard ids.count < AchievementShowcase.maxFeatured else { return false }
            ids.append(achievementID)
        }
        profile.showcasedAchievementIDs = ids
        return true
    }

    // Claude  Date 07/01/2026
    // Reorder the featured badges (their left-to-right order on the card). Driven by the
    // Featured Badges picker's drag-to-reorder (`.onMove`); persists via profile's didSet.
    func moveShowcased(fromOffsets: IndexSet, toOffset: Int) {
        var ids = profile.showcasedAchievementIDs
        ids.move(fromOffsets: fromOffsets, toOffset: toOffset)
        profile.showcasedAchievementIDs = ids
    }

    // MARK: - Exercises

    // Claude  Date 06/09/2026 last changed: 06/14/2026 by: Claude
    // Create an exercise, returning it so callers (e.g. the picker) can select it.
    @discardableResult
    func addExercise(name: String, region: MuscleRegion = .other, category: String,
                     isUnilateral: Bool = false, liftType: LiftType? = nil,
                     primaryMover: String = "", quality: LiftQuality? = nil) -> Exercise {
        let exercise = Exercise(name: name, region: region, category: category,
                                isUnilateral: isUnilateral, liftType: liftType,
                                primaryMover: primaryMover, quality: quality)
        exercises.append(exercise)
        return exercise
    }

    func deleteExercises(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }

    // Claude  Date 06/18/2026
    // Replace an exercise in the library (matched by id) after editing its details —
    // e.g. from the pencil in the workout editor's exercise header. Persists via the
    // exercises didSet; workouts reference exercises by id, so their labels update live.
    func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
        }
    }

    // Claude  Date 06/14/2026
    // Remove a specific exercise by identity — used by the region-sectioned list,
    // where swipe offsets are relative to a section rather than the whole array.
    func deleteExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
    }

    // Claude  Date 06/14/2026
    // The library grouped for browsing: body region (in MuscleRegion order) → its
    // exercises clustered by muscle sub-group (`category`) then name. Empty regions
    // are dropped. Pass a pre-filtered list (e.g. search results) to group those.
    func exercisesByRegion(_ list: [Exercise]? = nil) -> [(region: MuscleRegion, exercises: [Exercise])] {
        let source = list ?? exercises
        return MuscleRegion.allCases.compactMap { region in
            let items = source
                .filter { $0.region == region }
                .sorted { ($0.category, $0.name) < ($1.category, $1.name) }
            return items.isEmpty ? nil : (region, items)
        }
    }

    // Claude  Date 07/09/2026
    // Options for the cascading muscle pickers in the exercise editor, both DERIVED from
    // the current library so they stay self-maintaining (no hand-kept table): the distinct
    // muscle sub-groups within a region, and the distinct primary movers within one of
    // those sub-groups. The "Other" catch-all is excluded from the group list — it only
    // exists as a category under Region = .other.
    func categories(in region: MuscleRegion) -> [String] {
        let cats = exercises.filter { $0.region == region }.map(\.category)
        return Array(Set(cats)).filter { $0 != "Other" }.sorted()
    }

    func movers(in category: String, region: MuscleRegion) -> [String] {
        let m = exercises
            .filter { $0.region == region && $0.category == category && !$0.primaryMover.isEmpty }
            .map(\.primaryMover)
        return Array(Set(m)).sorted()
    }

    func exercise(for id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }

    // MARK: - Workouts

    func addWorkout(_ workout: Workout) {
        workouts.append(workout)
    }

    func deleteWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
    }

    // Claude  Date 06/16/2026
    // The in-progress (unfinished) workout, if any. By product decision there's only
    // one active workout at a time; if several somehow exist, the most recent by date.
    // Drives the global mini-bar and the "In progress" row.
    var activeWorkout: Workout? {
        workouts.filter { !$0.isFinished }.max { $0.date < $1.date }
    }

    // Claude  Date 06/16/2026
    // Mark a workout complete — the ONLY moment its sets earn credit. Checking sets
    // during the session just stamps `completedAt` locally (no ledger writes), so an
    // abandoned/never-finished workout never counts. Finishing appends a ledger event
    // for each checked-off set (stamped with that set's real completion time, idempotent
    // by setId), which re-evaluates achievements via activityLog's didSet — producing
    // the badge "burst" on completion. The big-3 `liftType` is frozen into each event.
    func finishWorkout(id: UUID) {
        guard let index = workouts.firstIndex(where: { $0.id == id }),
              !workouts[index].isFinished else { return }

        var newEvents: [ActivityEvent] = []
        for logged in workouts[index].exercises {
            // Claude  Date 07/11/2026
            // effectiveLiftType (not the raw liftType tag) so any Arms/Biceps exercise
            // credits the curl badge automatically, not just an explicitly tagged one.
            let liftType = exercise(for: logged.exerciseId)?.effectiveLiftType
            for set in logged.sets where set.completedAt != nil {
                guard !activityLog.contains(where: { $0.setId == set.id }) else { continue }
                newEvents.append(ActivityEvent(
                    setId: set.id, exerciseId: logged.exerciseId,
                    reps: set.reps, weight: set.weight,
                    loggedAt: set.completedAt ?? Date(), liftType: liftType))
            }
        }
        if !newEvents.isEmpty { activityLog.append(contentsOf: newEvents) }
        // Claude  Date 07/01/2026
        // Stamp the real finish time so the performance card's elapsed span
        // (startedAt → finishedAt) is the true wall-clock duration — including any time
        // the app spent backgrounded or the phone was locked.
        workouts[index].finishedAt = Date()
        workouts[index].isFinished = true

        // Claude  Date 06/16/2026
        // Queue the performance card from the now-finished workout. RootTabView shows
        // it first; dismissing it lets the badge celebrations (queued above) play.
        pendingWorkoutSummary = WorkoutSummary(workout: workouts[index], exercises: exercises)
    }

    // Claude  Date 06/16/2026
    // Dismiss the performance card (after the user taps to continue).
    func dismissWorkoutSummary() {
        pendingWorkoutSummary = nil
    }

    /// A two-way binding to a workout identified by `id`, resilient to the array
    /// being reordered. Editing through this binding mutates the `workouts`
    /// array, which triggers `didSet` and persists the change.
    func binding(for id: UUID) -> Binding<Workout>? {
        guard workouts.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.workouts.first(where: { $0.id == id }) ?? Workout() },
            set: { newValue in
                if let index = self.workouts.firstIndex(where: { $0.id == id }) {
                    self.workouts[index] = newValue
                }
            }
        )
    }

    // MARK: - Rep ranges

    // Claude  Date 06/18/2026
    // Preferred target rep range for an exercise, learned from its own history: the
    // most-used target range across the most recent 3 logged instances (ties broken by
    // recency). Example: the last three were 4–6, 6–8, 4–6 → 4–6. nil if it's never been
    // logged with a range yet. Pure read over `workouts`, all on-device.
    func preferredRepRange(for exerciseId: UUID) -> RepRange? {
        let recent = workouts
            .sorted { $0.date > $1.date }
            .flatMap { $0.exercises.filter { $0.exerciseId == exerciseId } }
            .compactMap { $0.targetRepRange }
            .prefix(3)
        guard !recent.isEmpty else { return nil }

        var counts: [RepRange: Int] = [:]
        recent.forEach { counts[$0, default: 0] += 1 }
        // Highest count wins; on a tie keep the most recent (lowest index).
        return recent.enumerated().max {
            let c0 = counts[$0.element] ?? 0, c1 = counts[$1.element] ?? 0
            return c0 != c1 ? c0 < c1 : $0.offset > $1.offset
        }?.element
    }

    // Claude  Date 06/18/2026
    // The range to pre-fill when (re)queuing an exercise so every lift always arrives
    // with one: an explicit range (e.g. carried from a preset) wins, else the
    // history-preferred range, else a sensible 8–12 default.
    func defaultRepRange(for exerciseId: UUID, explicit: RepRange? = nil) -> RepRange {
        explicit ?? preferredRepRange(for: exerciseId) ?? RepRange(min: 8, max: 12)
    }

    // MARK: - Nutrition

    // Claude  Date 06/16/2026
    // Add a food to the library, returning it so callers (e.g. the picker) can log
    // it immediately after creating it. Mirrors addExercise.
    @discardableResult
    func addFood(_ food: FoodItem) -> FoodItem {
        foods.append(food)
        return food
    }

    func deleteFood(_ food: FoodItem) {
        foods.removeAll { $0.id == food.id }
    }

    // Claude  Date 06/16/2026
    // Persist a food fetched from Open Food Facts into the local library so it works
    // offline next time. Deduped by barcode: if we already cached this product,
    // return the existing copy (don't append a duplicate) so logging links to one
    // stable library entry. Foods without a barcode are always added.
    @discardableResult
    func cacheFood(_ food: FoodItem) -> FoodItem {
        if let code = food.barcode, !code.isEmpty,
           let existing = foods.first(where: { $0.barcode == code }) {
            return existing
        }
        foods.append(food)
        return food
    }

    // Claude  Date 06/17/2026
    // Barcode-cache hooks used by CachedFoodService (networking stays out of here —
    // these are purely the local read/write side of the cache).
    //
    // Read: return the cached product for a barcode, or nil. We guard on `contains`
    // so a miss doesn't fire the mutating `lookup` (which would persist for nothing);
    // a hit touches recency (LRU) and persists via didSet.
    func cachedFood(forBarcode code: String) -> FoodItem? {
        guard barcodeCache.contains(code) else { return nil }
        return barcodeCache.lookup(code)
    }

    // Write: remember a freshly-fetched product (insert + LRU evict), persisting.
    func rememberScannedFood(_ food: FoodItem, forBarcode code: String) {
        barcodeCache.insert(food, forBarcode: code)
    }

    // Claude  Date 06/16/2026
    // Log a library food into the diary at `servings` of its reference serving,
    // under `meal`, on the calendar day `date`. The entry SNAPSHOTS the food's
    // name + per-serving nutrients (see FoodEntry.from), so later edits to the
    // library never rewrite this diary record. `date` is stamped with the current
    // time-of-day so entries on the selected day stay chronologically ordered.
    func logFood(_ food: FoodItem, servings: Double, meal: MealType, on date: Date = Date()) {
        foodLog.append(FoodEntry.from(food, servings: servings, mealType: meal,
                                      loggedAt: Self.stamp(date)))
    }

    func deleteFoodEntry(id: UUID) {
        foodLog.removeAll { $0.id == id }
    }

    // Claude  Date 06/16/2026
    // Replace a logged entry in place (matched by id), e.g. after correcting its
    // servings or meal in the editor. The nutrient snapshot is preserved by the
    // caller — this just writes the edited entry back, which persists via didSet.
    func updateFoodEntry(_ entry: FoodEntry) {
        if let index = foodLog.firstIndex(where: { $0.id == entry.id }) {
            foodLog[index] = entry
        }
    }

    // Claude  Date 06/16/2026
    // Add water (canonical milliliters) toward the day's goal, stamped onto `date`.
    func logWater(milliliters: Double, on date: Date = Date()) {
        waterLog.append(WaterEntry(milliliters: milliliters, loggedAt: Self.stamp(date)))
    }

    func deleteWaterEntry(id: UUID) {
        waterLog.removeAll { $0.id == id }
    }

    // Claude  Date 06/16/2026
    // The derived diary view for one calendar day (totals + per-meal grouping).
    func nutritionDay(for date: Date) -> NutritionDay {
        NutritionDay(date: date, foodLog: foodLog, waterLog: waterLog)
    }

    // MARK: - Nutrient focus goals

    // Claude  Date 07/12/2026
    // Focus-goal list mutations (didSet persists). One goal per nutrient, so
    // addFocusGoal is a no-op if that nutrient is already tracked; in-place edits
    // flow through ForEach($focusGoals) bindings in FocusGoalsView.
    func addFocusGoal(for nutrient: NutrientFocusGoal.Nutrient) {
        guard !focusGoals.contains(where: { $0.nutrient == nutrient }) else { return }
        focusGoals.append(NutrientFocusGoal(nutrient: nutrient))
    }

    func deleteFocusGoals(at offsets: IndexSet) {
        focusGoals.remove(atOffsets: offsets)
    }

    // Claude  Date 06/16/2026
    // Logging onto the diary's selected day: keep "now" for today, otherwise pin the
    // chosen day at the current time-of-day so back-dated entries sort sensibly and
    // never land on the wrong calendar day.
    private static func stamp(_ date: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return Date() }
        let t = cal.dateComponents([.hour, .minute, .second], from: Date())
        return cal.date(bySettingHour: t.hour ?? 12, minute: t.minute ?? 0,
                        second: t.second ?? 0, of: date) ?? date
    }

    // MARK: - Presets

    func addPreset(_ preset: WorkoutPreset) {
        presets.append(preset)
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
    }

    func deletePresets(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
    }

    /// A reorder-safe two-way binding to a preset, mirroring `binding(for:)`.
    func presetBinding(for id: UUID) -> Binding<WorkoutPreset>? {
        guard presets.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.presets.first(where: { $0.id == id }) ?? WorkoutPreset() },
            set: { newValue in
                if let index = self.presets.firstIndex(where: { $0.id == id }) {
                    self.presets[index] = newValue
                }
            }
        )
    }

    // MARK: - Adaptive presets

    // Claude  Date 07/01/2026
    // The weight jump for an adaptive exercise when it progresses. A per-exercise
    // override (set in the preset editor) always wins; otherwise a smart default: 10 lb
    // for lower-body work and the deadlift (big compounds add weight in bigger jumps),
    // 5 lb for everything else. Equipment isn't modeled, so region/liftType stand in.
    func smartIncrement(for exerciseId: UUID, override: Double? = nil) -> Double {
        if let override { return override }
        let exercise = exercise(for: exerciseId)
        if exercise?.region == .legs || exercise?.liftType == .deadlift { return 10 }
        return 5
    }

    // Claude  Date 07/01/2026
    // Compute the adaptive (double-progression) weight suggestion for an exercise from
    // its own history, all on-device over `workouts`:
    //   • Gather finished sessions that logged a COMPLETED set for this exercise, newest first.
    //   • A session's "working weight" = the heaviest completed set's weight; its "working
    //     sets" = the completed sets at that weight (warmups aren't modeled, so top-weight
    //     sets stand in for working sets; unilateral sides are pooled together in v1).
    //   • Increase: every working set in the latest session hit the top of the range → +increment.
    //   • Deload: the latest TWO sessions each had all working sets BELOW the bottom → −increment (≥ 0).
    //   • Otherwise hold at the last working weight.
    // Returns nil when there's no completed history yet (nothing to base a suggestion on).
    func adaptiveSuggestion(for exerciseId: UUID, range: RepRange,
                            increment: Double) -> AdaptiveSuggestion? {
        let low = Swift.min(range.min, range.max)
        let high = Swift.max(range.min, range.max)

        // Per finished session (newest first): the working weight and the reps of its
        // working sets (completed sets performed at that top weight).
        let sessions: [(weight: Double, reps: [Int])] = workouts
            .filter { $0.isFinished }
            .sorted { $0.date > $1.date }
            .compactMap { workout in
                let completed = workout.exercises
                    .filter { $0.exerciseId == exerciseId }
                    .flatMap { $0.sets }
                    .filter { $0.completedAt != nil }
                guard let topWeight = completed.map(\.weight).max() else { return nil }
                let reps = completed.filter { $0.weight == topWeight }.map(\.reps)
                return (topWeight, reps)
            }

        guard let latest = sessions.first else { return nil }

        // Increase: all of the latest session's working sets reached the top of the range.
        if !latest.reps.isEmpty && latest.reps.allSatisfy({ $0 >= high }) {
            return AdaptiveSuggestion(weight: latest.weight + increment,
                                      deltaFromLast: increment, outcome: .increased)
        }

        // Deload: the two most recent sessions each fell entirely below the bottom.
        let missedBottom: ((weight: Double, reps: [Int])) -> Bool = { session in
            !session.reps.isEmpty && session.reps.allSatisfy { $0 < low }
        }
        if sessions.count >= 2, sessions.prefix(2).allSatisfy(missedBottom) {
            return AdaptiveSuggestion(weight: Swift.max(0, latest.weight - increment),
                                      deltaFromLast: -increment, outcome: .deloaded)
        }

        // Hold at last session's working weight.
        return AdaptiveSuggestion(weight: latest.weight, deltaFromLast: 0, outcome: .held)
    }

    /// Looks up a preset by id (nil when it no longer exists).
    // Claude  Date 07/13/2026
    // Mirror of exercise(for:) — used by the workout editor to resolve a workout's
    // source preset (for the "Override Preset" affordance and its name).
    func preset(for id: UUID) -> WorkoutPreset? {
        presets.first { $0.id == id }
    }

    /// Builds a fresh workout from a preset: each preset item becomes a logged
    /// exercise carrying the target rep range, pre-filled with the preset's planned
    /// number of (empty, unchecked) sets so you're not tapping "Add Set" repeatedly.
    // Claude  Date 06/18/2026 last changed: 07/13/2026 by: Claude
    // Backfill the rep range so every queued lift has one: the preset's own range wins,
    // else the history-preferred range, else the 8–12 default (see defaultRepRange). For
    // an ADAPTIVE preset, also attach a per-exercise weight suggestion (adaptiveSuggestion),
    // computed against that resolved rep range and the exercise's smart increment.
    // (07/13) Tag the workout with its source preset and pre-fill item.targetSets sets.
    func workout(from preset: WorkoutPreset) -> Workout {
        Workout(exercises: preset.items.map { item in
            let range = defaultRepRange(for: item.exerciseId, explicit: item.targetRepRange)
            let adaptive = preset.isAdaptive
                ? adaptiveSuggestion(for: item.exerciseId, range: range,
                                     increment: smartIncrement(for: item.exerciseId,
                                                               override: item.weightIncrement))
                : nil
            return LoggedExercise(exerciseId: item.exerciseId, targetRepRange: range,
                                  note: item.note, restSeconds: item.restSeconds,
                                  sets: initialSets(for: item, range: range, adaptive: adaptive),
                                  adaptive: adaptive)
        }, presetID: preset.id)
    }

    // Claude  Date 07/13/2026
    // The pre-filled sets for a preset item when a workout is started: item.targetSets
    // logical sets (nil / 0 → none, preserving the old "empty" behavior). Each seeds its
    // reps from the low end of the target range (else 8) and its weight from the adaptive
    // suggestion (else 0) — the same defaults "Add Set" uses. Nothing is checked off, so
    // these count toward nothing until the user completes them. Unilateral exercises get
    // a matched Left+Right pair per logical set (mirroring ExerciseLogSection.addSet).
    private func initialSets(for item: PresetItem, range: RepRange,
                             adaptive: AdaptiveSuggestion?) -> [ExerciseSet] {
        guard let count = item.targetSets, count > 0 else { return [] }
        let low = Swift.min(range.min, range.max)
        let reps = low > 0 ? low : 8
        let weight = adaptive?.weight ?? 0
        let unilateral = exercise(for: item.exerciseId)?.isUnilateral ?? false
        return (0..<count).flatMap { _ -> [ExerciseSet] in
            unilateral
                ? [ExerciseSet(reps: reps, weight: weight, side: .left),
                   ExerciseSet(reps: reps, weight: weight, side: .right)]
                : [ExerciseSet(reps: reps, weight: weight)]
        }
    }

    // Claude  Date 07/13/2026
    // The logical set count of a logged exercise, for capturing into a preset item's
    // targetSets. Unilateral exercises store Left/Right as two ExerciseSets per logical
    // set, so halve them. No sets logged → nil (don't pin a count).
    private func logicalSetCount(of logged: LoggedExercise) -> Int? {
        let count = logged.sets.count
        guard count > 0 else { return nil }
        let unilateral = exercise(for: logged.exerciseId)?.isUnilateral ?? false
        return unilateral ? count / 2 : count
    }

    /// Builds a preset from a workout: each logged exercise becomes a preset item
    /// carrying its rep range, note, and how many sets were logged (sets themselves are
    /// dropped — presets hold no sets, just the planned count).
    // Claude  Date 06/18/2026 last changed: 07/13/2026 by: Claude
    // (07/13) Capture the logged set count into targetSets so a preset saved from a
    // workout remembers how many sets to pre-fill next time.
    func makePreset(from workout: Workout, name: String) -> WorkoutPreset {
        WorkoutPreset(name: name, items: workout.exercises.map {
            PresetItem(exerciseId: $0.exerciseId, targetRepRange: $0.targetRepRange,
                       note: $0.note, restSeconds: $0.restSeconds,
                       targetSets: logicalSetCount(of: $0))
        })
    }

    // Claude  Date 07/13/2026
    // Overwrite an existing preset from a workout ("Override Preset"): rebuild its items
    // to match the workout's current exercises — which lifts are kept vs removed (and
    // their order), each lift's rep range, note, rest, and logged set count. The preset's
    // own identity (id, name, icon, adaptive toggle) is left untouched, and each surviving
    // item keeps its id and adaptive weight-step override (a preset-only field the workout
    // doesn't carry) by matching on exerciseId. No-op if the preset no longer exists.
    func updatePreset(id: UUID, from workout: Workout) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let existing = presets[index].items
        presets[index].items = workout.exercises.map { logged in
            let prior = existing.first { $0.exerciseId == logged.exerciseId }
            return PresetItem(id: prior?.id ?? UUID(),
                              exerciseId: logged.exerciseId,
                              targetRepRange: logged.targetRepRange,
                              note: logged.note,
                              restSeconds: logged.restSeconds,
                              weightIncrement: prior?.weightIncrement,
                              targetSets: logicalSetCount(of: logged))
        }
    }
}

// MARK: - Seed data

extension AppStore {
    // Curated, science-based lift library (from lift-list-condensed.md) pre-loaded
    // on first launch. `category` is the training sub-group (drives the muscle-group
    // chart / top-muscle stat); `primaryMover` names the muscle the lift drives;
    // `quality` is the Optimal/Classic tag. Only the true powerlifting big-3 carry a
    // `liftType` (squat/bench/deadlift) so the lift achievements stay exact.
    static let seedExercises: [Exercise] = [
        // MARK: Legs — Quads
        Exercise(name: "Hack Squat", region: .legs, category: "Quads", primaryMover: "Quadriceps", quality: .optimal),
        Exercise(name: "Barbell Back Squat", region: .legs, category: "Quads", liftType: .squat, primaryMover: "Quadriceps", quality: .classic),
        Exercise(name: "Leg Press", region: .legs, category: "Quads", primaryMover: "Quadriceps", quality: .optimal),
        Exercise(name: "Leg Extension", region: .legs, category: "Quads", primaryMover: "Quadriceps", quality: .optimal),
        Exercise(name: "Bulgarian Split Squat", region: .legs, category: "Quads", isUnilateral: true, primaryMover: "Quadriceps", quality: .optimal),

        // MARK: Legs — Hamstrings
        Exercise(name: "Seated Leg Curl", region: .legs, category: "Hamstrings", primaryMover: "Hamstrings", quality: .optimal),
        Exercise(name: "Romanian Deadlift", region: .legs, category: "Hamstrings", primaryMover: "Hamstrings", quality: .classic),
        Exercise(name: "Lying Leg Curl", region: .legs, category: "Hamstrings", primaryMover: "Hamstrings", quality: .classic),
        Exercise(name: "Stiff-Leg Deadlift", region: .legs, category: "Hamstrings", primaryMover: "Hamstrings", quality: .optimal),

        // MARK: Legs — Glutes
        Exercise(name: "Hip Thrust", region: .legs, category: "Glutes", primaryMover: "Gluteus Maximus", quality: .classic),
        Exercise(name: "Walking Lunge", region: .legs, category: "Glutes", isUnilateral: true, primaryMover: "Gluteus Maximus", quality: .optimal),
        Exercise(name: "Cable Kickback", region: .legs, category: "Glutes", isUnilateral: true, primaryMover: "Gluteus Maximus", quality: .optimal),

        // MARK: Legs — Calves
        Exercise(name: "Standing Calf Raise", region: .legs, category: "Calves", primaryMover: "Gastrocnemius", quality: .optimal),
        Exercise(name: "Seated Calf Raise", region: .legs, category: "Calves", primaryMover: "Soleus", quality: .optimal),

        // MARK: Chest
        Exercise(name: "Incline Barbell Press", region: .chest, category: "Chest", primaryMover: "Pectorals (Upper)", quality: .optimal),
        Exercise(name: "Flat Barbell Bench Press", region: .chest, category: "Chest", liftType: .bench, primaryMover: "Pectorals", quality: .classic),
        Exercise(name: "Deep Stretch Cable Fly", region: .chest, category: "Chest", primaryMover: "Pectorals", quality: .optimal),
        Exercise(name: "Weighted Dip", region: .chest, category: "Chest", primaryMover: "Pectorals (Lower)", quality: .classic),

        // MARK: Back — Lats
        Exercise(name: "Pull-Up", region: .back, category: "Lats", primaryMover: "Latissimus Dorsi", quality: .classic),
        Exercise(name: "Close-Grip Lat Pulldown", region: .back, category: "Lats", primaryMover: "Latissimus Dorsi", quality: .optimal),
        Exercise(name: "Single-Arm Cable Pullover", region: .back, category: "Lats", isUnilateral: true, primaryMover: "Latissimus Dorsi", quality: .optimal),

        // MARK: Back — Mid-Back / Traps
        Exercise(name: "Chest-Supported Row", region: .back, category: "Mid-Back", primaryMover: "Rhomboids / Mid Traps", quality: .optimal),
        Exercise(name: "T-Bar Row", region: .back, category: "Mid-Back", primaryMover: "Mid-Back", quality: .classic),
        Exercise(name: "Seated Cable Row", region: .back, category: "Mid-Back", primaryMover: "Mid-Back", quality: .classic),
        Exercise(name: "Barbell Shrug", region: .back, category: "Traps", primaryMover: "Upper Trapezius", quality: .optimal),

        // MARK: Back — Lower Back
        Exercise(name: "Conventional Deadlift", region: .back, category: "Lower Back", liftType: .deadlift, primaryMover: "Spinal Erectors", quality: .classic),
        Exercise(name: "Back Extension", region: .back, category: "Lower Back", primaryMover: "Spinal Erectors", quality: .optimal),

        // MARK: Shoulders — Side Delts
        Exercise(name: "Cable Lateral Raise", region: .shoulders, category: "Side Delts", primaryMover: "Lateral Deltoid", quality: .optimal),
        Exercise(name: "Dumbbell Lateral Raise", region: .shoulders, category: "Side Delts", primaryMover: "Lateral Deltoid", quality: .classic),
        Exercise(name: "Overhead Press", region: .shoulders, category: "Side Delts", primaryMover: "Anterior / Lateral Deltoid", quality: .classic),

        // MARK: Shoulders — Rear Delts
        Exercise(name: "Reverse Pec Deck", region: .shoulders, category: "Rear Delts", primaryMover: "Posterior Deltoid", quality: .optimal),
        Exercise(name: "Face Pull", region: .shoulders, category: "Rear Delts", primaryMover: "Posterior Deltoid", quality: .optimal),

        // MARK: Arms — Biceps
        // Claude  Date 07/11/2026 last changed: 07/11/2026 by: Claude
        // A standard curl for the library. No explicit liftType tag needed — every
        // exercise below counts toward the Bicep Curl badge automatically via
        // Exercise.effectiveLiftType (region == .arms && category == "Biceps").
        Exercise(name: "Barbell Curl", region: .arms, category: "Biceps", primaryMover: "Biceps Brachii", quality: .classic),
        Exercise(name: "Incline Dumbbell Curl", region: .arms, category: "Biceps", primaryMover: "Biceps Brachii", quality: .optimal),
        Exercise(name: "Cable Curl", region: .arms, category: "Biceps", primaryMover: "Biceps Brachii", quality: .optimal),
        Exercise(name: "EZ-Bar Curl", region: .arms, category: "Biceps", primaryMover: "Biceps Brachii", quality: .classic),
        Exercise(name: "Hammer Curl", region: .arms, category: "Biceps", primaryMover: "Brachialis / Brachioradialis", quality: .optimal),

        // MARK: Arms — Triceps
        Exercise(name: "Overhead Cable Extension", region: .arms, category: "Triceps", primaryMover: "Triceps (Long Head)", quality: .optimal),
        Exercise(name: "Close-Grip Bench Press", region: .arms, category: "Triceps", primaryMover: "Triceps", quality: .classic),
        Exercise(name: "Triceps Pushdown", region: .arms, category: "Triceps", primaryMover: "Triceps (Lateral Head)", quality: .classic),
        Exercise(name: "Skull Crusher", region: .arms, category: "Triceps", primaryMover: "Triceps (Long Head)", quality: .optimal),

        // MARK: Arms — Forearms
        Exercise(name: "Wrist Curl", region: .arms, category: "Forearms", primaryMover: "Wrist Flexors", quality: .optimal),
        Exercise(name: "Reverse Wrist Curl", region: .arms, category: "Forearms", primaryMover: "Wrist Extensors", quality: .optimal),
        Exercise(name: "Farmer's Carry", region: .arms, category: "Forearms", primaryMover: "Grip / Forearms", quality: .classic),

        // MARK: Core
        Exercise(name: "Weighted Cable Crunch", region: .core, category: "Core", primaryMover: "Rectus Abdominis", quality: .optimal),
        Exercise(name: "Hanging Leg Raise", region: .core, category: "Core", primaryMover: "Rectus Abdominis (Lower)", quality: .optimal),
        Exercise(name: "Pallof Press", region: .core, category: "Core", isUnilateral: true, primaryMover: "Obliques", quality: .optimal),
        Exercise(name: "Plank", region: .core, category: "Core", primaryMover: "Transverse Abdominis", quality: .classic),
    ]
}
