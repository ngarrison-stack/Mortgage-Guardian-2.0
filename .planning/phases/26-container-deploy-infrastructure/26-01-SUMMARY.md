---
phase: 26-container-deploy-infrastructure
plan: 01
subsystem: infra
tags: [docker, multi-stage, node-alpine, next-standalone, clerk]

# Dependency graph
requires:
  - phase: 25-environment-config-management
    provides: env validation (envValidator.js, env.ts) that runs at container startup
provides:
  - Production Dockerfiles for backend and frontend services
  - .dockerignore files preventing sensitive/test files in images
  - Next.js standalone output configuration
affects: [26-02-docker-compose, deployment, CI/CD]

# Tech tracking
tech-stack:
  added: []
  patterns: [multi-stage Docker builds, non-root container user, Docker healthcheck]

key-files:
  created:
    - backend-express/.dockerignore
    - frontend/Dockerfile
    - frontend/.dockerignore
  modified:
    - backend-express/Dockerfile
    - frontend/next.config.ts
    - frontend/package.json

key-decisions:
  - "Upgraded @clerk/nextjs 6.34.5 → 6.39.1 to fix Next.js 16 Turbopack Server Actions build error"
  - "Used --legacy-peer-deps in frontend Dockerfile due to Clerk 6.39.1 react peer dep range (~19.1.4 vs 19.1.0)"
  - "Backend image 421MB due to native deps (argon2/napi-rs 48MB, pdf-parse 57MB) — unavoidable with current stack"
  - "Frontend uses format-valid Clerk placeholder keys for build — real values must be passed as build args"

patterns-established:
  - "Multi-stage Docker: deps → builder → runtime pattern for Node.js services"
  - "Non-root user: appuser (1001) in all production containers"

issues-created: []

# Metrics
duration: 15min
completed: 2026-04-03
---

# Phase 26-01: Production Dockerfiles Summary

**Multi-stage Dockerfiles for backend (Node.js/Express) and frontend (Next.js standalone) with non-root user, healthcheck, and .dockerignore**

## Performance

- **Duration:** 15 min
- **Started:** 2026-04-03T11:30:00Z
- **Completed:** 2026-04-03T11:45:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Production-optimized multi-stage Dockerfiles for both services
- Backend: 421MB image with healthcheck, non-root user, direct `node server.js` CMD
- Frontend: 274MB standalone Next.js image with non-root user
- Fixed Clerk/Next.js 16 Turbopack build compatibility by upgrading @clerk/nextjs

## Task Commits

Each task was committed atomically:

1. **Task 1: Backend Dockerfile and .dockerignore** - `2df5fee` (feat)
2. **Task 2: Frontend Dockerfile and .dockerignore** - `657eab1` (feat)

**Plan metadata:** (pending)

## Files Created/Modified
- `backend-express/Dockerfile` - Multi-stage production build (replaced basic single-stage)
- `backend-express/.dockerignore` - Excludes tests, env files, docs from context
- `backend-express/package-lock.json` - Regenerated to fix sync issue
- `frontend/Dockerfile` - 3-stage build: deps → builder → standalone runtime
- `frontend/.dockerignore` - Excludes node_modules, .next, env files
- `frontend/next.config.ts` - Added `output: "standalone"` for Docker
- `frontend/package.json` - @clerk/nextjs upgraded to 6.39.1
- `frontend/package-lock.json` - Regenerated for Clerk upgrade

## Decisions Made
- Upgraded @clerk/nextjs 6.34.5 → 6.39.1 to fix "Server Actions must be async functions" build error in Next.js 16
- Used `--legacy-peer-deps` in frontend Docker npm ci due to Clerk peer dep range mismatch with react 19.1.0
- Backend image at 421MB exceeds 200MB plan target — unavoidable due to native deps (argon2, pdf-parse, plaid)
- Used format-valid Clerk placeholder keys (same as CI workflow) for build-time validation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Backend package-lock.json out of sync**
- **Found during:** Task 1 (Backend Dockerfile build)
- **Issue:** `npm ci` failed — lock file had stale versions for express-rate-limit, file-type, ip-address
- **Fix:** Ran `npm install` to regenerate lock file
- **Files modified:** backend-express/package-lock.json
- **Verification:** Docker build succeeds
- **Committed in:** `2df5fee`

**2. [Rule 1 - Bug fix] Clerk/Next.js 16 Turbopack incompatibility**
- **Found during:** Task 2 (Frontend Dockerfile build)
- **Issue:** @clerk/nextjs 6.34.5 has non-async `formatMetadataHeaders()` flagged as Server Action by Next.js 16
- **Fix:** Upgraded @clerk/nextjs to 6.39.1 which fixes the issue
- **Files modified:** frontend/package.json, frontend/package-lock.json
- **Verification:** `next build --turbopack` succeeds locally and in Docker
- **Committed in:** `657eab1`

**3. [Rule 3 - Blocking] Clerk key format validation at build time**
- **Found during:** Task 2 (Frontend Dockerfile build)
- **Issue:** Placeholder `pk_test_placeholder` rejected by Clerk at build time
- **Fix:** Used format-valid placeholder from CI workflow: `pk_test_Y2ktcGxhY2Vob2xkZXItMDAuY2xlcmsuYWNjb3VudHMuZGV2JA==`
- **Files modified:** frontend/Dockerfile
- **Verification:** Build completes, static pages render
- **Committed in:** `657eab1`

---

**Total deviations:** 3 auto-fixed (1 bug fix, 2 blocking), 0 deferred
**Impact on plan:** All auto-fixes necessary for builds to succeed. No scope creep.

## Issues Encountered
- Backend image size (421MB) exceeds plan's 200MB target — driven by production dependencies with native bindings. No actionable fix without removing features.

## Next Phase Readiness
- Both Dockerfiles verified building successfully
- Ready for Plan 26-02 (Docker Compose & Deployment Guide)
- Images can be pushed to any container registry

---
*Phase: 26-container-deploy-infrastructure*
*Completed: 2026-04-03*
