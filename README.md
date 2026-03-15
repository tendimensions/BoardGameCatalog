# Board Game Catalog

A comprehensive web and mobile application for managing your board game collection, syncing with BoardGameGeek, and organizing game nights with friends.

## 🎲 Overview

Board Game Catalog helps board game enthusiasts organize their collections, discover games via barcode scanning, sync with BoardGameGeek, and coordinate game nights with party lists. Built with Django and Flutter for a seamless cross-platform experience.

## ✨ Features

### Current Roadmap

**Phase 1: Core Web Application** (MVP)
- User registration and authentication
- Manual game collection management
- Game search and filtering
- Basic collection views and statistics

**Phase 2: BoardGameGeek Integration**
- One-way sync from BGG to local collection
- Game metadata enrichment (images, ratings, descriptions)
- Rate-limited, polite API integration

**Phase 3: Mobile App (Flutter)**
- Barcode scanning for instant game addition
- Mobile-friendly collection browsing
- Offline-capable game lookup

**Phase 4: Party Lists**
- Create game lists for specific events/parties
- Compile games from multiple users' collections
- Request to borrow games from friends

**Phase 5: Deployment**
- Production server setup
- Docker containerization
- PostgreSQL migration

**Phase 6: Future Enhancements**
- Game lending/borrowing tracking
- Mobile barcode deletion workflow
- Advanced search and filtering
- Collection statistics and insights

## 🛠️ Tech Stack

### Web Application
- **Framework:** Django 5.0+
- **Rendering:** Server-Side Rendering (SSR) with Django Templates
- **Interactivity:** HTMX + Alpine.js for progressive enhancement
- **Database:** SQLite (development) → PostgreSQL (production)
- **API:** Django REST Framework for mobile client

### Mobile Application
- **Framework:** Flutter
- **Platforms:** iOS and Android
- **Features:** Barcode scanning, offline support, REST API integration

### External Integrations
- **BoardGameGeek.com XML API:** Game metadata and user collection sync
- **GameUPC.com API:** Barcode (UPC) to game mapping with community contributions

### Infrastructure
- **Deployment:** Docker + Nginx
- **Email:** SMTP (provider TBD)
- **Storage:** Local filesystem → Cloud storage (future)

## 📁 Project Structure

```
BoardGameCatalog/
├── docs/
│   └── adr/                    # Architecture Decision Records
├── REQUIREMENTS-AND-DESIGN.md  # Comprehensive project documentation
├── USER_SPECS.md               # Original user specifications
└── README.md                   # This file
```

## 📚 Documentation

- **[Requirements & Design](REQUIREMENTS-AND-DESIGN.md)** - Comprehensive requirements document with 90+ requirements, database schema, API specifications, and development phases
- **[Architecture Decision Records](docs/adr/)** - Documents key architectural decisions:
  - [ADR-0001: Django Framework Selection](docs/adr/0001-use-django-as-web-framework.md)
  - [ADR-0002: Server-Side Rendering with HTMX](docs/adr/0002-use-server-side-rendering-with-htmx.md)
  - [ADR-0003: External API Integration Strategy](docs/adr/0003-external-api-integration-strategy.md)
  - [ADR-0004: Authentication and Security Policies](docs/adr/0004-authentication-and-security-policies.md)

## 🚀 Getting Started

### Prerequisites

- Python 3.11+
- pip and virtualenv
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/tendimensions/BoardGameCatalog.git
cd BoardGameCatalog

# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Start development server
python manage.py runserver
```

Visit `http://localhost:8000` to view the application.

### Configuration

Development configuration uses:
- SQLite database
- Django's console email backend
- DEBUG mode enabled

## 🗄️ Database Schema

The application uses 8+ interconnected tables:

- **Users** - Django's built-in authentication
- **Games** - Board game metadata (title, year, players, etc.)
- **UserCollections** - User-owned games with acquisition details
- **BoardGameGeekLinks** - BGG integration data (ratings, complexity)
- **Barcodes** - UPC/barcode mappings
- **PartyLists** - Game event/party planning
- **GameRequests** - Borrow/lend game requests
- **LendingHistory** - Game lending tracking (future)

See [REQUIREMENTS-AND-DESIGN.md](REQUIREMENTS-AND-DESIGN.md) for complete schema details.

## 🔑 Key Design Decisions

### Why Django?
- Solo developer context: Built-in auth, admin, ORM, templates
- Rapid development velocity for 14-week project
- Mature ecosystem with extensive documentation
- Seamless progression from SQLite to PostgreSQL

### Why Server-Side Rendering?
- Simplicity: No separate frontend build process
- SEO-friendly: Content rendered on server
- Progressive enhancement: HTMX for interactivity without SPA complexity
- Faster initial development for solo developer

### External API Strategy
- **BoardGameGeek:** 2-second rate limiting, HTTP 202 retry logic, 24-hour caching
- **GameUPC:** Free API, bidirectional data flow (query + contribute mappings)
- Polite, community-conscious integration patterns

## 🧪 Testing

```bash
# Run all tests
python manage.py test

# Run with coverage
coverage run --source='.' manage.py test
coverage report
```

## 🤝 Contributing

This is a personal project, but contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📅 Project Timeline

- **Weeks 1-2:** Phase 1 - Core Web Application
- **Weeks 3-4:** Phase 2 - BoardGameGeek Integration
- **Weeks 5-8:** Phase 3 - Mobile App Development
- **Weeks 9-11:** Phase 4 - Party Lists & Social Features
- **Week 12:** Phase 5 - Deployment
- **Weeks 13-14:** Phase 6 - Polish & Future Features

## 📄 License

[Choose appropriate license - MIT, GPL, Apache 2.0, etc.]

## 🙏 Acknowledgments

- **BoardGameGeek.com** - For providing the community-driven game database and API
- **GameUPC.com** - For the crowdsourced barcode-to-game mapping service
- **Django Community** - For the excellent framework and ecosystem
- **Flutter Team** - For the cross-platform mobile framework

## 📞 Contact

- **Repository:** [https://github.com/tendimensions/BoardGameCatalog](https://github.com/tendimensions/BoardGameCatalog)
- **Issues:** [https://github.com/tendimensions/BoardGameCatalog/issues](https://github.com/tendimensions/BoardGameCatalog/issues)

---

**Project Status:** 🚧 Planning & Early Development

Currently in the planning phase with comprehensive requirements documentation complete. Phase 1 development (Core Web Application) starting soon.
