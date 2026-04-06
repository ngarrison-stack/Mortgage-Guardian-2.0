# Codebase Concerns

**Analysis Date:** 2026-04-04

## Tech Debt

**Duplicate "version 2" files throughout codebase:**
- Issue: 10+ duplicate component files with ` 2` suffix cluttering frontend
- Files: `frontend/src/components/stats-card 2.tsx`, `sidebar 2.tsx`, `document-list 2.tsx`, `confidence-gauge 2.tsx`, `case-table 2.tsx`, `app-shell 2.tsx`, `risk-badge 2.tsx`, `letter-viewer 2.tsx`, `report-summary 2.tsx`, `case-form 2.tsx`, plus `frontend/src/components/ui 2/` directory
- Also: `supabase/migrations/20260401092448_baseline 2.sql`, `supabase/schema_dump 2.sql`, `supabase/config 2.toml`, `.claude_settings 2.json`, `.claude_settings 3.json`, `backend-express/.eslintrc 2.json`
- Why: Likely macOS Finder copy artifacts or accidental duplications
- Impact: Repository bloat, confusion about which file is canonical
- Fix approach: Delete all ` 2` and ` 3` suffixed files after confirming originals exist

**Legacy `quickstart/` directory:**
- Issue: Full Plaid quickstart reference code (1.5 MB, 83 files) not used by application
- Files: `quickstart/` directory at project root
- Why: Kept as reference during Plaid integration development
- Impact: Repository bloat, confusion about "real" implementation, uses older Plaid SDK v30 vs production v41
- Fix approach: Remove directory (already identified in `LEGACY_MODULE_REVIEW.md`)

**Empty `Mortgage-Guardian-2.0/` directory:**
- Issue: Empty legacy directory at project root
- Why: Remnant from project restructuring
- Impact: Minor confusion
- Fix approach: Remove (identified in `LEGACY_MODULE_REVIEW.md`)

**Large service files needing modularization:**
- Issue: Several service files exceed 600+ lines
- Files:
  - `backend-express/services/documentAnalysisService.js` (803 lines)
  - `backend-express/services/documentPipelineService.js` (784 lines)
  - `backend-express/services/complianceRuleEngine.js` (756 lines)
  - `backend-express/services/complianceAnalysisService.js` (663 lines)
  - `backend-express/services/consolidatedReportService.js` (657 lines)
- Why: Complex domain logic accumulated during feature development
- Impact: Harder to test individual concerns, longer context needed for modifications
- Fix approach: Extract sub-concerns into focused modules (e.g., split pipeline stages)

## Known Bugs

No known bugs identified during analysis.

## Security Considerations

**Document encryption key management:**
- Risk: `DOCUMENT_ENCRYPTION_KEY` requires manual 256-bit hex generation
- Current mitigation: `envValidator.js` validates key format on startup, `ENV-GUIDE.md` documents generation
- Files: `backend-express/services/documentEncryptionService.js`, `backend-express/utils/envValidator.js`
- Recommendations: Consider key rotation strategy documentation

**Backend TypeScript strict mode disabled:**
- Risk: Type errors not caught at compile time in backend code
- Current mitigation: Joi validation at API boundary, Jest tests with high coverage
- File: `backend-express/tsconfig.json` (`"strict": false`)
- Recommendations: Enable strict mode incrementally (start with `strictNullChecks`)

## Performance Bottlenecks

**Large static config files loaded at startup:**
- Problem: `backend-express/config/stateStatuteTaxonomy.js` is 94KB (all 50 states)
- Files: `backend-express/config/stateStatuteTaxonomy.js`, `backend-express/config/stateComplianceRuleMappings.js`
- Measurement: Loaded once at startup, no runtime impact after
- Cause: Comprehensive state-by-state legal data
- Improvement path: Lazy-load per-state data on demand if memory becomes a concern

**Large frontend page components:**
- Problem: Analysis and report pages combine data fetching, state management, and rendering
- Files: `frontend/src/app/dashboard/cases/[caseId]/analysis/page.tsx` (457 lines), `frontend/src/app/dashboard/cases/[caseId]/report/page.tsx` (439 lines)
- Cause: Complex UI with multiple data sources
- Improvement path: Extract sub-components for each section

## Fragile Areas

**Document processing pipeline:**
- File: `backend-express/services/documentPipelineService.js`
- Why fragile: Orchestrates OCR, classification, analysis, compliance mapping in sequence
- Common failures: Claude API timeouts, PDF parsing errors on unusual formats
- Safe modification: Pipeline has stage-based architecture, modify individual stages
- Test coverage: Integration tests in `backend-express/__tests__/services/documentPipeline-integration.test.js`

**Compliance rule engine:**
- File: `backend-express/services/complianceRuleEngine.js`
- Why fragile: Maps findings to 50-state statute taxonomy with complex rule matching
- Common failures: New statute patterns not matching existing rules
- Safe modification: Add new rules to config files, test with `complianceRuleEngine.test.js`
- Test coverage: 100% statements, 85.2% branches

## Scaling Limits

**Supabase hosting:**
- Current capacity: Depends on Supabase plan tier
- Limit: Free tier has connection limits and storage caps
- Symptoms at limit: Connection errors, storage write failures
- Scaling path: Upgrade Supabase plan, add connection pooling

**Claude API rate limits:**
- Current capacity: Depends on Anthropic API tier
- Limit: Rate limits on concurrent requests
- Symptoms at limit: 429 errors during batch document processing
- Scaling path: Queue-based processing, retry with backoff (partially implemented in pipeline)

## Dependencies at Risk

**No critical dependencies at risk identified.** Major dependencies (Express, Next.js, React, Jest) are actively maintained with large ecosystems.

## Missing Critical Features

**Frontend test coverage:**
- Problem: No test framework configured for frontend
- Current workaround: Manual testing, ESLint catches some issues
- Blocks: Cannot verify component behavior automatically
- Implementation complexity: Medium (add Jest/Vitest + React Testing Library)

## Test Coverage Gaps

**Frontend has zero test coverage:**
- What's not tested: All React components, hooks, pages, API client
- Risk: UI regressions undetected, component behavior untested
- Priority: Medium (backend has 97%+ coverage, frontend is newer)
- Difficulty to test: Need to add test framework, mock Clerk auth and API client

**Type safety gap in analysis page:**
- What's not tested: Multiple `as any` casts bypass TypeScript in forensic data handling
- Files: `frontend/src/app/dashboard/cases/[caseId]/analysis/page.tsx` (lines 56-59, 143-144, 172-173, 383-384)
- Risk: Runtime type errors on forensic/compliance data structures
- Priority: Low (data comes from typed backend, but frontend doesn't validate)
- Difficulty to test: Define proper TypeScript interfaces for forensic response shape

---

*Concerns audit: 2026-04-04*
*Update as issues are fixed or new ones discovered*
