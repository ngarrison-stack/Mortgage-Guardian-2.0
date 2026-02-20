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
- [ ] **Phase 2: Authentication Layer** - Enforce JWT authentication across all API routes
- [ ] **Phase 3: Input Validation Framework** - Implement Joi validation at all API boundaries
- [ ] **Phase 4: Document Upload Security** - Secure file uploads with validation and scanning
- [ ] **Phase 5: Core Service Tests** - Test coverage for Claude AI and Plaid integrations
- [ ] **Phase 6: Document Processing Tests** - Test coverage for document workflows
- [ ] **Phase 7: Service Refactoring** - Break down large services into maintainable modules
- [ ] **Phase 8: Structured Logging** - Replace console.log with Winston structured logging

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
- [ ] 02-03: Authentication tests (valid tokens, expired tokens, missing tokens)

### Phase 3: Input Validation Framework
**Goal**: Implement Joi schema validation at all API boundaries with consistent error responses
**Depends on**: Phase 2 (auth must be in place before validating authenticated requests)
**Research**: Unlikely (Joi already in dependencies, validation patterns standard)
**Plans**: 5-7 plans

Plans:
- [ ] 03-01: Joi validation middleware with error response formatting
- [ ] 03-02: Document upload endpoint schemas (file metadata, user context)
- [ ] 03-03: Plaid endpoint schemas (tokens, account IDs, date ranges)
- [ ] 03-04: Claude AI endpoint schemas (document content, analysis parameters)
- [ ] 03-05: Validation tests (valid inputs, invalid inputs, edge cases)

### Phase 4: Document Upload Security
**Goal**: Secure document uploads with file type validation, size limits, and malware scanning
**Depends on**: Phase 3 (validation framework must exist for file validation)
**Research**: Likely (malware scanning integration decision needed)
**Research topics**: ClamAV vs VirusTotal API vs AWS S3 malware scanning, file magic number validation libraries
**Plans**: 3-5 plans

Plans:
- [ ] 04-01: File type validation (MIME type + magic number verification)
- [ ] 04-02: Enhanced size limits and content sanitization
- [ ] 04-03: Malware scanning integration (chosen solution from research)
- [ ] 04-04: File upload security tests

### Phase 5: Core Service Tests
**Goal**: Achieve 90%+ test coverage for Claude AI analysis and Plaid integration services
**Depends on**: Phase 1 (testing utilities for service mocks)
**Research**: Unlikely (testing established services with known patterns)
**Plans**: 4-6 plans

Plans:
- [ ] 05-01: Claude AI service tests (document analysis, confidence scoring, error handling)
- [ ] 05-02: Plaid service tests (token exchange, account retrieval, transaction sync)
- [ ] 05-03: Financial security service tests (encryption, PII handling)
- [ ] 05-04: Integration tests (service interactions, error propagation)

### Phase 6: Document Processing Tests
**Goal**: Achieve 90%+ test coverage for document upload, storage, and processing workflows
**Depends on**: Phase 1 (testing utilities), Phase 4 (secure upload patterns established)
**Research**: Unlikely (testing existing document processing logic)
**Plans**: 3-5 plans

Plans:
- [ ] 06-01: Document upload flow tests (multipart handling, storage)
- [ ] 06-02: OCR/text extraction tests (various document formats)
- [ ] 06-03: Document processing pipeline tests (upload → analyze → store)
- [ ] 06-04: Error handling tests (storage failures, analysis timeouts)

### Phase 7: Service Refactoring
**Goal**: Break down 800+ line service files into focused, maintainable modules (analysis, encryption, validation per service)
**Depends on**: Phase 5, Phase 6 (tests must exist before refactoring for safety)
**Research**: Unlikely (internal refactoring with test coverage as safety net)
**Plans**: 5-8 plans

Plans:
- [ ] 07-01: Financial security service refactoring (analysis.js, encryption.js, validation.js)
- [ ] 07-02: Vendor neutral security service refactoring (modular structure)
- [ ] 07-03: Document service refactoring (upload, processing, storage modules)
- [ ] 07-04: Verify all tests pass post-refactoring
- [ ] 07-05: Update imports and dependencies across codebase

### Phase 8: Structured Logging
**Goal**: Replace 66+ console.log statements with Winston structured logging (consistent format, log levels, production-ready)
**Depends on**: Phase 7 (refactored services are cleaner foundation for logging)
**Research**: Unlikely (Winston already integrated, structured logging patterns standard)
**Plans**: 3-5 plans

Plans:
- [ ] 08-01: Winston configuration (log levels, formats, transports)
- [ ] 08-02: Replace console.log in backend services (claude, plaid, document)
- [ ] 08-03: Replace console.log in route handlers and middleware
- [ ] 08-04: Logging tests and production log verification

## Progress

**Execution Order:**
All phases are integers (1-8) for initial milestone.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Testing Infrastructure | 3/3 | Complete | 2026-02-20 |
| 2. Authentication Layer | 2/3 | In progress | - |
| 3. Input Validation Framework | 0/7 | Not started | - |
| 4. Document Upload Security | 0/5 | Not started | - |
| 5. Core Service Tests | 0/6 | Not started | - |
| 6. Document Processing Tests | 0/5 | Not started | - |
| 7. Service Refactoring | 0/8 | Not started | - |
| 8. Structured Logging | 0/5 | Not started | - |

**Total Plans:** 46 plans across 8 phases
