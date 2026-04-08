---
phase: 33-authentication-flow-completion
plan: 01
subsystem: auth
tags: [clerk, jwks-rsa, jwt, express-middleware, dual-provider]

# Dependency graph
requires:
  - phase: 32-express-api-client-migration
    provides: Express backend APIClient used by iOS app
provides:
  - Dual-provider auth middleware (Clerk JWKS + Supabase fallback)
  - CLERK_ISSUER_URL env var configuration
  - 26 auth middleware tests covering both providers
affects: [33-02 iOS Token Lifecycle, 33-03 LoginView Polish]

# Tech tracking
tech-stack:
  added: [jwks-rsa]
  patterns: [dual-provider JWT verification, JWKS key caching, provider-tagged req.user]

key-files:
  created:
    - backend-express/__mocks__/jwks-rsa.js
  modified:
    - backend-express/middleware/auth.js
    - backend-express/__tests__/middleware/auth.test.js
    - backend-express/.env.example

key-decisions:
  - "Used jwks-rsa (not jsonwebtoken) for Clerk JWKS verification with automatic key caching"
  - "Clerk verification tried first, Supabase fallback second — optimizes for mobile-first traffic"
  - "Added provider field to req.user ('clerk' or 'supabase') for downstream provider-aware logic"
  - "Created __mocks__/jwks-rsa.js auto-mock to prevent ESM/jose import failures across 54 test suites"

patterns-established:
  - "Dual-provider auth: try Clerk JWKS → fall back to Supabase → 401 if both fail"
  - "Provider tagging: req.user.provider identifies auth source for logging/routing"

issues-created: []

# Metrics
duration: 7min
completed: 2026-04-07
---

# Phase 33-01: Clerk JWT Verification in Express Middleware Summary

**Dual-provider auth middleware accepting Clerk JWKS-verified iOS tokens with Supabase fallback, plus 26 tests covering both paths**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-07
- **Completed:** 2026-04-07
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Auth middleware verifies Clerk RS256 JWTs via JWKS endpoint with automatic key caching
- Supabase token validation preserved as fallback for web frontend
- 26 auth middleware tests (up from 15) covering Clerk acceptance, Supabase fallback, expiry, wrong issuer, JWKS unavailability, and combined failure
- Global `__mocks__/jwks-rsa.js` prevents ESM import failures across entire test suite

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Clerk JWT verification to auth middleware** - `43347f5` (feat)
2. **Task 2: Add dual-provider auth middleware tests** - `abbd61e` (test)

## Files Created/Modified
- `backend-express/middleware/auth.js` - Dual-provider auth: Clerk JWKS first, Supabase fallback
- `backend-express/package.json` - Added jwks-rsa dependency
- `backend-express/package-lock.json` - Lock file updated
- `backend-express/.env.example` - Added CLERK_ISSUER_URL with comments
- `backend-express/__mocks__/jwks-rsa.js` - Global Jest mock preventing ESM/jose import errors
- `backend-express/__tests__/middleware/auth.test.js` - 26 tests for dual-provider auth flow

## Decisions Made
- Used `jwks-rsa` with `cache: true, rateLimit: true` for automatic JWKS key caching and rotation
- Clerk verification tried first (optimizes for mobile-first traffic pattern)
- Added `provider` field to `req.user` object for downstream provider-aware logic
- Used Node.js `crypto` module directly for test JWT creation (simpler than jsonwebtoken for test-only RS256 signing)
- Created `__mocks__/jwks-rsa.js` auto-mock to prevent ESM/jose import failures across all 54 test suites

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added __mocks__/jwks-rsa.js global mock**
- **Found during:** Task 1 (auth middleware implementation)
- **Issue:** `jwks-rsa` depends on `jose` which uses ESM exports, causing 11 test suites to fail when loading server.js → auth.js → jwks-rsa
- **Fix:** Created `__mocks__/jwks-rsa.js` auto-mock so Jest intercepts the import globally
- **Files modified:** backend-express/__mocks__/jwks-rsa.js
- **Verification:** All 54 test suites pass
- **Committed in:** 43347f5 (Task 1 commit)

**2. [Rule 1 - Auto-fix] Updated error message in existing test**
- **Found during:** Task 1 (auth middleware implementation)
- **Issue:** Supabase exception case now returns "Invalid or expired token" instead of "Token validation failed" due to restructured try-catch
- **Fix:** Updated existing test expectation to match new error message
- **Verification:** All existing tests pass
- **Committed in:** 43347f5 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug fix), 0 deferred
**Impact on plan:** Both auto-fixes necessary for correctness. No scope creep.

## Issues Encountered
None

## Next Phase Readiness
- Express backend now accepts Clerk iOS JWTs — ready for 33-02 iOS Token Lifecycle
- `req.user.provider` field available for any provider-specific downstream logic
- 1609 tests passing, zero regressions

---
*Phase: 33-authentication-flow-completion*
*Completed: 2026-04-07*
