---
phase: 12-individual-document-analysis
plan: 01
subsystem: api
tags: [joi, schema, validation, document-analysis, completeness-scoring, mortgage-docs]

# Dependency graph
requires:
  - phase: 10-document-intake-classification
    provides: DOCUMENT_TAXONOMY with 6 categories/54 subtypes, classificationService, extractedMetadata format
provides:
  - analysisReportSchema — Joi validation for structured analysis output
  - DOCUMENT_FIELD_DEFINITIONS — field maps for all 54 document subtypes
  - validateAnalysisReport() helper function
  - getFieldDefinition(), getExpectedFieldCount(), categorizeField() helpers
affects: [12-02 document analysis service, 12-03 pipeline integration, 13 cross-document analysis, 16 consolidated reporting]

# Tech tracking
tech-stack:
  added: []
  patterns: [schema-first design for AI output validation, tiered field definitions (critical/expected/optional)]

key-files:
  created:
    - backend-express/schemas/analysisReportSchema.js
    - backend-express/config/documentFieldDefinitions.js
  modified: []

key-decisions:
  - "Schema-first design: define analysis output contract before building analysis service"
  - "Flexible Joi.object().pattern() for extractedData sub-objects — different document types produce different field names"
  - "Three-tier field classification (critical/expected/optional) drives completeness scoring severity"
  - "Generic fallback definition for unknown subtypes ensures graceful degradation"

patterns-established:
  - "Analysis report schema as contract between Claude AI and all downstream consumers"
  - "Document field definitions as config-driven completeness scoring (not hardcoded)"

issues-created: []

# Metrics
duration: 8 min
completed: 2026-02-27
---

# Phase 12 Plan 01: Analysis Report Schema & Document Field Definitions Summary

**Joi validation schema for structured analysis reports and tiered field definitions for all 54 mortgage document subtypes enabling completeness scoring**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-27T15:24:36Z
- **Completed:** 2026-02-27T15:32:37Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Analysis report Joi schema with 5 validated sections: documentInfo, extractedData, anomalies, completeness, summary
- Flexible extractedData validation using Joi.object().pattern() supporting any field names across document types
- Anomaly tracking with enum validation (5 types, 5 severity levels) and optional regulation citations
- Document field definitions covering all 54 subtypes across 6 categories with critical/expected/optional tiers
- Helper functions for completeness scoring: getFieldDefinition, getExpectedFieldCount, categorizeField
- Generic fallback for unknown subtypes ensuring graceful degradation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create analysis report Joi validation schema** - `f1dfbf8` (feat)
2. **Task 2: Create document field definitions for completeness scoring** - `5697a32` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `backend-express/schemas/analysisReportSchema.js` - Joi schema defining the structured output format for document analysis reports with 5 sections and validation helpers
- `backend-express/config/documentFieldDefinitions.js` - Field definitions for all 54 document subtypes across 6 categories with helper functions for completeness scoring

## Decisions Made
- **Schema-first design:** Define the analysis output contract before building the analysis service — ensures Claude AI output is validated and consistent from day one
- **Flexible pattern matching:** Used `Joi.object().pattern(Joi.string(), flexibleValue)` for extractedData sub-objects — different document types will have different field names, so the schema validates structure without being rigid about field names
- **Three-tier field classification:** critical (missing = high-severity anomaly), expected (missing = medium-severity), optional (missing = info) — drives downstream completeness scoring
- **Generic fallback definition:** Unknown subtypes get basic field expectations rather than failing — ensures pipeline resilience

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness
- Analysis report schema ready for consumption by document analysis service (12-02)
- Field definitions ready for completeness scoring integration
- All 690 existing tests pass with zero regressions

---
*Phase: 12-individual-document-analysis*
*Completed: 2026-02-27*
