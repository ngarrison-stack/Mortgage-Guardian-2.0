-- =============================================
-- Rollback: Baseline Migration — Mortgage Guardian 2.0
-- =============================================
-- Reverses the baseline migration in reverse dependency order.
-- Uses IF EXISTS / CASCADE for safety.
--
-- WARNING: This will destroy all application data in these tables.
-- =============================================

-- =============================================
-- 1. Drop Triggers
-- =============================================
DROP TRIGGER IF EXISTS set_pipeline_state_updated_at ON pipeline_state;
DROP TRIGGER IF EXISTS update_case_files_updated_at ON case_files;
DROP TRIGGER IF EXISTS update_plaid_accounts_updated_at ON plaid_accounts;
DROP TRIGGER IF EXISTS update_plaid_items_updated_at ON plaid_items;

-- =============================================
-- 2. Drop Storage Bucket Policies
-- =============================================
DROP POLICY IF EXISTS "Users can delete own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can download own documents" ON storage.objects;

-- =============================================
-- 3. Drop RLS Policies — pipeline_state
-- =============================================
DROP POLICY IF EXISTS "Users can delete own pipeline state" ON pipeline_state;
DROP POLICY IF EXISTS "Users can update own pipeline state" ON pipeline_state;
DROP POLICY IF EXISTS "Users can insert own pipeline state" ON pipeline_state;
DROP POLICY IF EXISTS "Users can view own pipeline state" ON pipeline_state;

-- =============================================
-- 4. Drop RLS Policies — document_classifications
-- =============================================
DROP POLICY IF EXISTS "Users can insert own document classifications" ON document_classifications;
DROP POLICY IF EXISTS "Users can view own document classifications" ON document_classifications;

-- =============================================
-- 5. Drop RLS Policies — case_files
-- =============================================
DROP POLICY IF EXISTS "Users can delete own case files" ON case_files;
DROP POLICY IF EXISTS "Users can update own case files" ON case_files;
DROP POLICY IF EXISTS "Users can insert own case files" ON case_files;
DROP POLICY IF EXISTS "Users can view own case files" ON case_files;

-- =============================================
-- 6. Drop RLS Policies — documents
-- =============================================
DROP POLICY IF EXISTS "Users can delete own documents" ON documents;
DROP POLICY IF EXISTS "Users can update own documents" ON documents;
DROP POLICY IF EXISTS "Users can insert own documents" ON documents;
DROP POLICY IF EXISTS "Users can view own documents" ON documents;

-- =============================================
-- 7. Drop RLS Policies — notifications
-- =============================================
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;

-- =============================================
-- 8. Drop RLS Policies — plaid_transactions
-- =============================================
DROP POLICY IF EXISTS "Users can insert own transactions" ON plaid_transactions;
DROP POLICY IF EXISTS "Users can view own transactions" ON plaid_transactions;

-- =============================================
-- 9. Drop RLS Policies — plaid_accounts
-- =============================================
DROP POLICY IF EXISTS "Users can update own accounts" ON plaid_accounts;
DROP POLICY IF EXISTS "Users can insert own accounts" ON plaid_accounts;
DROP POLICY IF EXISTS "Users can view own accounts" ON plaid_accounts;

-- =============================================
-- 10. Drop RLS Policies — plaid_items
-- =============================================
DROP POLICY IF EXISTS "Users can delete own plaid items" ON plaid_items;
DROP POLICY IF EXISTS "Users can update own plaid items" ON plaid_items;
DROP POLICY IF EXISTS "Users can insert own plaid items" ON plaid_items;
DROP POLICY IF EXISTS "Users can view own plaid items" ON plaid_items;

-- =============================================
-- 11. Disable RLS
-- =============================================
ALTER TABLE IF EXISTS pipeline_state DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS document_classifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS case_files DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS plaid_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS plaid_accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS plaid_items DISABLE ROW LEVEL SECURITY;

-- =============================================
-- 12. Drop Indexes (on columns added by ALTER TABLE)
-- =============================================
DROP INDEX IF EXISTS idx_documents_case_id;

-- =============================================
-- 13. Remove columns added to documents by ALTER TABLE
-- =============================================
ALTER TABLE IF EXISTS documents DROP COLUMN IF EXISTS classification_id;
ALTER TABLE IF EXISTS documents DROP COLUMN IF EXISTS case_id;

-- =============================================
-- 14. Drop Tables (reverse dependency order)
-- =============================================
DROP TABLE IF EXISTS pipeline_state CASCADE;
DROP TABLE IF EXISTS document_classifications CASCADE;
DROP TABLE IF EXISTS case_files CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS plaid_transactions CASCADE;
DROP TABLE IF EXISTS plaid_accounts CASCADE;
DROP TABLE IF EXISTS plaid_items CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- =============================================
-- 15. Drop Functions
-- =============================================
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
