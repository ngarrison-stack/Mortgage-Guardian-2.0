-- =============================================
-- Baseline Migration — Mortgage Guardian 2.0
-- =============================================
-- Consolidates manual migrations 001–005 from backend-express/migrations/
-- into a single Supabase CLI migration.
--
-- Source files:
--   001_plaid_tables.sql
--   002_case_files_and_classifications.sql
--   003_pipeline_state.sql
--   004_document_rls_policies.sql
--   005_storage_bucket_policies.sql
--   + users & documents tables from QUICK-START bootstrap
--
-- Created: 2026-04-01
-- =============================================

-- ===================
-- Extensions
-- ===================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- ===================
-- Functions
-- ===================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Tables (dependency order)
-- =============================================

-- 1. users — referenced by documents FK
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT UNIQUE NOT NULL,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. documents — referenced by case_files/classifications FKs
CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id TEXT UNIQUE NOT NULL,
  user_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  document_type TEXT,
  analysis_results JSONB,
  metadata JSONB,
  storage_path TEXT,
  encrypted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at DESC);

-- 3. plaid_items — independent table
CREATE TABLE IF NOT EXISTS plaid_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  item_id VARCHAR(255) UNIQUE NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  access_token TEXT NOT NULL,
  status VARCHAR(50) DEFAULT 'active',
  institution_id VARCHAR(255),
  error JSONB,
  requires_user_action BOOLEAN DEFAULT FALSE,
  last_webhook_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_plaid_items_user_id ON plaid_items(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_items_status ON plaid_items(status);
CREATE INDEX IF NOT EXISTS idx_plaid_items_item_id ON plaid_items(item_id);

-- 4. plaid_accounts — depends on plaid_items
CREATE TABLE IF NOT EXISTS plaid_accounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id VARCHAR(255) UNIQUE NOT NULL,
  item_id VARCHAR(255) NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  official_name VARCHAR(255),
  type VARCHAR(50),
  subtype VARCHAR(50),
  mask VARCHAR(10),
  current_balance DECIMAL(15, 2),
  available_balance DECIMAL(15, 2),
  "limit" DECIMAL(15, 2),
  iso_currency_code VARCHAR(3),
  unofficial_currency_code VARCHAR(10),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (item_id) REFERENCES plaid_items(item_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_plaid_accounts_user_id ON plaid_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_accounts_item_id ON plaid_accounts(item_id);
CREATE INDEX IF NOT EXISTS idx_plaid_accounts_account_id ON plaid_accounts(account_id);

-- 5. plaid_transactions — depends on plaid_items, plaid_accounts
CREATE TABLE IF NOT EXISTS plaid_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  transaction_id VARCHAR(255) UNIQUE NOT NULL,
  item_id VARCHAR(255) NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  account_id VARCHAR(255) NOT NULL,
  amount DECIMAL(15, 2),
  iso_currency_code VARCHAR(3),
  unofficial_currency_code VARCHAR(10),
  category JSONB,
  category_id VARCHAR(50),
  transaction_type VARCHAR(50),
  name TEXT,
  merchant_name VARCHAR(255),
  date DATE,
  authorized_date DATE,
  authorized_datetime TIMESTAMP WITH TIME ZONE,
  datetime TIMESTAMP WITH TIME ZONE,
  payment_channel VARCHAR(50),
  location JSONB,
  payment_meta JSONB,
  account_owner VARCHAR(255),
  pending BOOLEAN DEFAULT FALSE,
  pending_transaction_id VARCHAR(255),
  transaction_code VARCHAR(50),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (item_id) REFERENCES plaid_items(item_id) ON DELETE CASCADE,
  FOREIGN KEY (account_id) REFERENCES plaid_accounts(account_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_plaid_transactions_user_id ON plaid_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_transactions_item_id ON plaid_transactions(item_id);
CREATE INDEX IF NOT EXISTS idx_plaid_transactions_account_id ON plaid_transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_plaid_transactions_date ON plaid_transactions(date DESC);
CREATE INDEX IF NOT EXISTS idx_plaid_transactions_transaction_id ON plaid_transactions(transaction_id);

-- 6. notifications — references plaid_items loosely (no FK)
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  item_id VARCHAR(255),
  type VARCHAR(50),
  message TEXT,
  priority VARCHAR(20) DEFAULT 'medium',
  read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- 7. case_files — independent table
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

CREATE INDEX IF NOT EXISTS idx_case_files_user_status ON case_files(user_id, status);
CREATE INDEX IF NOT EXISTS idx_case_files_user_created ON case_files(user_id, created_at DESC);

-- 8. document_classifications — independent (app-level link to documents)
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

CREATE INDEX IF NOT EXISTS idx_doc_classifications_document_id ON document_classifications(document_id);
CREATE INDEX IF NOT EXISTS idx_doc_classifications_type ON document_classifications(classification_type);

-- 9. Add case & classification link columns to documents
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS case_id UUID REFERENCES case_files(id) ON DELETE SET NULL;

ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS classification_id UUID REFERENCES document_classifications(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_documents_case_id ON documents(case_id);

-- 10. pipeline_state — depends on case_files
CREATE TABLE IF NOT EXISTS pipeline_state (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id text UNIQUE NOT NULL,
  user_id text NOT NULL,
  document_type text,
  file_name text,
  status text NOT NULL DEFAULT 'uploaded',
  steps jsonb DEFAULT '{}',
  extracted_text text,
  classification_results jsonb,
  analysis_results jsonb,
  case_id uuid REFERENCES case_files(id) ON DELETE SET NULL,
  error jsonb,
  retry_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_state_document ON pipeline_state(document_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_state_user_status ON pipeline_state(user_id, status);

-- =============================================
-- Enable Row Level Security
-- =============================================

ALTER TABLE plaid_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE plaid_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE plaid_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE case_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_classifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_state ENABLE ROW LEVEL SECURITY;

-- =============================================
-- RLS Policies — plaid_items
-- =============================================

CREATE POLICY "Users can view own plaid items" ON plaid_items
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own plaid items" ON plaid_items
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own plaid items" ON plaid_items
  FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own plaid items" ON plaid_items
  FOR DELETE USING (auth.uid()::text = user_id);

-- =============================================
-- RLS Policies — plaid_accounts
-- =============================================

CREATE POLICY "Users can view own accounts" ON plaid_accounts
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own accounts" ON plaid_accounts
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own accounts" ON plaid_accounts
  FOR UPDATE USING (auth.uid()::text = user_id);

-- =============================================
-- RLS Policies — plaid_transactions
-- =============================================

CREATE POLICY "Users can view own transactions" ON plaid_transactions
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own transactions" ON plaid_transactions
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- =============================================
-- RLS Policies — notifications
-- =============================================

CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid()::text = user_id);

-- =============================================
-- RLS Policies — documents
-- =============================================

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
-- RLS Policies — case_files
-- =============================================

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
-- RLS Policies — document_classifications
-- =============================================

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
-- RLS Policies — pipeline_state
-- =============================================

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
-- Storage Bucket Policies
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
-- Triggers
-- =============================================

CREATE TRIGGER update_documents_updated_at
  BEFORE UPDATE ON documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_plaid_items_updated_at
  BEFORE UPDATE ON plaid_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_plaid_accounts_updated_at
  BEFORE UPDATE ON plaid_accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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

CREATE TRIGGER set_pipeline_state_updated_at
  BEFORE UPDATE ON pipeline_state
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
