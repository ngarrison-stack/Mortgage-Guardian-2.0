---
phase: 33-authentication-flow-completion
plan: 02
subsystem: auth
tags: [clerk-ios-sdk, jwt-refresh, session-persistence, swift, swiftui]

# Dependency graph
requires:
  - phase: 33-authentication-flow-completion
    plan: 01
    provides: Express backend accepts Clerk JWTs via JWKS verification
  - phase: 32-express-api-client-migration
    provides: APIClient.swift with setAuthToken() and performRequest()
provides:
  - AuthManager with full token lifecycle (refresh, persist, re-auth)
  - 401 automatic re-authentication via APIClient callback
  - App launch flow: splash → session check → login or main
affects: [33-03 LoginView Polish, 34 Document Upload Pipeline]

# Tech tracking
tech-stack:
  added: []
  patterns: [periodic-token-refresh, 401-callback-re-auth, three-state-app-launch]

key-files:
  modified:
    - MortgageGuardian/Services/AuthManager.swift
    - MortgageGuardian/Services/APIClient.swift
    - MortgageGuardian/MortgageGuardianApp.swift

key-decisions:
  - "4-minute refresh interval (under Clerk's 5-min JWT expiry)"
  - "No Keychain storage — Clerk SDK handles session persistence internally"
  - "401 callback on APIClient rather than retry logic — keeps APIClient simple"
  - "Removed setupCrashProtection() — referenced undefined plaidLinkService"

patterns-established:
  - "Token refresh: single refreshToken() method as source of truth for fresh JWTs"
  - "401 re-auth: APIClient.onAuthenticationRequired callback → AuthManager.handleAuthenticationRequired()"
  - "App launch: isLoading → session restore → isSignedIn routing"

issues-created: []

# Metrics
duration: 35min
completed: 2026-04-07
---

# Phase 33-02: iOS Token Lifecycle & Session Persistence Summary

**AuthManager with 4-min periodic token refresh, Clerk session restore on launch, and automatic 401 re-authentication via APIClient callback**

## Performance

- **Duration:** 35 min
- **Started:** 2026-04-07
- **Completed:** 2026-04-07
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- AuthManager restores Clerk session on app launch via `Clerk.shared.user` check
- Periodic token refresh every 4 minutes (under 5-min Clerk JWT expiry)
- 401 responses trigger automatic re-auth attempt before failing
- App entry point shows loading → auth → main three-state flow
- Clean sign-out cancels refresh task, clears API token, resets state

## Task Commits

Each task was committed atomically:

1. **Task 1: Add token lifecycle and session persistence to AuthManager** - `68b941a` (feat)
2. **Task 2: Wire 401 handling and loading state into app entry point** - `71ee871` (feat)

## Files Created/Modified
- `MortgageGuardian/Services/AuthManager.swift` - Full token lifecycle: isLoading, refreshToken(), periodic refresh, handleAuthenticationRequired(), clean signOut
- `MortgageGuardian/Services/APIClient.swift` - Added onAuthenticationRequired callback, called on 401 before throwing
- `MortgageGuardian/MortgageGuardianApp.swift` - Three-state view (loading/auth/main), wired 401 callback, removed setupCrashProtection()

## Decisions Made
- 4-minute refresh interval chosen to stay under Clerk's 5-minute JWT expiry default
- No Keychain storage added — Clerk SDK handles session persistence internally
- 401 uses callback pattern (not retry) to keep APIClient simple and let AuthManager own auth decisions
- Removed `setupCrashProtection()` which referenced undefined `plaidLinkService`

## Deviations from Plan
None - plan executed exactly as written

## Issues Encountered
None

## Next Phase Readiness
- Auth flow complete: launch → session restore → refresh → re-auth on 401
- Ready for 33-03 LoginView Polish & Build Verification
- All downstream API consumers benefit from automatic token refresh without code changes

---
*Phase: 33-authentication-flow-completion*
*Completed: 2026-04-07*
