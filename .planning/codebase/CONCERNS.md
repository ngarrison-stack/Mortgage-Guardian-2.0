# Codebase Concerns

**Analysis Date:** 2026-01-12

## Tech Debt

**No test infrastructure:**
- Issue: Zero automated tests, placeholder test scripts only
- Files: `backend-express/package.json` (line 10: `"test": "echo \"No tests yet\" && exit 0"`)
- Why: Rapid MVP development prioritized shipping over testing
- Impact: No regression detection, unsafe refactoring, manual testing burden
- Fix approach: Implement Jest or Vitest, add unit tests for services, integration tests for API endpoints

**Console.log debugging in production code:**
- Issue: 66+ console.log/console.error statements throughout backend code
- Files: `backend-express/server.js`, `backend-express/routes/*.js`, services
- Why: Quick debugging during development
- Impact: Clutters production logs, no structured logging, performance overhead
- Fix approach: Replace with Winston logger calls, remove debug console.logs, keep only error logging

**Duplicate project structure:**
- Issue: `Mortgage-Guardian-2.0/` subdirectory contains duplicate/outdated codebase
- Files: Root `/Mortgage-Guardian-2.0/` directory mirrors main structure
- Why: Likely leftover from restructuring or accidental commit
- Impact: Confusion about which code is canonical, wasted repository space, maintenance burden
- Fix approach: Delete `Mortgage-Guardian-2.0/` subdirectory, verify .gitignore, clean git history

**Large service files without decomposition:**
- Issue: `financialSecurityService.js` (848 lines) and `vendorNeutralSecurityService.js` (827 lines) are very large
- Files:
  - `backend-express/services/financialSecurityService.js` (848 lines)
  - `backend-express/services/vendorNeutralSecurityService.js` (827 lines)
- Why: Feature growth without refactoring, single-file service pattern
- Impact: Hard to navigate, difficult to test individual functions, merge conflicts
- Fix approach: Split into smaller modules by responsibility (e.g., `services/security/analysis.js`, `services/security/encryption.js`)

**Mixed deployment configurations:**
- Issue: Multiple deployment targets configured (Vercel, Railway, Netlify, Render) with overlapping scripts
- Files: `backend-express/vercel.json`, `railway.json`, `railway.toml`, `deploy-*.sh` scripts
- Why: Testing different platforms, migration between providers
- Impact: Confusion about production target, maintenance burden, potential config conflicts
- Fix approach: Standardize on one deployment platform, archive unused configs, document deployment process

## Known Bugs

**No known bugs explicitly documented**
- Check: No TODO/FIXME comments found in codebase
- Recommendation: Add issue tracking (GitHub Issues) for bug reports

## Security Considerations

**API keys in environment variables:**
- Risk: API keys stored in `.env.local`, `.env.production` files (gitignored but risky)
- Files: `backend-express/.env.local`, `backend-express/.env.production`, `backend-express/.env.railway.local`
- Current mitigation: Files in .gitignore, not committed to repository
- Recommendations:
  - Use secret management service (Vercel environment variables, Railway secrets)
  - Rotate keys regularly
  - Implement key expiration
  - Audit `.env.*` files are never committed

**No input validation framework:**
- Risk: Manual validation in route handlers, inconsistent sanitization
- Files: All `backend-express/routes/*.js` files
- Current mitigation: Manual `if (!field)` checks in route handlers
- Recommendations:
  - Implement Joi schema validation (already in dependencies)
  - Create validation middleware
  - Add request schema documentation
  - Validate all user inputs at API boundary

**Large file upload limit (50MB):**
- Risk: Potential DoS via large document uploads
- Files: `backend-express/server.js` (line 38: `{ limit: '50mb' }`)
- Current mitigation: Express rate limiting (100 requests per 15 minutes)
- Recommendations:
  - Implement file size validation before processing
  - Add file type validation (allow only PDFs, images)
  - Stream large files instead of buffering
  - Consider cloud storage with presigned URLs

**No authentication middleware:**
- Risk: API endpoints have no authentication checks
- Files: All `backend-express/routes/*.js` - no auth middleware applied
- Current mitigation: None detected (JWT package present but not enforced)
- Recommendations:
  - Implement JWT verification middleware
  - Protect all `/v1/` routes with authentication
  - Add role-based access control (RBAC)
  - Document public vs protected endpoints

**Secrets visible in command-line arguments:**
- Risk: Shell scripts may expose secrets in process lists
- Files: Various `*.sh` scripts pass tokens as arguments
- Current mitigation: Scripts use environment variables mostly
- Recommendations:
  - Always read secrets from env vars or files
  - Never pass secrets as command-line arguments
  - Audit shell scripts for secret exposure

## Performance Bottlenecks

**Synchronous Claude AI calls:**
- Problem: Document analysis blocks request until AI response completes
- Files: `backend-express/routes/claude.js` (line 30+), `backend-express/services/claudeService.js`
- Measurement: Potential 10-30 second response times for large documents
- Cause: Synchronous await on Anthropic API call
- Improvement path: Implement async job queue (Bull/BullMQ with Redis), return job ID immediately, poll for results

**No caching layer:**
- Problem: Repeated Plaid API calls for same data
- Files: `backend-express/services/plaidService.js`, `backend-express/services/plaidDataService.js`
- Measurement: Unnecessary API calls, slower response times
- Cause: No caching implementation despite Redis available
- Improvement path: Implement Redis caching with TTL for Plaid transactions, bank accounts

**No database connection pooling visible:**
- Problem: Supabase client may create new connections per request
- Files: Services using Supabase (no connection pooling configuration visible)
- Measurement: Potential connection exhaustion under load
- Cause: Direct client usage without explicit pool management
- Improvement path: Verify Supabase client connection pooling, implement explicit pool if needed

## Fragile Areas

**Error handling in route handlers:**
- Files: All `backend-express/routes/*.js`
- Why fragile: Inconsistent error status codes, some errors not caught
- Common failures: Unhandled promise rejections, generic 500 errors
- Safe modification: Always wrap async handlers in try/catch, use consistent error response format
- Test coverage: None - all error paths untested

**Environment variable parsing:**
- Files: `backend-express/server.js` (lines with `parseInt(process.env.*)`)
- Why fragile: No validation of env var format, silent failures
- Common failures: Invalid number format causes NaN, missing required vars
- Safe modification: Add env var validation at startup, fail fast on missing/invalid vars
- Test coverage: None

**Multi-platform deployment configs:**
- Files: `backend-express/vercel.json`, `railway.json`, various deploy scripts
- Why fragile: Different platforms have different requirements, easy to misconfigure
- Common failures: Missing env vars on deployment, platform-specific errors
- Safe modification: Test deployments in staging before production
- Test coverage: Manual smoke tests only (`test-live-backend.sh`)

## Scaling Limits

**Stateless but no horizontal scaling config:**
- Current capacity: Single instance deployment
- Limit: CPU/memory of single container/serverless instance
- Symptoms at limit: Slow response times, timeouts, 502 errors
- Scaling path: Enable auto-scaling on Vercel/Railway, implement health checks

**Redis single instance:**
- Current capacity: Single Redis instance for rate limiting and caching
- Limit: Redis memory limit, no high availability
- Symptoms at limit: Rate limiting failures, cache misses, connection errors
- Scaling path: Upgrade to Redis cluster, implement Redis Sentinel for HA

**Supabase free tier:**
- Current capacity: Depends on Supabase plan (likely free tier)
- Limit: API rate limits, storage limits, connection limits
- Symptoms at limit: 429 rate limit errors, connection pool exhausted
- Scaling path: Upgrade Supabase plan, implement connection pooling, add caching layer

## Dependencies at Risk

**No automated dependency updates:**
- Risk: Security vulnerabilities in outdated packages
- Impact: Unpatched CVEs, compatibility issues
- Migration plan: Implement Dependabot or Renovate for automated PR generation

**@anthropic-ai/sdk rapid evolution:**
- Risk: SDK at v0.68.0, API potentially unstable (pre-1.0)
- Impact: Breaking changes in minor versions
- Migration plan: Pin to specific version, monitor release notes, test before upgrading

**Next.js 15 (recently released):**
- Risk: Next.js 15.5.4 is very new, potential stability issues
- Impact: Bugs in framework, Turbopack instability
- Migration plan: Monitor Next.js issues, consider downgrade to v14 if problems arise

## Missing Critical Features

**No audit logging:**
- Problem: No audit trail for sensitive operations (document access, bank data queries)
- Current workaround: None - no logging of who accessed what
- Blocks: Compliance requirements (SOC 2, HIPAA), security investigations
- Implementation complexity: Medium - add audit log table, middleware to capture events

**No webhook handling:**
- Problem: Plaid webhooks configured but not fully implemented
- Current workaround: Polling for updates (inefficient)
- Blocks: Real-time transaction updates, account status changes
- Implementation complexity: Low - implement webhook endpoint with signature verification

**No email notifications:**
- Problem: No way to notify users of analysis completion, alerts
- Current workaround: Users must poll API
- Blocks: User engagement, critical alerts
- Implementation complexity: Low - integrate SendGrid or similar service

**No document retention policy:**
- Problem: Uploaded documents stored indefinitely
- Current workaround: None - manual cleanup
- Blocks: Compliance (GDPR, data retention policies), storage costs
- Implementation complexity: Medium - implement TTL, automatic deletion, user-controlled retention

## Test Coverage Gaps

**All core functionality untested:**
- What's not tested: Claude AI integration, Plaid integration, document processing, all services
- Risk: Breaking changes go unnoticed, regressions in production
- Priority: High - critical business logic has zero test coverage
- Difficulty to test: Medium - requires mocking external APIs

**No integration tests:**
- What's not tested: End-to-end API flows, authentication, error handling
- Risk: Integration issues between services go undetected
- Priority: High - multi-service flows are complex and error-prone
- Difficulty to test: Medium - requires test database, mock external services

**No security tests:**
- What's not tested: SQL injection, XSS, CSRF, authentication bypass
- Risk: Security vulnerabilities go undetected
- Priority: High - financial data requires robust security
- Difficulty to test: Medium - requires security testing framework, OWASP test cases

---

*Concerns audit: 2026-01-12*
*Update as issues are fixed or new ones discovered*

**Overall Assessment:** Codebase is functional MVP with solid external integrations but lacks production hardening (tests, monitoring, security). Priority fixes: Add test infrastructure, implement authentication middleware, add audit logging.
