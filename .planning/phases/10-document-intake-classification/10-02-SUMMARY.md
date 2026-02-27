---
phase: 10-document-intake-classification
plan: 02
subsystem: api
tags: [ocr, pdf-parse, claude-vision, document-extraction, anthropic-sdk]

# Dependency graph
requires:
  - phase: 10-01
    provides: case_files and document_classifications schema, caseFileService singleton
  - phase: v2.0 milestone
    provides: documentService patterns, claudeService Anthropic SDK usage, createLogger utility
provides:
  - ocrService.js hybrid text extraction (pdf-parse + Claude Vision)
  - Server-side OCR removing iOS client dependency
  - Automatic fallback from text extraction to Vision for scanned documents
affects: [phase-10-03, phase-10-04, phase-10-05, phase-12, phase-13]

# Tech tracking
tech-stack:
  added: [pdf-parse]
  patterns: [lazy-client-initialization, hybrid-extraction-with-fallback]

key-files:
  created:
    - backend-express/services/ocrService.js
    - backend-express/__tests__/services/ocrService.test.js
  modified:
    - backend-express/package.json
    - backend-express/package-lock.json

key-decisions:
  - "Lazy Anthropic client initialization — only errors on missing API key when Vision is actually needed, not on module load"
  - "50-char threshold for meaningful text — avoids treating scanned PDFs with metadata-only text as text PDFs"
  - "Module cache clearing in tests for fresh singleton per test case"

patterns-established:
  - "Hybrid extraction pattern: try cheap/fast method first, fallback to AI when insufficient"
  - "Lazy client initialization: defer API client creation until first use"

issues-created: []

# Metrics
duration: 4min
completed: 2026-02-27
---

# Phase 10 Plan 02: Server-Side OCR Service Summary

**Hybrid OCR service using pdf-parse for text PDFs and Claude Vision for scanned documents/images, with automatic fallback when extracted text is insufficient (<50 chars)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-27T07:42:39Z
- **Completed:** 2026-02-27T07:46:38Z
- **Tasks:** 2
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- Created ocrService.js with hybrid extraction: pdf-parse for text PDFs (fast, free), Claude Vision for scanned PDFs and images (AI-powered)
- Automatic scanned PDF detection — falls back to Vision when pdf-parse yields <50 chars of text or throws errors
- Supports 6 file types: PDF, JPG, JPEG, PNG, HEIC, TIFF with proper MIME type routing
- 28 test cases covering all extraction paths, error handling, input validation, and edge cases
- Zero regressions: 547 tests passing (28 new + 519 existing)

## Task Commits

Each task was committed atomically:

1. **Task 1: Install pdf-parse and create OCR service with hybrid extraction** - `921a274` (feat)
2. **Task 2: Create comprehensive OCR service tests** - `6cd6b7f` (test)

## Files Created/Modified
- `backend-express/services/ocrService.js` - OcrService singleton with extractText(), _extractFromPdf(), _extractFromImage(), _detectFileType()
- `backend-express/__tests__/services/ocrService.test.js` - 28 tests covering text PDF, scanned PDF fallback, image extraction, unsupported types, error handling, missing API key, input validation
- `backend-express/package.json` - Added pdf-parse ^2.4.5 dependency
- `backend-express/package-lock.json` - Updated lockfile

## Decisions Made
- **Lazy Anthropic client initialization:** Client created on first Vision use via `_getClient()` rather than at module scope. This allows ocrService to load and handle text PDFs without ANTHROPIC_API_KEY, only erroring when Vision is actually needed.
- **50-char meaningful text threshold:** Prevents scanned PDFs containing only embedded metadata from being treated as text PDFs. Balances false-positive avoidance with reasonable detection.
- **Module cache clearing in tests:** `getOcrService()` helper clears require cache for fresh singleton state per test, essential for testing API key presence/absence scenarios.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## Next Phase Readiness
- ocrService ready for integration into 10-04 (Enhanced Intake Pipeline)
- Classification engine (10-03) can receive extracted text from ocrService
- Total test count: 547 passing (28 new + 519 existing)

---
*Phase: 10-document-intake-classification*
*Completed: 2026-02-27*
