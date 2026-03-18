---
phase: 20-pipeline-accuracy
plan: 02
subsystem: classification
tags: [confidence-gating, classification, pipeline, prompt-engineering]

# Dependency graph
requires:
  - phase: 10-document-intake-classification
    provides: Classification service with 6-category/54-subtype taxonomy
  - phase: 12-individual-document-analysis
    provides: Pipeline passes classification results directly to analysis
provides:
  - confidenceLevel field (high/medium/low) on all classification results
  - classificationWarning flag for low-confidence documents
  - Non-conflicting user hint prompt handling
affects: [20-pipeline-accuracy, 21-report-generation]

# Tech tracking
tech-stack:
  added: []
  patterns: [confidence-gating threshold pattern, conditional prompt construction]

key-files:
  modified:
    - backend-express/services/classificationService.js
    - backend-express/services/documentPipelineService.js
    - backend-express/__tests__/services/classificationService.test.js

key-decisions:
  - "0.7/0.4 confidence thresholds: high > 0.7, medium 0.4-0.7, low < 0.4"
  - "Low confidence flags but does not block pipeline — downstream consumers see warning"
  - "User hint replaces 'classify independently' instead of conflicting with it"

patterns-established:
  - "Confidence gating: threshold constants at top of service, confidenceLevel in return object"
  - "Conditional prompt: hint-aware vs independent classification instructions"

issues-created: []

# Metrics
duration: 3min
completed: 2026-03-18
---

# Phase 20 Plan 02: Classification Confidence Gating Summary

**Added confidence-level gating (high/medium/low) to classification results and fixed conflicting user-hint prompt instructions**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-18T10:57:49Z
- **Completed:** 2026-03-18T11:01:13Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Classification results now include `confidenceLevel` field based on 0.7/0.4 thresholds
- Pipeline logs warnings and sets `classificationWarning` for low-confidence documents without blocking flow
- Fixed user-provided type hint prompt to remove conflicting "classify independently" instruction
- Added 8 new tests covering confidence levels, boundary values, and prompt variants

## Task Commits

Each task was committed atomically:

1. **Task 1: Add confidence threshold and low-confidence handling** - `d61b0df` (feat)
2. **Task 2: Fix user-provided type hint handling and add tests** - `a1b361f` (feat)

## Files Created/Modified
- `backend-express/services/classificationService.js` - Added CONFIDENCE_HIGH/LOW_THRESHOLD constants, confidenceLevel in _parseClassificationResponse, conditional hint prompt
- `backend-express/services/documentPipelineService.js` - Added low/medium confidence logging and classificationWarning field in _runClassification
- `backend-express/__tests__/services/classificationService.test.js` - 8 new tests for confidence levels and prompt variants, 4 updated for new prompt wording

## Decisions Made
- Thresholds set at 0.7 (high) and 0.4 (low) — these are tunable constants, not magic numbers
- Low confidence flags rather than blocks — avoids breaking pipeline flow while making uncertainty visible
- User hint wording tells Claude to "consider as starting point but override if content clearly indicates different type"

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## Next Phase Readiness
- Classification confidence gating in place for downstream consumption
- Ready for 20-03-PLAN.md (Compliance Rule Matching Precision)

---
*Phase: 20-pipeline-accuracy*
*Completed: 2026-03-18*
