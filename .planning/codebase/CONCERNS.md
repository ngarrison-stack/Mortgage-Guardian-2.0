# Codebase Concerns

**Analysis Date:** 2026-02-26

## Tech Debt

**Aspirational security services not integrated:**
- Issue: `services/financialSecurity/` and `services/vendorNeutralSecurity/` contain 15+ files of bank-level security features (AWS KMS, CloudHSM, Elasticsearch, zero-knowledge auth) that are never imported by any route or active service
- Why: Built speculatively for future compliance requirements
- Impact: Maintenance overhead; try-catch optional requires for packages not installed (`aws-sdk`, `rate-limiter-flexible`, `speakeasy`, `winston-syslog`, `winston-elasticsearch`)
- Fix approach: Either integrate into production code with real tests, or move to `services/_aspirational/` directory and exclude from coverage

**Webhook handlers log but don't persist:**
- Issue: `routes/plaid.js` webhook handlers (`handleTransactionWebhook`, `handleItemWebhook`) log events but don't call `plaidDataService.storeTransactions()`
- Why: Handlers written as stubs during initial development
- Impact: Real-time transaction updates from Plaid are silently ignored
- Fix approach: Implement actual data persistence in webhook handlers

**Mock service tight coupling:**
- Issue: Every Plaid method checks `useMockService` at runtime with duplicated `if (useMockService)` in 15+ methods
- Files: `services/plaidService.js`
- Why: Quick solution for dev/sandbox testing
- Impact: Hard to test real behavior; mock responses may not match real API shapes
- Fix approach: Use dependency injection or factory pattern to select service at initialization

## Known Bugs

**None confirmed at this time.**
- 488 tests passing, 0 npm audit vulnerabilities
- All 9 phases of production hardening complete

## Security Considerations

**Plaid access tokens returned to client:**
- Risk: `routes/plaid.js` returns `access_token` in exchange response; if intercepted, attacker gains persistent bank access
- Current mitigation: SSL/TLS in transit, JWT auth on endpoint
- Recommendations: Store access tokens server-side only; issue short-lived references to client

**Webhook signature verification has silent fallback:**
- Risk: `services/plaidService.js` skips signature verification if `PLAID_WEBHOOK_VERIFICATION_KEY` env var is missing, allowing forged webhook requests
- Current mitigation: Warning logged
- Recommendations: Make verification key mandatory when `NODE_ENV=production`

**CORS too permissive by default:**
- Risk: `ALLOWED_ORIGINS=*` in `.env.example` allows any domain to make authenticated requests
- Current mitigation: Works correctly when configured properly
- Recommendations: Log warning in production when CORS is set to `*`; document proper configuration

**Database tokens stored unencrypted:**
- Risk: `migrations/001_plaid_tables.sql` stores `access_token` as plaintext TEXT column
- Current mitigation: Supabase provides encryption at rest
- Recommendations: Add application-layer field encryption for sensitive tokens

**Prompt injection risk in Claude integration:**
- Risk: User-provided `documentText` is interpolated directly into Claude prompt in `services/claudeService.js`
- Current mitigation: None (Claude handles some injection resistance natively)
- Recommendations: Use separate message blocks or content type separation for user-provided text

## Performance Bottlenecks

**Large file base64 buffering:**
- Problem: Document uploads decode full base64 to in-memory buffer (up to 20MB PDFs)
- Files: `routes/documents.js`
- Measurement: Not yet measured; theoretical concern for concurrent uploads
- Cause: `Buffer.from(content, 'base64')` creates full buffer before validation
- Improvement path: Consider streaming validation for large files; monitor memory in production

## Fragile Areas

**Security services with optional dependencies:**
- Files: `services/financialSecurity/config.js`, `services/vendorNeutralSecurity/service.js`
- Why fragile: 5 packages loaded via try-catch optional requires; all resolve to `null` in current deployment
- Common failures: Code paths that assume packages exist will fail with cryptic null errors
- Safe modification: Always check `if (!Package)` before using optional packages
- Test coverage: Tested with `{ virtual: true }` mocks; 155+ tests for these services

## Scaling Limits

**Vercel serverless cold starts:**
- Current capacity: Adequate for low-moderate traffic
- Limit: Each cold start initializes Anthropic, Plaid, Supabase, Redis clients
- Symptoms at limit: Increased latency for first request after idle period
- Scaling path: Connection pooling, lazy client initialization, or move to persistent server (Railway)

**Rate limiting:**
- Current: 100 requests per 15 minutes per IP (global for all endpoints)
- Limit: Same limit for lightweight health checks and expensive document analysis
- Scaling path: Tiered rate limiting by endpoint; user-specific limits

## Dependencies at Risk

**Express 4.x:**
- Risk: Express 5.x available (5.2.1); v4 entering LTS maintenance
- Impact: No current vulnerabilities on 4.22.1
- Migration plan: Plan Express 5 upgrade as future phase; test breaking changes (error handler signatures, route handling)

**file-type 16.x:**
- Risk: Last CJS-compatible version; v17+ is ESM-only
- Impact: Can't upgrade without migrating entire backend to ES modules
- Migration plan: Monitor for security advisories; plan ESM migration if vulnerability found

**Plaid API version 2020-09-14:**
- Risk: API version is 6+ years old; Plaid has released newer versions
- Impact: May miss newer features; old versions eventually deprecated
- Migration plan: Check Plaid changelog; plan API version upgrade

## Missing Critical Features

**Backend CI/CD pipeline:**
- Problem: No GitHub Actions workflow for backend testing
- Current workaround: Tests run manually via `npm test`
- Blocks: Automated quality gates, PR checks, deployment automation
- Implementation complexity: Low (add `.github/workflows/backend-test.yml`)

**Error tracking service:**
- Problem: No Sentry, Datadog, or similar for production error monitoring
- Current workaround: Winston logs to stdout, checked manually in Vercel/Railway dashboards
- Blocks: Proactive error detection, alerting, error trend analysis
- Implementation complexity: Low-Medium (add Sentry SDK + DSN env var)

**API documentation:**
- Problem: No OpenAPI/Swagger spec; routes documented only in JSDoc comments
- Current workaround: Developers read route files directly
- Blocks: API consumers (iOS app team) need reference documentation
- Implementation complexity: Medium (add swagger-jsdoc + serve at `/api/docs`)

**Environment variable validation at startup:**
- Problem: Missing env vars cause runtime errors on first request, not at startup
- Current workaround: Health check endpoint partially validates
- Blocks: Fast failure detection after deployment
- Implementation complexity: Low (add validation in `server.js` before listen)

**Request ID correlation:**
- Problem: No unique request IDs for tracing across logs
- Current workaround: Timestamps used for rough correlation
- Blocks: Debugging production issues involving multiple service calls
- Implementation complexity: Low (add UUID middleware)

## Test Coverage Gaps

**Webhook flow end-to-end:**
- What's not tested: Full Plaid webhook receipt -> data persistence flow
- Risk: Webhook handlers silently drop data (they only log currently)
- Priority: High (functional gap, not just test gap)
- Difficulty to test: Low once handlers are implemented

**Cross-service integration:**
- What's not tested: Document upload -> Claude analysis -> Plaid cross-reference flow
- Risk: Integration issues between services could go undetected
- Priority: Medium
- Difficulty to test: Medium (requires orchestrating multiple mock services)

---

*Concerns audit: 2026-02-26*
*Update as issues are fixed or new ones discovered*
