# Plan 27-02 Summary: Sentry Error Tracking Integration

---
requires: [27-01]
provides: [sentry-error-tracking, global-error-boundary, frontend-error-capture]
affects: [phase-28]
---

Backend and frontend Sentry error tracking with graceful degradation when DSN is not configured.

## Performance

- **Duration**: ~8 min
- **Started**: 2026-04-04
- **Completed**: 2026-04-04

## Accomplishments

- Integrated @sentry/node into Express backend with expressIntegration
- Created graceful init pattern — logs info message and runs fine when SENTRY_DSN is not set
- Added Sentry error handler middleware positioned after routes, before custom error handler
- Added request context enrichment (requestId, userId, method, path) — no PII captured
- Disabled Sentry in test environment to avoid test noise
- Integrated @sentry/nextjs into Next.js frontend with side-effect import in layout
- Created global-error.tsx error boundary that captures exceptions to Sentry
- Session Replay explicitly disabled (replaysSessionSampleRate: 0, replaysOnErrorSampleRate: 0)
- Added SENTRY_DSN and NEXT_PUBLIC_SENTRY_DSN to env validation, .env.example files, and ENV-GUIDE.md
- Both variables are optional — app runs identically without them

## Task Commits

| Task | Commit | Hash |
|------|--------|------|
| Backend Sentry integration | feat(27-02): backend Sentry error tracking integration | 93c6f37 |
| Frontend Sentry integration | feat(27-02): frontend Sentry integration with global error boundary | 7c9de4d |

## Files Created

- `backend-express/utils/sentry.js` — initSentry, sentryErrorHandler, addSentryContext
- `frontend/src/lib/sentry.ts` — conditional Sentry.init with DSN check
- `frontend/src/app/global-error.tsx` — Next.js global error boundary with Sentry capture

## Files Modified

- `backend-express/server.js` — Sentry init, error handler, context enrichment
- `backend-express/utils/envValidator.js` — SENTRY_DSN as optional URI
- `backend-express/.env.example` — SENTRY_DSN section
- `backend-express/package.json` — @sentry/node dependency
- `frontend/src/app/layout.tsx` — sentry side-effect import
- `frontend/src/lib/env.ts` — NEXT_PUBLIC_SENTRY_DSN optional variable
- `frontend/.env.example` — NEXT_PUBLIC_SENTRY_DSN section
- `frontend/package.json` — @sentry/nextjs dependency
- `ENV-GUIDE.md` — Sentry entries in backend/frontend tables and environment matrix

## Decisions Made

- Used side-effect import (`import '@/lib/sentry'`) in layout.tsx instead of Sentry wizard config files (sentry.client.config.ts etc.) — simpler, fewer files, same effect
- Set tracesSampleRate to 0.1 (10%) for both backend and frontend to limit volume
- Classified SENTRY_DSN as production-only tier in envValidator but kept it optional (not enforced even in production) since the app works without it
- Did not add Sentry as a Winston transport — error tracking and logging remain separate concerns

## Phase 27 Status

**Phase 27 (Monitoring & Observability) is now COMPLETE** — 2/2 plans done.
- 27-01: Enhanced Health Checks & Request Metrics
- 27-02: Sentry Error Tracking Integration

Ready for Phase 28 (Performance & Load Testing).
