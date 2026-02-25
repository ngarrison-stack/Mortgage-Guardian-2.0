/**
 * Unit tests for PlaidService (services/plaidService.js)
 *
 * Tests all Plaid API methods, helper functions, webhook verification,
 * testConnection, and mock fallback behavior with a fully mocked Plaid SDK.
 */

const crypto = require('crypto');

// ── Mock Plaid SDK ──────────────────────────────────────────────────────────
const mockPlaidClient = {
  linkTokenCreate: jest.fn(),
  itemPublicTokenExchange: jest.fn(),
  accountsGet: jest.fn(),
  transactionsGet: jest.fn(),
  itemGet: jest.fn(),
  itemWebhookUpdate: jest.fn(),
  itemRemove: jest.fn(),
  sandboxPublicTokenCreate: jest.fn(),
  categoriesGet: jest.fn()
};

jest.mock('plaid', () => ({
  Configuration: jest.fn(),
  PlaidApi: jest.fn(() => mockPlaidClient),
  PlaidEnvironments: {
    sandbox: 'https://sandbox.plaid.com',
    development: 'https://development.plaid.com',
    production: 'https://production.plaid.com'
  },
  Products: { Auth: 'auth', Transactions: 'transactions' },
  CountryCode: { Us: 'US' }
}));

// Set env vars BEFORE requiring plaidService so module-scope code uses real path
process.env.PLAID_CLIENT_ID = 'test_client_id';
process.env.PLAID_SECRET = 'test_secret';
process.env.PLAID_ENV = 'sandbox';

const plaidService = require('../../services/plaidService');

// ============================================================
// PlaidService — Real SDK path (mocked)
// ============================================================
describe('PlaidService', () => {
  beforeEach(() => {
    Object.values(mockPlaidClient).forEach(fn => fn.mockReset());
  });

  // ── createLinkToken ─────────────────────────────────────────
  describe('createLinkToken', () => {
    const mockResponse = {
      data: {
        link_token: 'link-sandbox-abc123',
        expiration: '2026-03-01T00:00:00Z',
        request_id: 'req-001'
      }
    };

    it('returns link token, expiration, and request_id on success', async () => {
      mockPlaidClient.linkTokenCreate.mockResolvedValue(mockResponse);

      const result = await plaidService.createLinkToken({ userId: 'user-1' });

      expect(result).toEqual({
        link_token: 'link-sandbox-abc123',
        expiration: '2026-03-01T00:00:00Z',
        request_id: 'req-001'
      });
    });

    it('forwards userId, clientName, and redirectUri parameters', async () => {
      mockPlaidClient.linkTokenCreate.mockResolvedValue(mockResponse);

      await plaidService.createLinkToken({
        userId: 'user-42',
        clientName: 'My App',
        redirectUri: 'https://example.com/callback'
      });

      expect(mockPlaidClient.linkTokenCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          user: { client_user_id: 'user-42' },
          client_name: 'My App',
          redirect_uri: 'https://example.com/callback'
        })
      );
    });

    it('includes access_token when provided (update mode)', async () => {
      mockPlaidClient.linkTokenCreate.mockResolvedValue(mockResponse);

      await plaidService.createLinkToken({
        userId: 'user-1',
        accessToken: 'access-sandbox-token'
      });

      expect(mockPlaidClient.linkTokenCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          access_token: 'access-sandbox-token'
        })
      );
    });

    it('throws formatted error when API rejects', async () => {
      const apiError = new Error('Request failed');
      apiError.response = {
        status: 400,
        data: {
          error_type: 'INVALID_REQUEST',
          error_code: 'MISSING_FIELDS',
          error_message: 'client_user_id is required',
          display_message: null
        }
      };
      mockPlaidClient.linkTokenCreate.mockRejectedValue(apiError);

      await expect(
        plaidService.createLinkToken({ userId: 'user-1' })
      ).rejects.toMatchObject({
        message: 'client_user_id is required',
        type: 'INVALID_REQUEST',
        code: 'MISSING_FIELDS'
      });
    });

    it('throws on empty userId', async () => {
      await expect(
        plaidService.createLinkToken({ userId: '' })
      ).rejects.toThrow('Valid userId is required');
    });

    it('throws on null userId', async () => {
      await expect(
        plaidService.createLinkToken({ userId: null })
      ).rejects.toThrow('Valid userId is required');
    });
  });

  // ── createSandboxPublicToken ────────────────────────────────
  describe('createSandboxPublicToken', () => {
    it('returns public token on success', async () => {
      mockPlaidClient.sandboxPublicTokenCreate.mockResolvedValue({
        data: { public_token: 'public-sandbox-xyz' }
      });

      const result = await plaidService.createSandboxPublicToken({});

      expect(result).toBe('public-sandbox-xyz');
    });

    it('forwards institutionId and initialProducts', async () => {
      mockPlaidClient.sandboxPublicTokenCreate.mockResolvedValue({
        data: { public_token: 'public-sandbox-xyz' }
      });

      await plaidService.createSandboxPublicToken({
        institutionId: 'ins_123',
        initialProducts: ['transactions', 'auth']
      });

      expect(mockPlaidClient.sandboxPublicTokenCreate).toHaveBeenCalledWith({
        institution_id: 'ins_123',
        initial_products: ['transactions', 'auth']
      });
    });

    it('throws formatted error on API failure', async () => {
      const apiError = new Error('Sandbox error');
      apiError.response = {
        status: 400,
        data: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_INSTITUTION',
          error_message: 'Institution not found',
          display_message: null
        }
      };
      mockPlaidClient.sandboxPublicTokenCreate.mockRejectedValue(apiError);

      await expect(
        plaidService.createSandboxPublicToken({})
      ).rejects.toMatchObject({
        message: 'Institution not found',
        type: 'INVALID_INPUT'
      });
    });
  });

  // ── exchangePublicToken ─────────────────────────────────────
  describe('exchangePublicToken', () => {
    it('returns accessToken, itemId, and requestId on success', async () => {
      mockPlaidClient.itemPublicTokenExchange.mockResolvedValue({
        data: {
          access_token: 'access-sandbox-abc',
          item_id: 'item-001',
          request_id: 'req-002'
        }
      });

      const result = await plaidService.exchangePublicToken('public-sandbox-token');

      expect(result).toEqual({
        accessToken: 'access-sandbox-abc',
        itemId: 'item-001',
        requestId: 'req-002'
      });
    });

    it('throws formatted error on API rejection', async () => {
      const apiError = new Error('Exchange failed');
      apiError.response = {
        status: 400,
        data: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_PUBLIC_TOKEN',
          error_message: 'public token is expired',
          display_message: 'Please try again'
        }
      };
      mockPlaidClient.itemPublicTokenExchange.mockRejectedValue(apiError);

      await expect(
        plaidService.exchangePublicToken('public-sandbox-expired')
      ).rejects.toMatchObject({
        message: 'public token is expired',
        type: 'INVALID_INPUT',
        code: 'INVALID_PUBLIC_TOKEN',
        displayMessage: 'Please try again'
      });
    });

    it('throws on invalid token format (missing public- prefix)', async () => {
      await expect(
        plaidService.exchangePublicToken('invalid-token')
      ).rejects.toThrow('Invalid public token format');
    });
  });

  // ── getAccounts ─────────────────────────────────────────────
  describe('getAccounts', () => {
    const mockAccountResponse = {
      data: {
        accounts: [{
          account_id: 'acc-001',
          name: 'Checking',
          official_name: 'Total Checking',
          type: 'depository',
          subtype: 'checking',
          mask: '1234',
          balances: {
            available: 5000,
            current: 5200,
            limit: null,
            iso_currency_code: 'USD',
            unofficial_currency_code: null
          },
          verification_status: null
        }],
        item: {
          item_id: 'item-001',
          institution_id: 'ins_109508',
          webhook: 'https://example.com/webhook',
          available_products: ['auth'],
          billed_products: ['transactions'],
          consent_expiration_time: null,
          update_type: 'background'
        },
        request_id: 'req-003'
      }
    };

    it('returns mapped accounts and item metadata on success', async () => {
      mockPlaidClient.accountsGet.mockResolvedValue(mockAccountResponse);

      const result = await plaidService.getAccounts('access-sandbox-token');

      expect(result.accounts).toHaveLength(1);
      expect(result.accounts[0]).toEqual({
        accountId: 'acc-001',
        name: 'Checking',
        officialName: 'Total Checking',
        type: 'depository',
        subtype: 'checking',
        mask: '1234',
        balances: {
          available: 5000,
          current: 5200,
          limit: null,
          currency: 'USD',
          unofficialCurrency: null
        },
        verificationStatus: null
      });
      expect(result.item.itemId).toBe('item-001');
      expect(result.requestId).toBe('req-003');
    });

    it('forwards optional account_ids filter', async () => {
      mockPlaidClient.accountsGet.mockResolvedValue(mockAccountResponse);

      await plaidService.getAccounts('access-sandbox-token', ['acc-001', 'acc-002']);

      expect(mockPlaidClient.accountsGet).toHaveBeenCalledWith({
        access_token: 'access-sandbox-token',
        options: { account_ids: ['acc-001', 'acc-002'] }
      });
    });

    it('does not include options when accountIds is null', async () => {
      mockPlaidClient.accountsGet.mockResolvedValue(mockAccountResponse);

      await plaidService.getAccounts('access-sandbox-token');

      expect(mockPlaidClient.accountsGet).toHaveBeenCalledWith({
        access_token: 'access-sandbox-token'
      });
    });

    it('throws on invalid access token format', async () => {
      await expect(
        plaidService.getAccounts('bad-token')
      ).rejects.toThrow('Invalid access token format');
    });
  });

  // ── getTransactions ─────────────────────────────────────────
  describe('getTransactions', () => {
    const mockTxnResponse = {
      data: {
        transactions: [{
          transaction_id: 'txn-001',
          account_id: 'acc-001',
          amount: 1200.00,
          date: '2026-02-20',
          authorized_date: '2026-02-19',
          name: 'Mortgage Payment',
          merchant_name: 'Bank of America',
          original_description: 'MORTGAGE PMT',
          category: ['Payment', 'Mortgage'],
          category_id: '16001000',
          personal_finance_category: { primary: 'LOAN_PAYMENTS' },
          pending: false,
          pending_transaction_id: null,
          payment_channel: 'online',
          transaction_type: 'special',
          transaction_code: null,
          location: {},
          payment_meta: {},
          account_owner: null,
          iso_currency_code: 'USD',
          unofficial_currency_code: null
        }],
        total_transactions: 1,
        accounts: [{
          account_id: 'acc-001',
          name: 'Checking',
          type: 'depository',
          subtype: 'checking',
          mask: '1234'
        }],
        request_id: 'req-004'
      }
    };

    it('returns mapped transactions, totalTransactions, and accounts', async () => {
      mockPlaidClient.transactionsGet.mockResolvedValue(mockTxnResponse);

      const result = await plaidService.getTransactions({
        accessToken: 'access-sandbox-token',
        startDate: '2026-02-01',
        endDate: '2026-02-28'
      });

      expect(result.transactions).toHaveLength(1);
      expect(result.transactions[0].transactionId).toBe('txn-001');
      expect(result.transactions[0].amount).toBe(1200.00);
      expect(result.transactions[0].name).toBe('Mortgage Payment');
      expect(result.totalTransactions).toBe(1);
      expect(result.accounts).toHaveLength(1);
      expect(result.requestId).toBe('req-004');
    });

    it('forwards count and offset pagination parameters', async () => {
      mockPlaidClient.transactionsGet.mockResolvedValue(mockTxnResponse);

      await plaidService.getTransactions({
        accessToken: 'access-sandbox-token',
        startDate: '2026-02-01',
        endDate: '2026-02-28',
        count: 50,
        offset: 10
      });

      expect(mockPlaidClient.transactionsGet).toHaveBeenCalledWith(
        expect.objectContaining({
          options: expect.objectContaining({
            count: 50,
            offset: 10
          })
        })
      );
    });

    it('forwards accountIds filter in options', async () => {
      mockPlaidClient.transactionsGet.mockResolvedValue(mockTxnResponse);

      await plaidService.getTransactions({
        accessToken: 'access-sandbox-token',
        startDate: '2026-02-01',
        endDate: '2026-02-28',
        accountIds: ['acc-001']
      });

      expect(mockPlaidClient.transactionsGet).toHaveBeenCalledWith(
        expect.objectContaining({
          options: expect.objectContaining({
            account_ids: ['acc-001']
          })
        })
      );
    });

    it('throws on invalid access token format', async () => {
      await expect(
        plaidService.getTransactions({
          accessToken: 'bad',
          startDate: '2026-02-01',
          endDate: '2026-02-28'
        })
      ).rejects.toThrow('Invalid access token format');
    });

    it('throws on invalid date format', async () => {
      await expect(
        plaidService.getTransactions({
          accessToken: 'access-sandbox-token',
          startDate: '02/01/2026',
          endDate: '2026-02-28'
        })
      ).rejects.toThrow('Invalid date format');
    });

    it('throws when date range exceeds 2 years', async () => {
      await expect(
        plaidService.getTransactions({
          accessToken: 'access-sandbox-token',
          startDate: '2023-01-01',
          endDate: '2026-02-28'
        })
      ).rejects.toThrow('Date range cannot exceed 2 years');
    });

    it('throws when end date is before start date', async () => {
      await expect(
        plaidService.getTransactions({
          accessToken: 'access-sandbox-token',
          startDate: '2026-03-01',
          endDate: '2026-02-01'
        })
      ).rejects.toThrow('End date must be after start date');
    });

    it('throws when count is out of range', async () => {
      await expect(
        plaidService.getTransactions({
          accessToken: 'access-sandbox-token',
          startDate: '2026-02-01',
          endDate: '2026-02-28',
          count: 501
        })
      ).rejects.toThrow('Count must be between 1 and 500');
    });
  });

  // ── getItem ─────────────────────────────────────────────────
  describe('getItem', () => {
    it('returns item details on success', async () => {
      mockPlaidClient.itemGet.mockResolvedValue({
        data: {
          item: {
            item_id: 'item-001',
            institution_id: 'ins_109508',
            webhook: 'https://example.com/webhook',
            error: null,
            available_products: ['auth'],
            billed_products: ['transactions'],
            consent_expiration_time: null,
            update_type: 'background'
          },
          request_id: 'req-005'
        }
      });

      const result = await plaidService.getItem('access-sandbox-token');

      expect(result).toEqual({
        itemId: 'item-001',
        institutionId: 'ins_109508',
        webhook: 'https://example.com/webhook',
        error: null,
        availableProducts: ['auth'],
        billedProducts: ['transactions'],
        consentExpirationTime: null,
        updateType: 'background',
        requestId: 'req-005'
      });
    });

    it('throws on invalid access token', async () => {
      await expect(
        plaidService.getItem('invalid')
      ).rejects.toThrow('Invalid access token format');
    });
  });

  // ── updateWebhook ───────────────────────────────────────────
  describe('updateWebhook', () => {
    it('returns updated item with new webhook URL', async () => {
      mockPlaidClient.itemWebhookUpdate.mockResolvedValue({
        data: {
          item: {
            item_id: 'item-001',
            webhook: 'https://new.example.com/webhook'
          },
          request_id: 'req-006'
        }
      });

      const result = await plaidService.updateWebhook(
        'access-sandbox-token',
        'https://new.example.com/webhook'
      );

      expect(result).toEqual({
        itemId: 'item-001',
        webhook: 'https://new.example.com/webhook',
        requestId: 'req-006'
      });
    });

    it('throws on invalid access token', async () => {
      await expect(
        plaidService.updateWebhook('bad', 'https://example.com')
      ).rejects.toThrow('Invalid access token format');
    });

    it('throws on invalid webhook URL', async () => {
      await expect(
        plaidService.updateWebhook('access-sandbox-token', 'not-a-url')
      ).rejects.toThrow('Invalid webhook URL format');
    });
  });

  // ── removeItem ──────────────────────────────────────────────
  describe('removeItem', () => {
    it('returns removed confirmation on success', async () => {
      mockPlaidClient.itemRemove.mockResolvedValue({
        data: { request_id: 'req-007' }
      });

      const result = await plaidService.removeItem('access-sandbox-token');

      expect(result).toEqual({
        removed: true,
        requestId: 'req-007'
      });
    });

    it('throws on invalid access token', async () => {
      await expect(
        plaidService.removeItem('bad')
      ).rejects.toThrow('Invalid access token format');
    });

    it('throws formatted error on API failure', async () => {
      const apiError = new Error('Remove failed');
      apiError.response = {
        status: 400,
        data: {
          error_type: 'INVALID_INPUT',
          error_code: 'INVALID_ACCESS_TOKEN',
          error_message: 'access token does not exist',
          display_message: null
        }
      };
      mockPlaidClient.itemRemove.mockRejectedValue(apiError);

      await expect(
        plaidService.removeItem('access-sandbox-bad')
      ).rejects.toMatchObject({
        message: 'access token does not exist',
        type: 'INVALID_INPUT',
        code: 'INVALID_ACCESS_TOKEN'
      });
    });
  });

  // ── verifyWebhookSignature ──────────────────────────────────
  describe('verifyWebhookSignature', () => {
    const webhookBody = '{"webhook_type":"TRANSACTIONS","webhook_code":"DEFAULT_UPDATE"}';

    it('returns true when HMAC signature matches', () => {
      const secret = 'test-webhook-secret';
      process.env.PLAID_WEBHOOK_VERIFICATION_KEY = secret;

      const hmac = crypto.createHmac('sha256', secret);
      hmac.update(webhookBody);
      const validSignature = hmac.digest('hex');

      const result = plaidService.verifyWebhookSignature(webhookBody, {
        'plaid-verification': validSignature
      });

      expect(result).toBe(true);
    });

    it('returns false for mismatched signature', () => {
      process.env.PLAID_WEBHOOK_VERIFICATION_KEY = 'test-webhook-secret';

      const result = plaidService.verifyWebhookSignature(webhookBody, {
        'plaid-verification': 'deadbeef'.repeat(8)
      });

      expect(result).toBe(false);
    });

    it('returns true (allow) when PLAID_WEBHOOK_VERIFICATION_KEY is not set', () => {
      delete process.env.PLAID_WEBHOOK_VERIFICATION_KEY;

      const result = plaidService.verifyWebhookSignature(webhookBody, {});

      expect(result).toBe(true);
    });

    it('returns false when plaid-verification header is missing', () => {
      process.env.PLAID_WEBHOOK_VERIFICATION_KEY = 'test-webhook-secret';

      const result = plaidService.verifyWebhookSignature(webhookBody, {});

      expect(result).toBe(false);
    });

    afterEach(() => {
      delete process.env.PLAID_WEBHOOK_VERIFICATION_KEY;
    });
  });

  // ── testConnection ──────────────────────────────────────────
  describe('testConnection', () => {
    it('returns status object with environment info', async () => {
      mockPlaidClient.categoriesGet.mockResolvedValue({});

      const result = await plaidService.testConnection();

      expect(result.success).toBe(true);
      expect(result.environment).toBe('sandbox');
      expect(result.usingMock).toBe(false);
      expect(result.apiConnectivity).toBe('healthy');
    });

    it('reports error when API connectivity check fails', async () => {
      mockPlaidClient.categoriesGet.mockRejectedValue(new Error('Network failure'));

      const result = await plaidService.testConnection();

      expect(result.success).toBe(false);
      expect(result.apiConnectivity).toBe('error');
      expect(result.error).toBe('Network failure');
    });
  });

  // ── formatPlaidError ────────────────────────────────────────
  describe('formatPlaidError', () => {
    it('formats Plaid error with type, code, message, displayMessage', () => {
      const error = new Error('Request failed');
      error.response = {
        status: 400,
        data: {
          error_type: 'INVALID_REQUEST',
          error_code: 'MISSING_FIELDS',
          error_message: 'Missing required field',
          display_message: 'Something went wrong'
        }
      };

      const formatted = plaidService.formatPlaidError(error);

      expect(formatted.message).toBe('Missing required field');
      expect(formatted.type).toBe('INVALID_REQUEST');
      expect(formatted.code).toBe('MISSING_FIELDS');
      expect(formatted.displayMessage).toBe('Something went wrong');
      expect(formatted.statusCode).toBe(400);
    });

    it('returns original error when no response.data exists', () => {
      const error = new Error('Network timeout');

      const formatted = plaidService.formatPlaidError(error);

      expect(formatted).toBe(error);
      expect(formatted.message).toBe('Network timeout');
    });

    it('handles error with missing display_message fields', () => {
      const error = new Error('Request failed');
      error.response = {
        status: 500,
        data: {
          error_type: 'API_ERROR',
          error_code: 'INTERNAL_SERVER_ERROR',
          error_message: 'Internal error'
        }
      };

      const formatted = plaidService.formatPlaidError(error);

      expect(formatted.message).toBe('Internal error');
      expect(formatted.displayMessage).toBeUndefined();
    });
  });

  // ── isValidDate ─────────────────────────────────────────────
  describe('isValidDate', () => {
    it('returns true for YYYY-MM-DD format', () => {
      expect(plaidService.isValidDate('2026-02-24')).toBe(true);
    });

    it('returns false for MM/DD/YYYY format', () => {
      expect(plaidService.isValidDate('02/24/2026')).toBe(false);
    });

    it('returns false for empty string', () => {
      expect(plaidService.isValidDate('')).toBe(false);
    });

    it('returns false for null', () => {
      expect(plaidService.isValidDate(null)).toBe(false);
    });

    it('returns false for undefined', () => {
      expect(plaidService.isValidDate(undefined)).toBe(false);
    });
  });

  // ── isValidUrl ──────────────────────────────────────────────
  describe('isValidUrl', () => {
    it('returns true for https URL', () => {
      expect(plaidService.isValidUrl('https://example.com/webhook')).toBe(true);
    });

    it('returns true for http URL', () => {
      expect(plaidService.isValidUrl('http://localhost:3000/webhook')).toBe(true);
    });

    it('returns false for non-URL string', () => {
      expect(plaidService.isValidUrl('not-a-url')).toBe(false);
    });

    it('returns false for empty string', () => {
      expect(plaidService.isValidUrl('')).toBe(false);
    });
  });
});

// ============================================================
// MockPlaidService — Fallback when no credentials
// ============================================================
describe('MockPlaidService fallback', () => {
  let mockPlaidServiceInstance;

  beforeAll(() => {
    jest.isolateModules(() => {
      // Clear credentials so module-scope picks mock path
      delete process.env.PLAID_CLIENT_ID;
      delete process.env.PLAID_SECRET;

      mockPlaidServiceInstance = require('../../services/plaidService');
    });
  });

  afterAll(() => {
    // Restore for other test files
    process.env.PLAID_CLIENT_ID = 'test_client_id';
    process.env.PLAID_SECRET = 'test_secret';
  });

  it('testConnection reports usingMock=true', async () => {
    const status = await mockPlaidServiceInstance.testConnection();

    expect(status.usingMock).toBe(true);
    expect(status.success).toBe(true);
    expect(status.message).toMatch(/mock/i);
  });

  it('createLinkToken returns a mock token object', async () => {
    const result = await mockPlaidServiceInstance.createLinkToken({
      userId: 'test-user'
    });

    expect(result.link_token).toMatch(/^link-sandbox-/);
    expect(result.expiration).toBeDefined();
    expect(result.request_id).toBe('mock-request-id');
  });

  it('getAccounts returns mock accounts with mortgage-relevant data', async () => {
    const result = await mockPlaidServiceInstance.getAccounts('access-mock');

    expect(result.accounts).toBeDefined();
    expect(result.accounts.length).toBeGreaterThan(0);
    expect(result.accounts[0]).toHaveProperty('accountId');
    expect(result.accounts[0]).toHaveProperty('name');
  });

  it('getTransactions returns filtered mock transactions', async () => {
    const result = await mockPlaidServiceInstance.getTransactions({
      accessToken: 'access-mock',
      startDate: '2020-01-01',
      endDate: '2030-12-31'
    });

    expect(result.transactions).toBeDefined();
    expect(Array.isArray(result.transactions)).toBe(true);
    expect(result.totalTransactions).toBe(5);
  });
});
