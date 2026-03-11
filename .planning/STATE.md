# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-26)

**Core value:** The platform must reliably and securely analyze mortgage documents to detect servicing errors with high confidence, cross-verify against actual bank transaction data, and protect sensitive financial information throughout the process.
**Current focus:** v3.0 Forensic Analysis Engine — litigation-grade document analysis with lending law compliance.

## Current Position

Phase: 16 of 17 (Consolidated Findings & Reporting)
Plan: 4 of 6 in current phase
Status: In progress
Last activity: 2026-03-11 — Completed 16-04-PLAN.md

Progress: █████████████████░░░ 95% (v3.0 Milestone — 37 of ~38 plans)

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
| 11-01 | Idempotent DO $$ guards on all 14 RLS policies | Safe to re-run migration multiple times |
| 11-01 | document_classifications uses EXISTS join RLS | No direct user_id column; joins through documents table |
| 11-01 | No service_role bypass policy | Supabase service_role bypasses RLS by default |
| 11-02 | storage.foldername(name)[2] for userId extraction | Path is documents/{userId}/{docId}; PG 1-indexed arrays |
| 11-02 | schemaname='storage' in pg_policies guard | Avoids false-positive match against public schema policies |
| 11-02 | validateStoragePath as defense-in-depth | Paths constructed internally; guards against future untrusted path changes |
| 11-03 | Pack format iv+authTag+ciphertext in single buffer | Simplifies storage (one blob) and unpacking (fixed offsets) |
| 11-03 | HKDF info string 'mortgage-guardian-doc-v1' | Domain separation ensures keys cannot be reused across apps |
| 11-04 | Lazy-load encryption service with env var guard | Constructor throws without key; lazy loading provides graceful degradation |
| 11-04 | Encrypted flag in document metadata | Enables backward compatibility: old unencrypted docs download alongside encrypted |
| 11-04 | Pipeline never encrypts/decrypts directly | Encryption is a storage concern in documentService, not a processing concern |
| 11-05 | Test real encryption, mock only Supabase boundary | Validates actual AES-256-GCM round-trip rather than mocking crypto |
| 11-05 | 10 user-isolation tests (exceeding 7+ target) | Includes negative + positive controls for complete cross-user coverage |
| 12-01 | Schema-first design for analysis output | Define contract before building analysis service; ensures consistent AI output |
| 12-01 | Flexible Joi.object().pattern() for extractedData | Different document types produce different field names; validates structure not field names |
| 12-01 | Three-tier field classification (critical/expected/optional) | Drives completeness scoring severity levels |
| 12-01 | Generic fallback for unknown subtypes | Ensures pipeline resilience for unrecognized documents |
| 12-02 | Dynamic extraction templates from field definitions | Prompts stay in sync with field definition changes; not hardcoded |
| 12-02 | Anomaly severity elevation for critical fields | Critical field anomalies auto-elevated to 'high' regardless of Claude's initial assessment |
| 12-02 | Markdown code fence extraction fallback | Claude occasionally wraps JSON in markdown; graceful extraction |
| 12-02 | Schema validation as warnings not rejections | Pipeline never fails on minor schema deviations; warnings attached instead |
| 12-03 | Pass classification results directly to analysis service | Avoids redundant re-classification; pipeline already has classification from earlier step |
| 12-03 | Analysis route BEFORE /:documentId | Prevents Express treating "analysis" as a documentId param |
| 12-03 | Return 200 with status:'error' for failed analysis | Client distinguishes "not analyzed" (404) from "analysis failed" (200 + error status) |
| 13-01 | Schema-first for cross-document analysis | Define output contract before building comparison engine |
| 13-01 | 9 comparison pairs for mortgage doc relationships | Covers stmt-vs-stmt, stmt-vs-closing, legal-vs-stmt, etc. |
| 13-01 | Bidirectional matching with wildcard subtypes | Single pair definition matches both document orderings |
| 13-01 | Severity elevation tied to field tiers | Critical tier fields auto-elevate discrepancy severity |
| 13-01 | paymentVerification nullable | Graceful degradation when no Plaid data available |
| 13-02 | Direct pipeline Map access for analysis fallback | getStatus() omits analysisResults; pipelineState.get() provides full data |
| 13-02 | Classification from analysisReport.documentInfo first | Primary source; pipeline classificationResults as fallback |
| 13-02 | Synchronous _normalizeDocument | Pipeline Map access is sync; no async needed for normalization |
| 13-03 | claude-sonnet-4-5 for cross-document comparison | Same model as individual analysis; fast, cost-effective for structured output |
| 13-03 | Type-specific forensic prompts via _getComparisonInstructions | 9 pair types with domain-specific forensic guidance plus default fallback |
| 13-03 | Result enrichment with enum validation | Assigns IDs if omitted, validates type/severity against allowed enums |
| 13-03 | Temperature 0.1 for forensic accuracy | Deterministic output for consistent forensic analysis |
| 13-04 | Greedy matching by (dateDiff + amountDiff) score | Best-match-first prevents one-to-many; remaining go to unmatched |
| 13-04 | 80% threshold for paymentVerified | Balance between strictness and real-world posting delays |
| 13-04 | Keyword-based escrow/fee classification | Transaction name/merchantName/category matched against keyword arrays |
| 13-04 | Pending transactions excluded before matching | Pending amounts may change; only match settled transactions |
| 13-06 | Forensic routes before /:caseId | Prevents Express param matching (consistent with 12-03 pattern) |
| 13-06 | 200 + status:'error' for analysis failures | Client distinguishes "not analyzed" (404) from "analysis failed" (200 + error) |
| 14-04 | claude-sonnet-4-5 for compliance analysis | Consistent with 12-02/13-03; fast, cost-effective for structured legal output |
| 14-04 | Violations batched by statute (max 10 per call) | Prevents context overflow; groups related violations for better Claude analysis |
| 14-04 | Graceful degradation on Claude API failure | Original violations returned unchanged; compliance engine never blocks on AI |
| 14-04 | Lazy Anthropic client initialization | Consistent with ocrService pattern; tests run without API key |
| 14-05 | Follows forensicAnalysisService orchestrator pattern | Singleton, error objects, step metadata, best-effort persistence |
| 14-05 | AI step auto-skipped on zero violations | No wasted Claude API calls when rule engine finds nothing |
| 14-05 | Post-evaluation statute filtering | Rule engine runs fully then results filtered; more flexible |
| 14-06 | Compliance routes before case routes in server.js | Prevents Express /:caseId param matching /compliance/* paths |
| 14-06 | Statute endpoints at /v1/compliance/statutes | Separate from case-scoped /v1/cases/:caseId/compliance routes |
| 15-01 | Optional jurisdiction fields in compliance schema | Federal-only reports validate unchanged; backward compatible |
| 15-01 | State taxonomy mirrors federal data shape | Enables matchRules() reuse for state statute processing |
| 15-01 | 6 priority states scaffolded (CA, NY, TX, FL, IL, MA) | Empty statute slots populated in 15-03/15-04 |
| 15-06 | Reuse _deduplicateViolations/_shouldElevateSeverity for state | Same dedup and elevation logic applies to state violations |
| 15-06 | StatuteId derived from sectionId first two underscore segments | Mirrors federal pattern (e.g. ca_hbor_dual_tracking → ca_hbor) |
| 15-06 | Skip refactor of federal/state evaluation duplication | Refactoring federal code path carries regression risk; defer |
| 15-07 | State AI uses same batching (max 10/call) and model as federal | Predictable token usage; avoids second batching strategy |
| 15-07 | generateLegalNarrative extended with optional 3rd param | Dynamic state section when present; avoids separate method |
| 15-07 | Lazy require for JurisdictionService | Fresh instance per call; avoids module-level init issues |
| 15-07 | stateCompliance summary parallels federal complianceSummary | Consistent report structure for consumers |
| 15-08 | State routes between federal statute and case routes | Consistent ordering pattern (12-03, 13-06, 14-06) |
| 15-08 | getSupportedStatesSchema uses unknown(false) | Rejects query garbage without needing specific params |
| 16-01 | Joi sync validate() warnings option removed | Joi's synchronous validate() does not support warnings: true; returns empty array |
| 16-03 | Per-layer scores start at 100, subtract severity-weighted penalties | Intuitive scoring model where clean = 100 and penalties degrade score |
| 16-03 | Missing layers get null scores with weight redistribution | Available layer weights normalized to sum to 1.0; missing ≠ bad |
| 16-03 | Forensic floor-drag penalty caps score at 45 | Prevents clean sub-factors from masking catastrophic failure in one area |
| 16-01 | LAYER_SCORING_FACTORS as separate export | Structured config for per-layer sub-weights rather than inline |
| 16-01 | Additional enum exports (FINDING_TYPES, OVERALL_RISK_LEVELS) | Downstream consumers need enum access without re-importing schema internals |
| 16-04 | Follow complianceAnalysisService singleton pattern with lazy Anthropic client | Tests run without API key; consistent with established codebase patterns |
| 16-04 | Return error objects instead of throwing on failure | Callers handle errors without try/catch; matches graceful degradation pattern |
| 16-04 | Extract violations/findings from consolidated report for Claude prompts | Full audit context for generating accurate, evidence-backed letters |

### Deferred Issues

None.

### Pending Todos

None.

### Blockers/Concerns

None.

### Roadmap Evolution

- Milestone v3.0 created: Forensic Analysis Engine, 8 phases (Phase 10-17)

## Session Continuity

Last session: 2026-03-11
Stopped at: Completed 16-04-PLAN.md — RESPA Dispute Letter Generator
Resume file: None — ready for 16-05-PLAN.md
