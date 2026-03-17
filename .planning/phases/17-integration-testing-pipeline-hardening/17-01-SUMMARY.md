---
phase: 17-integration-testing-pipeline-hardening
plan: 01
subsystem: testing
tags: [e2e, integration-tests, pipeline, regression, mock-infrastructure]

# Dependency graph
requires:
  - phase: 10-04
    provides: documentPipelineService state machine
  - phase: 13-05
    provides: forensicAnalysisService orchestrator
  - phase: 14-06
    provides: complianceService orchestrator
  - phase: 16-05
    provides: consolidatedReportService orchestrator
provides:
  - pipeline-wide mock factory (createMockPipelineContext, setupPipelineMocks)
  - 18 end-to-end integration tests covering full pipeline chain
  - regression safety net for Phases 10-16 orchestrator changes
affects: [17-02, 17-03, 17-04]

# Tech tracking
tech-stack:
  added: []
  patterns: [coordinated multi-orchestrator mock factory, pipeline context pattern]

# Test metrics delta
tests_before: 1145
tests_after: 1163
tests_added: 18
suites_before: 42
suites_after: 43
regressions: 0
---

## What was built

### Task 1: Pipeline-Wide Mock Infrastructure
**File:** `backend-express/__tests__/mocks/mockPipelineServices.js`

Created a centralized mock factory that produces coordinated mock responses across all 4 orchestrators:

- **`createMockPipelineContext(overrides?)`** — Returns a complete set of mock data for a 2-document case (mortgage statement + closing disclosure) with consistent IDs flowing through:
  - OCR results, classification results, individual analysis results
  - Cross-document forensic results (2 discrepancies: amount_mismatch, date_inconsistency)
  - Federal compliance results (1 RESPA violation)
  - State compliance results (1 CA HBOR violation)
  - Consolidated report with confidence scoring, evidence links, recommendations
  - Dispute letter content
  - Case data for caseFileService mocking

- **`setupPipelineMocks(context, mocks)`** — Configures mock implementations on already-mocked modules. Accepts references to all mocked dependencies and sets up coordinated responses.

### Task 2: End-to-End Pipeline Integration Tests
**File:** `backend-express/__tests__/integration/full-pipeline-e2e.test.js`

18 tests organized in 5 describe blocks:

1. **Full happy path (6 tests)**
   - Complete 2-document pipeline chain through all 4 orchestrators
   - State transitions verified: uploaded → ocr → classifying → analyzing → analyzed → review
   - Cross-document discrepancy detection validated
   - Federal + state compliance violations found
   - Consolidated report contains all upstream findings
   - Dispute letter generation with generateLetter option

2. **Pipeline state consistency (3 tests)**
   - Document IDs flow correctly through all stages
   - Case ID consistent across all orchestrator outputs
   - Finding counts in consolidated report match upstream totals (category sum = severity sum = total)

3. **Partial pipeline (3 tests)**
   - Individual document analysis works independently without forensics/compliance
   - Consolidated report handles missing forensic/compliance data gracefully (null scores, empty arrays)
   - Forensic analysis returns early with warning when < 2 analyzed documents

4. **Multi-document scaling (2 tests)**
   - 3+ documents processed, all comparison pairs generated (3 pairs for 3 docs)
   - Compliance evaluates findings from all documents

5. **Error resilience (4 tests)**
   - Forensic graceful degradation when one comparison pair fails
   - Compliance returns clear error when forensic data missing
   - Consolidated report returns error when gather step fails
   - Input validation for missing required parameters across all orchestrators

## Key design decisions

- **Mock at external boundaries only**: Anthropic SDK, Supabase, Plaid — tests exercise real orchestration logic
- **Reused existing patterns**: Hoisted jest.mock, mockSupabaseClient chainable pattern, beforeEach reset
- **setupPipelineMocks takes mock references** rather than calling jest.mock() internally, because jest.mock must be hoisted — the test file owns the mock declarations
- **Context object pattern**: Single `createMockPipelineContext()` call produces all cross-referenced data, preventing ID mismatches between stages
