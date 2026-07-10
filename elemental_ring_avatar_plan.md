# Elemental Ring Avatar — Implementation Plan

Companion to `elemental_ring_avatar_design.md`. That doc describes *what* the ring looks
like; this one describes *how it lands in the codebase* and what it must not break.

---

## Key finding: this is a view-layer feature

The rank system the ring correlates to **already exists**. `GymApp/Models/StrategistRank.swift`
defines the same seven ranks in the same order as the design doc (Initiate → Legend),
derived from achievement score via `StrategistScoring` (thresholds 0/8/24/45/75/110/150,
max score 168).

`AppStore` already exposes everything the ring needs:

| Property | Meaning |
|---|---|
| `store.strategistRank` | current `StrategistRank` |
| `store.strategistProgress` | 0…1 toward the next rank |
| `store.strategistScore` | raw score |

So: **no model changes, no persistence changes, no `SharedCard` changes, no backend work,
no migration.** The ring is a new view fed by existing state.

---

## What the ring must not break

`Avatar.swift` and `AvatarView.swift` are **not stubs** (the design doc says they are —
that claim is wrong and has been corrected). They are a shipped feature:

- A GamePigeon-style avatar picker with 7 characters, 3 coin-locked (500 / 1000).
- Purchases tracked in `ThemeManager.unlockedAvatarIDs`; all spend flows through
  `ThemeManager.coinsSpent`.
- Selection persisted on `UserProfile.avatarID`.
- Custom art is planned but not yet imported; `AvatarView` falls back to an SF Symbol.

**Decision: the ring frames the avatar, it does not replace it.** Coins buy the inside,
rank earns the outside. The coin sink and the planned art both survive.

---

## The `SharedCard` gap the ring happens to fix

`SharedCard` (the entire payload that leaves the device in Friends mode) carries
`rank` and `rankProgress` but **not** `avatarID`. `ProfileCard.avatarID` defaults to
`Avatar.defaultAvatar.id`, so **`FriendCardView` currently renders the default avatar for
every friend.**

Because the ring is rank-driven and rank *does* sync, the ring renders correctly for
friends with zero backend work. And the design doc's original "initials in the core" idea
is exactly the right core for the friend card, where avatar art isn't available.

One component, two cores:

| Surface | Core content |
|---|---|
| Your own `ProfileCard` | `AvatarView` (the avatar you picked) |
| `FriendCardView` | Initials, derived from `displayName` |

---

## Corrections to the design spec

1. **Off-by-one in segment counts.** The doc filled 0 segments at rank 1, 1 at rank 2,
   then jumped to *3* at rank 3 (skipping 2), and 7 at rank 7 — eight states across seven
   segments. It cannot close. **Resolved: rank N lights N segments.** Initiate gets one lit
   "spark," Legend lights all seven.

2. **Color ramp conflict.** The doc proposed stone-gray → bronze → gold-white. But
   `StrategistRank.tier` already maps each rank to a `BadgeTier` color, and the two ramps
   disagree for the same rank (Initiate is bronze on the emblem, stone gray in the doc;
   Warrior is gold on the emblem, silver-blue in the doc). Shipping both would paint one
   rank two colors on the same card. **Resolved: the ring uses `rank.tier`**, inheriting
   `color`, `fillGradient`, `glimmerColor`, and `hasPremiumShine` for free.

3. **Inactive segment color.** The doc hardcodes `#2A2A2A`. **Resolved: use
   `Color.primary.opacity(0.12)`** — what `StrategistEmblem` already uses for its progress
   track — which satisfies the doc's own "must degrade gracefully on light backgrounds"
   requirement automatically.

---

## Phases

**Status:** Phase 1 ✅ · Phase 2 ✅ (initials core, Centurion glyph) · Phase 3 ✅ · Phase 4 ⬜ (manual QA) · Phase 5 ✅

**Design decision — fill semantics (RESOLVED).** `RankRing.fillMode` has two readings:
- `.rankSegments` — N of 7 lit = rank; a map of the whole ladder.
- `.rankProgress` — the 7 segments fill continuously with `strategistProgress` toward the
  next rank; rank shown by color + the title text under the name.

Final wiring:
- **Your own card** (`ProfileView`, `EditProfileCardView` preview) → `.rankProgress`. The
  ring is your personal "how close am I to the next rank" meter.
- **Friends viewing your card** (`FriendCardView`) → `.rankSegments` (the default). They see
  your rank crest, **not** your progress — progress-to-next stays private.
- **Promotion overlay** (`RankPromotionOverlay`) → `.rankSegments` with the reveal sweep,
  unchanged.

`ringFillMode` is a param on `ProfileShowcaseCard`, defaulting to `.rankSegments`, so the
friend path needed no change.

Phase 5 added `RankRing.revealProgress` (0…1 sweep of the newest lit segment, default 1 =
static) + a mid-sweep glimmer flare. `RankPromotionOverlay` now shows the RankRing (rank
glyph in the core) and animates `reveal` 0→1 after the crest springs in.

**Dev tooling:** `GymApp/Views/Profile/RankRingLabView.swift` (`#if DEBUG`), linked from
Settings → "Rank ring lab". Live sliders for rank / size / reveal / progress, an
all-ranks row, and one-tap buttons that fire the real promotion overlay per rank via
`store.previewPromotion`. Ships only in Debug builds.

### Phase 1 — `RankRing.swift` (isolated, no integration)
New file `GymApp/Views/Profile/RankRing.swift`. A `RankRing<Core: View>` taking
`rank`, `progress`, `size`, and a `@ViewBuilder` core. Draws every layer from the design
doc's table: 7-segment ring (51.43° arcs, 4° gaps), inner ring from rank 2, outer detail
band from rank 4, aura from rank 6, Legend pulse. Reuses `SparkleField` for the Legend
twinkle rather than reimplementing a glow. Ships with a preview of all 7 ranks.

Nothing else in the app changes, so this is fully reviewable in isolation.

### Phase 2 — Cores
- `AvatarView` core for `ProfileCard`.
- Initials core for `FriendCardView`.
- The Centurion "small geometric symbol behind the initials" (design doc, rank 5).

### Phase 3 — Integration
- Wrap the 92pt avatar at `ProfileView.swift:176` in the ring.
- The separate 44pt `StrategistEmblem` under the name (`ProfileView.swift:187`) becomes
  redundant — the ring already encodes rank. Drop the emblem there, keep the rank *title*
  text. The emblem stays in `StrategistRankView` and its ladder rows.
- **Resolved:** `ProfileShowcaseCard.rank` is already `nil` when `showsRankOnCard` is off
  (both call sites pass `showsRankOnCard ? rank : nil`), so that nil *is* the ring gate —
  rank present → ring frames the avatar; rank nil → bare avatar, no ring. No new flag.
- `ProfileShowcaseCard.avatarID` became `String?` (nil = friend, who has no synced avatar
  → initials core). The core is sized to the ring's central slot via
  `RingGeometry.coreDiameter(for:)`.

### Phase 4 — Previews / QA
All 7 ranks at 40 / 80 / 120pt, light and dark.

### Phase 5 — The rank-up moment
`RankPromotionOverlay` already exists. Animate the newly-lit segment on promotion. This is
the payoff and it is cheap once Phase 1 lands.

---

## Risks designed around

- **Legibility at 40pt.** Seven segments plus outer notches mush together in a list row.
  The outer detail ring drops out below ~56pt.
- **Redraw cost.** `TimelineView(.animation)` redraws every frame. It is gated behind
  `rank == .legend`; ranks 1–6 are a static `Canvas`. A scrolling list of non-Legend rings
  costs nothing.
- **Gradient in `Canvas`.** `BadgeTier.gradientHexes` is private, so the ring draws its
  segments white into a `Canvas` and uses that as a `.mask()` for `tier.fillGradient`.
  This gets the material gradient without widening `BadgeTier`'s API.

---

## Files

| File | Change |
|---|---|
| `GymApp/Views/Profile/RankRing.swift` | **new** |
| `GymApp/Views/Profile/ProfileView.swift` | modified (Phase 3) |
| `GymApp/Views/Profile/FriendCardView.swift` | modified (Phase 3) |
| `GymApp/Views/Achievements/StrategistRankView.swift` | possibly (ladder rows) |
| `GymApp/Models/Avatar.swift` | **untouched** |
| `GymApp/Views/Profile/AvatarView.swift` | **untouched** |
| `GymApp/Models/SharedCard.swift` | **untouched** |
| `project.yml` | **untouched** (sources glob the `GymApp` dir) |
