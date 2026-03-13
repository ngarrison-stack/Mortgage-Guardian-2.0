# Roadmap: Mortgage Guardian 2.0

## Overview

Mortgage Guardian 2.0 roadmap tracking milestones from MVP hardening through forensic document analysis and lending law compliance.

## Milestones

- ✅ [v2.0 Production Hardening](milestones/v2.0-ROADMAP.md) (Phases 1-9, 32 plans) — SHIPPED 2026-02-26
- 🚧 **v3.0 Forensic Analysis Engine** — Phases 10-17 (in progress)

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

### 🚧 v3.0 Forensic Analysis Engine (In Progress)

**Milestone Goal:** Transform Mortgage Guardian from a production-hardened MVP into a litigation-grade forensic document analysis platform that processes mortgage files the way a large law firm would — intake, organize, analyze individually, cross-reference, and check against all applicable federal and state lending laws.

#### Phase 10: Document Intake & Classification Pipeline

**Goal**: Build a law firm discovery-style document intake pipeline — file upload, automatic document type classification (origination, servicing, correspondence, etc.), OCR integration, and structured case file organization
**Depends on**: v2.0 milestone complete
**Research**: Likely (OCR service evaluation, document classification approaches)
**Research topics**: OCR libraries/services for mortgage docs, ML-based document classification, case file data model design
**Plans**: TBD

Plans:
- [x] 10-01: Case File Data Model & Service
- [x] 10-02: Server-Side OCR Service
- [x] 10-03: Document Classification Engine
- [x] 10-04: Enhanced Intake Pipeline
- [x] 10-05: Intake API Routes & Verification

#### Phase 11: Isolated Secure Document Storage

**Goal**: Implement per-user isolated document storage with separate S3/Supabase Storage paths, Supabase RLS policies on all document metadata tables, and per-user encryption keys for documents at rest
**Depends on**: Phase 10
**Research**: Likely (per-user encryption key management, KMS integration, Supabase Storage isolation patterns)
**Research topics**: AWS KMS or Supabase Vault for per-user keys, RLS policy design for document tables, storage path isolation patterns
**Plans**: TBD

Plans:
- [x] 11-01: Database Row Level Security Migration
- [x] 11-02: Storage Path Isolation & Enforcement
- [x] 11-03: Per-User Encryption Service (TDD)
- [x] 11-04: Document Encryption Integration
- [x] 11-05: Security Integration Testing & Verification

#### Phase 12: Individual Document Analysis Engine

**Goal**: Build single-document Claude AI analysis — extract key data points (dates, amounts, terms, parties, account numbers), identify anomalies, flag missing information, and score document completeness with structured analysis reports
**Depends on**: Phase 11
**Research**: Likely (Claude AI structured output, prompt engineering for mortgage document analysis, context window management)
**Research topics**: Claude API structured output/tool use for data extraction, domain-specific prompt design, analysis report schema
**Plans**: 3

Plans:
- [x] 12-01: Analysis Report Schema & Document Field Definitions
- [x] 12-02: Document Analysis Service & Unit Tests
- [x] 12-03: Pipeline Integration & Analysis API

#### Phase 13: Cross-Document Forensic Analysis

**Goal**: Build multi-document comparison engine — Claude compares documents against each other for discrepancies, contradictions, and timeline violations; cross-references against Plaid bank transaction data for payment discrepancies, misapplied payments, escrow errors, and fee irregularities
**Depends on**: Phase 12
**Research**: Likely (multi-document context management with Claude, Plaid transaction API for cross-referencing, forensic analysis patterns)
**Research topics**: Claude multi-turn analysis for large document sets, Plaid transactions API extensions, discrepancy detection algorithms
**Plans**: 6

Plans:
- [x] 13-01: Cross-Document Analysis Schema & Comparison Configuration
- [x] 13-02: Document Data Aggregation & Comparison Pairs (TDD)
- [x] 13-03: Cross-Document Claude AI Comparison Service
- [x] 13-04: Plaid Transaction Cross-Reference Service (TDD)
- [x] 13-05: Forensic Analysis Orchestrator
- [x] 13-06: Cross-Document API Routes, Integration Tests & Verification

#### Phase 14: Federal Lending Law Compliance Engine

**Goal**: Build compliance checking against all major federal mortgage statutes — RESPA, TILA/Regulation Z, ECOA, FDCPA, SCRA, HMDA, Dodd-Frank/CFPB rules — mapping detected issues to specific statutory violations with citation references
**Depends on**: Phase 13
**Research**: Likely (federal lending law requirements, violation patterns, citation databases, compliance rule encoding)
**Research topics**: RESPA Section 6/8/10 requirements, TILA disclosure rules, FDCPA collection practices, SCRA interest rate caps, CFPB servicing rules (Reg X), statutory citation format
**Plans**: 6

Plans:
- [x] 14-01: Compliance Report Schema & Federal Violation Taxonomy
- [x] 14-02: Federal Statute Rule Definitions & Document-Statute Mapping
- [x] 14-03: Compliance Rule Engine (TDD)
- [x] 14-04: Claude AI Compliance Analysis Service & Tests
- [x] 14-05: Compliance Orchestrator & Tests
- [x] 14-06: Compliance API Routes, Integration Tests & Verification

#### Phase 15: State Lending Law Compliance Engine

**Goal**: Extend compliance engine with state-specific mortgage servicing regulations for all 50 states — jurisdiction detection, state-specific violation mapping, and state statutory citation references
**Depends on**: Phase 14
**Research**: Likely (50-state lending law survey, state-specific servicing requirements, jurisdiction determination logic)
**Research topics**: State mortgage servicing acts (CA, NY, MA, IL, TX, FL as priority), state-specific foreclosure requirements, licensing laws, state consumer protection statutes
**Plans**: 8

Plans:
- [x] 15-01: State Compliance Schema & Jurisdiction Model
- [x] 15-02: Jurisdiction Detection Service (TDD)
- [x] 15-03: Priority State Statutes — CA, NY, TX
- [x] 15-04: Priority State Statutes — FL, IL, MA
- [x] 15-05: State Compliance Rule Mappings
- [x] 15-06: State Rule Engine Integration (TDD)
- [x] 15-07: State AI Analysis & Orchestrator Integration
- [x] 15-08: State Compliance API & Integration Tests

#### Phase 16: Consolidated Findings & Reporting

**Goal**: Build unified audit report generation — aggregate findings from individual analysis, cross-document analysis, and compliance checks into a consolidated report with confidence scoring, violation summaries, evidence linking, and RESPA-compliant dispute letter generation
**Depends on**: Phase 15
**Research**: Unlikely (internal aggregation patterns, report formatting)
**Plans**: 6

Plans:
- [x] 16-01: Consolidated Report Schema & Scoring Configuration
- [x] 16-02: Report Data Aggregation Service (TDD)
- [x] 16-03: Confidence Scoring & Evidence Linking (TDD)
- [x] 16-04: RESPA Dispute Letter Generator
- [x] 16-05: Report Assembly Orchestrator
- [ ] 16-06: Reporting API Routes, Integration Tests & Verification

#### Phase 17: Integration Testing & Pipeline Hardening

**Goal**: End-to-end pipeline testing across the full document lifecycle (intake → storage → analysis → cross-reference → compliance → report), performance optimization for large document sets, and edge case handling
**Depends on**: Phase 16
**Research**: Unlikely (testing established pipeline)
**Plans**: TBD

Plans:
- [ ] 17-01: TBD

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
| 16. Consolidated Findings & Reporting | v3.0 | 5/6 | In progress | - |
| 17. Integration Testing & Pipeline Hardening | v3.0 | 0/? | Not started | - |

**Total Plans:** 32 plans across 9 phases (v2.0) — ALL COMPLETE | 8 phases planned (v3.0)
