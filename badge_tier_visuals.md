# Badge Tier Visuals — how to change them

_Reference for the achievement-badge / rank tier look. Last updated 07/23/2026._

Two files own the entire tier appearance:

| Concern | File | What's there |
|---|---|---|
| **Tier identity** (color, gradient, which tiers sparkle / are gems) | `GymApp/Models/Achievement.swift` → `enum BadgeTier` | `colorHex`, `gradientHexes`/`fillGradient`, `glimmerColor`, `hasPremiumShine`, `hasGemFacets` |
| **Rendering** (the disc, the gem texture) | `GymApp/Views/Achievements/BadgeView.swift` | `BadgeView` (medallion), `GemFacetOverlay` (cut-gem facets), `SparkleField` (twinkle) |

The seven tiers, low→high: `bronze, silver, gold, platinum, diamond, emerald, legend`.

> **Ripple warning:** `StrategistRank.tier` maps 1:1 onto `BadgeTier`
> (`gladiator→platinum`, `centurion→diamond`, `spartan→emerald`, …). Anything read
> off `BadgeTier` — `color`, `fillGradient`, `glimmerColor`, `hasPremiumShine` — is
> **shared** by the Strategist rank ring / emblem (`RankRing.swift`,
> `StrategistRankView.swift`). Change a tier color and the matching rank changes too.
> The **gem facets are the exception**: they live only in `BadgeView`, so they show on
> badges but not on rank rings (which use different arc geometry).

---

## Common edits

### Recolor a tier (or lighten/darken it)
`BadgeTier.colorHex` (line ~28) is the representative solid — used for the glow,
rewards, confetti, and the middle stop of the disc gradient. `gradientHexes` (line
~50) is the disc's `(light, deep)` sheen: `light` is the top-left highlight, `deep`
is the bottom-right shade. To lighten a tier, raise both hexes toward white
(that's exactly what the 07/23 platinum change did: `#3FD0E0`→`#7CE0EC`, and
`("#CDF7FB","#137885")`→`("#E6FBFD","#2FA9BA")`).

### Make a tier a faceted gem (or stop being one)
`BadgeTier.hasGemFacets` — currently diamond / emerald / **legend**. Add a tier here and
its badge (medallion disc + ringless card glyph) renders the `GemFacetOverlay`. The facet
**finish** (highlight colour) is `tier.glimmerColor` — white for diamond/emerald, **gold
for Legend** (which reads pink/purple with a gold finish). Kept separate from
`hasPremiumShine`, though today they overlap.

### Add/remove the twinkling sparkles
`BadgeTier.hasPremiumShine` — currently diamond/emerald/legend. Drives `SparkleField`
on both badges and rank emblems.

### The shine sweep color
`BadgeTier.glimmerColorHex` — white for all tiers except legend (gold). This is the
diagonal gloss that travels across a badge when `glimmer: true`.

---

## Tuning the gem texture (`GemFacetOverlay` in `BadgeView.swift`)

The overlay tessellates the disc into **triangular facets** — an octagonal center
"table" plus two concentric rings of zig-zag triangles (a brilliant cut seen top-
down) — and flat-shades each facet to one of a few discrete light/shadow steps.
Blended `.overlay` so it textures the tier hue without recoloring it. Knobs:

- **`sides`** (`8`) — facets per ring. Higher = finer/denser (better full-screen,
  muddier at tiny sizes); lower = bolder, chunkier facets.
- **`rings`** (`[0.32, 0.63, 1.15]`) — radii as fractions of the disc radius:
  `[table, crown, rim]`. The rim value overshoots >1.0 so facets cover to the round
  edge (excess is clipped). Bigger first value = larger flat top.
- **`steps`** (`[0.26, 0.12, 0.0, -0.15]`) — the discrete shade levels (`+`=white
  highlight, `−`=black shadow). Widen the spread for higher facet-to-facet contrast,
  tighten for subtler texture. Add/remove entries to change how many shade levels.
- **`highlight`** (`.white`) — the facet finish: the colour of the lit facets + the
  specular spot (shadows stay black). Callers pass `tier.glimmerColor`, so Legend gets a
  gold finish for free. Pass any colour to re-tint the whole gem's sheen.
- **`light`** (`(-0.72, -0.69)`) — key-light direction; which facets read brightest.
- **`jUp` / `jDn` jitter** and the `1 + jDn` term — the small deterministic per-facet
  offset that spreads neighbours across steps (the "textured" randomness) and keeps
  inward facets a step darker than outward ones.
- **Specular highlight** — the trailing `.overlay(Circle().fill(RadialGradient(...)))`
  is the soft glassy spot near the light; `.white.opacity(0.6)` / `endRadius` size it.

`GemFacetOverlay` is a standalone `View(diameter:sides:highlight:)` — clip it to any shape
and layer it over a base fill to reuse the look elsewhere.

---

## Gemstone profile cards (earned Diamond / Emerald / Legend cards)

Earning your first diamond / emerald / legend achievement grants a matching gemstone
profile card. The moving parts:

| Concern | Where |
|---|---|
| The cards | `CardStyle.all` ids `gem_diamond` / `gem_emerald` / `gem_legend`, `tier: .gem` |
| "Earned, never sold" gating | `CardStyle.isGrantOnly` (`isFounders \|\| tier == .gem`); used by `ThemeManager.isCardStyleUnlocked` and the `ShopView.fullCatalog` exclusion |
| Card visual | `GemCardBackground(tier:)` in `AnimatedCardBackground.swift` — reuses `GemFacetOverlay(sides: 14)` full-bleed over `tier.fillGradient` + a sweeping gloss |
| Which tier awards which card | `CardStyle.rewardCardID(for: BadgeTier)` |
| Grant + reveal | `RootTabView.syncRewardCards(reveal:)` → `ThemeManager.grantCardStyle(_:)` + `AppStore.celebrateCardUnlock(_:)` → `CardUnlockOverlay` |
| Which tiers are earned | `AppStore.openedTiers` (derived from `openedAchievementIDs` — see the lifecycle section below; this was `unlockedTiers` until 07/24/2026) |

**To add another gem card:** add an `AnimatedCard` case + `accent`, a branch in
`AnimatedCardBackground` returning `GemCardBackground(tier:)`, a `CardStyle` entry
(`tier: .gem`), a `rewardCardID` mapping, and the tier in `syncRewardCards`'s loop
(`[.diamond, .emerald, .legend]`). Gold/other finishes come free via `tier.glimmerColor`.

**Testing:** Settings › Developer (alpha) → **Reset achievements** or **Unlock all
achievements** flips `unlockedAchievementIDs`, and *opening* the resulting gem badge
in the Achievement Book fires the grant + reveal. Silent backfill for already-opened
tiers happens on launch (no reveal).

## Unlock lifecycle: earned vs. opened (07/24/2026)

A badge now has **two** states, and anything that reacts to earning one has to pick
the right one deliberately.

| State | Set | Persisted as | Means |
|---|---|---|---|
| Earned | `AppStore.unlockedAchievementIDs` | `achievements.json` | The criteria were met. Sticky — never removed. |
| Opened | `AppStore.openedAchievementIDs` | `opened_achievements.json` | The user has actually *watched* the reveal. |

`unlocked − opened` = `unopenedAchievementCount`, the red count drawn over the
Profile tab (`AgilTabBar.badgeCounts` → `TabBadge`) and on the Achievements row.

**Nothing auto-plays.** `evaluateAchievements` no longer queues celebrations — a
live unlock just leaves the badge out of `openedAchievementIDs`. Reveals are started
by the user from the Achievement Book: `openAchievement(_:)` (first watch, marked
opened on dismiss) or `replayCelebration(_:)` (re-watch or dev preview, persists
nothing). `RootTabView`'s overlay chain is unchanged and still renders
`CelebrationOverlay` — it just gets its input from a tap instead of a workout.

**Rule of thumb:** a *reward* for reaching a tier (gemstone cards) keys off
`openedTiers`, so it can't arrive before the badge that earned it has been seen.
Anything measuring *progress* (coins, Strategist rank, the card's badge shelf) keys
off `unlockedAchievementIDs` and is unaffected by whether a badge has been opened.

**Where the book lives:** `GymApp/Views/Achievements/AchievementBookView.swift` —
`AchievementBookView` (paged container + progress header), `AchievementBookPage` (one
category spread, 7 tier slots), `AchievementSlotView` (the locked / sealed / opened
states — the sealed one shows `tier.fillGradient` under a `sparkles` glyph, so it
teases the tier while hiding which badge it is), and `AchievementSecretsPage`.

The book **opens on the first spread holding an unopened badge** (`firstUnopenedPage`),
so earning one and walking in lands you on it. "First" is book order — categories left
to right, Secrets at the back — not lowest-tier or most-recent. The jump is latched to
once per visit (`didJumpToNew`); re-targeting as badges are opened would drag the user
off the spread they're reading.

**Secret achievements:** `Achievement.isSecret` (default `false`) moves an entry to
the Secrets page and conceals its name via `displayTitle(unlocked:)` /
`displayDetail(unlocked:)`. Two are authored — `secret_first_step` (bronze, first
completed set) and `secret_first_plan` (bronze, nutrition setup checklist) — and the
page pads to `AchievementShowcase.secretSlotCount` (6) mystery slots. Adding another
is a single `isSecret: true` entry in `Achievement.build(for:)`, no view or store
changes; each carries its own art through the per-achievement `icon` override rather
than its category's `iconName`.

**Testing the book:** Settings › Developer (alpha) → **Unlock all achievements**,
then **Mark all achievements unopened** (`markAllUnopened`) to refill the book with
sealed slots and light the tab count.

## Stat sources: ledger vs. configuration (07/25/2026)

`Achievement.isUnlocked` is a `(ProfileStats) -> Bool`, and until First Plan every
field it could read came from the tamper-resistant activity ledger or the food
diary — see the anti-cheat notes on `ProfileStats.init(events:…)`.

`completedNutritionSetup` is the first exception: it records what the user
*configured*, not what they did. It arrives through a new defaulted `setup:`
parameter on that init, fed from `profile.nutritionSetup` at the single evaluating
call site in `AppStore.evaluateAchievements`.

**Keep this narrow.** It's acceptable for a welcome badge because there is nothing
to cheat — the "achievement" is choosing your own calorie goal. Anything that
competes on progress (volume, lifts, streaks, days) must keep coming from `events`,
or the anti-cheat boundary is worth nothing.

**Two gotchas when adding profile-driven badges:**

1. `AppStore.profile`'s `didSet` **persists but does not evaluate**. Any mutation
   that could unlock something must call `evaluateAchievements()` explicitly — see
   `markNutritionSetup(_:)` and the gender picker in `SettingsView`.
2. Guard the mutator (`markNutritionSetup` returns early if the flag is already
   set). The nutrition goal fields call it on every keystroke; without the guard,
   typing "2400" would rebuild `ProfileStats` over the whole activity log four
   times. For the same reason `nutritionGoals`' `didSet` deliberately does *not*
   evaluate, which is why `daysNutritionOnGoal` refreshes on the next food-log
   change or launch rather than immediately.

**The nutrition setup checklist:** `GymApp/Models/NutritionSetup.swift` (four flags
on `UserProfile.nutritionSetup`) and `GymApp/Views/Nutrition/NutritionSetupCard.swift`,
mounted in the Journal between the date stepper and Summary. `isComplete` covers only
the two required items — `focusGoalsOpened` is a bonus and never gates the badge;
`acknowledged` retires the card without granting anything. The card must never name
First Plan: it's secret, and the reveal belongs to the Book.
