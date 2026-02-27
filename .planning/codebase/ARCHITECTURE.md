# Architecture

**Analysis Date:** 2026-02-26

## Pattern Overview

**Overall:** Monorepo with Express REST API backend + Next.js frontend

**Key Characteristics:**
- Serverless-first (Vercel handler wrapper)
- Service-oriented business logic (singleton instances)
- JWT authentication via Supabase Auth
- Schema-first input validation (Joi)
- Structured logging (Winston child loggers)

## Layers

**Route Layer:**
- Purpose: HTTP request handling, response formatting
- Contains: Route handlers with try/catch, error status mapping
- Location: `backend-express/routes/*.js`
- Depends on: Services, middleware, schemas
- Used by: Express router (mounted in server.js)

**Middleware Layer:**
- Purpose: Cross-cutting concerns (auth, validation)
- Contains: JWT verification, Joi schema validation factory
- Location: `backend-express/middleware/*.js`
- Depends on: Supabase client, Joi
- Used by: Route handlers (applied per-route or globally)

**Service Layer:**
- Purpose: Business logic and external API integration
- Contains: ClaudeService, PlaidService, DocumentService (singleton classes)
- Location: `backend-express/services/*.js`
- Depends on: External SDKs, logger utility
- Used by: Route handlers

**Utility Layer:**
- Purpose: Shared helpers (logging, file validation)
- Contains: Winston logger factory, file type validation, filename sanitization
- Location: `backend-express/utils/*.js`
- Depends on: Node.js built-ins, Winston, file-type
- Used by: Services, routes, middleware

**Schema Layer:**
- Purpose: Request validation definitions
- Contains: Joi schemas for all API endpoints
- Location: `backend-express/schemas/*.js`
- Depends on: Joi
- Used by: Middleware (validate factory)

## Data Flow

**Document Analysis Flow:**

1. Client sends `POST /v1/ai/claude/analyze` with Bearer token
2. `requireAuth` middleware validates JWT via Supabase
3. `validate(analyzeSchema)` checks request body
4. Route handler calls `claudeService.analyzeDocument()`
5. ClaudeService sends prompt to Anthropic API
6. Response formatted: `{ content, model, usage, stopReason }`
7. JSON response returned to client

**Plaid Banking Flow:**

1. Client requests `POST /v1/plaid/link_token` - creates Plaid Link token
2. Client UI opens Plaid Link, user connects bank
3. Client sends `POST /v1/plaid/exchange_token` with public token
4. PlaidService exchanges for persistent access token
5. Client uses access token for `POST /v1/plaid/accounts` and `/transactions`
6. Plaid webhooks hit `POST /v1/plaid/webhook` (signature verified, no JWT)

**Authentication Flow:**

1. Client authenticates via Supabase Auth (signUp/signIn)
2. Supabase returns JWT token
3. Client includes `Authorization: Bearer <token>` on all `/v1/` requests
4. `requireAuth` middleware extracts token, calls `supabase.auth.getUser(token)`
5. Valid: attaches `req.user`, calls `next()`
6. Invalid: returns 401

**State Management:**
- Stateless request handling (no server-side sessions by default)
- Database per request via Supabase client
- Optional Redis caching for rate limiting

## Key Abstractions

**Service (Singleton):**
- Purpose: Encapsulate business logic for a domain
- Examples: `claudeService.js`, `plaidService.js`, `documentService.js`
- Pattern: `class X { ... } module.exports = new X()`
- State: Shared across requests (SDK client instances)

**Middleware Factory:**
- Purpose: Configurable Express middleware
- Examples: `validate(schema, source)` returns middleware function
- Pattern: Higher-order function returning `(req, res, next) => {}`

**Re-export Facade:**
- Purpose: Backward-compatible imports after refactoring
- Examples: `financialSecurityService.js` re-exports from `./financialSecurity`
- Pattern: Single file re-exports from refactored sub-module directory

**Child Logger:**
- Purpose: Service-scoped structured logging
- Examples: `createLogger('claude')`, `createLogger('plaid')`
- Pattern: Winston child logger with service label in metadata

## Entry Points

**Development Server:**
- Location: `backend-express/server.js`
- Triggers: `npm run dev` (nodemon)
- Responsibilities: Initialize Express, mount middleware, register routes, listen on PORT

**Vercel Serverless:**
- Location: `backend-express/api/index.js`
- Triggers: HTTP requests to Vercel deployment
- Responsibilities: Export Express app as serverless handler

**Frontend:**
- Location: `frontend/src/app/layout.tsx`
- Triggers: Browser navigation
- Responsibilities: Root layout with Clerk auth provider

## Error Handling

**Strategy:** Try/catch in route handlers, centralized Express error middleware as fallback

**Patterns:**
- Route handlers catch known errors (401, 429) and return specific responses
- Unknown errors passed to `next(error)` for centralized handler
- Services throw errors with context, caught by route handlers
- Centralized handler in `server.js` returns generic 500 in production

**Error Response Format:**
```json
{ "error": "ErrorType", "message": "Description" }
```

## Cross-Cutting Concerns

**Logging:**
- Winston with `createLogger(serviceName)` child loggers
- JSON format in production, colorized in development, silent in tests
- Console-only transport (serverless-compatible)

**Validation:**
- Joi schemas at API boundary via `validate(schema)` middleware
- `stripUnknown: true`, `abortEarly: false` (collect all errors)

**Authentication:**
- JWT middleware on all `/v1/` routes
- Supabase Auth token validation
- Public paths: only `/v1/plaid/webhook` (uses signature verification instead)

**Rate Limiting:**
- `express-rate-limit` on all `/v1/` routes
- Default: 100 requests per 15 minutes per IP
- Configurable via `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX_REQUESTS`

**Security Headers:**
- Helmet.js applied globally (CSP, HSTS, X-Frame-Options, etc.)

---

*Architecture analysis: 2026-02-26*
*Update when major patterns change*
