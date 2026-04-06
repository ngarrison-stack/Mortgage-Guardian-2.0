# Security Audit Report

**Audit Date:** 2026-04-06
**Scope:** Backend Express API, Next.js Frontend, Database (Supabase)
**Methodology:** OWASP Top 10 2021, npm dependency audit, configuration review
**Audited Version:** v5.0 (Phases 29-01 through 29-03)

## Executive Summary

The Mortgage Guardian 2.0 platform underwent a comprehensive security audit covering dependency vulnerabilities, OWASP Top 10 code review, and security configuration hardening. The audit found 7 npm dependency vulnerabilities (1 critical, 3 high, 2 moderate, 1 moderate accepted), 14 source files corrupted by an OAuth token overwrite incident, and 2 information disclosure issues in the backend API. All actionable findings have been remediated. The platform's security posture is strong: JWT authentication on all API routes, AES-256-GCM encryption with per-user key derivation, Joi input validation on all endpoints, rate limiting, PII-aware logging, and comprehensive security headers via Helmet.js and Next.js. One moderate vulnerability (file-type ASF parser) remains as an accepted risk with documented rationale.

## Dependency Audit (Phase 29-01)

### Backend (backend-express)

| Vulnerability | Severity | Package | Resolution |
|---------------|----------|---------|------------|
| Prototype pollution | Critical | handlebars | Updated via npm audit fix |
| ReDoS | High | path-to-regexp | Updated via npm audit fix |
| ReDoS | High | picomatch | Updated via npm audit fix |
| ReDoS | Moderate | brace-expansion | Updated via npm audit fix |
| ASF parser infinite loop | Moderate | file-type v16 | **Accepted** (see below) |

### Frontend (frontend)

| Vulnerability | Severity | Package | Resolution |
|---------------|----------|---------|------------|
| Prototype pollution | High | flatted | Updated via npm audit fix |
| ReDoS | High | picomatch | Updated via npm audit fix |
| ReDoS | Moderate | brace-expansion | Updated via npm audit fix |

### Additional Findings

- **14 corrupted source files** were discovered and restored. Commit `1148a7c` had overwritten these files with OAuth token error text. All files were restored from commit `93c6f37` and verified with syntax checks.
- **file-type v21 (ESM-only)** was incompatible with the Jest/CJS test runner. Downgraded to v16 (CJS-compatible) which carries a moderate ASF parser vulnerability that does not affect allowed file types.

**Final state:** 0 critical, 0 high, 1 moderate (accepted) vulnerabilities.

## OWASP Top 10 Review (Phase 29-02)

### A01: Broken Access Control -- PASS

- JWT authentication (`requireAuth` middleware) enforced on all `/v1/` routes.
- Only bypass: Plaid webhook endpoint, which validates HMAC-SHA256 signatures using `crypto.timingSafeEqual`.
- All service methods filter by `req.user.id` for tenant isolation.
- Document storage paths validated to prevent directory traversal.
- Supabase Row Level Security (RLS) policies provide database-layer access control (29 policies across 9 tables).

### A02: Cryptographic Failures -- PASS

- AES-256-GCM encryption with `crypto.randomBytes(12)` initialization vectors.
- HKDF-SHA256 per-user key derivation prevents cross-user decryption.
- HSTS enabled via Helmet.js (max-age=31536000, includeSubDomains).
- Logger sanitizes 12 sensitive key patterns (tokens, secrets, passwords, API keys).

### A03: Injection -- PASS

- All database queries use Supabase query builder (parameterized queries). No raw SQL.
- No `eval()`, `Function()`, or `child_process` usage in the codebase.
- Joi validation with `stripUnknown: true` on all API endpoints removes unexpected fields.
- File upload validation uses magic number (file signature) checking, not just MIME type.

### A04: Insecure Design -- PASS

- Rate limiting: 100 requests per 15-minute window on all `/v1/` routes.
- File upload limits: 20MB for PDFs, 10MB for images, enforced at both Express body-parser and application layers.
- Joi `stripUnknown: true` prevents mass assignment attacks.
- Graceful shutdown with 10-second drain timeout prevents resource exhaustion.

### A05: Security Misconfiguration -- FIXED

Two issues found and remediated in Phase 29-02:

1. **404 route enumeration (fixed):** The 404 handler returned an `availableRoutes` array listing all 32 API endpoints to unauthenticated users. Now returns minimal `{ error: 'Not Found', message: 'Route not found' }` in production.
2. **Swagger /api-docs exposure (fixed):** Swagger UI was accessible in all environments. Now restricted to `NODE_ENV !== 'production'` only.

Additional verifications:
- Error handler masks stack traces and internal details in production.
- Helmet.js removes X-Powered-By header.
- Sandbox endpoints blocked in production.

### A06: Vulnerable and Outdated Components -- PASS (with accepted risk)

Handled in Phase 29-01. All actionable vulnerabilities resolved. One moderate vulnerability accepted (file-type ASF parser -- irrelevant to allowed file types).

### A07: Identification and Authentication Failures -- PASS

- Supabase `auth.getUser()` validates JWT expiry server-side on every request.
- Plaid webhook uses HMAC-SHA256 with `crypto.timingSafeEqual` (timing-safe comparison).
- No hardcoded secrets in source code.
- Frontend uses Clerk for authentication with format-validated keys.

### A08: Software and Data Integrity Failures -- PASS

- No unsafe deserialization (no `JSON.parse` on untrusted input without validation).
- Webhook signatures validated before payload processing.
- No user-provided code execution paths.
- Package-lock.json committed for reproducible builds.

### A09: Security Logging and Monitoring Failures -- PASS

- Authentication failures logged with request context.
- Winston logger sanitizes 12 sensitive field patterns before output.
- Sentry integration captures unhandled errors and exceptions (optional, graceful no-op when DSN not set).
- `logSecurityEvent` function for security-specific audit events.
- Request ID middleware enables log correlation across request lifecycle.

### A10: Server-Side Request Forgery (SSRF) -- PASS

- No user-controlled URLs passed to server-side HTTP clients.
- Claude AI integration receives only extracted text, not URLs.
- Plaid API uses environment-configured URLs only (sandbox/development/production).
- No URL-based file fetching from user input.

## Security Hardening (Phase 29-03)

### Backend (Helmet.js)

Verified Helmet 8.1.0 defaults provide production-grade security headers:
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `Content-Security-Policy: default-src 'none'`
- `Referrer-Policy: no-referrer`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- X-Powered-By header removed

No custom Helmet configuration needed -- defaults are secure for an API-only server.

### Backend (CORS)

CORS configuration documented with production guidance:
- `ALLOWED_ORIGINS` must be set to explicit comma-separated origins in production.
- Wildcard warning logged when `ALLOWED_ORIGINS=*` in production environment.
- `credentials: true` with spec-compliant origin echoing.

### Frontend (Next.js)

Security headers configured in `next.config.ts`:
- `X-Frame-Options: DENY` (stricter than backend SAMEORIGIN -- frontend should never be framed)
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`

## Security Controls Summary

| Control | Implementation | Status |
|---------|---------------|--------|
| Authentication | JWT via Supabase (backend), Clerk (frontend) | Active |
| Authorization | RLS policies (29 policies) + app-layer user ID filtering | Active |
| Input Validation | Joi schemas with stripUnknown (all /v1/ endpoints) | Active |
| File Validation | Magic number checking + size limits + type whitelist | Active |
| Encryption | AES-256-GCM with HKDF-SHA256 per-user key derivation | Active |
| Rate Limiting | 100 req/15min on /v1/ routes | Active |
| Security Headers | Helmet.js 8.1.0 (backend) + Next.js headers (frontend) | Active |
| Error Handling | Stack trace masking in production, generic error messages | Active |
| Logging | Winston with PII sanitization (12 sensitive patterns) | Active |
| Monitoring | Sentry integration (optional, no PII captured) | Active |
| Request Tracing | UUID request ID middleware for log correlation | Active |
| Graceful Shutdown | SIGTERM/SIGINT handling with 10s drain timeout | Active |

## Accepted Risks

### 1. file-type ASF Parser Vulnerability (Moderate)

**Risk:** file-type v16 contains a moderate infinite loop vulnerability in the ASF (Windows Media) parser.
**Rationale:** The application's file type whitelist only allows PDF, JPEG, PNG, HEIC, TIFF, and TXT. ASF/WMA files are never processed. Upgrading to file-type v22+ is not possible because it is ESM-only and incompatible with the Jest/CJS test runner.
**Mitigation:** File type whitelist enforcement prevents ASF parser from being reached.

### 2. CORS Wildcard in Development

**Risk:** `ALLOWED_ORIGINS=*` echoes back any Origin header when credentials are enabled.
**Rationale:** This is a deployment configuration concern, not a code defect. The application logs a warning when wildcard is used in production. Production deployments must set explicit origins.
**Mitigation:** Warning log in production; documented in server.js comments.

### 3. LLM Prompt Injection

**Risk:** User-uploaded document text is embedded in Claude AI prompts. Malicious document content could attempt to manipulate analysis output.
**Rationale:** This is inherent to any LLM-based document analysis system. The prompts use structured instructions that minimize injection risk. Analysis results include confidence scores that flag uncertain findings.
**Mitigation:** Structured prompts with clear role boundaries; confidence scoring; human review of findings expected.

### 4. PII in Logs (Theoretical)

**Risk:** Logger sanitizes tokens/secrets/passwords but does not regex-scan for SSN/email/phone patterns.
**Rationale:** No service in the codebase passes PII fields to Winston logger metadata. Financial data flows through Supabase (database) and encrypted storage, not through log calls.
**Mitigation:** Code review confirms no PII in log metadata; logger sanitizes 12 sensitive key patterns.

## Recommendations

### Short-term (Before Production Launch)

1. **Set explicit CORS origins** -- Configure `ALLOWED_ORIGINS` with specific production domains before deployment.
2. **Enable Supabase RLS verification** -- Run the existing RLS policy test suite against the production database to confirm all 29 policies are active.
3. **API key rotation procedure** -- Document rotation steps for Anthropic, Plaid, and Supabase keys.

### Medium-term (Post-Launch)

4. **Content Security Policy reporting** -- Add `report-uri` or `report-to` directive to CSP for monitoring violations in production.
5. **Rate limiting per-user** -- Current rate limiting is per-IP. Consider adding per-authenticated-user limits for abuse prevention.
6. **Dependency update automation** -- Configure Dependabot or Renovate for automated dependency update PRs.

### Long-term

7. **SOC 2 preparation** -- If handling institutional mortgage data, begin SOC 2 Type II audit preparation.
8. **Penetration testing** -- Commission external penetration test before processing real financial documents.
9. **WAF deployment** -- Consider a Web Application Firewall (Cloudflare, AWS WAF) for additional DDoS and bot protection.

---

*Audit conducted as Phase 29 of Mortgage Guardian 2.0 v5.0 Production Readiness milestone.*
*Methodology: Manual code review against OWASP Top 10 2021, automated npm audit, configuration inspection.*
