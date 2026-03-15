# ADR-0004: Authentication and Security Policies

**Date:** 2026-03-15

**Status:** Accepted

## Context

The Board Game Catalog requires user authentication for managing game collections, wishlists, and personal data. We need to establish security policies that balance user protection with usability, particularly around password requirements and credential management.

Key considerations:
- Application stores personal game collection data
- Users need secure access to their accounts
- Friction in registration/login reduces adoption
- Django provides robust built-in authentication and security
- Application is not handling financial data or highly sensitive PII

## Decision

### Password Requirements

**Minimum Length:** 8 characters

**Complexity Requirements:** None

**Rationale:**
- Prioritize user experience and lower barriers to entry
- 8-character minimum provides baseline security
- No complexity requirements reduces user frustration
- Django's built-in password hashers (PBKDF2, bcrypt, Argon2) provide strong encryption regardless of complexity
- Rate limiting on login attempts mitigates brute force attacks
- Data sensitivity level doesn't warrant strict complexity rules
- Can add complexity requirements later if security needs evolve

### Django Authentication Framework

**Implementation:**
- Use Django's built-in `django.contrib.auth` system
- Leverage Django's password validation framework
- Default to PBKDF2 password hasher (Django default)
- Consider upgrading to Argon2 for production (more secure, requires `argon2-cffi` package)

**Session Management:**
- Use Django's session framework with database-backed sessions
- Default session timeout: 2 weeks (Django default)
- "Remember me" option: Optional extension to 30 days

**Password Reset:**
- Email-based password reset using Django's built-in views
- Time-limited, single-use reset tokens
- Tokens expire after 3 days (Django default)

### Other Security Policies

**HTTPS:**
- Require HTTPS in production
- Set `SECURE_SSL_REDIRECT = True`
- Set `SESSION_COOKIE_SECURE = True`
- Set `CSRF_COOKIE_SECURE = True`

**CSRF Protection:**
- Use Django's built-in CSRF middleware (enabled by default)
- CSRF tokens on all POST/PUT/PATCH/DELETE requests

**Rate Limiting:**
- Implement rate limiting on login attempts (e.g., django-ratelimit or django-axes)
- Consider: 5 failed attempts → 15-minute lockout
- Rate limit password reset requests to prevent abuse

**Security Headers:**
- Enable Django's SecurityMiddleware
- Set appropriate CSP (Content Security Policy) headers
- Configure X-Content-Type-Options, X-Frame-Options, etc.

## Consequences

### Positive

- **Lower friction:** Users can create accounts quickly without password frustration
- **Good baseline security:** 8-character minimum + strong hashing provides reasonable protection
- **Django batteries included:** Leverages mature, well-tested authentication framework
- **Future flexibility:** Can add complexity requirements later if needed
- **Focus on app features:** Authentication security is "good enough" without over-engineering

### Negative

- **Potential for weak passwords:** Users might choose simple 8-character passwords
- **Partial mitigation:** Django's `CommonPasswordValidator` prevents most common passwords (e.g., "password", "12345678")
- **Mitigated by:** Strong hashing, rate limiting, HTTPS

### Future Considerations

- **Two-factor authentication (2FA):** Could add for highly security-conscious users
- **Social auth:** OAuth with Google, Facebook, BoardGameGeek
- **Password complexity:** Can add if user accounts are compromised
- **Password strength meter:** Visual feedback during registration
- **Argon2 hashing:** Upgrade from PBKDF2 for stronger protection

## References

- Django Authentication System: https://docs.djangoproject.com/en/5.0/topics/auth/
- Django Password Validation: https://docs.djangoproject.com/en/5.0/topics/auth/passwords/
- OWASP Password Guidelines: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- NIST Password Guidelines (SP 800-63B): https://pages.nist.gov/800-63-3/sp800-63b.html
