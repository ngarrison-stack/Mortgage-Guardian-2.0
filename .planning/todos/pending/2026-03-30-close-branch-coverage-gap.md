---
created: 2026-03-30T01:45
title: Close branch coverage gap to 90%
area: testing
files:
  - backend-express/services/documentPipelineService.js
  - backend-express/services/plaidCrossReferenceService.js
  - backend-express/services/financialSecurity/config.js
---

## Problem

Overall statement coverage is 87.6% and branch coverage is 74.4% — both below the 90% target. Gaps are concentrated in:
- `documentPipelineService.js` — 72% branch (OCR routing edge cases)
- `plaidCrossReferenceService.js` — 64% branch (bank data verification paths)
- `financialSecurity/config.js` — 0% branch (config loading branches)

## Solution

Add ~15-20 targeted tests for untested branches in the 3 gap files. Focus on:
- Pipeline OCR fallback paths and error branches
- Plaid cross-reference edge cases (missing data, partial matches)
- Config loading with different env var combinations
Should bring both statement and branch coverage above 90%.
