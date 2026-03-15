# ADR-0003: External API Integration Strategy

**Date:** 2026-03-15

**Status:** Accepted

## Context

The Board Game Catalog integrates with two critical external APIs:
1. **BoardGameGeek.com (BGG) XML API** - For game metadata and user collection sync
2. **GameUPC.com API** - For UPC/barcode to game mapping

Both APIs are community-run resources with specific characteristics that require careful integration strategy. Research was conducted to understand rate limits, authentication, costs, and usage patterns.

## Decision

We will integrate with both external APIs using the following strategies:

### BoardGameGeek.com API Integration

**Approach:** Polite, rate-limited synchronization with retry logic

**Key Implementation:**
- **2-second minimum delay** between all BGG API requests
- **HTTP 202 handling:** Implement retry logic with exponential backoff (2-5 seconds between retries)
- **Caching strategy:** 
  - Cache BGG responses for 24 hours minimum
  - Only re-sync when user explicitly requests OR >24 hours elapsed
  - BGG caches collections for 7 days (or until user modifies)
- **Progress feedback:** Show users "Your collection has XXX games. This may take 30-60 seconds..."
- **Request throttling:** Prevent multiple simultaneous sync requests from same user
- **No authentication required:** BGG username is a public identifier used to query the API; no password, OAuth, or API key needed for read-only collection access

**Authentication:** None (username-only lookup)

**Cost:** Free

### GameUPC.com API Integration

**Approach:** Direct API integration with community contribution model

**Key Implementation:**
- **No authentication required** - Completely open REST API
- **No rate limiting needed** - API has no documented limits
- **Free to use** - Zero cost
- **Bidirectional data flow:**
  - **Inbound:** Query GameUPC for UPC → BGG mappings
  - **Outbound:** Submit user-verified UPC mappings back to GameUPC
- **User experience:**
  - Verified barcodes (confidence 96+): Instant add
  - Unverified: Show 2-5 options for user selection
  - Missing: Fallback to manual BGG search
- **Community contribution:**
  - Users link barcodes via web app
  - App submits mappings to GameUPC: `POST /upc/{upc}/bgg_id/{bgg_id}`
  - Include anonymous user_id in submissions
  - Informational banner explains crowdsourced nature

**Authentication:** None required

**Cost:** Free

## Rationale

### BGG Rate Limiting Approach

**Why 2-second delays:**
- BGG is community-run with limited resources
- No published rate limits, but community best practice is to be polite
- Prevents overwhelming BGG servers
- Demonstrates good API citizenship
- 2-second delay is imperceptible to users for typical use cases

**Why HTTP 202 retry logic:**
- BGG queues large collection exports (100+ games can take 30-60 seconds)
- HTTP 202 "Accepted" signals request is queued
- Must poll until HTTP 200 received
- Exponential backoff prevents hammering BGG during queue processing
- User gets cached result on subsequent requests (fast)

**Why aggressive caching:**
- Reduces load on BGG servers
- BGG already caches for 7 days
- 24-hour local cache is reasonable for relatively static collection data
- User can manually trigger sync if needed

**Why no authentication required:**
- BGG API supports public username-based lookups for read-only operations
- Username is a public identifier, not a credential
- No password, OAuth, or API key needed
- Simpler implementation (no credential management)
- Zero security risk (no secrets to store)
- Sufficient for MVP requirements

### GameUPC Community Contribution Model

**Why bidirectional integration:**
- GameUPC has only ~42% verified coverage (9,615 / 22,996)
- Our users will encounter missing/unverified barcodes
- Contributing back improves database for all users
- Aligns with open-source/community ethos
- Small effort for significant community benefit

**Why no authentication:**
- GameUPC is designed as open crowdsource platform
- No costs or API keys to manage
- Simplified deployment
- Lower barrier to contribution

**Why web app contribution (not just mobile):**
- Users can verify/correct mappings after initial scan
- Desktop UX better for searching and selecting from options
- Mobile scans → Web app verifies → GameUPC benefits
- Reduces friction in contribution flow

## Consequences

### Positive:

**BGG Integration:**
- Minimal load on BGG infrastructure (good citizen)
- Fast user experience after first sync (caching)
- Simple authentication model
- No API costs
- Resilient to BGG queue delays

**GameUPC Integration:**
- Zero cost for UPC lookups
- No API key management
- Improves crowdsource database over time
- Users feel they're contributing to community
- Simple integration (no auth)

### Negative:

**BGG Integration:**
- First sync can take 30-60 seconds for large collections (mitigated by progress feedback)
- 2-second delays add latency if making multiple requests (rare in our use case)
- Cached data may be 24 hours stale (acceptable for collections)
- No bidirectional sync capability (BGG limitation, not our choice)

**GameUPC Integration:**
- Only 42% of UPCs verified - users will need to help verify
- Requires user education about crowdsource model
- Additional UI for barcode linking
- Depends on external free service (could change terms)

### Neutral:

**Both APIs:**
- Free to use (no revenue but also no costs)
- Community-run services (less reliability guarantee than commercial APIs)
- No SLA/support contracts

## Alternatives Considered

### BGG Integration Alternatives

**Alternative 1: No rate limiting**
- **Rejected:** Irresponsible API usage, could harm BGG service
- Could lead to IP blocking or community backlash
- Not aligned with open-source ethos

**Alternative 2: More aggressive polling (sub-second)**
- **Rejected:** Hammers BGG servers during queue processing
- No benefit (BGG queue time doesn't change)
- Could cause performance issues for BGG

**Alternative 3: OAuth/password authentication**
- **Rejected:** Unnecessarily complex for read-only access
- Stores sensitive credentials
- BGG supports username-only for collections
- Can revisit if bidirectional sync becomes available

**Alternative 4: No caching**
- **Rejected:** Wasteful of BGG resources
- Slower user experience (wait for BGG every time)
- BGG already caches for 7 days anyway

### GameUPC Alternatives

**Alternative 1: Read-only (no contribution back)**
- **Rejected:** Doesn't help improve database
- Misses opportunity for community contribution
- Selfish use of community resource

**Alternative 2: Different UPC database**
- **Evaluated:** Few board game-specific UPC databases exist
- GameUPC is focused on board games → BGG
- Free and open
- Alternative databases not board-game specific

**Alternative 3: Build our own UPC database**
- **Rejected:** Massive effort to duplicate existing work
- Fragments community data
- Would still need bootstrapping from somewhere
- Better to contribute to existing solution

## Implementation Notes

### BGG API Handler (Python/Django)

```python
import time
from datetime import datetime, timedelta

class BGGAPIClient:
    RATE_LIMIT_DELAY = 2  # seconds
    MAX_RETRIES = 10
    RETRY_DELAY = 2  # seconds (exponential backoff)
    CACHE_DURATION = timedelta(hours=24)
    
    def fetch_collection(self, username):
        # Check cache first
        cached = self.get_cached_collection(username)
        if cached and not self.is_cache_expired(cached):
            return cached
            
        # Rate limit: wait since last request
        self.enforce_rate_limit()
        
        # Make request with retry logic
        for attempt in range(self.MAX_RETRIES):
            response = requests.get(url)
            
            if response.status_code == 200:
                # Success - cache and return
                self.cache_collection(username, response.data)
                return response.data
                
            elif response.status_code == 202:
                # Queued - wait and retry
                delay = min(self.RETRY_DELAY * (1.5 ** attempt), 30)
                time.sleep(delay)
                continue
                
            else:
                raise BGGAPIError(response.status_code)
                
        raise BGGAPIError("Max retries exceeded")
```

### GameUPC Contribution Handler

```python
class GameUPCClient:
    def submit_barcode_mapping(self, upc, bgg_id, user_id_hash):
        """Submit user-verified UPC mapping to GameUPC"""
        url = f"https://api.gameupc.com/upc/{upc}/bgg_id/{bgg_id}"
        payload = {"user_id": user_id_hash}
        
        response = requests.post(url, json=payload)
        return response.ok
```

## Related Decisions

- See ADR-0001 for Django framework selection (includes caching strategy)
- See ADR-0002 for SSR approach (affects how progress feedback is shown)
- See Section 7.4.4 (API Specifications) for detailed endpoint documentation
- See Section 14.2 and 14.3 for remaining open questions about these APIs

## References

- BoardGameGeek XML API2: https://boardgamegeek.com/wiki/page/BGG_XML_API2
- BGG API Community Thread: https://boardgamegeek.com/thread/1188687 (HTTP 202 behavior)
- GameUPC API Documentation: https://www.gameupc.com/
- GameUPC REST API: https://api.gameupc.com/
- Requirements: Section 3.2.2 (BGG Sync), Section 3.2.3-3.2.4 (Barcode/GameUPC)
- Requirements: REQ-CM-030 through REQ-CM-038 (Community Contribution)
- Non-Functional Requirements: REQ-NFR-003, REQ-NFR-026, REQ-NFR-032
