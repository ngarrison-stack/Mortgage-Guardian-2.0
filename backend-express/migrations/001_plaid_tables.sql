-- =============================================
-- Plaid Integration Tables for Supabase
-- =============================================
-- Run this migration in Supabase SQL editor
-- Created: 2025-11-09
-- =============================================

-- 1. Plaid Items Table (Bank Connections)
-- Stores authenticated bank connections from Plaid Link
CREATE TABLE IF NOT EXISTS plaid_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  item_id VARCHAR(255) UNIQUE NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  access_token TEXT NOT NULL, -- Should be encrypted in production
  status VARCHAR(50) DEFAULT 'active',
  institution_id VARCHAR(255),
  error JSONB,
  requires_user_action BOOLEAN DEFAULT FALSE,
  last_webhook_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX idx_plaid_items_user_id ON plaid_items(user_id);
CREATE INDEX idx_plaid_items_status ON plaid_items(status);
CREATE INDEX idx_plaid_items_item_id ON plaid_items(item_id);

-- 2. Plaid Accounts Table
-- Stores account information for each connected item
CREATE TABLE IF NOT EXISTS plaid_accounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id VARCHAR(255) UNIQUE NOT NULL,
  item_id VARCHAR(255) NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  official_name VARCHAR(255),
  type VARCHAR(50), -- depository, credit, loan, investment
  subtype VARCHAR(50), -- checking, savings, credit card, etc.
  mask VARCHAR(10),
  current_balance DECIMAL(15, 2),
  available_balance DECIMAL(15, 2),
  limit DECIMAL(15, 2),
  iso_currency_code VARCHAR(3),
  unofficial_currency_code VARCHAR(10),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (item_id) REFERENCES plaid_items(item_id) ON DELETE CASCADE
);

-- Indexes for accounts
CREATE INDEX idx_plaid_accounts_user_id ON plaid_accounts(user_id);
CREATE INDEX idx_plaid_accounts_item_id ON plaid_accounts(item_id);
CREATE INDEX idx_plaid_accounts_account_id ON plaid_accounts(account_id);

-- 3. Plaid Transactions Table
-- Stores transaction data from Plaid
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
  transaction_type VARCHAR(50), -- place, digital, special, unresolved
  name TEXT,
  merchant_name VARCHAR(255),
  date DATE,
  authorized_date DATE,
  authorized_datetime TIMESTAMP WITH TIME ZONE,
  datetime TIMESTAMP WITH TIME ZONE,
  payment_channel VARCHAR(50), -- in store, online, other
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

-- Indexes for transactions
CREATE INDEX idx_plaid_transactions_user_id ON plaid_transactions(user_id);
CREATE INDEX idx_plaid_transactions_item_id ON plaid_transactions(item_id);
CREATE INDEX idx_plaid_transactions_account_id ON plaid_transactions(account_id);
CREATE INDEX idx_plaid_transactions_date ON plaid_transactions(date DESC);
CREATE INDEX idx_plaid_transactions_transaction_id ON plaid_transactions(transaction_id);

-- 4. Notifications Table
-- Stores user notifications for webhook events
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  item_id VARCHAR(255),
  type VARCHAR(50), -- authentication_required, transactions_updated, error, etc.
  message TEXT,
  priority VARCHAR(20) DEFAULT 'medium', -- low, medium, high
  read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE plaid_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE plaid_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE plaid_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS Policies (adjust based on your auth setup)
-- Example: Users can only see their own data
-- You'll need to adjust these based on your Supabase auth setup

-- Plaid items policies
CREATE POLICY "Users can view own plaid items" ON plaid_items
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own plaid items" ON plaid_items
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own plaid items" ON plaid_items
  FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own plaid items" ON plaid_items
  FOR DELETE USING (auth.uid()::text = user_id);

-- Plaid accounts policies
CREATE POLICY "Users can view own accounts" ON plaid_accounts
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own accounts" ON plaid_accounts
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own accounts" ON plaid_accounts
  FOR UPDATE USING (auth.uid()::text = user_id);

-- Plaid transactions policies
CREATE POLICY "Users can view own transactions" ON plaid_transactions
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own transactions" ON plaid_transactions
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- Notifications policies
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid()::text = user_id);

-- 7. Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Apply updated_at triggers
CREATE TRIGGER update_plaid_items_updated_at BEFORE UPDATE ON plaid_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_plaid_accounts_updated_at BEFORE UPDATE ON plaid_accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- Migration Notes:
-- =============================================
-- 1. Run this in Supabase SQL editor (supabase.com → SQL Editor)
-- 2. After running, verify tables in Table Editor
-- 3. Adjust RLS policies based on your auth implementation
-- 4. Consider encrypting access_token column in production
-- 5. Monitor table growth and add partitioning if needed
-- =============================================