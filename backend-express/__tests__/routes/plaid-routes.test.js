/**
 * Plaid Route Handler Tests
 *
 * Tests all Plaid endpoints via supertest:
 *   POST /v1/plaid/link_token
 *   POST /v1/plaid/exchange_token
 *   POST /v1/plaid/accounts
 *   POST /v1/plaid/transactions
 *   POST /v1/plaid/item
 *   POST /v1/plaid/item/webhook
 *   DELETE /v1/plaid/item
 *   POST /v1/plaid/webhook
 *   POST /v1/plaid/sandbox_public_token
 *   POST /v1/plaid/test
 *
 * Uses the same mock infrastructure as cases-routes.test.js:
 * mockSupabaseClient for auth, mocked services for business logic.
 */

const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');
const mockClaudeService = require('../mocks/mockClaudeService');
const request = require('supertest');

const mockClient = createMockSupabaseClient();

// Mock @supabase/supabase-js before any module loads it
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Mock service modules to prevent real API calls
jest.mock('../../services/claudeService', () => mockClaudeService);

const mockDocumentService = {
  uploadDocument: jest.fn().mockResolvedValue({ documentId: 'doc-1', storagePath: 'mock/path' }),
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true }),
  getContentType: jest.fn().mockReturnValue('application/pdf')
};
jest.mock('../../services/documentService', () => mockDocumentService);

// Hoist mock functions for plaidService methods
const mockCreateLinkToken = jest.fn();
const mockExchangePublicToken = jest.fn();
const mockGetAccounts = jest.fn();
const mockGetTransactions = jest.fn();
const mockGetItem = jest.fn();
const mockUpdateWebhook = jest.fn();
const mockRemoveItem = jest.fn();
const mockCreateSandboxPublicToken = jest.fn();
const mockTestConnection = jest.fn();
const mockVerifyWebhookSignature = jest.fn();

jest.mock('../../services/plaidService', () => ({
  createLinkToken: mockCreateLinkToken,
  exchangePublicToken: mockExchangePublicToken,
  getAccounts: mockGetAccounts,
  getTransactions: mockGetTransactions,
  getItem: mockGetItem,
  removeItem: mockRemoveItem,
  updateWebhook: mockUpdateWebhook,
  createSandboxPublicToken: mockCreateSandboxPublicToken,
  testConnection: mockTestConnection,
  verifyWebhookSignature: mockVerifyWebhookSignature
}));

// Hoist mock functions for plaidDataService
const mockUpsertPlaidItem = jest.fn();
const mockGetItemData = jest.fn();
const mockStoreTransactions = jest.fn();
const mockUpsertAccounts = jest.fn();
const mockCreateNotification = jest.fn();
const mockRemoveTransactions = jest.fn();
const mockUpdateItemStatus = jest.fn();

jest.mock('../../services/plaidDataService', () => ({
  upsertPlaidItem: mockUpsertPlaidItem,
  getItem: mockGetItemData,
  storeTransactions: mockStoreTransactions,
  upsertAccounts: mockUpsertAccounts,
  createNotification: mockCreateNotification,
  removeTransactions: mockRemoveTransactions,
  updateItemStatus: mockUpdateItemStatus
}));

// Set env vars so modules initialize properly
process.env.SUPABASE_URL = 'https://mock.supabase.co';
process.env.SUPABASE_ANON_KEY = 'mock-anon-key';
process.env.NODE_ENV = 'production';
process.env.VERCEL = '1';

// Auth header for authenticated requests
const AUTH = 'Bearer valid-token';

let app;

beforeAll(() => {
  const serverPath = require.resolve('../../server');
  const routePaths = [
    require.resolve('../../routes/claude'),
    require.resolve('../../routes/plaid'),
    require.resolve('../../routes/documents'),
    require.resolve('../../routes/cases'),
    require.resolve('../../routes/health')
  ];
  delete require.cache[serverPath];
  for (const routePath of routePaths) {
    delete require.cache[routePath];
  }
  const authPath = require.resolve('../../middleware/auth');
  delete require.cache[authPath];

  app = require('../../server');
  process.env.NODE_ENV = 'test';
});

afterAll(() => {
  delete process.env.VERCEL;
});

beforeEach(() => {
  mockClient.reset();
  mockClaudeService.reset();
  jest.clearAllMocks();

  // Restore default mock implementations
  mockCreateLinkToken.mockResolvedValue({
    link_token: 'link-sandbox-mock123',
    expiration: '2026-12-31T00:00:00Z',
    request_id: 'req-link-001'
  });
  mockExchangePublicToken.mockResolvedValue({
    accessToken: 'access-sandbox-exchanged',
    itemId: 'item-exchange-001',
    requestId: 'req-exchange-001'
  });
  mockGetAccounts.mockResolvedValue({
    accounts: [{ accountId: 'acc-001', name: 'Checking' }],
    item: { itemId: 'item-001' },
    requestId: 'req-acc-001'
  });
  mockGetTransactions.mockResolvedValue({
    transactions: [{ transactionId: 'txn-001', amount: 1200 }],
    totalTransactions: 1,
    accounts: [{ accountId: 'acc-001' }],
    requestId: 'req-txn-001'
  });
  mockGetItem.mockResolvedValue({
    itemId: 'item-001',
    institutionId: 'ins_109508',
    requestId: 'req-item-001'
  });
  mockUpdateWebhook.mockResolvedValue({
    itemId: 'item-001',
    webhook: 'https://new.example.com/webhook',
    requestId: 'req-wh-001'
  });
  mockRemoveItem.mockResolvedValue({ removed: true, requestId: 'req-rm-001' });
  mockCreateSandboxPublicToken.mockResolvedValue('public-sandbox-mock');
  mockTestConnection.mockResolvedValue({ success: true, environment: 'sandbox', usingMock: false });
  mockVerifyWebhookSignature.mockReturnValue(true);
  mockUpsertPlaidItem.mockResolvedValue({ success: true });
  mockGetItemData.mockResolvedValue({
    success: true,
    data: { access_token: 'access-sandbox-stored', user_id: 'user-stored-001' }
  });
  mockStoreTransactions.mockResolvedValue({ success: true });
  mockUpsertAccounts.mockResolvedValue({ success: true });
  mockCreateNotification.mockResolvedValue({ success: true });
  mockRemoveTransactions.mockResolvedValue({ success: true });
  mockUpdateItemStatus.mockResolvedValue({ success: true });
});

// ============================================================
// POST /v1/plaid/link_token
// ============================================================
describe('POST /v1/plaid/link_token', () => {
  it('returns 200 with link token on success', async () => {
    const res = await request(app)
      .post('/v1/plaid/link_token')
      .set('Authorization', AUTH)
      .send({ user_id: 'user-123' });

    expect(res.status).toBe(200);
    expect(res.body.link_token).toBe('link-sandbox-mock123');
    expect(res.body.expiration).toBe('2026-12-31T00:00:00Z');
    expect(res.body.request_id).toBe('req-link-001');
  });

  it('passes userId and optional params to service', async () => {
    await request(app)
      .post('/v1/plaid/link_token')
      .set('Authorization', AUTH)
      .send({
        user_id: 'user-456',
        client_name: 'Mortgage Guardian',
        redirect_uri: 'https://app.example.com/callback',
        access_token: 'access-sandbox-update',
        products: ['transactions', 'auth']
      });

    expect(mockCreateLinkToken).toHaveBeenCalledWith({
      userId: 'user-456',
      clientName: 'Mortgage Guardian',
      redirectUri: 'https://app.example.com/callback',
      accessToken: 'access-sandbox-update',
      products: ['transactions', 'auth']
    });
  });

  it('returns 400 when user_id is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/link_token')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('returns 400 when user_id is empty string', async () => {
    const res = await request(app)
      .post('/v1/plaid/link_token')
      .set('Authorization', AUTH)
      .send({ user_id: '' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('returns 400 when redirect_uri is not a valid URI', async () => {
    const res = await request(app)
      .post('/v1/plaid/link_token')
      .set('Authorization', AUTH)
      .send({ user_id: 'user-123', redirect_uri: 'not-a-url' });

    expect(res.status).toBe(400);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/plaid/link_token')
      .send({ user_id: 'user-123' });

    expect(res.status).toBe(401);
  });

  it('forwards service error to error handler', async () => {
    const plaidError = new Error('Plaid API failure');
    plaidError.type = 'INVALID_REQUEST';
    plaidError.code = 'MISSING_FIELDS';
    plaidError.statusCode = 400;
    mockCreateLinkToken.mockRejectedValue(plaidError);

    const res = await request(app)
      .post('/v1/plaid/link_token')
      .set('Authorization', AUTH)
      .send({ user_id: 'user-123' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Plaid API Error');
    expect(res.body.type).toBe('INVALID_REQUEST');
    expect(res.body.code).toBe('MISSING_FIELDS');
  });
});

// ============================================================
// POST /v1/plaid/exchange_token
// ============================================================
describe('POST /v1/plaid/exchange_token', () => {
  it('returns 200 with access token on success', async () => {
    const res = await request(app)
      .post('/v1/plaid/exchange_token')
      .set('Authorization', AUTH)
      .send({ public_token: 'public-sandbox-token123' });

    expect(res.status).toBe(200);
    expect(res.body.access_token).toBe('access-sandbox-exchanged');
    expect(res.body.item_id).toBe('item-exchange-001');
    expect(res.body.request_id).toBe('req-exchange-001');
    expect(res.body.warning).toBeDefined();
  });

  it('stores item in database when user_id is provided', async () => {
    await request(app)
      .post('/v1/plaid/exchange_token')
      .set('Authorization', AUTH)
      .send({
        public_token: 'public-sandbox-token123',
        user_id: 'user-789',
        institution_id: 'ins_109508'
      });

    expect(mockUpsertPlaidItem).toHaveBeenCalledWith({
      itemId: 'item-exchange-001',
      userId: 'user-789',
      accessToken: 'access-sandbox-exchanged',
      status: 'active',
      institutionId: 'ins_109508'
    });
  });

  it('does not store item when user_id is missing', async () => {
    await request(app)
      .post('/v1/plaid/exchange_token')
      .set('Authorization', AUTH)
      .send({ public_token: 'public-sandbox-token123' });

    expect(mockUpsertPlaidItem).not.toHaveBeenCalled();
  });

  it('sets institutionId to null when not provided', async () => {
    await request(app)
      .post('/v1/plaid/exchange_token')
      .set('Authorization', AUTH)
      .send({
        public_token: 'public-sandbox-token123',
        user_id: 'user-789'
      });

    expect(mockUpsertPlaidItem).toHaveBeenCalledWith(
      expect.objectContaining({ institutionId: null })
    );
  });

  it('returns 400 when public_token is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/exchange_token')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('returns 400 when public_token has invalid format', async () => {
    const res = await request(app)
      .post('/v1/plaid/exchange_token')
      .set('Authorization', AUTH)
      .send({ public_token: 'invalid-format-token' });

    expect(res.status).toBe(400);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/plaid/exchange_token')
      .send({ public_token: 'public-sandbox-token123' });

    expect(res.status).toBe(401);
  });

  it('forwards service error to error handler', async () => {
    const plaidError = new Error('Exchange failed');
    plaidError.type = 'INVALID_INPUT';
    plaidError.code = 'INVALID_PUBLIC_TOKEN';
    plaidError.statusCode = 400;
    mockExchangePublicToken.mockRejectedValue(plaidError);

    const res = await request(app)
      .post('/v1/plaid/exchange_token')
      .set('Authorization', AUTH)
      .send({ public_token: 'public-sandbox-expired' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Plaid API Error');
  });
});

// ============================================================
// POST /v1/plaid/accounts
// ============================================================
describe('POST /v1/plaid/accounts', () => {
  it('returns 200 with accounts on success', async () => {
    const res = await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(200);
    expect(res.body.accounts).toHaveLength(1);
    expect(res.body.accounts[0].accountId).toBe('acc-001');
    expect(res.body.requestId).toBe('req-acc-001');
  });

  it('passes access_token and account_ids to service', async () => {
    await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        account_ids: ['acc-001', 'acc-002']
      });

    expect(mockGetAccounts).toHaveBeenCalledWith(
      'access-sandbox-token123',
      ['acc-001', 'acc-002']
    );
  });

  it('passes undefined account_ids when not provided', async () => {
    await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(mockGetAccounts).toHaveBeenCalledWith('access-sandbox-token123', undefined);
  });

  it('returns 400 when access_token is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('returns 400 when access_token has invalid format', async () => {
    const res = await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({ access_token: 'bad-token' });

    expect(res.status).toBe(400);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/plaid/accounts')
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(401);
  });

  it('forwards Plaid error to error handler', async () => {
    const plaidError = new Error('Accounts fetch failed');
    plaidError.type = 'INVALID_INPUT';
    plaidError.code = 'INVALID_ACCESS_TOKEN';
    plaidError.statusCode = 400;
    mockGetAccounts.mockRejectedValue(plaidError);

    const res = await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-bad' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Plaid API Error');
  });

  it('returns 500 on generic service error', async () => {
    mockGetAccounts.mockRejectedValue(new Error('Network timeout'));

    const res = await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(500);
  });
});

// ============================================================
// POST /v1/plaid/transactions
// ============================================================
describe('POST /v1/plaid/transactions', () => {
  it('returns 200 with transactions on success', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        start_date: '2026-01-01',
        end_date: '2026-03-31'
      });

    expect(res.status).toBe(200);
    expect(res.body.transactions).toHaveLength(1);
    expect(res.body.totalTransactions).toBe(1);
    expect(res.body.requestId).toBe('req-txn-001');
  });

  it('passes all parameters to service including defaults', async () => {
    await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        start_date: '2026-01-01',
        end_date: '2026-03-31'
      });

    expect(mockGetTransactions).toHaveBeenCalledWith({
      accessToken: 'access-sandbox-token123',
      startDate: '2026-01-01',
      endDate: '2026-03-31',
      accountIds: undefined,
      count: 100,
      offset: 0
    });
  });

  it('passes custom count, offset, and account_ids', async () => {
    await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        start_date: '2026-01-01',
        end_date: '2026-03-31',
        account_ids: ['acc-001'],
        count: 50,
        offset: 10
      });

    expect(mockGetTransactions).toHaveBeenCalledWith({
      accessToken: 'access-sandbox-token123',
      startDate: '2026-01-01',
      endDate: '2026-03-31',
      accountIds: ['acc-001'],
      count: 50,
      offset: 10
    });
  });

  it('returns 400 when access_token is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({ start_date: '2026-01-01', end_date: '2026-03-31' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when start_date is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-tok', end_date: '2026-03-31' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when end_date is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-tok', start_date: '2026-01-01' });

    expect(res.status).toBe(400);
  });

  it('returns 400 for invalid date format', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-tok',
        start_date: '01/01/2026',
        end_date: '2026-03-31'
      });

    expect(res.status).toBe(400);
  });

  it('returns 400 when access_token has invalid format', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({
        access_token: 'bad-token',
        start_date: '2026-01-01',
        end_date: '2026-03-31'
      });

    expect(res.status).toBe(400);
  });

  it('returns 400 when count exceeds 500', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-tok',
        start_date: '2026-01-01',
        end_date: '2026-03-31',
        count: 501
      });

    expect(res.status).toBe(400);
  });

  it('returns 400 when count is less than 1', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-tok',
        start_date: '2026-01-01',
        end_date: '2026-03-31',
        count: 0
      });

    expect(res.status).toBe(400);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/plaid/transactions')
      .send({
        access_token: 'access-sandbox-tok',
        start_date: '2026-01-01',
        end_date: '2026-03-31'
      });

    expect(res.status).toBe(401);
  });

  it('forwards service error to error handler', async () => {
    const plaidError = new Error('Transactions failed');
    plaidError.type = 'API_ERROR';
    plaidError.code = 'INTERNAL_SERVER_ERROR';
    plaidError.statusCode = 500;
    mockGetTransactions.mockRejectedValue(plaidError);

    const res = await request(app)
      .post('/v1/plaid/transactions')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        start_date: '2026-01-01',
        end_date: '2026-03-31'
      });

    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Plaid API Error');
  });
});

// ============================================================
// POST /v1/plaid/item
// ============================================================
describe('POST /v1/plaid/item', () => {
  it('returns 200 with item info on success', async () => {
    const res = await request(app)
      .post('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(200);
    expect(res.body.itemId).toBe('item-001');
    expect(res.body.institutionId).toBe('ins_109508');
  });

  it('passes access_token to service', async () => {
    await request(app)
      .post('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(mockGetItem).toHaveBeenCalledWith('access-sandbox-token123');
  });

  it('returns 400 when access_token is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(400);
  });

  it('returns 400 when access_token has invalid format', async () => {
    const res = await request(app)
      .post('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({ access_token: 'invalid' });

    expect(res.status).toBe(400);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/plaid/item')
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(401);
  });

  it('forwards service error to error handler', async () => {
    mockGetItem.mockRejectedValue(new Error('Item not found'));

    const res = await request(app)
      .post('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(500);
  });
});

// ============================================================
// POST /v1/plaid/item/webhook
// ============================================================
describe('POST /v1/plaid/item/webhook', () => {
  it('returns 200 with updated webhook on success', async () => {
    const res = await request(app)
      .post('/v1/plaid/item/webhook')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        webhook: 'https://new.example.com/webhook'
      });

    expect(res.status).toBe(200);
    expect(res.body.itemId).toBe('item-001');
    expect(res.body.webhook).toBe('https://new.example.com/webhook');
  });

  it('passes access_token and webhook to service', async () => {
    await request(app)
      .post('/v1/plaid/item/webhook')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        webhook: 'https://hooks.example.com/plaid'
      });

    expect(mockUpdateWebhook).toHaveBeenCalledWith(
      'access-sandbox-token123',
      'https://hooks.example.com/plaid'
    );
  });

  it('returns 400 when access_token is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/item/webhook')
      .set('Authorization', AUTH)
      .send({ webhook: 'https://example.com/webhook' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when webhook is missing', async () => {
    const res = await request(app)
      .post('/v1/plaid/item/webhook')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(400);
  });

  it('returns 400 when webhook is not a valid URI', async () => {
    const res = await request(app)
      .post('/v1/plaid/item/webhook')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        webhook: 'not-a-url'
      });

    expect(res.status).toBe(400);
  });

  it('returns 400 when access_token has invalid format', async () => {
    const res = await request(app)
      .post('/v1/plaid/item/webhook')
      .set('Authorization', AUTH)
      .send({
        access_token: 'bad',
        webhook: 'https://example.com/webhook'
      });

    expect(res.status).toBe(400);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/plaid/item/webhook')
      .send({
        access_token: 'access-sandbox-token123',
        webhook: 'https://example.com/webhook'
      });

    expect(res.status).toBe(401);
  });

  it('forwards service error to error handler', async () => {
    mockUpdateWebhook.mockRejectedValue(new Error('Webhook update failed'));

    const res = await request(app)
      .post('/v1/plaid/item/webhook')
      .set('Authorization', AUTH)
      .send({
        access_token: 'access-sandbox-token123',
        webhook: 'https://example.com/webhook'
      });

    expect(res.status).toBe(500);
  });
});

// ============================================================
// DELETE /v1/plaid/item
// ============================================================
describe('DELETE /v1/plaid/item', () => {
  it('returns 200 with removal confirmation on success', async () => {
    const res = await request(app)
      .delete('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(200);
    expect(res.body.removed).toBe(true);
    expect(res.body.requestId).toBe('req-rm-001');
  });

  it('passes access_token to service', async () => {
    await request(app)
      .delete('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(mockRemoveItem).toHaveBeenCalledWith('access-sandbox-token123');
  });

  it('returns 400 when access_token is missing', async () => {
    const res = await request(app)
      .delete('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(400);
  });

  it('returns 400 when access_token has invalid format', async () => {
    const res = await request(app)
      .delete('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({ access_token: 'invalid' });

    expect(res.status).toBe(400);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .delete('/v1/plaid/item')
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(401);
  });

  it('forwards Plaid error to error handler', async () => {
    const plaidError = new Error('Item removal failed');
    plaidError.type = 'INVALID_INPUT';
    plaidError.code = 'INVALID_ACCESS_TOKEN';
    plaidError.statusCode = 400;
    mockRemoveItem.mockRejectedValue(plaidError);

    const res = await request(app)
      .delete('/v1/plaid/item')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Plaid API Error');
  });
});

// ============================================================
// POST /v1/plaid/webhook (incoming Plaid webhooks - PUBLIC)
// ============================================================
describe('POST /v1/plaid/webhook', () => {
  /**
   * The webhook route uses express.raw({ type: 'application/json' }) for signature
   * verification with the raw body. The global express.json() middleware in server.js
   * would normally pre-parse the body, making express.raw() a no-op. To properly test
   * webhook handlers, we create a minimal Express app that mounts only the plaid routes
   * WITHOUT the global json parser, mimicking how Plaid would send webhooks.
   */
  let webhookApp;

  beforeAll(() => {
    const express = require('express');
    webhookApp = express();
    // NO express.json() here — let express.raw() in the route handle it
    const plaidRoutes = require('../../routes/plaid');
    webhookApp.use('/v1/plaid', plaidRoutes);
  });

  const sendWebhook = (body) => {
    const raw = JSON.stringify(body);
    return request(webhookApp)
      .post('/v1/plaid/webhook')
      .set('Content-Type', 'application/json')
      .send(raw);
  };

  // --- Signature validation ---
  it('returns 401 when webhook signature is invalid', async () => {
    mockVerifyWebhookSignature.mockReturnValue(false);

    const res = await sendWebhook({
      webhook_type: 'TRANSACTIONS',
      webhook_code: 'DEFAULT_UPDATE',
      item_id: 'item-001'
    });

    expect(res.status).toBe(401);
    expect(res.body.error).toBe('Unauthorized');
  });

  // --- TRANSACTIONS webhooks ---
  describe('TRANSACTIONS webhook type', () => {
    it('handles DEFAULT_UPDATE - fetches and stores transactions', async () => {
      mockGetTransactions.mockResolvedValue({
        transactions: [{ transactionId: 'txn-new' }],
        accounts: [{ accountId: 'acc-001' }]
      });

      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'DEFAULT_UPDATE',
        item_id: 'item-wh-001',
        new_transactions: 5
      });

      expect(res.status).toBe(200);
      expect(res.body.acknowledged).toBe(true);
      expect(res.body.handled).toBe(true);
      expect(mockGetItemData).toHaveBeenCalledWith('item-wh-001');
      expect(mockStoreTransactions).toHaveBeenCalled();
      expect(mockUpsertAccounts).toHaveBeenCalled();
      expect(mockCreateNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'transactions_updated',
          priority: 'low'
        })
      );
    });

    it('handles INITIAL_UPDATE same as DEFAULT_UPDATE', async () => {
      mockGetTransactions.mockResolvedValue({
        transactions: [{ transactionId: 'txn-init' }],
        accounts: []
      });

      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'INITIAL_UPDATE',
        item_id: 'item-wh-001',
        new_transactions: 10
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
    });

    it('handles HISTORICAL_UPDATE same as DEFAULT_UPDATE', async () => {
      mockGetTransactions.mockResolvedValue({
        transactions: [],
        accounts: []
      });

      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'HISTORICAL_UPDATE',
        item_id: 'item-wh-001',
        new_transactions: 100
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
    });

    it('returns handled=false when item not found in DB', async () => {
      mockGetItemData.mockResolvedValue({ success: false, error: 'Not found' });

      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'DEFAULT_UPDATE',
        item_id: 'item-unknown',
        new_transactions: 1
      });

      expect(res.status).toBe(200);
      expect(res.body.acknowledged).toBe(true);
      expect(res.body.handled).toBe(false);
    });

    it('returns handled=false when transaction fetch returns null', async () => {
      mockGetTransactions.mockResolvedValue(null);

      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'DEFAULT_UPDATE',
        item_id: 'item-wh-001',
        new_transactions: 1
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('returns handled=false when transactions response lacks transactions field', async () => {
      mockGetTransactions.mockResolvedValue({ accounts: [] });

      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'DEFAULT_UPDATE',
        item_id: 'item-wh-001',
        new_transactions: 1
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('returns handled=false when store transactions fails', async () => {
      mockGetTransactions.mockResolvedValue({
        transactions: [{ transactionId: 'txn-1' }],
        accounts: []
      });
      mockStoreTransactions.mockResolvedValue({ success: false, error: 'DB error' });

      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'DEFAULT_UPDATE',
        item_id: 'item-wh-001',
        new_transactions: 1
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('does not upsert accounts when empty array returned', async () => {
      mockGetTransactions.mockResolvedValue({
        transactions: [{ transactionId: 'txn-1' }],
        accounts: []
      });

      await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'DEFAULT_UPDATE',
        item_id: 'item-wh-001',
        new_transactions: 1
      });

      expect(mockUpsertAccounts).not.toHaveBeenCalled();
    });

    it('handles TRANSACTIONS_REMOVED', async () => {
      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'TRANSACTIONS_REMOVED',
        item_id: 'item-wh-001',
        removed_transactions: ['txn-001', 'txn-002']
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
      expect(mockRemoveTransactions).toHaveBeenCalledWith({
        transactionIds: ['txn-001', 'txn-002']
      });
    });

    it('returns handled=false when remove transactions fails', async () => {
      mockRemoveTransactions.mockResolvedValue({ success: false, error: 'DB error' });

      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'TRANSACTIONS_REMOVED',
        item_id: 'item-wh-001',
        removed_transactions: ['txn-001']
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('handles unrecognized transaction webhook code', async () => {
      const res = await sendWebhook({
        webhook_type: 'TRANSACTIONS',
        webhook_code: 'UNKNOWN_CODE',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });
  });

  // --- ITEM webhooks ---
  describe('ITEM webhook type', () => {
    it('handles ERROR with ITEM_LOGIN_REQUIRED', async () => {
      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'ERROR',
        item_id: 'item-wh-001',
        error: { error_code: 'ITEM_LOGIN_REQUIRED', error_message: 'Login required' }
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
      expect(mockUpdateItemStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          itemId: 'item-wh-001',
          status: 'login_required',
          requiresAction: true
        })
      );
      expect(mockCreateNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'authentication_required',
          priority: 'high'
        })
      );
    });

    it('handles ERROR with generic error code', async () => {
      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'ERROR',
        item_id: 'item-wh-001',
        error: { error_code: 'INSTITUTION_DOWN', error_message: 'Bank is unavailable' }
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
      expect(mockUpdateItemStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'error',
          requiresAction: true
        })
      );
      expect(mockCreateNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'item_error',
          priority: 'medium'
        })
      );
    });

    it('handles ERROR - returns false when item not found', async () => {
      mockGetItemData.mockResolvedValue({ success: false, error: 'Not found' });

      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'ERROR',
        item_id: 'item-unknown',
        error: { error_code: 'ITEM_LOGIN_REQUIRED' }
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('handles ERROR - catches handler exceptions', async () => {
      mockGetItemData.mockResolvedValue({
        success: true,
        data: { access_token: 'at', user_id: 'uid' }
      });
      mockUpdateItemStatus.mockRejectedValue(new Error('DB write error'));

      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'ERROR',
        item_id: 'item-wh-001',
        error: { error_code: 'ITEM_LOGIN_REQUIRED' }
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('handles PENDING_EXPIRATION', async () => {
      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'PENDING_EXPIRATION',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
      expect(mockUpdateItemStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          itemId: 'item-wh-001',
          status: 'expiring_soon',
          requiresAction: true
        })
      );
      expect(mockCreateNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'consent_expiring',
          priority: 'high'
        })
      );
    });

    it('handles PENDING_EXPIRATION - returns false when item not found', async () => {
      mockGetItemData.mockResolvedValue({ success: false, error: 'Not found' });

      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'PENDING_EXPIRATION',
        item_id: 'item-unknown'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('handles PENDING_EXPIRATION - catches handler exceptions', async () => {
      mockGetItemData.mockResolvedValue({
        success: true,
        data: { access_token: 'at', user_id: 'uid' }
      });
      mockUpdateItemStatus.mockRejectedValue(new Error('DB error'));

      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'PENDING_EXPIRATION',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('handles USER_PERMISSION_REVOKED', async () => {
      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'USER_PERMISSION_REVOKED',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
      expect(mockUpdateItemStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          itemId: 'item-wh-001',
          status: 'permission_revoked',
          requiresAction: false
        })
      );
      expect(mockCreateNotification).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'permission_revoked',
          priority: 'medium'
        })
      );
    });

    it('handles USER_PERMISSION_REVOKED - returns false when item not found', async () => {
      mockGetItemData.mockResolvedValue({ success: false, error: 'Not found' });

      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'USER_PERMISSION_REVOKED',
        item_id: 'item-unknown'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('handles USER_PERMISSION_REVOKED - catches handler exceptions', async () => {
      mockGetItemData.mockResolvedValue({
        success: true,
        data: { access_token: 'at', user_id: 'uid' }
      });
      mockUpdateItemStatus.mockRejectedValue(new Error('DB error'));

      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'USER_PERMISSION_REVOKED',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('handles WEBHOOK_UPDATE_ACKNOWLEDGED', async () => {
      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'WEBHOOK_UPDATE_ACKNOWLEDGED',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
      expect(mockUpdateItemStatus).toHaveBeenCalledWith(
        expect.objectContaining({
          itemId: 'item-wh-001',
          status: 'active',
          requiresAction: false
        })
      );
    });

    it('handles WEBHOOK_UPDATE_ACKNOWLEDGED - returns false on error', async () => {
      mockUpdateItemStatus.mockRejectedValue(new Error('DB error'));

      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'WEBHOOK_UPDATE_ACKNOWLEDGED',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });

    it('handles unrecognized item webhook code', async () => {
      const res = await sendWebhook({
        webhook_type: 'ITEM',
        webhook_code: 'FUTURE_CODE',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });
  });

  // --- AUTH webhooks ---
  describe('AUTH webhook type', () => {
    it('handles AUTOMATICALLY_VERIFIED', async () => {
      const res = await sendWebhook({
        webhook_type: 'AUTH',
        webhook_code: 'AUTOMATICALLY_VERIFIED',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
    });

    it('handles VERIFICATION_EXPIRED', async () => {
      const res = await sendWebhook({
        webhook_type: 'AUTH',
        webhook_code: 'VERIFICATION_EXPIRED',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(true);
    });

    it('handles unrecognized auth webhook code', async () => {
      const res = await sendWebhook({
        webhook_type: 'AUTH',
        webhook_code: 'UNKNOWN_AUTH_CODE',
        item_id: 'item-wh-001'
      });

      expect(res.status).toBe(200);
      expect(res.body.handled).toBe(false);
    });
  });

  // --- Unknown webhook types ---
  it('handles unknown webhook_type gracefully', async () => {
    const res = await sendWebhook({
      webhook_type: 'INVESTMENTS',
      webhook_code: 'DEFAULT_UPDATE',
      item_id: 'item-wh-001'
    });

    expect(res.status).toBe(200);
    expect(res.body.acknowledged).toBe(true);
    expect(res.body.handled).toBe(false);
  });

  // --- Handler throws exception ---
  it('returns 200 with error when webhook handler throws', async () => {
    mockGetItemData.mockRejectedValue(new Error('Unexpected DB failure'));

    const res = await sendWebhook({
      webhook_type: 'TRANSACTIONS',
      webhook_code: 'DEFAULT_UPDATE',
      item_id: 'item-wh-001',
      new_transactions: 1
    });

    expect(res.status).toBe(200);
    expect(res.body.acknowledged).toBe(true);
    expect(res.body.handled).toBe(false);
  });

  // --- Does not require auth (public path) ---
  it('does not require Authorization header', async () => {
    const res = await sendWebhook({
      webhook_type: 'AUTH',
      webhook_code: 'AUTOMATICALLY_VERIFIED',
      item_id: 'item-001'
    });

    // Should NOT get 401 since webhook is a public path
    expect(res.status).toBe(200);
  });
});

// ============================================================
// POST /v1/plaid/sandbox_public_token
// ============================================================
describe('POST /v1/plaid/sandbox_public_token', () => {
  it('returns 200 with public token on success', async () => {
    const res = await request(app)
      .post('/v1/plaid/sandbox_public_token')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.public_token).toBe('public-sandbox-mock');
  });

  it('passes institution_id and initial_products to service', async () => {
    await request(app)
      .post('/v1/plaid/sandbox_public_token')
      .set('Authorization', AUTH)
      .send({
        institution_id: 'ins_109508',
        initial_products: ['transactions', 'auth']
      });

    expect(mockCreateSandboxPublicToken).toHaveBeenCalledWith({
      institutionId: 'ins_109508',
      initialProducts: ['transactions', 'auth']
    });
  });

  it('returns 403 in production environment', async () => {
    const origEnv = process.env.PLAID_ENV;
    process.env.PLAID_ENV = 'production';

    const res = await request(app)
      .post('/v1/plaid/sandbox_public_token')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(403);
    expect(res.body.error).toBe('Forbidden');

    process.env.PLAID_ENV = origEnv;
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/plaid/sandbox_public_token')
      .send({});

    expect(res.status).toBe(401);
  });

  it('forwards service error to error handler', async () => {
    mockCreateSandboxPublicToken.mockRejectedValue(new Error('Sandbox creation failed'));

    const res = await request(app)
      .post('/v1/plaid/sandbox_public_token')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(500);
  });
});

// ============================================================
// POST /v1/plaid/test
// ============================================================
describe('POST /v1/plaid/test', () => {
  it('returns 200 with connection status on success', async () => {
    const res = await request(app)
      .post('/v1/plaid/test')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.environment).toBe('sandbox');
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/plaid/test')
      .send({});

    expect(res.status).toBe(401);
  });

  it('forwards service error to error handler', async () => {
    mockTestConnection.mockRejectedValue(new Error('Connection test failed'));

    const res = await request(app)
      .post('/v1/plaid/test')
      .set('Authorization', AUTH)
      .send({});

    expect(res.status).toBe(500);
  });
});

// ============================================================
// Error handler coverage
// ============================================================
describe('Plaid error handler', () => {
  it('returns Plaid-specific error with type and code', async () => {
    const plaidError = new Error('Access token invalid');
    plaidError.type = 'INVALID_INPUT';
    plaidError.code = 'INVALID_ACCESS_TOKEN';
    plaidError.statusCode = 400;
    plaidError.displayMessage = 'Please reconnect your bank account';
    mockGetAccounts.mockRejectedValue(plaidError);

    const res = await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Plaid API Error');
    expect(res.body.type).toBe('INVALID_INPUT');
    expect(res.body.code).toBe('INVALID_ACCESS_TOKEN');
    expect(res.body.displayMessage).toBe('Please reconnect your bank account');
  });

  it('returns generic error for non-Plaid errors', async () => {
    mockGetAccounts.mockRejectedValue(new Error('Something went wrong'));

    const res = await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Error');
  });

  it('hides error details in production mode', async () => {
    const origEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    mockGetAccounts.mockRejectedValue(new Error('Sensitive internal detail'));

    const res = await request(app)
      .post('/v1/plaid/accounts')
      .set('Authorization', AUTH)
      .send({ access_token: 'access-sandbox-token123' });

    expect(res.status).toBe(500);
    expect(res.body.message).toBe('Internal server error');
    expect(res.body.stack).toBeUndefined();

    process.env.NODE_ENV = origEnv;
  });
});

// ============================================================
// Sanitization middleware
// ============================================================
describe('Sanitization middleware', () => {
  it('strips script tags from request body strings', async () => {
    await request(app)
      .post('/v1/plaid/link_token')
      .set('Authorization', AUTH)
      .send({ user_id: 'user-<script>alert(1)</script>safe' });

    expect(mockCreateLinkToken).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-safe'
      })
    );
  });
});
