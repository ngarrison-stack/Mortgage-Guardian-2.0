-- =============================================
-- Case Files & Document Classifications Migration
-- =============================================
-- Run this migration in Supabase SQL editor
-- Created: 2026-02-27
-- Phase: 10-01 (Document Intake & Classification Pipeline)
--
-- Purpose: Establish the relational model that groups documents into
-- per-borrower audit cases, with classification metadata that powers
-- downstream forensic analysis (Phases 11-17).
-- =============================================

-- =============================================
-- 1. case_files Table
-- =============================================
-- Organizational backbone: groups documents into per-borrower audit cases.
-- Every document in the system can belong to exactly one case file.
-- A case represents a single mortgage audit (e.g., one borrower, one loan).

CREATE TABLE IF NOT EXISTS case_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  case_name TEXT NOT NULL,
  borrower_name TEXT,
  property_address TEXT,
  loan_number TEXT,
  servicer_name TEXT,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_review', 'complete', 'archived')),
  notes TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE case_files IS
  'Per-borrower audit cases — organizational backbone for grouping mortgage documents into a single forensic analysis unit.';

-- Indexes for case_files
CREATE INDEX IF NOT EXISTS idx_case_files_user_status
  ON case_files (user_id, status);

CREATE INDEX IF NOT EXISTS idx_case_files_user_created
  ON case_files (user_id, created_at DESC);

-- =============================================
-- 2. document_classifications Table
-- =============================================
-- Stores AI-generated (or manual) document type classifications.
-- Each document can have one classification record linking it to a
-- broad category (e.g., "origination") and specific subtype (e.g., "note").
-- Extracted metadata captures key fields pulled from the document.

CREATE TABLE IF NOT EXISTS document_classifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id TEXT NOT NULL,
  classification_type TEXT NOT NULL,
  classification_subtype TEXT,
  confidence NUMERIC(4,3)
    CHECK (confidence >= 0 AND confidence <= 1),
  extracted_metadata JSONB DEFAULT '{}',
  classified_by TEXT NOT NULL DEFAULT 'claude',
  classified_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE document_classifications IS
  'AI or manual document type classifications — maps each document to a category/subtype with confidence score and extracted key fields.';

-- Indexes for document_classifications
CREATE INDEX IF NOT EXISTS idx_doc_classifications_document_id
  ON document_classifications (document_id);

CREATE INDEX IF NOT EXISTS idx_doc_classifications_type
  ON document_classifications (classification_type);

-- =============================================
-- 3. Alter documents Table — Add case & classification links
-- =============================================
-- Add foreign key columns linking documents to their case file and
-- classification record. ON DELETE SET NULL ensures documents survive
-- if a case or classification is removed.

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS case_id UUID REFERENCES case_files(id) ON DELETE SET NULL;

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS classification_id UUID REFERENCES document_classifications(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_documents_case_id
  ON documents (case_id);

-- =============================================
-- 4. Apply updated_at trigger to case_files
-- =============================================
-- Reuse the trigger function created in 001_plaid_tables.sql.
-- The function update_updated_at_column() already exists.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'update_case_files_updated_at'
  ) THEN
    CREATE TRIGGER update_case_files_updated_at
      BEFORE UPDATE ON case_files
      FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
END
$$;

-- =============================================
-- Migration Notes:
-- =============================================
-- 1. Run this in Supabase SQL editor AFTER 001_plaid_tables.sql
-- 2. The documents table must already exist (created by app bootstrap)
-- 3. document_classifications.document_id references documents.document_id
--    at the application level (no FK constraint — documents.document_id
--    may not have a formal PK constraint)
-- 4. RLS policies for case_files and document_classifications should be
--    added in Phase 11 (Isolated Secure Document Storage)
-- =============================================
