-- =============================================
-- Row Level Security Policies for Document Tables
-- =============================================
-- Run this migration in Supabase SQL editor
-- Created: 2026-02-27
-- Phase: 11-01 (Isolated Secure Document Storage)
--
-- Purpose: Enforce per-user data isolation at the database level for all
-- document-related tables. Defense-in-depth — even if the service key is
-- compromised, the database enforces that users can only access their own data.
--
-- Note: service_role key already bypasses RLS by default in Supabase,
-- so no service_role bypass policy is needed.
-- =============================================

-- =============================================
-- 1. documents Table — RLS Policies
-- =============================================

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'documents' AND policyname = 'Users can view own documents'
  ) THEN
    CREATE POLICY "Users can view own documents" ON documents
      FOR SELECT USING (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'documents' AND policyname = 'Users can insert own documents'
  ) THEN
    CREATE POLICY "Users can insert own documents" ON documents
      FOR INSERT WITH CHECK (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'documents' AND policyname = 'Users can update own documents'
  ) THEN
    CREATE POLICY "Users can update own documents" ON documents
      FOR UPDATE USING (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'documents' AND policyname = 'Users can delete own documents'
  ) THEN
    CREATE POLICY "Users can delete own documents" ON documents
      FOR DELETE USING (auth.uid()::text = user_id);
  END IF;
END
$$;

-- =============================================
-- 2. case_files Table — RLS Policies
-- =============================================

ALTER TABLE case_files ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'case_files' AND policyname = 'Users can view own case files'
  ) THEN
    CREATE POLICY "Users can view own case files" ON case_files
      FOR SELECT USING (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'case_files' AND policyname = 'Users can insert own case files'
  ) THEN
    CREATE POLICY "Users can insert own case files" ON case_files
      FOR INSERT WITH CHECK (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'case_files' AND policyname = 'Users can update own case files'
  ) THEN
    CREATE POLICY "Users can update own case files" ON case_files
      FOR UPDATE USING (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'case_files' AND policyname = 'Users can delete own case files'
  ) THEN
    CREATE POLICY "Users can delete own case files" ON case_files
      FOR DELETE USING (auth.uid()::text = user_id);
  END IF;
END
$$;

-- =============================================
-- 3. document_classifications Table — RLS Policies
-- =============================================
-- Note: document_classifications does NOT have its own user_id column.
-- Ownership is determined by joining through the documents table via document_id.

ALTER TABLE document_classifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'document_classifications' AND policyname = 'Users can view own document classifications'
  ) THEN
    CREATE POLICY "Users can view own document classifications" ON document_classifications
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM documents d
          WHERE d.document_id = document_classifications.document_id
            AND d.user_id = auth.uid()::text
        )
      );
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'document_classifications' AND policyname = 'Users can insert own document classifications'
  ) THEN
    CREATE POLICY "Users can insert own document classifications" ON document_classifications
      FOR INSERT WITH CHECK (
        EXISTS (
          SELECT 1 FROM documents d
          WHERE d.document_id = document_classifications.document_id
            AND d.user_id = auth.uid()::text
        )
      );
  END IF;
END
$$;

-- =============================================
-- 4. pipeline_state Table — RLS Policies
-- =============================================

ALTER TABLE pipeline_state ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'pipeline_state' AND policyname = 'Users can view own pipeline state'
  ) THEN
    CREATE POLICY "Users can view own pipeline state" ON pipeline_state
      FOR SELECT USING (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'pipeline_state' AND policyname = 'Users can insert own pipeline state'
  ) THEN
    CREATE POLICY "Users can insert own pipeline state" ON pipeline_state
      FOR INSERT WITH CHECK (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'pipeline_state' AND policyname = 'Users can update own pipeline state'
  ) THEN
    CREATE POLICY "Users can update own pipeline state" ON pipeline_state
      FOR UPDATE USING (auth.uid()::text = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'pipeline_state' AND policyname = 'Users can delete own pipeline state'
  ) THEN
    CREATE POLICY "Users can delete own pipeline state" ON pipeline_state
      FOR DELETE USING (auth.uid()::text = user_id);
  END IF;
END
$$;

-- =============================================
-- Migration Notes:
-- =============================================
-- 1. Run this in Supabase SQL editor AFTER 003_pipeline_state.sql
-- 2. All policies use auth.uid()::text to match the TEXT user_id columns
-- 3. document_classifications uses EXISTS join through documents table
--    because it has no direct user_id column
-- 4. service_role key bypasses RLS by default — no bypass policy needed
-- 5. Idempotent: safe to re-run (DO $$ guards check pg_policies)
-- 6. RLS integration testing requires a live Supabase instance
-- =============================================
