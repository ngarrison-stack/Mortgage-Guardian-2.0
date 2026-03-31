---
phase: 21-report-generation-integration-fixes
plan: 02
subsystem: api
tags: [joi, schema-validation, dispute-letter, respa, field-alignment]

# Dependency graph
requires:
  - phase: 16-consolidated-findings-reporting
    provides: disputeLetterSchema, disputeLetterService, consolidated report service
provides:
  - disputeLetterSchema matches actual service output (structured content, servicer fields)
  - Letter service reads violations/findings from both raw and stored report formats
affects: [21-report-generation-integration-fixes, dispute-letter-pipeline]

# Tech tracking
tech-stack:
  added: []
  patterns: [coalesce field access for dual-shape input data]

key-files:
  created: []
  modified:
    - backend-express/schemas/consolidatedReportSchema.js
    - backend-express/services/disputeLetterService.js

key-decisions:
  - "Schema changed to match service output — not the other way around"
  - "Letter service uses coalesce pattern (stored field || raw field) rather than normalizing at call site"
  - "Stored report field names checked first (preferred canonical format)"

patterns-established:
  - "Dual-shape coalesce: report.complianceFindings || report.complianceReport for services receiving both formats"

issues-created: []

# Metrics
duration: 5min
completed: 2026-03-30
---

# Phase 21 Plan 02: Dispute Letter Schema & Field Alignment Summary

**disputeLetterSchema now validates structured content/recipientInfo; letter service reads violations and findings from both stored and raw report formats**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-30
- **Completed:** 2026-03-30
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- disputeLetterSchema content field changed from string to structured object (subject, body, demands, etc.)
- recipientInfo fields aligned to servicerName/servicerAddress matching actual service output
- _extractViolations reads from both complianceFindings and complianceReport
- _extractFindings reads from both documentAnalysis (singular) and documentAnalyses (plural)

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix disputeLetterSchema to match actual service output** - `5b1c106` (fix)
2. **Task 2: Fix dispute letter service to read from both raw and consolidated report formats** - `57cae2a` (fix)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified
- `backend-express/schemas/consolidatedReportSchema.js` - Restructured disputeLetterSchema content and recipientInfo fields
- `backend-express/services/disputeLetterService.js` - Coalesce field access in _extractViolations and _extractFindings

## Decisions Made
- Fixed schema to match service output, not vice versa — the service is the source of truth; the schema is the contract that describes it
- Used coalesce pattern (stored field name first, raw fallback) to keep letter service self-contained rather than requiring callers to normalize data shapes
- No new tests added per plan — Plan 21-04 covers end-to-end verification

## Deviations from Plan

None - plan executed exactly as written

## Issues Encountered
None

## Next Phase Readiness
- Dispute letter schema validates actual service output
- Letters from stored reports now contain all violations and findings
- Ready for 21-03 (Forensic & Compliance Report Normalization)

---
*Phase: 21-report-generation-integration-fixes*
*Completed: 2026-03-30*
