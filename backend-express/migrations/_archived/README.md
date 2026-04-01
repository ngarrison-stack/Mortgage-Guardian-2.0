# Archived Migrations

These manual SQL migration files (001-005) have been superseded by the Supabase CLI baseline migration at:

    supabase/migrations/20260401092448_baseline.sql

They are preserved here for historical reference only. All future migrations should be created using `supabase migration new <name>` and will live in `supabase/migrations/`.

## Original Files

| File | Purpose |
|------|---------|
| 001_plaid_tables.sql | Plaid integration tables, RLS policies, triggers |
| 002_case_files_and_classifications.sql | Case files and document classification tables |
| 003_pipeline_state.sql | Document processing pipeline state table |
| 004_document_rls_policies.sql | RLS policies for document-related tables |
| 005_storage_bucket_policies.sql | Supabase Storage bucket isolation policies |
