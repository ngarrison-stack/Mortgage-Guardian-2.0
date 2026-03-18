---
phase: 20-pipeline-accuracy
plan: 01
subsystem: api
tags: [ocr, pdf-parse, claude-vision, text-quality, confidence-scoring]

# Dependency graph
requires:
  - phase: 10-document-intake-classification
    provides: OCR service with two-strategy approach (pdf-parse + Claude Vision)
provides:
  - Quality-aware OCR text extraction with dynamic confidence scoring
  - _assessTextQuality() heuristic method for text quality evaluation
  - qualityMetrics object in extraction results
affects: [12-individual-document-analysis, 20-02-classification-confidence]

# Tech tracking
tech-stack:
  added: []
  patterns: [quality-based confidence scoring, extraction quality heuristics]

key-files:
  created: []
  modified:
    - backend-express/services/ocrService.js
    - backend-express/__tests__/services/ocrService.test.js

key-decisions:
  - "Raised MEANINGFUL_TEXT_THRESHOLD from 50 to 200 characters to prevent scanned PDFs with minimal metadata from being misclassified as text-based"
  - "Quality score formula uses four heuristics: wordCount, avgWordLength, alphaRatio, lineCount with weighted penalties"
  - "pdf-parse base confidence 0.90, Vision base confidence 0.80, both multiplied by qualityScore"
  - "Low-quality threshold set at 0.4 — below this, pdf-parse results fall through to Vision"

patterns-established:
  - "Quality-based confidence: never hardcode confidence values, derive from extraction quality metrics"

issues-created: []

# Metrics
duration: 7min
completed: 2026-03-18
---

# Phase 20 Plan 01: OCR Text Extraction Fixes Summary

**Quality-aware OCR extraction with dynamic confidence scoring replacing hardcoded 0.95/0.85 values and 4x threshold increase (50→200 chars)**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-18T10:48:53Z
- **Completed:** 2026-03-18T10:55:46Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Raised MEANINGFUL_TEXT_THRESHOLD from 50 to 200 characters, preventing scanned PDFs with minimal embedded metadata from being treated as text-based
- Added `_assessTextQuality()` heuristic method evaluating wordCount, avgWordLength, alphaRatio, and lineCount with a composite qualityScore
- Replaced hardcoded confidence values (0.95/0.85) with dynamic scoring: base × qualityScore
- Low-quality pdf-parse results (qualityScore < 0.4) now automatically fall through to Claude Vision
- qualityMetrics included in all extraction result objects for downstream consumption

## Task Commits

Each task was committed atomically:

1. **Task 1: Raise text threshold and add extraction quality heuristics** - `f47fde4` (feat)
2. **Task 2: Replace hardcoded confidence with dynamic quality-based scoring** - `efce3f8` (test)

## Files Created/Modified
- `backend-express/services/ocrService.js` - Added _assessTextQuality(), raised threshold, dynamic confidence, qualityMetrics in results
- `backend-express/__tests__/services/ocrService.test.js` - Updated fixture text, added 8 new tests for quality scoring and dynamic confidence

## Decisions Made
- Used multiplicative confidence formula (base × qualityScore) rather than additive — ensures bad extractions get proportionally low confidence
- Set quality threshold at 0.4 for Vision fallback — balances catching truly bad extractions without over-triggering Vision API calls
- pdf-parse gets higher base (0.90) than Vision (0.80) because it reads embedded text directly vs. interpreting images

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- node_modules were corrupted (yargs/semver build artifacts missing) — resolved with clean `rm -rf node_modules && npm install`

## Next Phase Readiness
- Quality-aware OCR extraction is complete, ready for 20-02 (Classification Confidence Gating)
- qualityMetrics in extraction results can be consumed by classification pipeline

---
*Phase: 20-pipeline-accuracy*
*Completed: 2026-03-18*
