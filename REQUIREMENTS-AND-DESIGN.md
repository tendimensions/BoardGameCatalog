# Board Game Catalog - Requirements and Design Document

**Version:** 1.0  
**Date:** March 14, 2026  
**Project:** Board Game Collection Management System

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Overview](#system-overview)
3. [Functional Requirements](#functional-requirements)
4. [Non-Functional Requirements](#non-functional-requirements)
5. [System Architecture](#system-architecture)
6. [Data Models](#data-models)
7. [API Specifications](#api-specifications)
8. [User Interface Design](#user-interface-design)
9. [Security Considerations](#security-considerations)
10. [Integration Points](#integration-points)
11. [Deployment Strategy](#deployment-strategy)
12. [Development Roadmap](#development-roadmap)
13. [Testing Strategy](#testing-strategy)
14. [Open Questions and Issues](#open-questions-and-issues)

---

## 1. Executive Summary

The Board Game Catalog is a comprehensive collection management system consisting of two applications: a web application and a mobile application. The system allows users to manage their board game collections, sync with BoardGameGeek.com, scan barcodes to add games, and create party lists for sharing collections with other users.

**Key Features:**

- User account management with email verification
- BoardGameGeek.com integration for collection syncing
- Barcode scanning via mobile app for quick game addition
- Party list creation and sharing
- API-based mobile app authentication
- Cross-platform mobile support (Android & iOS)

**Target Deployment:** boardgames.tendimensions.com

---

## 2. System Overview

### 2.1 Component Architecture

The system comprises:

1. **Web Application**
   - Hosted at boardgames.tendimensions.com
   - Docker containerized deployment
   - SQLite database backend
   - Nginx reverse proxy

2. **Mobile Application**
   - Cross-platform (Android & iOS) using Flutter
   - Native barcode scanning libraries
   - API key authentication

3. **External Integrations**
   - BoardGameGeek.com API
   - GameUPC.com API
   - Firebase for mobile distribution
   - CodeMagic.io for CI/CD

### 2.2 Technology Stack

**Web Application:**

- Framework: Django 5.0+ (Python)
- ORM: Django ORM (built-in)
- Templates: Django Templates (server-side rendering)
- Dynamic UI: HTMX + Alpine.js
- API: Django REST Framework (for mobile app)
- Database: SQLite (initial) → PostgreSQL (production-ready)
- Web Server: Nginx (reverse proxy)
- Container: Docker
- Email: Django SMTP backend
- Admin: Django Admin (built-in)

**Mobile Application:**

- Framework: Flutter
- Native Libraries: Barcode scanning (platform-specific)
- Distribution: Firebase
- CI/CD: CodeMagic.io

**Development Philosophy:**

- Server-side rendering for speed and simplicity
- Progressive enhancement with HTMX for dynamic interactions
- Single codebase for web UI (Python)
- RESTful API for mobile app integration
- Django admin for data management and analytics

---

## 3. Functional Requirements

### 3.1 User Management (Web Application)

#### 3.1.1 Account Creation

- **REQ-UM-001:** Users must be able to create an account with email, username, and optional BoardGameGeek.com username
- **REQ-UM-002:** Email addresses must be unique across the system
- **REQ-UM-003:** Usernames must be unique across the system
- **REQ-UM-004:** System must send email verification link via SMTP upon account creation
- **REQ-UM-005:** Users must verify email before accessing their account
- **REQ-UM-006:** Users set password during email verification process
- **REQ-UM-007:** System must display appropriate error messages for duplicate usernames or emails

#### 3.1.2 Authentication

- **REQ-UM-010:** Users must be able to log in with username and password
- **REQ-UM-011:** System must provide "Forgot Password" functionality
- **REQ-UM-012:** System must maintain secure session management

#### 3.1.3 Profile Management

- **REQ-UM-020:** Users can edit their username
- **REQ-UM-021:** Users cannot edit their email address after creation
- **REQ-UM-022:** Users cannot edit their BoardGameGeek.com username after creation
- **REQ-UM-023:** Users can generate API keys for mobile application access
- **REQ-UM-024:** Users can view and manage multiple API keys
- **REQ-UM-025:** API key generation screen must be mobile-friendly

### 3.2 Collection Management

#### 3.2.1 Board Game Collection

- **REQ-CM-001:** Users must have a personal board game collection (initially empty)
- **REQ-CM-002:** Collection must display all games owned by the user
- **REQ-CM-003:** Users can view detailed information for each game
- **REQ-CM-004:** Collection must support search and filtering capabilities
- **REQ-CM-005:** Users can manually add games to their collection
- **REQ-CM-006:** Users can remove games from their collection
- **REQ-CM-007:** Users can edit game details in their collection

#### 3.2.2 BoardGameGeek.com Sync

- **REQ-CM-010:** System must provide "Sync from BoardGameGeek.com" button on main screen
- **REQ-CM-011:** Sync operation must fetch user's collection from BoardGameGeek.com API
- **REQ-CM-012:** Sync must be non-destructive (additive only, not overwriting existing data)
- **REQ-CM-013:** Sync must link imported games to user's collection
- **REQ-CM-014:** BGG data may not contain barcode (UPC) information
- **REQ-CM-015:** System must handle sync errors gracefully
- **REQ-CM-016:** System should investigate bidirectional sync (push updates to BoardGameGeek.com)

#### 3.2.3 Barcode Integration

- **REQ-CM-020:** System must accept barcode scan data from mobile application
- **REQ-CM-021:** Barcode information comes exclusively from mobile application scans (not from BGG)
- **REQ-CM-022:** Barcode data must be processed via GameUPC.com API to retrieve game metadata
- **REQ-CM-023:** System must check if scanned game already exists in user's collection
- **REQ-CM-024:** If game exists in collection, system must update existing record with barcode information
- **REQ-CM-025:** If game does not exist in collection, system must create new game record with full metadata
- **REQ-CM-026:** System must handle invalid or unknown UPC codes
- **REQ-CM-027:** System must associate scanned games with correct user account

#### 3.2.4 GameUPC Community Contribution

- **REQ-CM-030:** Users can contribute UPC/barcode mappings to GameUPC.com via web application
- **REQ-CM-031:** Web app must provide "Link Barcode to Game" feature on game detail pages
- **REQ-CM-032:** Users can manually enter UPC code and associate it with a game in their collection
- **REQ-CM-033:** System must submit verified mappings back to GameUPC.com API to improve crowdsource database
- **REQ-CM-034:** Collection screen must display informational banner about GameUPC crowdsourced data
- **REQ-CM-035:** Banner must explain: "Barcode scanning uses crowdsourced data from GameUPC.com. You may be asked to help verify game information when scanning. You can also manually link barcodes to your games to help the community."
- **REQ-CM-036:** User contributions must include unique user ID when submitting to GameUPC API
- **REQ-CM-037:** System must handle GameUPC API submission errors gracefully
- **REQ-CM-038:** System must provide feedback to users when their contribution is successfully submitted
- **REQ-CM-028:** Same update/create logic applies when scanning in party list mode

### 3.3 Party Lists

#### 3.3.1 Party List Creation

- **REQ-PL-001:** Users can create named party lists
- **REQ-PL-002:** Users can add games from their collection to party lists
- **REQ-PL-003:** Users can remove games from party lists
- **REQ-PL-004:** Users can edit party list names and descriptions
- **REQ-PL-005:** Users can delete party lists

#### 3.3.2 Party List Sharing

- **REQ-PL-010:** Users can share party lists with other users on the system
- **REQ-PL-011:** Multiple users' party lists can be compiled into a single view
- **REQ-PL-012:** Compiled view must highlight duplicate games across party lists
- **REQ-PL-013:** Users can request other users to bring specific games
- **REQ-PL-014:** System must support party list permissions/access control

#### 3.3.3 Mobile Party List Assembly

- **REQ-PL-020:** Mobile app must support a special "party list mode" for scanning
- **REQ-PL-021:** Games scanned in party list mode must be added to designated party list
- **REQ-PL-022:** Mobile app must provide visual feedback for party list mode

### 3.4 Mobile Application

#### 3.4.1 Authentication

- **REQ-MA-001:** Mobile app must authenticate using API key
- **REQ-MA-002:** API key must be generated from web application
- **REQ-MA-003:** Mobile app must securely store API key
- **REQ-MA-004:** Mobile app must validate API key with web application
- **REQ-MA-005:** Mobile app must handle expired or invalid API keys

#### 3.4.2 Barcode Scanning

- **REQ-MA-010:** Mobile app must support continuous barcode scanning
- **REQ-MA-011:** App must provide audio feedback (beep) on successful scan
- **REQ-MA-012:** Each scan must immediately send data to web application
- **REQ-MA-013:** App must handle network errors during scan transmission
- **REQ-MA-014:** App must support both standard collection mode and party list mode
- **REQ-MA-015:** App must display scan history/status

#### 3.4.3 Collection Access

- **REQ-MA-020:** Mobile app must allow users to view their collection
- **REQ-MA-021:** Mobile app must sync collection data from web application
- **REQ-MA-022:** Mobile app must support offline viewing of cached collection

### 3.5 Future Enhancements (Post-MVP)

#### 3.5.1 Mobile Barcode Collection Management

- **REQ-FE-001:** Mobile app shall support "Remove from Collection" mode via barcode scanning
- **REQ-FE-002:** User can scan game barcode to remove it from their collection
- **REQ-FE-003:** Mobile app must prompt for confirmation before removing game
- **REQ-FE-004:** Removed games must be immediately reflected in web application
- **REQ-FE-005:** This is distinct from web-based deletion (which is available in Phase 1)

#### 3.5.2 Game Lending Tracking

- **REQ-FE-010:** Users shall be able to mark games as "Lent Out" via barcode scan
- **REQ-FE-011:** System must record who the game was lent to (free text or contact selection)
- **REQ-FE-012:** System must record when game was lent (date/time)
- **REQ-FE-013:** Users can add notes about the loan
- **REQ-FE-014:** Lent games must be visually distinguished in collection view (both mobile and web)
- **REQ-FE-015:** Users can scan game again to mark it as "Returned"
- **REQ-FE-016:** System should maintain lending history for each game
- **REQ-FE-017:** Users can view all currently lent games in a filtered view
- **REQ-FE-018:** Lent games can still be added to party lists with visual indicator

---

## 4. Non-Functional Requirements

### 4.1 Performance

- **REQ-NFR-001:** Web application must handle at least 100 concurrent users
- **REQ-NFR-002:** API responses must return within 2 seconds under normal load
- **REQ-NFR-003:** BoardGameGeek.com sync must provide progress feedback for large collections
- **REQ-NFR-004:** Mobile app must process barcode scans within 1 second
- **REQ-NFR-005:** Database queries must be optimized with appropriate indexes

### 4.2 Scalability

- **REQ-NFR-010:** System architecture must support migration from SQLite to PostgreSQL/MySQL if needed
- **REQ-NFR-011:** Docker container must be scalable horizontally behind load balancer
- **REQ-NFR-012:** API must support rate limiting to prevent abuse

### 4.3 Security

- **REQ-NFR-020:** All passwords must be hashed using industry-standard algorithms (bcrypt/Argon2)
- **REQ-NFR-021:** API keys must be cryptographically secure random strings
- **REQ-NFR-022:** All API endpoints must require authentication
- **REQ-NFR-023:** HTTPS must be enforced for all connections
- **REQ-NFR-024:** SMTP credentials must be stored securely (environment variables/secrets)
- **REQ-NFR-025:** System must protect against SQL injection, XSS, CSRF attacks
- **REQ-NFR-026:** API must implement rate limiting per user/API key

### 4.4 Reliability

- **REQ-NFR-030:** System must have 99% uptime
- **REQ-NFR-031:** Database must be backed up daily
- **REQ-NFR-032:** System must gracefully handle third-party API failures
- **REQ-NFR-033:** Mobile app must queue scans when offline and sync when connection restored

### 4.5 Usability

- **REQ-NFR-040:** Web UI must follow dark theme design from sample-style.css
- **REQ-NFR-041:** Web UI must be responsive on mobile devices
- **REQ-NFR-042:** Mobile app must have intuitive barcode scanning interface
- **REQ-NFR-043:** Error messages must be user-friendly and actionable

### 4.6 Maintainability

- **REQ-NFR-050:** Code must follow framework-specific best practices
- **REQ-NFR-051:** API must be versioned (e.g., /api/v1/)
- **REQ-NFR-052:** System must have comprehensive logging
- **REQ-NFR-053:** Documentation must be maintained for API endpoints

---

## 5. System Architecture

### 5.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet                                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ HTTPS
                       ▼
             ┌──────────────────┐
             │  Nginx Reverse   │
             │     Proxy        │
             └────────┬─────────┘
                      │
                      │ HTTP (localhost)
                      ▼
             ┌──────────────────┐
             │  Docker Container│
             │                  │
             │  ┌────────────┐  │
             │  │   Web App  │◄─┼─────────┐
             │  │            │  │         │
             │  │  ┌──────┐  │  │         │ REST API
             │  │  │SQLite│  │  │         │ (HTTPS)
             │  │  └──────┘  │  │         │
             │  └────────────┘  │         │
             └──────────────────┘         │
                      │                   │
          ┌───────────┴───────────┐       │
          │                       │       │
          ▼                       ▼       │
┌────────────────────┐  ┌────────────────────┐
│ BoardGameGeek.com  │  │   GameUPC.com      │
│       API          │  │      API           │
│ (HTTPS)            │  │   (HTTPS)          │
└────────────────────┘  └────────────────────┘
                                          │
                                          │
                                ┌─────────┴─────────┐
                                │  Mobile App       │
                                │  (Android/iOS)    │
                                │                   │
                                │  Flutter + Native │
                                │  Barcode Scanner  │
                                └─────────┬─────────┘
                                          │
                                          │ Distribution
                                          ▼
                                ┌─────────────────────┐
                                │  Firebase           │
                                │  App Distribution   │
                                └─────────────────────┘
```

### 5.2 Component Details

#### 5.2.1 Web Application Layer

- **Responsibilities:**
  - HTTP request/response handling
  - User authentication and session management
  - Business logic execution
  - Database operations
  - Third-party API integration
  - Email sending

#### 5.2.2 Data Layer

- **SQLite Database:**
  - Stores user accounts
  - Stores game collections
  - Stores party lists
  - Stores API keys
  - Stores BoardGameGeek.com links

#### 5.2.3 Mobile Application Layer

- **Responsibilities:**
  - API key authentication
  - Barcode scanning
  - Local data caching
  - API communication with web app

### 5.3 Network Architecture

- **Domain:** boardgames.tendimensions.com
- **SSL/TLS:** Required for all external connections
- **Nginx Configuration:**
  - Reverse proxy to Docker container
  - SSL termination
  - Static file serving (optional)
  - Request logging

### 5.4 Data Flow Diagrams

#### 5.4.1 Barcode Scanning Flow

**Important Note:** Barcode (UPC) information comes exclusively from mobile app scans. BoardGameGeek.com data does not contain barcode information.

```
┌─────────────────┐
│  Mobile App     │
│  Scans Barcode  │
└────────┬────────┘
         │ 1. POST /api/v1/scan/barcode
         │    { upc: "123456789", party_list_id?: 42 }
         ▼
┌─────────────────────────────────────────┐
│  Web App API                            │
│                                         │
│  2. Query GameUPC.com API               │
│     GET https://gameupc.com/api/...    │
│                                         │
└────────┬────────────────────────────────┘
         │ 3. Receive game metadata
         │    { title, year, players, etc. }
         ▼
┌─────────────────────────────────────────┐
│  Web App - Game Matching Logic         │
│                                         │
│  4. Check if game exists in user's     │
│     collection:                         │
│     - Search by title/BGG ID           │
│     - Fuzzy match if needed            │
│                                         │
│  5a. If EXISTS:                        │
│      - Update game record with UPC     │
│      - Return existing game            │
│                                         │
│  5b. If NOT EXISTS:                    │
│      - Create new game record          │
│      - Add to user's collection        │
│      - Save UPC with game data         │
│                                         │
│  6. If party_list_id provided:         │
│     - Add game to party list           │
│                                         │
└────────┬────────────────────────────────┘
         │ 7. Return response
         │    { game, operation: "created|updated",
         │      added_to_collection: true,
         │      added_to_party_list: true }
         ▼
┌─────────────────┐
│  Mobile App     │
│  Shows Feedback │
│  (Beep + Status)│
└─────────────────┘
```

#### 5.4.2 BoardGameGeek.com Sync Flow

```
┌─────────────────┐
│  Web App User   │
│  Clicks "Sync"  │
└────────┬────────┘
         │ 1. POST /api/v1/collection/sync-bgg
         ▼
┌─────────────────────────────────────────┐
│  Web App API                            │
│                                         │
│  2. Query BGG API with username        │
│     - Wait 2 seconds between requests  │
│     - Handle HTTP 202 (queued)         │
│     - Poll every 2-5 seconds if queued │
│     GET boardgamegeek.com/xmlapi2/...  │
│                                         │
└────────┬────────────────────────────────┘
         │ 3. Receive collection data (XML)
         │    NOTE: No UPC/barcode info from BGG
         ▼
┌─────────────────────────────────────────┐
│  Web App - Sync Logic                  │
│                                         │
│  4. Parse BGG XML response             │
│  5. For each game in BGG collection:   │
│     - Check if exists locally by BGG ID│
│     - If exists: Update metadata       │
│       (keep existing UPC if present)   │
│     - If not exists: Create new record │
│       (UPC will be null until scanned) │
│  6. Link all games to user collection  │
│                                         │
└────────┬────────────────────────────────┘
         │ 7. Return sync results
         ▼
┌─────────────────┐
│  Web App User   │
│  Views Updated  │
│  Collection     │
└─────────────────┘
```

---

## 6. Data Models

### 6.1 Database Schema

#### 6.1.1 Users Table

```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    bgg_username VARCHAR(50),
    email_verified BOOLEAN DEFAULT FALSE,
    verification_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

#### 6.1.2 API Keys Table

```sql
CREATE TABLE api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    api_key VARCHAR(64) UNIQUE NOT NULL,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX idx_api_keys_key ON api_keys(api_key);
```

#### 6.1.3 Games Table

```sql
CREATE TABLE games (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bgg_id INTEGER UNIQUE,
    upc VARCHAR(50),  -- Populated exclusively by mobile app barcode scans (not from BGG)
    title VARCHAR(255) NOT NULL,
    year_published INTEGER,
    min_players INTEGER,
    max_players INTEGER,
    playing_time INTEGER,
    min_age INTEGER,
    description TEXT,
    thumbnail_url VARCHAR(500),
    image_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_games_bgg_id ON games(bgg_id);
CREATE INDEX idx_games_upc ON games(upc);
CREATE INDEX idx_games_title ON games(title);
```

#### 6.1.4 User Collections Table

```sql
CREATE TABLE user_collections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    game_id INTEGER NOT NULL,
    acquisition_date DATE,
    notes TEXT,
    source VARCHAR(50), -- 'bgg_sync', 'manual', 'barcode'
    is_lent BOOLEAN DEFAULT FALSE,  -- Future: Track if game is lent out
    lent_to VARCHAR(255),           -- Future: Who borrowed the game
    lent_date DATE,                 -- Future: When was it lent
    lent_notes TEXT,                -- Future: Notes about the loan
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE,
    UNIQUE(user_id, game_id)
);

CREATE INDEX idx_user_collections_user_id ON user_collections(user_id);
CREATE INDEX idx_user_collections_game_id ON user_collections(game_id);
CREATE INDEX idx_user_collections_is_lent ON user_collections(is_lent);
```

#### 6.1.5 Party Lists Table

```sql
CREATE TABLE party_lists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_id INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    event_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_party_lists_owner_id ON party_lists(owner_id);
```

#### 6.1.6 Party List Games Table

```sql
CREATE TABLE party_list_games (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    party_list_id INTEGER NOT NULL,
    game_id INTEGER NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (party_list_id) REFERENCES party_lists(id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE,
    UNIQUE(party_list_id, game_id)
);

CREATE INDEX idx_party_list_games_list_id ON party_list_games(party_list_id);
CREATE INDEX idx_party_list_games_game_id ON party_list_games(game_id);
```

#### 6.1.7 Party List Shares Table

```sql
CREATE TABLE party_list_shares (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    party_list_id INTEGER NOT NULL,
    shared_with_user_id INTEGER NOT NULL,
    permission VARCHAR(20) DEFAULT 'view', -- 'view', 'edit'
    accepted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (party_list_id) REFERENCES party_lists(id) ON DELETE CASCADE,
    FOREIGN KEY (shared_with_user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(party_list_id, shared_with_user_id)
);

CREATE INDEX idx_party_list_shares_list_id ON party_list_shares(party_list_id);
CREATE INDEX idx_party_list_shares_user_id ON party_list_shares(shared_with_user_id);
```

#### 6.1.8 Game Requests Table

```sql
CREATE TABLE game_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    party_list_id INTEGER NOT NULL,
    requester_id INTEGER NOT NULL,
    owner_id INTEGER NOT NULL,
    game_id INTEGER NOT NULL,
    message TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'accepted', 'declined'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (party_list_id) REFERENCES party_lists(id) ON DELETE CASCADE,
    FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE
);

CREATE INDEX idx_game_requests_party_list_id ON game_requests(party_list_id);
CREATE INDEX idx_game_requests_owner_id ON game_requests(owner_id);
```

#### 6.1.9 Lending History Table (Future Enhancement)

```sql
-- Optional table for maintaining full audit trail of game loans
-- This would be implemented in Phase 6 alongside lending features
CREATE TABLE lending_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    game_id INTEGER NOT NULL,
    lent_to VARCHAR(255) NOT NULL,
    lent_date DATE NOT NULL,
    returned_date DATE,
    lent_notes TEXT,
    return_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE
);

CREATE INDEX idx_lending_history_user_id ON lending_history(user_id);
CREATE INDEX idx_lending_history_game_id ON lending_history(game_id);
CREATE INDEX idx_lending_history_returned_date ON lending_history(returned_date);
```

**Note:** This table is optional. The basic lending functionality can work with just the fields added to `user_collections`. This separate table would enable:

- Full historical tracking of all loans
- Analytics on lending patterns
- Data retention after games are removed from collection

### 6.2 Entity Relationships

```
users ──┬── api_keys (1:many)
        ├── user_collections (1:many) ── games (many:1)
        ├── party_lists (1:many - as owner)
        ├── party_list_shares (1:many - as shared_with)
        ├── game_requests (1:many - as requester)
        ├── game_requests (1:many - as owner)
        └── lending_history (1:many - future)

party_lists ──┬── party_list_games (1:many) ── games (many:1)
              ├── party_list_shares (1:many)
              └── game_requests (1:many)

games ──┬── user_collections (1:many)
        ├── party_list_games (1:many)
        ├── game_requests (1:many)
        └── lending_history (1:many - future)
```

---

## 7. API Specifications

### 7.1 API Design Principles

- RESTful architecture
- JSON request/response format
- API versioning: `/api/v1/`
- Authentication: Bearer token (API key)
- HTTP status codes for responses
- Consistent error response format

### 7.2 Authentication

**Header Format:**

```
Authorization: Bearer <API_KEY>
```

### 7.3 Error Response Format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {}
  }
}
```

### 7.4 API Endpoints

#### 7.4.1 Authentication & User Management

**POST /api/v1/auth/register**

- Create new user account
- Request: `{ username, email, password, bgg_username? }`
- Response: `{ message, user_id }`
- Status: 201 Created

**POST /api/v1/auth/verify-email**

- Verify email with token
- Request: `{ token }`
- Response: `{ message }`
- Status: 200 OK

**POST /api/v1/auth/login**

- User login (web app only)
- Request: `{ username, password }`
- Response: `{ session_token, user }`
- Status: 200 OK

**POST /api/v1/auth/forgot-password**

- Request password reset
- Request: `{ email }`
- Response: `{ message }`
- Status: 200 OK

**POST /api/v1/auth/reset-password**

- Reset password with token
- Request: `{ token, new_password }`
- Response: `{ message }`
- Status: 200 OK

**GET /api/v1/users/profile**

- Get current user profile
- Response: `{ user }`
- Status: 200 OK

**PATCH /api/v1/users/profile**

- Update user profile
- Request: `{ username? }`
- Response: `{ user }`
- Status: 200 OK

#### 7.4.2 API Key Management

**GET /api/v1/api-keys**

- List user's API keys
- Response: `{ api_keys: [...] }`
- Status: 200 OK

**POST /api/v1/api-keys**

- Generate new API key
- Request: `{ name? }`
- Response: `{ api_key, key_id, created_at }`
- Status: 201 Created

**DELETE /api/v1/api-keys/:key_id**

- Revoke API key
- Response: `{ message }`
- Status: 200 OK

#### 7.4.3 Collection Management

**GET /api/v1/collection**

- Get user's collection
- Query params: `?search=<term>&sort=<field>&order=<asc|desc>&limit=<n>&offset=<n>`
- Response: `{ games: [...], total_count, page_info }`
- Status: 200 OK

**POST /api/v1/collection/sync-bgg**

- Sync collection from BoardGameGeek.com
- Response: `{ message, games_added, status }`
- Status: 202 Accepted (async operation)

**GET /api/v1/collection/sync-bgg/status**

- Check BGG sync status
- Response: `{ status, progress, message }`
- Status: 200 OK

**POST /api/v1/collection/games**

- Manually add game to collection
- Request: `{ game_id?, title, year?, ... }` (creates game if not exists)
- Response: `{ collection_item }`
- Status: 201 Created

**DELETE /api/v1/collection/games/:game_id**

- Remove game from collection
- Response: `{ message }`
- Status: 200 OK

**PATCH /api/v1/collection/games/:game_id**

- Update collection item
- Request: `{ notes?, acquisition_date? }`
- Response: `{ collection_item }`
- Status: 200 OK

#### 7.4.4 Barcode Scanning

**POST /api/v1/scan/barcode**

- Process barcode scan from mobile app
- Request: `{ upc, party_list_id? }`
- Response: `{ game, operation, added_to_collection, added_to_party_list?, updated_existing }`
- Status: 200 OK (updated existing) or 201 Created (new game)
- **Processing Logic:**
  1. Receive UPC from mobile app
  2. Query GameUPC.com API for game metadata
  3. Check if game exists in user's collection (by title match or existing UPC)
  4. If exists: Update game record with UPC if not already present
  5. If not exists: Create new game record and add to collection
  6. If party_list_id provided: Add game to specified party list
  7. Return game data and operation performed

**GET /api/v1/scan/history**

- Get recent scan history
- Query params: `?limit=<n>`
- Response: `{ scans: [...] }`
- Status: 200 OK

**DELETE /api/v1/scan/barcode (Future)**

- Remove game from collection via barcode scan
- Request: `{ upc }`
- Response: `{ message, game_removed }`
- Status: 200 OK
- **Note:** This is a future enhancement for mobile barcode-based removal

**POST /api/v1/scan/lend (Future)**

- Mark game as lent via barcode scan
- Request: `{ upc, lent_to, notes? }`
- Response: `{ game, lent_status }`
- Status: 200 OK
- **Processing Logic:**
  1. Receive UPC from mobile app
  2. Find game in user's collection
  3. Update collection record with lent status
  4. Record lent_to, lent_date, and notes
  5. Return updated game status

**POST /api/v1/scan/return (Future)**

- Mark lent game as returned via barcode scan
- Request: `{ upc, return_notes? }`
- Response: `{ game, return_status }`
- Status: 200 OK
- **Processing Logic:**
  1. Receive UPC from mobile app
  2. Find game in user's collection
  3. Update is_lent to false
  4. Optionally archive lending history

#### 7.4.5 GameUPC Community Contribution

**POST /api/v1/collection/games/:game_id/link-barcode**

- Link a UPC barcode to a game in user's collection
- Request: `{ upc, user_contribution: true }`
- Response: `{ game, gameupc_submission_status }`
- Status: 200 OK
- **Processing Logic:**
  1. Validate UPC format (numeric, reasonable length)
  2. Update game record in database with UPC
  3. Submit mapping to GameUPC.com API:
     - POST https://api.gameupc.com/upc/{upc}/bgg_id/{bgg_id}
     - Include user_id in request body (anonymous hash of user ID)
  4. Return success status and updated game
- **Note:** This helps improve GameUPC.com crowdsource database for all users

**GET /api/v1/collection/games/:game_id/suggest-barcodes**

- Get suggested UPC barcodes from GameUPC for a specific game
- Query params: `?search=<game_title>`
- Response: `{ suggestions: [{ upc, confidence, bgg_info }] }`
- Status: 200 OK
- **Processing Logic:**
  1. Query GameUPC.com with game title or BGG ID
  2. Return list of potential UPC matches
  3. User can select correct one and submit via link-barcode endpoint
  5. Return updated game status

#### 7.4.6 Party Lists

**GET /api/v1/party-lists**

- Get user's party lists (owned and shared)
- Response: `{ owned: [...], shared: [...] }`
- Status: 200 OK

**POST /api/v1/party-lists**

- Create new party list
- Request: `{ name, description?, event_date? }`
- Response: `{ party_list }`
- Status: 201 Created

**GET /api/v1/party-lists/:list_id**

- Get party list details
- Response: `{ party_list, games: [...], shares: [...] }`
- Status: 200 OK

**PATCH /api/v1/party-lists/:list_id**

- Update party list
- Request: `{ name?, description?, event_date? }`
- Response: `{ party_list }`
- Status: 200 OK

**DELETE /api/v1/party-lists/:list_id**

- Delete party list
- Response: `{ message }`
- Status: 200 OK

**POST /api/v1/party-lists/:list_id/games**

- Add game to party list
- Request: `{ game_id }`
- Response: `{ message }`
- Status: 201 Created

**DELETE /api/v1/party-lists/:list_id/games/:game_id**

- Remove game from party list
- Response: `{ message }`
- Status: 200 OK

**POST /api/v1/party-lists/:list_id/share**

- Share party list with user
- Request: `{ username, permission }`
- Response: `{ share }`
- Status: 201 Created

**DELETE /api/v1/party-lists/:list_id/share/:share_id**

- Revoke party list share
- Response: `{ message }`
- Status: 200 OK

**POST /api/v1/party-lists/:list_id/compile**

- Compile multiple party lists
- Request: `{ party_list_ids: [...] }`
- Response: `{ compiled_games: [...], duplicates: [...] }`
- Status: 200 OK

#### 7.4.7 Game Requests

**POST /api/v1/party-lists/:list_id/requests**

- Request game from another user
- Request: `{ game_id, owner_id, message? }`
- Response: `{ request }`
- Status: 201 Created

**GET /api/v1/requests**

- Get user's game requests (sent and received)
- Response: `{ sent: [...], received: [...] }`
- Status: 200 OK

**PATCH /api/v1/requests/:request_id**

- Update request status
- Request: `{ status }`
- Response: `{ request }`
- Status: 200 OK

#### 7.4.8 Game Search

**GET /api/v1/games/search**

- Search for games
- Query params: `?q=<term>&source=<bgg|upc|local>`
- Response: `{ games: [...] }`
- Status: 200 OK

**GET /api/v1/games/:game_id**

- Get game details
- Response: `{ game }`
- Status: 200 OK

---

## 8. User Interface Design

### 8.1 Design System

**Theme:** Dark theme based on sample-style.css

**Color Palette:**

- Background: `#0f0f0f`
- Secondary Background: `#1a1a2e`
- Borders: `#333`, `#2a2a2a`
- Text Primary: `#ddd`
- Text Secondary: `#888`, `#666`
- Accent: `#7eb8f7`
- Error Background: `#3b0000`
- Error Border: `#c0392b`
- Error Text: `#ff6b6b`

**Typography:**

- Base: `system-ui, sans-serif`, 14px
- Headers: 1.2rem, `#7eb8f7`

**Components:**

- Inputs: Dark background `#1e1e1e`, border `#333`
- Tables: Sticky headers, hover effects
- Buttons: Consistent styling across app

### 8.2 Page Layouts

#### 8.2.1 Login Screen

- Centered login form
- Username field
- Password field
- Login button
- "Forgot Password" link
- "Create Account" link
- Clean, minimal design

#### 8.2.2 Create Account Screen

- Username field
- Email field
- BoardGameGeek.com username field (optional)
- Password field
- Confirm password field
- Terms acceptance checkbox
- Create Account button
- Back to Login link

#### 8.2.3 Email Verification Screen

- Message showing verification email sent
- Resend verification email button
- Back to Login link

#### 8.2.4 Main Collection Screen

- Header with app title, stats bar, user menu
- **Informational Banner (collapsible):**
  - "ℹ️ Barcode scanning uses crowdsourced data from GameUPC.com. You may be asked to help verify game information when scanning. You can also manually link barcodes to your games to help the community."
  - Link to "How it works" explanation
  - Dismiss button (stores preference)
- Search and filter controls
- Filter options: All / Available / Lent Out (future) / Missing Barcode
- "Sync from BoardGameGeek.com" button (prominent)
- Results info (e.g., "Showing 24 of 156 games")
- Game table with columns:
  - Thumbnail
  - Title
  - Year
  - Players
  - Play Time
  - Barcode Status (icon: ✓ if UPC present, "Link" button if missing)
  - Status (future: "Lent to [Person]" indicator)
  - Actions (View, Remove)
- Visual indicator for lent games (future: badge or icon)
- Pagination controls
- Empty state: "Your collection is empty. Sync from BoardGameGeek or scan a barcode to get started."

#### 8.2.4a Game Detail / Edit Screen

- Game information display (title, year, players, etc.)
- Collection notes editor
- **Barcode Management Section:**
  - If UPC exists: Display UPC with "Edit" button
  - If UPC missing: "Link Barcode" form
    - Manual UPC entry field
    - "Search GameUPC" button to find suggestions
    - Explanation: "Help the community by linking this game's barcode"
  - Submit button to add/update UPC
  - Success message: "Barcode linked! This helps other users too."
- Acquisition date
- Source indicator (BGG sync, manual, barcode)
- Remove from collection button

#### 8.2.5 Profile Screen

- User profile information
- Edit username form
- Display email (non-editable)
- Display BoardGameGeek.com username (non-editable)
- Password change section
- Account deletion option

#### 8.2.6 API Key Management Screen

- Mobile-friendly layout
- List of existing API keys with names, created dates, last used
- Generate New API Key button
- Copy to clipboard functionality
- Revoke buttons per key
- Instructions for mobile app setup

#### 8.2.7 Party Lists Screen

- List of user's party lists
- Create New Party List button
- Each list shows:
  - Name
  - Event date
  - Game count
  - Shared with count
- Actions: View, Edit, Share, Delete

#### 8.2.8 Party List Detail Screen

- Party list name and description
- Event date
- List of games in party list
- Add Game button
- Share list controls
- Compile with other lists button
- Game request inbox/outbox

### 8.3 Mobile App Screens

#### 8.3.1 Setup/Login Screen

- Instructions for obtaining API key
- API key input field
- Connect button
- Link to web app

#### 8.3.2 Main Scanning Screen

- Large viewfinder for camera
- Scanning status indicator
- Mode selector (Collection / Party List / Remove / Lend - future modes)
- Party list selector (when in party list mode)
- Recent scans list
- Settings/profile icon

#### 8.3.3 Collection View

- Simple list of user's games
- Visual indicator for lent games (future)
- Filter options: All / Available / Lent Out (future)
- Search functionality
- Pull to refresh
- Tap to view game details

#### 8.3.4 Settings Screen

- User information
- API key status
- Sign out button
- About/version info

#### 8.3.5 Future: Lending Management Screen

- List of all currently lent games
- Each entry shows:
  - Game name and image
  - Lent to (person/contact)
  - Lent date
  - Days lent
  - Notes
- Tap to view details or mark as returned
- Sort by: Date lent, Person, Game name
- Search/filter functionality

#### 8.3.6 Future: Scan Mode Screen

- Mode selection before scanning:
  - **Add to Collection** (default)
  - **Add to Party List**
  - **Remove from Collection**
  - **Lend Game**
  - **Return Game**
- Each mode shows:
  - Icon
  - Description
  - Color-coded for easy identification
- Selected mode persists until changed
- Confirmation prompt for destructive actions (Remove)

---

## 9. Security Considerations

### 9.1 Authentication & Authorization

1. **Password Security:**
   - Use bcrypt or Argon2 for password hashing
   - Minimum password length: 8 characters
   - Password complexity requirements
   - Secure password reset flow with time-limited tokens

2. **API Key Security:**
   - Generate cryptographically secure random API keys (256-bit)
   - Store hashed versions in database
   - Support key rotation
   - Log API key usage

3. **Session Management:**
   - Secure session tokens
   - HTTP-only cookies
   - CSRF protection
   - Session timeout

### 9.2 Data Protection

1. **HTTPS Everywhere:**
   - Enforce HTTPS for all connections
   - HSTS headers
   - Secure cookie flags

2. **Input Validation:**
   - Validate all user inputs
   - Sanitize data before database insertion
   - Parameterized queries to prevent SQL injection

3. **Output Encoding:**
   - HTML entity encoding to prevent XSS
   - Content Security Policy headers

4. **Sensitive Data:**
   - SMTP credentials in environment variables
   - No passwords or API keys in logs
   - Database backups encrypted at rest

### 9.3 API Security

1. **Rate Limiting:**
   - Per-user rate limits
   - Per-IP rate limits
   - Throttling for authentication endpoints

2. **API Key Permissions:**
   - Scope API keys to specific operations
   - Audit trail for API key usage
   - Automatic key revocation after suspicious activity

3. **CORS Configuration:**
   - Restrict origins
   - Proper preflight handling

### 9.4 Third-Party Integration Security

1. **BoardGameGeek.com API:**
   - Respect rate limits
   - Handle API errors gracefully
   - Don't expose user BGG credentials

2. **GameUPC.com API:**
   - Validate responses
   - Handle malicious data
   - API key rotation

### 9.5 Mobile App Security

1. **API Key Storage:**
   - Use platform secure storage (Keychain/KeyStore)
   - Never log API keys

2. **Network Security:**
   - Certificate pinning consideration
   - Validate SSL certificates

---

## 10. Integration Points

### 10.1 BoardGameGeek.com API

**Purpose:** Sync user's board game collection metadata

**Endpoints:**

- Collection API: `https://boardgamegeek.com/xmlapi2/collection?username={username}`
- Game details: `https://boardgamegeek.com/xmlapi2/thing?id={id}`

**Integration Requirements:**

- Respect BGG API rate limits (avoid hammering)
- Parse XML responses
- Handle API unavailability
- Map BGG game IDs to local database
- Support incremental sync (future)

**Data Mapping:**

- BGG game ID → games.bgg_id
- Game name, year, players, playtime, description, images
- User ownership status

**Important:** BGG data does **not** include UPC/barcode information. The `upc` field will remain null for BGG-synced games until they are scanned via the mobile app.

**Future Consideration:**

- POST updates to BGG collection (investigate BGG API capabilities)
- OAuth authentication with BGG

### 10.2 GameUPC.com API

**Purpose:** Look up board games by UPC barcode (exclusive source for barcode data)

**Base URL:** `https://gameupc.com/`

**Integration Requirements:**

- API key authentication (store securely)
- Handle rate limits
- Parse JSON responses
- Handle "not found" cases
- Link retrieved game data to BGG data if possible

**Data Mapping:**

- UPC → games.upc
- Game details → games table

**Barcode Processing Flow:**

1. Mobile app scans barcode and sends UPC to web app
2. Web app queries GameUPC.com with UPC
3. Retrieve game metadata (title, year, etc.)
4. Check if game exists in user's collection:
   - **Match by title or existing BGG ID**
   - If found: Update game record with UPC information
   - If not found: Create new game record with full metadata from GameUPC
5. Add to user's collection if not already present
6. If in party list mode: Add to specified party list

**Note:** BoardGameGeek.com data does not contain UPC/barcode information. Barcodes come exclusively from mobile app scans via GameUPC.com.

**Error Handling:**

- Unknown UPC: Allow manual game entry
- API down: Queue for later retry
- Duplicate detection: Use fuzzy matching on title if needed

### 10.3 CodeMagic.io CI/CD

**Purpose:** Build and compile mobile app for Android and iOS

**Configuration:**

- Create `codemagic.yaml` in mobile app repository
- Configure build workflows for both platforms
- Set up code signing certificates
- Configure environment variables for API endpoints
- Automatic builds on git push
- Deploy to Firebase App Distribution

**Build Artifacts:**

- Android: APK/AAB
- iOS: IPA

### 10.4 Firebase Distribution

**Purpose:** Distribute mobile app to testers and users

**Configuration:**

- Set up Firebase project
- Configure app distribution
- Create release groups
- Integrate with CodeMagic.io for automatic uploads

**Release Flow:**

1. Code pushed to repository
2. CodeMagic.io builds app
3. Build uploaded to Firebase
4. Testers notified
5. Users download/update app

---

## 11. Deployment Strategy

### 11.1 Infrastructure

**Hosting:**

- Domain: boardgames.tendimensions.com
- Server: Linux-based (Ubuntu/Debian recommended)
- Docker host

**Components:**

- Nginx (installed on host)
- Docker container running web application
- SQLite database (inside container, volume mounted)

### 11.2 Docker Configuration

**Dockerfile:**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Collect static files
RUN python manage.py collectstatic --noinput

# Expose port
EXPOSE 8000

# Run application with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "boardgame_catalog.wsgi:application"]
```

**docker-compose.yml:**

```yaml
version: '3.8'

services:
  web:
    build: .
    container_name: boardgame_catalog
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data  # SQLite database
      - ./logs:/app/logs
    environment:
      - ENV=production
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
      - BGG_API_KEY=${BGG_API_KEY}
      - GAMEUPC_API_KEY=${GAMEUPC_API_KEY}
      - SECRET_KEY=${SECRET_KEY}
    restart: unless-stopped
```

**.env file (not committed to repository):**

```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@tendimensions.com
SMTP_PASSWORD=<secure-password>
BGG_API_KEY=<if-required>
GAMEUPC_API_KEY=<api-key>
SECRET_KEY=<random-secret-key>
```

### 11.3 Nginx Configuration

**Site configuration (`/etc/nginx/sites-available/boardgames.tendimensions.com`):**

```nginx
server {
    listen 80;
    server_name boardgames.tendimensions.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name boardgames.tendimensions.com;

    ssl_certificate /etc/letsencrypt/live/boardgames.tendimensions.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/boardgames.tendimensions.com/privkey.pem;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 11.4 SSL/TLS

- Use Let's Encrypt for free SSL certificates
- Certbot for automatic renewal
- Setup: `certbot --nginx -d boardgames.tendimensions.com`

### 11.5 Database Backups

**Backup Script:**

```bash
#!/bin/bash
BACKUP_DIR="/backups/boardgame_catalog"
DATE=$(date +%Y%m%d_%H%M%S)
docker exec boardgame_catalog sqlite3 /app/data/db.sqlite3 ".backup /app/data/backup_${DATE}.db"
docker cp boardgame_catalog:/app/data/backup_${DATE}.db ${BACKUP_DIR}/
# Keep last 30 days
find ${BACKUP_DIR} -name "backup_*.db" -mtime +30 -delete
```

**Cron job:**

```
0 2 * * * /usr/local/bin/backup-boardgame-db.sh
```

### 11.6 Deployment Process

1. **Initial Setup:**
   - Clone repository to server
   - Create `.env` file with secrets
   - Build Docker image: `docker-compose build`
   - Start container: `docker-compose up -d`
   - Run migrations: `docker exec boardgame_catalog python manage.py migrate`
   - Configure Nginx
   - Setup SSL with Certbot

2. **Updates:**
   - Pull latest code: `git pull`
   - Rebuild image: `docker-compose build`
   - Restart container: `docker-compose up -d`
   - Run migrations if needed

3. **Monitoring:**
   - Check container status: `docker ps`
   - View logs: `docker logs boardgame_catalog`
   - Monitor Nginx logs: `/var/log/nginx/`

---

## 12. Development Roadmap

### Phase 1: Foundation (Weeks 1-3)

**Objectives:**

- Project setup
- Basic infrastructure
- User authentication

**Deliverables:**

1. **Project Initialization:**
   - Initialize Django 5.0+ project
   - Set up Django REST Framework for mobile API
   - Configure HTMX and Alpine.js for dynamic UI
   - Initialize repositories (web app, mobile app)
   - Set up development environments
   - Create database schema (Django migrations)

2. **User Management:**
   - User registration with email verification
   - Login/logout functionality
   - Password reset flow
   - Profile management
   - **Django Admin:** Configure admin interface for user/collection management and analytics

3. **Infrastructure:**
   - Docker configuration
   - Basic Nginx setup
   - Development/staging environment

### Phase 2: Core Collection Features (Weeks 4-6)

**Objectives:**

- BoardGameGeek.com integration
- Collection management

**Deliverables:**

1. **Collection Display:**
   - Collection list view
   - Search and filtering
   - Empty state handling

2. **BGG Integration:**
   - BGG API client implementation
   - Collection sync functionality
   - Progress feedback for sync
   - Error handling

3. **Manual Game Management:**
   - Add games manually
   - Edit game details
   - Remove games from collection

### Phase 3: API & Mobile App Foundation (Weeks 7-9)

**Objectives:**

- RESTful API
- API key authentication
- Basic mobile app

**Deliverables:**

1. **API Development:**
   - API endpoint implementation
   - API key generation/management
   - Authentication middleware
   - Rate limiting

2. **Mobile App Setup:**
   - Flutter project initialization
   - API client implementation
   - API key authentication
   - Basic UI framework

3. **Barcode Scanning:**
   - Native barcode scanner integration
   - GameUPC.com API integration
   - Continuous scanning mode
   - Audio feedback

### Phase 4: Advanced Features (Weeks 10-12)

**Objectives:**

- Party lists
- Sharing functionality
- Game requests

**Deliverables:**

1. **Party Lists:**
   - Create/edit/delete party lists
   - Add games to party lists
   - Party list mobile scanning mode

2. **Sharing:**
   - Share party lists with users
   - Compiled party list view
   - Duplicate detection

3. **Game Requests:**
   - Request game from another user
   - View/manage requests
   - Accept/decline requests

### Phase 5: Polish & Deploy (Weeks 13-14)

**Objectives:**

- UI refinement
- Testing
- Production deployment

**Deliverables:**

1. **UI/UX Polish:**
   - Responsive design refinement
   - Error message improvement
   - Loading states
   - Mobile app UI polish

2. **Testing:**
   - Unit tests for critical functions
   - API endpoint testing
   - Mobile app testing on devices
   - User acceptance testing

3. **Deployment:**
   - Production server setup
   - SSL configuration
   - Database migration
   - Mobile app distribution via Firebase
   - Documentation

### Phase 6: Post-Launch (Ongoing)

**Objectives:**

- Monitoring
- Bug fixes
- Feature enhancements

**Activities:**

- User feedback collection
- Performance monitoring
- Security audits
- Feature requests prioritization
- BGG bidirectional sync investigation

**Future Feature Development:**

1. **Mobile Barcode Collection Removal:**
   - Add "Remove from Collection" scanning mode to mobile app
   - Implement DELETE /api/v1/scan/barcode endpoint
   - Add confirmation dialogs and undo functionality
   - Update mobile app UI to support mode switching

2. **Game Lending Tracking:**
   - Implement "Lend Game" scanning mode in mobile app
   - Add API endpoints for lend/return operations
   - Update database schema (already planned in user_collections)
   - Create lending history view in web app
   - Add visual indicators for lent games in collection views
   - Implement filters for "Lent Games" and "Available Games"
   - Add optional reminder system for overdue loans
   - Consider contact picker integration on mobile

3. **Lending History & Analytics:**
   - Create separate lending_history table for audit trail
   - Show lending statistics (most borrowed, average loan duration)
   - Export lending history reports

---

## 13. Testing Strategy

### 13.1 Unit Testing

**Web Application:**

- Test user authentication functions
- Test password hashing/verification
- Test API key generation
- Test database models and queries
- Test BGG API client
- Test GameUPC API client
- Coverage target: 70%+

**Mobile Application:**

- Test API client
- Test barcode scanning handling
- Test data models
- Test offline caching
- Coverage target: 60%+

### 13.2 Integration Testing

- Test API endpoints end-to-end
- Test BGG sync flow
- Test barcode scanning → collection flow
- Test party list creation → sharing flow
- Test email sending

### 13.3 API Testing

- Use Postman/Insomnia for manual testing
- Automated API tests with pytest/jest
- Test authentication
- Test error responses
- Test rate limiting

### 13.4 Mobile App Testing

**Devices:**

- Android: Various versions (10+)
- iOS: iPhone models (iOS 13+)
- Different screen sizes

**Testing Focus:**

- Barcode scanning accuracy
- Network error handling
- API key authentication
- Offline functionality

### 13.5 User Acceptance Testing

- Recruit beta testers
- Test all user flows
- Collect feedback
- Iterate on issues

### 13.6 Security Testing

- SQL injection testing
- XSS testing
- CSRF testing
- Authentication bypass attempts
- API key security validation

### 13.7 Performance Testing

- Load testing for concurrent users
- Stress testing API endpoints
- Database query optimization
- Mobile app responsiveness

---

## 14. Open Questions and Issues

### 14.1 Technology Stack Decisions

For architectural decisions, see the Architecture Decision Records (ADRs) in the `docs/adr/` directory:

- **[ADR-0001: Use Django as Web Framework](docs/adr/0001-use-django-as-web-framework.md)** - Django 5.0+ selected for development velocity, built-in features, and solo developer context
- **[ADR-0002: Use Server-Side Rendering with HTMX](docs/adr/0002-use-server-side-rendering-with-htmx.md)** - SSR with HTMX/Alpine.js for simplicity and development speed
- **[ADR-0003: External API Integration Strategy](docs/adr/0003-external-api-integration-strategy.md)** - BGG rate limiting approach and GameUPC community contribution model

### 14.2 BoardGameGeek.com Integration

**DESIGN DECISION CONFIRMED:** BoardGameGeek.com data does not contain barcode/UPC information. BGG sync will populate game metadata (title, year, players, images, etc.) but the UPC field will remain null until the game is scanned via the mobile app.

**Implementation Strategy:** See [ADR-0003: External API Integration Strategy](docs/adr/0003-external-api-integration-strategy.md) for rate limiting, caching, and retry logic decisions.

**ISSUE-012: BGG Authentication**

- **Question:** Does BGG require OAuth or API keys? How do we authenticate on behalf of users?
- **Research needed:** BGG API authentication documentation
- **Impacts:** Sync implementation
- **Current approach:** Username-only (no password) for read-only collection access
- **RESOLVED:** See [ADR-0003: External API Integration Strategy](docs/adr/0003-external-api-integration-strategy.md) - BGG username is a public identifier; no authentication required

### 14.3 GameUPC.com Integration

**DESIGN DECISION CONFIRMED:** Barcode (UPC) information comes exclusively from mobile app scans via GameUPC.com API. BoardGameGeek.com data does not contain barcode information. When a barcode is scanned, the system will check if the game exists in the user's collection and either update the existing record with UPC info or create a new record.

**Implementation Strategy:** See [ADR-0003: External API Integration Strategy](docs/adr/0003-external-api-integration-strategy.md) for API access details, UPC coverage handling, and community contribution model.

**Key Facts (from ADR-0003):**
- GameUPC API is completely FREE with no authentication required
- ~42% UPC verification rate (9,615 verified / 22,996 suggestions)
- Users contribute mappings back via web app to improve community database

**ISSUE-023: Game Matching Logic**

- **Question:** What algorithm should be used to match GameUPC data to existing BGG-synced games?
- **Considerations:**
  - Exact title match
  - Fuzzy title matching (Levenshtein distance, etc.)
  - Year published as secondary validation
  - Publisher/designer as tertiary validation
- **Impacts:** Accuracy of avoiding duplicate game entries
- **Decision needed by:** Phase 3 start

### 14.4 Party List Features

**ISSUE-030: Party List Visibility**

- **Question:** Should party lists be public, private, or have configurable visibility?
- **Current assumption:** Explicitly shared only
- **User story clarification needed:** How do users discover others' lists?

**ISSUE-031: Party List Compilation**

- **Question:** How should the UI handle compiling multiple party lists? Separate page or modal?
- **Design needed:** Wireframe for compiled view

**ISSUE-032: Game Request Workflow**

- **Question:** Should game requests include in-app notifications? Email notifications?
- **Consideration:** Push notifications for mobile app?
- **Impacts:** Notification system implementation

### 14.5 Mobile App

**ISSUE-040: Native vs. Flutter Barcode Libraries**

- **Question:** Which Flutter barcode scanning package should be used? (mobile_scanner, barcode_scan2, etc.)
- **Evaluation needed:** Compare packages for reliability, platform support, maintenance
- **Decision needed by:** Phase 3 start

**ISSUE-041: Offline Mode**

- **Question:** What data should be cached offline? Should scans be queued when offline?
- **User story clarification needed:** Typical use case scenarios
- **Impacts:** Local storage strategy

**ISSUE-042: iOS Testing Requirements**

- **Question:** Do we have access to iOS devices and Apple Developer account for testing?
- **Action required:** Verify Apple Developer Program enrollment
- **Impacts:** iOS build and distribution timeline

### 14.6 Security & Privacy

**ISSUE-050: SMTP Provider**

- **Question:** Which SMTP provider should be used? (Gmail, SendGrid, AWS SES, Mailgun)
- **Considerations:**
  - Cost
  - Reliability
  - Deliverability rates
  - Setup complexity
- **Decision needed by:** Phase 1

**ISSUE-051: Password Requirements**

- **Question:** What specific password complexity requirements should be enforced?
- **Current assumption:** Minimum 8 characters
- **Consideration:** Add requirement for mixed case, numbers, special characters?
- **RESOLVED:** See [ADR-0004: Authentication and Security Policies](docs/adr/0004-authentication-and-security-policies.md) - 8-character minimum, no complexity requirements to reduce friction

**ISSUE-052: GDPR Compliance**

- **Question:** Are there GDPR or other privacy regulations to consider?
- **Consideration:** User data export, right to be forgotten
- **Impacts:** Account deletion implementation, privacy policy

### 14.7 Deployment & Operations

**ISSUE-060: Server Hosting**

- **Question:** Where will the server be hosted? (AWS, DigitalOcean, Linode, etc.)
- **Considerations:**
  - Cost
  - Reliability
  - Geographic location
  - Scaling options
- **Decision needed by:** Phase 5

**ISSUE-061: Database Scaling**

- **Question:** At what point should we migrate from SQLite to PostgreSQL/MySQL?
- **Current assumption:** SQLite sufficient for MVP
- **Monitoring:** Track database size and performance
- **Migration plan needed:** If user base grows significantly

**ISSUE-062: Monitoring & Logging**

- **Question:** What monitoring and logging tools should be used?
- **Options:** ELK Stack, Prometheus+Grafana, cloud-native solutions
- **Consideration:** Cost vs. features
- **Decision needed by:** Phase 5

**ISSUE-063: Backup Strategy**

- **Question:** Should backups be stored offsite? How long should backups be retained?
- **Current plan:** Daily backups, 30-day retention
- **Consideration:** Offsite backup to cloud storage (S3, etc.)

### 14.8 User Experience

**ISSUE-070: Empty Collection Onboarding**

- **Question:** What's the best onboarding flow for new users with empty collections?
- **Ideas:**
  - Tutorial overlay
  - Sample data
  - Guided first sync
- **Design needed:** Onboarding wireframes

**ISSUE-071: Game Image Handling**

- **Question:** How should game images be stored? Cache from BGG? Store locally?
- **Consideration:** Storage costs, copyright, loading performance
- **Current assumption:** Store URLs, display from external sources

**ISSUE-072: Mobile App Icon & Branding**

- **Question:** What should the app icon and branding look like?
- **Action required:** Design app icon, logo
- **Decision needed by:** Phase 3

### 14.9 Features & Scope

**ISSUE-080: Multi-User Collections**

- **Question:** Should users be able to mark games as "co-owned" with other users?
- **User story clarification needed:** Is this a common use case?
- **Impacts:** Data model changes

**ISSUE-081: Game Wishlists**

- **Question:** Should users have wishlist functionality separate from owned collection?
- **User story clarification needed:** Priority for MVP?
- **Potential:** Future enhancement

**ISSUE-082: Game Plays Tracking**

- **Question:** Should users be able to track when they play games (play history)?
- **Consideration:** BGG supports play logging
- **Potential:** Future enhancement

**ISSUE-083: Collection Statistics**

- **Question:** What statistics should be displayed on the main screen? (Total games, total value, most played, etc.)
- **Design needed:** Stats bar content

**ISSUE-084: Search Functionality**

- **Question:** Should search be simple text match or more advanced (fuzzy search, filters)?
- **Current assumption:** Basic text search with filters
- **Enhancement:** Full-text search if needed

**ISSUE-085: Analytics and Usage Tracking (Future Enhancement)**

- **Question:** What analytics should be tracked for site usage and user behavior?
- **Options:**
  - Django Admin: Built-in user management, view/edit collections, API keys
  - Custom analytics dashboard: User registrations over time, active users, collections stats
  - Usage metrics: Most synced games, popular party list features, BGG sync frequency
  - Performance monitoring: API response times, BGG sync duration
- **Implementation:**
  - Django Admin provides immediate data management capabilities
  - Custom analytics views can be added as needed (Phase 6+)
  - Consider privacy-focused analytics (no user tracking)
  - Database queries for aggregate statistics
- **Privacy consideration:** Aggregate data only, no personal tracking
- **Decision needed by:** Phase 6
- **Note:** Django Admin already provides user management; custom analytics would be future enhancement

### 14.10 Legal & Business

**ISSUE-090: Terms of Service**

- **Question:** What should be included in Terms of Service and Privacy Policy?
- **Action required:** Draft legal documents or consult legal advisor
- **Required for:** Production launch

**ISSUE-091: BoardGameGeek.com Attribution**

- **Question:** Are there attribution requirements when using BGG data?
- **Research needed:** Review BGG API terms of service
- **Impacts:** UI footer or attribution page

**ISSUE-092: Data Ownership**

- **Question:** Who owns the collection data? What happens if the service shuts down?
- **Consideration:** Data export functionality
- **User assurance:** Clear data ownership policy

### 14.11 Future Features

**ISSUE-100: Mobile Barcode Deletion Confirmation**

- **Question:** What level of confirmation is needed when deleting via barcode scan?
- **Options:**
  - Simple confirmation dialog
  - Swipe-to-confirm gesture
  - Require re-scan to confirm
  - Undo buffer (30-second window)
- **Consideration:** Prevent accidental deletions while maintaining speed
- **Decision needed by:** Phase 6

**ISSUE-101: Deletion Behavior vs. Web**

- **Question:** Should mobile barcode deletion have different behavior than web deletion?
- **Considerations:**
  - Web deletion: Permanent with confirmation
  - Mobile barcode deletion: Quick action, might need undo
  - Should deleted games go to a "trash" temporarily?
- **Decision needed by:** Phase 6

**ISSUE-102: Game Lending - Contact Integration**

- **Question:** Should the "lent to" field integrate with device contacts?
- **Options:**
  - Free text entry only
  - Contact picker with fallback to text
  - User account lookup (if lent to another system user)
- **Privacy consideration:** Access to contacts permissions
- **Decision needed by:** Phase 6

**ISSUE-103: Lending Reminders**

- **Question:** Should the system send reminders for lent games?
- **Options:**
  - Push notifications after X days
  - Email reminders
  - In-app "overdue" indicator
  - User-configurable reminder periods
- **Consideration:** Could be perceived as nagging
- **User preference:** Should be opt-in
- **Decision needed by:** Phase 6

**ISSUE-104: Bidirectional BGG Sync**

- **Future Feature:** Sync lent/borrowed status, wishlist changes, or play logs back to BoardGameGeek
- **Current Decision:** No bidirectional sync in MVP. BGG sync is one-way (BGG → our system)
- **Rationale:** Reduces complexity, avoids sync conflicts, BGG API may not support write operations for all data
- **Future Investigation:** Research BGG API capabilities for POST/PUT operations on user collections
- **Decision needed by:** Post-MVP (if user demand exists)

**ISSUE-104: Lending History Tracking**

- **Question:** How detailed should lending history be?
- **Options:**
  - Simple current status only
  - Full audit trail in separate table
  - Analytics (most borrowed games, frequent borrowers)
- **Storage consideration:** Historical data growth
- **Decision needed by:** Phase 6

**ISSUE-105: Lent Games in Party Lists**

- **Question:** Should lent games be addable to party lists?
- **Scenarios:**
  - Game might be returned before party
  - Visual indicator that game is currently lent
  - Warning when adding lent game
  - Option to send request to borrower
- **User flexibility:** Allow but warn
- **Decision needed by:** Phase 6

**ISSUE-106: Multiple Lending Records**

- **Question:** Can a user lend the same game multiple times (multiple copies)?
- **Current schema:** Assumes one copy per game
- **Enhancement:** Track quantity owned
- **Workaround:** Add separate collection entries for multiple copies
- **Future consideration:** Quantity tracking system

**ISSUE-107: Barcode Scan Mode Switching**

- **Question:** How should users switch between scan modes (add/delete/lend/party)?
- **Options:**
  - Mode selector on main screen
  - Swipe between modes
  - Long-press to change mode
  - Separate screens for each mode
- **UX consideration:** Must be clear which mode is active
- **Decision needed by:** Phase 6

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | March 14, 2026 | AI Assistant | Initial document creation based on USER_SPECS.md |
| 1.1 | March 14, 2026 | AI Assistant | Fixed architecture diagram to show mobile→web app→external APIs flow |
| 1.2 | March 14, 2026 | AI Assistant | Added barcode handling logic: BGG has no UPC data, update vs. create flow, GameUPC as exclusive barcode source |
| 1.3 | March 14, 2026 | AI Assistant | Added future features: mobile barcode deletion and game lending tracking with associated requirements, API endpoints, database schema updates, and open questions |
| 2.0 | March 15, 2026 | AI Assistant | **TECH STACK DECISION**: Django 5.0+ with SSR + HTMX. Updated entire document: resolved ISSUE-001 (Django) and ISSUE-002 (SSR), updated technology stack section, deployment examples, and Phase 1 deliverables. Rationale: sole developer, Python preference, 14-week timeline, built-in admin/auth/ORM. |

---

## Appendices

### Appendix A: References

**Web Framework & Tools:**
- Django: <https://www.djangoproject.com/>
- Django REST Framework: <https://www.django-rest-framework.org/>
- HTMX: <https://htmx.org/>
- Alpine.js: <https://alpinejs.dev/>

**APIs & Integrations:**
- BoardGameGeek.com API: <https://boardgamegeek.com/wiki/page/BGG_XML_API2>
- GameUPC.com: <https://gameupc.com/>

**Mobile Development:**
- Flutter: <https://flutter.dev/>
- CodeMagic.io: <https://codemagic.io/>
- Firebase: <https://firebase.google.com/>

**Infrastructure:**
- Docker: <https://www.docker.com/>
- Nginx: <https://nginx.org/>
- PostgreSQL: <https://www.postgresql.org/>

### Appendix B: Glossary

- **BGG:** BoardGameGeek.com
- **UPC:** Universal Product Code (barcode)
- **API:** Application Programming Interface
- **REST:** Representational State Transfer
- **CI/CD:** Continuous Integration/Continuous Deployment
- **SMTP:** Simple Mail Transfer Protocol
- **HTTPS:** Hypertext Transfer Protocol Secure
- **MVP:** Minimum Viable Product
- **CRUD:** Create, Read, Update, Delete
- **SSR:** Server-Side Rendering (HTML generated on server, sent to browser)
- **SPA:** Single Page Application (JavaScript-heavy frontend)
- **HTMX:** Library for adding dynamic behavior to HTML without writing JavaScript
- **ORM:** Object-Relational Mapping (database abstraction layer)
- **Scan Mode:** Operating mode in mobile app determining action when barcode is scanned (add, delete, lend, etc.)
- **Lent Game:** Game marked as temporarily loaned to another person
- **Lending History:** Historical record of all game loans and returns

---

**END OF DOCUMENT**
