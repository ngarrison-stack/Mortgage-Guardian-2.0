---
phase: 13-cross-document-forensic-analysis
plan: 01
subsystem: api
tags: [joi, schema, forensic-analysis, cross-document, comparison-engine, discrepancy-detection]

# Dependency graph
requires:
  - phase: 12-individual-document-analysis
    provides: analysisReportSchema.js patterns, documentFieldDefinitions.js, documentTaxonomy.js
provides:
  - crossDocumentAnalysisSchema with Joi validation for forensic analysis reports
  - COMPARISON_PAIRS configuration for 9 document type relationships
  - DISCREPANCY_SEVERITY_RULES with field-based elevation logic
  - getComparisonPairsForDocTypes() bidirectional matching helper
  - validateCrossDocumentAnalysis() validation helper
affects: [13-02 data aggregation, 13-03 Claude comparison service, 13-04 Plaid cross-reference, 13-05 orchestrator, 13-06 API routes]

# Tech tracking
tech-stack:
  added: []
  patterns: [cross-document schema contract, comparison pair configuration, severity elevation rules, bidirectional type matching]

key-files:
  created:
    - backend-express/schemas/crossDocumentAnalysisSchema.js
    - backend-express/config/crossDocumentComparisons.js
  modified: []

key-decisions:
  - "Schema-first for cross-document analysis — define output contract before building comparison engine"
  - "9 comparison pairs covering primary mortgage document relationships (stmt-vs-stmt, stmt-vs-closing, etc.)"
  - "Bidirectional matching with wildcard subtype support for flexible pair resolution"
  - "Severity elevation rules tied to field tiers from documentFieldDefinitions.js"
  - "paymentVerification nullable — null when no Plaid data available"

patterns-established:
  - "Comparison pair config: declarative document relationship definitions driving engine behavior"
  - "Severity elevation: default severity + field-based elevation rules pattern"
  - "Bidirectional matching: single pair definition matches both orderings"

issues-created: []

# Metrics
duration: 4min
completed: 2026-03-01
---

# Phase 13 Plan 01: Cross-Document Analysis Schema & Comparison Configuration Summary

**Joi validation schema for cross-document forensic analysis reports + 9 comparison pair definitions covering primary mortgage document relationships with severity elevation rules**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-01T01:01:48Z
- **Completed:** 2026-03-01T01:06:20Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Cross-document analysis report schema with full Joi validation covering discrepancies (8 types), timeline events/violations, payment verification with escrow and fee analysis, and risk-scored summary
- 9 comparison pair configurations defining which document types to compare and what discrepancies to detect (stmt-vs-stmt, stmt-vs-closing, stmt-vs-paymenthistory, stmt-vs-escrow, stmt-vs-modification, closing-vs-note, stmt-vs-armadjust, correspondence-vs-stmt, legal-vs-stmt)
- Severity elevation rules for all 8 discrepancy types with field-tier-based and context-based elevation logic
- Bidirectional matching helper with wildcard subtype support for flexible pair resolution

## Task Commits

Each task was committed atomically:

1. **Task 1: Create cross-document analysis report schema** - `e4cd6bb` (feat)
2. **Task 2: Create comparison pair configuration and discrepancy taxonomy** - `9b1b694` (feat)

## Files Created/Modified
- `backend-express/schemas/crossDocumentAnalysisSchema.js` - Joi schema for cross-document forensic analysis output (280 lines)
- `backend-express/config/crossDocumentComparisons.js` - Comparison pair config + severity rules + helper (267 lines)

## Decisions Made
- Schema-first approach for cross-document analysis, matching the pattern established in Phase 12
- 9 comparison pairs cover the primary mortgage servicing audit relationships
- Bidirectional matching allows single pair definition to work regardless of document order
- Severity elevation rules reference field tiers from documentFieldDefinitions.js (critical tier → elevated severity)
- paymentVerification is nullable (null when no Plaid data), not required — graceful degradation when bank data unavailable

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness
- Schema contract defined for all downstream services (comparison engine, Plaid cross-reference, orchestrator, API)
- Ready for 13-02-PLAN.md: Document Data Aggregation & Comparison Pairs (TDD)

---
*Phase: 13-cross-document-forensic-analysis*
*Completed: 2026-03-01*
