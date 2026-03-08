---
phase: 13-cross-document-forensic-analysis
plan: 03
subsystem: api
tags: [claude-ai, forensic-analysis, cross-document-comparison, prompt-engineering, discrepancy-detection]

# Dependency graph
requires:
  - phase: 13-01
    provides: crossDocumentComparisons config with COMPARISON_PAIRS, DISCREPANCY_SEVERITY_RULES
  - phase: 13-02
    provides: crossDocumentAggregationService for collecting document pairs
  - phase: 12-02
    provides: documentAnalysisService patterns (Claude AI integration, prompt construction, response parsing)
provides:
  - crossDocumentComparisonService.compareDocumentPair(docA, docB, comparisonConfig) — Claude AI forensic comparison
  - Type-specific forensic prompts for all 9 comparison pair types plus default fallback
  - Structured output: discrepancies, timelineEvents, timelineViolations, comparisonSummary
  - Graceful error handling (never throws, returns error objects with pairId context)
affects: [13-05 forensic orchestrator, 13-06 API routes]

# Tech tracking
tech-stack:
  added: []
  patterns: [system-prompt + user-message Claude API pattern, type-specific prompt routing via switch on pairId, markdown code fence JSON extraction fallback, result enrichment with enum validation]

key-files:
  created:
    - backend-express/services/crossDocumentComparisonService.js
    - backend-express/__tests__/services/crossDocumentComparisonService.test.js
  modified: []
  config: []
---

## Summary

Built the cross-document comparison service that uses Claude AI to perform forensic analysis on document pairs. The service detects discrepancies, contradictions, timeline violations, and regulatory concerns across related mortgage documents.

### Task 1: Cross-document comparison service (561 lines)

Created `crossDocumentComparisonService.js` following established patterns from `documentAnalysisService.js`:

- **Main method**: `compareDocumentPair(docA, docB, comparisonConfig)` — accepts two analyzed documents and a comparison configuration, calls Claude AI with forensic prompts, returns structured discrepancy output
- **System prompt**: Establishes forensic mortgage analyst persona at a major law firm
- **Type-specific instructions**: `_getComparisonInstructions(pairId)` provides domain-specific forensic guidance for all 9 comparison pair types (stmt-vs-stmt, stmt-vs-closing, stmt-vs-paymenthistory, stmt-vs-escrow, stmt-vs-modification, closing-vs-note, stmt-vs-armadjust, correspondence-vs-stmt, legal-vs-stmt) plus a default generic comparison
- **Prompt construction**: Includes filtered extractedData (only comparison-relevant field categories), known anomalies from individual analysis, applicable discrepancy types, and JSON output schema
- **Response parsing**: Direct JSON parse with markdown code fence extraction fallback
- **Result enrichment**: Assigns discrepancy IDs if omitted, validates type/severity against allowed enums, provides defaults for missing fields
- **Error handling**: Never throws — returns error objects with pairId, documentA/B refs, empty arrays, and errorMessage for all failure modes (null inputs, empty data, API errors, parse failures)
- **Configuration**: claude-sonnet-4-5-20250514, max_tokens 4096, temperature 0.1

### Task 2: Comprehensive unit tests (654 lines, 43 tests)

Created `crossDocumentComparisonService.test.js` with fully mocked Anthropic SDK:

- **compareDocumentPair** (14 tests): System prompt content, extractedData inclusion, type-specific instructions, JSON parsing, code fence handling, API error handling, parse failure handling, null document handling, empty data handling, anomaly context, model config, missing config, single-doc data
- **comparison instructions** (10 tests): All 9 pair types verified for correct forensic focus areas, default fallback for unknown pair IDs
- **response enrichment** (9 tests): ID assignment, type enum validation, severity enum validation, optional field handling, missing description/refs, timeline violation defaults, empty arrays, missing arrays
- **_parseResponse** (4 tests): Valid JSON, code fences with/without language tag, non-JSON text
- **_filterExtractedData** (3 tests): Field filtering, null extractedData, null comparisonFields
- **_buildDocRef** (3 tests): Valid doc, null doc, missing fields

### Commits

- `b0ddb5b` — feat(13-03): create cross-document comparison service with forensic prompts
- `2c0c4cb` — test(13-03): add comprehensive tests for cross-document comparison service

### Test Results

- New tests: 43 passed
- Full suite: 796 passed (29 test suites)
- No regressions

### Deviations

None. Both files were already present as untracked files matching the plan specification exactly. All verification checks passed on first run.
