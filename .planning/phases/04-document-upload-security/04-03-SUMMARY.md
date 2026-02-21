---
phase: 04-document-upload-security
plan: 03
subsystem: security
tags: [malware-scanning, deferred, stub, defense-in-depth, serverless]

# Dependency graph
requires:
  - phase: 04-document-upload-security/01
    provides: fileValidation utility (validateFileContent, sanitizeFileName)
  - phase: 04-document-upload-security/02
    provides: Upload route with validation pipeline and size limits
provides:
  - scanFileContent() stub exported for future malware scanning integration
  - Documented deferral decision with compensating controls and revisit criteria
affects: [05-core-service-tests, 06-document-processing-tests]

# Tech tracking
tech-stack:
  added: []
  patterns: [stub-for-future-integration, documented-deferral-decision]

key-files:
  created: []
  modified:
    - backend-express/utils/fileValidation.js

key-decisions:
  - "Malware scanning deferred: serverless (Vercel/Railway) incompatible with ClamAV, VirusTotal async gap and rate limits not justified at current scale"
  - "scanFileContent() exported as stub so future integration is drop-in replacement"
  - "5 compensating controls documented inline (auth, Joi, magic numbers, sanitization, size limits)"

patterns-established:
  - "Stub pattern: export function with correct signature now, implement later without breaking callers"

issues-created: []

# Metrics
duration: 23 min (includes user decision time)
completed: 2026-02-21
---

# Phase 4 Plan 03: Malware Scanning Decision Summary

**Malware scanning deferred with documented rationale, 5 compensating controls cataloged, and scanFileContent() stub exported as drop-in interface for future integration**

## Performance

- **Duration:** 23 min (includes decision checkpoint wait time)
- **Started:** 2026-02-21T22:28:46Z
- **Completed:** 2026-02-21T22:52:02Z
- **Tasks:** 2 (1 decision checkpoint + 1 implementation)
- **Files modified:** 1

## Accomplishments
- Evaluated 3 malware scanning options (VirusTotal, ClamAV, defer) against serverless deployment constraints
- Selected "defer" — strongest ROI given current 5-layer security stack and serverless architecture
- Added scanFileContent() stub with comprehensive JSDoc documenting: decision rationale, compensating controls, and revisit criteria
- Stub exported alongside existing utilities — future scanning integration requires zero changes to calling code
- All 150 existing tests pass after changes

## Task Commits

Each task was committed atomically:

1. **Task 1: Decision checkpoint** - No commit (decision only, documented in this summary)
2. **Task 2: Implement defer approach with stub** - `919c2d3` (feat)

**Plan metadata:** (next commit) (docs: complete plan)

## Files Created/Modified
- `backend-express/utils/fileValidation.js` - Added scanFileContent() stub (44 lines) with documented deferral rationale, compensating controls catalog, and revisit criteria; exported in module.exports

## Decisions Made
- **Malware scanning deferred** — ClamAV incompatible with serverless deployment; VirusTotal async scanning creates gap where files exist unscanned, and free tier rate limits (4 req/min, 500/day) could block legitimate uploads; current 5-layer security stack provides adequate protection for mortgage document uploads at current scale
- **Stub pattern chosen** — scanFileContent(buffer) returns { scanned: false, reason: string } so future integration swaps the function body without touching any caller
- **Revisit triggers documented** — containerized deployment, high-risk document types, or volume growth justifying VirusTotal paid tier

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness
- scanFileContent stub exported and ready for drop-in replacement
- All 150 tests passing
- Ready for 04-04-PLAN.md (file upload security tests)

---
*Phase: 04-document-upload-security*
*Completed: 2026-02-21*
