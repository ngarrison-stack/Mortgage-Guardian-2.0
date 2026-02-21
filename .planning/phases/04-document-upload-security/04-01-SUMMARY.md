---
phase: 04-document-upload-security
plan: 01
subsystem: security
tags: [file-type, magic-number, tdd, validation, sanitization, upload-security]

# Dependency graph
requires:
  - phase: 03-input-validation-framework
    provides: Joi validation middleware and patterns
provides:
  - validateFileContent() with magic number detection via file-type v16
  - sanitizeFileName() with path traversal and null byte protection
  - ALLOWED_FILE_TYPES and FILE_SIZE_LIMITS constants
affects: [04-document-upload-security, 06-document-processing-tests]

# Tech tracking
tech-stack:
  added: [file-type@^16.5.4]
  patterns: [TDD red-green-refactor, magic number validation, filename sanitization]

key-files:
  created:
    - backend-express/utils/fileValidation.js
    - backend-express/__tests__/utils/fileValidation.test.js
  modified:
    - backend-express/package.json

key-decisions:
  - "file-type v16.x chosen (last CJS-compatible version; v17+ is ESM-only)"
  - "Object.freeze() on exported constants to prevent runtime mutation"
  - "Undetectable types (plain text) allowed with warning rather than rejected"

patterns-established:
  - "TDD for security-critical utilities: test-first catches implementation bugs early"
  - "Magic number validation pattern: FileType.fromBuffer() → compare with claimed extension"

issues-created: []

# Metrics
duration: 6 min
completed: 2026-02-21
---

# Phase 4 Plan 01: File Validation Utility (TDD) Summary

**Magic number file validation with file-type v16, filename sanitization against path traversal/null bytes, and per-type size limits — 38 tests via TDD**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-21T01:43:13Z
- **Completed:** 2026-02-21T01:49:17Z
- **Tasks:** 3 (RED, GREEN, REFACTOR)
- **Files modified:** 3

## Accomplishments
- validateFileContent() detects PDF, JPEG, PNG magic numbers and rejects disguised files (EXE-as-PDF)
- sanitizeFileName() strips path traversal (../), null bytes, special characters, and truncates to 255 chars
- Per-type size limits enforced: PDF 20MB, images 10MB, text 5MB
- Undetectable types (plain text) allowed with warning for graceful handling
- Constants frozen with Object.freeze() to prevent accidental runtime mutation

## Task Commits

Each TDD phase was committed atomically:

1. **RED: Failing tests** - `7b66f41` (test) — 38 tests across validateFileContent, sanitizeFileName, constants
2. **GREEN: Implementation** - `956ec50` (feat) — file-type v16 integration, all 38 tests pass
3. **REFACTOR: Cleanup** - `010bfbe` (refactor) — Object.freeze() on constants, anchored regex for extension parsing

## Files Created/Modified
- `backend-express/utils/fileValidation.js` — Created (229 lines) — Core validation utility with magic number detection
- `backend-express/__tests__/utils/fileValidation.test.js` — Created (404 lines) — 38 comprehensive tests
- `backend-express/package.json` — Modified — Added file-type@^16.5.4 dependency

## RED Phase
- Wrote 38 tests covering: valid file types (PDF, JPEG, PNG), disguised files (EXE-as-PDF), disallowed types (ZIP, RAR), empty buffers, size limit violations, undetectable types, filename sanitization (path traversal, null bytes, special chars, truncation)
- Tests failed with `Cannot find module '../../utils/fileValidation'` — expected RED state

## GREEN Phase
- Installed file-type@^16.5.4 (last CJS-compatible version)
- Implemented validateFileContent() using FileType.fromBuffer() for magic number detection
- Implemented sanitizeFileName() with path traversal removal, null byte stripping, special char replacement
- Fixed consecutive underscore collapsing bug caught by TDD (input "my document (1).pdf" was producing double underscores)
- All 38 tests pass

## REFACTOR Phase
- Applied Object.freeze() to ALLOWED_FILE_TYPES and FILE_SIZE_LIMITS constants
- Changed `.replace('.', '')` to `.replace(/^\./, '')` for anchored regex precision
- All 38 tests still pass

## Decisions Made
- Used file-type v16.x (not v17+) because backend uses CommonJS; v17+ is ESM-only
- Undetectable types (plain text) return valid:true with warning instead of rejection — balances security with usability for .txt uploads
- Object.freeze() on exported constants as defensive programming practice

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None

## Next Step
Ready for 04-02-PLAN.md

---
*Phase: 04-document-upload-security*
*Completed: 2026-02-21*
