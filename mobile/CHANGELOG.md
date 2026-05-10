# Mobile App Changelog

## Firebase Release Notes
- Full collection now loads for users with more than 200 games (pagination fix).
- Typing a game name in the barcode-link screen now carries across both tabs.
- New filter icon on the Collection tab: filter by Barcode Not Linked or In a List.

---

All notable changes to the Board Game Catalog Flutter app.

## [0.9.1] — 2026-05-09

### Fixed
- Collection silently truncated at 200 games — now pages automatically until the full set is loaded (Issue #16).
- Typing in one tab of the barcode-link screen now carries to the other tab on switch (Issue #21).

### Added
- Filter icon on the Collection search bar: "Barcode Not Linked" toggle and "In a List" selector with per-list breakdown (Issue #23).

### CI/CD
- Version number now read directly from `pubspec.yaml`; removed the manually-maintained `$PROJECT_BUILD_VERSION` Codemagic variable that was causing the app to always report `1.0.0`.

## [1.1.0] — 2026-05-09

### Added
- Game detail screen accessible from tapped collection items
- Direct barcode scan-and-link flow for collection games that do not yet have a UPC

### Changed
- Expanded mobile game metadata to include minimum age and description
- Expanded collection detail display with source, notes, acquisition date, and lending status

## [1.0.1] — 2026-05-09

### Changed
- Reordered the mobile bottom navigation to Collection, Lists, Scan, Settings
- Replaced the setup screen die icon with the app icon

### CI/CD
- Added CodeMagic release note generation from the top section of this changelog
- Published generated release notes to Firebase App Distribution via `release_notes.txt`

## [1.0.0] — 2026-03-15

### Added
- API key setup screen — paste key generated from the web app to connect
- Barcode scanner screen with live camera viewfinder and torch toggle
- Distinct success and error audio feedback on each scan
- Scan history list showing last 20 scans with game thumbnail, title, and status
- Collection screen with search, pull-to-refresh, and offline cache (1-hour TTL)
- Settings screen showing username, masked API key, and app version
- Sign out with confirmation dialog
- Secure API key storage (iOS Keychain / Android Keystore via flutter_secure_storage)
- Dark theme matching the web app colour palette
- Android and iOS support
- CodeMagic CI/CD pipeline → Firebase App Distribution
