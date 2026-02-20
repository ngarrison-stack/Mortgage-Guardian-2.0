# Codebase Structure

**Analysis Date:** 2026-01-12

## Directory Layout

```
Mortgage-Guardian-2.0-Clean/
├── backend-express/          # Node.js Express API server
│   ├── routes/              # API route handlers
│   ├── services/            # Business logic and external API clients
│   ├── migrations/          # Database migrations
│   ├── api/                 # Vercel serverless functions (optional)
│   ├── docs/                # API documentation
│   └── server.js            # Express app entry point
├── frontend/                # Next.js 15 web application
│   ├── src/                 # Source code
│   │   ├── app/            # Next.js App Router pages
│   │   └── middleware.ts   # Clerk authentication middleware
│   ├── public/             # Static assets
│   └── .netlify/           # Netlify deployment artifacts
├── backend/                 # Alternative backend (Aurora/AWS architecture)
│   └── api-service/        # TypeScript API service
├── quickstart/              # Plaid quickstart examples
│   ├── frontend/           # React Plaid integration example
│   └── node/               # Node.js Plaid example
├── fastlane/                # iOS app deployment automation
├── Mortgage _App_Extra/     # Additional iOS app resources
└── package.json             # Root package manifest (minimal)
```

## Directory Purposes

**backend-express/**
- Purpose: Primary backend API service (production-ready)
- Contains: Express.js server, routes, services, migrations
- Key files:
  - `server.js` - Express app configuration and startup
  - `routes/` - API endpoint definitions
  - `services/` - Business logic modules
  - `.env.example` - Environment variable template
  - `package.json` - Node.js dependencies
- Subdirectories:
  - `routes/` - API route handlers (claude.js, plaid.js, documents.js, health.js)
  - `services/` - Service layer implementations
  - `migrations/` - Database schema migrations
  - `docs/` - API documentation
  - `api/` - Vercel serverless function wrappers
  - `__tests__/mocks/` - Service mock modules (mockClaudeService, mockSupabaseClient, mockRedisClient)
  - `__tests__/utils/` - Test utilities (testUtils.js: setupTestApp, generateTestJWT, assertions)
  - `__tests__/fixtures/` - Test data factories (dbFixtures.js: user, document, analysis, transaction)
- Deployment: Vercel (`vercel.json`), Railway (`railway.json`, `railway.toml`)

**frontend/**
- Purpose: Next.js 15 web application with Clerk authentication
- Contains: React 19 components, Tailwind CSS v4 styling, Clerk auth
- Key files:
  - `src/app/layout.tsx` - Root layout with ClerkProvider
  - `src/app/page.tsx` - Landing page
  - `src/middleware.ts` - Clerk authentication middleware
  - `next.config.ts` - Next.js configuration
  - `package.json` - Frontend dependencies
  - `.env.example` - Clerk API key template
- Subdirectories:
  - `src/app/` - App Router pages and layouts
  - `public/` - Static assets (images, favicons)
  - `.netlify/` - Netlify deployment configuration and functions
  - `.next/` - Build output (gitignored)
- Deployment: Netlify (pre-configured), Vercel compatible

**backend/api-service/**
- Purpose: Alternative TypeScript backend with AWS integration
- Contains: Aurora PostgreSQL, AWS Glue, dbt, TypeScript
- Status: Not actively used (backend-express/ is primary)
- Key files: `package.json` with AWS SDK dependencies

**quickstart/**
- Purpose: Plaid integration examples and testing
- Contains: Frontend and Node.js Plaid quickstart templates
- Subdirectories:
  - `frontend/` - React Plaid Link example
  - `node/` - Node.js Plaid API example

**fastlane/**
- Purpose: iOS app deployment automation
- Contains: Fastlane configuration for iOS CI/CD

**Mortgage _App_Extra/**
- Purpose: Additional iOS app resources and Docker configurations
- Contains: Docker Compose files, iOS assets

## Key File Locations

**Entry Points:**
- `backend-express/server.js` - Backend API server entry
- `frontend/src/app/layout.tsx` - Frontend root layout
- `frontend/src/app/page.tsx` - Frontend landing page

**Configuration:**
- `backend-express/.env.example` - Backend environment variables template
- `frontend/.env.example` - Frontend environment variables (Clerk)
- `backend-express/tsconfig.json` - TypeScript configuration (backend)
- `frontend/tsconfig.json` - TypeScript configuration (frontend)
- `backend-express/vercel.json` - Vercel deployment config
- `backend-express/railway.json` - Railway deployment config
- `frontend/next.config.ts` - Next.js build configuration
- `frontend/eslint.config.mjs` - ESLint configuration

**Core Logic:**
- `backend-express/routes/` - API route handlers
  - `claude.js` - Claude AI document analysis endpoints
  - `plaid.js` - Plaid banking integration endpoints
  - `documents.js` - Document upload/management endpoints
  - `health.js` - Health check endpoint
- `backend-express/services/` - Business logic
  - `claudeService.js` - Anthropic Claude AI client
  - `plaidService.js` - Plaid API client
  - `plaidDataService.js` - Transaction data processing
  - `documentService.js` - Document lifecycle management
  - `financialSecurityService.js` - Security analysis logic
  - `vendorNeutralSecurityService.js` - Security utilities
  - `mockPlaidService.js` - Mock data for testing

**Testing:**
- `backend-express/test-claude.js` - Claude AI integration test
- `backend-express/test-live-backend.sh` - Backend API smoke tests
- Root level: `test-plaid-corrected.js` - Plaid integration test
- No organized test directory currently

**Documentation:**
- `README.md` - Project overview (root)
- `CLAUDE.md` - AI assistant instructions (root and project-specific)
- `backend-express/README.md` - Backend setup guide
- `backend-express/docs/` - API documentation
- `backend-express/DEPLOYMENT-FLOW.md` - Deployment guides
- `frontend/README.md` - Frontend setup guide

## Naming Conventions

**Files:**
- camelCase.js - JavaScript modules (server.js, documentService.js)
- kebab-case.sh - Shell scripts (deploy-railway.sh)
- UPPERCASE.md - Important documentation (README.md, CLAUDE.md)
- camelCase.tsx - React components (layout.tsx, page.tsx)

**Directories:**
- kebab-case - All directories (backend-express/, api-service/)
- Plural for collections - routes/, services/, migrations/

**Special Patterns:**
- .env.example - Environment variable templates
- *.test.js - Test files (currently minimal)
- middleware.ts - Next.js middleware (frontend)

## Where to Add New Code

**New API Endpoint:**
- Primary code: `backend-express/routes/{feature}.js`
- Service logic: `backend-express/services/{feature}Service.js`
- Tests: `backend-express/test-{feature}.js` or dedicated test directory
- Documentation: Update `backend-express/docs/` and OpenAPI spec

**New Service Integration:**
- Implementation: `backend-express/services/{vendor}Service.js`
- Configuration: Add env vars to `backend-express/.env.example`
- Route: Create or update `backend-express/routes/{feature}.js`

**New Frontend Page:**
- Implementation: `frontend/src/app/{route}/page.tsx`
- Layout: Optionally add `frontend/src/app/{route}/layout.tsx`
- Middleware: Update `frontend/src/middleware.ts` for auth rules

**Database Migration:**
- Implementation: `backend-express/migrations/{timestamp}_{description}.sql`
- Apply: Via Supabase dashboard or migration tool

**Utilities:**
- Backend shared helpers: Create `backend-express/utils/` directory
- Frontend shared components: Create `frontend/src/components/` directory
- Type definitions: Add to existing or create `types/` directories

## Special Directories

**backend-express/node_modules/**
- Purpose: NPM dependencies
- Source: npm install from package.json
- Committed: No (.gitignored)

**frontend/.next/**
- Purpose: Next.js build output
- Source: Generated by `npm run build`
- Committed: No (.gitignored)

**frontend/.netlify/**
- Purpose: Netlify deployment artifacts and edge functions
- Source: Generated during Netlify build
- Committed: Partially (configuration yes, build artifacts no)

**backend-express/api/**
- Purpose: Vercel serverless function wrappers
- Source: Created for Vercel deployment compatibility
- Committed: Yes (needed for Vercel deployment)

**Mortgage-Guardian-2.0/** (subdirectory)
- Purpose: Duplicate/archived version of project
- Source: Old project structure
- Status: Should be cleaned up or removed
- Committed: Currently yes (likely unintentional)

---

*Structure analysis: 2026-01-12*
*Update when directory structure changes*
