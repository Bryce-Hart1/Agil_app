import Foundation
import SwiftUI
// Claude  Date 07/16/2026
// WidgetKit: to reload the home-screen widget's timeline whenever the nutrition
// data it displays changes (see syncWidgetSnapshot).
import WidgetKit

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
    // CLAUDE  Date 09/19/2026
    // The user's current weight for cardio estimates, preferring their weigh-ins over the one
    // number typed in Settings. A closure because the weigh-ins live in BodyStore's encrypted
    // vault and must never be copied into profile.json, which lands in every device backup.
    // Set once at launch (GymAppApp); nil until then, which just means the typed value is used.
    var bodyweightProvider: (() -> Double?)?
    var effectiveBodyweightLb: Double? { bodyweightProvider?() ?? profile.bodyweightLb }
    // Claude  Date 06/16/2026
    // Nutrition tracking. Mirrors the workouts model: `foods` is the reusable food
    // library (seeded on first launch, like seedExercises; later augmented by the
    // Open Food Facts cache), `foodLog`/`waterLog` are the dated diary entries, and
    // `nutritionGoals` holds the daily targets the diary fills toward. Each auto-
    // saves on change via its own JSON file.
    @Published var foods: [FoodItem] { didSet { persistence.save(foods, to: Self.foodsFile) } }
    // Claude  Date 08/11/2026
    // User-built recipes (see Recipe): named ingredient lists that log into the diary as
    // one per-serving entry. Separate from `foods` because a recipe is an aggregate with
    // its own editable parts, not a library food — it only becomes FoodItem-shaped at the
    // moment it's searched or logged (Recipe.asFoodItem). Local-only, never submitted.
    @Published var recipes: [Recipe] { didSet { persistence.save(recipes, to: Self.recipesFile) } }
    // Claude  Date 06/17/2026
    // Local barcode → product cache (see BarcodeCache). Separate from `foods` so it
    // can be evicted freely without touching the curated library; consulted by
    // CachedFoodService before any Open Food Facts barcode lookup. Persists on change.
    @Published private(set) var barcodeCache: BarcodeCache { didSet { persistence.save(barcodeCache, to: Self.barcodeCacheFile) } }
    // Claude  Date 07/11/2026
    // foodLog now also re-evaluates achievements on change (Days Tracked reads it),
    // mirroring the activityLog didSet pattern above.
    // Claude  Date 07/11/2026 last changed: 07/16/2026 by: Claude
    // foodLog changes now also refresh the home-screen widget's snapshot (it shows
    // today's calories), alongside the existing achievements re-evaluation.
    @Published var foodLog: [FoodEntry] {
        didSet {
            persistence.save(foodLog, to: Self.foodLogFile)
            evaluateAchievements()
            syncWidgetSnapshot()
        }
    }
    @Published var waterLog: [WaterEntry] { didSet { persistence.save(waterLog, to: Self.waterLogFile) } }
    // Claude  Date 08/07/2026
    // The water quick-add chips (see WaterPreset): two built-ins plus up to three the user
    // names themselves. Use counts live here so "most used first" survives relaunches —
    // but the diary freezes the display order on appear, so a tap never reshuffles the row
    // the user is looking at.
    @Published private(set) var waterPresets: [WaterPreset] {
        didSet { persistence.save(waterPresets, to: Self.waterPresetsFile) }
    }
    // Claude  Date 08/29/2026
    // The supplement tracker (see Supplement.swift). Four collections, and the split
    // between the last two is the important part:
    //
    //   supplementSlots  — the named times of day, and their reminder schedules.
    //   supplements      — what the user takes, each assigned to a slot.
    //   supplementLog    — every individual check-off, dated. Drives the journal card.
    //   clearedSupplementDays — days the whole due stack got cleared. MONOTONE: entries
    //     are only ever added. This is what the achievement ladder is scored against.
    //
    // The last two look redundant but can't be collapsed. A slot's `weekdays` is mutable
    // and unversioned, so "was this supplement due last Tuesday?" is unanswerable after
    // the fact — recomputing history from the log would silently rewrite past progress
    // every time the user edits a schedule or adds a supplement. Banking the day's verdict
    // at the moment it's earned (the same trick as checkInDays) makes it permanent.
    //
    // None of these touch syncWidgetSnapshot(): the widget renders calories and focus
    // goals, and nothing here.
    @Published private(set) var supplementSlots: [SupplementSlot] {
        didSet {
            persistence.save(supplementSlots, to: Self.supplementSlotsFile)
            resyncSupplementReminders()
        }
    }
    @Published private(set) var supplements: [Supplement] {
        didSet {
            persistence.save(supplements, to: Self.supplementsFile)
            // Not just the slots: which supplements exist decides which slots are
            // non-empty, and an empty slot must not fire (see SupplementNotifications).
            resyncSupplementReminders()
        }
    }
    @Published private(set) var supplementLog: [SupplementEntry] {
        didSet {
            persistence.save(supplementLog, to: Self.supplementLogFile)
            // CLAUDE  Date 09/24/2026 — today's follow-up lists what's still unchecked,
            // so every check-off and un-check reschedules it (or drops it once cleared).
            resyncSupplementReminders()
        }
    }
    @Published private(set) var clearedSupplementDays: Set<Date> {
        didSet { persistence.save(clearedSupplementDays, to: Self.supplementClearedFile) }
    }
    // Claude  Date 08/06/2026
    // Per-food memory of the last amount+unit logged, keyed by FoodItem/FoodDetail id.
    // Seeds the detail page so re-logging a food you eat often is two taps instead of
    // re-dialing the amount every time — the whole point of the measurement redesign.
    // Written only by `logFoodDetail` (private(set)), so the page itself stays
    // store-free. Uncapped: one tiny record per distinct food ever logged, bounded by
    // the size of the user's food library.
    @Published private(set) var lastMeasurements: [UUID: FoodMeasurement] {
        didSet { persistence.save(lastMeasurements, to: Self.foodMeasurementsFile) }
    }
    // Claude  Date 08/18/2026
    // When each food entered the library, keyed by food id. The other half of the Recents
    // ordering: `lastLoggedByFood` only knows about foods you've EATEN, so a food you just
    // created sorted below every food you'd ever logged — the opposite of what "Recents"
    // should show right after you add something.
    //
    // A side table rather than a FoodItem.createdAt: FoodItem is also the backend wire
    // type, and this is local bookkeeping the server has no business carrying. Stamped on
    // insert only (never overwritten), so re-scanning a barcode you already have doesn't
    // pretend it's new. A deleted food leaves an orphan key, which costs nothing.
    @Published private(set) var addedAt: [UUID: Date] {
        didSet { persistence.save(addedAt, to: Self.foodAddedFile) }
    }
    // Claude  Date 08/18/2026
    // Which unit each micronutrient field is TYPED in, keyed by MicroField.id (its label,
    // so reordering the table can't scramble saved choices). Nutrition labels are
    // inconsistent about mg vs µg, so the new-food form lets each row be switched and
    // remembers it — set Vitamin D to µg once, not on every food you add.
    //
    // Display only: what's stored in Micros is always the field's canonical unit. Absent =
    // the default (see microUnit(for:)).
    @Published private(set) var microUnits: [String: MicroUnit] {
        didSet { persistence.save(microUnits, to: Self.microUnitsFile) }
    }
    // Claude  Date 08/07/2026
    // Recency signal for the Foods library "Recents" ordering: the most recent loggedAt
    // per foodId, folded from the diary. A food never logged is simply absent, so callers
    // fall back to insertion order. Derived, not persisted — foodLog is the source of
    // truth and is already loaded, so there's no separate per-food timestamp (and no
    // FoodItem schema change) to keep in sync. foodLog is a personal diary, so the fold is
    // cheap at these sizes.
    var lastLoggedByFood: [UUID: Date] {
        var map: [UUID: Date] = [:]
        for entry in foodLog {
            guard let id = entry.foodId else { continue }
            if let existing = map[id], existing >= entry.loggedAt { continue }
            map[id] = entry.loggedAt
        }
        return map
    }
    // Claude  Date 08/18/2026
    // The Recents ordering key: the later of "last eaten" and "added to the library",
    // whichever exist. Adding a food counts as activity on it, so a food created seconds
    // ago sorts to the very top, while re-logging an old food still bumps that one back
    // above it. nil only for foods that predate `addedAt` and have never been logged —
    // those keep falling back to insertion order at the call site.
    var foodRecency: [UUID: Date] {
        var map = lastLoggedByFood
        for (id, added) in addedAt {
            if let logged = map[id] { map[id] = max(logged, added) } else { map[id] = added }
        }
        return map
    }

    // Claude  Date 08/22/2026
    // "Top picks" tuning. Ranking reads the diary for foods the user eats AT THIS TIME
    // OF DAY, which is the signal Recents throws away: at 7am, `foodRecency` ranks last
    // night's dinner exactly as highly as this morning's usual breakfast.
    //
    // minLogs = 2 is what separates a routine from a one-off — it also absorbs most of
    // the noise from `stamp(_:)` (see below), which files a BACK-DATED log under the
    // clock time it was typed at rather than the hour it was eaten. A single mistimed
    // entry can't reach the row on its own.
    enum TopPicks {
        static let windowDays = 21
        static let hourRadius: TimeInterval = 3 * 3600
        static let minLogs = 2
        static let maxCards = 5
    }

    // Claude  Date 08/22/2026
    // The ids behind the Top picks row, best first. One pass over the diary: keep the
    // last three weeks, keep only entries whose TIME OF DAY lands within ±3h of `now`,
    // tally per food.
    //
    // Derived, not persisted — same reasoning as `lastLoggedByFood` above. `now` is a
    // parameter rather than an internal `Date()` so the caller can freeze it for the
    // life of a screen; recomputing against a live clock would let cards reorder under
    // a finger (cf. NutritionDiaryView.freezeWaterOrder).
    //
    // Entries with no `foodId` are skipped: a pick has to resolve back to something
    // tappable, and a nil link never will.
    func topPickIDs(asOf now: Date = Date(), calendar: Calendar = .current) -> [UUID] {
        guard let start = calendar.date(byAdding: .day, value: -TopPicks.windowDays, to: now)
        else { return [] }
        let nowSeconds = Self.secondsIntoDay(now, calendar: calendar)

        var counts: [UUID: Int] = [:]
        var latest: [UUID: Date] = [:]
        for entry in foodLog {
            // Lower bound only. `now` is frozen by the caller for ordering stability, so
            // an upper bound here would drop a food logged since the screen appeared —
            // the row would ignore the log the user just made from it. Nothing can land
            // ahead of the real clock anyway: the diary refuses to step past today.
            guard entry.loggedAt > start else { continue }
            guard let id = entry.foodId else { continue }
            let seconds = Self.secondsIntoDay(entry.loggedAt, calendar: calendar)
            guard Self.clockDistance(seconds, nowSeconds) <= TopPicks.hourRadius else { continue }
            counts[id, default: 0] += 1
            if let seen = latest[id], seen >= entry.loggedAt { continue }
            latest[id] = entry.loggedAt
        }

        // Count first, then recency, then id. The last tiebreak is deliberate: without a
        // total order two equally-ranked foods can swap places on every recompute, and
        // the row visibly reshuffles for no reason (same trap MonthlyRecap.topExerciseName
        // guards against).
        return counts
            .filter { $0.value >= TopPicks.minLogs }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                let l = latest[lhs.key] ?? .distantPast
                let r = latest[rhs.key] ?? .distantPast
                if l != r { return l > r }
                return lhs.key.uuidString < rhs.key.uuidString
            }
            .prefix(TopPicks.maxCards)
            .map(\.key)
    }

    // Claude  Date 08/22/2026
    // The Top picks row itself. A pick whose food has since been deleted resolves to nil
    // and simply drops out rather than leaving a hole.
    func topPicks(asOf now: Date = Date()) -> [FoodItem] {
        topPickIDs(asOf: now).compactMap { food(for: $0) }
    }

    // Claude  Date 08/22/2026
    // A logged food's id back to something displayable — the library first, then the
    // recipe book via `asFoodItem` (which keeps the recipe's own id, so the lookup is a
    // plain id match). Mirrors `exercise(for:)` on the workouts side.
    func food(for id: UUID) -> FoodItem? {
        if let item = foods.first(where: { $0.id == id }) { return item }
        return recipes.first(where: { $0.id == id })?.asFoodItem
    }

    // Seconds since midnight — the time-of-day coordinate the window is measured in.
    private static func secondsIntoDay(_ date: Date, calendar: Calendar) -> TimeInterval {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = TimeInterval(c.hour ?? 0)
        let minute = TimeInterval(c.minute ?? 0)
        let second = TimeInterval(c.second ?? 0)
        return hour * 3600 + minute * 60 + second
    }

    // Distance between two times of day, THE SHORT WAY ROUND. Without the wrap, a ±3h
    // window at 01:00 would cover 01:00–04:00 only and quietly drop the 22:00–24:00 half
    // of a late-night routine.
    private static func clockDistance(_ a: TimeInterval, _ b: TimeInterval) -> TimeInterval {
        let raw = abs(a - b)
        return min(raw, 86_400 - raw)
    }

    @Published var nutritionGoals: NutritionGoals {
        didSet {
            persistence.save(nutritionGoals, to: Self.nutritionGoalsFile)
            syncWidgetSnapshot()
        }
    }
    // Claude  Date 07/12/2026 last changed: 07/16/2026 by: Claude
    // User-created nutrient focus goals (fiber/sugar/sodium floors/ceilings shown
    // as the diary's Focus card). Its own file rather than a NutritionGoals field
    // because it's an add/remove list, not a fixed set of daily targets. Changes
    // also refresh the widget snapshot (the widget shows the first focus goal).
    @Published var focusGoals: [NutrientFocusGoal] {
        didSet {
            persistence.save(focusGoals, to: Self.focusGoalsFile)
            syncWidgetSnapshot()
        }
    }
    // Claude  Date 06/13/2026
    // Achievement ids the user has unlocked. Sticky — once earned, never removed
    // (so e.g. a streak badge survives a missed week). Recomputed from history by
    // evaluateAchievements(); only AppStore mutates it.
    @Published private(set) var unlockedAchievementIDs: Set<String>
    // Claude  Date 07/24/2026
    // Achievement ids whose unlock animation the user has actually WATCHED, as
    // opposed to merely earned. Persisted. This is the counter behind the red
    // count over the Profile tab: unlocked − opened = "new, waiting in the book".
    // Published (it wasn't, as celebratedAchievementIDs) because the tab badge and
    // every book slot re-render off it.
    @Published private(set) var openedAchievementIDs: Set<String> = []
    // Claude  Date 06/13/2026 last changed: 07/24/2026 by: Claude
    // Achievements queued for the unlock celebration (transient — not persisted).
    // RootTabView shows the first one as a full-screen celebration. Nothing fills
    // this automatically any more: unlocks land silently and the user chooses when
    // to play them from the Achievement Book (openAchievement / openAllUnopened).
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
    // Claude  Date 07/23/2026
    // Gemstone cards queued for the "new card unlocked" reveal (transient, empty =
    // none). Set when the user earns their first diamond/emerald achievement live
    // (RootTabView.syncRewardCards). Shown one at a time by CardUnlockOverlay; the
    // grant itself lives in ThemeManager, this only drives the reveal.
    @Published var pendingCardUnlock: [CardStyle] = []
    // CLAUDE  Date 09/05/2026
    // Whether the fullscreen card showcase / inspect overlay is up. Set by tapping the
    // Profile tab's card; hosted from RootTabView so it draws over the tab bar. Not
    // persisted — it is presentation state, not a preference.
    @Published var showsCardInspect = false
    // Claude  Date 07/14/2026
    // Whether the spotlight tour overlay is running (transient). Auto-started once
    // after onboarding (RootTabView) and replayable from Settings; the persistent
    // "seen it" flag is profile.hasSeenTour. Skipping counts as seen.
    @Published var tourActive = false
    // Claude  Date 06/16/2026
    // Alpha dev-only: a flat coin grant folded into totalCoinsEarned, so the dev
    // can top up the wallet to test shop/card purchases without grinding workouts.
    // Persisted like everything else; not part of the real economy.
    @Published private(set) var devBonusCoins: Int = 0 {
        didSet { persistence.save(devBonusCoins, to: Self.devCoinsFile) }
    }
    // Claude  Date 08/23/2026
    // Every distinct calendar day the user has OPENED the app, as local start-of-day
    // dates. Folded into totalCoinsEarned via DailyCheckIn.earned, which is what pays
    // the +20 daily bonus — see DailyCheckIn for why the log lives here rather than as
    // a term in Wallet. Only recordDailyCheckIn writes it, and it only ever grows.
    @Published private(set) var checkInDays: Set<Date> = [] {
        didSet { persistence.save(checkInDays, to: Self.checkInsFile) }
    }
    // Claude  Date 08/23/2026
    // The daily bonus waiting to be acknowledged (transient, like pendingCelebrations).
    // Set by recordDailyCheckIn on the first open of a new day; rendered by the
    // ModeNotch pill as a transient message (its presentableCheckIn gate decides
    // WHEN it's polite to show). The coins are
    // already banked by the time this is set — this drives the receipt, not the grant.
    @Published var pendingCheckIn: DailyCheckIn.Award?

    private let persistence: PersistenceService
    // Claude  Date 06/15/2026
    // Highest Strategist rank already celebrated, so a promotion fires only once.
    private var celebratedRank: StrategistRank = .initiate
    // Claude  Date 06/15/2026 last changed: 07/24/2026 by: Claude
    // Ids currently queued as a *replay* rather than a first opening, so dismissing
    // them leaves openedAchievementIDs untouched. Transient. Used by the badge
    // gallery's preview and by re-tapping an already-opened badge in the book.
    private var previewCelebrationIDs: Set<String> = []

    private static let exercisesFile = "exercises.json"
    // Claude  Date 09/06/2026 — which seedExercises revision this install has merged.
    private static let seedVersionFile = "seed_library_version.json"
    private static let workoutsFile = "workouts.json"
    private static let presetsFile = "presets.json"
    private static let profileFile = "profile.json"
    private static let achievementsFile = "achievements.json"
    // Claude  Date 07/24/2026 — was celebrated_achievements.json; renamed with the
    // "seen" → "opened" concept. Alpha build, no installed users, so no migration.
    private static let openedFile = "opened_achievements.json"
    private static let activityLogFile = "activity_log.json"
    private static let rankFile = "strategist_rank.json"
    // Claude  Date 06/16/2026 — nutrition data files.
    private static let foodsFile = "foods.json"
    // Claude  Date 08/11/2026 — user-built recipes.
    private static let recipesFile = "recipes.json"
    private static let foodLogFile = "nutrition_log.json"
    private static let waterLogFile = "water_log.json"
    private static let waterPresetsFile = "water_presets.json"
    private static let nutritionGoalsFile = "nutrition_goals.json"
    // Claude  Date 07/12/2026 — nutrient focus goals (diary Focus card).
    private static let focusGoalsFile = "nutrient_focus_goals.json"
    // Claude  Date 08/06/2026 — last amount+unit logged, per food.
    private static let foodMeasurementsFile = "food_measurements.json"
    // Claude  Date 08/18/2026 — when each food entered the library (Recents ordering).
    private static let foodAddedFile = "food_added.json"
    // Claude  Date 08/18/2026 — per-nutrient entry unit for the new-food form.
    private static let microUnitsFile = "micro_units.json"
    // Claude  Date 06/16/2026 — alpha dev coin grant.
    private static let devCoinsFile = "dev_coins.json"
    // Claude  Date 08/23/2026 — days the app was opened (daily check-in bonus).
    private static let checkInsFile = "daily_checkins.json"
    // Claude  Date 06/17/2026 — barcode → product lookup cache.
    private static let barcodeCacheFile = "barcode_cache.json"
    // Claude  Date 08/29/2026 — supplement tracker (stack, schedule, log, cleared days).
    private static let supplementSlotsFile = "supplement_slots.json"
    private static let supplementsFile = "supplements.json"
    private static let supplementLogFile = "supplement_log.json"
    private static let supplementClearedFile = "supplement_cleared_days.json"

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
        self.openedAchievementIDs = persistence.load(Self.openedFile, default: Set<String>())
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
        self.recipes = persistence.load(Self.recipesFile, default: [Recipe]())
        self.foodLog = persistence.load(Self.foodLogFile, default: [FoodEntry]())
        self.waterLog = persistence.load(Self.waterLogFile, default: [WaterEntry]())
        self.waterPresets = persistence.load(Self.waterPresetsFile,
                                             default: WaterPreset.defaults)
        self.nutritionGoals = persistence.load(Self.nutritionGoalsFile, default: NutritionGoals())
        self.focusGoals = persistence.load(Self.focusGoalsFile, default: [NutrientFocusGoal]())
        self.lastMeasurements = persistence.load(Self.foodMeasurementsFile,
                                                 default: [UUID: FoodMeasurement]())
        self.addedAt = persistence.load(Self.foodAddedFile, default: [UUID: Date]())
        self.microUnits = persistence.load(Self.microUnitsFile, default: [String: MicroUnit]())
        self.barcodeCache = persistence.load(Self.barcodeCacheFile, default: BarcodeCache())
        self.devBonusCoins = persistence.load(Self.devCoinsFile, default: 0)
        self.checkInDays = persistence.load(Self.checkInsFile, default: Set<Date>())

        // Claude  Date 08/29/2026
        // Supplements. The slot list is seeded like waterPresets — there must always be at
        // least one slot for a supplement to belong to (Supplement.slotId is non-optional),
        // and seeding one "Daily" slot means a user who takes everything at once never
        // meets the grouping UI. Saved explicitly below, since init assignments don't fire
        // the didSets. An empty file (the user deleted down to nothing, which can't happen
        // through the UI) re-seeds rather than leaving the invariant broken.
        let loadedSlots = persistence.load(Self.supplementSlotsFile, default: [SupplementSlot]())
        self.supplementSlots = loadedSlots.isEmpty ? SupplementSlot.defaults : loadedSlots
        self.supplements = persistence.load(Self.supplementsFile, default: [Supplement]())
        self.supplementLog = persistence.load(Self.supplementLogFile, default: [SupplementEntry]())
        self.clearedSupplementDays = persistence.load(Self.supplementClearedFile,
                                                      default: Set<Date>())

        // Claude  Date 09/06/2026
        // Version-gated seed sync: seedExercises only loads on a first launch (above), so
        // library changes never reached existing installs. Renames run first and IN PLACE
        // (the row keeps its id, so history/PRs/presets follow), then missing seed lifts
        // are appended. Side effect: a bump re-adds a seed lift the user had deleted.
        // Must precede the backfill below, which matches seeds by their CURRENT name.
        let storedSeedVersion = persistence.load(Self.seedVersionFile, default: 0)
        let seedSyncNeeded = storedSeedVersion < AppStore.seedLibraryVersion
        var syncedSeeds = false
        if !loadedExercises.isEmpty && seedSyncNeeded {
            for index in self.exercises.indices {
                let key = self.exercises[index].name.lowercased()
                if let renamed = AppStore.seedRenames[key] {
                    self.exercises[index].name = renamed
                    syncedSeeds = true
                }
            }
            // Appending the seed value whole avoids a fourth hand-copy site (resolveExerciseID
            // silently dropped `note` and `equipmentType` that way). Reusing its id is safe:
            // seedExercises is a static let, so its UUIDs are minted once per process.
            var known = Set(self.exercises.map { $0.name.lowercased() })
            for seed in AppStore.seedExercises where !known.contains(seed.name.lowercased()) {
                self.exercises.append(seed)
                known.insert(seed.name.lowercased())
                syncedSeeds = true
            }
        }

        // Claude  Date 08/18/2026
        // One-time equipment backfill. seedExercises only loads on a first launch (above),
        // so every existing install sits at equipmentType == nil for all 55 curated lifts
        // and would never get the nameplate. Match by name against the seed table and fill
        // ONLY nils: that makes this idempotent (a no-op on every later launch) and keeps
        // it from stomping a type the user set by hand. A renamed or custom lift simply
        // doesn't match and stays nil, which canBeBranded treats permissively. A branded
        // version matches too — its `name` is still the base lift's — which is correct.
        var backfilledEquipment = false
        if !loadedExercises.isEmpty {
            let seedEquipment: [String: EquipmentType] = Dictionary(
                AppStore.seedExercises.compactMap { seed in
                    seed.equipmentType.map { (seed.name.lowercased(), $0) }
                },
                uniquingKeysWith: { first, _ in first })
            for index in self.exercises.indices where self.exercises[index].equipmentType == nil {
                if let type = seedEquipment[self.exercises[index].name.lowercased()] {
                    self.exercises[index].equipmentType = type
                    backfilledEquipment = true
                }
            }
        }

        if loadedExercises.isEmpty || backfilledEquipment || syncedSeeds {
            persistence.save(self.exercises, to: Self.exercisesFile)
        }
        // Stamp the version on a fresh install too, so the sync never runs on one.
        if seedSyncNeeded {
            persistence.save(AppStore.seedLibraryVersion, to: Self.seedVersionFile)
        }
        // One-time cleanup: if we stripped any leftover seed foods above, persist it.
        if self.foods.count != loadedFoods.count {
            persistence.save(self.foods, to: Self.foodsFile)
        }
        // Persist the seeded default slot on first launch (init assignments skip didSet).
        if loadedSlots.isEmpty {
            persistence.save(self.supplementSlots, to: Self.supplementSlotsFile)
        }

        // Claude  Date 06/13/2026
        // Catch up on achievements already satisfied by existing history (the
        // first-run backdating pass) — silently, so we don't pop a celebration for
        // every past unlock on launch. Live unlocks during the session DO celebrate.
        evaluateAchievements(announce: false)
    }

    // MARK: - Tour

    // Claude  Date 07/14/2026
    // Start/finish the first-boot spotlight tour. Lives here (not view @State) so
    // Settings can trigger a replay from a pushed screen. completeTour handles both
    // "Done" and "Skip" — either way the tour never auto-plays again.
    func startTour() { tourActive = true }
    func completeTour() {
        tourActive = false
        profile.hasSeenTour = true
    }

    // MARK: - Achievements

    // Claude  Date 07/14/2026
    // The gender-calibrated achievement catalog (thresholds/titles vary; the id set
    // is identical in every variant, so unlock persistence is gender-agnostic).
    // Everything user-facing should read this instead of Achievement.all.
    var achievementCatalog: [Achievement] { Achievement.catalog(for: profile.gender) }

    // Claude  Date 07/24/2026 last changed: 07/26/2026 by: Claude
    // Earned but not yet watched — the badges sitting in the Achievement Book with
    // their reveal still to play. This count is what the red dot over the Profile
    // tab (and the Achievements row) shows.
    //
    // Scoped to the CURRENT catalog, which is the fix for a stuck badge: this used to
    // be a plain `unlocked − opened`, so any id in the persisted unlocked set with no
    // matching catalog entry counted forever. Nothing in the Book could render it and
    // `openAllUnopened` filtered it straight back out, so the dot never cleared and
    // "Open N new" no-opped. Orphans are easy to accumulate in alpha — every time a
    // threshold changes, the id derived from it changes with it (`logged_30` →
    // `logged_25`), stranding the old one in achievements.json. Deriving the count
    // from the catalog makes "the badge is countable" and "the Book has a slot for
    // it" the same statement, and self-heals whatever is already on disk.
    // The unlocked set itself is left untouched — it's the sticky earned record, and
    // an id that's orphaned today may just be a catalog the user isn't on right now.
    var unopenedAchievementIDs: Set<String> {
        let waiting = unlockedAchievementIDs.subtracting(openedAchievementIDs)
        guard !waiting.isEmpty else { return [] }
        return Set(achievementCatalog.lazy.map(\.id).filter { waiting.contains($0) })
    }

    var unopenedAchievementCount: Int { unopenedAchievementIDs.count }

    // Claude  Date 07/23/2026 last changed: 07/24/2026 by: Claude
    // The set of badge tiers the user has OPENED at least one achievement of — used
    // to grant the matching gemstone card the first time a tier is earned (see
    // RootTabView.syncRewardCards). This read the sticky *unlocked* set until badges
    // started waiting in the book to be revealed: keying the card off the unlock
    // would hand over the diamond card while the diamond badge that earned it was
    // still sealed. Opened is the honest trigger — the user has seen the badge.
    var openedTiers: Set<BadgeTier> {
        Set(achievementCatalog.filter { openedAchievementIDs.contains($0.id) }.map(\.tier))
    }

    // Claude  Date 06/13/2026 last changed: 07/24/2026 by: Claude
    // Add any achievements whose criteria are currently met to the unlocked set.
    // Never removes (unlocks are permanent); persists + publishes only on change.
    //
    // Claude  Date 07/24/2026
    // `announce` no longer means "pop a celebration" — nothing interrupts the user
    // any more. A live unlock simply stays OUT of openedAchievementIDs, which lights
    // the Profile-tab count and leaves the badge waiting in the Achievement Book for
    // the user to open when they want it. `announce: false` is still the first-run
    // backdating pass: it marks the catch-up unlocks opened so a fresh install
    // doesn't present a book full of "new" badges the user never actually earned
    // in-session. Rank promotions are unaffected and still fire immediately.
    func evaluateAchievements(announce: Bool = true) {
        // Claude  Date 06/13/2026 last changed: 07/25/2026 by: Claude
        // Stats come from the activity ledger (completed sets, real timestamps),
        // NOT from editable workout numbers — that's the anti-cheat fix. Now also
        // feeds the food diary + calorie goal for the Days Tracked badges, and the
        // nutrition setup checklist for First Plan.
        let stats = ProfileStats(events: activityLog, exercises: exercises, foodLog: foodLog,
                                 nutritionGoals: nutritionGoals,
                                 setup: profile.nutritionSetup,
                                 tookFirstStep: profile.tookFirstStep,
                                 clearedSupplementDays: clearedSupplementDays)
        // Claude  Date 07/14/2026
        // Evaluate against the gender-calibrated catalog — this is where the
        // identity choice actually changes badge progress. Ids are identical
        // across variants, so the sticky unlocked set stays valid either way.
        var updated = unlockedAchievementIDs
        for achievement in achievementCatalog where achievement.isUnlocked(stats) {
            updated.insert(achievement.id)
        }
        guard updated != unlockedAchievementIDs else { return }

        let newlyUnlocked = updated.subtracting(unlockedAchievementIDs)
        unlockedAchievementIDs = updated
        persistence.save(updated, to: Self.achievementsFile)

        if !announce {
            // Backdating pass: treat already-satisfied achievements as opened.
            openedAchievementIDs.formUnion(newlyUnlocked)
            persistence.save(openedAchievementIDs, to: Self.openedFile)
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

    // MARK: - Nutrition setup checklist

    // Claude  Date 07/25/2026
    // Tick off one item on the Journal's setup checklist (see NutritionSetupCard).
    // The guard makes this idempotent, which is what lets the goal fields call it on
    // every keystroke: without it, typing "2400" would re-evaluate the whole catalog
    // four times. The explicit evaluateAchievements() is required — `profile`'s
    // didSet only persists, it doesn't evaluate (same reason SettingsView calls it by
    // hand after the gender picker writes), and First Plan reads this state.
    func markNutritionSetup(_ field: WritableKeyPath<NutritionSetup, Bool>) {
        guard !profile.nutritionSetup[keyPath: field] else { return }
        profile.nutritionSetup[keyPath: field] = true
        evaluateAchievements()
    }

    // Claude  Date 07/25/2026
    // Retire the checklist card — auto-called a few seconds after the user finishes,
    // and by the card's X. Deliberately separate from NutritionSetup.isComplete so
    // dismissing early never counts as completing (and never grants First Plan).
    func acknowledgeNutritionSetup() {
        guard !profile.nutritionSetup.acknowledged else { return }
        profile.nutritionSetup.acknowledged = true
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

    // Claude  Date 07/24/2026
    // Open one badge from the Achievement Book: play its reveal now. Dismissing the
    // overlay is what marks it opened (see dismissCurrentCelebration), so backing
    // out mid-animation leaves it "new" and it can be opened again later.
    func openAchievement(_ achievement: Achievement) {
        queueCelebrations([achievement])
    }

    // Claude  Date 07/24/2026
    // Open everything waiting at once ("Open N new" in the book) — plays lowest
    // tier → highest so the run builds to the best badge earned.
    func openAllUnopened() {
        let waiting = unopenedAchievementIDs
        queueCelebrations(achievementCatalog.filter { waiting.contains($0.id) })
    }

    // Claude  Date 06/15/2026 last changed: 07/24/2026 by: Claude
    // Replay a badge's reveal without touching persisted state — for tapping a badge
    // you've already opened, and for the dev badge gallery's preview (which can play
    // one you haven't even earned). Was previewCelebration; renamed now that replay
    // is a real user-facing action rather than a dev-only affordance.
    func replayCelebration(_ achievement: Achievement) {
        previewCelebrationIDs.insert(achievement.id)
        if !pendingCelebrations.contains(where: { $0.id == achievement.id }) {
            pendingCelebrations.append(achievement)
        }
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

    // Claude  Date 06/13/2026 last changed: 07/24/2026 by: Claude
    // Dismiss the current celebration: mark it opened and advance the queue. This is
    // the only place openedAchievementIDs grows outside the backdating pass — the
    // badge counts down only once the user has actually watched the reveal.
    func dismissCurrentCelebration() {
        guard let current = pendingCelebrations.first else { return }
        // A replay (or a dev-gallery preview) leaves the persisted state untouched,
        // so a badge you replay stays opened and one you previewed stays new.
        if previewCelebrationIDs.remove(current.id) == nil {
            openedAchievementIDs.insert(current.id)
            persistence.save(openedAchievementIDs, to: Self.openedFile)
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

    // Claude  Date 07/23/2026
    // Queue the "new card unlocked" reveal for freshly-granted gemstone cards
    // (skipping any already queued), shown one at a time by CardUnlockOverlay. The
    // grant is done by the caller (ThemeManager.grantCardStyle); this only reveals.
    func celebrateCardUnlock(_ styles: [CardStyle]) {
        let queued = Set(pendingCardUnlock.map(\.id))
        let additions = styles.filter { !queued.contains($0.id) }
        guard !additions.isEmpty else { return }
        pendingCardUnlock.append(contentsOf: additions)
    }

    // Dismiss the current card-unlock reveal and advance the queue.
    func dismissCardUnlock() {
        guard !pendingCardUnlock.isEmpty else { return }
        pendingCardUnlock.removeFirst()
    }

    // Claude  Date 06/13/2026 last changed: 07/24/2026 by: Claude
    // Dev/alpha helper: mark every unlocked achievement as NEW again (non-destructive
    // — coins/unlocks are kept). Was replayCelebrations, which queued a wall of
    // overlays; now that reveals are user-initiated, the useful test action is to
    // refill the book with unopened slots and light the Profile-tab count.
    func markAllUnopened() {
        openedAchievementIDs = []
        persistence.save(openedAchievementIDs, to: Self.openedFile)
        pendingCelebrations = []
    }

    // Claude  Date 06/15/2026
    // Dev/alpha helper: mark every achievement unlocked so the profile card, shelf,
    // achievements list, and Strategist rank all populate for review. Silent (marks
    // everything celebrated, sets the rank as seen) so it doesn't fire a wall of
    // overlays. Use "Reset achievements" to return to history-based progress.
    func unlockAllAchievements() {
        unlockedAchievementIDs = Set(achievementCatalog.map(\.id))
        openedAchievementIDs = unlockedAchievementIDs
        celebratedRank = strategistRank
        pendingCelebrations = []
        pendingPromotions = []
        persistence.save(unlockedAchievementIDs, to: Self.achievementsFile)
        persistence.save(openedAchievementIDs, to: Self.openedFile)
        persistence.save(celebratedRank, to: Self.rankFile)
    }

    // Claude  Date 07/25/2026
    // Dev/alpha helper: force an ARBITRARY set of achievements locked or unlocked,
    // bypassing ProfileStats entirely. The existing helpers are all-or-nothing
    // (unlockAllAchievements / resetAchievements); this is the surgical one behind
    // the Achievement forcing screen, so a single badge, a tier, or one category can
    // be put in any state without manufacturing the workout history to earn it.
    //
    // Three things have to be kept coherent by hand, because this deliberately skips
    // evaluateAchievements:
    //  - `queueAsNew` decides whether forced unlocks land UNOPENED (waiting in the
    //    Achievement Book, lighting the Profile-tab count) or pre-opened and silent.
    //  - Locking a badge also unpins it: the profile card must never feature one the
    //    user doesn't hold, and nothing else would clean that up.
    //  - `firePromotions` mirrors evaluateAchievements' rank block. It matters even
    //    when you don't want an overlay: leaving celebratedRank stale below the new
    //    rank means the NEXT real evaluation dumps every skipped promotion at once,
    //    so the else-branch resyncs it silently instead of leaving that landmine.
    //    Forcing badges DOWN never demotes celebratedRank — same one-way rule the
    //    real ladder follows.
    func devSetAchievements(ids: Set<String>, unlocked: Bool,
                            queueAsNew: Bool = true, firePromotions: Bool = false) {
        guard !ids.isEmpty else { return }
        if unlocked {
            unlockedAchievementIDs.formUnion(ids)
            if queueAsNew {
                openedAchievementIDs.subtract(ids)
            } else {
                openedAchievementIDs.formUnion(ids)
            }
        } else {
            unlockedAchievementIDs.subtract(ids)
            openedAchievementIDs.subtract(ids)
            pendingCelebrations.removeAll { ids.contains($0.id) }
            profile.showcasedAchievementIDs.removeAll { ids.contains($0) }
        }
        persistence.save(unlockedAchievementIDs, to: Self.achievementsFile)
        persistence.save(openedAchievementIDs, to: Self.openedFile)

        let newRank = strategistRank
        if newRank > celebratedRank {
            if firePromotions {
                let queued = Set(pendingPromotions)
                pendingPromotions.append(contentsOf: StrategistRank.allCases.filter {
                    $0 > celebratedRank && $0 <= newRank && !queued.contains($0)
                })
            }
            celebratedRank = newRank
            persistence.save(celebratedRank, to: Self.rankFile)
        }
    }

    /// Single-achievement convenience over `devSetAchievements`.
    func devSetAchievement(id: String, unlocked: Bool,
                           queueAsNew: Bool = true, firePromotions: Bool = false) {
        devSetAchievements(ids: [id], unlocked: unlocked,
                           queueAsNew: queueAsNew, firePromotions: firePromotions)
    }

    // Claude  Date 06/15/2026
    // Dev/alpha helper: play a rank promotion overlay on demand. Non-persistent —
    // dismissing it leaves celebratedRank untouched.
    func previewPromotion(_ rank: StrategistRank) {
        if !pendingPromotions.contains(rank) { pendingPromotions.append(rank) }
    }

    // Claude  Date 06/13/2026 last changed: 07/24/2026 by: Claude
    // Dev/alpha helper: wipe all achievement progress, then re-earn from history.
    // Clears showcased pins too. announce: true means the re-earned badges come back
    // as UNOPENED (nothing pops) — the book fills with new slots to open.
    func resetAchievements() {
        unlockedAchievementIDs = []
        openedAchievementIDs = []
        pendingCelebrations = []
        profile.showcasedAchievementIDs = []
        persistence.save(unlockedAchievementIDs, to: Self.achievementsFile)
        persistence.save(openedAchievementIDs, to: Self.openedFile)
        evaluateAchievements(announce: true)
    }

    // Claude  Date 09/06/2026
    // "Delete Account": put every piece of on-device state back to what a fresh
    // install holds. Only AccountDeletion calls this, and only after the server copy
    // is gone. Sets the live @Published values rather than just deleting files, so
    // the running UI empties out immediately instead of showing stale data until the
    // next launch — the didSets rewrite defaults to disk, and AccountDeletion's final
    // PersistenceService.removeAll() sweeps those away too.
    //
    // Side effect: profile goes back to a default UserProfile, so hasOnboarded flips
    // false and RootTabView re-presents onboarding on its own.
    func eraseAllData() {
        // Transient/presentation state first, so nothing is left pointing at data
        // that's about to disappear.
        pendingCelebrations = []
        pendingPromotions = []
        pendingWorkoutSummary = nil
        pendingFoundersUnlock = []
        pendingCardUnlock = []
        pendingCheckIn = nil
        showsCardInspect = false
        tourActive = false
        previewCelebrationIDs = []
        celebratedRank = .initiate

        // Training.
        workouts = []
        presets = []
        activityLog = []
        exercises = AppStore.seedExercises

        // Nutrition, water, supplements.
        foods = []
        recipes = []
        foodLog = []
        waterLog = []
        waterPresets = WaterPreset.defaults
        nutritionGoals = NutritionGoals()
        focusGoals = []
        lastMeasurements = [:]
        addedAt = [:]
        microUnits = [:]
        barcodeCache = BarcodeCache()
        supplementSlots = SupplementSlot.defaults
        supplements = []
        supplementLog = []
        clearedSupplementDays = []

        // Progression + economy.
        unlockedAchievementIDs = []
        openedAchievementIDs = []
        devBonusCoins = 0
        checkInDays = []

        // Identity last: flipping hasOnboarded is what re-presents onboarding, and it
        // should only happen once everything behind it is already empty.
        profile = UserProfile()

        // These two have no didSet of their own (they're written by hand elsewhere).
        persistence.save(unlockedAchievementIDs, to: Self.achievementsFile)
        persistence.save(openedAchievementIDs, to: Self.openedFile)
        persistence.save(celebratedRank, to: Self.rankFile)
        persistence.save(AppStore.seedLibraryVersion, to: Self.seedVersionFile)
        syncWidgetSnapshot()
    }

    // Claude  Date 06/13/2026 last changed: 08/23/2026 by: Claude
    // Lifetime coins earned = weekly-consistency coins + achievement rewards + daily
    // check-in bonuses (+ any alpha dev grant). This is the "earned" side of the wallet
    // (ThemeManager.balance subtracts spend).
    //
    // (08/23) Every term here is monotonic in its input, which is what lets this feed
    // Wallet.earnedHighWater. The check-in term is the newest: see DailyCheckIn for why
    // the day log is persisted here and derived, rather than being a stored balance.
    var totalCoinsEarned: Int {
        Coins.earned(from: workouts)
            + Coins.earnedFromAchievements(unlockedIDs: unlockedAchievementIDs)
            + DailyCheckIn.earned(from: checkInDays)
            + devBonusCoins
    }

    // MARK: - Daily check-in

    // Claude  Date 08/23/2026
    // Record that the app was opened today, paying +20 coins for the first open of a
    // day (5 paying days per Mon–Sun week). Idempotent per calendar day, so it's safe —
    // and expected — to call on every launch and every foreground; only the day's FIRST
    // call returns true and queues a toast.
    //
    // The grant itself is implicit: inserting the day republishes totalCoinsEarned,
    // which RootTabView's .onChange feeds to theme.noteEarned. There is no "add coins"
    // call anywhere in this app and this doesn't introduce one.
    //
    // Days past the weekly cap are still RECORDED (so the Shop's week strip stays
    // truthful about which days you showed up) but queue nothing — Bryce's call: a
    // notification carrying no reward is just an interruption.
    @discardableResult
    func recordDailyCheckIn(now: Date = .now, calendar: Calendar = .current) -> Bool {
        // Not during onboarding — a brand-new user shouldn't get a coin pill over the
        // name prompt. RootTabView calls this again the moment onboarding completes.
        guard profile.hasOnboarded else { return false }

        let day = calendar.startOfDay(for: now)
        // contains(where:) rather than Set.contains: a timezone change moves what
        // startOfDay resolves to, and a same-day test is what actually prevents two
        // entries for one day. The set holds one Date per day, so the scan is trivial.
        guard !checkInDays.contains(where: { calendar.isDate($0, inSameDayAs: day) }) else {
            return false
        }
        checkInDays.insert(day)

        let week = DailyCheckIn.progress(days: checkInDays, asOf: now, calendar: calendar)
        if week.claimed <= DailyCheckIn.daysPerWeek {
            pendingCheckIn = DailyCheckIn.Award(coins: DailyCheckIn.coinsPerDay,
                                                dayInWeek: week.claimed)
        }
        return true
    }

    /// Clear the queued daily bonus once its toast has been shown (or flicked away).
    func dismissCheckIn() { pendingCheckIn = nil }

    /// This week's check-in progress, for the Shop's "This week" strip.
    var checkInWeek: DailyCheckIn.WeekProgress { DailyCheckIn.progress(days: checkInDays) }

    #if DEBUG
    // Claude  Date 08/23/2026
    // Dev-only: wipe the check-in log so the toast replays on the next foreground.
    // Without this the only way to see the reward again is to wait until tomorrow.
    // Note it does NOT lower the balance — the wallet's high-water mark is the point.
    func debugResetCheckIns() {
        checkInDays = []
        pendingCheckIn = nil
    }
    #endif

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

    // MARK: - Profile card back

    // CLAUDE  Date 09/05/2026
    // The back's style, falling back to the front when the user hasn't picked one
    // ("Match front"). One place so the card and the style picker cannot disagree.
    var resolvedBackCardStyle: CardStyle {
        CardStyle.style(for: profile.cardBackStyleID ?? profile.cardStyleID)
    }

    var cardBackHeroStat: CardStat? {
        profile.cardBackHeroStat.flatMap(CardStat.init(rawValue:))
    }

    var cardBackTileStats: [CardStat] {
        CardStatLayout.stats(from: profile.cardBackStatIDs)
    }

    // CLAUDE  Date 09/05/2026
    // The expensive half of the card back (two ProfileStats passes plus the PR scan).
    // Callers hold the RESULT in @State and refresh on data changes rather than
    // touching this per render — the same guard ProgressDashboardView puts on recap.
    var cardBackStatInputs: CardStatInputs {
        CardStatInputs(workouts: workouts, exercises: exercises, activityLog: activityLog,
                       foodLog: foodLog, nutritionGoals: nutritionGoals)
    }

    var cardBackStats: CardBackStats {
        CardStatResolver.backStats(hero: cardBackHeroStat, tiles: cardBackTileStats,
                                   inputs: cardBackStatInputs)
    }

    // CLAUDE  Date 09/05/2026
    // Add/remove a stat tile on the card back. Returns false (changing nothing) past the
    // cap, matching toggleShowcased. Hero and tiles are kept disjoint, so promoting a
    // tile to hero elsewhere never leaves it showing twice.
    @discardableResult
    func toggleBackStat(_ stat: CardStat) -> Bool {
        var ids = profile.cardBackStatIDs
        if let index = ids.firstIndex(of: stat.rawValue) {
            ids.remove(at: index)
        } else {
            guard ids.count < CardStat.maxTiles else { return false }
            if profile.cardBackHeroStat == stat.rawValue { profile.cardBackHeroStat = nil }
            ids.append(stat.rawValue)
        }
        profile.cardBackStatIDs = ids
        return true
    }

    // Reorder the back's tiles (their reading order in the grid). Driven by the stat
    // picker's drag-to-reorder; persists via profile's didSet.
    func moveBackStat(fromOffsets: IndexSet, toOffset: Int) {
        var ids = profile.cardBackStatIDs
        ids.move(fromOffsets: fromOffsets, toOffset: toOffset)
        profile.cardBackStatIDs = ids
    }

    // Set (or clear, with nil) the big highlighted stat. Tapping the current hero again
    // clears it; promoting a stat that was a tile removes the tile so it isn't doubled.
    func setCardBackHeroStat(_ stat: CardStat?) {
        guard let stat else { profile.cardBackHeroStat = nil; return }
        if profile.cardBackHeroStat == stat.rawValue {
            profile.cardBackHeroStat = nil
            return
        }
        profile.cardBackStatIDs.removeAll { $0 == stat.rawValue }
        profile.cardBackHeroStat = stat.rawValue
    }

    // MARK: - Exercises

    // Claude  Date 06/09/2026 last changed: 08/18/2026 by: Claude
    // Create an exercise, returning it so callers (e.g. the picker) can select it.
    // (08/18) Brand is normalized HERE rather than in the views, so no caller can
    // introduce a second spelling of a brand the library already has. Also started
    // forwarding `note` — it was silently dropped before, so a lift created from a
    // template lost its form cue.
    @discardableResult
    func addExercise(name: String, region: MuscleRegion = .other, category: String,
                     isUnilateral: Bool = false, liftType: LiftType? = nil,
                     primaryMover: String = "", quality: LiftQuality? = nil,
                     isBodyweight: Bool = false, note: String? = nil,
                     brand: String = "", equipmentType: EquipmentType? = nil,
                     cardioMachine: CardioMachine? = nil) -> Exercise {
        let exercise = Exercise(name: name, region: region, category: category,
                                isUnilateral: isUnilateral, liftType: liftType,
                                primaryMover: primaryMover, quality: quality,
                                isBodyweight: isBodyweight, note: note,
                                brand: Exercise.normalizedBrand(brand, in: exercises),
                                equipmentType: equipmentType, cardioMachine: cardioMachine)
        exercises.append(exercise)
        return exercise
    }

    // Claude  Date 08/18/2026
    // Clone a lift into a branded sibling: same movement, new id, brand set. The new id
    // is the entire point — history keys off exerciseId everywhere, so the variant starts
    // with an empty chart and graphs on its own while the generic lift keeps everything it
    // already had. Nothing is reassigned retroactively.
    //
    // liftType and the perma note ride along deliberately: the big-3 badge asks "did you
    // squat", not "did you squat on one particular rack", and a form cue still applies to
    // the same movement on a different machine.
    //
    // Returns the EXISTING variant rather than a twin when this base+brand pair is already
    // in the library, so callers that immediately select the result still terminate.
    // Returns nil only for a blank brand. No canBeBranded guard here — the UI gates the
    // entry point; the store shouldn't silently refuse an action the user took.
    @discardableResult
    func addBrandVariant(of base: Exercise, brand: String) -> Exercise? {
        let canonical = Exercise.normalizedBrand(brand, in: exercises)
        guard !canonical.isEmpty else { return nil }
        // Re-read by id: `base` is a snapshot taken when the sheet opened and the lift may
        // have been edited behind it (same reasoning as NewExerciseView.saveInPlace).
        let source = exercise(for: base.id) ?? base

        if let existing = exercises.first(where: {
            $0.name.caseInsensitiveCompare(source.name) == .orderedSame
                && $0.brand.caseInsensitiveCompare(canonical) == .orderedSame
        }) { return existing }

        let variant = Exercise(name: source.name, region: source.region,
                               category: source.category, isUnilateral: source.isUnilateral,
                               liftType: source.liftType, primaryMover: source.primaryMover,
                               quality: source.quality, isBodyweight: source.isBodyweight,
                               note: source.note, brand: canonical,
                               equipmentType: source.equipmentType,
                               cardioMachine: source.cardioMachine)
        exercises.append(variant)
        return variant
    }

    func deleteExercises(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }

    // Claude  Date 06/18/2026
    // Replace an exercise in the library (matched by id) after editing its details —
    // e.g. from the pencil in the workout editor's exercise header. Persists via the
    // exercises didSet; workouts reference exercises by id, so their labels update live.
    // (08/18) Normalizes the brand on the way in, against the library MINUS this lift —
    // without that exclusion a user fixing the casing of the only lift carrying a brand
    // would have their new spelling snapped straight back to the old one, forever.
    func updateExercise(_ exercise: Exercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        var updated = exercise
        updated.brand = Exercise.normalizedBrand(updated.brand,
                                                 in: exercises.filter { $0.id != exercise.id })
        exercises[index] = updated
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
                // Claude  Date 08/18/2026
                // Brand is the third key so branded versions of one lift sit together
                // directly under their generic (whose brand is "", sorting first) rather
                // than in whatever order the array happens to hold.
                .sorted { ($0.category, $0.name, $0.brand) < ($1.category, $1.name, $1.brand) }
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

    // Claude  Date 08/18/2026
    // Brand options for the editors, derived from the library the same way the muscle
    // pickers are — there's no shipped brand list, the user's own machines are the canon.
    var knownBrands: [String] { Exercise.knownBrands(in: exercises) }

    func normalizedBrand(_ input: String) -> String {
        Exercise.normalizedBrand(input, in: exercises)
    }

    // Autocomplete for the brand field. A blank query offers what's already in the
    // library (discovery matters more than filtering on an empty field), and an exact
    // full match offers nothing — mirrors NewExerciseView's mover suggestions.
    func brandSuggestions(matching query: String, limit: Int = 6) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = knownBrands
        guard !q.isEmpty else { return Array(all.prefix(limit)) }
        let matches = all.filter { $0.lowercased().contains(q) }
        if matches.count == 1 && matches[0].lowercased() == q { return [] }
        return Array(matches.prefix(limit))
    }

    func exercise(for id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }

    // Claude  Date 08/04/2026
    // Write access to a lift's perma note (Exercise.note) for the editors that show
    // it — the workout editor and the preset editor both display the note of a lift
    // they only reference by id, so neither has a Binding into `exercises` to hand a
    // TextField. Writing through the array hits its didSet, which persists the
    // library immediately: that's what makes the note "perma", including from a
    // blank workout the user never saves as a preset.
    //
    // A lift deleted while its editor is open reads nil and swallows writes rather
    // than resurrecting a library row.
    func exerciseNoteBinding(for id: UUID) -> Binding<String?> {
        Binding(
            get: { [weak self] in self?.exercise(for: id)?.note },
            set: { [weak self] newValue in
                guard let self,
                      let index = self.exercises.firstIndex(where: { $0.id == id })
                else { return }
                self.exercises[index].note = newValue
            }
        )
    }

    // MARK: - Workouts

    func addWorkout(_ workout: Workout) {
        workouts.append(workout)
        // Claude  Date 07/27/2026
        // Starting a workout — empty or from a preset — is one of the two ways out
        // of the get-started state, so it earns First Step immediately.
        markFirstStep()
    }

    // Claude  Date 07/27/2026
    // Record that the user has acted on the Workouts tab's get-started state and
    // award First Step. Called from the two ways forward that screen offers:
    // installPremade (browse the catalog and add a split) and addWorkout (start an
    // empty one, or one from a preset). The guard makes it idempotent — every
    // subsequent workout hits this — and the explicit evaluateAchievements() is
    // required because `profile`'s didSet only persists, it doesn't evaluate (same
    // as markNutritionSetup above).
    func markFirstStep() {
        guard !profile.tookFirstStep else { return }
        profile.tookFirstStep = true
        evaluateAchievements()
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
    //
    // Claude  Date 09/02/2026
    // `at` overrides the finish stamp (nil = now) and `showSummary` suppresses the
    // performance card; both exist for autoFinishStaleWorkouts below, which closes a
    // forgotten session at the time it really stopped, silently. Manual completion —
    // the Complete Workout button — still uses the defaults.
    // Claude  Date 09/07/2026
    // Lifting / Cardio / Mixed for a session, resolved against the library. Derived, never
    // stored — see Workout.kind(using:). nil for a session with no exercises yet.
    func kind(of workout: Workout) -> WorkoutKind? { workout.kind(using: exercises) }

    func finishWorkout(id: UUID, at finishDate: Date? = nil, showSummary: Bool = true) {
        guard let index = workouts.firstIndex(where: { $0.id == id }),
              !workouts[index].isFinished else { return }

        // Claude  Date 09/14/2026 last changed: 09/17/2026 by: CLAUDE
        // An empty session (no exercises added) is thrown away, not saved: it has nothing
        // to credit, so it shouldn't count as a finished session or pop the performance card.
        // Side effect: it simply disappears from the mini-bar / History.
        //
        // CLAUDE  Date 09/17/2026
        // Same for a session with NOTHING checked off (Bryce, 9/17/26): the missed-set alert
        // has already asked, so the user has said they didn't do those sets. History only
        // holds sessions with at least one completed set. Applies to auto-finish too, so a
        // forgotten session nobody logged a set in is dropped rather than filed.
        if workouts[index].exercises.isEmpty || workouts[index].completedSets == 0 {
            workouts.remove(at: index)
            return
        }

        var newEvents: [ActivityEvent] = []
        for logged in workouts[index].exercises {
            // Claude  Date 07/11/2026
            // effectiveLiftType (not the raw liftType tag) so any Arms/Biceps exercise
            // credits the curl badge automatically, not just an explicitly tagged one.
            // Region is frozen alongside it for region-wide ladders such as Back Strength.
            let exercise = exercise(for: logged.exerciseId)
            let liftType = exercise?.effectiveLiftType
            for set in logged.sets where set.completedAt != nil {
                guard !activityLog.contains(where: { $0.setId == set.id }) else { continue }
                // Claude  Date 09/07/2026
                // A cardio bout only reaches the ledger when it is long enough to be real
                // training AND inside the plausibility band (CardioPolicy.earnsCredit), so a
                // 30-second tap or a 100-mph "run" buys no streak day. It still saves and
                // still shows in history — it just earns nothing. Lifting sets are untouched.
                if let seconds = set.durationSeconds {
                    guard let machine = exercise?.cardioMachine,
                          CardioPolicy.earnsCredit(machine: machine, seconds: seconds,
                                                   meters: set.distanceMeters) else { continue }
                }
                newEvents.append(ActivityEvent(
                    setId: set.id, exerciseId: logged.exerciseId,
                    reps: set.reps, weight: set.weight,
                    loggedAt: set.completedAt ?? Date(), liftType: liftType,
                    muscleRegion: exercise?.region,
                    durationSeconds: set.durationSeconds,
                    distanceMeters: set.distanceMeters))
            }
        }
        if !newEvents.isEmpty { activityLog.append(contentsOf: newEvents) }
        // Claude  Date 07/01/2026
        // Stamp the real finish time so the performance card's elapsed span
        // (startedAt → finishedAt) is the true wall-clock duration — including any time
        // the app spent backgrounded or the phone was locked.
        workouts[index].finishedAt = finishDate ?? Date()
        workouts[index].isFinished = true

        // Claude  Date 06/16/2026 last changed: 07/21/2026 by: Claude
        // Queue the performance card from the now-finished workout. RootTabView shows
        // it first; dismissing it lets the badge celebrations (queued above) play.
        // (07/21) The card's "Best Set" is now scored against the user's history, so it
        // gets the ledger — MINUS this session's own events, which were appended a few
        // lines up. Without that filter every workout would set a record against itself.
        // Claude  Date 09/14/2026 last changed: 09/17/2026 by: CLAUDE
        // (09/17) The zero-completed-set case never reaches here any more — such a session is
        // dropped above — so this is only autoFinishStaleWorkouts asking for no card.
        guard showSummary else { return }
        let ownSetIds = Set(workouts[index].exercises.flatMap { $0.sets.map(\.id) })
        pendingWorkoutSummary = WorkoutSummary(
            workout: workouts[index],
            exercises: exercises,
            history: activityLog.filter { !ownSetIds.contains($0.setId) },
            // Claude  Date 09/07/2026 last changed: 09/19/2026 by: CLAUDE — on-device only, and
            // nil is fine: no weight simply means the card shows no calorie figure rather than
            // a guessed one. (09/19) Now prefers the user's latest weigh-in when they have one.
            bodyweightLb: effectiveBodyweightLb)
    }

    // Claude  Date 09/02/2026
    // Safeguard against a session the user simply forgot to finish, which used to run
    // for hours or days and report that as its elapsed time. Any active workout idle
    // past Workout.idleFinishLimit (1h with no set checked off) is completed here and
    // stamped with `lastActivityAt` — the last set they actually checked, or the start
    // if they never checked one — so the session reads as the hour it really took.
    //
    // Credit is unchanged: this goes through finishWorkout, so every checked set still
    // lands in the ledger with its own timestamp and still earns badges. Side effects:
    // the workout leaves the mini-bar / "In progress" row, and the performance card is
    // deliberately suppressed — it would otherwise pop full-screen on launch for a
    // session that ended yesterday. Called on launch, on foreground, and from a
    // one-minute tick (see RootTabView).
    @discardableResult
    func autoFinishStaleWorkouts(asOf now: Date = Date()) -> [UUID] {
        let stale = workouts.filter { $0.isStale(asOf: now) }
        for workout in stale {
            finishWorkout(id: workout.id, at: workout.lastActivityAt, showSummary: false)
        }
        return stale.map(\.id)
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
        // Claude  Date 08/18/2026 — stamp it so it opens at the top of Recents, above
        // foods you've logged before but haven't touched since.
        stampAdded(food.id)
        return food
    }

    // Claude  Date 08/18/2026
    // Record when a food entered the library. Never overwrites: the first time a food
    // shows up is when it was added, and a barcode re-scan that resolves to this same
    // food isn't a new addition.
    private func stampAdded(_ id: UUID, at date: Date = Date()) {
        guard addedAt[id] == nil else { return }
        addedAt[id] = date
    }

    // Claude  Date 08/18/2026
    // The unit a micronutrient field is entered in. Defaults to milligrams — the unit
    // most labels print and the one most people can read off a package without
    // converting — except the fats, which every label prints in grams. A field the user
    // has switched keeps their choice.
    func microUnit(for field: MicroField) -> MicroUnit {
        if let chosen = microUnits[field.id] { return chosen }
        return field.unit == .g ? .g : .mg
    }

    func setMicroUnit(_ unit: MicroUnit, for field: MicroField) {
        microUnits[field.id] = unit
    }

    func deleteFood(_ food: FoodItem) {
        foods.removeAll { $0.id == food.id }
    }

    // Claude  Date 08/11/2026
    // Recipe CRUD, mirroring the food library above. A recipe logs through the ordinary
    // food path (`logFood(recipe.asFoodItem, …)`), so there's no recipe-specific logging
    // method here — the diary only ever sees a FoodEntry.
    @discardableResult
    func addRecipe(_ recipe: Recipe) -> Recipe {
        recipes.append(recipe)
        return recipe
    }

    func updateRecipe(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
        }
    }

    func deleteRecipe(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
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
        stampAdded(food.id)
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

    // Claude  Date 07/15/2026 Peer reviewed Bryce Hart Aug 6, 2026
    // Log straight from the food detail page (a scan or a tapped recent). That page is
    // per-100 and lets the user dial in an exact amount — grams, a serving, cups… — so
    // it hands back the already-consumed nutrients. We snapshot those as a single
    // "serving" (servings folded into the nutrients, so `consumed` reads back the same),
    // linking `foodId` to the library food when there is one. Stamped like logFood so the
    // entry lands chronologically on `date`.
    // carries the `measurement` — the amount+unit
    // as the user dialed it. Two uses, and this is the one choke point for both: it's
    // stamped onto the entry so the diary row can read "200 g" instead of the
    // hardcoded "1× serving", and remembered per food so re-opening seeds the page
    // with it. Optional/defaulted because `logFood` and any plain servings-count path
    // legitimately have no unit to record.)
    func logFoodDetail(_ food: FoodDetail, consumed: Nutrients, measurement: FoodMeasurement? = nil, meal: MealType,
     on date: Date = Date()) {
        foodLog.append(FoodEntry(foodId: food.id, name: food.snapshotLabel,
                                 nutrients: consumed, servings: 1, mealType: meal,
                                 loggedAt: Self.stamp(date), measurement: measurement,
                                 basis: MeasurementBasis(food)))
        if let measurement { lastMeasurements[food.id] = measurement }
    }

    func deleteFoodEntry(id: UUID) {
        foodLog.removeAll { $0.id == id }
    }

    // Claude  Date 06/16/2026 last changed: 08/06/2026 by: Claude
    // Replace a logged entry in place (matched by id), e.g. after correcting its
    // amount or meal in the editor. The nutrient snapshot is the caller's to compute —
    // this just writes the edited entry back, which persists via didSet.
    //
    // (A corrected amount also refreshes this food's remembered measurement: an edit is
    // the user's most recent statement of how they measure this food, and a correction
    // is usually the thing worth repeating next time.)
    func updateFoodEntry(_ entry: FoodEntry) {
        if let index = foodLog.firstIndex(where: { $0.id == entry.id }) {
            foodLog[index] = entry
        }
        if let foodId = entry.foodId, let measurement = entry.measurement {
            lastMeasurements[foodId] = measurement
        }
    }

    // Add water (canonical milliliters) toward the day's goal, stamped onto `date`.
    func logWater(milliliters: Double, on date: Date = Date()) {
        waterLog.append(WaterEntry(milliliters: milliliters, loggedAt: Self.stamp(date)))
    }

    func deleteWaterEntry(id: UUID) {
        waterLog.removeAll { $0.id == id }
    }

    // Claude  Date 08/07/2026
    // Log a quick-add chip and count the tap. The count only affects ordering the NEXT
    // time the diary appears — see WaterPreset.
    func logWater(preset: WaterPreset, on date: Date = Date()) {
        logWater(milliliters: preset.milliliters, on: date)
        if let index = waterPresets.firstIndex(where: { $0.id == preset.id }) {
            waterPresets[index].useCount += 1
        }
    }

    // How many of the user's three custom slots are spoken for.
    var customWaterPresetCount: Int { waterPresets.filter(\.isCustom).count }
    var canAddWaterPreset: Bool { customWaterPresetCount < WaterPreset.maxCustomCount }

    // Claude  Date 08/07/2026
    // Save a named custom chip. Name is trimmed and clipped to WaterPreset.maxNameLength
    // here as well as at the field, so no caller can persist one too long to render.
    // Returns false when the cap is reached or the input is unusable.
    @discardableResult
    func addWaterPreset(name: String, milliliters: Double) -> Bool {
        guard canAddWaterPreset, milliliters > 0 else { return false }
        let clipped = String(name.trimmingCharacters(in: .whitespaces)
            .prefix(WaterPreset.maxNameLength))
        guard !clipped.isEmpty else { return false }
        waterPresets.append(WaterPreset(name: clipped, milliliters: milliliters,
                                        isCustom: true))
        return true
    }

    // Built-ins are permanent; only the user's own chips can go.
    func deleteWaterPreset(id: UUID) {
        waterPresets.removeAll { $0.id == id && $0.isCustom }
    }

    // MARK: - Supplements

    // Claude  Date 08/29/2026
    // The stack due on `date`, in the order the card draws it: slots in their own order,
    // supplements by sortIndex within each slot. Only slots whose weekdays include that
    // date contribute — that is what makes a "Weekdays" slot disappear on Saturday.
    func dueSupplements(on date: Date = Date(), calendar: Calendar = .current) -> [Supplement] {
        let dueSlots = supplementSlots.filter { $0.isDue(on: date, calendar: calendar) }
        let rank = Dictionary(uniqueKeysWithValues: dueSlots.enumerated().map { ($1.id, $0) })
        return supplements
            .filter { rank[$0.slotId] != nil }
            .sorted {
                let l = rank[$0.slotId] ?? 0, r = rank[$1.slotId] ?? 0
                return l == r ? $0.sortIndex < $1.sortIndex : l < r
            }
    }

    /// Which supplements are already checked off on `date`.
    func takenSupplementIDs(on date: Date = Date(),
                            calendar: Calendar = .current) -> Set<UUID> {
        Set(supplementLog
            .filter { calendar.isDate($0.takenAt, inSameDayAs: date) }
            .map(\.supplementId))
    }

    /// The supplements assigned to one slot, in the user's order.
    func supplementsInSlot(_ slotId: UUID) -> [Supplement] {
        supplements.filter { $0.slotId == slotId }.sorted { $0.sortIndex < $1.sortIndex }
    }

    // Claude  Date 08/29/2026
    // Check one supplement on or off. TODAY ONLY, deliberately — see Supplement.swift for
    // why (it keeps clearedSupplementDays a real-time ledger rather than a number the user
    // can type in). `at:` takes the exact Date the caller captured when the tap happened
    // instead of re-reading the clock here, and a date that isn't today is refused: the
    // journal's selectedDate is fixed at view construction and there is no .active
    // transition if the app sits open across midnight (RootTabView documents this), so a
    // tap at 00:02 must not land on the day the card was drawn for.
    @discardableResult
    func setSupplement(_ id: UUID, taken: Bool, at now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        guard calendar.isDateInToday(now),
              supplements.contains(where: { $0.id == id }) else { return false }

        let already = supplementLog.contains {
            $0.supplementId == id && calendar.isDate($0.takenAt, inSameDayAs: now)
        }
        if taken {
            guard !already else { return false }
            supplementLog.append(SupplementEntry(supplementId: id, takenAt: now))
        } else {
            guard already else { return false }
            // Un-checking drops the entry but never un-banks the day (see below). The
            // ledger is monotone, so a mis-tap stays undoable in the UI without rewriting
            // progress that was already earned.
            supplementLog.removeAll {
                $0.supplementId == id && calendar.isDate($0.takenAt, inSameDayAs: now)
            }
        }
        bankSupplementDayIfCleared(at: now, calendar: calendar)
        return true
    }

    /// Check off everything still outstanding today, for people who take it all at once.
    func takeAllSupplements(at now: Date = Date()) {
        let calendar = Calendar.current
        guard calendar.isDateInToday(now) else { return }
        let taken = takenSupplementIDs(on: now, calendar: calendar)
        let outstanding = dueSupplements(on: now, calendar: calendar)
            .filter { !taken.contains($0.id) }
        guard !outstanding.isEmpty else { return }
        supplementLog.append(contentsOf: outstanding.map {
            SupplementEntry(supplementId: $0.id, takenAt: now)
        })
        bankSupplementDayIfCleared(at: now, calendar: calendar)
    }

    // Claude  Date 08/29/2026
    // Clear today's check-offs — the counterpart to takeAllSupplements, for a mis-tapped
    // "Take all". Deliberately does NOT un-bank the day in clearedSupplementDays: that
    // ledger is monotone by design (see below), so undoing the tick marks is a UI
    // correction, not a rewrite of earned progress.
    func untakeAllSupplements(at now: Date = Date()) {
        let calendar = Calendar.current
        guard calendar.isDateInToday(now) else { return }
        let due = Set(dueSupplements(on: now, calendar: calendar).map(\.id))
        guard !due.isEmpty else { return }
        supplementLog.removeAll {
            due.contains($0.supplementId) && calendar.isDate($0.takenAt, inSameDayAs: now)
        }
    }

    // Claude  Date 08/29/2026
    // Bank the day once the whole due stack is checked off. Three guards, each covering a
    // way this quietly goes wrong:
    //
    //  1. `!due.isEmpty` — "everything due is taken" is VACUOUSLY TRUE when nothing is due
    //     (no supplements added yet, or a weekday no slot covers). Without this the ladder
    //     pays out every day for merely having the app installed.
    //  2. SupplementTracking.isEnabled — someone who turned the tracker off in Settings
    //     shouldn't keep earning from a stale log.
    //  3. contains(where: isDate(_:inSameDayAs:)) rather than Set.contains — a timezone
    //     change moves what startOfDay resolves to, so one local day can produce two
    //     different Date values. Set.contains would store both and inflate the badge count
    //     by taking a flight. Exactly the reasoning in recordDailyCheckIn.
    //
    // Entries are never removed. Deleting a supplement mid-day can shrink the due set down
    // to something already taken and bank the day; that is worth at most one day per real
    // day, which isn't worth policing. The journal card is a to-do list — THIS is the
    // ledger the achievements read, and the two are allowed to disagree.
    private func bankSupplementDayIfCleared(at now: Date, calendar: Calendar) {
        guard SupplementTracking.isEnabled else { return }
        let due = dueSupplements(on: now, calendar: calendar)
        guard !due.isEmpty else { return }
        let taken = takenSupplementIDs(on: now, calendar: calendar)
        guard due.allSatisfy({ taken.contains($0.id) }) else { return }

        let day = calendar.startOfDay(for: now)
        guard !clearedSupplementDays.contains(where: {
            calendar.isDate($0, inSameDayAs: day)
        }) else { return }
        clearedSupplementDays.insert(day)
        // The didSet only persists — the ladder reads this, so evaluate by hand (same
        // reason markNutritionSetup does).
        evaluateAchievements()
    }

    // MARK: - Supplements: the stack

    var canAddSupplement: Bool { supplements.count < Supplement.maxCount }

    // Name and dose are trimmed and clipped here as well as at the field, so no caller can
    // persist one too long to render. Returns false when the cap is hit or input is unusable.
    @discardableResult
    func addSupplement(name: String, dose: String? = nil, slotId: UUID? = nil) -> Bool {
        guard canAddSupplement else { return false }
        let clipped = String(name.trimmingCharacters(in: .whitespaces)
            .prefix(Supplement.maxNameLength))
        guard !clipped.isEmpty else { return false }
        // Falls back to the first slot, which always exists (see the seed in init).
        guard let slot = slotId ?? supplementSlots.first?.id else { return false }
        let next = (supplementsInSlot(slot).map(\.sortIndex).max() ?? -1) + 1
        supplements.append(Supplement(name: clipped, dose: Self.cleanDose(dose),
                                      slotId: slot, sortIndex: next))
        return true
    }

    func updateSupplement(_ supplement: Supplement) {
        guard let index = supplements.firstIndex(where: { $0.id == supplement.id }) else { return }
        var clean = supplement
        clean.name = String(clean.name.trimmingCharacters(in: .whitespaces)
            .prefix(Supplement.maxNameLength))
        clean.dose = Self.cleanDose(clean.dose)
        guard !clean.name.isEmpty, clean != supplements[index] else { return }
        supplements[index] = clean
    }

    // The log keeps its rows on purpose: they're a dated record of what actually happened,
    // and an orphaned supplementId costs nothing (taken ids are only ever checked against
    // supplements that still exist).
    func deleteSupplement(id: UUID) {
        supplements.removeAll { $0.id == id }
    }

    private static func cleanDose(_ dose: String?) -> String? {
        guard let dose else { return nil }
        let clipped = String(dose.trimmingCharacters(in: .whitespaces)
            .prefix(Supplement.maxDoseLength))
        return clipped.isEmpty ? nil : clipped
    }

    // MARK: - Supplements: reminders

    // Claude  Date 08/29/2026
    // Rebuild the pending reminders from the current schedule. Driven by the two didSets
    // above, and called by hand from the places a didSet can't see: app launch (init
    // assignments never fire didSet, so a schedule loaded from disk was never scheduled in
    // this process), foregrounding (permission can be revoked in the Settings app behind
    // our back), the moment notification permission is granted, and the Settings toggle.
    // CLAUDE  Date 09/24/2026 — also passes today's check-offs, which the optional follow-up
    // reminder needs to know whether anything is still left (see SupplementNotifications).
    func resyncSupplementReminders() {
        SupplementNotifications.resync(slots: supplementSlots, supplements: supplements,
                                       takenToday: takenSupplementIDs(on: Date()))
    }

    // MARK: - Supplements: slots

    var canAddSupplementSlot: Bool { supplementSlots.count < SupplementSlot.maxCount }

    @discardableResult
    func addSupplementSlot(name: String, hour: Int = 8, minute: Int = 0) -> UUID? {
        guard canAddSupplementSlot else { return nil }
        let clipped = String(name.trimmingCharacters(in: .whitespaces)
            .prefix(SupplementSlot.maxNameLength))
        guard !clipped.isEmpty else { return nil }
        let slot = SupplementSlot(name: clipped, hour: hour, minute: minute)
        supplementSlots.append(slot)
        return slot.id
    }

    func updateSupplementSlot(_ slot: SupplementSlot) {
        guard let index = supplementSlots.firstIndex(where: { $0.id == slot.id }) else { return }
        var clean = slot
        clean.name = String(clean.name.trimmingCharacters(in: .whitespaces)
            .prefix(SupplementSlot.maxNameLength))
        // Claude  Date 08/29/2026
        // The no-op guard matters more than it looks: the slot editor writes through on
        // every keystroke and every DatePicker tick, and this property's didSet reschedules
        // notifications. Without it, merely OPENING the editor (onAppear seeds the name
        // field, which fires onChange with the identical value) would rewrite the file and
        // tear down and rebuild every pending reminder.
        guard !clean.name.isEmpty, clean != supplementSlots[index] else { return }
        supplementSlots[index] = clean
    }

    // Claude  Date 08/29/2026
    // Deleting a slot RE-HOMES its supplements rather than deleting them — losing your
    // whole stack because you renamed how the day is split would be a nasty surprise. The
    // last slot can never go: Supplement.slotId is non-optional, so every supplement needs
    // somewhere to live.
    func deleteSupplementSlot(id: UUID) {
        guard supplementSlots.count > 1,
              let fallback = supplementSlots.first(where: { $0.id != id })?.id else { return }
        for index in supplements.indices where supplements[index].slotId == id {
            supplements[index].slotId = fallback
        }
        supplementSlots.removeAll { $0.id == id }
    }

    // The derived diary view for one calendar day (totals + per-meal grouping).
    func nutritionDay(for date: Date) -> NutritionDay{
        NutritionDay(date: date, foodLog: foodLog, waterLog: waterLog)

    }
    

    // Rewrite the home-screen widget's shared snapshot (App Group) and reload its
    // timeline. Called from the foodLog/nutritionGoals/focusGoals didSets and once
    // at launch (from GymAppApp, since didSets don't fire during init). Only the
    // nutrition fields are written here — the theme part belongs to ThemeManager.
    func syncWidgetSnapshot() {
        let today = nutritionDay(for: Date())
        let goal = focusGoals.first
        WidgetSnapshot.update { snapshot in
            snapshot.dayStart = today.date
            snapshot.caloriesToday = today.totals.calories
            snapshot.calorieGoal = nutritionGoals.calories
            snapshot.focusGoal = goal
            snapshot.focusConsumed = goal.map { $0.nutrient.value(from: today.totals) } ?? 0
        }
        WidgetCenter.shared.reloadAllTimelines()
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

    // Claude  Date 08/25/2026
    // The already-saved preset `candidate` would duplicate, or nil if it's new. Compared
    // on content only (WorkoutPreset.contentKey) — same name, icon, exercises, plan, and
    // settings. `candidate` itself is skipped by id so an existing preset can be checked
    // against its neighbours without matching itself, which is what the preset editor does.
    //
    // Every save point runs this and refuses rather than the store rejecting the write:
    // an addPreset that silently dropped its argument would be a trap for the next caller,
    // and each screen needs to say something different about the duplicate it found.
    func duplicatePreset(of candidate: WorkoutPreset) -> WorkoutPreset? {
        let key = candidate.contentKey
        return presets.first { $0.id != candidate.id && $0.contentKey == key }
    }

    // Claude  Date 08/25/2026
    // The preset `installPremade` WOULD produce, resolved against the library as it
    // stands — nothing is created and nothing is persisted. For the duplicate check on
    // the install button, which has to run BEFORE the install mints exercises.
    //
    // Returns nil when any catalog lift is missing from the library, meaning "no duplicate
    // is possible": every saved preset points at exercise ids that already exist, so a
    // template needing a new one cannot match any of them.
    func premadePresetPreview(_ premade: PremadeWorkout, name: String, symbolName: String) -> WorkoutPreset? {
        var created: [Exercise] = []
        var items: [PresetItem] = []
        for item in premade.items {
            guard let exerciseID = resolveExerciseID(for: item, creating: &created),
                  created.isEmpty else { return nil }
            items.append(PresetItem(exerciseId: exerciseID,
                                    targetRepRange: item.reps,
                                    restSeconds: item.restSeconds,
                                    targetSets: item.sets))
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkoutPreset(name: trimmed.isEmpty ? premade.name : trimmed,
                             symbolName: symbolName,
                             items: items,
                             isAdaptive: premade.isAdaptive,
                             premadeID: premade.id)
    }

    func deletePresets(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
    }

    // MARK: - Premade workouts

    // Claude  Date 07/25/2026
    // Install a shipped template (see PremadeWorkout) as a real preset, under the
    // name and icon the user chose on the detail screen. Everything else — rep
    // ranges, planned sets, rest, notes, the adaptive flag — comes from the catalog.
    //
    // The catalog names its lifts as STRINGS rather than ids, because seedExercises
    // mints a fresh UUID per install, so `resolveExerciseID` below does the matching
    // and creates anything missing. Any exercises it has to create are collected and
    // appended in one shot: `exercises` persists in its didSet, so appending inside
    // the loop would rewrite the whole library file once per lift.
    @discardableResult
    func installPremade(_ premade: PremadeWorkout, name: String, symbolName: String) -> WorkoutPreset {
        var created: [Exercise] = []
        // Claude  Date 08/11/2026
        // The catalog's form cues used to land on PresetItem.note. That field is retired
        // (session notes live on workouts now), so they'd vanish on install — and they're
        // worth keeping: a cue like "pause at chest" describes the LIFT, which is exactly
        // what the perma note is for. Collected here, applied below.
        var cues: [(exerciseID: UUID, cue: String)] = []
        let items: [PresetItem] = premade.items.compactMap { item in
            guard let exerciseID = resolveExerciseID(for: item, creating: &created) else { return nil }
            if let cue = item.note?.trimmingCharacters(in: .whitespacesAndNewlines), !cue.isEmpty {
                cues.append((exerciseID, cue))
            }
            return PresetItem(exerciseId: exerciseID,
                              targetRepRange: item.reps,
                              restSeconds: item.restSeconds,
                              targetSets: item.sets)
        }
        if !created.isEmpty { exercises.append(contentsOf: created) }

        // Claude  Date 08/11/2026
        // Apply the cues to blank perma notes only — a lift the user has already annotated
        // keeps THEIR note; a shipped template shouldn't overwrite it. Batched into a single
        // assignment because `exercises` persists in its didSet (same reason the creations
        // above are appended in one shot).
        if !cues.isEmpty {
            var updated = exercises
            var changed = false
            for (exerciseID, cue) in cues {
                guard let index = updated.firstIndex(where: { $0.id == exerciseID }),
                      (updated[index].note ?? "")
                          .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                updated[index].note = cue
                changed = true
            }
            if changed { exercises = updated }
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = WorkoutPreset(name: trimmed.isEmpty ? premade.name : trimmed,
                                   symbolName: symbolName,
                                   items: items,
                                   isAdaptive: premade.isAdaptive,
                                   premadeID: premade.id)
        addPreset(preset)
        // Claude  Date 07/27/2026
        // Picking a premade split is the other way out of the get-started state, so
        // it earns First Step here rather than making the user go start the workout
        // too — the get-started screen offers this and "empty workout" as equals.
        markFirstStep()
        return preset
    }

    // Claude  Date 07/25/2026
    // Turn a catalog lift's NAME into a library exercise id, in priority order:
    //   1. already in the user's library (the normal case) — reuse it;
    //   2. already staged for creation by an earlier item in this same install;
    //   3. a seedExercises lift the user deleted — recreate it with its real metadata
    //      (region, mover, quality…) rather than a bare stub, so graphs and the big-3
    //      achievements still work;
    //   4. a lift outside the seed library — build it from the entry's `fallback`.
    // Anything else is a typo in the catalog: skipped so the preset still installs,
    // with a debug trap so it's caught here rather than shipped.
    // New exercises go into `created` instead of `exercises` — see installPremade.
    private func resolveExerciseID(for item: PremadeExercise, creating created: inout [Exercise]) -> UUID? {
        let name = item.name
        func matches(_ exercise: Exercise) -> Bool {
            exercise.name.caseInsensitiveCompare(name) == .orderedSame
        }

        // Claude  Date 08/18/2026
        // A premade template names a MOVEMENT, not a machine, and a branded version keeps
        // the base name — so a plain name match could silently wire an installed split to
        // the user's Hammer Strength leg press (whichever row came first in the array).
        // Always resolve to the generic lift when one exists; falling back to any match
        // still covers a user who branded every copy and deleted the generic.
        func isGeneric(_ exercise: Exercise) -> Bool { matches(exercise) && exercise.brandLabel == nil }

        if let generic = exercises.first(where: isGeneric) { return generic.id }
        if let generic = created.first(where: isGeneric) { return generic.id }
        if let existing = exercises.first(where: matches) { return existing.id }
        if let staged = created.first(where: matches) { return staged.id }

        guard let template = AppStore.seedExercises.first(where: matches) ?? item.fallback else {
            assertionFailure("Premade workout references unknown exercise \"\(name)\" — "
                             + "add it to seedExercises or give the entry a fallback.")
            return nil
        }
        // Fresh id: the template is a shared static (or catalog literal), so reusing its
        // id would hand two installs the same identity.
        // Every field is copied by hand here, so a new one on Exercise silently stops
        // carrying over unless it's added below (note and equipmentType both bit us).
        let exercise = Exercise(name: template.name, region: template.region,
                                category: template.category, isUnilateral: template.isUnilateral,
                                liftType: template.liftType, primaryMover: template.primaryMover,
                                quality: template.quality, isBodyweight: template.isBodyweight,
                                note: template.note, brand: template.brand,
                                equipmentType: template.equipmentType,
                                cardioMachine: template.cardioMachine)
        created.append(exercise)
        return exercise.id
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
    // 5 lb for everything else. Equipment is modeled now (Exercise.equipmentType), but
    // this still keys off region/liftType — increment-by-equipment (a plate-loaded machine
    // vs. a 5 lb cable stack) is a real behavior change worth doing on its own.
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
        // Claude  Date 09/07/2026
        // Cardio has no working weight to progress — its bouts carry weight = 0, so the scan
        // below would happily "suggest" 0 lb for a treadmill in an adaptive preset.
        guard exercise(for: exerciseId)?.isCardio != true else { return nil }
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
    // (08/04) Carry the preset's own notes onto the workout, so a template's standing
    // instructions are at the top of the page the moment the session starts.
    // Claude  Date 08/11/2026
    // (Notes) Each exercise's note is now a message from your LAST session of this preset
    // rather than a field on the template — see LoggedExercise.noteIsCarriedForward. We
    // read it out of workout history, which is already persisted, instead of storing it on
    // PresetItem: "Override Preset" (updatePreset below) rebuilds every PresetItem from the
    // workout and would silently drop a field it doesn't know to carry.
    func workout(from preset: WorkoutPreset) -> Workout {
        let previous = previousSession(ofPreset: preset.id)
        return Workout(exercises: preset.items.map { item in
            let range = defaultRepRange(for: item.exerciseId, explicit: item.targetRepRange)
            let adaptive = preset.isAdaptive
                ? adaptiveSuggestion(for: item.exerciseId, range: range,
                                     increment: smartIncrement(for: item.exerciseId,
                                                               override: item.weightIncrement))
                : nil
            let carried = carriedNote(for: item.exerciseId, from: previous)
            return LoggedExercise(exerciseId: item.exerciseId, targetRepRange: range,
                                  note: carried, restSeconds: item.restSeconds,
                                  sets: initialSets(for: item, range: range, adaptive: adaptive),
                                  adaptive: adaptive,
                                  noteIsCarriedForward: carried != nil ? true : nil)
        }, notes: preset.notes ?? "", presetID: preset.id)
    }

    // Claude  Date 08/11/2026
    // The most recent FINISHED session of a preset. An abandoned session is skipped rather
    // than consuming the note, so leaving a workout unfinished doesn't quietly eat it.
    private func previousSession(ofPreset id: UUID) -> Workout? {
        workouts
            .filter { $0.presetID == id && $0.isFinished }
            .max { ($0.finishedAt ?? $0.date) < ($1.finishedAt ?? $1.date) }
    }

    // Claude  Date 08/11/2026
    // The note to carry into the new session: only one that was WRITTEN in the previous
    // session. A note that was itself carried has now had its one showing, so it's dropped
    // here — which is the entire expiry mechanism; nothing deletes it, it just stops being
    // copied. Matching is by exerciseId, consistent with updatePreset (and sharing its
    // ambiguity if a preset lists the same lift twice).
    private func carriedNote(for exerciseId: UUID, from previous: Workout?) -> String? {
        guard let prior = previous?.exercises.first(where: { $0.exerciseId == exerciseId }),
              prior.noteIsCarriedForward != true,
              let note = prior.note,
              !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return note
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
        // Claude  Date 09/14/2026 — cardio is done once per workout, not in sets: always
        // exactly one time/distance entry, whatever targetSets the preset carries.
        if exercise(for: item.exerciseId)?.cardioMachine != nil { return [.cardioEntry()] }
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
    // Claude  Date 08/04/2026
    // (08/04) The workout's own notes ride along onto the new preset, so starting
    // from it later brings them back. Blank stays nil rather than "" — the preset
    // editor's field bridges nil↔"" and shouldn't persist an empty string.
    // Claude  Date 08/11/2026
    // (Notes) A logged exercise's note is a message to the NEXT session, not a property of
    // the template, so it is deliberately NOT captured here — capturing it would freeze one
    // session's reminder into the preset forever. It travels through workout history
    // instead (see workout(from:)).
    func makePreset(from workout: Workout, name: String) -> WorkoutPreset {
        WorkoutPreset(name: name, items: workout.exercises.map {
            PresetItem(exerciseId: $0.exerciseId, targetRepRange: $0.targetRepRange,
                       restSeconds: $0.restSeconds,
                       targetSets: logicalSetCount(of: $0))
        }, notes: workout.notes.isEmpty ? nil : workout.notes)
    }

    // Claude  Date 07/13/2026
    // Overwrite an existing preset from a workout ("Override Preset"): rebuild its items
    // to match the workout's current exercises — which lifts are kept vs removed (and
    // their order), each lift's rep range, rest, and logged set count. The preset's
    // own identity (id, name, icon, adaptive toggle) is left untouched, and each surviving
    // item keeps its id and adaptive weight-step override (a preset-only field the workout
    // doesn't carry) by matching on exerciseId. No-op if the preset no longer exists.
    // Claude  Date 07/13/2026 last changed: 08/04/2026 by: Claude
    // (08/04) The workout's notes now overwrite the preset's too — same rule as the
    // items: whatever the workout currently says wins.
    func updatePreset(id: UUID, from workout: Workout) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[index].notes = workout.notes.isEmpty ? nil : workout.notes
        let existing = presets[index].items
        presets[index].items = workout.exercises.map { logged in
            let prior = existing.first { $0.exerciseId == logged.exerciseId }
            // (08/11) The note is not captured — see makePreset. It belongs to the session,
            // not the template.
            return PresetItem(id: prior?.id ?? UUID(),
                              exerciseId: logged.exerciseId,
                              targetRepRange: logged.targetRepRange,
                              restSeconds: logged.restSeconds,
                              weightIncrement: prior?.weightIncrement,
                              targetSets: logicalSetCount(of: logged))
        }
    }
}

// MARK: - Seed data

extension AppStore {
    // Curated, science-based lift library (55 lifts) pre-loaded on first launch, and
    // merged into existing libraries by the version-gated sync in init. `category` is the
    // training sub-group (drives the muscle-group chart / top-muscle stat); `primaryMover`
    // names the muscle the lift drives; `quality` is the Optimal/Classic tag. Only the true
    // powerlifting big-3 carry a `liftType` (squat/bench/deadlift) so the lift achievements
    // stay exact. Editing this list means bumping `seedLibraryVersion` below; renaming a
    // row means adding its old name to `seedRenames` AND updating PremadeWorkout.swift,
    // which resolves its lifts by name and will otherwise mint a duplicate.
    // Claude  Date 09/06/2026
    // Bump this whenever the list below changes — AppStore.init merges the delta into
    // existing libraries once per bump. 1 = the original 48; 2 = +7 lifts, 3 renames;
    // 3 = +5 cardio machines.
    static let seedLibraryVersion = 3

    // Old lowercased name -> current name, for seeds renamed after they shipped. Applied
    // in place by that merge, so the lift keeps its id and all of its history.
    static let seedRenames: [String: String] = [
        "flat barbell bench press": "Barbell Bench Press",
        "deep stretch cable fly":   "Cable Fly",
        "weighted cable crunch":    "Cable Crunch",
    ]

    static let seedExercises: [Exercise] = [
        // MARK: Legs — Quads
        Exercise(name: "Hack Squat", region: .legs, category: "Quads", primaryMover: "Quadriceps", quality: .optimal, equipmentType: .machine),
        Exercise(name: "Barbell Back Squat", region: .legs, category: "Quads", liftType: .squat, primaryMover: "Quadriceps", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Leg Press", region: .legs, category: "Quads", primaryMover: "Quadriceps", quality: .optimal, equipmentType: .machine),
        Exercise(name: "Leg Extension", region: .legs, category: "Quads", primaryMover: "Quadriceps", quality: .optimal, equipmentType: .machine),
        Exercise(name: "Bulgarian Split Squat", region: .legs, category: "Quads", isUnilateral: true, primaryMover: "Quadriceps", quality: .optimal, equipmentType: .freeWeight),

        // MARK: Legs — Hamstrings
        Exercise(name: "Seated Leg Curl", region: .legs, category: "Hamstrings", primaryMover: "Hamstrings", quality: .optimal, equipmentType: .machine),
        Exercise(name: "Romanian Deadlift", region: .legs, category: "Hamstrings", primaryMover: "Hamstrings", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Lying Leg Curl", region: .legs, category: "Hamstrings", primaryMover: "Hamstrings", quality: .classic, equipmentType: .machine),
        Exercise(name: "Stiff-Leg Deadlift", region: .legs, category: "Hamstrings", primaryMover: "Hamstrings", quality: .optimal, equipmentType: .freeWeight),

        // MARK: Legs — Glutes
        Exercise(name: "Hip Thrust", region: .legs, category: "Glutes", primaryMover: "Gluteus Maximus", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Walking Lunge", region: .legs, category: "Glutes", isUnilateral: true, primaryMover: "Gluteus Maximus", quality: .optimal, equipmentType: .freeWeight),
        Exercise(name: "Cable Kickback", region: .legs, category: "Glutes", isUnilateral: true, primaryMover: "Gluteus Maximus", quality: .optimal, equipmentType: .cable),

        // Claude  Date 09/06/2026
        // Two new sub-groups. "Adductors"/"Abductors" were already canonical primary
        // movers in Exercise.commonPrimaryMovers but had no lift using them; the two
        // machines fill that gap. `category` is free text, so no enum change is needed.
        // MARK: Legs — Adductors
        Exercise(name: "Hip Adductor", region: .legs, category: "Adductors", primaryMover: "Adductors", quality: .optimal, equipmentType: .machine),

        // MARK: Legs — Abductors
        Exercise(name: "Hip Abductor", region: .legs, category: "Abductors", primaryMover: "Abductors", quality: .optimal, equipmentType: .machine),

        // MARK: Legs — Calves
        Exercise(name: "Standing Calf Raise", region: .legs, category: "Calves", primaryMover: "Gastrocnemius", quality: .optimal, equipmentType: .machine),
        Exercise(name: "Seated Calf Raise", region: .legs, category: "Calves", primaryMover: "Soleus", quality: .optimal, equipmentType: .machine),

        // MARK: Chest
        Exercise(name: "Incline Barbell Press", region: .chest, category: "Chest", primaryMover: "Pectorals (Upper)", quality: .optimal, equipmentType: .freeWeight),
        Exercise(name: "Barbell Bench Press", region: .chest, category: "Chest", liftType: .bench, primaryMover: "Pectorals", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Cable Fly", region: .chest, category: "Chest", primaryMover: "Pectorals", quality: .optimal, equipmentType: .cable),
        Exercise(name: "Weighted Dip", region: .chest, category: "Chest", primaryMover: "Pectorals (Lower)", quality: .classic, equipmentType: .bodyweight),

        // MARK: Back — Lats
        Exercise(name: "Pull-Up", region: .back, category: "Lats", primaryMover: "Latissimus Dorsi", quality: .classic, equipmentType: .bodyweight),
        Exercise(name: "Wide-Grip Lat Pulldown", region: .back, category: "Lats", primaryMover: "Latissimus Dorsi", quality: .classic, equipmentType: .cable),
        Exercise(name: "Lat Pulldown", region: .back, category: "Lats", primaryMover: "Latissimus Dorsi", quality: .optimal, equipmentType: .cable),
        Exercise(name: "Close-Grip Lat Pulldown", region: .back, category: "Lats", primaryMover: "Latissimus Dorsi", quality: .optimal, equipmentType: .cable),
        Exercise(name: "Single-Arm Cable Pullover", region: .back, category: "Lats", isUnilateral: true, primaryMover: "Latissimus Dorsi", quality: .optimal, equipmentType: .cable),

        // MARK: Back — Mid-Back / Traps
        Exercise(name: "Chest-Supported Row", region: .back, category: "Mid-Back", primaryMover: "Rhomboids / Mid Traps", quality: .optimal, equipmentType: .machine),
        Exercise(name: "Kelso Shrug", region: .back, category: "Mid-Back", primaryMover: "Rhomboids / Mid Traps", quality: .optimal, equipmentType: .freeWeight),
        Exercise(name: "T-Bar Row", region: .back, category: "Mid-Back", primaryMover: "Mid-Back", quality: .classic, equipmentType: .machine),
        Exercise(name: "Seated Cable Row", region: .back, category: "Mid-Back", primaryMover: "Mid-Back", quality: .classic, equipmentType: .cable),
        Exercise(name: "Barbell Shrug", region: .back, category: "Traps", primaryMover: "Upper Trapezius", quality: .optimal, equipmentType: .freeWeight),

        // MARK: Back — Lower Back
        Exercise(name: "Conventional Deadlift", region: .back, category: "Lower Back", liftType: .deadlift, primaryMover: "Spinal Erectors", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Back Extension", region: .back, category: "Lower Back", primaryMover: "Spinal Erectors", quality: .optimal, equipmentType: .machine),

        // MARK: Shoulders — Side Delts
        Exercise(name: "Cable Lateral Raise", region: .shoulders, category: "Side Delts", primaryMover: "Lateral Deltoid", quality: .optimal, equipmentType: .cable),
        Exercise(name: "Dumbbell Lateral Raise", region: .shoulders, category: "Side Delts", primaryMover: "Lateral Deltoid", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Overhead Press", region: .shoulders, category: "Side Delts", primaryMover: "Anterior / Lateral Deltoid", quality: .classic, equipmentType: .freeWeight),

        // MARK: Shoulders — Rear Delts
        Exercise(name: "Reverse Pec Deck", region: .shoulders, category: "Rear Delts", primaryMover: "Posterior Deltoid", quality: .optimal, equipmentType: .machine),
        Exercise(name: "Face Pull", region: .shoulders, category: "Rear Delts", primaryMover: "Posterior Deltoid", quality: .optimal, equipmentType: .cable),

        // MARK: Arms — Biceps
        // Claude  Date 07/11/2026 last changed: 07/11/2026 by: Claude
        // A standard curl for the library. No explicit liftType tag needed — every
        // exercise below counts toward the Bicep Curl badge automatically via
        // Exercise.effectiveLiftType (region == .arms && category == "Biceps").
        Exercise(name: "Barbell Curl", region: .arms, category: "Biceps", primaryMover: "Biceps Brachii", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Incline Dumbbell Curl", region: .arms, category: "Biceps", primaryMover: "Biceps Brachii", quality: .optimal, equipmentType: .freeWeight),
        Exercise(name: "Cable Curl", region: .arms, category: "Biceps", primaryMover: "Biceps Brachii", quality: .optimal, equipmentType: .cable),
        Exercise(name: "EZ-Bar Curl", region: .arms, category: "Biceps", primaryMover: "Biceps Brachii", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Hammer Curl", region: .arms, category: "Biceps", primaryMover: "Brachialis / Brachioradialis", quality: .optimal, equipmentType: .freeWeight),

        // MARK: Arms — Triceps
        Exercise(name: "Overhead Cable Extension", region: .arms, category: "Triceps", primaryMover: "Triceps (Long Head)", quality: .optimal, equipmentType: .cable),
        Exercise(name: "Close-Grip Bench Press", region: .arms, category: "Triceps", primaryMover: "Triceps", quality: .classic, equipmentType: .freeWeight),
        Exercise(name: "Triceps Pushdown", region: .arms, category: "Triceps", primaryMover: "Triceps (Lateral Head)", quality: .classic, equipmentType: .cable),
        Exercise(name: "Single-Arm Triceps Pushdown", region: .arms, category: "Triceps", isUnilateral: true, primaryMover: "Triceps (Lateral Head)", quality: .optimal, equipmentType: .cable),
        Exercise(name: "Skull Crusher", region: .arms, category: "Triceps", primaryMover: "Triceps (Long Head)", quality: .optimal, equipmentType: .freeWeight),

        // MARK: Arms — Forearms
        Exercise(name: "Wrist Curl", region: .arms, category: "Forearms", primaryMover: "Wrist Flexors", quality: .optimal, equipmentType: .freeWeight),
        Exercise(name: "Reverse Wrist Curl", region: .arms, category: "Forearms", primaryMover: "Wrist Extensors", quality: .optimal, equipmentType: .freeWeight),
        Exercise(name: "Farmer's Carry", region: .arms, category: "Forearms", primaryMover: "Grip / Forearms", quality: .classic, equipmentType: .freeWeight),

        // MARK: Core
        Exercise(name: "Cable Crunch", region: .core, category: "Core", primaryMover: "Rectus Abdominis", quality: .optimal, equipmentType: .cable),
        Exercise(name: "Hanging Leg Raise", region: .core, category: "Core", primaryMover: "Rectus Abdominis (Lower)", quality: .optimal, equipmentType: .bodyweight),
        Exercise(name: "Pallof Press", region: .core, category: "Core", isUnilateral: true, primaryMover: "Obliques", quality: .optimal, equipmentType: .cable),
        Exercise(name: "Plank", region: .core, category: "Core", primaryMover: "Transverse Abdominis", quality: .classic, equipmentType: .bodyweight),

        // Claude  Date 09/06/2026
        // First lift in the `.other` region: serratus anterior is a rib/scapula muscle,
        // not a delt head or a lat, so it fits no existing region. isBodyweight stays
        // false like every other seed — PersonalRecord.bests skips bodyweight lifts.
        // MARK: Other — Serratus
        Exercise(name: "Scapular Push-Up", region: .other, category: "Serratus", primaryMover: "Serratus Anterior", quality: .classic, equipmentType: .bodyweight),

        // Claude  Date 09/07/2026
        // Cardio machines. `region: .cardio` earns them their own picker/library section;
        // `cardioMachine` is what actually switches logging to duration + distance.
        // equipmentType stays .machine — a treadmill genuinely is one — which keeps the
        // nameplate chip and brand variants (a Woodway is not a Precor) working unchanged.
        // primaryMover is deliberately blank: cardio drives no single muscle.
        // NOTE: a user who already hand-made their own "Treadmill" keeps it. The merge in
        // init() matches seeds by lowercased name, so theirs wins and never becomes cardio —
        // correct (we never stomp user data), and a two-tap fix in the exercise editor.
        // MARK: Cardio
        Exercise(name: "Treadmill", region: .cardio, category: "Cardio", equipmentType: .machine, cardioMachine: .treadmill),
        Exercise(name: "Stationary Bike", region: .cardio, category: "Cardio", equipmentType: .machine, cardioMachine: .stationaryBike),
        Exercise(name: "Elliptical", region: .cardio, category: "Cardio", equipmentType: .machine, cardioMachine: .elliptical),
        Exercise(name: "Rowing Machine", region: .cardio, category: "Cardio", equipmentType: .machine, cardioMachine: .rower),
        Exercise(name: "Stair Climber", region: .cardio, category: "Cardio", equipmentType: .machine, cardioMachine: .stairClimber),
    ]
}
