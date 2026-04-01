---
phase: 22-database-migration-framework
plan: 02
subsystem: database
tags: [supabase, migrations, rollback, schema]

# Dependency graph
requires:
  - phase: 22-database-migration-framework
    provides: Schema dump and CLI setup from plan 22-01
provides:
  - Baseline migration consolidating all 5 manual migrations + bootstrap tables
  - Rollback script in reverse dependency order
  - Archived old migrations with README
  - Migration workflow documentation
affects: [22-03-completeness-verification, 23-ci-cd-pipeline]

# Tech tracking
tech-stack:
  added: []
  patterns: [supabase-migrations, idempotent-ddl, do-block-guards]

key-files:
  created:
    - supabase/migrations/20260401092448_baseline.sql
    - supabase/rollback/baseline_down.sql
    - supabase/README.md
    - backend-express/migrations/_archived/README.md
  modified:
    - backend-express/migrations/ (5 files moved to _archived/)

key-decisions:
  - "Built baseline from migration files 001-005, not from empty remote dump"
  - "Included documents and users bootstrap tables (not in any migration file, found in QUICK-START docs)"
  - "Quoted reserved word 'limit' in plaid_accounts to prevent PostgreSQL syntax errors"
  - "Preserved original idempotency patterns: direct CREATE POLICY for baseline, DO $$ guards matching 004/005 style"

patterns-established:
  - "Baseline migrations in supabase/migrations/ with timestamp prefix"
  - "Rollback scripts in supabase/rollback/"
  - "Old migrations archived in backend-express/migrations/_archived/"

issues-created: []

# Metrics
duration: 5min
completed: 2026-04-01
---

# Phase 22, Plan 02: Migration Organization & Rollback Summary

**577-line baseline migration consolidating 10 tables from 5 manual migrations + bootstrap, with rollback and archived originals**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-01
- **Completed:** 2026-04-01
- **Tasks:** 3
- **Files created:** 4
- **Files moved:** 5

## Accomplishments
- Baseline migration (`20260401092448_baseline.sql`) consolidates all application schema: 10 tables, all indexes, RLS on 8 tables, all policies, storage bucket policies, triggers, and the `update_updated_at_column()` function
- Rollback script reverses everything in correct reverse dependency order
- Old manual migrations archived with explanatory README
- Developer workflow documentation covers fresh setup, new migrations, rollback, and conventions

## Task Commits

Each task was committed atomically:

1. **Task 1: Create baseline migration** — `28bc3da` (feat)
2. **Task 2: Create rollback and archive old migrations** — `bca2f8b` (refactor)
3. **Task 3: Migration workflow documentation** — `b9943e4` (docs)

## Files Created/Modified
- `supabase/migrations/20260401092448_baseline.sql` — Complete baseline migration (577 lines)
- `supabase/rollback/baseline_down.sql` — Full rollback in reverse dependency order
- `supabase/README.md` — Migration workflow documentation
- `backend-express/migrations/_archived/README.md` — Archive explanation
- `backend-express/migrations/_archived/001-005*.sql` — 5 archived migration files (git mv)

## Decisions Made
- **Bootstrap tables included:** The `documents` and `users` tables were not defined in the 5 migration files — they were documented in QUICK-START-NO-AWS.md as manual bootstrap steps. Included in baseline since migration 002 adds columns to `documents` and 004 creates RLS policies on it.
- **Reserved word quoting:** `plaid_accounts.limit` is a PostgreSQL reserved word — quoted as `"limit"` in baseline to prevent syntax errors.
- **Idempotency patterns preserved:** Plaid policies use direct CREATE (safe for fresh baseline), while document/case/pipeline/storage policies use `DO $$ ... END $$` guards matching the original 004/005 style.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added documents and users bootstrap tables**
- **Found during:** Task 1 (baseline migration creation)
- **Issue:** Plan assumed all tables were in migration files 001-005, but `documents` and `users` tables were only in QUICK-START docs as manual steps
- **Fix:** Included both tables in baseline migration since other migrations depend on them
- **Verification:** Baseline contains all 10 tables in correct dependency order

**2. [Rule 1 - Auto-fix Bug] Quoted reserved word 'limit'**
- **Found during:** Task 1 (baseline migration creation)
- **Issue:** `plaid_accounts` table has column named `limit` — a PostgreSQL reserved word
- **Fix:** Quoted as `"limit"` to prevent syntax errors
- **Verification:** Valid SQL syntax

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 bug fix), 0 deferred
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered
None.

## Next Phase Readiness
- Baseline migration ready for verification in Plan 22-03
- `supabase db reset` can test fresh schema creation
- Cross-reference with service code needed to confirm completeness

---
*Phase: 22-database-migration-framework*
*Completed: 2026-04-01*
