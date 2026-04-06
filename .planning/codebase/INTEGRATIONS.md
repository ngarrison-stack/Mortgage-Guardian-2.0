# External Integrations

**Analysis Date:** 2026-04-04

## APIs & External Services

**AI Document Analysis:**
- Anthropic Claude - Mortgage document analysis, classification, dispute letter generation
  - SDK/Client: `@anthropic-ai/sdk` 0.78.0 (`backend-express/package.json`)
  - Auth: API key in `ANTHROPIC_API_KEY` env var
  - Services using it:
    - `backend-express/services/claudeService.js` - Core API wrapper
    - `backend-express/services/documentAnalysisService.js` - PDF analysis
    - `backend-express/services/forensicAnalysisService.js` - Forensic case analysis
    - `backend-express/services/disputeLetterService.js` - RESPA letter generation
    - `backend-express/services/classificationService.js` - Document type classification
  - Routes: `backend-express/routes/claude.js`
  - Feature flag: `NEXT_PUBLIC_ENABLE_AI_ANALYSIS` (`frontend/.env.example`)

**Banking Integration:**
- Plaid - Banking data aggregation and transaction access
  - SDK/Client: `plaid` 41.3.0 (`backend-express/package.json`)
  - Auth: `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_ENV` env vars
  - Webhook: `PLAID_WEBHOOK_URL`, `PLAID_WEBHOOK_VERIFICATION_KEY`
  - Services:
    - `backend-express/services/plaidService.js` - Main integration
    - `backend-express/services/mockPlaidService.js` - Mock for development
    - `backend-express/services/plaidCrossReferenceService.js` - Cross-reference with documents
    - `backend-express/services/plaidDataService.js` - Data processing
  - Routes: `backend-express/routes/plaid.js`
  - Feature flag: `NEXT_PUBLIC_ENABLE_PLAID` (`frontend/.env.example`)
  - Documentation: `PLAID-INTEGRATION-COMPLETE.md`, `PLAID-SETUP-GUIDE.md`

## Data Storage

**Databases:**
- Supabase PostgreSQL - Primary data store
  - Client: `@supabase/supabase-js` 2.80.0 (`backend-express/package.json`)
  - Connection: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY` env vars
  - Migrations: `backend-express/migrations/001-005*.sql` (5 active migrations)
  - Baseline: `supabase/migrations/20260401092448_baseline.sql`
  - RLS policies for user isolation (enforced at DB level)
  - Services using Supabase:
    - `backend-express/services/caseFileService.js`
    - `backend-express/services/documentPipelineService.js`
    - `backend-express/services/consolidatedReportService.js`

**File Storage:**
- Supabase Storage - Document storage with bucket policies
  - Encrypted at rest via `backend-express/services/documentEncryptionService.js` (AES-256-GCM)
  - RLS bucket policies: `backend-express/migrations/005_storage_bucket_policies.sql`

**Caching:**
- Redis - Optional caching and rate limiting
  - Client: `ioredis` 5.3.2 (`backend-express/package.json`)
  - Connection: `REDIS_URL` env var (optional)
  - Docker: Redis 7-alpine service in `docker-compose.yml`
  - Services: `backend-express/services/financialSecurity/`, rate limiting middleware
  - Graceful degradation when not configured

## Authentication & Identity

**Frontend Auth Provider:**
- Clerk - User authentication and management
  - SDK: `@clerk/nextjs` 6.39.1 (`frontend/package.json`)
  - Middleware: `frontend/src/middleware.ts` (auth + public route matcher)
  - Pages: `frontend/src/app/sign-in/`, `frontend/src/app/sign-up/`
  - Env vars: `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`

**Backend Auth:**
- JWT verification - Token-based API authentication
  - Package: `jsonwebtoken` 9.0.2 (`backend-express/package.json`)
  - Middleware: `backend-express/middleware/auth.js`
  - Secret: `JWT_SECRET` or `SUPABASE_JWT_SECRET` env var
  - Frontend passes Bearer token via `frontend/src/lib/api.ts`

**Password Security:**
- Argon2 - Password hashing
  - Package: `argon2` 0.44.0 (`backend-express/package.json`)

## Monitoring & Observability

**Error Tracking:**
- Sentry - Server and client error tracking
  - Backend: `@sentry/node` 10.47.0 (`backend-express/utils/sentry.js`)
  - Frontend: `@sentry/nextjs` 10.47.0 (`frontend/src/lib/sentry.ts`)
  - Global error boundary: `frontend/src/app/global-error.tsx`
  - DSN: `SENTRY_DSN` / `NEXT_PUBLIC_SENTRY_DSN` env vars (optional)
  - Traces sampling: 10% (`tracesSampleRate: 0.1`)
  - No PII captured

**Logging:**
- Winston - Structured logging (backend only)
  - Service: `backend-express/services/logger.js`
  - Factory: `backend-express/utils/logger.js` via `createLogger(serviceName)`
  - Production: JSON format; Development: colorized; Test: silent
  - Level: `LOG_LEVEL` env var (default: info in prod, debug in dev)

**Metrics:**
- Custom ring-buffer metrics middleware (`backend-express/middleware/metrics.js`)
  - Endpoint: `GET /metrics` — request counts, error rates, p50/p95/p99 response times, memory usage
  - Load testing: `backend-express/loadtest/` with autocannon suites

**Health Checks:**
- `GET /health` - Overall health with service dependency checks
- `GET /health/live` - Liveness probe (always 200)
- `GET /health/ready` - Readiness probe (503 if dependencies down)
- Route: `backend-express/routes/health.js`

## CI/CD & Deployment

**Hosting:**
- Railway - Backend deployment (primary)
  - Config: `backend-express/railway.json`, `railway.toml`
- Vercel - Frontend/backend deployment (alternative)
  - Config: `backend-express/vercel.json`
- Docker - Container deployment
  - Backend: `backend-express/Dockerfile` (multi-stage, 421MB)
  - Frontend: `frontend/Dockerfile` (multi-stage, 274MB standalone)
  - Compose: `docker-compose.yml` (backend + frontend + Redis)

**CI Pipeline:**
- GitHub Actions
  - Backend CI: `.github/workflows/backend-ci.yml` (Node 20, lint, test with coverage)
  - Frontend CI: `.github/workflows/frontend-ci.yml` (Node 20, lint, build)
  - iOS CI: `.github/workflows/ci.yml` (Xcode build, macOS-latest)

## Environment Configuration

**Development:**
- Required: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ANTHROPIC_API_KEY`
- Optional: `PLAID_CLIENT_ID`, `PLAID_SECRET` (mock service available)
- Optional: Redis (graceful fallback)
- Templates: `backend-express/.env.example`, `frontend/.env.example`

**Production:**
- Secrets: Platform environment variables (Railway dashboard, Vercel dashboard)
- Database: Supabase hosted PostgreSQL with RLS
- Document encryption: `DOCUMENT_ENCRYPTION_KEY` (256-bit hex, 64 chars)
- Guide: `ENV-GUIDE.md`

## Webhooks & Callbacks

**Incoming:**
- Plaid webhooks - Transaction updates, item status changes
  - Verification: `PLAID_WEBHOOK_VERIFICATION_KEY`
  - Route: via `backend-express/routes/plaid.js`

**Outgoing:**
- None

## API Security

- Helmet - HTTP security headers (`helmet` 8.1.0)
- CORS - Configurable origins via `ALLOWED_ORIGINS` env var (`cors` 2.8.5)
- Rate limiting - Per-IP via `express-rate-limit` 8.2.2
  - Config: `RATE_LIMIT_WINDOW_MS` (default 15 min), `RATE_LIMIT_MAX_REQUESTS` (default 100)
- Request validation - Joi schemas in `backend-express/schemas/`
- Compression - Response compression via `compression` 1.7.4

---

*Integration audit: 2026-04-04*
*Update when adding/removing external services*
