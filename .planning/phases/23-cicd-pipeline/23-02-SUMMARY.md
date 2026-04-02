---
phase: 23-cicd-pipeline
plan: 02
subsystem: infra
tags: [github-actions, nextjs, ci, clerk, eslint]

# Dependency graph
requires:
  - phase: 23-cicd-pipeline/01
    provides: GitHub Actions workflow pattern, concurrency config approach
provides:
  - Frontend CI workflow with lint + build on push/PR to main
  - Clerk placeholder key pattern for CI builds
affects: [23-cicd-pipeline/03, 24-test-coverage-hardening]

# Tech tracking
tech-stack:
  added: []
  patterns: [ci-placeholder-env-vars, clerk-format-valid-key-for-ci]

key-files:
  created: [.github/workflows/frontend-ci.yml]
  modified: []

key-decisions:
  - "Used format-valid synthetic Clerk key (pk_test_Y2kt...) instead of simple placeholder — Clerk validates key format at build time"
  - "Added NEXT_PUBLIC_API_URL and NEXT_PUBLIC_APP_URL placeholders — next.config.ts references these in rewrites"

patterns-established:
  - "CI placeholder env vars: use format-valid values that pass SDK validation but aren't real credentials"

issues-created: []

# Metrics
duration: 3min
completed: 2026-04-02
---

# Phase 23, Plan 02: Frontend CI Workflow Summary

**GitHub Actions frontend-ci.yml with Next.js build + ESLint lint, using format-valid Clerk placeholder key for CI**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-02
- **Completed:** 2026-04-02
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Created frontend-ci.yml workflow triggered on push/PR to main
- Validated lint (zero warnings) and build (7/7 static pages) locally
- Discovered Clerk key format validation requirement and solved with synthetic key

## Task Commits

Each task was committed atomically:

1. **Task 1: Create frontend CI workflow** - `115ee1f` (feat)
2. **Task 2: Validate frontend CI locally** - `3659f5f` (fix)

**Plan metadata:** (pending)

## Files Created/Modified
- `.github/workflows/frontend-ci.yml` - Frontend CI workflow with lint + build, Clerk/API placeholder env vars

## Decisions Made
- Used `pk_test_Y2ktcGxhY2Vob2xkZXItMDAuY2xlcmsuYWNjb3VudHMuZGV2JA==` as Clerk publishable key placeholder — Clerk validates key format during Next.js static page generation, so a simple string like "pk_test_placeholder" fails the build
- Added `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_APP_URL` env vars — `next.config.ts` references `NEXT_PUBLIC_API_URL` in rewrites, and `.env.example` lists both

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Clerk key format validation at build time**
- **Found during:** Task 2 (local validation)
- **Issue:** `pk_test_placeholder` fails — Clerk SDK validates publishable key format during `next build` static generation
- **Fix:** Changed to format-valid synthetic key encoding `ci-placeholder-00.clerk.accounts.dev$`
- **Files modified:** `.github/workflows/frontend-ci.yml`
- **Verification:** `npm run build` succeeds with 7/7 static pages
- **Committed in:** `3659f5f`

**2. [Rule 3 - Blocking] Missing NEXT_PUBLIC_ env vars for build**
- **Found during:** Task 2 (local validation)
- **Issue:** `next.config.ts` references `NEXT_PUBLIC_API_URL` in rewrites; build needs it present
- **Fix:** Added `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_APP_URL` placeholder values
- **Files modified:** `.github/workflows/frontend-ci.yml`
- **Verification:** Build succeeds with all env vars present
- **Committed in:** `3659f5f`

---

**Total deviations:** 2 auto-fixed (both blocking), 0 deferred
**Impact on plan:** Both auto-fixes necessary for CI build to pass. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## Next Phase Readiness
- Frontend CI workflow ready for GitHub
- Plan 23-03 (PR Quality Gates & iOS Cleanup) can proceed — both backend and frontend CI workflows are in place

---
*Phase: 23-cicd-pipeline*
*Completed: 2026-04-02*
