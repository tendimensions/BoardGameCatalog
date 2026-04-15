# Feature Spec: Game Lists

**Branch:** `feature/game-lists`  
**Status:** Final - implementation in progress  
**Date:** 2026-04-12

---

## Overview

Game Lists are user-defined, named collections of games drawn from the user's existing
collection. A list is essentially a tag group: games must already exist in the user's
collection to be added to a list. Each entry in a list can carry an optional free-text
note (e.g. "Loaned to Mike", "Bring to game night Friday").

Example use cases:
- **Loaned** — track which games are currently lent out and to whom
- **Game Day — April 19** — assemble games to bring to a specific event
- **Favourites** — curate a personal highlight reel
- **Teach next** — games queued to learn/teach

Lists are distinct from Party Lists (REQ-PL-*). Party Lists are a social/sharing feature
tied to events with multi-user compilation and game request workflows. Game Lists are
purely personal organisational tags with no sharing component (at this stage).

---

## Requirements

### REQ-GL-001 through REQ-GL-010 — List Management

- **REQ-GL-001:** Users can create a named Game List with an optional description.
- **REQ-GL-002:** Users can rename or update the description of an existing list.
- **REQ-GL-003:** Users can delete a list. Deleting a list does not remove games from the collection.
- **REQ-GL-004:** A user may have any number of lists.
- **REQ-GL-005:** List names need not be unique; the user may have two lists with the same name.
- **REQ-GL-006:** Lists are private to the owning user. No sharing in this phase.

### REQ-GL-010 through REQ-GL-019 — List Entries

- **REQ-GL-010:** Users can add a game to a list. The game must already be in the user's collection.
- **REQ-GL-011:** A game may appear in multiple lists simultaneously.
- **REQ-GL-012:** Each list entry may carry an optional note (free text, no enforced length limit in the DB but UI should suggest brevity).
- **REQ-GL-013:** Users can edit the note on an existing list entry without removing and re-adding the game.
- **REQ-GL-014:** Users can remove a game from a list. Removal does not affect the collection record.
- **REQ-GL-015:** If a game is removed from the user's collection entirely, it must be removed from all of that user's lists automatically (cascade).

### REQ-GL-020 through REQ-GL-029 — Web Interface

The web app top navigation bar currently reads:
**Collection | API Keys | Profile | Logout**

- **REQ-GL-020:** A **"Manage Lists"** link must be added to the top navigation bar between "Collection" and "API Keys", making the bar read: **Collection | Manage Lists | API Keys | Profile | Logout**
- **REQ-GL-021:** The Manage Lists page must show all of the user's lists with their name, description, game count, and creation date. From this page users can create a new list, rename an existing list, or delete a list.
- **REQ-GL-022:** Each list name on the Manage Lists page must link to a list detail view showing all games in that list, their thumbnails, and their per-entry notes, ordered newest-first.
- **REQ-GL-023:** From a game's detail page, users must be able to see which lists contain that game and add or remove it from any of their lists.
- **REQ-GL-024:** The "add to list" action on a game detail page must support creating a new list inline without navigating away.
- **REQ-GL-025:** List detail views must be filterable/searchable by game title.
- **REQ-GL-026:** If a user attempts to add a game to a list via the web UI and that game is not in their collection, the system must display a confirmation prompt: "This game is not in your collection. Add it to your collection and this list?" If confirmed, the game is added to the collection first, then to the list. No silent automatic additions.

### REQ-GL-030 through REQ-GL-041 — Mobile: Tab Structure and Scanning Modes

The mobile app currently has three bottom navigation tabs:
**Scan | Collection | Settings**

#### New Tab: Lists

- **REQ-GL-030:** A **"Lists"** tab must be added to the bottom navigation bar between "Collection" and "Settings", making the bar read: **Scan | Collection | Lists | Settings**
- **REQ-GL-031:** The Lists tab must show all of the user's lists with name, description, and game count. From this screen users can create a new list, tap into a list to view its entries, edit a note on an entry, remove a game from a list, rename a list, or delete a list.
- **REQ-GL-032:** Each list detail view in the mobile app must display games in newest-first order, showing thumbnail, title, and note for each entry.

#### Scan Tab: Mode Selection

- **REQ-GL-033:** Tapping the **Scan** tab must no longer navigate directly to the camera. Instead it must first present a **scan mode selection screen** with two clearly labelled options:
  - **"Add to Collection"** — the existing behaviour (Mode A)
  - **"Add to List"** — the new list-scanning mode (Mode B)
- **REQ-GL-034:** **Mode A — "Add to Collection":** Unchanged current behaviour. Scans a barcode, looks it up on GameUPC, adds the game to the user's collection. If the barcode is unknown, triggers the unknown-barcode contribution flow (REQ-CM-040 through REQ-CM-049). Does not interact with lists.
- **REQ-GL-035:** **Mode B — "Add to List":** Before the camera opens, the user must select a target list from their existing lists. If they have no lists, the app must prompt them to create one before proceeding. Once a list is selected, the camera opens and scanning begins.
- **REQ-GL-036:** In Mode B, the active list name must be displayed persistently in the scanner UI (e.g. in a banner or header) so the user always knows which list is receiving scans.
- **REQ-GL-037:** In Mode B, each successful scan adds the matched game to the selected list. If the game is not yet in the user's collection, it must be added to the collection first (same logic as Mode A) and then to the list.
- **REQ-GL-038:** In Mode B, after a successful scan, the app must present a confirmation screen with a note input field and a clearly labelled "Skip" action. This encourages a note without making it mandatory.
- **REQ-GL-039:** In Mode B, if the scanned game is already on the selected list, the app must notify the user (e.g. "Already on this list") without creating a duplicate entry and without interrupting the scanning session.
- **REQ-GL-040:** In Mode B, if the barcode is unknown (not in GameUPC), the system must save an `UnlinkedBarcode` record, play the error audio, and display a message that names the active list: e.g. "Barcode saved — remember to add this game to 'Loaned' once it's linked." Nothing is added to the list at this point.
- **REQ-GL-041:** Switching between Mode A and Mode B, or changing the active list within Mode B, must not require re-authenticating or restarting the app. The user returns to the mode selection screen to make a new choice.

### REQ-GL-050 — Future: BGG Write-Back

- **REQ-GL-050 (Future):** The system should investigate writing collection updates back to BoardGameGeek.com — for example, marking games as owned, updating play counts, or syncing notes. This applies to all new games added to the local DB regardless of source (barcode, manual, list). This is not in scope for this feature but is noted here as a known future requirement. A dedicated ADR will be written when that work begins.

---

## Data Model

### New Table: `game_lists`

```sql
CREATE TABLE game_lists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_game_lists_user_id ON game_lists(user_id);
```

### New Table: `game_list_entries`

```sql
CREATE TABLE game_list_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    list_id INTEGER NOT NULL,
    game_id INTEGER NOT NULL,
    note TEXT,
    added_via VARCHAR(20) DEFAULT 'manual',  -- 'manual', 'barcode'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (list_id) REFERENCES game_lists(id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE,
    UNIQUE(list_id, game_id)
);

CREATE INDEX idx_game_list_entries_list_id ON game_list_entries(list_id);
CREATE INDEX idx_game_list_entries_game_id ON game_list_entries(game_id);
```

### Updated Entity Relationships

```
users ──┬── api_keys (1:many)
        ├── user_collections (1:many) ── games (many:1)
        ├── game_lists (1:many)
        │     └── game_list_entries (1:many) ── games (many:1)
        ├── party_lists (1:many - as owner)
        ├── party_list_shares (1:many - as shared_with)
        ├── game_requests (1:many - as requester)
        ├── game_requests (1:many - as owner)
        └── lending_history (1:many - future)
```

**Cascade rule:** `game_list_entries` references `games(id)` with `ON DELETE CASCADE`.
Since `user_collections` records are the user's ownership record, removing a game from
the collection (deleting the `user_collections` row) does not automatically cascade to
`game_list_entries` via the DB — the application layer must handle this (delete list
entries for that user when the collection record is removed). REQ-GL-015 covers this.

**Collection enforcement (web UI):** If a user attempts to add a game to a list via the
web UI and that game is not in their collection, the system must present a confirmation
prompt: "This game is not in your collection. Add it to your collection and then to this
list?" If confirmed, the game is added to the collection first, then to the list. Silent
automatic addition is not acceptable (REQ-GL-010).

**List entry ordering:** Entries are ordered by `created_at` descending (newest first).
Manual reordering is deferred to a future enhancement.

---

## API Endpoints (Mobile)

All endpoints require `Authorization: Bearer <api_key>`.

### Lists

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/lists` | Get all lists for the authenticated user |
| `POST` | `/api/v1/lists` | Create a new list |
| `GET` | `/api/v1/lists/{list_id}` | Get a list with all its entries |
| `PATCH` | `/api/v1/lists/{list_id}` | Update list name or description |
| `DELETE` | `/api/v1/lists/{list_id}` | Delete a list |

### List Entries

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/lists/{list_id}/entries` | Add a game to a list |
| `PATCH` | `/api/v1/lists/{list_id}/entries/{entry_id}` | Edit the note on a list entry |
| `DELETE` | `/api/v1/lists/{list_id}/entries/{entry_id}` | Remove a game from a list |

### Scanning (Mode B)

The existing `POST /api/v1/scan/barcode` endpoint must be extended to accept an optional
`list_id` parameter. When provided, the server adds the resolved game to that list after
adding it to the collection.

```
POST /api/v1/scan/barcode
{
  "upc": "012345678901",
  "list_id": 7          ← optional; omit for Mode A behaviour
}
```

Response adds `added_to_list` and `already_on_list` boolean fields when `list_id` is
provided.

---

## Design Decisions (Resolved)

1. **Note on scan:** The mobile app always shows a note prompt on the scan confirmation screen, but it must be easy to dismiss ("Skip"). This encourages richer data without blocking the scanning flow. See REQ-GL-037.

2. **Unknown barcode in Mode B:** The "barcode saved" notification must name the active list so the user remembers to manually add the game after linking. See REQ-GL-033.

3. **Collection enforcement (web UI):** If a game is not in the user's collection, the system must ask for confirmation before adding it to both the collection and the list. No silent data changes. See REQ-GL-010 and the cascade rule note in the Data Model section.

4. **List entry ordering:** Newest first (`created_at DESC`). Manual reordering deferred to a future enhancement.

5. **BGG write-back:** Confirmed as a future feature independent of Game Lists — any new game added to the local DB (regardless of source) will eventually need to be pushed back to BGG. A dedicated ADR will be written when that work begins. See REQ-GL-050.