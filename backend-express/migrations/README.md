# Database Migrations

This directory contains SQL migration files for the Mortgage Guardian backend database schema in Supabase.

## Overview

The backend uses Supabase (PostgreSQL) for data persistence. These migration files define the database schema for various features:

- **001_plaid_tables.sql** - Tables for Plaid banking integration (items, accounts, transactions, notifications)

## How to Run Migrations

### Option 1: Supabase Dashboard (Recommended)

1. Log in to your Supabase project at [supabase.com](https://supabase.com)
2. Navigate to the **SQL Editor** section
3. Copy the contents of the migration file (e.g., `001_plaid_tables.sql`)
4. Paste into the SQL editor
5. Click **Run** to execute the migration
6. Verify tables were created in the **Table Editor** section

### Option 2: Supabase CLI

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Link to your project
supabase link --project-ref your-project-ref

# Run migration
supabase db push migrations/001_plaid_tables.sql
```

### Option 3: Direct PostgreSQL Connection

```bash
# Connect using psql
psql "postgresql://[user]:[password]@[host]:[port]/[database]" < migrations/001_plaid_tables.sql
```

## Migration Files

### 001_plaid_tables.sql

Creates the following tables for Plaid integration:

- **plaid_items** - Stores authenticated bank connections
  - `item_id` - Unique Plaid item identifier
  - `user_id` - Associated user
  - `access_token` - Encrypted access token
  - `status` - Connection status (active, error, etc.)
  - `requires_user_action` - Flag for required re-authentication

- **plaid_accounts** - Bank account details
  - `account_id` - Unique account identifier
  - `item_id` - Parent bank connection
  - `type/subtype` - Account classification
  - Balance information

- **plaid_transactions** - Transaction history
  - `transaction_id` - Unique transaction identifier
  - Transaction details (amount, date, merchant, etc.)
  - Category and location data

- **notifications** - User notifications from webhooks
  - Authentication warnings
  - New transaction alerts
  - Error notifications

## Row Level Security (RLS)

All tables have RLS enabled with policies that:
- Allow users to view only their own data
- Prevent cross-user data access
- Require authentication for all operations

**Important**: Adjust the RLS policies based on your authentication setup:
- If using Supabase Auth, the current policies work as-is
- If using custom auth, modify the `auth.uid()` references

## Best Practices

1. **Always backup** your database before running migrations
2. **Test migrations** in a development environment first
3. **Review RLS policies** to ensure they match your auth system
4. **Monitor table growth** and consider partitioning for large datasets
5. **Encrypt sensitive data** like access tokens in production

## Rollback

To rollback a migration, you'll need to manually drop the tables:

```sql
-- Rollback 001_plaid_tables.sql
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS plaid_transactions CASCADE;
DROP TABLE IF EXISTS plaid_accounts CASCADE;
DROP TABLE IF EXISTS plaid_items CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;
```

## Environment Variables

Ensure these are set in your `.env`:

```env
SUPABASE_URL=your-project-url
SUPABASE_SERVICE_KEY=your-service-key
```

## Troubleshooting

### Permission Errors
- Ensure you're using the service key, not the anon key
- Check that your database user has CREATE TABLE permissions

### RLS Policy Issues
- If queries return no data, check RLS policies
- Use service key for admin operations that bypass RLS

### Migration Failed
- Check for existing tables with same names
- Verify PostgreSQL version compatibility (requires 9.5+)
- Review error messages in Supabase logs

## Next Steps

After running migrations:

1. Verify tables in Supabase Table Editor
2. Test webhook handlers with sample data
3. Configure Plaid webhook URL in Plaid dashboard
4. Set up monitoring for webhook failures