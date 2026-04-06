---
phase: 29-security-audit-compliance-review
plan: 02
subsystem: security
tags: [owasp, information-disclosure, security-audit, helmet, cors]

requires:
  - phase: 29-security-audit-compliance-review
    plan: 01
    provides: clean dependency state, all files restored

provides:
  - OWASP Top 10 systematic audit results
  - Information disclosure fixes (404, error handler, Swagger)
  - Audit findings documented for 29-03

affects: [29-03-security-hardening]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: [backend-express/server.js]

key-decisions:
  - "Restrict 404 handler and /api-docs in production only -- dev DX preserved"
  - "No additional code fixes needed from OWASP audit -- existing security layers are comprehensive"
  - "CORS wildcard warning is a deployment config concern, not a code fix -- documented as accepted risk"
  - "PII logging risk is theoretical -- no service passes email/SSN/phone to logger metadata"

patterns-established: []
issues-created: []

duration: 12min
completed: 2026-04-06
---

# 29-02 Summary: OWASP Code Audit & Vulnerability Fixes

## What Was Done

### Task 1: Information Disclosure Fixes

Fixed three information disclosure vulnerabilities in `backend-express/server.js`:

1. **404 handler route enumeration** -- The 404 handler returned an `availableRoutes` array listing all 32 API endpoints, exposing the full API surface to unauthenticated users. In production mode, the response now returns only `{ error: 'Not Found', message: 'Route not found' }` with no route list, method echo, or path echo. Development mode retains the verbose response for DX.

2. **Swagger /api-docs exposure** -- The Swagger UI was served at `/api-docs` in all environments, providing detailed API documentation to anyone with network access. Now wrapped in `NODE_ENV !== 'production'` guard so it is only available in development.

3. **Error handler verification** -- Confirmed the global error handler (server.js lines 187-202) correctly masks error details in production: generic "Internal server error" message, no stack traces, no internal service names. The `formatErrorResponse` function in errorHandler.js also correctly gates debug info behind `isDevelopment`.

4. **Helmet.js verification** -- Confirmed `app.use(helmet())` is called before all routes, which removes the `X-Powered-By` header and enables security headers (HSTS, X-Content-Type-Options, X-Frame-Options, etc.).

Commit: `561a6ff fix(29-02): restrict information disclosure in production mode`

### Task 2: OWASP Top 10 Systematic Audit

Performed a comprehensive code audit against all OWASP 2021 Top 10 categories. No additional code changes were required -- the existing security layers built across v2.0-v5.0 are comprehensive.

## OWASP Top 10 Audit Results

| Category | Status | Notes |
|----------|--------|-------|
| A01 Broken Access Control | PASS | JWT auth on all /v1/ routes via `requireAuth`. Only bypass: webhook (has signature verification). All services filter by `req.user.id`. Storage path validation prevents traversal. |
| A02 Cryptographic Failures | PASS | AES-256-GCM with `crypto.randomBytes(12)` IV. HKDF-SHA256 per-user key derivation. Logger sanitizes 12 sensitive key patterns. HSTS enabled via Helmet. |
| A03 Injection | PASS | All DB queries use Supabase query builder (parameterized). No `eval()`, `Function()`, or `child_process`. Joi validation with `stripUnknown`. |
| A04 Insecure Design | PASS | Rate limiting 100 req/15min on /v1/. File upload limits (20MB PDF, 10MB images). Joi `stripUnknown: true` prevents mass assignment. |
| A05 Security Misconfiguration | FIXED | 404 route enumeration and /api-docs exposure fixed in Task 1. Sandbox endpoint already blocked in production. Helmet defaults appropriate. |
| A06 Vulnerable Components | N/A | Handled in 29-01. npm audit clean (1 accepted moderate -- irrelevant parser). |
| A07 Auth Failures | PASS | Supabase `auth.getUser()` validates JWT expiry server-side. Plaid webhook uses HMAC-SHA256 with `crypto.timingSafeEqual`. No hardcoded secrets. |
| A08 Data Integrity | PASS | No unsafe deserialization. Webhook signatures validated before payload processing. No user-provided code execution. |
| A09 Logging Failures | PASS | Auth failures logged. Logger sanitizes 12 sensitive field patterns. Sentry captures unhandled errors. `logSecurityEvent` for security-specific events. |
| A10 SSRF | PASS | No user-controlled URLs in fetch/http calls. Claude API receives only text. Plaid API uses env-configured URLs only. |

## Accepted Risks

1. **CORS wildcard in development** -- `ALLOWED_ORIGINS=*` logs a warning in production (server.js:78-80) but does not block. This is a deployment configuration concern, not a code defect. Production deployments should set explicit origins.

2. **Claude AI prompt injection** -- User document text is embedded in LLM prompts via template literals. This is inherent to any LLM-based document analysis and cannot be prevented at the code level without removing the feature. The prompts use structured instructions that minimize injection risk.

3. **PII in logs (theoretical)** -- Logger sanitizes tokens/secrets/passwords but does not regex-scan for SSN/email/phone patterns. However, no service in the codebase passes PII fields to logger metadata -- financial data flows through Supabase, not through Winston log calls.

## Commits

| Hash | Message |
|------|---------|
| `561a6ff` | fix(29-02): restrict information disclosure in production mode |

## Test Results

All 1636 tests passing across 54 test suites. Zero regressions.
