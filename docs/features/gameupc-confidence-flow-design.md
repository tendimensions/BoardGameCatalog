# Design: GameUPC Confidence Flow — Full Three-Scenario Integration

**Status:** Ready for review  
**Date:** 2026-05-09  
**Relates to:** `docs/features/gameupc-feature-requests.md`, REQ-GU-001 through REQ-GU-006  
**Prerequisite reading:** `docs/adr/0003-external-api-integration-strategy.md`

---

## 1. The Three Scenarios

When the mobile app scans a barcode and the server queries GameUPC, the API always
returns one of three distinct responses, distinguished by `bgg_info_status` and the
`new` flag.  The table below summarises the current and target behaviour.

| | Case 1 — Verified | Case 2 — Ambiguous | Case 3 — Unknown |
|---|---|---|---|
| **Test UPC** | `111111111117` | `222222222224` | `333333333331` |
| **GameUPC signals** | `bgg_info_status: "verified"`, single entry in `bgg_info` | `bgg_info_status: "choose_from_bgg_info_or_search"`, 2+ entries in `bgg_info` | `new: true`, `bgg_info` empty |
| **Current behaviour** | ✅ Auto-resolves correctly | ❌ Silently picks first candidate | ⚠️ Saved as `UnlinkedBarcode`; can link to existing collection game only |
| **Target behaviour** | No change | Present candidate list; user selects; post-back to GameUPC | Offer both "link to collection game" and "search BGG by name" |
| **GameUPC post-back required?** | No (mapping already verified) | Yes — `POST /upc/{upc}/bgg_id/{bgg_id}` after user confirms | Yes — same post-back after user confirms |

---

## 2. GameUPC API Response Structures

### Case 1 — Verified

```json
{
  "new": false,
  "bgg_info_status": "verified",
  "bgg_info": [
    {
      "bgg_id": 148228,
      "name": "Splendor",
      "year_published": 2014,
      "min_players": 2,
      "max_players": 4,
      "playing_time": 30,
      "thumbnail": "https://cf.geekdo-images.com/...",
      "image": "https://cf.geekdo-images.com/...",
      "confidence": 1.0
    }
  ]
}
```

Single entry, `confidence` near 1.0.  Auto-resolve — no user interaction needed.

### Case 2 — Ambiguous

```json
{
  "new": false,
  "bgg_info_status": "choose_from_bgg_info_or_search",
  "bgg_info": [
    {
      "bgg_id": 284108,
      "name": "Tiny Towns",
      "year_published": 2019,
      "min_players": 1,
      "max_players": 6,
      "playing_time": 60,
      "thumbnail": "https://cf.geekdo-images.com/...",
      "confidence": 0.72
    },
    {
      "bgg_id": 295895,
      "name": "Tiny Towns: Fortune",
      "year_published": 2020,
      "min_players": 1,
      "max_players": 6,
      "playing_time": 60,
      "thumbnail": "https://cf.geekdo-images.com/...",
      "confidence": 0.55
    }
  ]
}
```

Multiple entries ordered by descending `confidence`.  User must choose.  After
selection the server posts back `POST /upc/{upc}/bgg_id/{chosen_bgg_id}`.

### Case 3 — Unknown

```json
{
  "new": true,
  "bgg_info": []
}
```

GameUPC has never seen this barcode.  User must identify the game, after which the
server posts back the confirmed mapping.

---

## 3. Required Backend Changes

### 3.1  `gameupc.py` — `lookup_barcode()` return type

`lookup_barcode()` currently returns a single `GameUPCResult` or raises.  It needs
to distinguish Case 1 from Case 2 so the caller can handle them differently.

**Proposed change:** Return a `GameUPCLookup` union type:

```python
@dataclass
class GameUPCCandidate:
    bgg_id: Optional[int]
    title: str
    year_published: Optional[int]
    min_players: Optional[int]
    max_players: Optional[int]
    playing_time: Optional[int]
    thumbnail_url: str
    image_url: str
    confidence: float          # new field — was silently dropped before

@dataclass
class GameUPCResult:           # Case 1 — verified, auto-resolvable
    upc: str
    candidate: GameUPCCandidate

@dataclass
class GameUPCCandidates:       # Case 2 — ambiguous, user must choose
    upc: str
    candidates: list[GameUPCCandidate]
```

`lookup_barcode()` raises `GameNotFound` for Case 3 (unchanged).

### 3.2  `POST /api/v1/scan/barcode` — `BarcodeScanView`

**Case 1 (no change):** Auto-resolves and returns the game as today.

**Case 2 (new path):** Returns HTTP 200 with `status: "needs_selection"` and a
`suggestions` array instead of a resolved game.  No game is added to the collection
at this stage.

```json
{
  "status": "needs_selection",
  "upc": "222222222224",
  "suggestions": [
    {
      "bgg_id": 284108,
      "title": "Tiny Towns",
      "year_published": 2019,
      "thumbnail_url": "https://...",
      "confidence": 0.72
    },
    {
      "bgg_id": 295895,
      "title": "Tiny Towns: Fortune",
      "year_published": 2020,
      "thumbnail_url": "https://...",
      "confidence": 0.55
    }
  ]
}
```

**Case 3 (unchanged):** Returns HTTP 404 with `awaiting_link: true`.  The
`UnlinkedBarcode` record is saved as now.

### 3.3  New endpoint: `POST /api/v1/scan/confirm`

Handles the user's selection for Case 2.

**Request:**
```json
{ "upc": "222222222224", "bgg_id": 284108 }
```

**Behaviour:**
1. Validate the `bgg_id` is one of the candidates returned for this UPC (optional
   guard — GameUPC ignores invalid mappings but it's good hygiene).
2. `get_or_create(Game, bgg_id=bgg_id)` — fetch metadata from BGG if the game does
   not yet exist locally.
3. `get_or_create(UserCollection, user=request.user, game=game)`.
4. Stamp `game.upc = upc`.
5. Call `submit_barcode_mapping(upc, bgg_id, request.user.id)`.
6. Return the resolved game.

**Response (HTTP 201 if newly added, 200 if already in collection):**
```json
{
  "game": { ... },
  "added_to_collection": true,
  "submitted_to_gameupc": true
}
```

### 3.4  Extend `POST /api/v1/scan/link` for Case 3 BGG search

Currently `link` only accepts a `game_id` (an existing collection game).  Add an
alternative path that accepts a `bgg_id` directly, for when the user finds the game
via a BGG name search and it is not yet in their collection.

**New request shape (either `game_id` or `bgg_id`, not both):**
```json
{ "upc": "333333333331", "bgg_id": 12345 }
```

**Behaviour when `bgg_id` is supplied:**
1. Fetch game metadata from BGG (`fetch_thing(bgg_id)`).
2. `get_or_create(Game, bgg_id=bgg_id)`.
3. Add to user's collection with `source='barcode'`.
4. Stamp `game.upc`.
5. Call `submit_barcode_mapping()`.
6. Delete `UnlinkedBarcode` record.

### 3.5  New endpoint: `GET /api/v1/games/search?q=<name>`

Proxies a BGG XML API name search so the mobile app can find games by title without
leaving the scan flow.  Returns up to 10 results (title, year, bgg_id, thumbnail).

Used exclusively by the Case 3 "Search BGG" path in the mobile app.

### 3.6  New endpoint: `POST /api/v1/gameupc/test`

Runs all three test UPCs against the configured GameUPC endpoint and returns the raw
results.  Used by the Settings page test UI (Section 6).

**Response:**
```json
{
  "environment": "test | production",
  "results": [
    {
      "upc": "111111111117",
      "case": "verified",
      "status": "ok",
      "title": "Splendor",
      "bgg_id": 148228,
      "candidate_count": 1,
      "error": null
    },
    {
      "upc": "222222222224",
      "case": "ambiguous",
      "status": "ok",
      "title": null,
      "bgg_id": null,
      "candidate_count": 2,
      "error": null
    },
    {
      "upc": "333333333331",
      "case": "unknown",
      "status": "ok",
      "title": null,
      "bgg_id": null,
      "candidate_count": 0,
      "error": null
    }
  ]
}
```

---

## 4. Mobile App — Scan Flow Changes

### 4.1  New `ScanStatus` value

`ScanStatus.needsSelection` is added alongside the existing `awaitingLink`.  The
`scanBarcode()` API service method returns this when the server responds with
`status: "needs_selection"`.

### 4.2  Updated `_onDetect` flow in `ScannerScreen`

```
scan barcode
    │
    ▼
POST /api/v1/scan/barcode
    │
    ├─ game returned (Case 1)
    │   → success beep
    │   → ScanStatus.success
    │   → add to history
    │
    ├─ status: "needs_selection" (Case 2)
    │   → error beep (unknown outcome)
    │   → ScanStatus.needsSelection
    │   → add to history with suggestions stored in ScanResult
    │
    └─ 404 + awaiting_link: true (Case 3)
        → error beep
        → ScanStatus.awaitingLink
        → add to history
```

### 4.3  Tapping a `needsSelection` history card → `CandidateSelectionSheet`

A modal bottom sheet slides up showing the candidates.

**Visual design:**

```
┌─────────────────────────────────────────┐
│  Which game is this?                    │
│  Barcode: 222222222224                  │
│                                         │
│  GameUPC found multiple possible games. │
│  Pick the correct one or dismiss.       │
├─────────────────────────────────────────┤
│ ┌──────┐  Tiny Towns               72% │
│ │ img  │  2019 · 1–6 players           │
│ └──────┘                               │
├─────────────────────────────────────────┤
│ ┌──────┐  Tiny Towns: Fortune      55% │
│ │ img  │  2020 · 1–6 players           │
│ └──────┘                               │
├─────────────────────────────────────────┤
│           [ None of these ]             │
└─────────────────────────────────────────┘
```

- Candidates listed in confidence-descending order.
- Confidence shown as a percentage bar or label.
- "None of these" dismisses the sheet; no game is added; no post-back.
- Selecting a candidate triggers a **confirmation dialog** (see 4.4).

### 4.4  Confirmation dialog for Case 2

Same deliberate confirmation pattern as Case 3 linking:

```
┌──────────────────────────────────────────┐
│  Confirm game                            │
│                                          │
│  Are you sure this is the correct game?  │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  Tiny Towns                      │   │
│  │  2019                            │   │
│  └──────────────────────────────────┘   │
│                                          │
│  Barcode: 222222222224                   │
│                                          │
│  Your selection will be submitted to     │
│  GameUPC.com to help other users.        │
│                                          │
│     [ Cancel ]    [ Yes, that's it ]    │
└──────────────────────────────────────────┘
```

On confirm: `POST /api/v1/scan/confirm` with UPC + chosen bgg_id.  
On cancel: return to candidate sheet.

### 4.5  Tapping an `awaitingLink` history card → `LinkBarcodeScreen` (extended)

The existing `LinkBarcodeScreen` (already built) handles linking to a game already
in the collection.  It needs an additional **"Search BGG by name"** tab/section for
games not yet in the collection.

**Updated layout:**

```
┌─────────────────────────────────────────┐
│  Link Barcode to Game          [Discard]│
│  Barcode not found in GameUPC           │
│  Barcode: 333333333331                  │
├─────────────────────────────────────────┤
│  [My Collection] [Search BGG]           │  ← Tab bar
├─────────────────────────────────────────┤
│                                         │
│  "My Collection" tab (existing):        │
│  Searchable list of collection games    │
│  without a barcode.                     │
│                                         │
│  ── OR ──                               │
│                                         │
│  "Search BGG" tab (new):                │
│  ┌─────────────────────────────────┐   │
│  │ 🔍  Search by game name…        │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [results appear here]                  │
│                                         │
└─────────────────────────────────────────┘
```

**"Search BGG" tab behaviour:**
- User types a game name.
- After 500 ms debounce, calls `GET /api/v1/games/search?q=<name>`.
- Results show thumbnail, title, year.
- Selecting a result shows the same **confirmation dialog** as Case 2.
- On confirm: `POST /api/v1/scan/link` with `upc` + `bgg_id` (new path in Section 3.4).
- Game is created, added to collection, UPC stamped, posted to GameUPC.

---

## 5. Scan Result Card Changes

| Status | Colour | Right-side indicator | Tap action |
|--------|--------|----------------------|------------|
| `success` | Green (added) / Blue (existing) | dot | none |
| `needsSelection` | Amber | `?` icon | opens `CandidateSelectionSheet` |
| `awaitingLink` | Purple | link icon | opens `LinkBarcodeScreen` |
| `notFound` | Amber | dot | none |
| `error` | Red | dot | none |

---

## 6. Settings Page — GameUPC Integration Test

A new **"Test GameUPC Connection"** section is added to the existing `SettingsScreen`.
The section is always visible (test or production environment).

### 6.1  Visual layout

```
┌─────────────────────────────────────────┐
│  GAMEUPC INTEGRATION                    │
│                                         │
│  Environment: [TEST / PRODUCTION]       │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │  [ Run Integration Tests ]         │ │
│  └────────────────────────────────────┘ │
│                                         │
│  (results appear here after tapping)    │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │ ✓  UPC 111111111117 — Verified     │ │
│  │    Splendor (BGG 148228)           │ │
│  │    1 candidate · confidence 100%   │ │
│  ├────────────────────────────────────┤ │
│  │ ✓  UPC 222222222224 — Ambiguous    │ │
│  │    2 candidates returned           │ │
│  │    (Tiny Towns, Tiny Towns:Fortune)│ │
│  ├────────────────────────────────────┤ │
│  │ ✓  UPC 333333333331 — Unknown      │ │
│  │    new: true · no candidates       │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

A single **"Run Integration Tests"** button fires all three at once (one call to
`POST /api/v1/gameupc/test`).  The results panel replaces itself with pass/fail for
each case.

**Pass criteria:**
- Case 1: `status == "ok"` and `candidate_count == 1`
- Case 2: `status == "ok"` and `candidate_count >= 2`
- Case 3: `status == "ok"` and `case == "unknown"`

**Failure states** shown in red with the error message if the API is unreachable or
returns unexpected data.

### 6.2  Implementation notes

- `POST /api/v1/gameupc/test` runs on the server so the API key is never exposed to
  the mobile app.
- The endpoint calls `lookup_barcode()` for each test UPC and returns the structured
  summary above.
- No games are added to any collection; no UPCs are submitted to GameUPC.
- The endpoint is rate-limited to one call per minute per user to avoid hammering the
  test environment.

---

## 7. Implementation Order

Given the dependencies between pieces, the recommended build order is:

1. **`gameupc.py` refactor** — introduce `GameUPCCandidate`, update `lookup_barcode()`
   to detect `bgg_info_status`, return `GameUPCCandidates` for Case 2.

2. **`POST /api/v1/gameupc/test`** — simple endpoint, no mobile changes needed, lets
   you verify the API shape against the live test environment immediately.

3. **Settings page test UI** — thin Flutter widget calling the test endpoint; validates
   the whole stack is wired up before building the selection UI.

4. **Case 2: `BarcodeScanView` + `POST /api/v1/scan/confirm`** — return `suggestions`
   instead of auto-resolving; new confirm endpoint.

5. **Case 2: `CandidateSelectionSheet`** — mobile bottom sheet + confirmation dialog.

6. **Case 3: `GET /api/v1/games/search`** — BGG name search proxy endpoint.

7. **Case 3: Extend `LinkBarcodeScreen`** — add "Search BGG" tab; extend
   `POST /api/v1/scan/link` to accept `bgg_id`.

---

## 8. Open Questions

1. **Case 2 — no game added on dismiss:** If the user sees candidates but taps "None
   of these", should the scan still record anything?  Current proposal: no game added,
   no post-back, scan history shows "Not identified" with amber dot.  Confirm?

2. **Case 3 — retain `UnlinkedBarcode` after BGG search:**  If the user finds the game
   via BGG search and confirms, the `UnlinkedBarcode` is deleted.  If they dismiss the
   BGG search without selecting, should the `UnlinkedBarcode` stay alive so they can
   come back to it?  Current proposal: yes, retain it — consistent with REQ-CM-048.

3. **Confidence display format:**  Show as percentage (`72%`) or bar?  A text
   percentage is simpler to implement and clear enough for this use case.  Confirm?

4. **BGG name search scope:**  Should the search only return games not already in the
   user's collection, or all BGG results?  Proposal: all BGG results, but flag
   "Already owned" inline.  This avoids hiding valid matches.

5. **`POST /api/v1/gameupc/test` auth:**  The test endpoint requires an API key (all
   `/api/v1/` endpoints do).  This is appropriate — only logged-in users should be
   able to trigger it.  Confirm rate-limit of 1 per minute per user?
