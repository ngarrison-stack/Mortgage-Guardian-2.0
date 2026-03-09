---
phase: 13-cross-document-forensic-analysis
plan: 05
subsystem: api
tags: [orchestrator, forensic-analysis, pipeline, graceful-degradation, jest]

requires:
  - phase: 13-02
    provides: Cross-document aggregation service (document collection + pair generation)
  - phase: 13-03
    provides: Cross-document comparison service (AI-powered pair analysis)
  - phase: 13-04
    provides: Plaid cross-reference service (payment verification)
  - phase: 13-01
    provides: Cross-document analysis schema for report validation
provides:
  - Forensic analysis orchestrator coordinating aggregation, comparison, Plaid cross-reference, and consolidation
  - Consolidated forensic report with summary, risk levels, recommendations, and metadata
  - Graceful degradation on partial failures (individual pair errors, Plaid outages, Supabase write failures)
  - Recommendation generation mapped from discrepancy types
affects: [13-06, 16-consolidated-reporting]

tech-stack:
  added: []
  used: [node, jest]
---

## What was built

**ForensicAnalysisService** (`backend-express/services/forensicAnalysisService.js`) — the orchestrator that ties together all Phase 13 services into a single `analyzeCaseForensics(caseId, userId, options)` entry point.

### Orchestration flow

1. **AGGREGATE** — calls `crossDocumentAggregationService.aggregateForCase()` to collect case documents and generate comparison pairs
2. **COMPARE PAIRS** — iterates over each pair calling `crossDocumentComparisonService.compareDocumentPair()`, collecting discrepancies and timeline data with graceful degradation on individual failures
3. **PLAID CROSS-REFERENCE** (optional) — when `plaidAccessToken` is provided, fetches transactions via `plaidService.getTransactions()`, extracts document payments, and cross-references via `plaidCrossReferenceService`
4. **CONSOLIDATE** — merges all findings, deduplicates discrepancies and violations, calculates summary (risk level, key findings, recommendations), validates against schema

### Key design decisions

- **Graceful degradation**: individual comparison pair failures log warnings and continue; Plaid failures skip the step; Supabase persistence failures are best-effort
- **Schema validation as warnings**: report is validated against `crossDocumentAnalysisSchema` but never rejected on validation errors
- **Deduplication**: discrepancies with same field+type keep the higher severity; recommendations are deduplicated via Set; timeline violations deduplicated by description
- **Sequential discrepancy IDs**: all discrepancies across all pairs get sequential `disc-001`, `disc-002`, etc.
- **Recommendation mapping**: each discrepancy type maps to a specific actionable recommendation

## Files

| File | Action |
|------|--------|
| `backend-express/services/forensicAnalysisService.js` | Created |
| `backend-express/__tests__/services/forensicAnalysisService.test.js` | Created |

## Test results

- **33 tests**, all passing
- **Coverage areas**: aggregation step (4), comparison step (6), Plaid cross-reference step (6), consolidation step (9), metadata tracking (3), error handling (5)
- **Full suite**: 848 tests across 31 suites, all passing
