# Code Review

## Findings

### 1. High — Ambiguous scans in “Add to List” mode never add the game to the selected list

- `BarcodeScanView` accepts `list_id` and adds to the target list on the verified path (`web/catalog/api_views.py:198`, `web/catalog/api_views.py:296`), but `ConfirmScanView` only accepts `upc` + `bgg_id` and has no list handling at all (`web/catalog/api_views.py:318`).
- On the client side, `ScannerScreen` opens `CandidateSelectionSheet` without passing any list context (`mobile/lib/screens/scanner_screen.dart:187`), and the sheet confirms via `confirmScan(widget.upc, candidate.bggId)` (`mobile/lib/screens/candidate_selection_sheet.dart:40`).
- Result: if a user scans in Mode B and GameUPC returns `needs_selection`, confirming the correct game adds it to the collection but silently skips the selected list. That breaks the core Mode B contract in `REQ-GL-037`.

### 2. High — The web BGG sync path appears unusable in production

- `SyncBGGView` always calls the server-side client (`web/catalog/views.py:120`).
- The collection page posts directly to that view and explicitly documents the same server-side strategy (`web/templates/catalog/collection.html:30`).
- But the BGG client itself says the production-safe path is browser-fetched XML via `parse_collection_xml()` because cloud-hosted server-side requests are blocked (`web/catalog/bgg.py:47`, `web/catalog/bgg.py:102`).
- The repo docs and changelog also describe a browser-side/client-side fetch path (`web/CHANGELOG.md:12`, `docs/testing/unit-test-gaps.md:134`), but there is no corresponding view/template flow in the current code.
- Impact: the deployed web app is likely to fail exactly where users expect BGG sync to work.

### 3. Medium — Barcode scans can stamp a UPC onto the wrong game by title-only matching

- In the verified scan flow, when no exact UPC match exists, the backend falls back to `Game.objects.filter(title__iexact=candidate.title).first()` (`web/catalog/api_views.py:264`).
- That means a barcode result can attach itself to the first same-title row even when the existing local record has a different `bgg_id`, edition, or entirely different game with a colliding title.
- Board games have frequent title collisions across editions, reprints, and expansions, so this is not theoretical. A wrong merge here pollutes both the local collection and future GameUPC submissions.

### 4. Medium — The mobile app silently truncates collections at 200 games

- `ApiService.fetchCollection()` defaults to `limit = 200` (`mobile/lib/services/api_service.dart:82`, `mobile/lib/services/api_service.dart:86`).
- `CollectionProvider.load()` calls it once with no pagination (`mobile/lib/providers/collection_provider.dart:41`), so the main collection screen never fetches page 2+ (`mobile/lib/screens/collection_screen.dart:33`).
- The unknown-barcode linking flow also hard-caps its collection lookup at 200 items (`mobile/lib/screens/link_barcode_screen.dart:384`).
- For larger collections, the app will quietly hide owned games and prevent linking to many legitimate targets.

### 5. Medium — Several destructive mobile actions ignore server failures and can desync the UI

- `discardBarcode()`, `deleteList()`, and `removeFromList()` send DELETE requests but never run `_checkResponse()` or inspect the HTTP status (`mobile/lib/services/api_service.dart:202`, `mobile/lib/services/api_service.dart:296`, `mobile/lib/services/api_service.dart:329`).
- Callers then optimistically update local state as if the delete succeeded (`mobile/lib/providers/list_provider.dart:65`, `mobile/lib/providers/list_provider.dart:89`, `mobile/lib/screens/link_barcode_screen.dart:47`, `mobile/lib/screens/candidate_selection_sheet.dart:171`).
- If the API key is expired or the server returns `404/409/500`, the app will still remove the item locally or dismiss the pending barcode, leaving client state inconsistent with the backend.

## Open Questions

- The backend test helper in `web/catalog/tests/test_api_views.py` still constructs `GameUPCResult` using the old shape (`web/catalog/tests/test_api_views.py:33`), while the production dataclass now requires `candidate=` (`web/catalog/gameupc.py:118`). Once Django dependencies are installed, that suite may fail before exercising the API logic.

## Verification

- `flutter test` passed in `mobile/`.
- `python manage.py test` could not be run in `web/` because Django is not installed in the current environment.
