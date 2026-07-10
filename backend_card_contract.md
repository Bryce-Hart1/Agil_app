# Backend contract — Shared Profile Card

> Status: spec to implement in the Rust/Axum backend (`agil_backend`). The iOS app side
> (this repo) is built against this contract: `BackendClient` + `CardSyncService`.
> Date: 2026-06-18.

## Purpose & privacy stance

The app's first backend tie-in is deliberately tiny so it can be marketed as privacy-first.
**The only things that ever leave the device** are a user's public id (their *friend code*)
and the contents of their **profile card**. Workouts, nutrition, water, the full earned-
achievement set, and any future bodyweight/sex/height fields are never sent.

This build is **plumbing only**: upload my card, fetch a card by id. No friend graph yet.

## Identity & auth (anonymous id + secret key)

- The device generates, on first opt-in to Friends mode: a public `user_id` (random UUID,
  the friend code) and a 256-bit secret `key` stored only in the device Keychain.
- **Reads are public** — a friend only needs your `user_id`.
- **Writes carry the secret** in the `X-Card-Key` header. The server uses **trust-on-first-
  use**: the first `PUT` for an id stores `sha256(key)`; later writes must present a key whose
  SHA-256 matches, else `403`. Squatting is mitigated by the id being an unguessable 128-bit
  UUID. No JWT, no accounts, no email (those come later with B2).
- Store only `sha256(key)` (hex). SHA-256 is fine for alpha; argon2 can arrive with B2.

## Conventions (match existing backend)

camelCase JSON, ISO-8601 `Z` timestamps, client-supplied UUIDs. No CORS needed (native app).

## Data model — new `cards` table

Standalone, keyed by the app's `user_id`. **Do not** couple to the unbuilt `users`/accounts table.

| column | type | notes |
|---|---|---|
| `user_id` | TEXT PRIMARY KEY | the public friend code (UUID string) |
| `display_name` | TEXT | |
| `card_style_id` | TEXT | a `CardStyle.id`, e.g. `"nebula"` |
| `shows_rank_on_card` | INTEGER | bool 0/1 |
| `rank` | INTEGER NULL | StrategistRank raw value 0–6 (pawn=0 … legendKing=6); null when not equipped |
| `rank_progress` | DOUBLE | 0…1 ring fill |
| `showcased_achievement_ids` | TEXT | JSON array string, ≤4 ids |
| `member_since` | TEXT NULL | ISO-8601 |
| `card_key_hash` | TEXT | `sha256(key)` hex — set on first write (TOFU) |
| `created_at` | TEXT | ISO-8601 |
| `updated_at` | TEXT | ISO-8601 |

## Endpoints

### `GET /cards/{id}`

Public read. → `200` with the `SharedCard` JSON, or `404` if absent. No key required.

### `PUT /cards/{id}`  (header `X-Card-Key: <secret>`)

Upsert the card. Body is the `SharedCard` (see below); `{id}` must equal body `userId`.

- Row absent → insert, store `card_key_hash = sha256(key)`, `201`.
- Row present and `sha256(key) == card_key_hash` → update, `200`.
- Row present and key mismatch → `403`.
- Missing/empty key → `401`.

### `DELETE /cards/{id}`  (header `X-Card-Key: <secret>`)

→ `204` on success, `403` on key mismatch, `404` if absent. Used when a user switches back
to Offline so their shared card is actually removed.

## `SharedCard` JSON (exact shape the app sends/expects)

```json
{
  "userId": "f1c2a0d6-3b9e-4e2a-9c77-2b4a1e0c9aef",
  "displayName": "Bryce",
  "cardStyleID": "nebula",
  "showsRankOnCard": true,
  "rank": 2,
  "rankProgress": 0.42,
  "showcasedAchievementIDs": ["squat_135", "logged_30"],
  "memberSince": "2026-06-09T00:00:00Z",
  "updatedAt": "2026-06-18T21:54:00Z"
}
```

- `rank` is `null` when `showsRankOnCard` is false (or no rank equipped).
- `memberSince` and `updatedAt` may be `null`.
- The server may set/overwrite `updatedAt` server-side; the app also sends its own.

## Out of scope (future)

Friend graph (add/remove/list), uploading the full earned-achievement set, real accounts
(B2 email/password + JWT/argon2), HTTPS/prod host, rate limiting, conflict resolution.

```
