---
phase: 04-document-upload-security
plan: 02
subsystem: api
tags: [express, joi, file-validation, security, body-parser, sanitization]

# Dependency graph
requires:
  - phase: 04-document-upload-security/01
    provides: fileValidation utility (validateFileContent, sanitizeFileName)
  - phase: 03-input-validation-framework
    provides: Joi validation middleware, uploadDocumentSchema
provides:
  - Secure upload route with file content validation before storage
  - Filename sanitization in upload pipeline
  - Tightened body parser limits (25MB)
  - Hardened Joi schema with fileName pattern, content size max, documentType whitelist
affects: [document-processing-tests, malware-scanning]

# Tech tracking
tech-stack:
  added: []
  patterns: [defense-in-depth validation (Joi + fileValidation), buffer-decode-then-validate]

key-files:
  created: []
  modified:
    - backend-express/routes/documents.js
    - backend-express/server.js
    - backend-express/schemas/documents.js

key-decisions:
  - "25MB body limit accommodates base64 overhead (~33%) for 20MB PDF binary limit"
  - "Defense-in-depth: Joi rejects path separators in fileName AND sanitizeFileName strips them"
  - "File validation runs after Joi but before storage — needs decoded buffer from route handler"

patterns-established:
  - "Buffer decode → validate → sanitize → store pattern for file uploads"

issues-created: []

# Metrics
duration: 3 min
completed: 2026-02-21
---

# Phase 4 Plan 02: Upload Route Security Hardening Summary

**File validation wired into upload route with buffer-decode-then-validate pattern, body parser reduced to 25MB, and Joi schema hardened with fileName pattern + content size max + documentType whitelist**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-21T01:54:54Z
- **Completed:** 2026-02-21T01:57:46Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Upload route now validates file content (magic number detection) before storage
- Filenames sanitized via sanitizeFileName() before passing to documentService
- Body parser limit reduced from 50MB to 25MB (accommodates base64 overhead for 20MB PDFs)
- Joi schema hardened: fileName max 255 chars with safe character pattern, content max 28MB, documentType whitelist

## Task Commits

Each task was committed atomically:

1. **Task 1: Add file validation to document upload route** - `30a6bba` (feat)
2. **Task 2: Harden body parser limit and update upload Joi schema** - `6470e89` (hardening)

**Plan metadata:** (this commit) (docs: complete plan)

## Files Created/Modified
- `backend-express/routes/documents.js` - Added validateFileContent + sanitizeFileName imports, buffer decode → validate → sanitize flow before storage
- `backend-express/server.js` - Reduced express.json() and express.urlencoded() limits from 50mb to 25mb
- `backend-express/schemas/documents.js` - Added .max(255) + .pattern() to fileName, .max(28000000) to content, .valid() whitelist to documentType

## Decisions Made
- 25MB body limit chosen to accommodate base64 overhead (~33% larger than binary) for 20MB PDF limit
- Defense-in-depth approach: Joi pattern rejects path separators at schema level AND sanitizeFileName strips them in route handler
- File validation kept in route handler (not middleware) because it needs the decoded buffer specific to this route's logic

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness
- Upload route now validates and sanitizes all file uploads
- Ready for 04-03-PLAN.md (malware scanning integration)
- All 150 existing tests still passing

---
*Phase: 04-document-upload-security*
*Completed: 2026-02-21*
