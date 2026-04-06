# Technology Stack

**Analysis Date:** 2026-04-04

## Languages

**Primary:**
- JavaScript (ES2022) - Backend application code (`backend-express/`)
- TypeScript (strict) - Frontend application code (`frontend/src/`)

**Secondary:**
- SQL - Database migrations (`backend-express/migrations/`)
- Swift - iOS native app (`MortgageGuardian.xcodeproj/`)

## Runtime

**Environment:**
- Node.js >=20.0.0 (`backend-express/package.json` engines field)
- Docker images use `node:20-alpine` (`backend-express/Dockerfile`, `frontend/Dockerfile`)

**Package Manager:**
- npm >=9.0.0 (`backend-express/package.json` engines field)
- Lockfiles: `backend-express/package-lock.json`, `frontend/package-lock.json`

## Frameworks

**Core:**
- Express.js 4.18.2 - Backend HTTP server (`backend-express/server.js`)
- Next.js 16.1.7 - Frontend React framework with App Router (`frontend/next.config.ts`)
- React 19.1.0 - UI library (`frontend/package.json`)
- Tailwind CSS 4 - Utility-first styling (`frontend/postcss.config.mjs`)

**Testing:**
- Jest 29.7.0 - Backend test runner (`backend-express/jest.config.js`)
- Supertest 7.2.2 - HTTP assertion library for API tests
- ts-jest 29.4.6 - TypeScript support for Jest
- autocannon 8.0.0 - Load testing (`backend-express/loadtest/`)

**Build/Dev:**
- Turbopack - Next.js dev/build bundler (`frontend/package.json` scripts)
- TypeScript 5.9.3 - Type checking (`backend-express/tsconfig.json`, `frontend/tsconfig.json`)
- ESLint 8.57.1 (backend), 9.39.1 (frontend) - Linting
- nodemon 3.0.2 - Backend dev server auto-reload

## Key Dependencies

**Critical:**
- `@anthropic-ai/sdk` 0.78.0 - Claude AI document analysis (`backend-express/services/claudeService.js`)
- `@supabase/supabase-js` 2.80.0 - Database client (`backend-express/services/caseFileService.js`)
- `plaid` 41.3.0 - Banking data integration (`backend-express/services/plaidService.js`)
- `@clerk/nextjs` 6.39.1 - Frontend authentication (`frontend/src/middleware.ts`)
- `@sentry/node` / `@sentry/nextjs` 10.47.0 - Error tracking (both packages)

**Infrastructure:**
- `express` 4.18.2 - HTTP routing and middleware
- `ioredis` 5.3.2 - Redis client for caching (`backend-express/services/financialSecurity/`)
- `helmet` 8.1.0 - Security headers middleware
- `express-rate-limit` 8.2.2 - API rate limiting
- `joi` 18.0.1 - Request validation (`backend-express/schemas/`)
- `winston` 3.11.0 - Structured logging (`backend-express/services/logger.js`)
- `jsonwebtoken` 9.0.2 - JWT authentication
- `argon2` 0.44.0 - Password hashing
- `pdf-parse` 2.4.5 - PDF text extraction

**Frontend:**
- `@tanstack/react-query` 5.96.0 - Server state management (`frontend/src/lib/query-client.ts`)
- `recharts` 3.8.1 - Data visualization
- `react-dropzone` 15.0.0 - File upload handling
- `lucide-react` 1.7.0 - Icon library

## Configuration

**Environment:**
- `.env` files for environment-specific config (gitignored)
- `.env.example` in both `backend-express/` and `frontend/` for templates
- Backend validation: `backend-express/utils/envValidator.js` (Joi-based, 4-tier classification)
- Frontend validation: `frontend/src/lib/env.ts` (typed singleton)
- Documentation: `ENV-GUIDE.md` (unified reference)

**Build:**
- `frontend/next.config.ts` - Next.js configuration
- `frontend/tsconfig.json` - Frontend TypeScript (target ES2017, strict mode, path alias `@/*`)
- `backend-express/tsconfig.json` - Backend TypeScript (target ES2022, strict disabled)
- `frontend/postcss.config.mjs` - PostCSS with Tailwind CSS 4 plugin
- `frontend/eslint.config.mjs` - Frontend ESLint with Next.js config

## Platform Requirements

**Development:**
- macOS/Linux/Windows (any platform with Node.js 20+)
- Docker optional for Redis (`docker-compose.yml`)

**Production:**
- Backend: Railway, Vercel Functions, or Docker container
  - Config: `backend-express/railway.json`, `backend-express/vercel.json`
- Frontend: Vercel or Docker container
  - Multi-stage Dockerfile: `frontend/Dockerfile`
- Database: Supabase PostgreSQL (hosted)
- Redis: Optional (graceful degradation without it)

---

*Stack analysis: 2026-04-04*
*Update after major dependency changes*
