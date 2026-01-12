# Mortgage Guardian 2.0 - Production Hardening

## What This Is

Mortgage Guardian 2.0 is a multi-platform mortgage servicing audit system that uses AI-powered document analysis (Claude AI) to detect errors in mortgage loan servicing, cross-references with bank data via Plaid, and generates RESPA-compliant dispute letters. Currently an MVP with Express backend, Next.js frontend, and iOS mobile app - now being hardened for production deployment with comprehensive security, testing, and maintainability improvements.

## Core Value

The platform must reliably and securely analyze mortgage documents to detect servicing errors with high confidence, cross-verify against actual bank transaction data, and protect sensitive financial information throughout the process.

## Requirements

### Validated

<!-- Shipped functionality confirmed working in existing codebase -->

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

### Active

<!-- Current hardening scope - building toward production readiness -->

- [ ] JWT authentication enforcement - Require authentication for all `/v1/` API routes using Supabase Auth
- [ ] Critical path test coverage - Automated tests for Claude AI analysis, Plaid integration, document processing flows
- [ ] Input validation framework - Joi schema validation at all API boundaries with consistent error responses
- [ ] File upload security - Type validation, size limits, malware scanning for document uploads
- [ ] Service layer refactoring - Break down large services (800+ lines) into focused, maintainable modules
- [ ] Structured logging system - Replace 66+ console.log statements with Winston structured logging

### Out of Scope

<!-- Explicit boundaries to prevent scope creep -->

- New feature development - No additional document types, AI capabilities, or user-facing features — Focus is pure hardening, not expansion
- Performance optimization (beyond security) - Not addressing caching strategies or database query optimization in this phase — Separate performance milestone
- DevOps automation - No CI/CD pipeline setup or deployment automation beyond basic configs — Can be added after hardening complete
- Monitoring and observability - No error tracking (Sentry) or analytics integration — Post-hardening enhancement
- Frontend refactoring - Next.js app stays as-is unless changes needed for authentication flow — Backend-focused hardening

## Context

**Technical Environment:**
- Node.js 20+ backend with Express 4.18
- TypeScript 5.9 enabled but minimal type annotations currently
- Supabase PostgreSQL for data, Redis for caching
- Anthropic Claude AI (SDK v0.68) and Plaid (v39.1) integrations
- Vercel/Railway deployment targets (serverless-ready)

**Current State (from codebase analysis):**
- Zero automated tests - Placeholder test scripts only
- No API authentication - All `/v1/` endpoints publicly accessible
- Manual validation - Inconsistent input checking across routes
- Large service files - `financialSecurityService.js` (848 lines), `vendorNeutralSecurityService.js` (827 lines)
- Console.log debugging - 66+ debug statements throughout backend
- 50MB upload limit - No file type or content validation

**Why Hardening Matters:**
- Handles sensitive financial data (bank accounts, mortgage documents, PII)
- Production deployment requires security guarantees and reliability
- Maintainability essential for solo developer working with AI assistance
- Test coverage enables safe refactoring and feature additions

**Existing Infrastructure to Leverage:**
- Joi 18.0.1 already in dependencies (unused)
- Winston 3.11.0 already integrated (underutilized)
- jsonwebtoken 9.0.2 + Supabase Auth ready for enforcement
- Express middleware patterns established

## Constraints

- **No breaking changes**: Existing iOS app and frontend must continue working during incremental rollout — Can add authentication gradually without disruption
- **Full flexibility otherwise**: No timeline pressure, tech stack locked, or deployment constraints — Optimize for best practices and long-term quality

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| JWT authentication for all /v1/ routes | Supabase Auth already integrated, standard bearer token pattern, protects sensitive financial data | — Pending |
| Jest as test framework | Industry standard, excellent TypeScript support, rich ecosystem, integrates with existing Node.js tooling | — Pending |
| Joi for input validation | Already in dependencies, declarative schema approach, comprehensive validation rules | — Pending |
| Winston structured logging | Already integrated, production-grade, supports multiple transports (console, file, syslog) | — Pending |
| Service refactoring by domain | Break large files into focused modules: analysis.js, encryption.js, validation.js per service | — Pending |

---
*Last updated: 2026-01-12 after initialization*
