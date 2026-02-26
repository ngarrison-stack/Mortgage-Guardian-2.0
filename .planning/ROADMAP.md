# Roadmap: Mortgage Guardian 2.0 - Production Hardening

## Overview

Transform the Mortgage Guardian 2.0 MVP from a working prototype into a production-ready system through comprehensive security hardening, test coverage, and maintainability improvements. The journey progresses from establishing testing infrastructure, through authentication and validation layers, to service quality improvements with refactoring and structured logging. Each phase delivers a complete, verifiable security or quality enhancement.

## Domain Expertise

None (general Node.js/Express backend hardening)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation & Testing Infrastructure** - Establish Jest testing framework and utilities
- [x] **Phase 2: Authentication Layer** - Enforce JWT authentication across all API routes
- [x] **Phase 3: Input Validation Framework** - Implement Joi validation at all API boundaries
- [x] **Phase 4: Document Upload Security** - Secure file uploads with validation and scanning
- [x] **Phase 5: Core Service Tests** - Test coverage for Claude AI and Plaid integrations
- [x] **Phase 6: Document Processing Tests** - Test coverage for document workflows
- [x] **Phase 7: Service Refactoring** - Break down large services into maintainable modules
- [x] **Phase 8: Structured Logging** - Replace console.log with Winston structured logging
- [x] **Phase 9: Dependency Security** - Fix npm audit vulnerabilities (90 Dependabot alerts → 0)

## Phase Details

### Phase 1: Foundation & Testing Infrastructure
**Goal**: Establish comprehensive testing infrastructure with Jest, testing utilities, and foundational patterns for all subsequent test development
**Depends on**: Nothing (first phase)
**Research**: Unlikely (Jest is standard, patterns well-established)
**Plans**: 3-5 plans

Plans:
- [x] 01-01: Jest configuration with TypeScript support and coverage reporting
- [x] 01-02: Testing utilities (mocks for Supabase, Plaid, Claude AI, Redis)
- [x] 01-03: Integration test patterns and database test fixtures

### Phase 2: Authentication Layer
**Goal**: Enforce JWT authentication on all `/v1/` API routes using Supabase Auth, protecting sensitive financial endpoints
**Depends on**: Phase 1 (testing infrastructure for auth tests)
**Research**: Unlikely (Supabase Auth already integrated, JWT patterns established)
**Plans**: 3 plans

Plans:
- [x] 02-01: JWT middleware with token validation and error handling
- [x] 02-02: Protected route enforcement across all `/v1/` endpoints
- [x] 02-03: Authentication tests (valid tokens, expired tokens, missing tokens)

### Phase 3: Input Validation Framework
**Goal**: Implement Joi schema validation at all API boundaries with consistent error responses
**Depends on**: Phase 2 (auth must be in place before validating authenticated requests)
**Research**: Unlikely (Joi already in dependencies, validation patterns standard)
**Plans**: 5 plans

Plans:
- [x] 03-01: Joi validation middleware with error response formatting
- [x] 03-02: Document upload endpoint schemas (file metadata, user context)
- [x] 03-03: Plaid endpoint schemas (tokens, account IDs, date ranges)
- [x] 03-04: Claude AI endpoint schemas (document content, analysis parameters)
- [x] 03-05: Validation tests (valid inputs, invalid inputs, edge cases)

### Phase 4: Document Upload Security
**Goal**: Secure document uploads with file type validation, size limits, and malware scanning
**Depends on**: Phase 3 (validation framework must exist for file validation)
**Research**: Likely (malware scanning integration decision needed)
**Research topics**: ClamAV vs VirusTotal API vs AWS S3 malware scanning, file magic number validation libraries
**Plans**: 3-5 plans

Plans:
- [x] 04-01: File type validation (MIME type + magic number verification)
- [x] 04-02: Enhanced size limits and content sanitization
- [x] 04-03: Malware scanning integration (chosen solution from research)
- [x] 04-04: File upload security tests

### Phase 5: Core Service Tests
**Goal**: Achieve 90%+ test coverage for Claude AI analysis, Plaid integration, financial security, and data persistence services
**Depends on**: Phase 1 (testing utilities for service mocks)
**Research**: Unlikely (testing established services with known patterns)
**Plans**: 5 plans

Plans:
- [x] 05-01: Claude AI service tests (analyzeDocument, prompt building, error handling)
- [x] 05-02: Plaid service tests (API methods, webhook verification, helpers, mock fallback)
- [x] 05-03: Financial security service tests (encryption, credentials, compliance, audit)
- [x] 05-04: Vendor-neutral security tests (native crypto, sessions, audit log, middleware)
- [x] 05-05: Data service & integration tests (plaidDataService, cross-service flows)

### Phase 6: Document Processing Tests
**Goal**: Achieve 90%+ test coverage for document upload, storage, and processing workflows
**Depends on**: Phase 1 (testing utilities), Phase 4 (secure upload patterns established)
**Research**: Unlikely (testing existing document processing logic)
**Plans**: 3-5 plans

Plans:
- [x] 06-01: documentService unit tests (all CRUD, Supabase + mock modes, error paths)
- [x] 06-02: Document route handler tests (GET list, GET single, DELETE via supertest)

### Phase 7: Service Refactoring
**Goal**: Break down 800+ line service files into focused, maintainable modules (analysis, encryption, validation per service)
**Depends on**: Phase 5, Phase 6 (tests must exist before refactoring for safety)
**Research**: Unlikely (internal refactoring with test coverage as safety net)
**Plans**: 2 plans

Plans:
- [x] 07-01: Financial security service refactoring (credential, encryption, validation, fraud, compliance, audit modules)
- [x] 07-02: Vendor neutral security service refactoring (extract 13 classes into separate files)

### Phase 8: Structured Logging
**Goal**: Replace 66+ console.log statements with Winston structured logging (consistent format, log levels, production-ready)
**Depends on**: Phase 7 (refactored services are cleaner foundation for logging)
**Research**: Unlikely (Winston already integrated, structured logging patterns standard)
**Plans**: 3-5 plans

Plans:
- [x] 08-01: Winston configuration (log levels, formats, transports)
- [x] 08-02: Replace console.log in backend services (claude, plaid, document)
- [x] 08-03: Replace console.log in route handlers and middleware
- [x] 08-04: Logging tests and production log verification

## Progress

**Execution Order:**
All phases are integers (1-8) for initial milestone.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Testing Infrastructure | 3/3 | Complete | 2026-02-20 |
| 2. Authentication Layer | 3/3 | Complete | 2026-02-20 |
| 3. Input Validation Framework | 5/5 | Complete | 2026-02-21 |
| 4. Document Upload Security | 4/4 | Complete | 2026-02-22 |
| 5. Core Service Tests | 5/5 | Complete | 2026-02-25 |
| 6. Document Processing Tests | 2/2 | Complete | 2026-02-25 |
| 7. Service Refactoring | 2/2 | Complete | 2026-02-25 |
| 8. Structured Logging | 4/4 | Complete | 2026-02-25 |

### Phase 9: Dependency Security
**Goal**: Fix npm audit vulnerabilities — remove unused dependencies, update safe patch/minor versions, evaluate major upgrades, verify clean audit
**Depends on**: Phase 8 (all production hardening complete first)
**Research**: Unlikely (dependency updates follow standard npm workflow)
**Plans**: 4 plans

Plans:
- [x] 09-01: Remove unused dependencies (multer, winston-syslog, speakeasy, rate-limiter-flexible)
- [x] 09-02: Update safe dependencies (patch/minor versions via npm update)
- [x] 09-03: Evaluate major version upgrades (Anthropic SDK 0.78, Plaid 41.x applied; Express 5.x deferred)
- [x] 09-04: Audit verification and cleanup (0 vulnerabilities across all workspaces)

## Progress

**Execution Order:**
All phases are integers (1-9).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Testing Infrastructure | 3/3 | Complete | 2026-02-20 |
| 2. Authentication Layer | 3/3 | Complete | 2026-02-20 |
| 3. Input Validation Framework | 5/5 | Complete | 2026-02-21 |
| 4. Document Upload Security | 4/4 | Complete | 2026-02-22 |
| 5. Core Service Tests | 5/5 | Complete | 2026-02-25 |
| 6. Document Processing Tests | 2/2 | Complete | 2026-02-25 |
| 7. Service Refactoring | 2/2 | Complete | 2026-02-25 |
| 8. Structured Logging | 4/4 | Complete | 2026-02-25 |
| 9. Dependency Security | 4/4 | Complete | 2026-02-25 |

**Total Plans:** 32 plans across 9 phases — ALL COMPLETE
