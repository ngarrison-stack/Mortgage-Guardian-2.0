---
phase: 32-express-api-client-migration
plan: 03
subsystem: api
tags: [swift, ios, migration, refactoring, express]

# Dependency graph
requires:
  - phase: 32-express-api-client-migration
    provides: APIClient with typed Express endpoint methods (32-01, 32-02)
provides:
  - All service consumers migrated to APIClient
  - Zero AWSBackendClient usage outside AWSBackendClient.swift
affects: [32-04]

# Tech tracking
tech-stack:
  added: []
  patterns: [OCR-first-then-API pattern for Claude analysis]

key-files:
  created: []
  modified: [MortgageGuardian/Services/DocumentManager.swift, MortgageGuardian/Services/DocumentAnalysisService.swift, MortgageGuardian/Services/EnhancedPlaidService.swift, MortgageGuardian/Services/DocumentAnalysisError.swift]

key-decisions:
  - "DocumentAnalysisService sends OCR text to Express (not raw image data) — iOS does OCR locally via Vision"
  - "Removed duplicate DocumentListResponse from DocumentManager (now in APIClient+Documents.swift)"
  - "EnhancedPlaidService uses apiClient.post/get calls that are still placeholder methods — will need proper typed methods in future"

patterns-established:
  - "OCR-first pattern: iOS Vision OCR → text → Express Claude analysis"

issues-created: []

# Metrics
duration: 6min
completed: 2026-04-07
---

# Phase 32-03: Consumer Migration Summary

**Migrated DocumentManager, DocumentAnalysisService, EnhancedPlaidService, and error handling from AWSBackendClient to APIClient**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-07
- **Completed:** 2026-04-07
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- DocumentManager: replaced manual multipart upload with APIClient.uploadDocument(), fetchDocuments() uses typed method
- DocumentAnalysisService: replaced AWSBackendClient with APIClient.shared, Claude analysis sends OCR text (not image) to Express
- EnhancedPlaidService: switched from AWSBackendClient.shared to APIClient.shared
- DocumentAnalysisError: error mapping updated from AWSBackendClient.BackendError to APIError
- All hardcoded AWS Lambda URLs replaced with APIConfiguration.baseURL
- Removed duplicate DocumentListResponse from DocumentManager

## Task Commits

Each task was committed atomically:

1. **Task 1: DocumentManager & DocumentAnalysisService** - `0320fbd` (feat)
2. **Task 2: EnhancedPlaidService & error handling** - `68daaa2` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `MortgageGuardian/Services/DocumentManager.swift` - APIClient upload/fetch, removed multipart/auth boilerplate
- `MortgageGuardian/Services/DocumentAnalysisService.swift` - APIClient for Claude/documents, Vision OCR text extraction
- `MortgageGuardian/Services/EnhancedPlaidService.swift` - APIClient.shared reference swap
- `MortgageGuardian/Services/DocumentAnalysisError.swift` - APIError mapping

## Decisions Made
- DocumentAnalysisService now sends OCR-extracted text to Express (not raw image data) — iOS does local OCR first
- Kept EnhancedPlaidService's untyped post/get calls (aspirational endpoints not yet on Express)

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## Next Phase Readiness
- AWSBackendClient.swift only referenced by itself and CloudMigrationTestNotes.swift
- Ready for Plan 32-04: delete AWSBackendClient, purge AWS refs, verify Xcode build

---
*Phase: 32-express-api-client-migration*
*Completed: 2026-04-07*
