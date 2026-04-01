-- =============================================
-- Supabase Storage Bucket Isolation Policies
-- =============================================
-- Run this migration in Supabase SQL editor
-- Created: 2026-02-27
-- Phase: 11-02 (Isolated Secure Document Storage)
--
-- Purpose: Enforce per-user document isolation at the Supabase Storage level.
-- These policies apply to the internal `storage.objects` table and restrict
-- access based on the userId embedded in the storage path.
--
-- Storage path convention: documents/{userId}/{documentId}
-- The `storage.foldername(name)` function returns folder segments as a
-- PostgreSQL text array. For path 'documents/user123/doc456':
--   foldername returns ARRAY['documents', 'user123']
--   [1] = 'documents' (bucket prefix)
--   [2] = 'user123'   (userId)
--
-- Note: These policies apply to anon and authenticated key access only.
-- The service_role key (used by the Express backend) bypasses RLS/storage
-- policies by default in Supabase. This is by design — the backend performs
-- its own authorization checks before issuing storage operations.
-- =============================================

-- =============================================
-- 1. SELECT — Users can download their own documents
-- =============================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Users can download own documents'
  ) THEN
    CREATE POLICY "Users can download own documents" ON storage.objects
      FOR SELECT USING (
        bucket_id = 'documents' AND
        (storage.foldername(name))[2] = auth.uid()::text
      );
  END IF;
END
$$;

-- =============================================
-- 2. INSERT — Users can upload to their own folder
-- =============================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Users can upload own documents'
  ) THEN
    CREATE POLICY "Users can upload own documents" ON storage.objects
      FOR INSERT WITH CHECK (
        bucket_id = 'documents' AND
        (storage.foldername(name))[2] = auth.uid()::text
      );
  END IF;
END
$$;

-- =============================================
-- 3. UPDATE — Users can update their own documents
-- =============================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Users can update own documents'
  ) THEN
    CREATE POLICY "Users can update own documents" ON storage.objects
      FOR UPDATE USING (
        bucket_id = 'documents' AND
        (storage.foldername(name))[2] = auth.uid()::text
      );
  END IF;
END
$$;

-- =============================================
-- 4. DELETE — Users can delete their own documents
-- =============================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Users can delete own documents'
  ) THEN
    CREATE POLICY "Users can delete own documents" ON storage.objects
      FOR DELETE USING (
        bucket_id = 'documents' AND
        (storage.foldername(name))[2] = auth.uid()::text
      );
  END IF;
END
$$;

-- =============================================
-- Migration Notes:
-- =============================================
-- 1. Run this in Supabase SQL editor AFTER 004_document_rls_policies.sql
-- 2. Policies target storage.objects (Supabase internal table for Storage)
-- 3. storage.foldername(name)[2] extracts userId from path segment
-- 4. bucket_id filter ensures policies only apply to 'documents' bucket
-- 5. service_role key bypasses these policies — backend uses service_role
-- 6. Idempotent: safe to re-run (DO $$ guards check pg_policies)
-- 7. schemaname = 'storage' is included in pg_policies check to avoid
--    collisions with same-named policies on other schemas
-- =============================================
