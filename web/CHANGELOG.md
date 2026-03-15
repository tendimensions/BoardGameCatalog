# Web App Changelog

All notable changes to the Board Game Catalog web application.

---

## [1.0.0] — 2026-03-15

### Added
- User registration with email verification
- Login, logout, forgot password, and password change flows
- BoardGameGeek XML API v2 collection sync (client-side fetch to avoid IP blocks)
- Game collection view with search, filter (all / missing barcode / lent), and sort
- HTMX-powered in-place updates for search and filter controls
- Pagination (25 games per page)
- API key management page — generate, copy, and revoke keys for mobile app access
- GameUPC informational banner with dismiss (stored in session)
- REST API v1 for mobile app: `POST /api/v1/auth/login`, `GET /api/v1/collection`, `POST /api/v1/scan/barcode`, `GET /api/v1/users/profile`
- GameUPC.com barcode lookup client
- Microsoft Graph API email backend (replaces SMTP)
- Docker + Gunicorn deployment with host nginx reverse proxy
- WhiteNoise static file serving
- Dark theme UI
