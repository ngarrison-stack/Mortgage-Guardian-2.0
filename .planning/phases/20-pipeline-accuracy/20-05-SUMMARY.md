---
phase: 20-pipeline-accuracy
plan: 05
subsystem: scoring, config
tags: [risk-thresholds, classification-confidence, confidence-scoring, pipeline-accuracy]

requires:
  - phase: 20-pipeline-accuracy/20-04
    provides: Calibrated severity penalty values, floor drag cap at 35
  - phase: 20-pipeline-accuracy/20-02
    provides: Classification confidence levels (high/medium/low)
provides:
  - Recalibrated risk thresholds aligned with penalty system (30/55/75/92/100)
  - Classification confidence wired into scoring pipeline
  - classificationImpact transparency field in scoring response
  - Backward compatible when classification confidence not provided
affects: [21-report-generation]

tech-stack:
  added: []
  patterns: [classificationConfidence scaling factor, classificationImpact response field, options parameter on calculateConfidence]

key-files:
  created: []
  modified:
    - backend-express/config/consolidatedReportConfig.js
    - backend-express/services/confidenceScoringService.js
    - backend-express/services/consolidatedReportService.js
    - backend-express/__tests__/services/confidenceScoringService.test.js

key-decisions:
  - "Risk thresholds widened to 30/55/75/92/100 to align with recalibrated penalty values"
  - "Classification confidence applies only to documentAnalysis layer since forensic/compliance layers don't depend on classification type"
  - "Confidence factor bands: >=0.7 → 1.0, 0.4-0.7 → 0.85, <0.4 → 0.65"

patterns-established:
  - "classificationImpact transparency field: all scoring responses include how classification confidence affected the score"
  - "Options parameter pattern on calculateConfidence for optional pipeline metadata"

issues-created: []

duration: 4min
completed: 2026-03-18
---

# Phase 20 Plan 5: Risk Threshold Recalibration & Classification Confidence Summary

**Recalibrated risk thresholds to 30/55/75/92/100 aligned with penalty system, and wired classification confidence into documentAnalysis scoring layer with transparency field**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-18T14:43:06Z
- **Completed:** 2026-03-18T14:46:52Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Risk thresholds recalibrated from 25/50/70/90 to 30/55/75/92 with documented rationale linking to penalty calibration
- Classification confidence wired into scoring — low-confidence classifications reduce documentAnalysis layer trustworthiness
- classificationImpact transparency field added to all scoring responses
- Backward compatible — scoring works unchanged when classification confidence not provided

## Task Commits

Each task was committed atomically:

1. **Task 1: Recalibrate risk thresholds** - `058c876` (feat)
2. **Task 2: Wire classification confidence into scoring pipeline** - `521f93a` (feat)

**Plan metadata:** `f3ebc26` (docs: complete plan)

## Files Created/Modified
- `backend-express/config/consolidatedReportConfig.js` — Threshold values updated to 30/55/75/92/100 with calibration rationale comment block
- `backend-express/services/confidenceScoringService.js` — calculateConfidence() accepts classificationConfidence option, applies scaling factor to documentAnalysis layer, returns classificationImpact field
- `backend-express/services/consolidatedReportService.js` — Passes classificationConfidence from aggregated data into scoring
- `backend-express/__tests__/services/confidenceScoringService.test.js` — Updated boundary tests + 9 new classification confidence tests

## Decisions Made
- Risk thresholds widened to 30/55/75/92/100 to align with recalibrated penalty values from 20-04
- Classification confidence factor applied only to documentAnalysis layer — forensic and compliance layers don't depend on classification type
- Confidence factor bands: >=0.7 → 1.0 (no penalty), 0.4-0.7 → 0.85 (15% reduction), <0.4 → 0.65 (35% reduction)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## Next Phase Readiness
- Phase 20 (Pipeline Accuracy) complete — all 5 plans finished
- All accuracy improvements integrated: OCR confidence, classification gating, compliance precision, scoring deduplication, threshold calibration, and classification→scoring pipeline
- Ready for Phase 21: Report Generation & Integration Fixes

---
*Phase: 20-pipeline-accuracy*
*Completed: 2026-03-18*
