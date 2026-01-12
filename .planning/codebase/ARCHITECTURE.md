# Architecture

**Analysis Date:** 2026-01-12

## Pattern Overview

**Overall:** Multi-Platform Mortgage Audit System - Decoupled backend API with Next.js frontend and iOS mobile app

**Key Characteristics:**
- Microservices-style with independent backend and frontend deployments
- RESTful API architecture with versioned endpoints (`/v1/`)
- Service-oriented backend with modular route handlers
- Serverless-ready (Vercel/Railway compatible)
- Stateless request handling with JWT authentication
- Event-driven document processing pipeline

## Layers

**API Layer:**
- Purpose: HTTP request routing and middleware orchestration
- Contains: Express route handlers, middleware stack, request validation
- Location: `backend-express/server.js`, `backend-express/routes/*.js`
- Depends on: Service layer for business logic
- Used by: Frontend (Next.js), iOS app, external API consumers

**Service Layer:**
- Purpose: Core business logic and external API integration
- Contains: Claude AI service, Plaid service, document processing, financial security analysis
- Location: `backend-express/services/*.js`
  - `claudeService.js` - AI document analysis
  - `plaidService.js` - Banking integration
  - `plaidDataService.js` - Transaction data processing
  - `documentService.js` - Document lifecycle management
  - `financialSecurityService.js` - Security analysis
  - `vendorNeutralSecurityService.js` - Vendor-agnostic security utilities
  - `mockPlaidService.js` - Test/development mock data
- Depends on: External APIs (Anthropic, Plaid, Supabase), database, cache
- Used by: Route handlers

**Data Layer:**
- Purpose: Database access and caching
- Contains: Supabase client, Redis client, data persistence
- Integration: Indirect via @supabase/supabase-js and ioredis clients in services
- Depends on: Supabase PostgreSQL, Redis cache
- Used by: Service layer

**Frontend Layer:**
- Purpose: User interface and authentication
- Contains: Next.js 15 app with React 19, Clerk authentication, API client
- Location: `frontend/src/app/` (App Router architecture)
  - `layout.tsx` - Root layout with Clerk provider
  - `page.tsx` - Main landing page
  - `middleware.ts` - Clerk authentication middleware
- Depends on: Backend API (`backend-express/`), Clerk authentication
- Used by: Web users

## Data Flow

**Document Analysis Request (Primary Flow):**

1. iOS app or frontend uploads document via `POST /v1/documents/upload`
2. `documents.js` route handler receives multipart/form-data
3. `documentService.js` processes upload, stores in MinIO/Supabase Storage
4. Service calls `claudeService.js` with document text/OCR data
5. `claudeService.js` sends to Anthropic Claude API for analysis
6. AI response parsed for detected errors and confidence scores
7. Results stored in Supabase database
8. Response returned to client with findings

**Bank Transaction Verification Flow:**

1. Client initiates Plaid Link via `POST /v1/plaid/link_token`
2. `plaidService.js` creates Plaid Link token
3. Client exchanges public token via `POST /v1/plaid/exchange_token`
4. Access token stored securely for user
5. Client requests transactions via `POST /v1/plaid/transactions`
6. `plaidDataService.js` fetches transactions from Plaid API
7. `financialSecurityService.js` cross-references with mortgage documents
8. Discrepancies flagged and returned to client

**State Management:**
- Backend: Stateless - each request independent, auth via JWT
- Frontend: Next.js Server Components + Client Components
- Database: Persistent state in Supabase PostgreSQL
- Cache: Redis for rate limiting, API response caching

## Key Abstractions

**Service:**
- Purpose: Encapsulate integration with external APIs and business logic
- Examples: `backend-express/services/claudeService.js`, `backend-express/services/plaidService.js`
- Pattern: Module exports with async functions, no instantiation

**Route Handler:**
- Purpose: Express route definitions with middleware
- Examples: `backend-express/routes/claude.js`, `backend-express/routes/plaid.js`, `backend-express/routes/documents.js`
- Pattern: Express Router, middleware chain, error handling

**Middleware Stack:**
- Purpose: Cross-cutting concerns (security, logging, rate limiting)
- Examples: helmet (security), morgan (logging), express-rate-limit (throttling), cors (cross-origin)
- Pattern: Express middleware functions in `backend-express/server.js`

## Entry Points

**Backend API:**
- Location: `backend-express/server.js`
- Triggers: HTTP requests to Express server (port 3000 default)
- Responsibilities: Initialize middleware stack, register routes, start server
- Routes:
  - `GET /health` - Health check (no rate limit)
  - `POST /v1/ai/claude/analyze` - Document analysis
  - `POST /v1/plaid/*` - Banking operations
  - `POST /v1/documents/*` - Document management

**Frontend:**
- Location: `frontend/src/app/layout.tsx`, `frontend/src/app/page.tsx`
- Triggers: HTTP requests to Next.js server
- Responsibilities: Render React components, handle Clerk authentication
- Middleware: `frontend/src/middleware.ts` (Clerk auth protection)

## Error Handling

**Strategy:** Exception bubbling to top-level error middleware

**Patterns:**
- Service layer throws errors with descriptive messages
- Route handlers catch via Express error middleware (4-param function)
- Global error handler in `backend-express/server.js` (lines 91-100+)
- Production: Generic "Internal server error" messages
- Development: Full error stack traces
- HTTP status codes: 404 for not found, 500 for errors, custom codes via err.statusCode

## Cross-Cutting Concerns

**Logging:**
- Winston logger for application logs (backend)
- Morgan for HTTP request logging in development mode
- Conditional: `NODE_ENV === 'development'` uses `morgan('dev')`, production uses `morgan('combined')`
- Location: `backend-express/server.js`

**Validation:**
- Joi v18.0.1 for schema validation (`backend-express/package.json`)
- Input validation at API boundaries
- Implementation: Per-route in route handlers

**Authentication:**
- Backend: JWT tokens via jsonwebtoken v9.0.2 + Supabase Auth
- Frontend: Clerk authentication via @clerk/nextjs
- Middleware: Clerk middleware in `frontend/src/middleware.ts`
- Token flow: Client includes Authorization header, backend validates JWT

**Rate Limiting:**
- express-rate-limit v8.2.1 + rate-limiter-flexible v8.1.0
- Applied to `/v1/*` routes
- Configurable: `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX_REQUESTS` env vars
- Backend: Redis for distributed rate limiting
- Location: `backend-express/server.js` lines 49-56

**Security:**
- Helmet.js v8.1.0 for security headers
- CORS with configurable origins
- Compression middleware for response optimization
- 50MB body limit for document uploads
- Location: `backend-express/server.js`

---

*Architecture analysis: 2026-01-12*
*Update when major patterns change*
