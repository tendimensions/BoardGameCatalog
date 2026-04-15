# Feature Requests: GameUPC Confidence Flow

**Branch:** `feature/game-lists` (tracked here; may be implemented in a separate branch)  
**Status:** Draft — implementation not yet started  
**Date:** 2026-04-12  
**Source:** Email from GameUPC.com operator

---

## Background

The GameUPC.com operator has requested that the app implement distinct code paths for
each of the three confidence states their API can return when a barcode is scanned.
They also provided test UPCs to exercise each case:

| Test UPC | Case |
|----------|------|
| `111111111117` (or `1`) | Strong verified result |
| `222222222224` (or 2) | Some data — user must choose |
| `333333333331` (or 3) | No data — user must look up the game |

A PDF of printable barcodes for these test values is available from GameUPC.

---

## Current Implementation Status

### Case 1 — Verified result (`111111111117`)

**What GameUPC returns:** `bgg_info` populated with a single high-confidence entry.
`bgg_info_status` is `"verified"` (or equivalent).

**Current behaviour:** `lookup_barcode()` in `gameupc.py` checks that `bgg_info` is
non-empty, takes `bgg_info[0]`, and auto-resolves the game. `BarcodeScanView` adds it
to the collection without user interaction.

**Status: ✅ Implemented correctly.** No BGG ID post-back is required for this case —
the mapping is already verified in the GameUPC database.

---

### Case 2 — Suggestions (`222222222224`)

**What GameUPC returns:** `bgg_info` contains multiple candidate games.
`bgg_info_status` is `"choose_from_bgg_info_or_search"`.

**Current behaviour:** `lookup_barcode()` does not check `bgg_info_status`. It takes
`bgg_info[0]` — the first candidate — and treats it as a confirmed result. The game is
silently added to the collection as if the match were verified. The user is never shown
the candidates and never asked to confirm. No BGG ID is posted back to GameUPC.

**Status: ❌ Not implemented. Behaviour is incorrect.**

The first candidate may be wrong. By silently accepting it the app risks adding the
wrong game to the user's collection and provides no contribution back to GameUPC's
crowdsourced data.

**What needs to be built:**

- `lookup_barcode()` must detect `bgg_info_status == "choose_from_bgg_info_or_search"`
  and return all candidates to the caller rather than auto-resolving.
- `POST /api/v1/scan/barcode` must return a `suggestions` array to the mobile app
  instead of a resolved `game` object when candidates are present.
- The mobile app must display a selection sheet listing each candidate (thumbnail,
  name, year, confidence score) and prompt the user to pick the correct one or dismiss.
- Once the user selects a game, the mobile app posts the confirmed BGG ID back to the
  server, which calls `submit_barcode_mapping()` to submit to GameUPC via
  `POST /upc/{upc}/bgg_id/{bgg_id}`.
- If the user dismisses without selecting, no game is added to the collection and no
  post-back is made.

---

### Case 3 — No data (`333333333331`)

**What GameUPC returns:** `new: true` with empty `bgg_info`. GameUPC has no knowledge
of this barcode.

**Current behaviour:** `lookup_barcode()` detects `new: true` / empty `bgg_info` and
raises `GameNotFound`. `BarcodeScanView` saves an `UnlinkedBarcode` record and returns
`awaiting_link: true`. The mobile app can then link the barcode to a game already in
the user's collection, after which the server posts the BGG ID back to GameUPC via
`submit_barcode_mapping()`.

**Status: ⚠️ Partially implemented.**

The existing `UnlinkedBarcode` flow (REQ-CM-040 through REQ-CM-049) handles the case
where the game is already in the user's collection. What is missing is the ability to
look up the game by name when it is not yet in the collection.

The GameUPC operator's request is specifically: "need input from you to look up the
game" — meaning the user should be able to search for the correct game (by name, via
BGG search) directly within the scan flow, without first having to add it to their
collection through a separate step.

**What needs to be built:**

- When an `UnlinkedBarcode` is saved and the game is not in the user's collection, the
  mobile app must offer an additional option: **"Search for this game"** — a text
  search field that queries BGG by name.
- The search results (title, year, thumbnail) are displayed and the user selects the
  correct game.
- Upon confirmation, the server:
  1. Creates the `Game` record if it does not already exist (using BGG metadata).
  2. Adds the game to the user's collection.
  3. Stamps the UPC onto the game record.
  4. Submits the mapping to GameUPC via `POST /upc/{upc}/bgg_id/{bgg_id}`.
  5. Deletes the `UnlinkedBarcode` record.
- If the user dismisses without selecting, the `UnlinkedBarcode` record is retained so
  they can link it later (existing REQ-CM-048 behaviour).

---

## Requirements

### REQ-GU-001 — Case 2: Return candidates to mobile app

`POST /api/v1/scan/barcode` must detect the `choose_from_bgg_info_or_search` confidence
state and return a `suggestions` array instead of a resolved game:

```json
{
  "status": "needs_selection",
  "upc": "222222222224",
  "suggestions": [
    {
      "bgg_id": 12345,
      "title": "Some Game",
      "year": 2018,
      "thumbnail_url": "https://...",
      "confidence": 0.85
    },
    ...
  ]
}
```

### REQ-GU-002 — Case 2: Mobile selection UI

The mobile app must present a selection sheet when it receives `status: "needs_selection"`.
The sheet must show each candidate with thumbnail, name, and year. The user picks one or
dismisses. Dismissing records no game and makes no post-back.

### REQ-GU-003 — Case 2: Confirm selection endpoint

A new endpoint (or extension of the existing scan endpoint) must accept the user's
chosen BGG ID and UPC, resolve/create the game, add it to the collection, and submit
the mapping to GameUPC:

```
POST /api/v1/scan/confirm
{
  "upc": "222222222224",
  "bgg_id": 12345
}
```

### REQ-GU-004 — Case 3: In-app BGG name search

When a Case 3 barcode is scanned (no GameUPC data), the mobile app must offer a BGG
name search in addition to the existing "link to collection game" option. This search
uses the existing BGG API integration to find games by name.

### REQ-GU-005 — Case 3: Create game from search result

When a user selects a game from the BGG name search (REQ-GU-004), the server must
create the `Game` record (if it does not exist), add it to the user's collection, stamp
the UPC, submit to GameUPC, and clean up the `UnlinkedBarcode` record — all in a single
`POST /api/v1/scan/link` call extended to accept a `bgg_id` in addition to `game_id`.

### REQ-GU-006 — Test UPCs

The development and QA process must exercise all three test UPCs provided by GameUPC
before shipping the confidence flow implementation to production:

- `111111111117` — must auto-resolve with no user interaction
- `222222222224` — must present the selection sheet; chosen BGG ID must be posted back
- `333333333331` — must offer both "link to collection game" and "search BGG by name";
  confirmed BGG ID must be posted back

---

## Relationship to Existing Requirements

These requirements extend and complete the GameUPC Confidence Flow items already noted
as future work in `REQUIREMENTS-AND-DESIGN.md` (REQ-CM-039 through REQ-CM-044). Those
items should be considered superseded by this document once implementation begins.
