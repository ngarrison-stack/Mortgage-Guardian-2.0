# Roadmap: Mortgage Guardian 2.0

## Overview

Mortgage Guardian 2.0 roadmap tracking milestones from MVP hardening through forensic document analysis and lending law compliance.

## Milestones

- ✅ [v2.0 Production Hardening](milestones/v2.0-ROADMAP.md) (Phases 1-9, 32 plans) — SHIPPED 2026-02-26
- ✅ [v3.0 Forensic Analysis Engine](milestones/v3.0-ROADMAP.md) (Phases 10-17, 42 plans) — SHIPPED 2026-03-15
- ✅ [v4.0 Bug Fix & Stability Sprint](milestones/v4.0-ROADMAP.md) (Phases 18-21, 20 plans) — SHIPPED 2026-03-30
- 🚧 **v5.0 Production Readiness** — Phases 22-31 (in progress)

## Completed Milestones

<details>
<summary>v2.0 Production Hardening (Phases 1-9) — SHIPPED 2026-02-26</summary>

Transform the MVP from a working prototype into a production-ready system through comprehensive security hardening, test coverage, and maintainability improvements.

- [x] **Phase 1: Foundation & Testing Infrastructure** — 3/3 plans — 2026-02-20
- [x] **Phase 2: Authentication Layer** — 3/3 plans — 2026-02-20
- [x] **Phase 3: Input Validation Framework** — 5/5 plans — 2026-02-21
- [x] **Phase 4: Document Upload Security** — 4/4 plans — 2026-02-22
- [x] **Phase 5: Core Service Tests** — 5/5 plans — 2026-02-25
- [x] **Phase 6: Document Processing Tests** — 2/2 plans — 2026-02-25
- [x] **Phase 7: Service Refactoring** — 2/2 plans — 2026-02-25
- [x] **Phase 8: Structured Logging** — 4/4 plans — 2026-02-25
- [x] **Phase 9: Dependency Security** — 4/4 plans — 2026-02-25

**Key results:** 488 tests, 0 vulnerabilities, JWT auth on all routes, Joi validation on all endpoints, Winston logging, modular services.

Full details: [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)

</details>

<details>
<summary>v3.0 Forensic Analysis Engine (Phases 10-17) — SHIPPED 2026-03-15</summary>

Transform Mortgage Guardian from a production-hardened MVP into a litigation-grade forensic document analysis platform that processes mortgage files the way a large law firm would — intake, organize, analyze individually, cross-reference, and check against all applicable federal and state lending laws.

- [x] **Phase 10: Document Intake & Classification Pipeline** — 5/5 plans — 2026-02-27
- [x] **Phase 11: Isolated Secure Document Storage** — 5/5 plans — 2026-02-27
- [x] **Phase 12: Individual Document Analysis Engine** — 3/3 plans — 2026-02-28
- [x] **Phase 13: Cross-Document Forensic Analysis** — 6/6 plans — 2026-03-09
- [x] **Phase 14: Federal Lending Law Compliance Engine** — 6/6 plans — 2026-03-09
- [x] **Phase 15: State Lending Law Compliance Engine** — 8/8 plans — 2026-03-09
- [x] **Phase 16: Consolidated Findings & Reporting** — 6/6 plans — 2026-03-14
- [x] **Phase 17: Integration Testing & Pipeline Hardening** — 4/4 plans — 2026-03-15

**Key results:** Forensic document intake pipeline, per-user encrypted storage, individual + cross-document AI analysis, federal + 50-state compliance engine, consolidated reporting with RESPA dispute letters, end-to-end pipeline testing.

Full details: [milestones/v3.0-ROADMAP.md](milestones/v3.0-ROADMAP.md)

</details>

<details>
<summary>v4.0 Bug Fix & Stability Sprint (Phases 18-21) — SHIPPED 2026-03-30</summary>

Comprehensive bug fixing across backend, frontend, and analysis pipeline to improve reliability, accuracy, and usability. Bug fixes only — no new features.

- [x] **Phase 18: Backend API Stability** — 7/7 plans — 2026-03-18
- [x] **Phase 19: Frontend UI & State Repairs** — 3/3 plans — 2026-03-18
- [x] **Phase 20: Pipeline Accuracy** — 5/5 plans — 2026-03-18
- [x] **Phase 21: Report Generation & Integration Fixes** — 5/5 plans — 2026-03-30

**Key results:** 1,275 tests across 48 suites (zero failures), OCR accuracy gating, compliance rule precision, scoring calibration, report pipeline integrity, dual-format dispute letter support, stale test fix.

</details>

### 🚧 v5.0 Production Readiness (In Progress)

**Milestone Goal:** Get Mortgage Guardian 2.0 production-ready with codified database migrations, CI/CD automation, test coverage hardening, monitoring, security audit, and a validated deployment pipeline.

#### Phase 22: Database Migration Framework

**Goal**: Codify Supabase schema into version-controlled migration scripts with up/down support
**Depends on**: v4.0 milestone complete
**Research**: Unlikely (Supabase patterns established in codebase)
**Plans**: 3

Plans:
- [x] 22-01: Supabase CLI Setup & Schema Capture (verify CLI setup, dump remote schema) — 2026-04-01
- [x] 22-02: Migration Organization & Rollback (baseline migration, rollback, archive old migrations) — 2026-04-01
- [x] 22-03: Completeness Verification (cross-reference code, verify clean reset) — 2026-04-02

#### Phase 23: CI/CD Pipeline

**Goal**: GitHub Actions workflows for automated testing, linting, building, and deployment
**Depends on**: Phase 22
**Research**: Level 1 — Quick verification (GitHub Actions for Node.js/Next.js is well-known)
**Plans**: 3

Plans:
- [ ] 23-01: Backend CI Workflow (archive aspirational workflow, ESLint config, backend-ci.yml)
- [ ] 23-02: Frontend CI Workflow (frontend-ci.yml with build + lint)
- [ ] 23-03: PR Quality Gates & iOS Cleanup (branch protection docs, iOS CI fix, verify on GitHub)

#### Phase 24: Test Coverage Hardening

**Goal**: Close branch coverage gap to 90% target across all critical paths
**Depends on**: Phase 23
**Research**: Unlikely (internal testing patterns established in v2.0-v4.0)
**Plans**: TBD

Plans:
- [ ] 24-01: TBD (run /gsd:plan-phase 24 to break down)

#### Phase 25: Environment & Secrets Management

**Goal**: Production environment validation, secrets rotation strategy, and secure configuration management
**Depends on**: Phase 24
**Research**: Likely (secrets management tooling, rotation strategies)
**Research topics**: Secrets management approaches for Railway/Vercel, env validation libraries, rotation patterns
**Plans**: TBD

Plans:
- [ ] 25-01: TBD (run /gsd:plan-phase 25 to break down)

#### Phase 26: Container & Deploy Infrastructure

**Goal**: Production Docker configurations, deployment scripts, and infrastructure automation
**Depends on**: Phase 25
**Research**: Likely (Docker production optimization, hosting platform specifics)
**Research topics**: Docker multi-stage builds for Node.js, Railway/Vercel production configs, container security scanning
**Plans**: TBD

Plans:
- [ ] 26-01: TBD (run /gsd:plan-phase 26 to break down)

#### Phase 27: Monitoring & Observability

**Goal**: Health check endpoints, error tracking integration, alerting, and operational dashboards
**Depends on**: Phase 26
**Research**: Likely (error tracking services, APM tools)
**Research topics**: Sentry/Datadog integration, structured log aggregation, uptime monitoring services
**Plans**: TBD

Plans:
- [ ] 27-01: TBD (run /gsd:plan-phase 27 to break down)

#### Phase 28: Performance & Load Testing

**Goal**: Benchmarks, load tests, and bottleneck optimization to meet performance targets
**Depends on**: Phase 27
**Research**: Likely (load testing tools, benchmarking approaches)
**Research topics**: Artillery/k6 for API load testing, performance profiling Node.js, response time baseline establishment
**Plans**: TBD

Plans:
- [ ] 28-01: TBD (run /gsd:plan-phase 28 to break down)

#### Phase 29: Security Audit & Compliance Review

**Goal**: Final OWASP top-10 review, dependency audit, and security compliance verification
**Depends on**: Phase 28
**Research**: Unlikely (OWASP patterns established, security hardening done in v2.0)
**Plans**: TBD

Plans:
- [ ] 29-01: TBD (run /gsd:plan-phase 29 to break down)

#### Phase 30: Production Deployment Dry Run

**Goal**: Deploy to staging environment, run end-to-end smoke tests, validate full pipeline
**Depends on**: Phase 29
**Research**: Unlikely (internal deployment steps, existing infrastructure)
**Plans**: TBD

Plans:
- [ ] 30-01: TBD (run /gsd:plan-phase 30 to break down)

#### Phase 31: Operations Runbooks

**Goal**: Incident response procedures, deployment guides, and troubleshooting documentation
**Depends on**: Phase 30
**Research**: Unlikely (internal documentation)
**Plans**: TBD

Plans:
- [ ] 31-01: TBD (run /gsd:plan-phase 31 to break down)

---

### v4.0 Bug Fix & Stability Sprint — SHIPPED 2026-03-30

**Milestone Goal:** Comprehensive bug fixing across backend, frontend, and analysis pipeline to improve reliability, accuracy, and usability. Bug fixes only — no new features.

#### Phase 18: Backend API Stability

**Goal**: Debug and fix Express API endpoint failures, optimize slow responses, fix connection drops, timeouts, and resource exhaustion issues
**Depends on**: v3.0 milestone complete
**Research**: Unlikely (internal patterns, existing Express/Node stack)
**Plans**: 7

Plans:
- [x] 18-01: Server Lifecycle & Process Stability (graceful shutdown, uncaught exception handlers)
- [x] 18-02: CORS & Webhook Security (CORS credentials fix, webhook signature enforcement)
- [x] 18-03: Webhook Handler Bug Fixes (transaction .success field bug, handler return values)
- [x] 18-04: Document Route Security & Correctness (user ID isolation fix, HTTP status codes)
- [x] 18-05: Memory Leak Prevention (pipeline state cleanup, mock Map cleanup)
- [x] 18-06: Startup Validation & Config (env var validation, Vercel handler fix)
- [x] 18-07: Request Tracing (request ID middleware, logger propagation)

#### Phase 19: Frontend UI & State Repairs

**Goal**: Fix broken Next.js build, environment security vulnerabilities, layout/visual bugs, and replace boilerplate scaffolding with proper Mortgage Guardian branding
**Depends on**: Phase 18
**Research**: Unlikely (internal patterns, existing Next.js/React stack)
**Plans**: 3

Plans:
- [x] 19-01: Fix Build Failure & Dependencies (lodash.curry/PostCSS crash)
- [x] 19-02: Environment Security & Configuration (secrets removal, API rewrites)
- [x] 19-03: Layout, Metadata & Page Fixes (branding, CSS, boilerplate replacement)

#### Phase 20: Pipeline Accuracy

**Goal**: Tune document classification accuracy, fix OCR text extraction failures, refine federal and state compliance rules to reduce false positive violation flagging and incorrect statutory citations
**Depends on**: Phase 19
**Research**: Likely (OCR accuracy benchmarking, compliance rule false positive analysis, classification threshold tuning)
**Research topics**: OCR accuracy metrics and tuning approaches, compliance rule precision/recall analysis, document classification confidence thresholds
**Plans**: 5

Plans:
- [x] 20-01: OCR Text Extraction Fixes (threshold + dynamic confidence scoring)
- [x] 20-02: Classification Confidence Gating (threshold filter + hint handling)
- [x] 20-03: Compliance Rule Matching Precision (word boundaries + field patterns)
- [x] 20-04: Scoring & Deduplication Fixes (dedup preservation + penalty calibration)
- [x] 20-05: Risk Threshold Calibration (thresholds + classification→scoring pipeline)

#### Phase 21: Report Generation & Integration Fixes

**Goal**: Fix incorrect report aggregation, missing findings, formatting issues in consolidated reports, and cross-system verification to ensure end-to-end data integrity
**Depends on**: Phase 20
**Research**: Unlikely (internal aggregation patterns, existing report pipeline)
**Plans**: 5

Plans:
- [x] 21-01: Confidence Score Schema & Classification Pipeline (null layer fix + classificationConfidence wiring)
- [x] 21-02: Dispute Letter Schema & Field Alignment (content/recipientInfo schema fix + dual-format field reads)
- [x] 21-03: Report Assembly Finding Preservation (anomaly details in documentAnalysis + count consistency check)
- [x] 21-04: End-to-End Integrity Tests (report pipeline tests + letter-from-stored-report tests)
- [x] 21-05: Milestone Verification & Completion (full test suite + v4.0 milestone closure)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation & Testing Infrastructure | v2.0 | 3/3 | Complete | 2026-02-20 |
| 2. Authentication Layer | v2.0 | 3/3 | Complete | 2026-02-20 |
| 3. Input Validation Framework | v2.0 | 5/5 | Complete | 2026-02-21 |
| 4. Document Upload Security | v2.0 | 4/4 | Complete | 2026-02-22 |
| 5. Core Service Tests | v2.0 | 5/5 | Complete | 2026-02-25 |
| 6. Document Processing Tests | v2.0 | 2/2 | Complete | 2026-02-25 |
| 7. Service Refactoring | v2.0 | 2/2 | Complete | 2026-02-25 |
| 8. Structured Logging | v2.0 | 4/4 | Complete | 2026-02-25 |
| 9. Dependency Security | v2.0 | 4/4 | Complete | 2026-02-25 |
| 10. Document Intake & Classification Pipeline | v3.0 | 5/5 | Complete | 2026-02-27 |
| 11. Isolated Secure Document Storage | v3.0 | 5/5 | Complete | 2026-02-27 |
| 12. Individual Document Analysis Engine | v3.0 | 3/3 | Complete | 2026-02-28 |
| 13. Cross-Document Forensic Analysis | v3.0 | 6/6 | Complete | 2026-03-09 |
| 14. Federal Lending Law Compliance Engine | v3.0 | 6/6 | Complete | 2026-03-09 |
| 15. State Lending Law Compliance Engine | v3.0 | 8/8 | Complete | 2026-03-09 |
| 16. Consolidated Findings & Reporting | v3.0 | 6/6 | Complete | 2026-03-14 |
| 17. Integration Testing & Pipeline Hardening | v3.0 | 4/4 | Complete | 2026-03-15 |
| 18. Backend API Stability | v4.0 | 7/7 | Complete | 2026-03-18 |
| 19. Frontend UI & State Repairs | v4.0 | 3/3 | Complete | 2026-03-18 |
| 20. Pipeline Accuracy | v4.0 | 5/5 | Complete | 2026-03-18 |
| 21. Report Generation & Integration Fixes | v4.0 | 5/5 | Complete | 2026-03-30 |
| 22. Database Migration Framework | v5.0 | 3/3 | Complete | 2026-04-02 |
| 23. CI/CD Pipeline | v5.0 | 0/3 | Planned | - |
| 24. Test Coverage Hardening | v5.0 | 0/? | Not started | - |
| 25. Environment & Secrets Management | v5.0 | 0/? | Not started | - |
| 26. Container & Deploy Infrastructure | v5.0 | 0/? | Not started | - |
| 27. Monitoring & Observability | v5.0 | 0/? | Not started | - |
| 28. Performance & Load Testing | v5.0 | 0/? | Not started | - |
| 29. Security Audit & Compliance Review | v5.0 | 0/? | Not started | - |
| 30. Production Deployment Dry Run | v5.0 | 0/? | Not started | - |
| 31. Operations Runbooks | v5.0 | 0/? | Not started | - |

**Total Plans:** 32 plans across 9 phases (v2.0) — ALL COMPLETE | 42 plans across 8 phases (v3.0) — ALL COMPLETE | 20 plans across 4 phases (v4.0) — ALL COMPLETE | v5.0 in progress
