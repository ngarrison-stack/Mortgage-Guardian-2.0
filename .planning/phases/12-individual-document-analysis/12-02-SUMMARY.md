---
phase: 12-individual-document-analysis
plan: 02
subsystem: api
tags: [claude-ai, document-analysis, prompt-engineering, completeness-scoring, anomaly-detection, mortgage-docs]

# Dependency graph
requires:
  - phase: 12-individual-document-analysis
    plan: 01
    provides: analysisReportSchema, DOCUMENT_FIELD_DEFINITIONS, validateAnalysisReport(), getFieldDefinition(), getExpectedFieldCount(), categorizeField()
  - phase: 10-document-intake-classification
    provides: classificationService pattern (Claude API -> structured JSON -> validation -> return), DOCUMENT_TAXONOMY
provides:
  - documentAnalysisService.analyzeDocument() — main entry point for document analysis
  - Type-specific prompt builders for all 6 document categories (servicing, origination, correspondence, legal, financial, regulatory)
  - Completeness scoring using documentFieldDefinitions
  - Anomaly severity enrichment based on field criticality
  - Graceful error handling (API errors, JSON parse failures, validation warnings)
affects: [12-03 pipeline integration, 13 cross-document analysis, 16 consolidated reporting]

# Tech tracking
tech-stack:
  added: []
  patterns: [type-specific prompt routing, completeness scoring from field definitions, anomaly severity enrichment, graceful JSON parse fallback with rawResponse]

key-files:
  created:
    - backend-express/services/documentAnalysisService.js
    - backend-express/__tests__/services/documentAnalysisService.test.js
  modified: []

key-decisions:
  - "Type-specific prompt routing via switch on classificationType — each category gets domain-specific extraction instructions and anomaly checks"
  - "Extraction template dynamically built from documentFieldDefinitions — prompts are not hardcoded but reflect the 54-subtype field maps"
  - "Anomaly severity elevation: anomalies on critical fields automatically elevated to 'high' severity regardless of Claude's initial assessment"
  - "Graceful degradation at every level: API errors return error objects, JSON parse failures return rawResponse, validation failures attach warnings but don't reject"
  - "Generic prompt fallback for unknown document types using GENERIC_FIELD_DEFINITION"

patterns-established:
  - "Document analysis service as pure analysis layer — no persistence, no encryption, no auth"
  - "Type-specific prompt engineering with shared extraction template"
  - "Completeness scoring as post-processing enrichment using field definitions config"

issues-created: []

# Metrics
duration: 12 min
completed: 2026-02-28
---

# Phase 12 Plan 02: Document Analysis Service Summary

**Type-specific Claude AI analysis service with forensic prompt engineering, completeness scoring, and anomaly severity enrichment for all 6 mortgage document categories**

## Performance

- **Duration:** 12 min
- **Tasks:** 2
- **Files created:** 2
- **Tests added:** 37
- **Total test suite:** 727 tests, 26 suites, 0 failures

## Accomplishments

- Document analysis service (`documentAnalysisService.js`) with `analyzeDocument()` entry point following established classificationService patterns
- Type-specific prompt builders for all 6 document categories: servicing, origination, correspondence, legal, financial, regulatory
- Subtype-specific anomaly detection instructions (e.g., payment math for monthly_statement, APR calculation for closing_disclosure, RESPA timing for foreclosure_notice)
- Dynamic extraction template built from documentFieldDefinitions — prompts reflect the actual field maps for each of the 54 subtypes
- Completeness scoring that calculates field coverage against critical+expected fields, identifying missing critical fields separately
- Anomaly severity enrichment: anomalies on critical fields automatically elevated to 'high' severity
- Graceful error handling at every level: API errors, JSON parse failures (with markdown code fence extraction), partial responses, and schema validation warnings
- Generic prompt fallback for unknown/unrecognized document types
- 37 comprehensive unit tests covering all prompt types, completeness scoring, anomaly handling, error cases, and configuration

## Task Commits

Each task was committed atomically:

1. **Task 1: Create document analysis service** - `59070ca` (feat)
2. **Task 2: Create document analysis service unit tests** - `45a7cce` (test)

## Files Created/Modified

- `backend-express/services/documentAnalysisService.js` — 803-line service with analyzeDocument(), 7 type-specific prompt builders, completeness scoring, anomaly categorization, and graceful error handling
- `backend-express/__tests__/services/documentAnalysisService.test.js` — 768-line test file with 37 tests across 9 describe blocks

## Decisions Made

- **Dynamic extraction templates from field definitions:** Rather than hardcoding field lists in prompts, the `_buildExtractionTemplate()` method reads from `documentFieldDefinitions.js` and classifies fields into likely categories (dates, amounts, rates, parties, identifiers) using regex pattern matching on field names. This ensures prompts stay in sync with field definition changes.
- **Anomaly severity elevation policy:** Any anomaly on a critical field with severity 'low', 'info', or 'medium' gets elevated to 'high'. This ensures critical field issues are never downplayed by Claude's initial assessment.
- **Markdown code fence extraction:** Added fallback JSON extraction from markdown code fences (`\`\`\`json ... \`\`\``) since Claude occasionally wraps JSON responses in markdown despite instructions.
- **Schema validation as warnings, not rejections:** When the enriched report fails Joi validation, warnings are attached to the result (`validationWarnings` array) but the report is still returned. This prevents the analysis pipeline from failing on minor schema deviations.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness

- Document analysis service ready for pipeline integration (12-03)
- Service follows same pattern as classificationService — can be called from documentPipelineService
- Output conforms to analysisReportSchema validated in 12-01
- All 727 existing tests pass with zero regressions

---
*Phase: 12-individual-document-analysis*
*Completed: 2026-02-28*
