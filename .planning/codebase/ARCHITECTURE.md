# Architecture

**Analysis Date:** 2026-04-04

## Pattern Overview

**Overall:** Multi-component layered monolith (Express API + Next.js frontend + iOS app)

**Key Characteristics:**
- Stateless backend API with service-oriented business logic
- Clear separation: routes -> services -> data layer
- Serverless-optimized (Vercel Functions / Railway)
- Multi-tenant via Supabase RLS policies (user_id isolation)
- AI-powered document analysis pipeline (Claude API)

## Layers

**Presentation Layer (Frontend):**
- Purpose: User interface for case management, document upload, analysis, reports
- Contains: Next.js App Router pages, React components, TanStack Query hooks
- Location: `frontend/src/app/` (pages), `frontend/src/components/` (UI), `frontend/src/lib/` (utilities)
- Depends on: Backend API via `frontend/src/lib/api.ts`, Clerk for auth
- Used by: End users (browser)

**API Layer (Backend Routes):**
- Purpose: HTTP endpoint handlers, request validation, response formatting
- Contains: Express route handlers with Joi validation middleware
- Location: `backend-express/routes/` (7 route files)
- Depends on: Service layer, middleware layer
- Used by: Frontend API client

**Service Layer (Business Logic):**
- Purpose: Core domain logic — document analysis, compliance, reports, encryption
- Contains: 43 service files totaling ~8400 LOC
- Location: `backend-express/services/`
- Depends on: Supabase client, Claude API, Plaid API, config layer
- Used by: Route handlers

**Middleware Layer:**
- Purpose: Cross-cutting concerns (auth, validation, error handling, metrics)
- Contains: Express middleware functions
- Location: `backend-express/middleware/` (6 files)
- Depends on: Nothing (standalone)
- Used by: Route layer (applied globally or per-route)

**Schema Layer:**
- Purpose: Request validation definitions
- Contains: Joi schemas for all API endpoints
- Location: `backend-express/schemas/` (9 files)
- Depends on: Joi library
- Used by: Validation middleware

**Config Layer:**
- Purpose: Static domain configuration (statutes, rules, mappings)
- Contains: Federal/state statute taxonomies, compliance rule mappings, document field definitions
- Location: `backend-express/config/` (9 files, including 94KB state taxonomy)
- Depends on: Nothing
- Used by: Service layer (compliance, jurisdiction, report services)

**Data Layer:**
- Purpose: Database schema and access policies
- Contains: SQL migrations with RLS policies
- Location: `backend-express/migrations/` (5 active migrations)
- Depends on: Supabase PostgreSQL
- Used by: Service layer via Supabase client

## Data Flow

**Document Analysis Pipeline:**

1. User uploads PDF via frontend (`frontend/src/components/document-upload.tsx`)
2. API receives file at `POST /v1/documents/upload` (`backend-express/routes/documents.js`)
3. `documentPipelineService.js` orchestrates processing:
   - `ocrService.js` extracts text from PDF
   - `classificationService.js` identifies document type via Claude
   - `documentAnalysisService.js` performs detailed analysis via Claude
   - `complianceService.js` maps findings to federal/state statutes
   - Results stored in Supabase with encryption
4. Frontend polls for status, displays findings

**Case Management Flow:**

1. User creates case via form (`frontend/src/components/case-form.tsx`)
2. `POST /v1/cases` -> `backend-express/routes/cases.js`
3. Joi validation via `backend-express/schemas/cases.js`
4. `caseFileService.js` creates case in Supabase (RLS ensures user isolation)
5. User adds documents, triggers analysis, generates reports

**Report Generation Flow:**

1. User requests report -> `POST /v1/cases/:caseId/report`
2. `consolidatedReportService.js` aggregates all document analyses
3. `crossDocumentComparisonService.js` cross-references dates/amounts
4. `confidenceScoringService.js` scores finding confidence
5. Optionally `disputeLetterService.js` generates RESPA-compliant letter
6. Report stored in Supabase, rendered by frontend

**State Management:**
- Backend: Stateless — all state in Supabase, no in-memory persistence
- Frontend: TanStack Query for server state cache, React state for UI
- Sessions: JWT tokens (Clerk frontend, JWT verification backend)

## Key Abstractions

**Service Classes:**
- Purpose: Encapsulate domain logic for a specific concern
- Examples: `CaseFileService`, `DocumentAnalysisService`, `ConsolidatedReportService`
- Pattern: Class with methods, some use Supabase client, some use mock storage fallback
- Location: `backend-express/services/*.js`

**Custom Error Hierarchy:**
- Purpose: Typed errors with HTTP status codes for consistent API responses
- Base: `AppError` with `statusCode`, `code`, `type`, `displayMessage`, `isOperational`
- Subclasses: `ValidationError` (400), `NotFoundError` (404), `AuthenticationError` (401), `AuthorizationError` (403), `ConflictError` (409), `RateLimitError` (429), `ExternalServiceError` (502)
- Location: `backend-express/middleware/errorHandler.js`

**Validation Middleware Factory:**
- Purpose: Generate Express middleware from Joi schemas
- Pattern: `validate(schema, source)` returns middleware that validates `req[source]`
- Location: `backend-express/middleware/validate.js`

**API Client:**
- Purpose: Typed fetch wrapper with auth token injection
- Pattern: `fetchWithAuth()` adds Bearer token from Clerk, handles errors
- Location: `frontend/src/lib/api.ts`

**React Query Hooks:**
- Purpose: Data fetching with caching, refetching, optimistic updates
- Examples: `useCases()`, `useCase(id)`, `useCreateCase()`, `useUploadDocument()`
- Location: `frontend/src/lib/hooks.ts`

## Entry Points

**Backend Server:**
- Location: `backend-express/server.js` (Express app setup)
- Triggers: `npm start` or `npm run dev` (nodemon)
- Responsibilities: Mount middleware, routes, error handler, start listening

**Backend Serverless:**
- Location: `backend-express/api/index.js` (Vercel handler)
- Triggers: Vercel Functions invocation
- Responsibilities: Export Express app as serverless function

**Frontend App:**
- Location: `frontend/src/app/layout.tsx` (root layout)
- Triggers: Next.js server start
- Responsibilities: Clerk provider, query provider, Sentry, global styles

**Frontend Middleware:**
- Location: `frontend/src/middleware.ts`
- Triggers: Every request (Next.js middleware)
- Responsibilities: Clerk auth, public route matching

## Error Handling

**Strategy:** Custom error classes thrown in services, caught by global error handler middleware

**Patterns:**
- Services throw typed errors (ValidationError, NotFoundError, etc.)
- Route handlers wrapped in `asyncHandler()` for automatic error forwarding
- Global `errorHandler` middleware catches all errors, formats JSON response
- Frontend: `ApiError` class in `frontend/src/lib/api.ts`, React Query error handling
- Sentry captures unhandled errors (both backend and frontend)

## Cross-Cutting Concerns

**Logging:**
- Winston logger with service-specific instances via `createLogger(serviceName)`
- JSON format in production, colorized in development, silent in test
- Location: `backend-express/services/logger.js`, `backend-express/utils/logger.js`

**Validation:**
- Joi schemas at API boundary (`backend-express/schemas/`)
- Middleware: `validate(schema, 'body'|'query'|'params')`

**Authentication:**
- Frontend: Clerk middleware on all non-public routes
- Backend: JWT verification middleware (`backend-express/middleware/auth.js`)
- Database: RLS policies enforce `user_id` isolation

**Metrics:**
- Ring-buffer middleware tracks request counts, error rates, response time percentiles
- Endpoint: `GET /metrics` returns snapshot
- Location: `backend-express/middleware/metrics.js`

**Security:**
- Document encryption: AES-256-GCM at rest (`backend-express/services/documentEncryptionService.js`)
- Financial security: `backend-express/services/financialSecurity/` (6 files)
- Vendor-neutral security: `backend-express/services/vendorNeutralSecurity/` (6 files)
- Request IDs: `backend-express/middleware/requestId.js` for tracing

---

*Architecture analysis: 2026-04-04*
*Update when major patterns change*
