# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for the Board Game Catalog project.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences. ADRs help document the "why" behind technical choices.

## ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-use-django-as-web-framework.md) | Use Django as Web Framework | Accepted | 2026-03-15 |
| [0002](0002-use-server-side-rendering-with-htmx.md) | Use Server-Side Rendering with HTMX | Accepted | 2026-03-15 |
| [0003](0003-external-api-integration-strategy.md) | External API Integration Strategy | Accepted | 2026-03-15 |
| [0004](0004-authentication-and-security-policies.md) | Authentication and Security Policies | Accepted | 2026-03-15 |

## ADR Statuses

- **Proposed** - Under consideration
- **Accepted** - Decision made and being implemented
- **Deprecated** - No longer applies but kept for history
- **Superseded** - Replaced by a newer ADR

## Creating a New ADR

1. Copy the template below into a new file: `docs/adr/NNNN-title-with-dashes.md`
2. Fill in all sections thoroughly
3. Submit for review (if working with a team)
4. Update this README index

## ADR Template

```markdown
# ADR-NNNN: [Title]

**Date:** YYYY-MM-DD

**Status:** [Proposed | Accepted | Deprecated | Superseded by ADR-XXXX]

## Context

What is the issue that we're seeing that is motivating this decision or change?

## Decision

What is the change that we're proposing and/or doing?

## Rationale

Why did we choose this option over alternatives?

## Consequences

### Positive:
- What becomes easier?

### Negative:
- What becomes harder?

### Neutral:
- Trade-offs accepted?

## Alternatives Considered

What other options were evaluated and why were they rejected?

## Notes

Any additional context, links, or information.

## Related Decisions

Links to related ADRs or issues.

## References

- Links to documentation
- Links to requirement sections
- External resources
```

## Guidelines

- **Be concise but thorough** - Focus on the decision, not the implementation
- **Capture context** - Future you (or others) should understand why this decision was made
- **Document alternatives** - What else was considered and why it was rejected?
- **Include consequences** - Both positive and negative impacts
- **Link to requirements** - Reference specific requirement sections when applicable
- **Date decisions** - Track when the decision was made
- **Don't edit old ADRs** - If a decision changes, create a new ADR that supersedes
- **Use markdown formatting** - Code blocks, tables, and diagrams help clarity

## Further Reading

- [Michael Nygard's ADR article](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [GitHub ADR organization](https://adr.github.io/)
- [ADR Tools](https://github.com/npryce/adr-tools)
