const { createLogger } = require('../utils/logger');
const logger = createLogger('plaid-data');

// Lazy-loaded db module — only initialized when DATABASE_URL is set
let _db = null;
function getDb() {
  if (_db) return _db;
  if (!process.env.DATABASE_URL) return null;
  _db = require('../db');
  logger.info('Database client initialized for Plaid data');
  return _db;
}

class PlaidDataService {
  constructor() {
    // In-memory storage for mock/development mode
    this.mockItems = new Map();
    this.mockTransactions = new Map();
    this.mockAccounts = new Map();
  }

  /**
   * Store or update a Plaid item in the database
   */
  async upsertPlaidItem({ itemId, userId, accessToken, status, institutionId, error }) {
    if (!process.env.DATABASE_URL) {
      return this.mockUpsertItem({ itemId, userId, accessToken, status, institutionId, error });
    }

    try {
      const db = getDb();
      const now = new Date().toISOString();
      const result = await db.query(
        `INSERT INTO plaid_items (item_id, user_id, access_token, status, institution_id, error, last_webhook_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (item_id) DO UPDATE SET
           user_id = EXCLUDED.user_id,
           access_token = EXCLUDED.access_token,
           status = EXCLUDED.status,
           institution_id = EXCLUDED.institution_id,
           error = EXCLUDED.error,
           last_webhook_at = EXCLUDED.last_webhook_at,
           updated_at = EXCLUDED.updated_at
         RETURNING *`,
        [
          itemId,
          userId,
          accessToken,
          status || 'active',
          institutionId,
          error ? JSON.stringify(error) : null,
          now,
          now
        ]
      );

      return { success: true, data: result.rows[0] };
    } catch (error) {
      logger.error('Error upserting Plaid item', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Store transactions from Plaid webhook
   */
  async storeTransactions({ itemId, transactions, userId }) {
    if (!process.env.DATABASE_URL) {
      return this.mockStoreTransactions({ itemId, transactions, userId });
    }

    try {
      const db = getDb();
      const { pool } = db;
      const now = new Date().toISOString();

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        for (const transaction of transactions) {
          await client.query(
            `INSERT INTO plaid_transactions (
              transaction_id, item_id, user_id, account_id, amount,
              iso_currency_code, unofficial_currency_code, category, category_id,
              transaction_type, name, merchant_name, date, authorized_date,
              authorized_datetime, datetime, payment_channel, location,
              payment_meta, account_owner, pending, pending_transaction_id,
              transaction_code, created_at
            ) VALUES (
              $1, $2, $3, $4, $5,
              $6, $7, $8, $9,
              $10, $11, $12, $13, $14,
              $15, $16, $17, $18,
              $19, $20, $21, $22,
              $23, $24
            )
            ON CONFLICT (transaction_id) DO UPDATE SET
              item_id = EXCLUDED.item_id,
              user_id = EXCLUDED.user_id,
              account_id = EXCLUDED.account_id,
              amount = EXCLUDED.amount,
              iso_currency_code = EXCLUDED.iso_currency_code,
              unofficial_currency_code = EXCLUDED.unofficial_currency_code,
              category = EXCLUDED.category,
              category_id = EXCLUDED.category_id,
              transaction_type = EXCLUDED.transaction_type,
              name = EXCLUDED.name,
              merchant_name = EXCLUDED.merchant_name,
              date = EXCLUDED.date,
              authorized_date = EXCLUDED.authorized_date,
              authorized_datetime = EXCLUDED.authorized_datetime,
              datetime = EXCLUDED.datetime,
              payment_channel = EXCLUDED.payment_channel,
              location = EXCLUDED.location,
              payment_meta = EXCLUDED.payment_meta,
              account_owner = EXCLUDED.account_owner,
              pending = EXCLUDED.pending,
              pending_transaction_id = EXCLUDED.pending_transaction_id,
              transaction_code = EXCLUDED.transaction_code`,
            [
              transaction.transaction_id,
              itemId,
              userId,
              transaction.account_id,
              transaction.amount,
              transaction.iso_currency_code,
              transaction.unofficial_currency_code,
              transaction.category ? JSON.stringify(transaction.category) : null,
              transaction.category_id,
              transaction.transaction_type,
              transaction.name,
              transaction.merchant_name,
              transaction.date,
              transaction.authorized_date,
              transaction.authorized_datetime,
              transaction.datetime,
              transaction.payment_channel,
              transaction.location ? JSON.stringify(transaction.location) : null,
              transaction.payment_meta ? JSON.stringify(transaction.payment_meta) : null,
              transaction.account_owner,
              transaction.pending,
              transaction.pending_transaction_id,
              transaction.transaction_code,
              now
            ]
          );
        }

        await client.query('COMMIT');
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      } finally {
        client.release();
      }

      logger.info('Transactions stored', { count: transactions.length, itemId });
      return { success: true, count: transactions.length };
    } catch (error) {
      logger.error('Error storing transactions', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Remove transactions from database
   */
  async removeTransactions({ transactionIds }) {
    if (!process.env.DATABASE_URL) {
      return this.mockRemoveTransactions({ transactionIds });
    }

    try {
      const db = getDb();
      await db.query(
        `DELETE FROM plaid_transactions WHERE transaction_id = ANY($1::text[])`,
        [transactionIds]
      );

      logger.info('Transactions removed', { count: transactionIds.length });
      return { success: true, count: transactionIds.length };
    } catch (error) {
      logger.error('Error removing transactions', { error: error.message });
      return { success: false, error: error.message };
    }
  }

  /**
   * Update item status (for errors, warnings, etc.)
   */
  async updateItemStatus({ itemId, status, error = null, requiresAction = false }) {
    if (!process.env.DATABASE_URL) {
      return this.mockUpdateItemStatus({ itemId, status, error, requiresAction });
    }

    try {
      const db = getDb();
      const now = new Date().toISOString();
      const result = await db.query(
        `UPDATE plaid_items
         SET status = $1, error = $2, requires_user_action = $3, updated_at = $4
         WHERE item_id = $5
         RETURNING *`,
        [
          status,
          error ? JSON.stringify(error) : null,
          requiresAction,
          now,
          itemId
        ]
      );

      logger.info('Item status updated', { itemId, status });
      return { success: true, data: result.rows[0] };
    } catch (error) {
      logger.error('Error updating item status', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Store or update accounts information
   */
  async upsertAccounts({ itemId, accounts, userId }) {
    if (!process.env.DATABASE_URL) {
      return this.mockUpsertAccounts({ itemId, accounts, userId });
    }

    try {
      const db = getDb();
      const { pool } = db;
      const now = new Date().toISOString();

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        for (const account of accounts) {
          await client.query(
            `INSERT INTO plaid_accounts (
              account_id, item_id, user_id, name, official_name,
              type, subtype, mask, current_balance, available_balance,
              "limit", iso_currency_code, unofficial_currency_code, updated_at
            ) VALUES (
              $1, $2, $3, $4, $5,
              $6, $7, $8, $9, $10,
              $11, $12, $13, $14
            )
            ON CONFLICT (account_id) DO UPDATE SET
              item_id = EXCLUDED.item_id,
              user_id = EXCLUDED.user_id,
              name = EXCLUDED.name,
              official_name = EXCLUDED.official_name,
              type = EXCLUDED.type,
              subtype = EXCLUDED.subtype,
              mask = EXCLUDED.mask,
              current_balance = EXCLUDED.current_balance,
              available_balance = EXCLUDED.available_balance,
              "limit" = EXCLUDED."limit",
              iso_currency_code = EXCLUDED.iso_currency_code,
              unofficial_currency_code = EXCLUDED.unofficial_currency_code,
              updated_at = EXCLUDED.updated_at`,
            [
              account.account_id,
              itemId,
              userId,
              account.name,
              account.official_name,
              account.type,
              account.subtype,
              account.mask,
              account.balances?.current,
              account.balances?.available,
              account.balances?.limit,
              account.balances?.iso_currency_code,
              account.balances?.unofficial_currency_code,
              now
            ]
          );
        }

        await client.query('COMMIT');
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      } finally {
        client.release();
      }

      logger.info('Accounts updated', { count: accounts.length, itemId });
      return { success: true, count: accounts.length };
    } catch (error) {
      logger.error('Error upserting accounts', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Get item by ID
   */
  async getItem(itemId) {
    if (!process.env.DATABASE_URL) {
      return this.mockGetItem(itemId);
    }

    try {
      const db = getDb();
      const result = await db.query(
        `SELECT * FROM plaid_items WHERE item_id = $1`,
        [itemId]
      );

      const data = result.rows[0];
      if (!data) {
        return { success: false, error: 'Item not found' };
      }

      return { success: true, data };
    } catch (error) {
      logger.error('Error fetching item', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Create notification for user action required
   */
  async createNotification({ userId, itemId, type, message, priority = 'medium' }) {
    if (!process.env.DATABASE_URL) {
      logger.info('Mock notification', { priority, message, userId });
      return { success: true, mock: true };
    }

    try {
      const db = getDb();
      const now = new Date().toISOString();
      const result = await db.query(
        `INSERT INTO notifications (user_id, item_id, type, message, priority, read, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [userId, itemId, type, message, priority, false, now]
      );

      logger.info('Notification created', { priority, userId });
      return { success: true, data: result.rows[0] };
    } catch (error) {
      logger.error('Error creating notification', { error: error.message, userId });
      return { success: false, error: error.message };
    }
  }

  // Mock implementations for development/testing
  mockUpsertItem(item) {
    this.mockItems.set(item.itemId, {
      ...item,
      updatedAt: new Date().toISOString()
    });
    logger.debug('Mock: stored item', { itemId: item.itemId });
    return { success: true, mock: true, data: item };
  }

  mockStoreTransactions({ itemId, transactions, userId }) {
    transactions.forEach(transaction => {
      this.mockTransactions.set(transaction.transaction_id, {
        ...transaction,
        itemId,
        userId,
        createdAt: new Date().toISOString()
      });
    });
    logger.debug('Mock: stored transactions', { count: transactions.length });
    return { success: true, mock: true, count: transactions.length };
  }

  mockRemoveTransactions({ transactionIds }) {
    transactionIds.forEach(id => this.mockTransactions.delete(id));
    logger.debug('Mock: removed transactions', { count: transactionIds.length });
    return { success: true, mock: true, count: transactionIds.length };
  }

  mockUpdateItemStatus(update) {
    const item = this.mockItems.get(update.itemId);
    if (item) {
      this.mockItems.set(update.itemId, { ...item, ...update });
      logger.debug('Mock: updated item status', { itemId: update.itemId, status: update.status });
    }
    return { success: true, mock: true, data: update };
  }

  mockUpsertAccounts({ itemId, accounts, userId }) {
    accounts.forEach(account => {
      this.mockAccounts.set(account.account_id, {
        ...account,
        itemId,
        userId,
        updatedAt: new Date().toISOString()
      });
    });
    logger.debug('Mock: stored accounts', { count: accounts.length });
    return { success: true, mock: true, count: accounts.length };
  }

  mockGetItem(itemId) {
    const item = this.mockItems.get(itemId);
    if (item) {
      return { success: true, mock: true, data: item };
    }
    return { success: false, error: 'Item not found' };
  }
}

module.exports = new PlaidDataService();
