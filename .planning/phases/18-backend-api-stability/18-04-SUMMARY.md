---
phase: 18-backend-api-stability
plan: 04
subsystem: api
tags: [express, security, idor, http-status, joi, authorization]

# Dependency graph
requires:
  - phase: 18-02
    provides: CORS and webhook security patterns
provides:
  - IDOR-safe document routes using JWT auth context
  - Consistent 422 error status codes for analysis/compliance/report failures
affects: [frontend-api-integration, error-handling]

# Tech tracking
tech-stack:
  added: []
  patterns: [req.user.id-for-all-user-scoped-routes, 422-for-analysis-errors]

key-files:
  modified:
    - backend-express/routes/documents.js
    - backend-express/routes/cases.js
    - backend-express/routes/compliance.js
    - backend-express/routes/reports.js
    - backend-express/schemas/documents.js

key-decisions:
  - "Use 422 Unprocessable Entity for analysis/compliance/report failures (not 400 — input is valid, processing failed)"
  - "Remove userId from all Joi schemas — user identity always from JWT auth context"

patterns-established:
  - "All user-scoped routes MUST use req.user.id from JWT, never client-provided userId"
  - "Error responses use { error: 'ErrorType', message: '...' } format with appropriate 4xx status"

issues-created: []

# Metrics
duration: 10min
completed: 2026-03-17
---

# Phase 18 Plan 04: Document Route Security & Correctness Summary

**Closed IDOR vulnerability in 8 document routes by replacing client-provided userId with JWT auth context, and fixed error-as-200 responses across 4 route files to return proper 422 status codes**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-17T19:20:06Z
- **Completed:** 2026-03-17T19:29:49Z
- **Tasks:** 2
- **Files modified:** 13 (4 routes, 1 schema, 8 tests)

## Accomplishments
- Eliminated IDOR (Insecure Direct Object Reference) vulnerability in all document routes — userId now always comes from `req.user.id` (JWT auth middleware), never from `req.query` or `req.body`
- Fixed 5 error-as-200 patterns across `documents.js`, `cases.js`, `compliance.js`, and `reports.js` — all now return HTTP 422 with consistent `{ error, message }` format
- Updated Joi validation schemas to remove `userId` from client-provided fields
- Updated 8 test files (schema tests, route tests, integration tests, user-isolation tests) to reflect new security model

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix user ID isolation — use req.user.id** - `5a25ff4` (fix)
2. **Task 2: Fix error status codes — return proper 4xx** - `c8f30d0` (fix)

## Files Created/Modified
- `backend-express/routes/documents.js` - All 8 route handlers now use `req.user.id`
- `backend-express/routes/cases.js` - Forensic analysis error returns 422
- `backend-express/routes/compliance.js` - Compliance error returns 422
- `backend-express/routes/reports.js` - Report and letter generation errors return 422
- `backend-express/schemas/documents.js` - Removed `userId` from all 7 document schemas
- `backend-express/__tests__/validation/schemas.test.js` - Updated for schemas without userId
- `backend-express/__tests__/routes/documents-routes.test.js` - Uses mock JWT user ID
- `backend-express/__tests__/routes/documents-upload-security.test.js` - Removed userId from test bodies
- `backend-express/__tests__/integration/user-isolation.test.js` - Rewritten to verify JWT-based isolation
- `backend-express/__tests__/integration/document-analysis-pipeline.test.js` - Expects 422
- `backend-express/__tests__/complianceRoutes.test.js` - Expects 422
- `backend-express/__tests__/integration/consolidated-report.test.js` - Expects 422
- `backend-express/__tests__/integration/forensic-analysis.test.js` - Expects 422

## Decisions Made
- Used HTTP 422 (Unprocessable Entity) for analysis/report failures rather than 400 — the request format is valid, but the server can't process the content (e.g., document analysis failed, compliance evaluation errored). This follows RFC 4918 semantics.
- Chose to remove `userId` entirely from Joi schemas rather than making it optional — eliminates any possibility of the field being used, even accidentally.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Fixed error-as-200 in reports.js (not in original plan)**
- **Found during:** Task 2 (auditing error status codes)
- **Issue:** `reports.js` had 2 instances of error responses with HTTP 200 (report generation and letter generation)
- **Fix:** Changed both to return 422 with consistent error format
- **Files modified:** backend-express/routes/reports.js, backend-express/__tests__/integration/consolidated-report.test.js
- **Verification:** Tests updated and passing

---

**Total deviations:** 1 auto-fixed (1 missing critical in reports.js), 0 deferred
**Impact on plan:** Essential fix discovered during audit — same bug pattern in a file not originally listed. No scope creep.

## Issues Encountered
None

## Next Phase Readiness
- All document routes now use authenticated user identity — IDOR vulnerability fully closed
- Error responses use correct HTTP status codes — frontend/client code can properly detect errors via `res.ok` or `res.status`
- Ready for 18-05 (Memory Leak Prevention)

---
*Phase: 18-backend-api-stability*
*Completed: 2026-03-17*
