---
phase: 18-backend-api-stability
plan: 05
subsystem: api
tags: [memory-leak, cleanup, pipeline, mock-data, safety-valve]

# Dependency graph
requires:
  - phase: 18-04
    provides: Stable document routes and error handling
provides:
  - Pipeline state Map auto-cleanup on terminal states
  - Mock data Maps with clearMockData() and size-based eviction
affects: [server-stability, monitoring]

# Tech tracking
tech-stack:
  added: []
  patterns: [terminal-state-cleanup, size-based-eviction, grace-period-delete]

key-files:
  modified:
    - backend-express/services/documentPipelineService.js
    - backend-express/services/caseFileService.js
    - backend-express/services/documentService.js

key-decisions:
  - "Use setTimeout with 5-minute grace period for pipeline cleanup — clients may still poll final status"
  - "Use Map insertion order for eviction (oldest first) — no need for timestamp tracking"
  - "Use timer.unref() so cleanup timers don't prevent Node.js process exit"

patterns-established:
  - "Terminal state transitions trigger scheduled cleanup of in-memory state"
  - "All in-memory Maps must have size-based safety valves to prevent unbounded growth"

issues-created: []

# Metrics
duration: 5min
completed: 2026-03-18
---

# Phase 18 Plan 05: Memory Leak Prevention Summary

**Added automatic cleanup for unbounded in-memory Maps in pipeline and mock services to prevent memory exhaustion on long-running server instances**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-18
- **Completed:** 2026-03-18
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Pipeline state Map entries are automatically cleaned up 5 minutes after reaching terminal states (complete/failed)
- Added `getMapSize()` method to DocumentPipelineService for monitoring
- Safety valve logs warning and evicts oldest 100 entries when pipeline Map exceeds 1000 entries
- Added `clearMockData()` to both CaseFileService and DocumentService for manual cleanup
- Safety valve on mock Maps evicts oldest 100 entries when size exceeds 500

## Task Commits

Each task was committed atomically:

1. **Task 1: Add pipeline state cleanup on terminal states** - `883d5e8` (fix)
2. **Task 2: Add cleanup for mock service Maps** - `16af604` (fix)

## Files Modified
- `backend-express/services/documentPipelineService.js` - Added `getMapSize()`, `_enforceMapSizeLimit()`, `_scheduleCleanup()`, cleanup on terminal states
- `backend-express/services/caseFileService.js` - Added `clearMockData()`, `_enforceMockSizeLimit()`, safety valve in mock create/add methods
- `backend-express/services/documentService.js` - Added `clearMockData()`, `_enforceMockSizeLimit()`, safety valve in mock upload method

## Decisions Made
- Used `setTimeout` with `timer.unref()` for cleanup timers so they don't prevent graceful Node.js shutdown
- Placed safety valve checks after Map insertion (not before) to ensure the triggering entry is always stored
- Did not add interval-based cleanup timers — terminal state transition is the natural cleanup trigger
- Did not add TTL-based expiry for mock data — simple size-based eviction is sufficient

## Deviations from Plan
None

## Issues Encountered
- Pre-existing `npm test` failure due to yargs/hideBin dependency issue in jest — not caused by these changes. Verified correctness via manual Node.js module loading and integration checks.

## Next Phase Readiness
- Memory leak vectors eliminated for all in-memory Maps
- Ready for 18-06

---
*Phase: 18-backend-api-stability*
*Completed: 2026-03-18*
