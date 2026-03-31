---
phase: 21-report-generation-integration-fixes
plan: 04
status: completed
completed: 2026-03-30
tests_added: 10
tests_total: 1274
regressions: 0
---

# 21-04 Summary: End-to-End Integrity Tests

## What was done

Added 10 end-to-end integrity tests across 2 test files verifying the full report generation pipeline from aggregation through scoring, assembly, schema validation, and dispute letter generation.

### Task 1: Report Pipeline Integrity Tests (5 tests)

**File**: `backend-express/__tests__/integration/report-pipeline-integrity.test.js`

Created a new integration test file that runs the real aggregation, scoring, and assembly logic with only `caseFileService` mocked at the I/O boundary.

Tests:
1. **Full report validates against schema** — Comprehensive case data with documents, forensic analysis, and compliance report produces a schema-valid report with zero validation errors.
2. **Partial report validates (no forensic, no compliance)** — Case with only document analyses produces a valid report with null breakdown scores for absent layers.
3. **findingSummary counts match detail sections** — Verifies all 6 category counts (documentAnomalies, crossDocDiscrepancies, timelineViolations, paymentIssues, federalViolations, stateViolations) match the actual lengths of their detail arrays, and totalFindings equals the sum.
4. **documentAnalysis preserves anomaly details** — Each anomaly retains id, field, type, severity, and description through the aggregation → assembly pipeline.
5. **classificationConfidence flows into scoring** — Average classification confidence (0.85) propagates from document analysis_reports through aggregation into the confidence scoring service, producing the correct classificationImpact factor.

### Task 2: Dispute Letter Dual-Format Tests (5 tests)

**File**: `backend-express/__tests__/services/disputeLetterService.test.js` (appended)

Tests the Phase 21-02 fixes verifying `_extractViolations` and `_extractFindings` handle both data formats:

1. **_extractViolations from consolidated format** — Reads `complianceFindings.federalViolations` and `complianceFindings.stateViolations`.
2. **_extractViolations from raw aggregated format** — Reads `complianceReport.violations` and `complianceReport.stateViolations`.
3. **_extractFindings from consolidated format** — Reads `documentAnalysis` (singular) and `forensicFindings.discrepancies`.
4. **_extractFindings from raw aggregated format** — Reads `documentAnalyses` (plural) and `forensicReport.discrepancies`.
5. **Full letter generation from stored report** — Generates a QWR letter from a stored consolidated report and verifies the Claude prompt includes violation descriptions, legal citations, and finding details.

## Test counts

- New tests added: 10
- Total tests after: 1,274 passing
- Regressions: 0 (1 pre-existing failure in documentPipeline-integration.test.js unrelated to Phase 21)

## Key design decisions

- **Separate integration test file for pipeline integrity**: The existing `consolidatedReportService.test.js` uses hoisted `jest.mock()` for all upstream services. Pipeline integrity tests need real service logic, so a separate file with a minimal mock strategy (only caseFileService) was created.
- **Dual-format tests added to existing file**: The dispute letter dual-format tests fit naturally alongside the existing test structure since they share the same Anthropic SDK mock setup.

## Regression protection

These tests protect all Phase 21 fixes:
- **21-01**: Schema validation with null breakdown layers, classificationConfidence wiring
- **21-02**: Dual-format support in dispute letter extraction methods
- **21-03**: Anomaly detail preservation through the assembly pipeline
