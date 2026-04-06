# Codebase Structure

**Analysis Date:** 2026-04-04

## Directory Layout

```
Mortgage-Guardian-2.0-Clean/
├── backend-express/        # Node.js/Express API server
├── frontend/               # Next.js 16 web application
├── supabase/               # Supabase config and migrations
├── MortgageGuardian.xcodeproj/  # iOS app Xcode project
├── MortgageGuardian/       # iOS Swift source code
├── .planning/              # Project planning documents
├── .github/                # GitHub Actions CI/CD workflows
├── docker-compose.yml      # Local dev environment (backend + frontend + Redis)
├── CLAUDE.md               # AI assistant instructions
└── ENV-GUIDE.md            # Environment variable documentation
```

## Directory Purposes

**backend-express/**
- Purpose: Express.js REST API server
- Contains: Routes, services, middleware, schemas, config, migrations, tests, load tests
- Key files: `server.js` (entry), `api/index.js` (Vercel handler), `package.json`
- Subdirectories:
  - `routes/` - API endpoint handlers (7 files: health, cases, reports, compliance, documents, claude, plaid)
  - `services/` - Business logic (43 files, ~8400 LOC)
  - `middleware/` - Cross-cutting concerns (6 files: auth, errorHandler, validation, validate, metrics, requestId)
  - `schemas/` - Joi validation schemas (9 files)
  - `config/` - Static domain config: statute taxonomies, compliance rules (9 files)
  - `migrations/` - SQL database migrations (5 active: 001-005)
  - `__tests__/` - Jest test suite (unit, integration, middleware, mocks)
  - `loadtest/` - autocannon load test suites and runner
  - `utils/` - Shared utilities (logger, envValidator, sentry, fileValidation)
  - `scripts/` - Operational scripts

**frontend/**
- Purpose: Next.js web application with Clerk auth
- Contains: App Router pages, React components, utilities, hooks
- Key files: `next.config.ts`, `tsconfig.json`, `package.json`
- Subdirectories:
  - `src/app/` - Next.js App Router pages
  - `src/components/` - Reusable React components (35+ files)
  - `src/components/ui/` - Base UI primitives (button, card, dialog, input, table, tabs, etc.)
  - `src/lib/` - Utilities (api.ts, hooks.ts, types.ts, utils.ts, env.ts, query-client.ts, sentry.ts)

**supabase/**
- Purpose: Supabase project configuration
- Contains: Migration files, config, schema dump
- Key files: `config.toml`, `migrations/20260401092448_baseline.sql`

**.planning/**
- Purpose: Project planning and tracking
- Contains: PROJECT.md, ROADMAP.md, STATE.md, phase plans/summaries
- Subdirectories: `phases/` (28 phases), `codebase/` (this document), `todos/`

## Key File Locations

**Entry Points:**
- `backend-express/server.js` - Express app initialization and startup
- `backend-express/api/index.js` - Vercel serverless handler
- `frontend/src/app/layout.tsx` - Next.js root layout
- `frontend/src/app/page.tsx` - Landing page (auth gate -> dashboard)

**Configuration:**
- `backend-express/package.json` - Backend dependencies and scripts
- `frontend/package.json` - Frontend dependencies and scripts
- `backend-express/jest.config.js` - Test runner configuration
- `frontend/tsconfig.json` - TypeScript config (strict, path alias `@/*` -> `./src/*`)
- `backend-express/tsconfig.json` - TypeScript config (ES2022, non-strict)
- `backend-express/.env.example` - Backend environment template
- `frontend/.env.example` - Frontend environment template
- `backend-express/utils/envValidator.js` - Joi-based env var validation
- `frontend/src/lib/env.ts` - Frontend env validation singleton

**Core Logic:**
- `backend-express/services/caseFileService.js` - Case CRUD
- `backend-express/services/documentPipelineService.js` - Document processing orchestration
- `backend-express/services/claudeService.js` - Claude AI integration
- `backend-express/services/documentAnalysisService.js` - AI document analysis
- `backend-express/services/complianceService.js` - Statute compliance mapping
- `backend-express/services/consolidatedReportService.js` - Report aggregation
- `backend-express/services/disputeLetterService.js` - RESPA letter generation
- `backend-express/services/forensicAnalysisService.js` - Cross-document forensics
- `backend-express/middleware/errorHandler.js` - Error classes and handler

**Testing:**
- `backend-express/__tests__/` - All backend tests
- `backend-express/__tests__/mocks/` - Mock services (Supabase, Claude, Redis, Pipeline)
- `backend-express/__tests__/integration/` - Integration tests (user isolation, security, pipeline)
- `backend-express/__tests__/middleware/` - Middleware tests (auth, validation)
- `backend-express/loadtest/suites/` - Load test suites (health, api, stress, memory)

**Documentation:**
- `CLAUDE.md` - AI assistant instructions
- `ENV-GUIDE.md` - Environment variable guide
- `DEPLOY.md` - Deployment guide (Docker Compose, Railway, Vercel)
- `backend-express/PERFORMANCE-BASELINE.md` - Load test baselines

## Naming Conventions

**Files:**
- Backend services: camelCase (`caseFileService.js`, `documentAnalysisService.js`)
- Backend routes: lowercase (`cases.js`, `reports.js`, `health.js`)
- Backend middleware: camelCase (`errorHandler.js`, `requestId.js`)
- Backend schemas: camelCase (`cases.js`, `complianceReportSchema.js`)
- Frontend components: kebab-case (`case-form.tsx`, `document-upload.tsx`, `confidence-gauge.tsx`)
- Frontend pages: `page.tsx` (Next.js convention)
- Frontend utilities: camelCase (`api.ts`, `hooks.ts`, `types.ts`)
- Tests: `*.test.js` or `*.test.ts`

**Directories:**
- Lowercase for collections: `routes/`, `services/`, `middleware/`, `schemas/`, `config/`
- kebab-case for features: `dashboard/`, `sign-in/`, `sign-up/`
- `__tests__/` for test root (Jest convention)

**Special Patterns:**
- `[caseId]` - Next.js dynamic route segments
- `layout.tsx` - Next.js layout files
- `*.sql` - Numbered migration files (`001_description.sql`)

## Where to Add New Code

**New API Endpoint:**
- Route handler: `backend-express/routes/{resource}.js`
- Validation schema: `backend-express/schemas/{resource}.js`
- Service logic: `backend-express/services/{resource}Service.js`
- Tests: `backend-express/__tests__/{resource}.test.js`

**New Frontend Page:**
- Page: `frontend/src/app/dashboard/{feature}/page.tsx`
- Components: `frontend/src/components/{feature-name}.tsx`
- Hooks: Add to `frontend/src/lib/hooks.ts`
- Types: Add to `frontend/src/lib/types.ts`

**New Service:**
- Implementation: `backend-express/services/{name}Service.js`
- Tests: `backend-express/__tests__/services/{name}Service.test.js`
- Mocks (if needed): `backend-express/__tests__/mocks/mock{Name}Service.js`

**New Middleware:**
- Implementation: `backend-express/middleware/{name}.js`
- Tests: `backend-express/__tests__/middleware/{name}.test.js`

**New Database Migration:**
- SQL file: `backend-express/migrations/NNN_{description}.sql`
- Include RLS policies for user isolation

## Special Directories

**backend-express/loadtest/**
- Purpose: Load testing infrastructure
- Source: autocannon-based test suites
- Committed: Yes (suites committed, results gitignored)
- Suites: health, api, stress, memory, all

**backend-express/config/**
- Purpose: Static domain configuration (statute taxonomies, compliance rules)
- Source: Hand-authored legal/regulatory data
- Committed: Yes
- Note: `stateStatuteTaxonomy.js` is 94KB (all 50 states)

**.planning/**
- Purpose: Project planning (GSD workflow)
- Source: Planning documents, phase plans, summaries
- Committed: Yes

---

*Structure analysis: 2026-04-04*
*Update when directory structure changes*
