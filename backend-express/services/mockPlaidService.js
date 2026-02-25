// Mock Plaid service for development/testing when credentials aren't available
const crypto = require('crypto');
const { createLogger } = require('../utils/logger');
const logger = createLogger('plaid-mock');

class MockPlaidService {
  constructor() {
    this.mockData = {
      accounts: [
        {
          accountId: 'mock_account_1',
          name: 'Chase Checking',
          officialName: 'Chase Total Checking',
          type: 'depository',
          subtype: 'checking',
          balances: {
            available: 12543.67,
            current: 12543.67,
            limit: null,
            currency: 'USD'
          }
        },
        {
          accountId: 'mock_account_2',
          name: 'Wells Fargo Savings',
          officialName: 'Wells Fargo Way2Save Savings',
          type: 'depository',
          subtype: 'savings',
          balances: {
            available: 25000.00,
            current: 25000.00,
            limit: null,
            currency: 'USD'
          }
        },
        {
          accountId: 'mock_account_3',
          name: 'Citi Credit Card',
          officialName: 'Citi Double Cash Card',
          type: 'credit',
          subtype: 'credit card',
          balances: {
            available: 7543.67,
            current: -2456.33,
            limit: 10000.00,
            currency: 'USD'
          }
        }
      ],
      transactions: [
        {
          transactionId: 'mock_txn_1',
          accountId: 'mock_account_1',
          amount: -1200.00,
          date: this.getDateDaysAgo(5),
          name: 'Mortgage Payment - Bank of America',
          merchantName: 'Bank of America',
          category: ['Payment', 'Mortgage'],
          pending: false,
          paymentChannel: 'online'
        },
        {
          transactionId: 'mock_txn_2',
          accountId: 'mock_account_1',
          amount: -85.43,
          date: this.getDateDaysAgo(5),
          name: 'Escrow Shortage Adjustment',
          merchantName: 'Bank of America',
          category: ['Payment', 'Mortgage'],
          pending: false,
          paymentChannel: 'online'
        },
        {
          transactionId: 'mock_txn_3',
          accountId: 'mock_account_1',
          amount: 3500.00,
          date: this.getDateDaysAgo(7),
          name: 'Payroll Deposit',
          merchantName: 'ACME Corporation',
          category: ['Transfer', 'Payroll'],
          pending: false,
          paymentChannel: 'other'
        },
        {
          transactionId: 'mock_txn_4',
          accountId: 'mock_account_1',
          amount: -150.00,
          date: this.getDateDaysAgo(10),
          name: 'Electricity Bill',
          merchantName: 'Power Company',
          category: ['Service', 'Utilities'],
          pending: false,
          paymentChannel: 'online'
        },
        {
          transactionId: 'mock_txn_5',
          accountId: 'mock_account_2',
          amount: 500.00,
          date: this.getDateDaysAgo(15),
          name: 'Transfer from Checking',
          merchantName: null,
          category: ['Transfer'],
          pending: false,
          paymentChannel: 'other'
        }
      ]
    };
  }

  getDateDaysAgo(days) {
    const date = new Date();
    date.setDate(date.getDate() - days);
    return date.toISOString().split('T')[0];
  }

  generateMockToken(prefix) {
    return `${prefix}-${crypto.randomBytes(16).toString('hex')}`;
  }

  async createLinkToken({ userId, clientName }) {
    logger.debug('Mock: creating link token', { userId });
    return this.generateMockToken('link-sandbox');
  }

  async createSandboxPublicToken({ institutionId, initialProducts }) {
    logger.debug('Mock: creating sandbox public token', { institutionId });
    return this.generateMockToken('public-sandbox');
  }

  async exchangePublicToken(publicToken) {
    logger.debug('Mock: exchanging public token');
    return {
      accessToken: this.generateMockToken('access-sandbox'),
      itemId: this.generateMockToken('item')
    };
  }

  async getAccounts(accessToken) {
    logger.debug('Mock: getting accounts');
    return this.mockData.accounts;
  }

  async getTransactions({ accessToken, startDate, endDate }) {
    logger.debug('Mock: getting transactions', { startDate, endDate });
    // Filter transactions by date range
    return this.mockData.transactions.filter(txn => {
      return txn.date >= startDate && txn.date <= endDate;
    });
  }
}

module.exports = MockPlaidService;
