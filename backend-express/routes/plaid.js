const express = require('express');
const router = express.Router();
const plaidService = require('../services/plaidService');
const plaidDataService = require('../services/plaidDataService');
const { createLogger } = require('../utils/logger');
const logger = createLogger('plaid-routes');
const { validate } = require('../middleware/validate');
const {
  linkTokenSchema,
  exchangeTokenSchema,
  accountsSchema,
  transactionsSchema,
  itemSchema,
  updateWebhookSchema,
  deleteItemSchema,
  sandboxTokenSchema
} = require('../schemas/plaid');

/**
 * Sanitize user input to prevent injection attacks
 */
const sanitizeInput = (req, res, next) => {
  // Remove any potential script tags or malicious content
  const sanitize = (obj) => {
    if (typeof obj === 'string') {
      return obj.trim().replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
    }
    if (typeof obj === 'object' && obj !== null) {
      for (const key in obj) {
        obj[key] = sanitize(obj[key]);
      }
    }
    return obj;
  };

  req.body = sanitize(req.body);
  next();
};

// Apply sanitization to all routes
router.use(sanitizeInput);

// ============================================
// PLAID LINK TOKEN ENDPOINTS
// ============================================

/**
 * POST /v1/plaid/link_token
 * Create Plaid Link token for bank connection
 *
 * Request Body:
 * - user_id (required): Unique user identifier
 * - client_name (optional): Display name for Link UI
 * - redirect_uri (optional): OAuth redirect URI
 * - access_token (optional): For update mode (re-authentication)
 * - products (optional): Array of Plaid products to enable
 *
 * Response:
 * - link_token: Token to initialize Plaid Link
 * - expiration: ISO timestamp when token expires
 * - request_id: Plaid request ID for debugging
 */
router.post('/link_token', validate(linkTokenSchema), async (req, res, next) => {
  try {
    const {
      user_id,
      client_name,
      redirect_uri,
      access_token,
      products
    } = req.body;

    const result = await plaidService.createLinkToken({
      userId: user_id,
      clientName: client_name,
      redirectUri: redirect_uri,
      accessToken: access_token,
      products: products
    });

    res.json(result);

  } catch (error) {
    logger.error('Link token creation error', { error: error.message, type: error.type, code: error.code });
    next(error);
  }
});

// ============================================
// TOKEN EXCHANGE ENDPOINTS
// ============================================

/**
 * POST /v1/plaid/exchange_token
 * Exchange public token for access token
 *
 * This endpoint should be called immediately after successful Plaid Link flow.
 * The access token should be securely stored and associated with the user.
 *
 * Request Body:
 * - public_token (required): Public token from Plaid Link
 *
 * Response:
 * - access_token: Long-lived access token (store securely!)
 * - item_id: Unique identifier for this bank connection
 * - request_id: Plaid request ID for debugging
 *
 * Security Note:
 * - Access tokens should NEVER be exposed to the client
 * - Store access tokens encrypted in your database
 * - Associate access tokens with user IDs securely
 */
router.post('/exchange_token', validate(exchangeTokenSchema), async (req, res, next) => {
  try {
    const { public_token, user_id, institution_id } = req.body;

    const result = await plaidService.exchangePublicToken(public_token);

    // Store the item in database with access token
    if (user_id) {
      await plaidDataService.upsertPlaidItem({
        itemId: result.itemId,
        userId: user_id,
        accessToken: result.accessToken,
        status: 'active',
        institutionId: institution_id || null
      });

      logger.info('Plaid item stored', { itemId: result.itemId, userId: user_id });
    } else {
      logger.warn('No user_id provided - item not stored in database');
    }

    // WARNING: In production, store access_token in database, don't return to client
    // For this mortgage auditing use case, we're returning it so iOS can store locally
    res.json({
      access_token: result.accessToken,
      item_id: result.itemId,
      request_id: result.requestId,
      warning: 'Store access_token securely. Never expose in logs or to unauthorized parties.'
    });

  } catch (error) {
    logger.error('Token exchange error', { error: error.message, type: error.type, code: error.code });
    next(error);
  }
});

// ============================================
// ACCOUNT DATA ENDPOINTS
// ============================================

/**
 * POST /v1/plaid/accounts
 * Get account information
 *
 * Request Body:
 * - access_token (required): Plaid access token
 * - account_ids (optional): Specific account IDs to fetch
 *
 * Response:
 * - accounts: Array of account objects with balances
 * - item: Bank connection metadata
 * - request_id: Plaid request ID for debugging
 */
router.post('/accounts', validate(accountsSchema), async (req, res, next) => {
  try {
    const { access_token, account_ids } = req.body;

    const result = await plaidService.getAccounts(access_token, account_ids);

    res.json(result);

  } catch (error) {
    logger.error('Get accounts error', { error: error.message, type: error.type, code: error.code });
    next(error);
  }
});

/**
 * POST /v1/plaid/transactions
 * Get transaction history with pagination
 *
 * Request Body:
 * - access_token (required): Plaid access token
 * - start_date (required): Start date in YYYY-MM-DD format
 * - end_date (required): End date in YYYY-MM-DD format
 * - account_ids (optional): Specific account IDs to fetch transactions for
 * - count (optional): Number of transactions to fetch (1-500, default 100)
 * - offset (optional): Pagination offset (default 0)
 *
 * Response:
 * - transactions: Array of transaction objects
 * - total_transactions: Total number of transactions in date range
 * - accounts: Array of accounts with transactions
 * - request_id: Plaid request ID for debugging
 */
router.post('/transactions', validate(transactionsSchema), async (req, res, next) => {
  try {
    const {
      access_token,
      start_date,
      end_date,
      account_ids,
      count,
      offset
    } = req.body;

    const result = await plaidService.getTransactions({
      accessToken: access_token,
      startDate: start_date,
      endDate: end_date,
      accountIds: account_ids,
      count: count,
      offset: offset
    });

    res.json(result);

  } catch (error) {
    logger.error('Get transactions error', { error: error.message, type: error.type, code: error.code });
    next(error);
  }
});

// ============================================
// ITEM MANAGEMENT ENDPOINTS
// ============================================

/**
 * POST /v1/plaid/item
 * Get item (bank connection) information
 *
 * Request Body:
 * - access_token (required): Plaid access token
 *
 * Response:
 * - itemId: Unique item identifier
 * - institutionId: Bank institution ID
 * - webhook: Configured webhook URL
 * - availableProducts: Products available for this item
 * - billedProducts: Products currently being billed
 * - error: Any item-level errors
 */
router.post('/item', validate(itemSchema), async (req, res, next) => {
  try {
    const { access_token } = req.body;

    const result = await plaidService.getItem(access_token);

    res.json(result);

  } catch (error) {
    logger.error('Get item error', { error: error.message, type: error.type, code: error.code });
    next(error);
  }
});

/**
 * POST /v1/plaid/item/webhook
 * Update webhook URL for an item
 *
 * Request Body:
 * - access_token (required): Plaid access token
 * - webhook (required): New webhook URL (must be HTTPS)
 *
 * Response:
 * - itemId: Unique item identifier
 * - webhook: Updated webhook URL
 */
router.post('/item/webhook', validate(updateWebhookSchema), async (req, res, next) => {
  try {
    const { access_token, webhook } = req.body;

    const result = await plaidService.updateWebhook(access_token, webhook);

    res.json(result);

  } catch (error) {
    logger.error('Update webhook error', { error: error.message, type: error.type, code: error.code });
    next(error);
  }
});

/**
 * DELETE /v1/plaid/item
 * Remove (delete) an item and revoke access
 *
 * Request Body:
 * - access_token (required): Plaid access token
 *
 * Response:
 * - removed: Boolean indicating success
 * - request_id: Plaid request ID for debugging
 */
router.delete('/item', validate(deleteItemSchema), async (req, res, next) => {
  try {
    const { access_token } = req.body;

    const result = await plaidService.removeItem(access_token);

    res.json(result);

  } catch (error) {
    logger.error('Remove item error', { error: error.message, type: error.type, code: error.code });
    next(error);
  }
});

// ============================================
// WEBHOOK ENDPOINT
// ============================================

/**
 * POST /v1/plaid/webhook
 * Receive webhook notifications from Plaid
 *
 * Webhooks are sent for various events:
 * - INITIAL_UPDATE: Initial transaction data available
 * - HISTORICAL_UPDATE: Historical transactions available
 * - DEFAULT_UPDATE: New transactions available
 * - TRANSACTIONS_REMOVED: Transactions removed
 * - ITEM_ERROR: Item-level errors
 * - PENDING_EXPIRATION: Item consent expiring soon
 *
 * Security:
 * - Signature verification using HMAC-SHA256
 * - Webhook verification key from Plaid dashboard
 */
router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res, next) => {
  try {
    // Verify webhook signature for security
    const bodyRaw = req.body.toString('utf8');
    const isValid = plaidService.verifyWebhookSignature(bodyRaw, req.headers);

    if (!isValid) {
      logger.error('Invalid webhook signature');
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid webhook signature'
      });
    }

    // Parse webhook payload
    const webhookData = JSON.parse(bodyRaw);
    const { webhook_type, webhook_code, item_id, error } = webhookData;

    logger.info('Webhook received', { type: webhook_type, code: webhook_code, itemId: item_id });

    // Handle different webhook types
    switch (webhook_type) {
      case 'TRANSACTIONS':
        await handleTransactionWebhook(webhookData);
        break;

      case 'ITEM':
        await handleItemWebhook(webhookData);
        break;

      case 'AUTH':
        await handleAuthWebhook(webhookData);
        break;

      default:
        logger.info('Unhandled webhook type', { type: webhook_type });
    }

    // Always respond with 200 to acknowledge receipt
    res.json({ acknowledged: true });

  } catch (error) {
    logger.error('Webhook processing error', { error: error.message });
    // Still return 200 to prevent Plaid from retrying
    res.json({ acknowledged: true, error: error.message });
  }
});

// ============================================
// WEBHOOK HANDLERS
// ============================================

async function handleTransactionWebhook(data) {
  const { webhook_code, item_id, new_transactions, removed_transactions, error } = data;

  switch (webhook_code) {
    case 'INITIAL_UPDATE':
    case 'HISTORICAL_UPDATE':
    case 'DEFAULT_UPDATE':
      logger.info('Transaction update', { itemId: item_id, newTransactions: new_transactions });

      try {
        // 1. Look up item to get access token and user ID
        const itemResult = await plaidDataService.getItem(item_id);
        if (!itemResult.success) {
          logger.error('Failed to find item', { itemId: item_id, error: itemResult.error });
          return;
        }

        const { access_token, user_id } = itemResult.data;

        // 2. Fetch new transactions from Plaid
        const now = new Date();
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        const transactionsResponse = await plaidService.getTransactions({
          accessToken: access_token,
          startDate: thirtyDaysAgo.toISOString().split('T')[0],
          endDate: now.toISOString().split('T')[0]
        });

        if (!transactionsResponse || !transactionsResponse.transactions) {
          logger.error('Failed to fetch transactions', { itemId: item_id, response: transactionsResponse });
          return;
        }

        // 3. Store transactions in database
        const storeResult = await plaidDataService.storeTransactions({
          itemId: item_id,
          transactions: transactionsResponse.transactions,
          userId: user_id
        });

        if (!storeResult.success) {
          logger.error('Failed to store transactions', { error: storeResult.error });
          return;
        }

        logger.info('Transactions persisted', { count: transactionsResponse.transactions.length, itemId: item_id });

        // 4. Store/update accounts information
        if (transactionsResponse.accounts && transactionsResponse.accounts.length > 0) {
          await plaidDataService.upsertAccounts({
            itemId: item_id,
            accounts: transactionsResponse.accounts,
            userId: user_id
          });
        }

        // 5. Notify user of new data
        await plaidDataService.createNotification({
          userId: user_id,
          itemId: item_id,
          type: 'transactions_updated',
          message: `${new_transactions} new transactions have been synced to your account`,
          priority: 'low'
        });

        logger.info('Transactions processed', { count: new_transactions, itemId: item_id });
      } catch (error) {
        logger.error('Error processing transaction webhook', { itemId: item_id, error: error.message });
      }
      break;

    case 'TRANSACTIONS_REMOVED':
      logger.info('Transactions removed webhook', { itemId: item_id, count: removed_transactions.length });

      try {
        // Remove transactions from database
        const removeResult = await plaidDataService.removeTransactions({
          transactionIds: removed_transactions
        });

        if (!removeResult.success) {
          logger.error('Failed to remove transactions', { error: removeResult.error });
        } else {
          logger.info('Transactions removed successfully', { count: removed_transactions.length });
        }
      } catch (error) {
        logger.error('Error removing transactions', { error: error.message });
      }
      break;

    default:
      logger.info('Unhandled transaction webhook code', { code: webhook_code });
  }
}

async function handleItemWebhook(data) {
  const { webhook_code, item_id, error } = data;

  switch (webhook_code) {
    case 'ERROR':
      logger.error('Item error', { itemId: item_id, errorCode: error?.error_code });

      try {
        // Get item details for user notification
        const itemResult = await plaidDataService.getItem(item_id);
        if (!itemResult.success) {
          logger.error('Failed to find item for error handling', { itemId: item_id });
          return;
        }

        const { user_id } = itemResult.data;

        // Handle specific error types
        if (error && error.error_code === 'ITEM_LOGIN_REQUIRED') {
          // User needs to re-authenticate
          await plaidDataService.updateItemStatus({
            itemId: item_id,
            status: 'login_required',
            error: error,
            requiresAction: true
          });

          // Send high priority notification
          await plaidDataService.createNotification({
            userId: user_id,
            itemId: item_id,
            type: 'authentication_required',
            message: 'Your bank connection requires re-authentication. Please log in again to continue receiving updates.',
            priority: 'high'
          });

          logger.warn('Item requires re-authentication', { itemId: item_id });
        } else {
          // Generic error handling
          await plaidDataService.updateItemStatus({
            itemId: item_id,
            status: 'error',
            error: error,
            requiresAction: true
          });

          await plaidDataService.createNotification({
            userId: user_id,
            itemId: item_id,
            type: 'item_error',
            message: `An error occurred with your bank connection: ${error.error_message || 'Unknown error'}`,
            priority: 'medium'
          });

          logger.error('Item encountered error', { itemId: item_id, errorCode: error.error_code });
        }
      } catch (err) {
        logger.error('Error handling item error webhook', { error: err.message });
      }
      break;

    case 'PENDING_EXPIRATION':
      logger.warn('Item consent expiring soon', { itemId: item_id });

      try {
        // Get item details for user notification
        const itemResult = await plaidDataService.getItem(item_id);
        if (!itemResult.success) {
          logger.error('Failed to find item for expiration warning', { itemId: item_id });
          return;
        }

        const { user_id } = itemResult.data;

        // Update item status to warn about expiration
        await plaidDataService.updateItemStatus({
          itemId: item_id,
          status: 'expiring_soon',
          requiresAction: true
        });

        // Send warning notification
        await plaidDataService.createNotification({
          userId: user_id,
          itemId: item_id,
          type: 'consent_expiring',
          message: 'Your bank connection will expire soon. Please re-authenticate to maintain access to your financial data.',
          priority: 'high'
        });

        logger.info('User notified about pending expiration', { itemId: item_id });
      } catch (err) {
        logger.error('Error handling pending expiration webhook', { error: err.message });
      }
      break;

    case 'USER_PERMISSION_REVOKED':
      logger.info('User revoked permission', { itemId: item_id });

      try {
        // Get item details for logging
        const itemResult = await plaidDataService.getItem(item_id);
        if (!itemResult.success) {
          logger.error('Failed to find item for permission revocation', { itemId: item_id });
          return;
        }

        const { user_id } = itemResult.data;

        // Mark item as inactive in database
        await plaidDataService.updateItemStatus({
          itemId: item_id,
          status: 'permission_revoked',
          requiresAction: false
        });

        // Notify user that connection has been revoked
        await plaidDataService.createNotification({
          userId: user_id,
          itemId: item_id,
          type: 'permission_revoked',
          message: 'Your bank connection has been disconnected. You can reconnect at any time from your settings.',
          priority: 'medium'
        });

        logger.info('Item marked as inactive due to permission revocation', { itemId: item_id });
      } catch (err) {
        logger.error('Error handling permission revocation webhook', { error: err.message });
      }
      break;

    case 'WEBHOOK_UPDATE_ACKNOWLEDGED':
      logger.info('Webhook update acknowledged', { itemId: item_id });

      // Update last webhook timestamp
      try {
        await plaidDataService.updateItemStatus({
          itemId: item_id,
          status: 'active',
          requiresAction: false
        });
      } catch (err) {
        logger.error('Error acknowledging webhook update', { error: err.message });
      }
      break;

    default:
      logger.info('Unhandled item webhook code', { code: webhook_code });
  }
}

async function handleAuthWebhook(data) {
  const { webhook_code, item_id } = data;

  switch (webhook_code) {
    case 'AUTOMATICALLY_VERIFIED':
      logger.info('Auth automatically verified', { itemId: item_id });
      break;

    case 'VERIFICATION_EXPIRED':
      logger.warn('Auth verification expired', { itemId: item_id });
      break;

    default:
      logger.info('Unhandled auth webhook code', { code: webhook_code });
  }
}

// ============================================
// TESTING & SANDBOX ENDPOINTS
// ============================================

/**
 * POST /v1/plaid/sandbox_public_token
 * Create sandbox public token (for testing only)
 *
 * Only available in sandbox/development environments.
 *
 * Request Body:
 * - institution_id (optional): Sandbox institution ID
 * - initial_products (optional): Array of products to enable
 *
 * Response:
 * - public_token: Public token for sandbox testing
 */
router.post('/sandbox_public_token', validate(sandboxTokenSchema), async (req, res, next) => {
  try {
    // Block in production
    if (process.env.PLAID_ENV === 'production') {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Sandbox endpoints are not available in production'
      });
    }

    const { institution_id, initial_products } = req.body;

    const publicToken = await plaidService.createSandboxPublicToken({
      institutionId: institution_id,
      initialProducts: initial_products
    });

    res.json({
      public_token: publicToken
    });

  } catch (error) {
    logger.error('Sandbox token creation error', { error: error.message });
    next(error);
  }
});

/**
 * POST /v1/plaid/test
 * Test Plaid connection and configuration
 *
 * Response:
 * - success: Whether connection is working
 * - usingMock: Whether using mock service
 * - environment: Current Plaid environment
 * - webhookConfigured: Whether webhook URL is configured
 * - apiConnectivity: Status of API connection (if using real Plaid)
 */
router.post('/test', async (req, res, next) => {
  try {
    const status = await plaidService.testConnection();
    res.json(status);
  } catch (error) {
    logger.error('Plaid test error', { error: error.message });
    next(error);
  }
});

// ============================================
// ERROR HANDLING
// ============================================

/**
 * Custom error handler for Plaid-specific errors
 */
router.use((err, req, res, next) => {
  // Plaid-specific errors
  if (err.type && err.code) {
    const statusCode = err.statusCode || 400;

    return res.status(statusCode).json({
      error: 'Plaid API Error',
      type: err.type,
      code: err.code,
      message: err.message,
      displayMessage: err.displayMessage || err.message,
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    });
  }

  // Generic errors
  const statusCode = err.statusCode || 500;
  const message = process.env.NODE_ENV === 'production' && statusCode === 500
    ? 'Internal server error'
    : err.message;

  res.status(statusCode).json({
    error: 'Error',
    message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

module.exports = router;
