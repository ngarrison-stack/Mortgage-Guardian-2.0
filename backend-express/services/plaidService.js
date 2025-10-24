const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');
const MockPlaidService = require('./mockPlaidService');

// Initialize Plaid client
const plaidClientId = process.env.PLAID_CLIENT_ID;
const plaidSecret = process.env.PLAID_SECRET;
const plaidEnvironment = process.env.PLAID_ENV === 'production'
  ? PlaidEnvironments.production
  : PlaidEnvironments.sandbox;

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
      },
    },
  });
  client = new PlaidApi(configuration);
  console.log(`🔗 Using Real Plaid API (${process.env.PLAID_ENV || 'sandbox'})`);
}

class PlaidService {
  /**
   * Create Plaid Link token for bank connection flow
   */
  async createLinkToken({ userId, clientName = 'Mortgage Guardian' }) {
    if (useMockService) {
      return mockService.createLinkToken({ userId, clientName });
    }

    try {
      const response = await client.linkTokenCreate({
        user: {
          client_user_id: userId,
        },
        client_name: clientName,
        products: ['auth', 'transactions'],
        country_codes: ['US'],
        language: 'en',
      });

      return response.data.link_token;
    } catch (error) {
      console.error('Plaid createLinkToken error:', error);
      throw error;
    }
  }

  /**
   * Create sandbox public token (for testing)
   */
  async createSandboxPublicToken({ institutionId = 'ins_109508', initialProducts = ['transactions'] }) {
    if (useMockService) {
      return mockService.createSandboxPublicToken({ institutionId, initialProducts });
    }

    try {
      const response = await client.sandboxPublicTokenCreate({
        institution_id: institutionId,
        initial_products: initialProducts,
      });

      return response.data.public_token;
    } catch (error) {
      console.error('Plaid createSandboxPublicToken error:', error);
      throw error;
    }
  }

  /**
   * Exchange public token for access token
   */
  async exchangePublicToken(publicToken) {
    if (useMockService) {
      return mockService.exchangePublicToken(publicToken);
    }

    try {
      const response = await client.itemPublicTokenExchange({
        public_token: publicToken,
      });

      return {
        accessToken: response.data.access_token,
        itemId: response.data.item_id
      };
    } catch (error) {
      console.error('Plaid exchangePublicToken error:', error);
      throw error;
    }
  }

  /**
   * Get account information
   */
  async getAccounts(accessToken) {
    if (useMockService) {
      return mockService.getAccounts(accessToken);
    }

    try {
      const response = await client.accountsGet({
        access_token: accessToken,
      });

      return response.data.accounts.map(account => ({
        accountId: account.account_id,
        name: account.name,
        officialName: account.official_name,
        type: account.type,
        subtype: account.subtype,
        balances: {
          available: account.balances.available,
          current: account.balances.current,
          limit: account.balances.limit,
          currency: account.balances.iso_currency_code
        }
      }));
    } catch (error) {
      console.error('Plaid getAccounts error:', error);
      throw error;
    }
  }

  /**
   * Get transaction history
   */
  async getTransactions({ accessToken, startDate, endDate }) {
    if (useMockService) {
      return mockService.getTransactions({ accessToken, startDate, endDate });
    }

    try {
      const response = await client.transactionsGet({
        access_token: accessToken,
        start_date: startDate,
        end_date: endDate,
      });

      return response.data.transactions.map(txn => ({
        transactionId: txn.transaction_id,
        accountId: txn.account_id,
        amount: txn.amount,
        date: txn.date,
        name: txn.name,
        merchantName: txn.merchant_name,
        category: txn.category,
        pending: txn.pending,
        paymentChannel: txn.payment_channel
      }));
    } catch (error) {
      console.error('Plaid getTransactions error:', error);
      throw error;
    }
  }

  /**
   * Test Plaid connection
   */
  async testConnection() {
    return {
      success: true,
      usingMock: useMockService,
      environment: process.env.PLAID_ENV || 'sandbox',
      message: useMockService
        ? 'Using mock Plaid service (configure PLAID_CLIENT_ID and PLAID_SECRET for real API)'
        : 'Connected to real Plaid API'
    };
  }
}

module.exports = new PlaidService();
