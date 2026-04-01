# Supabase Migrations

Database schema management for Mortgage Guardian 2.0 using the Supabase CLI.

## Overview

All database schema changes are managed through timestamped SQL migration files in `supabase/migrations/`. The baseline migration consolidates the original manual migrations (001-005) that were previously applied via the Supabase SQL editor.

The rollback directory (`supabase/rollback/`) contains corresponding down-migration scripts for reversing changes when needed.

## Fresh Setup

```bash
# 1. Install Supabase CLI (if not already installed)
brew install supabase/tap/supabase

# 2. Log in to Supabase
supabase login

# 3. Link to the project
supabase link --project-ref huosfjdcnjzdzhkkjaqh

# 4. Apply all migrations to the remote database
supabase db push

# 5. (Alternative) Reset local database to match migrations
supabase db reset
```

## Creating New Migrations

```bash
# Generate a new timestamped migration file
supabase migration new <descriptive_name>

# Edit the generated file in supabase/migrations/
# Then push to remote
supabase db push
```

Always test migrations locally first with `supabase db reset` before pushing to remote.

## Rolling Back

Rollback scripts live in `supabase/rollback/` and must be applied manually:

```bash
# Connect to the remote database and run the rollback SQL
supabase db execute --file supabase/rollback/baseline_down.sql
```

Rollback scripts are not managed by the Supabase migration system. They are a manual safety net. Always review the rollback script before executing it, as rollbacks are destructive.

## Migration Files

| File | Description |
|------|-------------|
| `migrations/20260401092448_baseline.sql` | Baseline: all tables, indexes, RLS, triggers |
| `rollback/baseline_down.sql` | Reverses the baseline migration |

## Conventions

1. **One migration per change** -- each migration should be a single logical unit (new table, new policy, schema alteration).
2. **Idempotent when possible** -- use `IF NOT EXISTS` / `IF EXISTS` guards so migrations can be safely re-run.
3. **Dependency order** -- create tables before their dependents; drop in reverse order.
4. **No Supabase internals** -- never modify `auth.*` or `storage.*` system tables directly. Use RLS policies on `storage.objects` for storage access control.
5. **RLS by default** -- every new public table must have `ENABLE ROW LEVEL SECURITY` and at least one policy.
6. **Rollback scripts** -- for every up-migration, create a corresponding `rollback/<name>_down.sql`.
7. **Naming** -- use `supabase migration new <name>` to get the correct timestamp prefix. Use lowercase snake_case for the descriptive name.
8. **Testing** -- run `supabase db reset` locally to verify the full migration chain before pushing.
