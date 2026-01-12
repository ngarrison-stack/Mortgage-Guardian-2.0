# External Integrations

**Analysis Date:** 2026-01-12

## APIs & External Services

**AI Document Analysis:**
- Anthropic Claude AI - Mortgage document error detection and analysis
  - SDK/Client: @anthropic-ai/sdk v0.68.0 (`backend-express/package.json`)
  - Auth: API key in `ANTHROPIC_API_KEY` env var (`backend-express/.env.example`)
  - Endpoints used: Document analysis API via `claudeService.js`
  - Integration: `backend-express/services/claudeService.js`, `backend-express/routes/claude.js`

**Banking & Financial Data:**
- Plaid - Bank account verification and transaction data
  - SDK/Client: plaid v39.1.0 (`backend-express/package.json`, root `package.json`)
  - Auth: `PLAID_CLIENT_ID`, `PLAID_SECRET` in env vars (`backend-express/.env.example`)
  - Environment: Configurable via `PLAID_ENV` (sandbox/development/production)
  - Webhook: Optional `PLAID_WEBHOOK_URL` for real-time updates
  - Webhook verification: `PLAID_WEBHOOK_VERIFICATION_KEY` for HMAC-SHA256 signature validation
  - Integration: `backend-express/services/plaidService.js`, `backend-express/services/plaidDataService.js`, `backend-express/routes/plaid.js`

**Email/SMS:**
- Not detected currently

**External APIs:**
- iOS App Integration - Mobile app connects to Express backend
  - Integration method: REST API via `/v1/` endpoints
  - Auth: JWT tokens via `jsonwebtoken` package
  - CORS: Configured via `ALLOWED_ORIGINS` env var (`backend-express/server.js`)

## Data Storage

**Databases:**
- Supabase (PostgreSQL) - Primary data store
  - Connection: via `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY` env vars (`backend-express/.env.example`)
  - Client: @supabase/supabase-js v2.80.0
  - Migrations: Present in `backend-express/migrations/` directory
  - Purpose: User data, document metadata, audit records

**File Storage:**
- MinIO - S3-compatible object storage for documents (local development)
  - SDK/Client: S3-compatible API (inferred from docker-compose configuration)
  - Auth: MinIO credentials (configured in docker-compose.yml)
  - Purpose: Document uploads, processed files
- Supabase Storage - Alternative for production document storage
  - Integration: via @supabase/supabase-js client

**Caching:**
- Redis - Session storage, rate limiting, API caching
  - Connection: via ioredis v5.3.2 client (`backend-express/package.json`)
  - Purpose: Rate limiting via rate-limiter-flexible v8.1.0, API response caching
  - Local dev: Docker Compose (port 6379)

## Authentication & Identity

**Auth Provider (Backend):**
- Supabase Auth - User authentication and session management
  - Implementation: @supabase/supabase-js SDK
  - Token storage: JWT via jsonwebtoken v9.0.2
  - Session management: JWT tokens with Supabase Auth
  - 2FA: speakeasy v2.0.0 for TOTP (Time-Based One-Time Password)
  - Password hashing: argon2 v0.44.0

**Auth Provider (Frontend):**
- Clerk - Frontend authentication
  - Implementation: @clerk/nextjs v6.34.5 (`frontend/package.json`)
  - Configuration: `frontend/.env.example`, `frontend/src/middleware.ts`
  - Purpose: User authentication UI and session management in Next.js app

**OAuth Integrations:**
- Managed through Clerk (frontend) and Supabase (backend)
- Specific providers not configured yet in this codebase

## Monitoring & Observability

**Error Tracking:**
- Not detected currently

**Analytics:**
- Not detected currently

**Logs:**
- Winston v3.11.0 - Application logging (`backend-express/package.json`)
  - Implementation: `backend-express/services/` logging throughout
  - Transports: Console, optionally Syslog via winston-syslog v2.7.0
  - Format: Morgan v1.10.0 for HTTP request logging in development
- Production: Platform logs (Vercel/Railway stdout/stderr)

## CI/CD & Deployment

**Hosting:**
- **Backend**: Vercel or Railway - Serverless/container deployment
  - Deployment: Automatic via Git push (vercel.json, railway.json configs)
  - Environment vars: Configured in platform dashboard
  - Config files: `backend-express/vercel.json`, `backend-express/railway.json`
- **Frontend**: Vercel or Netlify - Next.js hosting
  - Deployment: Automatic via Git push
  - Netlify: Pre-configured in `frontend/.netlify/` directory
  - Environment vars: Clerk keys configured in platform

**CI Pipeline:**
- Not detected (no GitHub Actions, GitLab CI, or similar)
- Deploy scripts present: `backend-express/deploy-railway.sh`, `backend-express/deploy-render.sh`

## Environment Configuration

**Development:**
- Required env vars: `ANTHROPIC_API_KEY`, `PLAID_CLIENT_ID`, `PLAID_SECRET`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- Secrets location: `.env.local` files (gitignored), `.env.example` templates provided
- Mock/stub services: Plaid sandbox mode, `mockPlaidService.js` available
- Local infrastructure: Docker Compose with PostgreSQL, Redis, MinIO, Mailhog

**Staging:**
- Not explicitly configured (can use development/sandbox modes for APIs)

**Production:**
- Secrets management: Platform environment variables (Vercel/Railway dashboard)
- Database: Supabase production project
- Plaid: Production environment (requires approval)
- Rate limiting: Redis-backed via express-rate-limit

## Webhooks & Callbacks

**Incoming:**
- Plaid - Optional webhook endpoint (not fully implemented)
  - Endpoint: Configured via `PLAID_WEBHOOK_URL` env var
  - Verification: HMAC-SHA256 signature validation via `PLAID_WEBHOOK_VERIFICATION_KEY`
  - Events: Transaction updates, account changes
  - Status: Infrastructure present but handler not fully implemented

**Outgoing:**
- Not detected currently

## Security Features

**Request Security:**
- Helmet.js v8.1.0 - Security headers middleware (`backend-express/server.js`)
- CORS - Configurable origins via `ALLOWED_ORIGINS` (`backend-express/server.js`)
- Rate limiting - Express-rate-limit v8.2.1 + rate-limiter-flexible v8.1.0
  - Window: `RATE_LIMIT_WINDOW_MS` (default 15 minutes)
  - Max requests: `RATE_LIMIT_MAX_REQUESTS` (default 100 per window per IP)

**Data Security:**
- Password hashing: Argon2 v0.44.0 (memory-hard algorithm)
- JWT tokens: jsonwebtoken v9.0.2 for authentication
- 2FA: TOTP via speakeasy v2.0.0

---

*Integration audit: 2026-01-12*
*Update when adding/removing external services*
