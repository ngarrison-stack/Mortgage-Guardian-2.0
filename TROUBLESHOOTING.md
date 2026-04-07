# TROUBLESHOOTING.md

Common issues and solutions for Mortgage Guardian 2.0. Organized by symptom category for quick lookup.

> For environment variable details, see [ENV-GUIDE.md](ENV-GUIDE.md).
> For deployment procedures, see [DEPLOY.md](DEPLOY.md).
> For incident response, see [RUNBOOK.md](RUNBOOK.md).

---

## 1. Build & Startup Issues

### Problem: Docker build fails with "npm ci" error

**Cause:** `package-lock.json` is out of sync with `package.json`, or a dependency requires a newer Node.js version than the Docker image provides.

**Fix:**
1. Run `npm install` locally to regenerate `package-lock.json`
2. Commit the updated lockfile
3. Rebuild: `docker build -t mg-backend ./backend-express`

### Problem: Server won't start — "Environment validation failed"

**Cause:** Required environment variables are missing or malformed. The Joi-based validator in `backend-express/utils/envValidator.js` enforces four tiers: required, feature, optional, and production-only.

**Fix:**
1. Read the error message — it lists exactly which variables failed validation
2. Check `backend-express/.env` against `ENV-GUIDE.md` section 2
3. Required variables: `SUPABASE_URL` (must be `https://`), `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`, `DOCUMENT_ENCRYPTION_KEY` (must be exactly 64 hex characters)
4. Generate encryption key if missing: `openssl rand -hex 32`

### Problem: Frontend build fails — "Missing Clerk publishable key"

**Cause:** Clerk validates key format at build time. `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` must start with `pk_` and `CLERK_SECRET_KEY` must start with `sk_`.

**Fix:**
1. Copy `frontend/.env.example` to `frontend/.env`
2. Set `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_your-key` (get from [Clerk Dashboard](https://dashboard.clerk.com/))
3. Set `CLERK_SECRET_KEY=sk_test_your-key`
4. For CI, use synthetic format-valid values: `pk_test_ci_placeholder`, `sk_test_ci_placeholder`

### Problem: npm install fails with peer dependency conflicts

**Cause:** Node.js version mismatch or conflicting peer dependencies between packages.

**Fix:**
1. Verify Node.js version: `node -v` (project uses Node 20)
2. Delete `node_modules` and `package-lock.json`: `rm -rf node_modules package-lock.json`
3. Reinstall: `npm install`
4. If peer conflicts persist, check the specific package versions in the error output

---

## 2. Authentication Issues

### Problem: 401 Unauthorized on all /v1/ API requests

**Cause:** The `requireAuth` middleware is applied to all `/v1/` routes. Requests must include a valid JWT in the `Authorization: Bearer <token>` header.

**Fix:**
1. Verify the request includes `Authorization: Bearer <token>` header
2. Check that `SUPABASE_SERVICE_KEY` is set correctly in `.env`
3. Confirm the JWT has not expired
4. For development testing, use the Supabase anon key to generate a test token

### Problem: Clerk authentication not working in frontend

**Cause:** Clerk keys are invalid, or the publishable key does not match the environment.

**Fix:**
1. Confirm `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` starts with `pk_test_` (development) or `pk_live_` (production)
2. Confirm `CLERK_SECRET_KEY` starts with `sk_test_` or `sk_live_` matching the publishable key environment
3. Check the [Clerk Dashboard](https://dashboard.clerk.com/) for the correct keys
4. Restart the Next.js dev server after changing env vars

### Problem: CORS errors — "blocked by CORS policy"

**Cause:** The `ALLOWED_ORIGINS` variable does not include the requesting origin. In development, it defaults to `*` (wildcard). In production, it must list explicit origins.

**Fix:**
1. Check `ALLOWED_ORIGINS` in `backend-express/.env`
2. For local dev: set `ALLOWED_ORIGINS=*` or `ALLOWED_ORIGINS=http://localhost:3001`
3. For production: set comma-separated origins, e.g., `ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com`
4. Note: wildcard `*` must NOT be used in production (env validator enforces this)

---

## 3. Integration Issues

### Problem: Claude AI analysis returns errors or times out

**Cause:** `ANTHROPIC_API_KEY` is missing or invalid. This is a "feature" tier variable — the server starts without it but AI features are disabled.

**Fix:**
1. Check for warning in server logs: "ANTHROPIC_API_KEY missing — AI document analysis will be unavailable"
2. Get a valid key from [Anthropic Console](https://console.anthropic.com/)
3. Set `ANTHROPIC_API_KEY=sk-ant-...` in `backend-express/.env`
4. Restart the server

### Problem: Plaid bank linking fails

**Cause:** Plaid credentials are missing or the environment does not match. `PLAID_CLIENT_ID`, `PLAID_SECRET`, and `PLAID_ENV` are all needed for banking features.

**Fix:**
1. Check server logs for: "PLAID_CLIENT_ID and/or PLAID_SECRET missing — banking integration will be unavailable"
2. Get credentials from [Plaid Dashboard](https://dashboard.plaid.com/team/keys)
3. Set `PLAID_ENV=sandbox` for development, `PLAID_ENV=production` for live
4. Ensure `PLAID_CLIENT_ID`, `PLAID_SECRET`, and `PLAID_ENV` are all set in `backend-express/.env`

### Problem: Supabase connection refused or timeout

**Cause:** `SUPABASE_URL` is wrong, the project is paused, or network access is blocked.

**Fix:**
1. Verify `SUPABASE_URL` starts with `https://` and points to a valid project
2. Check if the Supabase project is active (not paused) in the [Supabase Dashboard](https://app.supabase.com/)
3. Confirm `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_KEY` match the project URL
4. Test connectivity: `curl -s https://your-project.supabase.co/rest/v1/ -H "apikey: your-anon-key"`

### Problem: Redis connection failed

**Cause:** Redis is not running or the connection variables are wrong. Redis is optional — the server runs without it but caching and rate limiting degrade.

**Fix:**
1. For Docker Compose: verify Redis container is healthy: `docker-compose ps`
2. Check `REDIS_HOST` (default: `localhost`), `REDIS_PORT` (default: `6379`), `REDIS_PASSWORD`
3. Test connectivity: `redis-cli -h localhost -p 6379 ping`
4. If not using Redis, remove `REDIS_HOST` from `.env` to suppress connection attempts

---

## 4. Runtime Issues

### Problem: High memory usage (> 100MB)

**Cause:** Large document uploads, accumulated pipeline state, or memory leaks in long-running processes.

**Fix:**
1. Check `/metrics` endpoint for current memory usage (`process_heap_used_bytes`)
2. Review document upload sizes — the body parser limit is 25MB (accommodates base64 overhead for 20MB PDFs)
3. Restart the server to clear accumulated state
4. If recurring, check `/health/ready` for degraded subsystems

### Problem: Slow API responses (> 1 second for standard operations)

**Cause:** Database query latency, missing Redis cache, or high request volume exceeding rate limits.

**Fix:**
1. Check `/metrics` for response time percentiles (p50, p95, p99)
2. Check `/health/ready` for slow subsystem checks
3. Verify Redis is connected (provides response caching)
4. Review rate limit settings: `RATE_LIMIT_WINDOW_MS` (default 900000ms) and `RATE_LIMIT_MAX_REQUESTS` (default 100)

### Problem: File upload fails — "Request entity too large"

**Cause:** The uploaded file exceeds the 25MB body parser limit configured in `server.js`.

**Fix:**
1. Verify file size is under 20MB (25MB limit accounts for base64 encoding overhead)
2. For larger files, compress or split the document before uploading
3. Check that `Content-Type: application/json` is set when sending base64-encoded documents

---

## 5. Development Environment

### Problem: Tests fail locally but pass in CI (or vice versa)

**Cause:** Environment differences — different Node.js version, missing test env vars, or timezone issues.

**Fix:**
1. Verify Node.js version matches CI: `node -v` (project uses Node 20)
2. Ensure `NODE_ENV=test` is set (env validation is skipped in test mode)
3. Run the full suite: `cd backend-express && npm test`
4. If specific tests fail, check for time-dependent assertions or missing mock data

### Problem: Docker Compose services can't communicate

**Cause:** Services are not on the same Docker network, or health checks are failing so dependent services haven't started.

**Fix:**
1. Check service status: `docker-compose ps` — all services should show "Up (healthy)"
2. Verify the `docker-compose.yml` network configuration
3. Use service names (not `localhost`) for inter-container communication: e.g., `redis` not `localhost` for Redis host
4. Check logs: `docker-compose logs <service-name>`

### Problem: Hot reload not working in development

**Cause:** Nodemon or Next.js file watcher is not detecting changes, often due to Docker volume mounts or filesystem events not propagating.

**Fix:**
1. Backend: verify `npm run dev` uses nodemon — check `backend-express/package.json` scripts
2. Frontend: verify `npm run dev` uses Turbopack — `next dev --turbopack`
3. In Docker: ensure source code is mounted as a volume, not copied into the image
4. On macOS with Docker: check that file sharing is enabled for the project directory in Docker Desktop settings

---

*Last updated: 2026-04-07 (Phase 31-02)*
