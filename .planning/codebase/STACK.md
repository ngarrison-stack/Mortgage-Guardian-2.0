# Technology Stack

**Analysis Date:** 2026-01-12

## Languages

**Primary:**
- JavaScript (Node.js) - Backend API service (`backend-express/`)
- TypeScript - Frontend application and type definitions

**Secondary:**
- JavaScript - Configuration files, build scripts
- Swift - iOS mobile app (referenced in documentation, not in this repository)

## Runtime

**Environment:**
- Node.js >=20.0.0 - `backend-express/package.json`
- Next.js 15.5.4 runtime - `frontend/package.json`
- React 19.1.0 - `frontend/package.json`

**Package Manager:**
- npm >=9.0.0 - `backend-express/package.json`
- Lockfiles: `package-lock.json` present in both backend-express/ and frontend/

## Frameworks

**Core:**
- Express 4.18.2 - Backend HTTP server (`backend-express/`)
- Next.js 15.5.4 - Frontend framework with Turbopack (`frontend/`)
- React 19.1.0 - UI library (`frontend/`)

**Testing:**
- No test framework detected currently
- Test scripts exist but show "No tests yet" placeholder

**Build/Dev:**
- Turbopack - Next.js bundler (via `--turbopack` flag in `frontend/package.json`)
- TypeScript 5.9.3 - Type checking (`backend-express/` and `frontend/`)
- nodemon 3.0.2 - Development server hot reload (`backend-express/`)

## Key Dependencies

**Critical:**
- @anthropic-ai/sdk ^0.68.0 - Claude AI integration for document analysis (`backend-express/`)
- plaid ^39.1.0 - Bank account integration and transaction data (`backend-express/` and root)
- @supabase/supabase-js ^2.80.0 - Database and authentication (`backend-express/`)
- @clerk/nextjs ^6.34.5 - Frontend authentication (`frontend/`)

**Infrastructure:**
- express ^4.18.2 - HTTP routing (`backend-express/`)
- ioredis ^5.3.2 - Redis client for caching/rate limiting (`backend-express/`)
- express-rate-limit ^8.2.1 - API rate limiting (`backend-express/`)
- helmet ^8.1.0 - Security headers middleware (`backend-express/`)
- winston ^3.11.0 - Logging framework (`backend-express/`)
- jsonwebtoken ^9.0.2 - JWT authentication (`backend-express/`)
- multer ^1.4.5-lts.1 - File upload handling (`backend-express/`)

## Configuration

**Environment:**
- `.env` files with dotenv package (`backend-express/`)
- `.env.example` templates in `backend-express/` and `frontend/`
- Key configs: `ANTHROPIC_API_KEY`, `PLAID_CLIENT_ID`, `PLAID_SECRET`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`

**Build:**
- `tsconfig.json` - TypeScript configuration (`backend-express/`, `frontend/`)
- `next.config.ts` - Next.js configuration (`frontend/`)
- `vercel.json` - Vercel deployment configuration (`backend-express/`)
- `railway.json` / `railway.toml` - Railway deployment configuration (`backend-express/`)

## Platform Requirements

**Development:**
- macOS/Linux/Windows (any platform with Node.js 20+)
- Docker Compose for local services (PostgreSQL, Redis, MinIO, Mailhog)
- Optional: Redis for caching and rate limiting

**Production:**
- **Backend**: Vercel, Railway, or any Node.js hosting platform
- **Frontend**: Vercel, Netlify (configured in `frontend/.netlify/`)
- **Database**: Supabase (PostgreSQL)
- **Caching**: Redis (ioredis client)
- **Storage**: MinIO (S3-compatible) or Supabase Storage

---

*Stack analysis: 2026-01-12*
*Update after major dependency changes*
