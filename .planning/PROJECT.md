# Mortgage Guardian 2.0 - Production Hardening

## What This Is

Mortgage Guardian 2.0 is a production-hardened multi-platform mortgage servicing audit system that uses AI-powered document analysis (Claude AI) to detect errors in mortgage loan servicing, cross-references with bank data via Plaid, and generates RESPA-compliant dispute letters. Express backend with comprehensive security layers, Next.js frontend, and iOS mobile app — deployed with JWT auth, input validation, file security, structured logging, and 488 automated tests.

## Core Value

The platform must reliably and securely analyze mortgage documents to detect servicing errors with high confidence, cross-verify against actual bank transaction data, and protect sensitive financial information throughout the process.

## Requirements

### Validated

<!-- Shipped functionality confirmed working -->

- ✓ Claude AI document analysis integration - Document error detection with confidence scoring — existing
- ✓ Plaid banking integration - Bank account verification and transaction data retrieval — existing
- ✓ Document upload and storage - MinIO (local) and Supabase Storage (production) — existing
- ✓ Express REST API with versioned endpoints - `/v1/` API structure with route handlers — existing
- ✓ Next.js 15 frontend - React 19 with Clerk authentication and Tailwind CSS — existing
- ✓ Supabase PostgreSQL database - With migrations for schema management — existing
- ✓ Redis caching and rate limiting - Rate limiter (100 req/15min) and caching infrastructure — existing
- ✓ Multi-platform architecture - Decoupled Express backend + Next.js frontend + iOS app — existing
- ✓ Security headers and CORS - Helmet.js and configurable CORS middleware — existing
- ✓ Document processing pipeline - Upload, OCR/text extraction, AI analysis workflow — existing
- ✓ JWT authentication enforcement - Supabase Auth on all `/v1/` routes with Bearer token validation — v2.0
- ✓ Critical path test coverage - 488 tests across 15 suites covering Claude AI, Plaid, security, documents — v2.0
- ✓ Input validation framework - Joi schemas at all 13 API boundaries with consistent error responses — v2.0
- ✓ File upload security - Magic number validation, filename sanitization, size limits, malware scanning stub — v2.0
- ✓ Service layer refactoring - Monolithic 800+ line services split into focused domain modules — v2.0
- ✓ Structured logging system - Winston replacing 119 console.log with child logger pattern — v2.0

### Active

<!-- Next milestone scope -->

(None yet — plan next milestone)

### Out of Scope

<!-- Explicit boundaries -->

- Performance optimization (beyond security) - Not addressing caching strategies or database query optimization — Separate performance milestone
- DevOps automation - No CI/CD pipeline setup or deployment automation beyond basic configs — Can be added as next milestone
- Monitoring and observability - No error tracking (Sentry) or analytics integration — Post-hardening enhancement
- Frontend refactoring - Next.js app stays as-is unless changes needed for authentication flow — Backend-focused hardening complete

## Context

**Current State (post v2.0 hardening):**
- 488 automated tests, 15 test suites, 90%+ coverage on critical paths
- 0 npm audit vulnerabilities across all workspaces
- All `/v1/` routes JWT-authenticated via Supabase Auth
- Joi validation on all 13 API endpoint boundaries
- Winston structured logging (zero console.log in production code)
- Services refactored into focused domain modules
- File uploads validated with magic numbers and filename sanitization

**Technical Environment:**
- Node.js 20+ backend with Express 4.22.1
- Supabase PostgreSQL for data, Redis for caching
- Anthropic Claude AI (SDK v0.78) and Plaid (v41) integrations
- Vercel/Railway deployment targets (serverless-ready)
- Jest 29.x test framework with ts-jest

**Accepted Technical Debt:**
- Express 5.x deferred (0 vulns on 4.22.1, breaking changes not justified)
- file-type v16.x (ESM-only from v17+, CJS project constraint)
- Malware scanning stub only (scanFileContent() placeholder for future integration)

## Constraints

- **No breaking changes**: Existing iOS app and frontend must continue working during incremental rollout
- **Full flexibility otherwise**: No timeline pressure, tech stack locked, or deployment constraints

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| JWT authentication for all /v1/ routes | Supabase Auth already integrated, standard bearer token pattern | ✓ Good — 27 auth tests, all routes protected |
| Jest as test framework | Industry standard, excellent TypeScript support, rich ecosystem | ✓ Good — 488 tests, 15 suites |
| Joi for input validation | Already in dependencies, declarative schema approach | ✓ Good — 13 schemas, 100% validation coverage |
| Winston structured logging | Already integrated, production-grade, serverless-compatible | ✓ Good — 119 console.log replaced, silent in tests |
| Service refactoring by domain | Prototype mixin + re-export facade for backward compatibility | ✓ Good — 800+ line files split, all tests pass |
| Express 5.x deferred | 0 vulnerabilities on 4.22.1, breaking changes not justified | ⚠️ Revisit when Express 5 stabilizes |
| file-type v16 kept | ESM-only from v17+, CJS project | ⚠️ Revisit if project migrates to ESM |
| Malware scanning deferred | Serverless incompatible with ClamAV, VirusTotal async gap | ⚠️ Revisit at scale |
| Anthropic SDK 0.68→0.78 | Stable API surface, no code changes needed | ✓ Good |
| Plaid SDK 39→41 | All 9 methods unchanged | ✓ Good |

---
*Last updated: 2026-02-26 after v2.0 milestone*
