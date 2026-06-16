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
    @Published var foodLog: [FoodEntry] { didSet { persistence.save(foodLog, to: Self.foodLogFile) } }
    @Published var waterLog: [WaterEntry] { didSet { persistence.save(waterLog, to: Self.waterLogFile) } }
    @Published var nutritionGoals: NutritionGoals { didSet { persistence.save(nutritionGoals, to: Self.nutritionGoalsFile) } }
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

    private let persistence: PersistenceService
    // Ids already celebrated, so we never re-show the same unlock. Persisted.
    private var celebratedAchievementIDs: Set<String> = []
    // Claude  Date 06/15/2026
    // Highest Strategist rank already celebrated, so a promotion fires only once.
    private var celebratedRank: StrategistRank = .pawn
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
        self.celebratedRank = persistence.load(Self.rankFile, default: StrategistRank.pawn)
        self.activityLog = persistence.load(Self.activityLogFile, default: [ActivityEvent]())

        // Claude  Date 06/16/2026
        // Nutrition: seed the food library on first launch (same pattern as
        // exercises). The diary/water logs start empty; goals fall back to defaults.
        let loadedFoods = persistence.load(Self.foodsFile, default: [FoodItem]())
        self.foods = loadedFoods.isEmpty ? AppStore.seedFoods : loadedFoods
        self.foodLog = persistence.load(Self.foodLogFile, default: [FoodEntry]())
        self.waterLog = persistence.load(Self.waterLogFile, default: [WaterEntry]())
        self.nutritionGoals = persistence.load(Self.nutritionGoalsFile, default: NutritionGoals())

        if loadedExercises.isEmpty {
            persistence.save(self.exercises, to: Self.exercisesFile)
        }
        if loadedFoods.isEmpty {
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
        // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
        // Stats come from the activity ledger (completed sets, real timestamps),
        // NOT from editable workout numbers — that's the anti-cheat fix.
        let stats = ProfileStats(events: activityLog)
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

    // Claude  Date 06/13/2026
    // Lifetime coins earned = weekly-consistency coins + achievement rewards.
    // This is the "earned" side of the wallet (ThemeManager.balance subtracts spend).
    var totalCoinsEarned: Int {
        Coins.earned(from: workouts) + Coins.earnedFromAchievements(unlockedIDs: unlockedAchievementIDs)
    }

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

    // Claude  Date 06/14/2026
    // Record a completed set in the append-only activity ledger. Called from the
    // explicit "complete set" tap with the set's real values. Idempotent by
    // `setId`, so re-completing the same set never double-counts. The big-3
    // `liftType` is resolved here (the store owns the exercise library) and frozen
    // into the event, so a later rename can't change earned credit. Appending
    // re-evaluates achievements via activityLog's didSet.
    func completeSet(setId: UUID, exerciseId: UUID, reps: Int, weight: Double) {
        guard !activityLog.contains(where: { $0.setId == setId }) else { return }
        let liftType = exercise(for: exerciseId)?.liftType
        activityLog.append(ActivityEvent(
            setId: setId, exerciseId: exerciseId,
            reps: reps, weight: weight, liftType: liftType))
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

    /// Builds a fresh workout from a preset: each preset item becomes a logged
    /// exercise carrying the target rep range, with no sets yet (you fill those in).
    func workout(from preset: WorkoutPreset) -> Workout {
        Workout(exercises: preset.items.map {
            LoggedExercise(exerciseId: $0.exerciseId, targetRepRange: $0.targetRepRange,
                           note: $0.note, restSeconds: $0.restSeconds)
        })
    }

    /// Builds a preset from a workout: each logged exercise becomes a preset item
    /// carrying its rep range and note (sets are dropped — presets hold no sets).
    func makePreset(from workout: Workout, name: String) -> WorkoutPreset {
        WorkoutPreset(name: name, items: workout.exercises.map {
            PresetItem(exerciseId: $0.exerciseId, targetRepRange: $0.targetRepRange,
                       note: $0.note, restSeconds: $0.restSeconds)
        })
    }
}

// MARK: - Seed data

extension AppStore {
    // Claude  Date 06/14/2026
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

// MARK: - Seed foods

extension AppStore {
    // Claude  Date 06/16/2026
    // A small starter food library pre-loaded on first launch (the nutrition analog
    // of seedExercises), so the diary is usable before the Open Food Facts search
    // lands in Phase 2. Values are approximate per the stated reference serving:
    // calories kcal; protein/carbs/fat/fiber/sugar grams; sodium mg. `source: .seed`
    // marks them as shipped (vs custom / API-cached).
    static let seedFoods: [FoodItem] = [
        FoodItem(name: "Chicken Breast, cooked", servingSize: 100, servingUnit: "g",
                 nutrients: Nutrients(calories: 165, protein: 31, carbs: 0, fat: 3.6, sodium: 74), source: .seed),
        FoodItem(name: "Salmon, cooked", servingSize: 100, servingUnit: "g",
                 nutrients: Nutrients(calories: 206, protein: 22, carbs: 0, fat: 13, sodium: 61), source: .seed),
        FoodItem(name: "Whole Egg", servingSize: 1, servingUnit: "large egg",
                 nutrients: Nutrients(calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8, sodium: 71), source: .seed),
        FoodItem(name: "White Rice, cooked", servingSize: 100, servingUnit: "g",
                 nutrients: Nutrients(calories: 130, protein: 2.7, carbs: 28, fat: 0.3, fiber: 0.4, sodium: 1), source: .seed),
        FoodItem(name: "Rolled Oats, dry", servingSize: 40, servingUnit: "g",
                 nutrients: Nutrients(calories: 156, protein: 6.8, carbs: 26, fat: 2.8, fiber: 4.2, sugar: 0.4), source: .seed),
        FoodItem(name: "Sweet Potato, cooked", servingSize: 100, servingUnit: "g",
                 nutrients: Nutrients(calories: 90, protein: 2, carbs: 21, fat: 0.1, fiber: 3.3, sugar: 6.5, sodium: 36), source: .seed),
        FoodItem(name: "Broccoli, cooked", servingSize: 100, servingUnit: "g",
                 nutrients: Nutrients(calories: 35, protein: 2.4, carbs: 7, fat: 0.4, fiber: 3.3, sugar: 1.4, sodium: 41), source: .seed),
        FoodItem(name: "Banana", servingSize: 1, servingUnit: "medium",
                 nutrients: Nutrients(calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1, sugar: 14, sodium: 1), source: .seed),
        FoodItem(name: "Greek Yogurt, plain nonfat", servingSize: 170, servingUnit: "g",
                 nutrients: Nutrients(calories: 100, protein: 17, carbs: 6, fat: 0.7, sugar: 4, sodium: 61), source: .seed),
        FoodItem(name: "Whole Milk", servingSize: 240, servingUnit: "ml",
                 nutrients: Nutrients(calories: 149, protein: 7.7, carbs: 12, fat: 8, sugar: 12, sodium: 105), source: .seed),
        FoodItem(name: "Almonds", servingSize: 28, servingUnit: "g",
                 nutrients: Nutrients(calories: 164, protein: 6, carbs: 6, fat: 14, fiber: 3.5, sugar: 1.2, sodium: 0), source: .seed),
        FoodItem(name: "Peanut Butter", servingSize: 32, servingUnit: "g",
                 nutrients: Nutrients(calories: 188, protein: 8, carbs: 6, fat: 16, fiber: 2, sugar: 3, sodium: 147), source: .seed),
    ]
}
