# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-26)

**Core value:** The platform must reliably and securely analyze mortgage documents to detect servicing errors with high confidence, cross-verify against actual bank transaction data, and protect sensitive financial information throughout the process.
**Current focus:** v3.0 Forensic Analysis Engine — litigation-grade document analysis with lending law compliance.

## Current Position

Phase: 10 of 17 (Document Intake & Classification Pipeline)
Plan: 5 of 5 in current phase
Status: Phase complete
Last activity: 2026-02-27 — Completed 10-05-PLAN.md

Progress: ████░░░░░░░░░░░░░░░░ 20% (v3.0 Milestone — 5 of ~25 plans)

## Performance Metrics

**Velocity (v2.0):**
- Total plans completed: 32
- Average duration: ~4 min
- Total execution time: ~2.5 hours

**By Phase (v2.0):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 3/3 | 11 min | 3.7 min |
| 2 | 3/3 | 13 min | 4.3 min |
| 3 | 5/5 | 13 min | 2.6 min |
| 4 | 4/4 | 37 min | 9.3 min |
| 5 | 5/5 | 24 min | 4.8 min |
| 6 | 2/2 | 8 min | 4.0 min |
| 7 | 2/2 | 8 min | 4.0 min |
| 8 | 4/4 | 12 min | 3.0 min |
| 9 | 4/4 | 18 min | 4.5 min |

## Accumulated Context

### Decisions

All v2.0 decisions documented in PROJECT.md Key Decisions table.

| Phase | Decision | Rationale |
|-------|----------|-----------|
| 10-01 | Application-level integrity for document_id FK | Existing documents table lacks formal PK on document_id |
| 10-01 | Status CHECK constraint (open/in_review/complete/archived) | Enforced at DB level for data integrity |
| 10-02 | Lazy Anthropic client initialization in ocrService | Allows text PDF extraction without API key; only errors when Vision needed |
| 10-02 | 50-char threshold for meaningful PDF text | Prevents scanned PDFs with metadata-only text from being misclassified |
| 10-03 | claude-sonnet-4-5 for classification (not opus) | Fast, cost-effective for structured classification; opus reserved for deep analysis |
| 10-03 | Graceful JSON parse fallback on Claude responses | Returns { rawResponse, parseError } instead of throwing; prevents pipeline crashes |
| 10-04 | Best-effort DB persistence for pipeline state | Pipeline never blocks on Supabase write failures; logs warning, continues in-memory |
| 10-04 | Dual input via Joi .or() (documentText or fileBuffer) | Supports iOS pre-extracted text and server-side OCR from same endpoint |
| 10-04 | Single-case auto-association only | Avoids ambiguity: 0 or 2+ open cases skip association, user assigns manually |
| 10-05 | userId from req.user.id (JWT) not request body | More secure than v2.0 pattern; prevents client-side userId spoofing |
| 10-05 | Integration tests mock external boundaries only | Internal pipeline logic runs for real; realistic coverage without API dependencies |

### Deferred Issues

None.

### Pending Todos

None.

### Blockers/Concerns

None.

### Roadmap Evolution

- Milestone v3.0 created: Forensic Analysis Engine, 8 phases (Phase 10-17)

## Session Continuity

Last session: 2026-02-27
Stopped at: Completed 10-05-PLAN.md — Phase 10 complete
Resume file: None
