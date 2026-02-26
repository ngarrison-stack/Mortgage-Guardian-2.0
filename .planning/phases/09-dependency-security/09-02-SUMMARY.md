---
phase: 09-dependency-security
plan: 02
type: summary
---

# 09-02 Summary: Update Safe Dependencies (Patch/Minor)

## What was done

Ran `npm update` in backend-express/ to update all packages to their semver-compatible wanted versions.

**Result**: `added 16 packages, removed 36 packages, changed 56 packages, and audited 507 packages`

### Key updates applied

| Package | Before | After | Type |
|---------|--------|-------|------|
| `@supabase/supabase-js` | 2.80.0 | 2.97.0 | minor |
| `cors` | 2.8.5 | 2.8.6 | patch |
| `dotenv` | 17.2.3 | 17.3.1 | minor |
| `express` | 4.21.2 | 4.22.1 | minor |
| `ioredis` | 5.8.2 | 5.9.3 | minor |
| `joi` | 18.0.1 | 18.0.2 | patch |
| `jsonwebtoken` | 9.0.2 | 9.0.3 | patch |
| `nodemon` | 3.1.10 | 3.1.14 | patch (dev) |
| `winston` | 3.18.3 | 3.19.0 | minor |

## Test fix required

Two test suites failed initially because `jest.mock('rate-limiter-flexible')` and `jest.mock('speakeasy')` couldn't resolve the packages (removed in 09-01). Fixed by adding `{ virtual: true }` option to these mock calls.

### Files modified

- `__tests__/services/financialSecurityService.test.js` — added `{ virtual: true }` to rate-limiter-flexible and speakeasy mocks
- `__tests__/services/vendorNeutralSecurityService.test.js` — added `{ virtual: true }` to rate-limiter-flexible mock, added factory to speakeasy mock

## Verification

- **488 tests passing** (all 15 suites)
- **`npm audit`: 0 vulnerabilities** (down from 90 Dependabot alerts!)
- `npm outdated` shows only major version upgrades remaining (Express 5.x, Plaid 41.x, Anthropic SDK 0.78, file-type 21.x, Jest 30.x)

## Duration

~5 minutes
