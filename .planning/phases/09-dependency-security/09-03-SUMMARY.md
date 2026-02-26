---
phase: 09-dependency-security
plan: 03
type: summary
---

# 09-03 Summary: Evaluate Major Version Upgrades

## Decisions

| Package | Action | Reason |
|---------|--------|--------|
| `@anthropic-ai/sdk` 0.68→0.78 | **UPGRADED** | Simple API surface (messages.create only), 488 tests pass |
| `plaid` 39→41 | **UPGRADED** | All 9 API methods work unchanged, 488 tests pass |
| `express` 4.22→5.x | **DEFERRED** | 0 vulnerabilities already (4.22.1 patched path-to-regexp). Express 5 has many breaking changes for no security gain |
| `file-type` 16→21 | **SKIP** | v17+ is ESM-only. CJS project would need full migration. Known decision from Phase 4 |
| `jest` 29→30 | **DEFERRED** | Test framework upgrade, no security benefit, risk of test behavior changes |
| Next.js 15→16 | **DEFERRED** | Frontend — too risky for a security patch, separate concern |

## Upgrades applied

### Anthropic SDK (0.68 → 0.78)

Our usage: `new Anthropic({ apiKey })` + `client.messages.create({ model, max_tokens, temperature, messages })`. This core API is stable across the 0.68→0.78 range. All tests pass without any code changes.

### Plaid SDK (39 → 41)

Our usage: `linkTokenCreate`, `itemPublicTokenExchange`, `accountsGet`, `transactionsGet`, `itemGet`, `itemWebhookUpdate`, `itemRemove`, `sandboxPublicTokenCreate`, `categoriesGet`. All 9 methods work unchanged. Tests pass without modifications.

## Verification

- 488 tests passing after each upgrade
- `npm audit`: 0 vulnerabilities maintained
- No code changes required for either SDK

## Duration

~3 minutes
