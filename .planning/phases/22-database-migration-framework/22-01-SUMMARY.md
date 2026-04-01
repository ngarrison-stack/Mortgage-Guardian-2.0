---
phase: 22-database-migration-framework
plan: 01
subsystem: database
tags: [supabase, pg_dump, schema, migrations]

# Dependency graph
requires:
  - phase: 21-report-generation-integration-fixes
    provides: stable v4.0 codebase ready for production readiness work
provides:
  - Complete remote Supabase schema dump (auth + storage schemas)
  - Confirmation that public schema is empty (no application tables in remote DB)
  - Supabase CLI initialized and linked to project
affects: [22-02-migration-organization, 22-03-completeness-verification]

# Tech tracking
tech-stack:
  added: [supabase-cli]
  patterns: [supabase-db-dump, schema-capture]

key-files:
  created:
    - supabase/config.toml
    - supabase/schema_dump.sql
  modified: []

key-decisions:
  - "Public schema is empty — existing migration files (001-005) are authoritative schema source, not remote DB"
  - "Dumped auth + storage schemas for infrastructure baseline"

patterns-established:
  - "Schema dumps stored in supabase/ directory"

issues-created: []

# Metrics
duration: 8min
completed: 2026-04-01
---

# Phase 22, Plan 01: Supabase CLI Setup & Schema Capture Summary

**Supabase CLI linked and full remote schema dumped; public schema confirmed empty — migration files are authoritative source**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-01
- **Completed:** 2026-04-01
- **Tasks:** 2
- **Files created:** 2

## Accomplishments
- Supabase CLI v2.75.0 installed, initialized, and linked to project `huosfjdcnjzdzhkkjaqh`
- Full remote schema dump captured (3,807 lines) covering auth (23 tables) and storage (8 tables)
- Critical discovery: public schema is empty — all 8 known application tables do not exist in remote DB
- Existing migration files (001-005 in backend-express/migrations/) confirmed as authoritative schema source

## Task Commits

Each task was committed atomically:

1. **Task 1: Supabase CLI initialization** — checkpoint:human-verify (no commit, user verification)
2. **Task 2: Dump complete remote schema** — `7e9c22e` (feat)

## Files Created/Modified
- `supabase/config.toml` — Supabase CLI project configuration
- `supabase/schema_dump.sql` — Complete remote schema dump (auth + storage infrastructure)

## Decisions Made
- **Public schema empty:** The remote Supabase database has no application tables in the public schema. The 8 known tables (documents, case_files, plaid_items, plaid_accounts, plaid_transactions, notifications, pipeline_state, document_classifications) were not found. The existing SQL migration files in `backend-express/migrations/` are the authoritative schema source for Plan 22-02.
- **Included auth + storage schemas:** Even though the plan focused on application tables, capturing the Supabase infrastructure schemas provides a complete baseline for reproducibility.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Docker not running for pg_dump**
- **Found during:** Task 2 (schema dump)
- **Issue:** `supabase db dump` requires Docker (runs pg_dump in container); Docker wasn't running
- **Fix:** Prompted user to start Docker Desktop
- **Verification:** Dump succeeded after Docker started
- **Impact:** Minor delay

**2. [Rule 3 - Blocking] Default dump captured empty public schema**
- **Found during:** Task 2 (schema dump)
- **Issue:** Initial dump without explicit `--schema` flag returned only grants/extensions (63 lines)
- **Fix:** Re-ran with `--schema public,storage,auth` and `--keep-comments` flags to capture full infrastructure
- **Verification:** Second dump produced 3,807 lines with 31 tables, 46 indexes, 20+ functions

---

**Total deviations:** 2 auto-fixed (both blocking), 0 deferred
**Impact on plan:** Both fixes necessary to produce usable output. No scope creep.

## Issues Encountered
- Public schema completely empty — changes the approach for Plan 22-02 (will build baseline migration from existing SQL files rather than reorganizing a remote dump)

## Next Phase Readiness
- Schema dump captured and committed
- Plan 22-02 should use `backend-express/migrations/001-005` as primary schema source, not the dump
- The dump provides infrastructure context (auth, storage, extensions) for baseline completeness
- Supabase CLI is ready for `supabase db push` / `supabase db reset` in Plan 22-03

---
*Phase: 22-database-migration-framework*
*Completed: 2026-04-01*
