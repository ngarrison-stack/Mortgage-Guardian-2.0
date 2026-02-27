# External Integrations

**Analysis Date:** 2026-02-26

## APIs & External Services

**AI Document Analysis:**
- Anthropic Claude AI - Mortgage document analysis and error detection
  - SDK/Client: `@anthropic-ai/sdk` v0.78.0
  - Auth: API key in `ANTHROPIC_API_KEY` env var
  - Default Model: `claude-3-5-sonnet-20241022`
  - Default Params: maxTokens=4096, temperature=0.1
  - Service: `backend-express/services/claudeService.js`
- Anthropic Claude Vision - OCR for scanned PDFs and images
  - SDK/Client: `@anthropic-ai/sdk` v0.78.0 (shared)
  - Model: `claude-sonnet-4-5-20250514` (cost-effective for OCR)
  - Max tokens: 8192
  - Service: `backend-express/services/ocrService.js`

**Banking Integration:**
- Plaid - Bank account linking and transaction retrieval
  - SDK/Client: `plaid` v41.3.0
  - Auth: `PLAID_CLIENT_ID`, `PLAID_SECRET` env vars
  - Environment: `PLAID_ENV` (sandbox|development|production)
  - API Version: 2020-09-14
  - Mock Fallback: `MockPlaidService` used when credentials missing or set to 'mock'
  - Service: `backend-express/services/plaidService.js`

## Data Storage

**Database:**
- Supabase (PostgreSQL) - Primary data store
  - Connection: `SUPABASE_URL` env var
  - Client: `@supabase/supabase-js` v2.80.0
  - Migrations: `backend-express/migrations/` (manual SQL execution)
  - Tables: documents, plaid_items, plaid_accounts, plaid_transactions

**File Storage:**
- Supabase Storage - Document uploads in production
  - SDK: `@supabase/supabase-js` storage API
  - Buckets: `documents/{userId}/{documentId}`
- MinIO - S3-compatible local storage via docker-compose (development)

**Caching:**
- Redis - Rate limiting and optional session caching
  - Client: `ioredis` v5.3.2
  - Connection: `REDIS_HOST` (default: localhost), `REDIS_PORT` (default: 6379)

## Authentication & Identity

**Backend Auth Provider:**
- Supabase Auth - JWT token validation
  - Implementation: `supabase.auth.getUser(token)` in middleware
  - Token: Bearer token in Authorization header
  - Middleware: `backend-express/middleware/auth.js`
  - Attaches: `req.user` object to authenticated requests

**Frontend Auth Provider:**
- Clerk - User authentication and session management
  - Client: `@clerk/nextjs` v6.34.5
  - Keys: `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`

## Monitoring & Observability

**Logging:**
- Winston - Structured logging (console transport only)
  - Production: JSON format with timestamps
  - Development: Colorized human-readable format
  - Test: Silent mode (no output)
  - Child loggers: `createLogger('service-name')` pattern
  - Service: `backend-express/utils/logger.js`

**HTTP Logging:**
- Morgan - HTTP request logging piped to Winston
  - Format: combined (Apache log format)

**Error Tracking:**
- None configured (gap - see CONCERNS.md)

## CI/CD & Deployment

**Backend Hosting:**
- Vercel - Primary serverless deployment
  - Handler: `backend-express/api/index.js` wraps Express app
  - Config: `vercel.json` (rewrites all routes to /api)
  - No build step (JavaScript runs as-is)
- Railway - Alternative deployment
  - Config: `railway.toml`, `railway.json`
  - Builder: Nixpacks, restart on failure (max 10 retries)

**Frontend Hosting:**
- Vercel - Next.js optimized deployment

**CI Pipeline:**
- GitHub Actions - iOS build/test only (`.github/workflows/`)
- Backend CI: Not configured (gap - see CONCERNS.md)

## Environment Configuration

**Development:**
- Required: `ANTHROPIC_API_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- Optional: `PLAID_CLIENT_ID` (falls back to mock), `REDIS_HOST`
- Local services: Docker Compose (PostgreSQL, Redis, MinIO, Mailhog)

**Production:**
- Required: All development vars + `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_WEBHOOK_URL`
- Rate limiting: `RATE_LIMIT_WINDOW_MS` (default 900000), `RATE_LIMIT_MAX_REQUESTS` (default 100)
- CORS: `ALLOWED_ORIGINS` (comma-separated or '*')
- Secrets: Managed in Vercel/Railway dashboards

## Webhooks & Callbacks

**Incoming:**
- Plaid - `POST /v1/plaid/webhook` (public, no JWT required)
  - Verification: HMAC-SHA256 signature via `PLAID_WEBHOOK_VERIFICATION_KEY`
  - Events: INITIAL_UPDATE, HISTORICAL_UPDATE, DEFAULT_UPDATE (transactions)
  - Note: Handlers log but don't yet persist data (gap - see CONCERNS.md)

**Outgoing:**
- None

---

*Integration audit: 2026-02-26*
*Update when adding/removing external services*
