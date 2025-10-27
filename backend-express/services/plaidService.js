const { Configuration, PlaidApi, PlaidEnvironments, Products, CountryCode } = require('plaid');
const MockPlaidService = require('./mockPlaidService');
const crypto = require('crypto');

// Initialize Plaid client with enhanced configuration
const plaidClientId = process.env.PLAID_CLIENT_ID;
const plaidSecret = process.env.PLAID_SECRET;
const plaidEnvironmentName = process.env.PLAID_ENV || 'sandbox';

// Map environment string to Plaid environment enum
const plaidEnvironment = plaidEnvironmentName === 'production'
  ? PlaidEnvironments.production
  : plaidEnvironmentName === 'development'
    ? PlaidEnvironments.development
    : PlaidEnvironments.sandbox;

// Webhook URL for real-time updates
const webhookUrl = process.env.PLAID_WEBHOOK_URL;

// Check if we should use mock service
const useMockService = !plaidClientId || !plaidSecret || plaidClientId === 'mock';

let client = null;
let mockService = null;

if (useMockService) {
  mockService = new MockPlaidService();
  console.log('🧪 Using Mock Plaid Service (no valid credentials)');
} else {
  const configuration = new Configuration({
    basePath: plaidEnvironment,
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': plaidClientId,
        'PLAID-SECRET': plaidSecret,
        'Plaid-Version': '2020-09-14', // Latest stable API version
      },
    },
  });
  client = new PlaidApi(configuration);
  console.log(`🔗 Using Real Plaid API (${plaidEnvironmentName})`);
  if (webhookUrl) {
    console.log(`📡 Webhook URL configured: ${webhookUrl}`);
  }
}

class PlaidService {
  /**
   * Create Plaid Link token for bank connection flow
   * @param {string} userId - Unique user identifier
   * @param {string} clientName - Display name for Link UI
   * @param {string} redirectUri - Optional redirect URI for OAuth
   * @param {string} accessToken - Optional access token for update mode
   * @param {Array<string>} products - Plaid products to enable
   * @returns {Promise<Object>} Link token and metadata
   */
  async createLinkToken({
    userId,
    clientName = 'Mortgage Guardian',
    redirectUri = null,
    accessToken = null,
    products = [Products.Auth, Products.Transactions]
  }) {
    if (useMockService) {
      return {
        link_token: await mockService.createLinkToken({ userId, clientName }),
        expiration: new Date(Date.now() + 14400000).toISOString(), // 4 hours
        request_id: 'mock-request-id'
      };
    }

    try {
      // Validate userId
      if (!userId || typeof userId !== 'string' || userId.trim().length === 0) {
        throw new Error('Valid userId is required');
      }

      const linkTokenRequest = {
        user: {
          client_user_id: userId,
        },
        client_name: clientName,
        products: products,
        country_codes: [CountryCode.Us],
        language: 'en',
        webhook: webhookUrl || undefined, // Only include if configured
      };

      // Add redirect URI for OAuth institutions
      if (redirectUri) {
        linkTokenRequest.redirect_uri = redirectUri;
      }

      // Add access token for update mode (re-authentication)
      if (accessToken) {
        linkTokenRequest.access_token = accessToken;
      }

      const response = await client.linkTokenCreate(linkTokenRequest);

      return {
        link_token: response.data.link_token,
        expiration: response.data.expiration,
        request_id: response.data.request_id
      };
    } catch (error) {
      console.error('Plaid createLinkToken error:', {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      throw this.formatPlaidError(error);
    }
  }

  /**
   * Create sandbox public token (for testing only - not for production)
   * @param {string} institutionId - Sandbox institution ID
   * @param {Array<string>} initialProducts - Plaid products to enable
   * @returns {Promise<string>} Public token
   */
  async createSandboxPublicToken({ institutionId = 'ins_109508', initialProducts = [Products.Transactions] }) {
    if (useMockService) {
      return mockService.createSandboxPublicToken({ institutionId, initialProducts });
    }

    // Only allow in non-production environments
    if (plaidEnvironmentName === 'production') {
      throw new Error('Sandbox tokens cannot be created in production environment');
    }

    try {
      const response = await client.sandboxPublicTokenCreate({
        institution_id: institutionId,
        initial_products: initialProducts,
      });

      return response.data.public_token;
    } catch (error) {
      console.error('Plaid createSandboxPublicToken error:', error);
      throw this.formatPlaidError(error);
    }
  }

  /**
   * Exchange public token for access token
   * This is a one-time operation that occurs after Link success
   * @param {string} publicToken - Public token from Plaid Link
   * @returns {Promise<Object>} Access token and item ID
   */
  async exchangePublicToken(publicToken) {
    if (useMockService) {
      return mockService.exchangePublicToken(publicToken);
    }

    try {
      // Validate public token format
      if (!publicToken || typeof publicToken !== 'string' || !publicToken.startsWith('public-')) {
        throw new Error('Invalid public token format');
      }

      const response = await client.itemPublicTokenExchange({
        public_token: publicToken,
      });

      // Log successful exchange (but not the tokens themselves)
      console.log('Successfully exchanged public token for item:', response.data.item_id);

      return {
        accessToken: response.data.access_token,
        itemId: response.data.item_id,
        requestId: response.data.request_id
      };
    } catch (error) {
      console.error('Plaid exchangePublicToken error:', {
        message: error.message,
        status: error.response?.status
      });
      throw this.formatPlaidError(error);
    }
  }

  /**
   * Get account information
   * @param {string} accessToken - Plaid access token
   * @param {Array<string>} accountIds - Optional specific account IDs to fetch
   * @returns {Promise<Object>} Accounts and item metadata
   */
  async getAccounts(accessToken, accountIds = null) {
    if (useMockService) {
      return { accounts: await mockService.getAccounts(accessToken), item: null };
    }

    try {
      // Validate access token format
      if (!accessToken || typeof accessToken !== 'string' || !accessToken.startsWith('access-')) {
        throw new Error('Invalid access token format');
      }

      const request = {
        access_token: accessToken,
      };

      // Add specific account IDs if provided
      if (accountIds && Array.isArray(accountIds) && accountIds.length > 0) {
        request.options = { account_ids: accountIds };
      }

      const response = await client.accountsGet(request);

      const accounts = response.data.accounts.map(account => ({
        accountId: account.account_id,
        name: account.name,
        officialName: account.official_name || account.name,
        type: account.type,
        subtype: account.subtype,
        mask: account.mask,
        balances: {
          available: account.balances.available,
          current: account.balances.current,
          limit: account.balances.limit,
          currency: account.balances.iso_currency_code || 'USD',
          unofficialCurrency: account.balances.unofficial_currency_code
        },
        verificationStatus: account.verification_status
      }));

      return {
        accounts,
        item: {
          itemId: response.data.item.item_id,
          institutionId: response.data.item.institution_id,
          webhook: response.data.item.webhook,
          availableProducts: response.data.item.available_products,
          billedProducts: response.data.item.billed_products,
          consentExpirationTime: response.data.item.consent_expiration_time,
          updateType: response.data.item.update_type
        },
        requestId: response.data.request_id
      };
    } catch (error) {
      console.error('Plaid getAccounts error:', {
        message: error.message,
        status: error.response?.status
      });
      throw this.formatPlaidError(error);
    }
  }

  /**
   * Get transaction history with pagination support
   * @param {string} accessToken - Plaid access token
   * @param {string} startDate - Start date (YYYY-MM-DD)
   * @param {string} endDate - End date (YYYY-MM-DD)
   * @param {Array<string>} accountIds - Optional specific account IDs
   * @param {number} count - Number of transactions to fetch (max 500)
   * @param {number} offset - Pagination offset
   * @returns {Promise<Object>} Transactions and metadata
   */
  async getTransactions({
    accessToken,
    startDate,
    endDate,
    accountIds = null,
    count = 100,
    offset = 0
  }) {
    if (useMockService) {
      return {
        transactions: await mockService.getTransactions({ accessToken, startDate, endDate }),
        totalTransactions: 5,
        accounts: []
      };
    }

    try {
      // Validate access token
      if (!accessToken || typeof accessToken !== 'string' || !accessToken.startsWith('access-')) {
        throw new Error('Invalid access token format');
      }

      // Validate dates
      if (!this.isValidDate(startDate) || !this.isValidDate(endDate)) {
        throw new Error('Invalid date format. Use YYYY-MM-DD');
      }

      // Validate date range (Plaid allows max 2 years)
      const daysDiff = Math.floor((new Date(endDate) - new Date(startDate)) / (1000 * 60 * 60 * 24));
      if (daysDiff > 730) {
        throw new Error('Date range cannot exceed 2 years');
      }

      if (daysDiff < 0) {
        throw new Error('End date must be after start date');
      }

      // Validate pagination parameters
      if (count < 1 || count > 500) {
        throw new Error('Count must be between 1 and 500');
      }

      const request = {
        access_token: accessToken,
        start_date: startDate,
        end_date: endDate,
        options: {
          count,
          offset,
          include_original_description: true,
          include_personal_finance_category: true
        }
      };

      // Add specific account IDs if provided
      if (accountIds && Array.isArray(accountIds) && accountIds.length > 0) {
        request.options.account_ids = accountIds;
      }

      const response = await client.transactionsGet(request);

      const transactions = response.data.transactions.map(txn => ({
        transactionId: txn.transaction_id,
        accountId: txn.account_id,
        amount: txn.amount,
        date: txn.date,
        authorizedDate: txn.authorized_date,
        name: txn.name,
        merchantName: txn.merchant_name,
        originalDescription: txn.original_description,
        category: txn.category,
        categoryId: txn.category_id,
        personalFinanceCategory: txn.personal_finance_category,
        pending: txn.pending,
        pendingTransactionId: txn.pending_transaction_id,
        paymentChannel: txn.payment_channel,
        transactionType: txn.transaction_type,
        transactionCode: txn.transaction_code,
        location: txn.location,
        paymentMeta: txn.payment_meta,
        accountOwner: txn.account_owner,
        isoCurrencyCode: txn.iso_currency_code,
        unofficialCurrencyCode: txn.unofficial_currency_code
      }));

      return {
        transactions,
        totalTransactions: response.data.total_transactions,
        accounts: response.data.accounts.map(account => ({
          accountId: account.account_id,
          name: account.name,
          type: account.type,
          subtype: account.subtype,
          mask: account.mask
        })),
        requestId: response.data.request_id
      };
    } catch (error) {
      console.error('Plaid getTransactions error:', {
        message: error.message,
        status: error.response?.status
      });
      throw this.formatPlaidError(error);
    }
  }

  /**
   * Get item (bank connection) information
   * @param {string} accessToken - Plaid access token
   * @returns {Promise<Object>} Item information
   */
  async getItem(accessToken) {
    if (useMockService) {
      return {
        itemId: 'mock-item-id',
        institutionId: 'ins_109508',
        webhook: webhookUrl,
        error: null,
        availableProducts: ['auth', 'transactions'],
        billedProducts: ['auth', 'transactions'],
        consentExpirationTime: null
      };
    }

    try {
      if (!accessToken || typeof accessToken !== 'string' || !accessToken.startsWith('access-')) {
        throw new Error('Invalid access token format');
      }

      const response = await client.itemGet({
        access_token: accessToken
      });

      return {
        itemId: response.data.item.item_id,
        institutionId: response.data.item.institution_id,
        webhook: response.data.item.webhook,
        error: response.data.item.error,
        availableProducts: response.data.item.available_products,
        billedProducts: response.data.item.billed_products,
        consentExpirationTime: response.data.item.consent_expiration_time,
        updateType: response.data.item.update_type,
        requestId: response.data.request_id
      };
    } catch (error) {
      console.error('Plaid getItem error:', {
        message: error.message,
        status: error.response?.status
      });
      throw this.formatPlaidError(error);
    }
  }

  /**
   * Update webhook URL for an item
   * @param {string} accessToken - Plaid access token
   * @param {string} webhook - New webhook URL
   * @returns {Promise<Object>} Updated item
   */
  async updateWebhook(accessToken, webhook) {
    if (useMockService) {
      return { itemId: 'mock-item-id', webhook };
    }

    try {
      if (!accessToken || typeof accessToken !== 'string' || !accessToken.startsWith('access-')) {
        throw new Error('Invalid access token format');
      }

      if (webhook && !this.isValidUrl(webhook)) {
        throw new Error('Invalid webhook URL format');
      }

      const response = await client.itemWebhookUpdate({
        access_token: accessToken,
        webhook: webhook
      });

      return {
        itemId: response.data.item.item_id,
        webhook: response.data.item.webhook,
        requestId: response.data.request_id
      };
    } catch (error) {
      console.error('Plaid updateWebhook error:', {
        message: error.message,
        status: error.response?.status
      });
      throw this.formatPlaidError(error);
    }
  }

  /**
   * Remove (delete) an item
   * @param {string} accessToken - Plaid access token
   * @returns {Promise<Object>} Deletion confirmation
   */
  async removeItem(accessToken) {
    if (useMockService) {
      return { removed: true, itemId: 'mock-item-id' };
    }

    try {
      if (!accessToken || typeof accessToken !== 'string' || !accessToken.startsWith('access-')) {
        throw new Error('Invalid access token format');
      }

      const response = await client.itemRemove({
        access_token: accessToken
      });

      console.log('Successfully removed item');

      return {
        removed: true,
        requestId: response.data.request_id
      };
    } catch (error) {
      console.error('Plaid removeItem error:', {
        message: error.message,
        status: error.response?.status
      });
      throw this.formatPlaidError(error);
    }
  }

  /**
   * Verify webhook signature for security
   * @param {string} bodyRaw - Raw request body
   * @param {Object} headers - Request headers
   * @returns {boolean} Whether signature is valid
   */
  verifyWebhookSignature(bodyRaw, headers) {
    try {
      const webhookVerificationKey = process.env.PLAID_WEBHOOK_VERIFICATION_KEY;

      if (!webhookVerificationKey) {
        console.warn('PLAID_WEBHOOK_VERIFICATION_KEY not configured - skipping signature verification');
        return true; // Allow in development, but should be required in production
      }

      const signature = headers['plaid-verification'];
      if (!signature) {
        console.error('Missing Plaid-Verification header');
        return false;
      }

      // Create HMAC signature
      const hmac = crypto.createHmac('sha256', webhookVerificationKey);
      hmac.update(bodyRaw);
      const expectedSignature = hmac.digest('hex');

      // Constant-time comparison to prevent timing attacks
      return crypto.timingSafeEqual(
        Buffer.from(signature, 'hex'),
        Buffer.from(expectedSignature, 'hex')
      );
    } catch (error) {
      console.error('Webhook signature verification error:', error);
      return false;
    }
  }

  /**
   * Test Plaid connection and configuration
   * @returns {Promise<Object>} Connection status
   */
  async testConnection() {
    const status = {
      success: true,
      usingMock: useMockService,
      environment: plaidEnvironmentName,
      webhookConfigured: !!webhookUrl,
      message: useMockService
        ? 'Using mock Plaid service (configure PLAID_CLIENT_ID and PLAID_SECRET for real API)'
        : 'Connected to real Plaid API'
    };

    // If using real Plaid, test the connection
    if (!useMockService) {
      try {
        // Test by getting categories (lightweight endpoint)
        await client.categoriesGet({});
        status.apiConnectivity = 'healthy';
      } catch (error) {
        status.apiConnectivity = 'error';
        status.error = error.message;
        status.success = false;
      }
    }

    return status;
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /**
   * Format Plaid API errors into user-friendly messages
   * @param {Error} error - Plaid API error
   * @returns {Error} Formatted error
   */
  formatPlaidError(error) {
    if (error.response?.data) {
      const plaidError = error.response.data;
      const formattedError = new Error(plaidError.error_message || 'Plaid API error');
      formattedError.type = plaidError.error_type;
      formattedError.code = plaidError.error_code;
      formattedError.displayMessage = plaidError.display_message;
      formattedError.statusCode = error.response.status;
      return formattedError;
    }
    return error;
  }

  /**
   * Validate date format (YYYY-MM-DD)
   * @param {string} dateString - Date string to validate
   * @returns {boolean} Whether date is valid
   */
  isValidDate(dateString) {
    if (!dateString || typeof dateString !== 'string') return false;
    const regex = /^\d{4}-\d{2}-\d{2}$/;
    if (!regex.test(dateString)) return false;
    const date = new Date(dateString);
    return date instanceof Date && !isNaN(date);
  }

  /**
   * Validate URL format
   * @param {string} url - URL to validate
   * @returns {boolean} Whether URL is valid
   */
  isValidUrl(url) {
    try {
      new URL(url);
      return true;
    } catch {
      return false;
    }
  }
}

module.exports = new PlaidService();
