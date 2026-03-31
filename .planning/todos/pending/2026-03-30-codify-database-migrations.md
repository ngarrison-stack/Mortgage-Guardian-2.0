---
created: 2026-03-30T01:45
title: Codify Supabase database migrations
area: database
files:
  - backend-express/services/caseFileService.js
  - backend-express/__tests__/migrations/rls-policies.test.js
---

## Problem

No Supabase migration files visible in the repo. Schema is likely managed through the Supabase dashboard, which means: no version control on schema changes, no reproducible environment setup, no way to spin up a fresh database for testing or staging without manual work. RLS policy tests exist but reference policies that aren't codified.

## Solution

Export current Supabase schema as migration files:
- Use `supabase db dump` or manually script CREATE TABLE statements
- Include RLS policies (already tested in rls-policies.test.js)
- Add to `database/migrations/` directory
- Document setup process for new environments
- Consider Supabase CLI for local development workflow
