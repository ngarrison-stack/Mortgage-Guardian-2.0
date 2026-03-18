---
phase: 19-frontend-ui-state-repairs
plan: 01
subsystem: ui
tags: [nextjs, postcss, tailwind-v4, build-fix]

# Dependency graph
requires:
  - phase: 18-backend-api-stability
    provides: stable backend API for frontend to connect to
provides:
  - Working Next.js frontend build with Tailwind v4
  - Deduplicated PostCSS dependency chain
affects: [19-02, 19-03, 20, 21]

# Tech tracking
tech-stack:
  added: []
  patterns: ["postcss override for dependency deduplication"]

key-files:
  created: []
  modified:
    - frontend/package.json
    - frontend/package-lock.json
    - frontend/.gitignore
    - frontend/eslint.config.mjs

key-decisions:
  - "Used npm overrides to deduplicate PostCSS rather than downgrading Next.js or Tailwind"

patterns-established:
  - "PostCSS override pattern: use package.json overrides to force single PostCSS version when Next.js and Tailwind conflict"

issues-created: []

# Metrics
duration: 4min
completed: 2026-03-18
---

# Phase 19 Plan 01: Fix Build Failure & Dependencies Summary

**Resolved Next.js build crash by deduplicating PostCSS via npm overrides — `@tailwindcss/postcss` and `next` now share `postcss@8.5.8`**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-18T09:11:58Z
- **Completed:** 2026-03-18T09:15:58Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Fixed `_lodashcurry.default is not a function` build crash caused by dual PostCSS versions
- Added `"overrides": { "postcss": "^8.5.6" }` to deduplicate PostCSS to single 8.5.8 instance
- Verified build, lint, and dev server all pass cleanly
- Added `.netlify` to `.gitignore` and eslint ignores for clean lint output

## Task Commits

Each task was committed atomically:

1. **Task 1: Diagnose and fix the build crash** - `f1b1e0c` (fix)
2. **Task 2: Verify build output and lint** - `79a6b80` (fix)

## Files Created/Modified
- `frontend/package.json` - Added postcss override to resolve version conflict
- `frontend/package-lock.json` - Regenerated with deduplicated postcss
- `frontend/.gitignore` - Added `.netlify` directory
- `frontend/eslint.config.mjs` - Added `.netlify/**` to eslint ignores

## Decisions Made
- Used npm `overrides` to force PostCSS deduplication rather than downgrading Next.js or Tailwind — this is the least invasive fix that preserves all existing Tailwind v4 syntax (`@import "tailwindcss"`, `@theme inline`)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness
- Frontend build is now functional — ready for 19-02 (Environment Security & Configuration)
- All Tailwind v4 CSS features work correctly
- No blockers

---
*Phase: 19-frontend-ui-state-repairs*
*Completed: 2026-03-18*
