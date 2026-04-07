---
phase: 32-express-api-client-migration
plan: 01
subsystem: api
tags: [swift, ios, urlsession, networking, retry, observable]

# Dependency graph
requires:
  - phase: v5.0 milestone
    provides: production-ready Express backend with /v1/ API routes
provides:
  - APIConfiguration.swift with environment-aware backend URL
  - Consolidated APIClient.swift with retry logic, @Observable, expanded errors
affects: [32-02, 32-03, 32-04, 33]

# Tech tracking
tech-stack:
  added: []
  patterns: [APIEnvironment enum for URL config, exponential backoff with jitter]

key-files:
  created: [MortgageGuardian/Services/APIConfiguration.swift]
  modified: [MortgageGuardian/Services/APIClient.swift]

key-decisions:
  - "APIEnvironment uses Swift enum with #if DEBUG — no Info.plist or env vars"
  - "Retry config uses let constants instead of nested struct (simpler with @Observable)"
  - "URLSession initialized in init() — lazy not compatible with @Observable macro"

patterns-established:
  - "APIConfiguration.baseURL: single source for backend URL across all networking"
  - "APIClient retry pattern: exponential backoff with 0.8-1.2 jitter, max 3 retries"

issues-created: []

# Metrics
duration: 5min
completed: 2026-04-07
---

# Phase 32-01: Backend URL Configuration & APIClient Consolidation Summary

**Environment-aware APIConfiguration with consolidated APIClient absorbing AWSBackendClient retry logic, @Observable, and expanded error handling**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-07
- **Completed:** 2026-04-07
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created APIConfiguration.swift with development/staging/production environments and #if DEBUG auto-detection
- Rewrote APIClient.swift replacing hardcoded AWS Lambda URL with APIConfiguration.baseURL
- Absorbed retry logic from AWSBackendClient (exponential backoff, jitter, retryable 429/5xx codes)
- Added @Observable macro, expanded APIError enum, OSLog logging, isAuthenticated property
- Maintained backward-compatible public API (request(), setAuthToken(), baseURL, shared singleton)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create APIConfiguration** - `a1a2fdf` (feat)
2. **Task 2: Rewrite APIClient** - `d6d7cda` (feat)
3. **Fix: @Observable lazy var** - `fbd8e0b` (fix)

**Plan metadata:** (this commit)

## Files Created/Modified
- `MortgageGuardian/Services/APIConfiguration.swift` - Environment enum with baseURL, build-config detection
- `MortgageGuardian/Services/APIClient.swift` - Consolidated networking layer with retry, auth, logging

## Decisions Made
- Used Swift enum with #if DEBUG for environment detection — simpler than Info.plist for iOS
- Replaced lazy URLSession with init()-based initialization due to @Observable macro constraint
- Kept retry config as simple let properties rather than nested RetryConfig struct

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Auto-fix Bug] @Observable incompatible with lazy var**
- **Found during:** Task 2 (APIClient rewrite)
- **Issue:** @Observable macro transforms stored properties; lazy is a computed property and isn't supported
- **Fix:** Moved URLSession initialization into init() with let binding
- **Files modified:** MortgageGuardian/Services/APIClient.swift
- **Verification:** Compiler diagnostic resolved
- **Committed in:** `fbd8e0b`

---

**Total deviations:** 1 auto-fixed (1 bug fix), 0 deferred
**Impact on plan:** Minimal — standard Swift macro constraint, no scope change.

## Issues Encountered
None beyond the lazy var fix.

## Next Phase Readiness
- APIConfiguration provides the URL source for all networking
- APIClient is ready for typed endpoint methods in Plan 32-02
- AWSBackendClient still exists — will be deleted in Plan 32-04 after all consumers migrate

---
*Phase: 32-express-api-client-migration*
*Completed: 2026-04-07*
