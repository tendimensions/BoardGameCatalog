# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

Phase 1 (Foundation) is **complete**. The Django web app is scaffolded and runnable. Phase 2 (BGG integration + collection management) is next.

## Repository Layout

```text
BoardGameCatalog/
├── web/                    ← Django web application (all web-specific files live here)
│   ├── boardgame_catalog/    ← Django project package (settings, urls, wsgi)
│   ├── accounts/             ← User auth, profiles, API keys, Graph email backend
│   ├── catalog/              ← Games, collections, party lists, game requests
│   ├── templates/            ← All HTML templates
│   ├── static/css/           ← Stylesheet (dark theme from sample-style.css)
│   ├── manage.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── docker-compose.yml    ← Uses build: . (context is web/)
│   ├── deploy.ps1            ← PowerShell deploy script (run from web/)
│   ├── server-setup.sh       ← One-time nginx + Certbot setup for the Linode
│   └── .env.example          ← Copy to .env and fill in secrets
├── mobile/               ← Flutter mobile app (Phase 3, not yet started)
└── docs/adr/             ← Architecture Decision Records
```

## Commands

All `manage.py` commands must be run from inside `web/`:

```bash
# First-time setup
cd web
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env            # fill in SECRET_KEY at minimum
python manage.py makemigrations  # only needed when models change
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver      # → http://localhost:8000

# Tests
python manage.py test
python manage.py test accounts.tests.SomeTest.test_method

# Coverage
coverage run --source='.' manage.py test
coverage report

# Docker (from web/)
docker-compose up --build
```

## Architecture

**Web:** Django 5.0+ with SSR (Django Templates + HTMX + Alpine.js). No SPA — all rendering server-side. HTMX powers live search/filter on the collection page without full reloads.

**Mobile:** Flutter (Phase 3, not started). Authenticates via `Authorization: Bearer <api_key>` handled by `accounts.authentication.APIKeyAuthentication`.

**Database:** SQLite (`web/db.sqlite3`) in development; docker-compose mounts `./data/db.sqlite3` in production.

### Django Apps

| App | Responsibility |
| --- | --- |
| `accounts` | Custom `User` model, email verification, API key CRUD, Graph email backend |
| `catalog` | `Game`, `UserCollection`, `PartyList`, `PartyListGame`, `PartyListShare`, `GameRequest`, `LendingHistory` |

### Key Domain Models

- `accounts.User` — extends `AbstractUser`; adds `bgg_username`, `email_verified`, `verification_token`. Email and BGG username are **read-only after creation**.
- `catalog.Game` — board game metadata. `upc` field is **only populated by mobile barcode scans** (never from BGG).
- `catalog.UserCollection` — joins User ↔ Game with `source` (`bgg_sync | manual | barcode`), lending fields (future Phase 6).
- `catalog.PartyList` / `PartyListGame` / `PartyListShare` / `GameRequest` — Phase 4 social features (models exist, views not yet built).
- `catalog.LendingHistory` — Phase 6 audit table (model exists, not yet used).

### External API Integration

Two external services are used (see [docs/adr/adr-0003-external-api-integration.md](docs/adr/adr-0003-external-api-integration.md)):

- **BoardGameGeek (BGG):** Rate-limited to 1 request per 2 seconds. Returns HTTP 202 when data isn't cached yet — must poll/retry. Cache responses for 24 hours.
- **GameUPC.com:** Community barcode database. Used bidirectionally: lookup barcode → game, and contribute new mappings back.

**Email:** Production email goes through Microsoft Graph API (`accounts/graph_email_backend.py`). The backend uses OAuth 2.0 client credentials flow via `msal`. Requires an Entra ID app registration with `Mail.Send` application permission and admin consent. In development the console backend is used — no Azure credentials needed.

### Architecture Decision Records

All major technology choices are documented in [docs/adr/](docs/adr/). Read these before proposing alternative technologies:

- `adr-0001` — Django chosen over Flask/Express
- `adr-0002` — SSR with HTMX chosen over SPA frameworks
- `adr-0003` — External API integration strategy (BGG + GameUPC)
- `adr-0004` — Authentication and security policies (8-char minimum password, no complexity requirements by design)

### Requirements

Full functional requirements (90+ items), database schema, and API specs are in [REQUIREMENTS-AND-DESIGN.md](REQUIREMENTS-AND-DESIGN.md). Consult it before implementing any feature.
