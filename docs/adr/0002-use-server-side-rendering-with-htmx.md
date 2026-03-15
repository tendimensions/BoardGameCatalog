# ADR-0002: Use Server-Side Rendering with HTMX

**Date:** 2026-03-15

**Status:** Accepted

## Context

The Board Game Catalog web application needs a frontend approach. The project requirements include:
- User interface for collection management, authentication, party lists
- Dynamic interactions (BGG sync progress, barcode scan results)
- Mobile app already provides native "app-like" experience
- Sole developer with 14-week timeline
- Python/Django backend already chosen (see ADR-0001)

The fundamental decision: Server-Side Rendering (SSR) vs. Single Page Application (SPA)?

Initial candidates considered:
- Server-Side Rendering with Django Templates
- SPA with Django REST API + React
- SPA with Django REST API + Vue
- Hybrid approach

## Decision

We will use **Server-Side Rendering (SSR) with Django Templates**, enhanced with **HTMX** for dynamic interactions and **Alpine.js** for simple client-side interactivity.

## Rationale

### Server-Side Rendering Advantages:

**1. Development Velocity (Critical for Sole Developer)**
- Single codebase - Python everywhere
- No build tools, no webpack, no npm complexity
- Django forms handle validation on both client and server
- CSRF protection automatic
- Estimated 2-3x faster feature delivery vs SPA
- 14-week timeline strongly favors SSR

**2. Simplicity**
- One language to think in (Python)
- Straightforward debugging (server logs)
- No API versioning concerns for web UI
- No CORS configuration needed
- Deploy once, not web + API separately

**3. Requirements Analysis**
Analyzed all 92+ functional requirements - **none require SPA architecture:**
- User forms → Django forms (REQ-UM-001 through REQ-UM-007)
- Collection lists → Django templates + pagination (REQ-CM-001 through REQ-CM-007)
- Search/filter → Server-side with URL parameters (REQ-CM-004)
- BGG sync → Form POST, progress page (REQ-CM-010 through REQ-CM-016)
- Party lists → Standard CRUD operations (REQ-PL-001 through REQ-PL-018)
- Mobile app already provides native "app experience"

**4. Django Integration**
- Template system powerful (inheritance, includes, filters)
- Forms framework excellent for validation
- Admin interface works seamlessly with SSR
- Authentication just works
- No impedance mismatch

**5. Progressive Enhancement with HTMX**
- Add SPA-like feel without SPA complexity
- ~10KB JavaScript library (no build step)
- Update page fragments without full reload
- Perfect for: BGG sync progress, party list updates, barcode scan feedback
- Easy to learn, minimal JavaScript knowledge needed

**6. Future-Proof**
- Can add React/Vue later if truly needed (Phase 6+)
- API already built for mobile app (reusable)
- Not locked in, just starting pragmatically

### Why Not SPA (React/Vue):

**1. Development Time**
- Two codebases to maintain (Python + JavaScript)
- Build tools configuration and maintenance
- State management (Redux, Pinia)
- Frontend routing
- Authentication complexity (JWT tokens vs sessions)
- Forms validation duplicated (client + server)
- As sole developer with 14 weeks, this is prohibitive

**2. Complexity for No Benefit**
- CORS configuration
- API versioning for web frontend
- Error handling in two places
- Deployment more complex
- No requirement demands this complexity

**3. Admin Interface Duplication**
- Django admin would be separate from main app
- Would need to build admin features twice (in React/Vue)
- Or accept two different UIs

**4. Timeline Risk**
- **SSR Path:** Week 3 = working authentication + collections ✅
- **SPA Path:** Week 3 = maybe authentication + React setup ⚠️
- Unacceptable risk for 14-week project

### HTMX as the Middle Ground:

```html
<!-- Example: BGG sync without page reload -->
<button hx-post="/collection/sync-bgg" 
        hx-target="#sync-status"
        hx-swap="innerHTML">
    Sync from BoardGameGeek
</button>

<div id="sync-status">
    <!-- Server returns HTML fragment: -->
    <!-- "Syncing... 24/156 games" -->
</div>
```

**Benefits:**
- Server-side rendering base
- Dynamic updates where beneficial
- No build tools required
- Progressive enhancement
- Falls back gracefully
- Learn as you go

## Consequences

### Positive:

- Maximum development velocity for sole developer
- Single codebase reduces cognitive load
- Faster time to market (critical for 14-week timeline)
- Django's strengths fully utilized
- Admin interface works seamlessly
- Simple deployment (one application)
- Can add API endpoints incrementally for mobile
- HTMX provides modern UX without SPA complexity

### Negative:

- Initial page loads include full page refresh (mitigated by HTMX)
- Not as "snappy" as full SPA for first-time visitors
- Complex drag-and-drop UIs would be harder (but not in requirements)
- Some developers prefer React/Vue experience (not relevant for solo dev)

### Neutral:

- Still building REST API (for mobile app)
- Both templates and API endpoints in codebase
- But Django REST Framework makes this straightforward

### Trade-offs Accepted:

- **Sacrificing:** Bleeding-edge SPA "coolness factor"
- **Gaining:** Shipping complete features faster
- **Result:** Better product delivered on time

## Implementation Details

**Technology Stack:**
- Django Templates for all page rendering
- HTMX (via CDN or static files) for dynamic updates
- Alpine.js (optional) for simple client-side interactions (modals, dropdowns)
- Django forms for user input
- sample-style.css as base styling
- Minimal custom JavaScript

**Dynamic Features with HTMX:**
- BGG sync progress updates
- Party list updates
- Search/filter without page reload
- Barcode scan result feedback
- Form submissions with inline errors

**Static Features (full page load):**
- Initial page loads
- Navigation between major sections
- User authentication flows
- Admin interface

## Migration Path (If Needed)

If SPA becomes necessary in Phase 6+:
1. API already exists (from mobile app development)
2. Can migrate page-by-page (not all-or-nothing)
3. Start with most interactive pages
4. Keep admin in Django (no need to migrate)

Likelihood: Low. Requirements don't demand it.

## Notes

- Django admin stays as-is (server-rendered, works perfectly)
- Mobile app gets native experience (Flutter)
- Web app optimized for functionality and development speed
- Progressive enhancement philosophy: works without JavaScript, better with it
- sample-style.css provides dark theme base

## Related Decisions

- See ADR-0001 for Django framework choice
- API architecture for mobile app: Django REST Framework

## References

- HTMX Documentation: https://htmx.org/
- Alpine.js Documentation: https://alpinejs.dev/
- Django Templates: https://docs.djangoproject.com/en/5.0/topics/templates/
- Project Requirements: REQUIREMENTS-AND-DESIGN.md Section 3 (all requirements reviewed)
- Development Timeline: REQUIREMENTS-AND-DESIGN.md Section 12 (14-week roadmap)
