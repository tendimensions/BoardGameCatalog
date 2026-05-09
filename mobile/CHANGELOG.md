# Mobile App Changelog

## Firebase Release Notes
- Reordered the bottom navigation to Collection, Lists, Scan, Settings.
- Replaced the first-run setup screen icon with the app icon.
- Added CodeMagic release-note generation from this changelog section.

---

All notable changes to the Board Game Catalog Flutter app.

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
