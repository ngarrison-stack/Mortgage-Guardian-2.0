# Technology Stack

**Analysis Date:** 2026-02-26

## Languages

**Primary:**
- JavaScript (ES2024) - All backend application code (Node.js)
- TypeScript 5.9.3 - Frontend application code (Next.js)

**Secondary:**
- Python 3.x - Token server utility (`tools/token_server/`)
- SQL - Database migrations (`backend-express/migrations/`)
- Swift/SwiftUI - iOS app (separate Xcode project)

## Runtime

**Environment:**
- Node.js >=20.0.0 (engines constraint in package.json)
- npm >=9.0.0

**Package Manager:**
- npm 10.x
- Lockfile: `package-lock.json` present and tracked in git (backend-express)

## Frameworks

**Core:**
- Express 4.18.2 - REST API server (`backend-express/`)
- Next.js 15.5.12 - Frontend with Turbopack (`frontend/`)
- React 19.1.0 - UI framework

**Testing:**
- Jest 29.7.0 - Unit and integration tests
- ts-jest 29.4.6 - TypeScript test transpilation
- supertest 7.2.2 - HTTP assertion library for route integration tests

**Build/Dev:**
- nodemon 3.0.2 - Auto-reload in development
- Turbopack - Next.js bundler (via `--turbopack` flag)
- TypeScript 5.9.3 - Compiler for frontend

## Key Dependencies

**Critical:**
- `@anthropic-ai/sdk` 0.78.0 - Claude AI document analysis
- `plaid` 41.3.0 - Bank account linking and transaction data
- `@supabase/supabase-js` 2.80.0 - Database, auth, and storage
- `@clerk/nextjs` 6.34.5 - Frontend authentication (Clerk)

**Infrastructure:**
- `ioredis` 5.3.2 - Redis client for caching/rate limiting
- `express-rate-limit` 8.2.1 - Per-IP rate limiting
- `winston` 3.11.0 - Structured logging (JSON prod, colorized dev)
- `joi` 18.0.1 - Input validation schemas

**Security:**
- `helmet` 8.1.0 - Security headers
- `cors` 2.8.5 - Cross-origin resource sharing
- `argon2` 0.44.0 - Password hashing
- `jsonwebtoken` 9.0.2 - JWT token handling
- `file-type` 16.5.4 - Magic number file validation (last CJS version)
- `pdf-parse` 2.4.5 - Lightweight PDF text extraction (serverless-compatible, no native deps)

## Configuration

**Environment:**
- `.env` files (gitignored) for secrets
- Key backend vars: `ANTHROPIC_API_KEY`, `PLAID_CLIENT_ID`, `PLAID_SECRET`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- Key frontend vars: `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`

**Build:**
- `jest.config.js` - Test runner (90% coverage threshold)
- `vercel.json` - Vercel deployment config
- `railway.toml` - Railway deployment config
- `tsconfig.json` - TypeScript config (frontend)

## Platform Requirements

**Development:**
- macOS/Linux/Windows (any platform with Node.js 20+)
- Docker for local infrastructure (PostgreSQL, Redis, MinIO, Mailhog)

**Production:**
- Vercel - Serverless backend (via `api/index.js` handler wrapper)
- Railway - Alternative backend deployment (Nixpacks builder)
- Vercel - Frontend deployment (Next.js optimized)

---

*Stack analysis: 2026-02-26*
*Update after major dependency changes*
