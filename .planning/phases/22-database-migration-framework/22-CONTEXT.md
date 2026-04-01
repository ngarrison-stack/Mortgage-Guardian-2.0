# Phase 22: Database Migration Framework - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning

<vision>
## How This Should Work

The current Supabase database schema gets exported and codified into version-controlled migration files. The end result is two things working together: a baseline snapshot that can stand up the full database from zero, and a sequential migration system for evolving the schema going forward.

When a new developer (or a CI pipeline) needs to spin up the database, they run one command and get an identical copy of the production schema — no tribal knowledge, no manual steps, no "ask Nick how the database is set up."

Future schema changes go through numbered migration files with up/down support, so changes are trackable, reviewable, and reversible.

</vision>

<essential>
## What Must Be Nailed

- **Completeness** — Everything must be captured: tables, indexes, RLS policies, functions, triggers, constraints. Not just the table definitions — the full picture. Mortgage data is security-sensitive and the RLS policies and functions are load-bearing parts of the schema.
- **Reproducibility** — Running the migrations from scratch must produce an identical database every time. No gaps, no manual steps.
- **Up/down support** — Every migration must have a clean rollback path.

</essential>

<boundaries>
## What's Out of Scope

- **No schema redesign** — Capture the existing schema faithfully as-is. Any table restructuring, relationship changes, or optimization happens in a future phase.
- CI/CD integration is Phase 23's concern — this phase produces the migration files and runner, not the automation around them.

</boundaries>

<specifics>
## Specific Ideas

No specific tool preferences — open to whatever fits best (Supabase CLI migrations, plain SQL files, or a lightweight framework). The right tool will be determined during research/planning.

</specifics>

<notes>
## Additional Context

This is the first phase of v5.0 Production Readiness. The database has been running successfully through v2.0-v4.0 (94 plans shipped), so the schema is battle-tested — it just isn't codified. The existing Supabase setup works; this phase is about making it reproducible and maintainable.

Data seeding and test fixtures were not explicitly excluded — they may or may not be included depending on what makes sense during planning.

</notes>

---

*Phase: 22-database-migration-framework*
*Context gathered: 2026-04-01*
