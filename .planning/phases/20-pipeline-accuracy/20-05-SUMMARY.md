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
---

# 20-05 Summary: Risk Threshold Recalibration & Classification Confidence

## Completed Tasks

### Task 1: Recalibrate risk thresholds (058c876)
- Updated RISK_THRESHOLDS: critical 25->30, high 50->55, medium 70->75, low 90->92
- Added calibration rationale comment block documenting penalty alignment
- Added boundary value tests for all new thresholds (30/31, 55/56, 75/76, 92/93)

### Task 2: Wire classification confidence into scoring pipeline (521f93a)
- Added optional `classificationConfidence` parameter to `calculateConfidence()`
- Classification confidence factor: >=0.7 -> 1.0, 0.4-0.7 -> 0.85, <0.4 -> 0.65
- Factor applied only to documentAnalysis layer (forensic/compliance unaffected)
- Added `classificationImpact` transparency field to scoring response
- Updated consolidatedReportService to pass classification confidence through
- Added 9 tests covering all confidence levels, boundaries, backward compatibility

## Files Modified
- `backend-express/config/consolidatedReportConfig.js` — threshold values and rationale
- `backend-express/services/confidenceScoringService.js` — classification confidence logic
- `backend-express/services/consolidatedReportService.js` — pass-through integration
- `backend-express/__tests__/services/confidenceScoringService.test.js` — threshold and confidence tests

## Test Results
- 1258 passed, 1 failed (pre-existing: documentPipeline-integration OCR method mismatch)
- 0 regressions from this plan

## Deviations
None.
