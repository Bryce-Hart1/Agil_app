# Backend contract — Food sources, verification & unified search

> Status: spec to implement in the Rust/Axum backend (`agil_backend`). The iOS app side
> (this repo) is already built against this contract: `FoodItem` / `FoodDetail` decode it,
> `BackendFoodClient` calls it, `FoodSubmissionClient` writes to it, `FoodSourceBadge`
> renders it.
> Date: 2026-08-04. Revised same day against the shipped backend — `isRestaurant` /
> `isGeneric` already exist, so the "kind" axis below matches them rather than proposing
> new `source` values.

## Purpose

Every food the app shows should say **where it came from** and **whether a human has vouched
for its numbers**. Those are two independent questions, so they are two independent fields —
not one enum. A Chipotle bowl submitted by a user is `source: "restaurant"` forever; what
changes when Bryce reviews it is `verification`, from `"pending"` to `"verified"`. Collapsing
them would mean relabelling a reviewed Open Food Facts row as "verified" and losing that it
is ODbL-licensed OFF data, which we cannot do (see *Licensing*, below).

Second half of the feature: the Foods tab now has **one search bar** over everything — the
curated vault, OFF, generic (USDA) staples, and restaurant submissions — so `/foods/search`
must stop being an OFF-only proxy and start returning a single blended-ranked list.

## Conventions (match existing backend)

camelCase JSON, ISO-8601 `Z` timestamps, client-supplied UUIDs. No CORS needed (native app).

## The three fields

| axis | field(s) | values |
|---|---|---|
| origin — where the record came from, **immutable** | `source` | `"seed"` (Agil curated vault) · `"openFoodFacts"` · `"userSubmitted"` · `"custom"` |
| kind — what sort of food it is | `isRestaurant`, `isGeneric` | booleans, both default `false` — **already shipped** |
| verification — has a human vouched for it | `verification` | `"verified"` · `"pending"` · `"unverified"` · `null` (unknown) — **the only thing missing** |

Only `verification` is new. Keep `isRestaurant` / `isGeneric` exactly as they are; the client
folds them into one display origin, with the flags winning over `source` because they're the
more specific statement (a submitted Chipotle bowl is `source: "userSubmitted"` +
`isRestaurant: true`, and reads as *Restaurant*).

**`source` is never rewritten.** Verification promotes `verification` and nothing else. This
is a hard rule, not a preference — it is what keeps OFF provenance intact for attribution.

Badge stacking the client does with these (FYI, so the data makes sense):

- vault rows → the brand-pink Agil-mark "Verified" badge, alone. Vault membership *is* verified.
- `isGeneric` / `isRestaurant` → kind badge **plus** a stacked verification badge, always.
- plain `openFoodFacts` → stacks a verification badge only when `verification == "verified"`
  (unverified is the OFF default; badging every OFF row would be noise).
- `custom` → no badge; it's the user's own food.

## Data model — `foods` table

The verification axis already exists server-side as `status` (`pending`/`verified`/`rejected`)
— it just isn't on the wire. Expose it. `rejected` rows must **not** appear in search results
at all; the client has no case for them.

| column | type | notes |
|---|---|---|
| `source` | TEXT | existing. Keep the true origin; the `'verified'` stamp on vault reads goes away (see below) |
| `status` | TEXT | existing. Maps to wire `verification`: `pending`→`"pending"`, `verified`→`"verified"`, anything else→`"unverified"`. `rejected` rows are filtered out of all reads |
| `is_restaurant`, `is_generic` | BOOL | existing, already on the wire. No change |
| `submitted_by` | TEXT NULL | existing; stays server-side, never on the wire |

## Wire changes to `FoodItemDto`

Two breaking bug fixes, then one addition:

1. **Stop sending non-UUID ids.** Verified-vault hits currently come back as
   `"id": "verified:{barcode}"`. Send the row's real UUID. *(The client now derives a stable
   UUID from a non-UUID id rather than throwing — that was a live crash-the-response bug — but
   a derived id can't link back to your row, so send the real one.)*
2. **Stop stamping `source: "verified"`** on vault hits. `"verified"` is not an origin. Send
   the true origin (`"seed"` for curated rows) and put the verified-ness in `verification`.
3. **Add `verification`** (nullable) to every food response — including the one
   `POST /foods/submit` echoes back, so the app can stamp the local copy correctly.

The client decodes both fields tolerantly — unknown `source`/`verification` strings degrade
instead of failing the response — so you can ship these in any order without breaking the app.

`micros` **must be per 100 g/ml**, while `nutrients` is per `servingSize`. The client scales
`nutrients` to a per-100 basis and passes `micros` through untouched, so per-serving micros
would render wrong. If that isn't what the DB holds today, say so rather than converting
silently.

### Exact shape

```json
{
  "id": "9f3b1a2c-4d5e-4f60-8a71-b2c3d4e5f607",
  "name": "Chicken Burrito Bowl",
  "brand": "Chipotle",
  "barcode": null,
  "servingSize": 1,
  "servingUnit": "bowl",
  "servingQuantity": 510,
  "servingLabel": "1 bowl",
  "category": "Restaurant, Mexican",
  "source": "userSubmitted",
  "isRestaurant": true,
  "isGeneric": false,
  "verification": "pending",
  "nutrients": { "calories": 625, "protein": 45, "carbs": 55, "fat": 22 },
  "micros": { "sodium": 1290, "fiber": 8 }
}
```

- `barcode` is `null` for restaurant and most generic foods — it is not a required key.
- `category` is comma-separated, most-general term first (drives the detail page's chip).
- `micros` is sparse; a missing nutrient renders as "not available", a real `0` renders `0`.

## `GET /foods/search?q=…`

Today this proxies OFF live and stamps every result `openFoodFacts`, so the vault is
unreachable by text. It must become the unified endpoint: query the curated vault, the local
`foods` table (OFF cache, generic, restaurant) **and** the OFF upstream, merge, dedupe, rank,
return.

- `200` → JSON array of `FoodItemDto`, **in ranked order**. The client renders server order
  verbatim and never re-sorts.
- `200` with `[]` → no matches (not a 404).
- Empty/whitespace `q` → `200` with `[]`.
- Upstream OFF failure → still `200` with whatever local results exist. Never fail the whole
  search because a third party is down.

**Dedupe** on barcode, highest trust wins (vault > verified > pending > unverified). Restaurant
foods have no barcode, so near-duplicate submissions are the review queue's problem, not the
API's — don't invent fuzzy name-merging here.

**Latency**: blended ranking that blocks on a live OFF fetch will feel broken on a phone. Give
the upstream call a hard budget (~1.5–2 s) and return local results without it on timeout. The
client debounces 400 ms between keystrokes, so you'll see roughly one request per typed word.

### Ranking — relevance with a trust boost

The requirement is *blended*, not tiered: a strong name match on an unverified food should be
able to outrank a weak match on a verified one. Multiplicative does that naturally:

```
score = textScore × trustMultiplier
```

| textScore | when |
|---|---|
| 1.0 | query equals the food name |
| 0.9 | name starts with the query |
| 0.7 | a word in the name starts with the query |
| 0.5 | name contains the query |
| 0.4 | only the brand matches |

| trustMultiplier | for |
|---|---|
| 1.0 | vault rows (curated) |
| 0.95 | `verification == "verified"` (any origin) |
| 0.85 | `isGeneric` regardless of status (USDA-grade data) |
| 0.8 | `verification == "pending"` |
| 0.7 | everything else (unverified OFF / restaurant) |

Ties break toward the higher trust tier, then shorter name. **The constants are yours to
tune** — the contract is the *ordering intent*: verified foods surface first for comparable
matches, and an exact name match never gets buried under a fuzzy verified one. FTS5 `bm25`
normalized to 0–1 is a fine substitute for the `textScore` table.

## Restaurant submissions

Restaurant foods are user-entered (someone looks up Chipotle's published macros and types
them in). The app now has the UI for this — `NewFoodView` → `FoodSubmissionClient` — and it
rides the **existing** pipeline, so no new endpoints:

- `POST /foods/submit` with `isRestaurant: true`, `brand` = the chain name, and no `barcode`.
  Row lands `status = pending`, `submitted_by` from the authenticated card. Unchanged.
- `GET /foods/pending`, `POST /foods/{id}/verify`, `POST /foods/{id}/reject` are unchanged —
  Bryce's manual review queue, the only thing that promotes a food.
- Pending foods **are** searchable (amber "In review" badge). Rejected ones are not.
- Micros arrive in `nutrimentsJson` with OFF keys in OFF's base units, per 100 g/ml — the
  client divides by the `MICRO_MAP` factor so the server's multiply lands back on the value
  the user typed. Fields the user left blank are **omitted**, never sent as `0`.

Same pipeline promotes OFF rows: reviewing an OFF food sets `verification: "verified"` and
leaves `source: "openFoodFacts"`.

### ⚠️ Restaurant foods can never be verified as things stand

This needs a decision before the feature is honest with users. From `verified_fields_list.md`:
the vault is **keyed by a numeric barcode ≤ 48 bits**, `food_to_vault_record()` returns `None`
without one, and `POST /foods/{id}/verify` answers **400**. Restaurant menu items have no
barcode. So today a restaurant submission enters the review queue and can be approved by a
human but **cannot physically enter the vault** — it is permanently stuck at `pending`.

Three ways out, in order of preference:

1. **Serve verified-but-unvaulted rows from SQLite.** Let `status = verified` mean verified
   regardless of vault membership; the vault stays the barcode-keyed fast path for scanning,
   and search reads both. Cheapest, no format change, and it's already almost true — search
   has to hit SQLite anyway.
2. **Synthetic barcodes in a reserved range.** Assign restaurant rows keys from a namespace
   real GTINs never occupy (e.g. `≥ 900_000_000_000`), so they vault normally. Costs nothing
   at read time, but invents an identifier that means nothing off-device, and a scan can
   never match it.
3. **Add a nullable key to the vault format.** Correct, and the most expensive: the record
   layout has no version header, so any field change invalidates `foods_vault.bin` and forces
   a full rebuild from SQLite.

Recommendation: **(1)**. Until it's decided, the app labels these foods "In review" and does
not promise they'll ever become verified.

## Licensing

- **OFF data is ODbL.** Attribution is required, and share-alike attaches to the *database*.
  Keeping `source: "openFoodFacts"` on promoted rows is what makes attribution possible at all
  — do not let verification launder OFF rows into the curated vault's identity. If a food is
  ever meant to become cleanly Agil-owned, its numbers must be re-entered from the label as
  independent facts, as a new `seed` row, not by flipping a column on the OFF row.
- **USDA FoodData Central is public domain** — no restrictions, import freely.
- **Restaurant nutrition facts are facts**, not copyrightable, and US chains are required to
  publish them. Storing user-entered macros under a chain's name is fine; don't ingest chains'
  marketing copy or logos along with the numbers.

## Out of scope (future)

USDA ingestion itself (the wire shape is reserved — `isGeneric: true`, imported
`verification: "verified"` since USDA data is authoritative — but nothing ingests it yet, and
which subset to take (Foundation + SR Legacy?) is undecided). Also: fuzzy cross-source name
dedupe, per-user submission moderation/rate limits, client-side re-ranking, and search
pagination.

Two smaller things noted from `verified_fields_list.md`, not blocking:

- The vault has **no `category` field**, so verified foods return `category: null` and lose
  their icon hint. Adding one changes the binary format (full rebuild), so it can wait — but
  the app does display category for every other source, so verified foods look thinner.
- **Lossy text**: `encode_string` lowercases and maps spaces to `?`, so a vault name reads
  back as `"chocolate?milk"`. The app currently renders the name it's given. Either the
  server should serve the display name from SQLite alongside the vault numbers, or the app
  needs a de-mangling pass — the first is much better. Flagging because it's user-visible
  the moment verified foods start appearing in search results.
