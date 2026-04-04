# Deployment Guide

## Prerequisites

- **Docker** v20+ and Docker Compose v2+ (for containerized development)
- **Node.js** 20+ and npm (for local development without Docker)
- **API Keys** (see [ENV-GUIDE.md](./ENV-GUIDE.md) for full details):
  - Anthropic (Claude AI document analysis)
  - Plaid (bank account verification)
  - Supabase (database and auth)
  - Clerk (frontend authentication)

## Local Development with Docker Compose

1. Copy environment files and fill in your API keys:

```bash
cp backend-express/.env.example backend-express/.env
cp frontend/.env.example frontend/.env
```

2. Edit both `.env` files and add your API keys. Never commit these files.

3. Start all services:

```bash
docker compose up --build
```

- Backend API: http://localhost:3000
- Frontend: http://localhost:3001

4. Rebuild after dependency changes:

```bash
docker compose up --build --force-recreate
```

5. Stop all services:

```bash
docker compose down
```

> **Note:** Docker Compose runs production-like builds inside containers. For hot-reload during active development, use the "without Docker" approach below.

## Local Development without Docker

1. Install dependencies in each directory:

```bash
cd backend-express && npm install
cd ../frontend && npm install
```

2. Copy and configure environment files as described above.

3. Start each service in a separate terminal:

```bash
# Terminal 1 - Backend
cd backend-express && npm run dev

# Terminal 2 - Frontend
cd frontend && npm run dev
```

This gives you hot-reload on file changes for both backend (nodemon) and frontend (Next.js Turbopack).

## Railway Deployment

Railway auto-detects the Dockerfile in each service directory.

1. Deploy the backend:

```bash
cd backend-express
railway login
railway init
railway up
```

2. Deploy the frontend:

```bash
cd frontend
railway login
railway init
railway up
```

3. Set environment variables in the Railway dashboard for each service.

> **Important:** `NEXT_PUBLIC_*` variables are baked into the frontend at build time. Set them as build-time variables in Railway, not just runtime variables.

## Vercel Deployment

Vercel uses its own build system (serverless, not Docker).

1. Deploy the backend:

```bash
cd backend-express
vercel --prod
```

2. Deploy the frontend:

```bash
cd frontend
vercel --prod
```

3. Set environment variables in the Vercel dashboard for each project.

## Generic Docker Host

Build and run each service independently:

```bash
# Backend
docker build -t mg-backend ./backend-express
docker run -d -p 3000:3000 --env-file backend-express/.env mg-backend

# Frontend
docker build -t mg-frontend \
  --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_xxx \
  --build-arg NEXT_PUBLIC_API_URL=https://api.example.com \
  --build-arg NEXT_PUBLIC_APP_URL=https://app.example.com \
  ./frontend
docker run -d -p 3001:3001 mg-frontend
```

> **IMPORTANT:** `NEXT_PUBLIC_*` variables are embedded into the JavaScript bundle at build time by Next.js. You must pass them as `--build-arg` values when building the frontend image. Setting them at runtime with `-e` or `--env-file` has no effect on the client-side bundle.

## Environment Variables

See [ENV-GUIDE.md](./ENV-GUIDE.md) for the complete list and descriptions.

Critical variables:

| Variable | Service | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Backend | Claude AI document analysis |
| `PLAID_CLIENT_ID` | Backend | Plaid bank integration |
| `PLAID_SECRET` | Backend | Plaid bank integration |
| `SUPABASE_URL` | Backend | Database connection |
| `SUPABASE_ANON_KEY` | Backend | Database auth |
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Frontend | Clerk authentication (build-time) |
| `CLERK_SECRET_KEY` | Frontend | Clerk authentication (runtime) |

## Troubleshooting

**Port conflicts:** If ports 3000 or 3001 are in use, stop the conflicting process or change the port mapping in `docker-compose.yml` (e.g., `"3002:3000"`).

**Docker build cache issues:** Force a clean rebuild:

```bash
docker compose build --no-cache
```

**Clerk key format:** Publishable keys start with `pk_test_` (development) or `pk_live_` (production). Secret keys start with `sk_test_` or `sk_live_`. Mismatched environments cause silent auth failures.

**Environment variables not loading:** Ensure `.env` files exist in both `backend-express/` and `frontend/` directories. Docker Compose reads them via `env_file` -- missing files cause startup errors. For `NEXT_PUBLIC_*` vars, remember they are baked at build time; changing them requires a rebuild.
