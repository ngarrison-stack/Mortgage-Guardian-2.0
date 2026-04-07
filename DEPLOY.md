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

## Pre-Deployment Checklist

Before deploying to any environment, verify:

- [ ] All tests pass: `cd backend-express && npm test`
- [ ] Backend lints cleanly: `cd backend-express && npm run lint` (if configured)
- [ ] Frontend builds: `cd frontend && npm run build`
- [ ] Environment variables are set for the target environment (see [ENV-GUIDE.md](./ENV-GUIDE.md))
- [ ] No secrets or `.env` files are committed: `git diff --cached --name-only | grep -i env`
- [ ] Docker images build: `docker compose build` or `bash scripts/validate-build.sh`
- [ ] Database migrations are applied (if applicable)
- [ ] Tag the release: `git tag -a v<version> -m "Release v<version>"`
- [ ] Note the current deployed commit hash for rollback: `git rev-parse HEAD`

## Rollback Procedures

### Docker Compose Rollback

```bash
# 1. Stop current deployment
docker compose down

# 2. Check out the previous known-good commit
git checkout <previous-commit-hash>

# 3. Rebuild and restart
docker compose up --build -d

# 4. Verify health
bash scripts/validate-deployment.sh http://localhost:3000
```

### Railway Rollback

Railway keeps deployment history in the dashboard.

1. Open the Railway dashboard for the affected service.
2. Navigate to **Deployments** and find the last successful deployment.
3. Click **Redeploy** on that deployment.
4. Alternatively, from the CLI:

```bash
# Roll back to a previous commit
git checkout <previous-commit-hash>
cd backend-express   # or frontend
railway up
```

5. Verify with `bash scripts/validate-deployment.sh <railway-url>`.

### Vercel Rollback

Vercel supports instant rollback from the dashboard.

1. Open the Vercel dashboard for the affected project.
2. Navigate to **Deployments**.
3. Find the last successful production deployment and click **Promote to Production** (three-dot menu).
4. Alternatively, redeploy from a known-good commit:

```bash
git checkout <previous-commit-hash>
cd backend-express   # or frontend
vercel --prod
```

### Generic Docker Rollback

```bash
# 1. List available image tags/digests
docker images mg-backend --format "{{.ID}} {{.CreatedAt}} {{.Tag}}"

# 2. Stop and remove the current container
docker stop mg-backend && docker rm mg-backend

# 3. Run the previous image
docker run -d --name mg-backend -p 3000:3000 --env-file backend-express/.env mg-backend:<previous-tag>

# Or rebuild from a known-good commit
git checkout <previous-commit-hash>
docker build -t mg-backend:rollback ./backend-express
docker run -d --name mg-backend -p 3000:3000 --env-file backend-express/.env mg-backend:rollback
```

> **Tip:** Always verify rollback success by running `bash scripts/validate-deployment.sh <url>`.

## Troubleshooting

**Port conflicts:** If ports 3000 or 3001 are in use, stop the conflicting process or change the port mapping in `docker-compose.yml` (e.g., `"3002:3000"`).

**Docker build cache issues:** Force a clean rebuild:

```bash
docker compose build --no-cache
```

**Clerk key format:** Publishable keys start with `pk_test_` (development) or `pk_live_` (production). Secret keys start with `sk_test_` or `sk_live_`. Mismatched environments cause silent auth failures.

**Environment variables not loading:** Ensure `.env` files exist in both `backend-express/` and `frontend/` directories. Docker Compose reads them via `env_file` -- missing files cause startup errors. For `NEXT_PUBLIC_*` vars, remember they are baked at build time; changing them requires a rebuild.
