const { createClient } = require('@supabase/supabase-js');
const { createLogger } = require('../utils/logger');
const logger = createLogger('plaid-data');

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

let supabase = null;
if (supabaseUrl && supabaseServiceKey) {
  supabase = createClient(supabaseUrl, supabaseServiceKey);
  logger.info('Supabase client initialized for Plaid data');
} else {
  logger.warn('Supabase not configured - Plaid data will use in-memory storage');
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
    if (!supabase) {
      return this.mockUpsertItem({ itemId, userId, accessToken, status, institutionId, error });
    }

    try {
      const { data, error: dbError } = await supabase
        .from('plaid_items')
        .upsert({
          item_id: itemId,
          user_id: userId,
          access_token: accessToken,
          status: status || 'active',
          institution_id: institutionId,
          error: error ? JSON.stringify(error) : null,
          last_webhook_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }, {
          onConflict: 'item_id'
        });

      if (dbError) {
        throw new Error(`Database error: ${dbError.message}`);
      }

      return { success: true, data };
    } catch (error) {
      logger.error('Error upserting Plaid item', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Store transactions from Plaid webhook
   */
  async storeTransactions({ itemId, transactions, userId }) {
    if (!supabase) {
      return this.mockStoreTransactions({ itemId, transactions, userId });
    }

    try {
      // Prepare transactions for bulk insert
      const transactionRecords = transactions.map(transaction => ({
        transaction_id: transaction.transaction_id,
        item_id: itemId,
        user_id: userId,
        account_id: transaction.account_id,
        amount: transaction.amount,
        iso_currency_code: transaction.iso_currency_code,
        unofficial_currency_code: transaction.unofficial_currency_code,
        category: transaction.category ? JSON.stringify(transaction.category) : null,
        category_id: transaction.category_id,
        transaction_type: transaction.transaction_type,
        name: transaction.name,
        merchant_name: transaction.merchant_name,
        date: transaction.date,
        authorized_date: transaction.authorized_date,
        authorized_datetime: transaction.authorized_datetime,
        datetime: transaction.datetime,
        payment_channel: transaction.payment_channel,
        location: transaction.location ? JSON.stringify(transaction.location) : null,
        payment_meta: transaction.payment_meta ? JSON.stringify(transaction.payment_meta) : null,
        account_owner: transaction.account_owner,
        pending: transaction.pending,
        pending_transaction_id: transaction.pending_transaction_id,
        transaction_code: transaction.transaction_code,
        created_at: new Date().toISOString()
      }));

      const { data, error } = await supabase
        .from('plaid_transactions')
        .upsert(transactionRecords, {
          onConflict: 'transaction_id'
        });

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      logger.info('Transactions stored', { count: transactions.length, itemId });
      return { success: true, count: transactions.length, data };
    } catch (error) {
      logger.error('Error storing transactions', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Remove transactions from database
   */
  async removeTransactions({ transactionIds }) {
    if (!supabase) {
      return this.mockRemoveTransactions({ transactionIds });
    }

    try {
      const { data, error } = await supabase
        .from('plaid_transactions')
        .delete()
        .in('transaction_id', transactionIds);

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      logger.info('Transactions removed', { count: transactionIds.length });
      return { success: true, count: transactionIds.length, data };
    } catch (error) {
      logger.error('Error removing transactions', { error: error.message });
      return { success: false, error: error.message };
    }
  }

  /**
   * Update item status (for errors, warnings, etc.)
   */
  async updateItemStatus({ itemId, status, error = null, requiresAction = false }) {
    if (!supabase) {
      return this.mockUpdateItemStatus({ itemId, status, error, requiresAction });
    }

    try {
      const updateData = {
        status,
        error: error ? JSON.stringify(error) : null,
        requires_user_action: requiresAction,
        updated_at: new Date().toISOString()
      };

      const { data, error: dbError } = await supabase
        .from('plaid_items')
        .update(updateData)
        .eq('item_id', itemId);

      if (dbError) {
        throw new Error(`Database error: ${dbError.message}`);
      }

      logger.info('Item status updated', { itemId, status });
      return { success: true, data };
    } catch (error) {
      logger.error('Error updating item status', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Store or update accounts information
   */
  async upsertAccounts({ itemId, accounts, userId }) {
    if (!supabase) {
      return this.mockUpsertAccounts({ itemId, accounts, userId });
    }

    try {
      const accountRecords = accounts.map(account => ({
        account_id: account.account_id,
        item_id: itemId,
        user_id: userId,
        name: account.name,
        official_name: account.official_name,
        type: account.type,
        subtype: account.subtype,
        mask: account.mask,
        current_balance: account.balances?.current,
        available_balance: account.balances?.available,
        limit: account.balances?.limit,
        iso_currency_code: account.balances?.iso_currency_code,
        unofficial_currency_code: account.balances?.unofficial_currency_code,
        updated_at: new Date().toISOString()
      }));

      const { data, error } = await supabase
        .from('plaid_accounts')
        .upsert(accountRecords, {
          onConflict: 'account_id'
        });

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      logger.info('Accounts updated', { count: accounts.length, itemId });
      return { success: true, count: accounts.length, data };
    } catch (error) {
      logger.error('Error upserting accounts', { error: error.message, itemId });
      return { success: false, error: error.message };
    }
  }

  /**
   * Get item by ID
   */
  async getItem(itemId) {
    if (!supabase) {
      return this.mockGetItem(itemId);
    }

    try {
      const { data, error } = await supabase
        .from('plaid_items')
        .select('*')
        .eq('item_id', itemId)
        .single();

      if (error) {
        throw new Error(`Database error: ${error.message}`);
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
    if (!supabase) {
      logger.info('Mock notification', { priority, message, userId });
      return { success: true, mock: true };
    }

    try {
      const { data, error } = await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          item_id: itemId,
          type,
          message,
          priority,
          read: false,
          created_at: new Date().toISOString()
        });

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      logger.info('Notification created', { priority, userId });
      return { success: true, data };
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