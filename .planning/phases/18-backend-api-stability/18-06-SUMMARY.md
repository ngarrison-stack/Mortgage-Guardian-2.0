---
phase: 18-backend-api-stability
plan: 06
subsystem: infra
tags: [express, vercel, serverless, env-validation, startup]

# Dependency graph
requires:
  - phase: 18-05
    provides: memory leak fixes and cleanup patterns
provides:
  - startup environment validation with fail-fast on missing config
  - correct Vercel serverless handler export
affects: [deployment, devops, vercel]

# Tech tracking
tech-stack:
  added: []
  patterns: [fail-fast env validation, require.main guard for dual-mode server]

key-files:
  created: []
  modified: [backend-express/server.js, backend-express/api/index.js]

key-decisions:
  - "Only SUPABASE_URL and SUPABASE_ANON_KEY are strictly required; API keys for external services are recommended warnings"
  - "Used require.main === module guard instead of VERCEL env check for cleaner dev/serverless dual-mode"

patterns-established:
  - "Fail-fast startup: validate required env vars before app.listen()"
  - "Serverless export: module.exports = app with require.main guard for listen()"

issues-created: []

# Metrics
duration: 2min
completed: 2026-03-18
---

# Phase 18 Plan 06: Startup Validation & Config Summary

**Fail-fast env var validation at startup and direct Express app export for Vercel serverless**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-18T08:33:06Z
- **Completed:** 2026-03-18T08:34:54Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Server validates SUPABASE_URL and SUPABASE_ANON_KEY at startup, failing fast with descriptive errors instead of cryptic runtime 500s
- Missing recommended keys (ANTHROPIC_API_KEY, PLAID_CLIENT_ID, PLAID_SECRET) generate warnings without blocking startup
- Vercel serverless handler now directly exports Express app via `module.exports = app`
- `app.listen()` guarded by `require.main === module` for correct dual-mode operation

## Task Commits

Each task was committed atomically:

1. **Task 1: Add startup environment variable validation** - `3365905` (fix)
2. **Task 2: Fix Vercel serverless handler export** - `7bd1472` (fix)

**Plan metadata:** (pending)

## Files Created/Modified
- `backend-express/server.js` - Added validateEnvironment() function, require.main guard on listen()
- `backend-express/api/index.js` - Simplified to direct module.exports = app

## Decisions Made
- Only Supabase keys are strictly required — external service API keys are recommended but not blocking, allowing health checks to work even without all keys configured
- Used `require.main === module` pattern instead of checking VERCEL env var — this is the idiomatic Node.js way to detect if a file is the entry point vs imported as a module

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] app.listen() guard change bundled into Task 1**
- **Found during:** Task 1 (environment validation)
- **Issue:** The require.main guard was tightly coupled with where validateEnvironment() is called — separating them across tasks would create an inconsistent intermediate state
- **Fix:** Applied require.main guard in same commit as validation function
- **Files modified:** backend-express/server.js
- **Verification:** Both dev startup and Vercel import work correctly
- **Committed in:** 3365905

---

**Total deviations:** 1 auto-fixed (blocking — structural coupling)
**Impact on plan:** Minor commit scope change. No scope creep.

## Issues Encountered
- Pre-existing npm test failure due to yargs/jest dependency incompatibility — unrelated to this plan's changes

## Next Phase Readiness
- Startup validation and Vercel handler are fixed
- Ready for 18-07: Request Tracing (request ID middleware, logger propagation)

---
*Phase: 18-backend-api-stability*
*Completed: 2026-03-18*
