import Foundation

// Claude  Date 06/14/2026
// Phase 2 anti-cheat tunables for achievement credit. Phase 1 made badges derive
// from the real-time activity ledger (so days/streak can't be backdated); these
// constants harden the two remaining pure-number badges — Big-3 lift and Total
// Lifted volume — which a single completed set could otherwise fake.
//
// All values are deliberately generous: a legitimately training user never brushes
// against them, while one-session / single-day fabrication does. Tune here only —
// the logic that applies them lives in ProfileStats(events:).
enum AchievementPolicy {
    // A completed set only counts toward credited lift/volume stats when its reps
    // and weight are humanly plausible. Bounds sit well past real-world maxima, so
    // they reject garbage (e.g. 9999×9999) without touching real training.
    static let maxPlausibleReps = 100
    static let maxPlausibleWeight = 1_500.0   // lb — beyond any human single lift

    // Most volume (Σ reps×weight, in lb) a single calendar day can contribute toward
    // the Total Lifted badges. Forces the big milestones to take real elapsed days:
    // at 50k/day, "Ten Million" needs ~200 days. A hard session rarely tops ~30k, so
    // genuine lifters are unaffected.
    static let dailyVolumeCap = 50_000.0

    // A big-3 weight must be reached on at least this many distinct days before it
    // counts toward a lift badge — so one fake heavy set can't unlock a tier. The
    // credited best becomes the Nth-highest of the per-day best big-3 lifts.
    static let big3ConfirmationDays = 2
}
