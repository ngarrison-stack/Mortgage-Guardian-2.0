-- Mortgage Guardian 2.0 — Database Setup
-- Run against Neon (or any Postgres) to create all tables.
--
-- Usage:
--   psql $DATABASE_URL -f migrations/setup.sql

-- ==========================================================================
-- Trigger function for auto-updating updated_at
-- ==========================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================================================
-- case_files
-- ==========================================================================

CREATE TABLE IF NOT EXISTS case_files (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        TEXT NOT NULL,
  case_name      TEXT NOT NULL,
  borrower_name  TEXT,
  property_address TEXT,
  loan_number    TEXT,
  servicer_name  TEXT,
  status         TEXT NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open', 'in_review', 'complete', 'archived')),
  notes          TEXT,
  metadata       JSONB DEFAULT '{}',
  consolidated_report JSONB,
  forensic_analysis   JSONB,
  compliance_report   JSONB,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_case_files_user_status ON case_files(user_id, status);
CREATE INDEX IF NOT EXISTS idx_case_files_user_created ON case_files(user_id, created_at DESC);

DROP TRIGGER IF EXISTS update_case_files_updated_at ON case_files;
CREATE TRIGGER update_case_files_updated_at
  BEFORE UPDATE ON case_files
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ==========================================================================
-- documents
-- ==========================================================================

CREATE TABLE IF NOT EXISTS documents (
  document_id    TEXT PRIMARY KEY,
  user_id        TEXT NOT NULL,
  file_name      TEXT,
  document_type  TEXT,
  status         TEXT,
  storage_path   TEXT,
  analysis_report JSONB,
  analysis_results JSONB,
  metadata       JSONB DEFAULT '{}',
  encrypted      BOOLEAN DEFAULT FALSE,
  case_id        UUID REFERENCES case_files(id) ON DELETE SET NULL,
  classification_id UUID,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_documents_case_id ON documents(case_id);
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);

DROP TRIGGER IF EXISTS update_documents_updated_at ON documents;
CREATE TRIGGER update_documents_updated_at
  BEFORE UPDATE ON documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ==========================================================================
-- document_classifications
-- ==========================================================================

CREATE TABLE IF NOT EXISTS document_classifications (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id         TEXT NOT NULL,
  classification_type TEXT NOT NULL,
  classification_subtype TEXT,
  confidence          NUMERIC(4,3),
  extracted_metadata  JSONB DEFAULT '{}',
  classified_by       TEXT NOT NULL DEFAULT 'claude',
  classified_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doc_classifications_document_id ON document_classifications(document_id);
CREATE INDEX IF NOT EXISTS idx_doc_classifications_type ON document_classifications(classification_type);

-- ==========================================================================
-- pipeline_state
-- ==========================================================================

CREATE TABLE IF NOT EXISTS pipeline_state (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id           TEXT NOT NULL UNIQUE,
  user_id               TEXT NOT NULL,
  document_type         TEXT,
  file_name             TEXT,
  status                TEXT NOT NULL DEFAULT 'uploaded',
  steps                 JSONB DEFAULT '{}',
  extracted_text        TEXT,
  classification_results JSONB,
  analysis_results      JSONB,
  case_id               UUID REFERENCES case_files(id) ON DELETE SET NULL,
  error                 JSONB,
  retry_count           INTEGER DEFAULT 0,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_state_document ON pipeline_state(document_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_state_user_status ON pipeline_state(user_id, status);

DROP TRIGGER IF EXISTS set_pipeline_state_updated_at ON pipeline_state;
CREATE TRIGGER set_pipeline_state_updated_at
  BEFORE UPDATE ON pipeline_state
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ==========================================================================
-- plaid_items
-- ==========================================================================

CREATE TABLE IF NOT EXISTS plaid_items (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id              VARCHAR(255) UNIQUE NOT NULL,
  user_id              VARCHAR(255) NOT NULL,
  access_token         TEXT NOT NULL,
  status               VARCHAR(50) DEFAULT 'active',
  institution_id       VARCHAR(255),
  error                JSONB,
  requires_user_action BOOLEAN DEFAULT FALSE,
  last_webhook_at      TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_plaid_items_user_id ON plaid_items(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_items_status ON plaid_items(status);
CREATE INDEX IF NOT EXISTS idx_plaid_items_item_id ON plaid_items(item_id);

DROP TRIGGER IF EXISTS update_plaid_items_updated_at ON plaid_items;
CREATE TRIGGER update_plaid_items_updated_at
  BEFORE UPDATE ON plaid_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ==========================================================================
-- plaid_accounts
-- ==========================================================================

CREATE TABLE IF NOT EXISTS plaid_accounts (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id              VARCHAR(255) UNIQUE NOT NULL,
  item_id                 VARCHAR(255) NOT NULL REFERENCES plaid_items(item_id) ON DELETE CASCADE,
  user_id                 VARCHAR(255) NOT NULL,
  name                    VARCHAR(255),
  official_name           VARCHAR(255),
  type                    VARCHAR(50),
  subtype                 VARCHAR(50),
  mask                    VARCHAR(10),
  current_balance         DECIMAL(15, 2),
  available_balance       DECIMAL(15, 2),
  "limit"                 DECIMAL(15, 2),
  iso_currency_code       VARCHAR(3),
  unofficial_currency_code VARCHAR(10),
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_plaid_accounts_user_id ON plaid_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_accounts_item_id ON plaid_accounts(item_id);

DROP TRIGGER IF EXISTS update_plaid_accounts_updated_at ON plaid_accounts;
CREATE TRIGGER update_plaid_accounts_updated_at
  BEFORE UPDATE ON plaid_accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ==========================================================================
-- plaid_transactions
-- ==========================================================================

CREATE TABLE IF NOT EXISTS plaid_transactions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id          VARCHAR(255) UNIQUE NOT NULL,
  item_id                 VARCHAR(255) NOT NULL REFERENCES plaid_items(item_id) ON DELETE CASCADE,
  user_id                 VARCHAR(255) NOT NULL,
  account_id              VARCHAR(255) NOT NULL REFERENCES plaid_accounts(account_id) ON DELETE CASCADE,
  amount                  DECIMAL(15, 2),
  iso_currency_code       VARCHAR(3),
  unofficial_currency_code VARCHAR(10),
  category                JSONB,
  category_id             VARCHAR(50),
  transaction_type        VARCHAR(50),
  name                    TEXT,
  merchant_name           VARCHAR(255),
  date                    DATE,
  authorized_date         DATE,
  authorized_datetime     TIMESTAMPTZ,
  datetime                TIMESTAMPTZ,
  payment_channel         VARCHAR(50),
  location                JSONB,
  payment_meta            JSONB,
  account_owner           VARCHAR(255),
  pending                 BOOLEAN DEFAULT FALSE,
  pending_transaction_id  VARCHAR(255),
  transaction_code        VARCHAR(50),
  created_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_plaid_transactions_user_id ON plaid_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_transactions_item_id ON plaid_transactions(item_id);
CREATE INDEX IF NOT EXISTS idx_plaid_transactions_account_id ON plaid_transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_plaid_transactions_date ON plaid_transactions(date DESC);

-- ==========================================================================
-- notifications
-- ==========================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     VARCHAR(255) NOT NULL,
  item_id     VARCHAR(255),
  type        VARCHAR(50),
  message     TEXT,
  priority    VARCHAR(20) DEFAULT 'medium',
  read        BOOLEAN DEFAULT FALSE,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- ==========================================================================
-- Done
-- ==========================================================================
-- Tables: case_files, documents, document_classifications, pipeline_state,
--         plaid_items, plaid_accounts, plaid_transactions, notifications
-- Total: 8 tables, 1 trigger function
