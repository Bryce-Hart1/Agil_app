# Elemental Ring Avatar — Design Spec

## Concept Overview

A fully client-side, procedurally generated profile icon built in SwiftUI.
No image assets required — everything is drawn with `Canvas`, `Path`, and `TimelineView`.

The design is a circular **rune ring** composed of geometric arc segments that evolve
in complexity and color as the user progresses through ranks. The user's initials sit
centered inside, making it feel like a personal crest rather than a generic badge.

---

## Rank System

There are 7 ranks in ascending order:

1. Initiate
2. Squire
3. Warrior
4. Gladiator
5. Centurion
6. Spartan
7. Legend

> **These already exist.** `GymApp/Models/StrategistRank.swift` defines exactly these seven
> ranks, in this order, derived from achievement score by `StrategistScoring`. The ring does
> not introduce a rank model — it renders the existing one. `AppStore` already publishes
> `strategistRank`, `strategistProgress`, and `strategistScore`.
>
> **Rank N lights N segments.** Initiate lights one ("you've started"), Legend lights all
> seven. An earlier draft of this doc filled 0 segments at rank 1 and 7 at rank 7 while
> skipping 2 — eight states across seven segments, which cannot close.

---

## Visual Structure (Layers, inside → out)

| Layer | Description |
|-------|-------------|
| **Core** | User initials, centered. Clean sans-serif or engraved-style font. |
| **Inner Fill** | Solid or gradient circle behind the initials. Darkens with rank. |
| **Inner Ring** | First ring around the core. Appears at rank 2 (Squire). |
| **Segment Ring** | The main ring. Divided into 7 arc segments, one per rank. Each segment activates as the user reaches that rank. Inactive segments are dim/etched. Active segments are filled and colored. |
| **Outer Detail Ring** | A thin outer band. Gains notches, rune marks, or spikes at higher ranks. Appears at rank 4 (Gladiator). |
| **Glow / Aura** | Soft radial glow around the full icon. Appears at rank 6 (Spartan). Color matches rank color. |

---

## Per-Rank Breakdown

### Rank 1 — Initiate
- One segment filled; the remaining 6 slots visible but dim (etched/ghost state)
- Core: initials in muted gray
- No inner ring, no outer detail, no glow
- Color: `BadgeTier.bronze`

### Rank 2 — Squire
- Two segments filled
- Inner ring appears (thin, simple circle)
- Core: initials slightly brighter
- Color: `BadgeTier.silver`

### Rank 3 — Warrior
- Three segments filled
- Inner ring gains a subtle dash pattern or tick marks
- Color: `BadgeTier.gold`

### Rank 4 — Gladiator
- Four segments filled
- Outer detail ring appears (thin band with small notches)
- Inner fill begins to show a very subtle gradient
- Color: `BadgeTier.platinum`

### Rank 5 — Centurion
- Five segments filled
- A small geometric symbol appears in the innermost core behind the initials
  (suggestion: a simple compass cross or diamond — not figurative)
- Outer detail ring gains additional marks
- Color: `BadgeTier.diamond`

### Rank 6 — Spartan
- Six segments filled
- Outer ring gains decorative spikes or rune-style marks between segments
- Soft glow aura activates around the whole icon
- Color: `BadgeTier.emerald`

### Rank 7 — Legend
- All 7 segments fully lit
- Inner core glows
- Aura is fully lit, radiant
- Subtle looping pulse animation on the aura (slow breathe, ~3s cycle)
- Sparkle twinkle via the existing `SparkleField` (gated by `tier.hasPremiumShine`)
- Color: `BadgeTier.legend` — royal purple with a gold glimmer

---

## Color Palette (Rank → Color)

**The ring does not define its own palette.** `StrategistRank.tier` already maps each rank
to a `BadgeTier`, and the ring reads its color from there — so a rank is the same color on
the ring, on the emblem, and on its badges. Reusing the tier also gets `fillGradient`,
`glimmerColor`, and `hasPremiumShine` for free.

| Rank | Name | `BadgeTier` | Color |
|------|------|-------------|-------|
| 1 | Initiate | `.bronze` | `#C77B30` |
| 2 | Squire | `.silver` | `#9AA0A6` |
| 3 | Warrior | `.gold` | `#E6B800` |
| 4 | Gladiator | `.platinum` | `#3FD0E0` |
| 5 | Centurion | `.diamond` | `#8FD3EF` |
| 6 | Spartan | `.emerald` | `#10B981` |
| 7 | Legend | `.legend` | `#5B21B6` + `#FFD479` glimmer |

Inactive segment color: `Color.primary.opacity(0.12)` — the same track color
`StrategistEmblem` uses. This adapts to light and dark automatically, satisfying the
light-mode requirement below without a second palette.

> An earlier draft of this doc proposed an independent stone-gray → gold-white ramp and a
> hardcoded `#2A2A2A` inactive color. Both were dropped: the ramp disagreed with
> `BadgeTier` for the same rank (Initiate is bronze on the emblem but stone gray in that
> ramp; Warrior is gold on the emblem but silver-blue), which would paint one rank two
> different colors on the same card.

---

## Animation

- **Ranks 1–6:** Static. No animation.
- **Rank 7 (Legend) only:** Slow aura pulse. The outer glow breathes in and out
  on a ~3 second loop using `TimelineView` + `withAnimation(.easeInOut)`.
  Subtle — not distracting.

---

## SwiftUI Implementation Notes

- Draw everything in a `Canvas` view or layered `ZStack` with `Path`-based shapes
- Arc segments: use `Path.addArc` with evenly divided angles (360° / 7 ≈ 51.4° each)
  Leave a small gap (~4°) between each segment for visual separation
- Segment state: active vs inactive toggled by comparing `user.rank` to segment index
- Initials: derived from `UserProfile.name` (first + last initial, or first two chars)
- The icon should render cleanly at multiple sizes: 40pt (list row), 80pt (profile header), 120pt (edit screen)
- All colors should support both light and dark mode — the design reads as dark-mode-first
  but should degrade gracefully on light backgrounds

---

## What Opus Should Produce

1. A SwiftUI `RankRing<Core: View>` that accepts `rank: StrategistRank`, `progress: Double`,
   `size: CGFloat`, and a `@ViewBuilder` core — *not* `rank: Int`, and *not* a hardcoded
   initials string. The generic core is what lets the profile card put avatar art inside
   the ring while the friend card puts initials inside the same ring.
2. Draws all layers described above using `Canvas` or `ZStack + Path`
3. Animate the Legend aura with `TimelineView`, gated so ranks 1–6 stay static
4. A preview with all 7 ranks displayed in a vertical list for visual QA
5. No external assets — fully procedural

---

## Files This Will Touch

- `GymApp/Views/Profile/RankRing.swift` — **new**, the primary implementation target
- `GymApp/Views/Profile/ProfileView.swift` — wraps the profile-card avatar in the ring
- `GymApp/Views/Profile/FriendCardView.swift` — ring with an initials core

**Not** `Avatar.swift` or `AvatarView.swift.` An earlier draft of this doc called both of
them stubs. They are not — together they are a shipped, working feature: a 7-character
avatar picker, 3 of them coin-locked (500/1000), with purchases in
`ThemeManager.unlockedAvatarIDs` and the selection persisted on `UserProfile.avatarID`.
Implementing the ring "into" those files would delete a live coin sink.

The ring **frames** the chosen avatar instead: rank earns the outside, coins buy the
inside. See `elemental_ring_avatar_plan.md` for the phased plan and the `SharedCard`
consequence (friends' cards carry `rank` but not `avatarID`, so the friend card takes an
initials core).
