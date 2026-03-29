---
phase: 21-report-generation-integration-fixes
plan: 01
subsystem: api
tags: [joi, schema-validation, confidence-scoring, aggregation, classification]

# Dependency graph
requires:
  - phase: 16-consolidated-findings-reporting
    provides: Joi schema for consolidated reports, confidence scoring service
  - phase: 20-pipeline-accuracy
    provides: classificationConfidence field on document analysis reports
provides:
  - Schema accepts null forensic/compliance breakdown scores
  - classificationImpact field accepted in confidence score schema
  - classificationConfidence flows from document analyses through aggregation
affects: [21-report-generation-integration-fixes, consolidated-report-pipeline]

# Tech tracking
tech-stack:
  added: []
  patterns: [null-tolerant Joi schemas with .allow(null).required()]

key-files:
  created: []
  modified:
    - backend-express/schemas/consolidatedReportSchema.js
    - backend-express/services/reportAggregationService.js
    - backend-express/__tests__/services/reportAggregationService.test.js

key-decisions:
  - "Used .allow(null).required() pattern — field must be present but may be null"
  - "classificationConfidence averaged only across documents that have it (not all documents)"
  - "classificationConfidence excluded from return object when undefined (backward compatible)"

patterns-established:
  - "Null-tolerant schema: .allow(null).required() for optional analysis layers"

issues-created: []

# Metrics
duration: 6min
completed: 2026-03-29
---

# Phase 21 Plan 01: Confidence Score Schema & Classification Pipeline Summary

**Joi schema now accepts null forensic/compliance breakdown scores and classificationImpact; aggregation service wires classificationConfidence from document analyses into scoring pipeline**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-29
- **Completed:** 2026-03-29
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Schema validation no longer rejects reports with missing forensic or compliance analysis layers
- classificationImpact field (from Phase 20-05) now passes schema validation
- classificationConfidence propagates from individual document analyses through aggregation into scoring

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix confidenceBreakdownSchema to allow null for missing layers** - `5bdbefd` (fix)
2. **Task 2: Wire classificationConfidence from aggregation service into scoring pipeline** - `f07e944` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified
- `backend-express/schemas/consolidatedReportSchema.js` - Allow null for forensic/compliance breakdown, add classificationImpact schema
- `backend-express/services/reportAggregationService.js` - Extract and average classificationConfidence from document analyses
- `backend-express/__tests__/services/reportAggregationService.test.js` - 6 new tests for schema validation and classificationConfidence wiring

## Decisions Made
- Used Joi `.allow(null).required()` pattern: the field must always be present in the object, but null is a valid value when that analysis layer wasn't run
- classificationConfidence is averaged only across documents that have the field, not all documents — prevents dilution when some documents predate the classification pipeline
- Result field is omitted entirely (not set to undefined/null) when no documents have it, maintaining backward compatibility

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] uuid ESM import fails under Jest CommonJS transform**
- **Found during:** Task 1 (schema validation tests)
- **Issue:** `require('uuid')` fails because uuid v10 is ESM-only
- **Fix:** Used `crypto.randomUUID()` instead (Node.js built-in)
- **Files modified:** backend-express/__tests__/services/reportAggregationService.test.js
- **Verification:** All tests pass
- **Committed in:** 5bdbefd (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking), 0 deferred
**Impact on plan:** Trivial — different UUID generation method, same result.

## Issues Encountered
None

## Next Phase Readiness
- Schema now validates all confidence score shapes the pipeline produces
- classificationConfidence flows end-to-end when available
- Ready for 21-02 (Dispute Letter Schema & Field Alignment)

---
*Phase: 21-report-generation-integration-fixes*
*Completed: 2026-03-29*
