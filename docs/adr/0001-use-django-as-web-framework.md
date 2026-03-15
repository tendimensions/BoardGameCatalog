# ADR-0001: Use Django as Web Framework

**Date:** 2026-03-15

**Status:** Accepted

## Context

The Board Game Catalog project requires a web application framework for the backend. The application needs:
- User authentication and email verification
- Admin interface for data management
- RESTful API for mobile app integration
- Complex data relationships (8+ database tables)
- Security best practices (CSRF, XSS, SQL injection protection)
- Email sending capabilities (SMTP)
- 14-week development timeline
- Sole developer working on the project

Initial candidates considered:
- Django (Python)
- Flask (Python)
- Express (Node.js)

## Decision

We will use **Django 5.0+** as the web application framework.

## Rationale

### Django Advantages for This Project:

**1. Development Speed**
- Built-in user authentication system (handles REQ-UM-001 through REQ-UM-007)
- Built-in admin interface (immediate data management capability)
- Django ORM handles complex relationships elegantly
- Email backend built-in
- CSRF/XSS protection automatic
- As a sole developer with 14-week timeline, batteries-included approach is critical

**2. Security**
- Security best practices built-in and actively maintained
- Password hashing with bcrypt/Argon2 supported
- SQL injection prevention via ORM
- CSRF tokens automatic
- XSS protection in templates
- Meets all REQ-NFR-020 through REQ-NFR-025 requirements by default

**3. ORM and Database**
- Django ORM excellent for our 8+ table schema
- Automatic migration system
- Seamless SQLite → PostgreSQL migration (one setting change)
- Foreign key relationships well-supported
- Query optimization tools built-in

**4. API Development**
- Django REST Framework is industry standard
- Well-documented, mature, feature-rich
- Authentication/permissions built-in
- Serialization automatic
- Perfect fit for mobile app API needs

**5. Community and Ecosystem**
- Massive ecosystem and community
- Extensive documentation
- Packages available for everything
- Long-term support and stability

**6. Admin Interface**
- Free, powerful admin panel out of the box
- Can manage users, collections, API keys, party lists
- Enables analytics and reporting
- Critical for sole developer operations

### Why Not Flask:

- More setup required (SQLAlchemy, Flask-Login, Flask-Mail, Flask-WTF, etc.)
- No built-in admin interface
- More boilerplate code
- Security must be manually implemented
- Would add 1-2 weeks to Phase 1 timeline
- Better for projects needing maximum flexibility (not our case)

### Why Not Express (Node.js):

- Everything is manual (Passport.js, Nodemailer, bcrypt, Sequelize/TypeORM, helmet, csurf)
- No admin interface out of the box
- Team is Python-focused, not JavaScript-focused
- More security implementation work
- Would add significant time to development
- Better for JavaScript-first teams or real-time requirements (not our case)

## Consequences

### Positive:

- Faster Phase 1 development (estimated 1-2 weeks saved)
- Immediate admin interface for data management
- Security built-in, less room for error
- Simplified authentication and email workflows
- Strong foundation for 14-week timeline
- Python preference aligns with developer expertise
- Excellent Django documentation available

### Negative:

- More opinionated than Flask (less flexibility)
- Larger framework footprint than microframeworks
- Some Django patterns to learn (though well-documented)
- Might be "overkill" for very simple projects (but not this one)

### Neutral:

- Committed to Python ecosystem (already preferred)
- Will use Django patterns and conventions
- Database migration from SQLite to PostgreSQL trivial when needed

## Notes

- Django ORM will be used (built-in, no separate ORM decision needed)
- Django REST Framework will be added for mobile API endpoints
- Admin interface provides immediate analytics and data management capabilities
- Framework supports all functional and non-functional requirements in REQUIREMENTS-AND-DESIGN.md

## Related Decisions

- See ADR-0002 for frontend rendering approach
- Database: SQLite initially, PostgreSQL for production (Django supports both seamlessly)

## References

- Django Documentation: https://www.djangoproject.com/
- Django REST Framework: https://www.django-rest-framework.org/
- Project Requirements: REQUIREMENTS-AND-DESIGN.md Section 3 (Functional Requirements)
- Security Requirements: REQUIREMENTS-AND-DESIGN.md Section 4.3 (Security)
