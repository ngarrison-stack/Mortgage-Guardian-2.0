# Codebase Structure

**Analysis Date:** 2026-02-26

## Directory Layout

```
Mortgage-Guardian-2.0-Clean/
├── backend-express/       # Node.js/Express REST API (primary backend)
├── frontend/              # Next.js 15 React application
├── tools/                 # Utility scripts (Python token server, icon gen)
├── MortgageGuardian/      # iOS Xcode project
├── docs/                  # Project documentation
├── scripts/               # Build/deploy shell scripts
├── .planning/             # GSD planning documents and codebase map
├── .github/               # GitHub Actions workflows
├── package.json           # Root monorepo marker (private: true)
├── CLAUDE.md              # Claude Code project instructions
├── README.md              # Project overview
├── SECURITY.md            # Security policies
└── docker-compose.yml     # Local development infrastructure
```

## Directory Purposes

**backend-express/**
- Purpose: REST API server — core business logic and integrations
- Contains: JavaScript source files, Jest tests, deployment configs
- Key files: `server.js` (entry), `api/index.js` (Vercel handler)
- Subdirectories: routes/, services/, middleware/, schemas/, utils/, __tests__/

**frontend/**
- Purpose: Next.js web application with Clerk auth
- Contains: TypeScript source, React components, Tailwind CSS
- Key files: `src/app/layout.tsx`, `src/app/page.tsx`
- Subdirectories: src/app/ (App Router pages)

**tools/**
- Purpose: Supporting utilities for development
- Contains: Python scripts for token generation and icon creation
- Subdirectories: token_server/, icon-generation/

**.planning/**
- Purpose: GSD planning documents, roadmap, and codebase analysis
- Contains: STATE.md, ROADMAP.md, PROJECT.md, phase plans and summaries
- Subdirectories: phases/, codebase/

## Backend-Express Structure

```
backend-express/
├── __tests__/                    # Jest test suite
│   ├── mocks/                   # Shared mock factories
│   │   ├── mockSupabaseClient.js
│   │   ├── mockClaudeService.js
│   │   └── mockRedisClient.js
│   ├── fixtures/                # Test data fixtures
│   │   └── dbFixtures.js
│   ├── middleware/              # Middleware tests
│   │   ├── auth.test.js
│   │   └── validate.test.js
│   ├── routes/                  # Route integration tests
│   │   ├── documents-routes.test.js
│   │   ├── documents-upload-security.test.js
│   │   └── auth-integration.test.js
│   ├── services/                # Service unit tests
│   │   ├── claudeService.test.js
│   │   ├── plaidService.test.js
│   │   ├── plaidDataService.test.js
│   │   ├── documentService.test.js
│   │   ├── financialSecurityService.test.js
│   │   ├── vendorNeutralSecurityService.test.js
│   │   ├── caseFileService.test.js
│   │   └── service-integration.test.js
│   ├── utils/                   # Utility function tests
│   │   ├── fileValidation.test.js
│   │   ├── logger.test.js
│   │   └── testUtils.js
│   └── validation/              # Schema validation tests
│       └── schemas.test.js
│
├── api/                         # Vercel serverless entry
│   └── index.js                # Express app handler wrapper
│
├── middleware/                  # Express middleware
│   ├── auth.js                 # JWT verification (Supabase)
│   └── validate.js             # Joi validation factory
│
├── routes/                      # API route handlers
│   ├── claude.js               # POST /v1/ai/claude/*
│   ├── plaid.js                # POST /v1/plaid/*
│   ├── documents.js            # POST/GET/DELETE /v1/documents/*
│   └── health.js               # GET /health, GET /
│
├── schemas/                     # Joi validation schemas
│   ├── claude.js               # analyzeSchema
│   ├── plaid.js                # linkToken, exchange, accounts, transactions
│   └── documents.js            # upload, list, get, delete schemas
│
├── services/                    # Business logic
│   ├── claudeService.js        # Anthropic Claude integration (singleton)
│   ├── plaidService.js         # Plaid API integration (singleton)
│   ├── plaidDataService.js     # Plaid data retrieval (singleton)
│   ├── mockPlaidService.js     # Mock Plaid for dev/testing
│   ├── caseFileService.js      # Case file CRUD + document association (singleton)
│   ├── documentService.js      # Supabase document storage (singleton)
│   ├── financialSecurityService.js    # Re-export facade
│   ├── vendorNeutralSecurityService.js # Re-export facade
│   ├── financialSecurity/      # Refactored: bank-level security
│   │   ├── index.js            # Assembles class from sub-modules
│   │   ├── config.js           # Shared deps (optional AWS, Redis)
│   │   ├── encryption.js       # AES-GCM encryption methods
│   │   ├── credentials.js      # Credential validation
│   │   ├── validation.js       # Data validation rules
│   │   ├── audit.js            # Audit logging
│   │   └── helpers.js          # MFA/TOTP helpers
│   └── vendorNeutralSecurity/  # Refactored: platform-agnostic security
│       ├── index.js            # Re-exports all classes
│       ├── service.js          # Main service class
│       ├── encryptionProviders.js  # Native, Vault, HSM providers
│       ├── secretManagers.js   # Filesystem, DB, K8s, Docker, Env
│       ├── sessionManagers.js  # In-Memory, Redis session mgmt
│       ├── auditLog.js         # ImmutableAuditLog
│       ├── zeroKnowledgeAuth.js # Zero-knowledge auth protocols
│       └── middleware.js       # Security middleware factory
│
├── utils/                       # Shared utilities
│   ├── logger.js               # Winston structured logging
│   └── fileValidation.js       # MIME validation, filename sanitization
│
├── migrations/                  # Database migration scripts
│   ├── 001_plaid_tables.sql    # Plaid table schemas
│   ├── 002_case_files_and_classifications.sql  # Case files + doc classifications
│   └── README.md
│
├── docs/                        # API documentation
│   ├── PLAID_API.md
│   ├── PLAID_QUICK_START.md
│   └── PLAID_SECURITY.md
│
├── server.js                    # Express app initialization (main entry)
├── jest.config.js              # Jest configuration (90% coverage)
├── package.json                # Dependencies and scripts
├── package-lock.json           # Dependency lockfile
├── vercel.json                 # Vercel deployment config
├── railway.toml                # Railway deployment config
├── Dockerfile                  # Docker containerization
└── Procfile                    # Heroku/Railway process definition
```

## Key File Locations

**Entry Points:**
- `backend-express/server.js` - Express server (dev + Railway)
- `backend-express/api/index.js` - Vercel serverless handler
- `frontend/src/app/layout.tsx` - Next.js root layout

**Configuration:**
- `backend-express/jest.config.js` - Test runner config
- `backend-express/vercel.json` - Vercel deployment
- `backend-express/package.json` - Dependencies, scripts, engines
- `frontend/next.config.ts` - Next.js configuration

**Core Logic:**
- `backend-express/services/claudeService.js` - AI document analysis
- `backend-express/services/plaidService.js` - Bank integration
- `backend-express/services/documentService.js` - Document storage
- `backend-express/services/caseFileService.js` - Case file CRUD operations (v3.0)
- `backend-express/services/ocrService.js` - Hybrid PDF text/Vision OCR extraction (v3.0)
- `backend-express/services/classificationService.js` - AI-powered forensic document classification (v3.0)
- `backend-express/services/documentPipelineService.js` - Document intake pipeline orchestration (v3.0)
- `backend-express/middleware/auth.js` - JWT authentication

**Testing:**
- `backend-express/__tests__/` - All test files (mirror src structure)
- `backend-express/__tests__/mocks/` - Mock service factories
- `backend-express/__tests__/utils/testUtils.js` - Test helpers

## Naming Conventions

**Files:**
- `camelCase.js` for services: `claudeService.js`, `plaidService.js`
- `camelCase.js` for routes: `claude.js`, `plaid.js`, `documents.js`
- `camelCase.js` for middleware: `auth.js`, `validate.js`
- `*.test.js` for tests: `claudeService.test.js`

**Directories:**
- `camelCase` for refactored modules: `financialSecurity/`, `vendorNeutralSecurity/`
- `lowercase` for categories: `routes/`, `services/`, `middleware/`, `utils/`
- `__tests__/` with double underscores for test root

**Special Patterns:**
- `index.js` for barrel exports in refactored modules
- `mock*.js` prefix for mock service classes
- `*Service.js` suffix for all service files

## Where to Add New Code

**New API Endpoint:**
- Route handler: `backend-express/routes/{domain}.js`
- Schema: `backend-express/schemas/{domain}.js`
- Register in: `backend-express/server.js` (app.use)
- Tests: `backend-express/__tests__/routes/{domain}.test.js`

**New Service:**
- Simple: `backend-express/services/{name}Service.js` (singleton pattern)
- Complex: `backend-express/services/{name}/` directory with `index.js` barrel
- Tests: `backend-express/__tests__/services/{name}Service.test.js`

**New Middleware:**
- Implementation: `backend-express/middleware/{name}.js`
- Apply in: `backend-express/server.js`
- Tests: `backend-express/__tests__/middleware/{name}.test.js`

**New Utility:**
- Implementation: `backend-express/utils/{name}.js`
- Tests: `backend-express/__tests__/utils/{name}.test.js`

## Special Directories

**coverage/**
- Purpose: Jest coverage reports (HTML, LCOV)
- Source: Generated by `npm run test:coverage`
- Committed: No (gitignored)

**.planning/**
- Purpose: GSD planning infrastructure
- Source: Created by `/gsd:new-project` and updated during work
- Committed: Yes

---

*Structure analysis: 2026-02-26*
*Update when directory structure changes*
