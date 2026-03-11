---
phase: 16-consolidated-findings-reporting
plan: 03
subsystem: api
tags: [jest, tdd, confidence-scoring, evidence-linking, risk-level]

# Dependency graph
requires:
  - phase: 16-consolidated-findings-reporting
    plan: 01
    provides: consolidatedReportConfig with SCORING_WEIGHTS, LAYER_SCORING_FACTORS, RISK_THRESHOLDS, EVIDENCE_CATEGORIES
  - phase: 16-consolidated-findings-reporting
    plan: 02
    provides: reportAggregationService with normalized aggregated data shapes
provides:
  - confidenceScoringService.js with calculateConfidence(), documentAnalysisScore(), forensicAnalysisScore(), complianceAnalysisScore(), determineRiskLevel(), buildEvidenceLinks()
affects: [16-04-recommendations, 16-05-report-assembly]

# Tech tracking
tech-stack:
  added: []
  patterns: [singleton-scoring-service, config-driven-weights, weight-redistribution-for-missing-layers, floor-drag-penalty]

key-files:
  created:
    - backend-express/services/confidenceScoringService.js
    - backend-express/__tests__/services/confidenceScoringService.test.js
  modified: []

key-decisions:
  - "Per-layer scores start at 100 and subtract severity-weighted penalties (severity multiplier * base penalty per unit)"
  - "Missing layers (null forensic or compliance) get null scores; weights redistribute proportionally to available layers"
  - "Empty case (no docs, no forensic, no compliance) returns overall 100 — no evidence of problems = clean"
  - "Floor-drag penalty: if any forensic sub-factor (discrepancy/timeline/payment) bottoms out at 0, overall forensic score capped at 45"
  - "Payment issues in evidence links assigned medium severity (consistent with reportAggregationService convention)"
  - "Evidence description templates populated from EVIDENCE_CATEGORIES config with {id}, {statuteName}, {jurisdiction} placeholders"

patterns-established:
  - "Weight redistribution: available layer weights normalized to sum to 1.0 when some layers are null"
  - "Floor-drag: prevents high clean sub-factors from masking a catastrophic failure in one sub-factor"
  - "Evidence link builder iterates all 6 finding types from aggregated data and creates schema-compliant link objects"

issues-created: []

# Metrics
duration: 5min
completed: 2026-03-11
---

# Phase 16 Plan 3: Confidence Scoring & Evidence Linking Summary

**TDD-built confidence scoring engine with per-layer scoring, weight redistribution, risk level mapping, and evidence linking across all finding types**

## Performance

- **Duration:** 5 min
- **Tasks:** 1 TDD feature (RED -> GREEN, no refactor needed)
- **Files created:** 2

## Accomplishments
- calculateConfidence() produces weighted overall score with per-layer breakdown, redistributing weights when layers are missing
- documentAnalysisScore() scores based on completeness (40% weight) and severity-weighted anomaly penalties (60% weight)
- forensicAnalysisScore() scores across 3 sub-factors (discrepancies 50%, timeline 30%, payment 20%) with floor-drag for bottomed-out components
- complianceAnalysisScore() applies severity multiplier (critical=4x, high=3x, medium=2x, low=1x) to violation penalties
- determineRiskLevel() maps scores to critical/high/medium/low/clean using RISK_THRESHOLDS config
- buildEvidenceLinks() creates evidence link objects for all 6 finding types with source document cross-references
- 36 passing tests covering clean, degraded, mixed, missing layer, edge cases, and all evidence link types

## Task Commits

Each task was committed atomically:

1. **RED: Failing tests** - `c3992ef` (test)
2. **GREEN: Implementation** - `3f9f506` (feat)

_No refactor phase needed -- implementation is clean and follows established patterns._

## Files Created/Modified
- `backend-express/services/confidenceScoringService.js` - Singleton scoring service with 6 public methods
- `backend-express/__tests__/services/confidenceScoringService.test.js` - 36 tests across all methods

## Decisions Made
- Per-layer scores use a "start at 100, subtract penalties" model for intuitive scoring
- Forensic floor-drag (cap at 45 when any sub-factor hits 0) prevents clean sub-factors from masking catastrophic failures
- Compliance scoring uses violationPenalty weight (0.7) for violation impact, with remaining 0.3 as baseline confidence
- Evidence links use config-driven description templates with placeholder replacement

## Deviations from Plan

None -- plan executed exactly as written.

## Issues Encountered
None

## Next Phase Readiness
- Confidence scoring service ready for recommendation generator (16-04) to use risk levels and evidence links
- calculateConfidence output matches confidenceScoreSchema in consolidatedReportSchema
- buildEvidenceLinks output matches evidenceLinkSchema in consolidatedReportSchema
- determineRiskLevel output matches OVERALL_RISK_LEVELS enum

---
*Phase: 16-consolidated-findings-reporting*
*Completed: 2026-03-11*
