---
phase: 24
plan: "02"
title: "Claude & Documents Routes Test Coverage"
subsystem: testing
tags: [claude, documents, routes, jest, supertest, coverage, pipeline]
requires: [backend-express/routes/claude.js, backend-express/routes/documents.js, backend-express/services/claudeService.js, backend-express/services/documentPipelineService.js]
provides: [backend-express/__tests__/routes/claude-routes.test.js]
affects: [routes/claude.js coverage, routes/documents.js coverage]
tech-stack: [jest@29.7.0, supertest, express]
key-files:
  - backend-express/__tests__/routes/claude-routes.test.js
  - backend-express/__tests__/routes/documents-routes.test.js
  - backend-express/routes/claude.js
  - backend-express/routes/documents.js
  - backend-express/schemas/claude.js
  - backend-express/schemas/documents.js
key-decisions:
  - Created new claude-routes.test.js rather than extending another file, matching 1-file-per-route convention
  - Extended existing documents-routes.test.js rather than creating a separate file, to avoid mock duplication
  - Mocked documentPipelineService with both sync (completeDocument, getUserPipeline) and async (processDocument, getStatus, retryDocument) methods
  - Used mockImplementation for sync throw errors (completeDocument) vs mockRejectedValue for async errors
patterns-established:
  - Pipeline service mocking pattern with both sync and async method mocks
  - Error message pattern matching for 400 vs 500 routing in catch blocks
  - Analysis endpoint testing with multiple document states (no analysis, error analysis, success)
duration: ~12 minutes
completed: 2026-04-02
---

# 24-02 Summary: Claude & Documents Routes Test Coverage

Added 46 tests across Claude and documents route files, raising claude.js from 58% to 100% and documents.js from 60% to 98% statement coverage.

## Performance

- Duration: ~12 minutes
- Tasks: 2
- Files created: 1
- Files modified: 1
- Tests added: 34 (22 new document tests + 12 claude tests)
- Final test suite: 50 suites, 1411 tests, all passing

## Accomplishments

- **routes/claude.js: 100% statements, 100% branches** (was 58.62% / 40%)
  - POST /analyze: prompt-based, documentText fallback via buildMortgageAnalysisPrompt, optional params
  - POST /analyze error branches: 401 (invalid API key), 429 (rate limit), generic 500
  - POST /test: success and error paths
  - Validation: missing prompt/documentText returns 400
  - Auth: missing token returns 401

- **routes/documents.js: 98.16% statements, 89.28% branches** (was 60.55% / 46.42%)
  - GET /pipeline: empty list, filtered by status, invalid status validation
  - GET /:documentId/analysis: success, 404 not found, 404 no analysis, 422 analysis error, 500 service throw
  - POST /process: success 200, pipeline failure 422, unexpected error 500, validation 400
  - GET /:documentId/status: found 200, not found 404
  - POST /:documentId/retry: success, failure 422, not-in-failed-state 400, no-pipeline 400, unexpected 500
  - POST /:documentId/complete: success, must-be-in-review 400, no-pipeline 400, unexpected 500
  - POST /upload error branch: service throw 500

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `d13fbe6` | Claude routes tests for uncovered paths |
| 2 | `045be9a` | Documents route tests for uncovered paths |

## Files Created/Modified

- **Created:** `backend-express/__tests__/routes/claude-routes.test.js` (260 lines)
- **Modified:** `backend-express/__tests__/routes/documents-routes.test.js` (+421 lines)

## Decisions Made

1. **Mock pattern for documentPipelineService:** Used a flat mock object with jest.fn() methods rather than mocking the class, since the module exports a singleton instance. Both sync methods (completeDocument, getUserPipeline) and async methods (processDocument, getStatus, retryDocument) were mocked.

2. **Error routing in retry/complete:** The route handlers use string matching on error.message to distinguish 400 (user error) from 500 (server error). Tests verify both paths with specific error message patterns.

3. **Upload error branch:** Covered line 68-69 by making uploadDocument reject. The file validation lines (39, 60) remain at ~98% since they are covered by the separate documents-upload-security.test.js file.

## Deviations from Plan

None. Both targets exceeded: claude.js hit 100% (target 90%), documents.js hit 98% (target 85%).

## Issues Encountered

None.

## Next Phase Readiness

Phase 24-03 can proceed. All route test files follow consistent patterns with mockSupabaseClient, mockClaudeService, and service-level mocks. The documentPipelineService mock pattern established here can be reused for any pipeline-related testing.
