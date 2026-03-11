---
phase: 16-consolidated-findings-reporting
plan: 04
subsystem: api
tags: [jest, tdd, respa, dispute-letter, claude-ai, qualified-written-request]

# Dependency graph
requires:
  - phase: 16-consolidated-findings-reporting
    plan: 01
    provides: consolidatedReportConfig with LETTER_TYPES, LETTER_SECTIONS
  - phase: 14-federal-lending-law-compliance
    plan: 04
    provides: complianceAnalysisService pattern (lazy Anthropic init, code fence fallback, graceful degradation)
provides:
  - disputeLetterService.js with generateDisputeLetter() for 3 RESPA letter types
affects: [16-05-report-assembly, 16-06-api-endpoint]

# Tech tracking
tech-stack:
  added: []
  patterns: [singleton-letter-service, lazy-anthropic-init, code-fence-json-fallback, graceful-degradation-on-api-failure]

key-files:
  created:
    - backend-express/services/disputeLetterService.js
    - backend-express/__tests__/services/disputeLetterService.test.js
  modified: []

key-decisions:
  - id: 16-04-001
    decision: Follow complianceAnalysisService singleton pattern with lazy Anthropic client init
    rationale: Tests run without API key; consistent with established codebase patterns
  - id: 16-04-002
    decision: Return error objects instead of throwing on failure
    rationale: Callers can handle errors without try/catch; matches graceful degradation pattern
  - id: 16-04-003
    decision: Extract violations and findings from consolidated report for inclusion in Claude prompts
    rationale: Provides Claude with full audit context for generating accurate, evidence-backed letters
---

## What was built

RESPA dispute letter generation service using Claude AI. Generates litigation-grade dispute letters in three types:

1. **Qualified Written Request (QWR)** — RESPA Section 6 (12 U.S.C. § 2605(e)), requiring 5-day acknowledgment and 30-day response
2. **Notice of Error** — 12 CFR 1024.35 (Regulation X), identifying specific error categories
3. **Request for Information (RFI)** — 12 CFR 1024.36 (Regulation X), requesting specific documents/records

## API

```js
const disputeLetterService = require('./services/disputeLetterService');

// Returns: { letterType, generatedAt, content: { subject, salutation, body, demands, legalCitations, responseDeadline, closingStatement }, recipientInfo }
// On failure: { error: true, errorMessage, letterType }
const result = await disputeLetterService.generateDisputeLetter(
  'qualified_written_request',
  consolidatedReport,
  { borrowerName: 'Jane Doe' }  // optional overrides
);
```

## Test coverage

20 tests covering:
- All 3 letter types (happy path)
- Prompt content verification (violations, servicer name, model/temperature)
- Invalid letter type, missing report, non-object report
- Claude API failure (graceful degradation)
- Unparseable and empty Claude responses
- Markdown code fence JSON extraction fallback
- Recipient info extraction with defaults
- Partial response field defaults
- Empty report handling
