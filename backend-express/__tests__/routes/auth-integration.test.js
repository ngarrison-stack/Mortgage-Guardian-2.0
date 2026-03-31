/**
 * Route-Level Authentication Integration Tests
 *
 * Uses supertest to verify the full Express middleware chain for auth protection.
 * Tests that:
 *   - All /v1/ routes return 401 without a valid token
 *   - Authenticated requests pass through the auth middleware (non-401 response)
 *   - Public routes (health, root) remain accessible without auth
 *
 * Mock strategy:
 *   - @clerk/backend is mocked to control verifyToken() responses
 *   - Service modules are mocked to prevent real API calls (Claude, Plaid, documents)
 *   - setupTestApp() clears module cache and requires a fresh app instance
 */

const mockClaudeService = require('../mocks/mockClaudeService');
const request = require('supertest');

// Mock @clerk/backend before any module loads it
const mockVerifyToken = jest.fn();
jest.mock('@clerk/backend', () => ({
  verifyToken: mockVerifyToken
}));

// Mock service modules to prevent real API calls
jest.mock('../../services/claudeService', () => mockClaudeService);

jest.mock('../../services/plaidService', () => ({
  createLinkToken: jest.fn().mockResolvedValue({ link_token: 'mock-link-token', expiration: '2025-01-01T00:00:00Z', request_id: 'mock-req-id' }),
  exchangePublicToken: jest.fn().mockResolvedValue({ accessToken: 'mock-access-token', itemId: 'mock-item-id', requestId: 'mock-req-id' }),
  getAccounts: jest.fn().mockResolvedValue({ accounts: [], item: {}, request_id: 'mock-req-id' }),
  getTransactions: jest.fn().mockResolvedValue({ transactions: [], total_transactions: 0, accounts: [], request_id: 'mock-req-id' }),
  getItem: jest.fn().mockResolvedValue({ itemId: 'mock-item-id', institutionId: 'mock-inst-id' }),
  removeItem: jest.fn().mockResolvedValue({ removed: true, request_id: 'mock-req-id' }),
  updateWebhook: jest.fn().mockResolvedValue({ itemId: 'mock-item-id', webhook: 'https://mock.webhook.url' }),
  createSandboxPublicToken: jest.fn().mockResolvedValue('public-sandbox-mock'),
  testConnection: jest.fn().mockResolvedValue({ success: true }),
  verifyWebhookSignature: jest.fn().mockReturnValue(true)
}));

jest.mock('../../services/plaidDataService', () => ({
  upsertPlaidItem: jest.fn().mockResolvedValue({ success: true }),
  getItem: jest.fn().mockResolvedValue({ success: true, data: { access_token: 'mock', user_id: 'mock' } }),
  storeTransactions: jest.fn().mockResolvedValue({ success: true }),
  upsertAccounts: jest.fn().mockResolvedValue({ success: true }),
  createNotification: jest.fn().mockResolvedValue({ success: true }),
  removeTransactions: jest.fn().mockResolvedValue({ success: true }),
  updateItemStatus: jest.fn().mockResolvedValue({ success: true })
}));

jest.mock('../../services/documentService', () => ({
  uploadDocument: jest.fn().mockResolvedValue({ documentId: 'mock-doc-id', storagePath: 'mock/path' }),
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true })
}));

// Set env vars so modules initialize properly
process.env.CLERK_SECRET_KEY = 'test-clerk-secret';

// Prevent server.js from calling app.listen() during tests.
process.env.NODE_ENV = 'production';
process.env.VERCEL = '1';

let app;

beforeAll(() => {
  // Clear cached server and route modules so our jest.mock() calls take effect
  const serverPath = require.resolve('../../server');
  const routePaths = [
    require.resolve('../../routes/claude'),
    require.resolve('../../routes/plaid'),
    require.resolve('../../routes/documents'),
    require.resolve('../../routes/health')
  ];
  delete require.cache[serverPath];
  for (const routePath of routePaths) {
    delete require.cache[routePath];
  }

  // Also clear the middleware module cache so it picks up the mock
  const authPath = require.resolve('../../middleware/auth');
  delete require.cache[authPath];

  app = require('../../server');

  // Restore NODE_ENV to test for proper behavior in tests
  process.env.NODE_ENV = 'test';
});

afterAll(() => {
  delete process.env.VERCEL;
});

beforeEach(() => {
  mockVerifyToken.mockReset();
  mockClaudeService.reset();
  // Default: valid token returns user
  mockVerifyToken.mockResolvedValue({ sub: 'mock-user-id-12345' });
});

describe('Route-level authentication', () => {
  // ==================================================
  // Protected routes reject unauthenticated requests
  // ==================================================
  describe('protected routes reject unauthenticated requests', () => {
    // For unauthenticated tests, verifyToken should not be called (no Bearer token)
    test('POST /v1/ai/claude/analyze -> 401 without auth', async () => {
      const response = await request(app)
        .post('/v1/ai/claude/analyze')
        .send({ prompt: 'test' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

    test('POST /v1/ai/claude/test -> 401 without auth', async () => {
      const response = await request(app)
        .post('/v1/ai/claude/test');

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

    test('POST /v1/plaid/link_token -> 401 without auth', async () => {
      const response = await request(app)
        .post('/v1/plaid/link_token')
        .send({ user_id: 'test-user' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

    test('POST /v1/plaid/accounts -> 401 without auth', async () => {
      const response = await request(app)
        .post('/v1/plaid/accounts')
        .send({ access_token: 'access-test-123' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

    test('POST /v1/plaid/transactions -> 401 without auth', async () => {
      const response = await request(app)
        .post('/v1/plaid/transactions')
        .send({ access_token: 'access-test-123', start_date: '2024-01-01', end_date: '2024-12-31' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

    test('POST /v1/documents/upload -> 401 without auth', async () => {
      const response = await request(app)
        .post('/v1/documents/upload')
        .send({ documentId: 'doc-1', userId: 'user-1', fileName: 'test.pdf', content: 'data' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

    test('GET /v1/documents -> 401 without auth', async () => {
      const response = await request(app)
        .get('/v1/documents')
        .query({ userId: 'test-user' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

    test('GET /v1/documents/test-id -> 401 without auth', async () => {
      const response = await request(app)
        .get('/v1/documents/test-id')
        .query({ userId: 'test-user' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

    test('DELETE /v1/documents/test-id -> 401 without auth', async () => {
      const response = await request(app)
        .delete('/v1/documents/test-id')
        .query({ userId: 'test-user' });

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });
  });

  // ==================================================
  // Protected routes accept authenticated requests
  // ==================================================
  describe('protected routes accept authenticated requests', () => {
    test('POST /v1/ai/claude/analyze -> passes auth with valid token (may fail validation, but not 401)', async () => {
      mockVerifyToken.mockResolvedValue({ sub: 'user-123' });

      const response = await request(app)
        .post('/v1/ai/claude/analyze')
        .set('Authorization', 'Bearer valid-test-token')
        .send({ prompt: 'Analyze this mortgage statement' });

      // The key assertion: NOT a 401. It should pass auth and reach the handler.
      expect(response.status).not.toBe(401);
    });
  });

  // ==================================================
  // Public routes remain accessible
  // ==================================================
  describe('public routes remain accessible', () => {
    test('GET /health -> 200 without auth', async () => {
      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
    });

    test('GET / -> 200 without auth', async () => {
      const response = await request(app).get('/');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('name', 'Mortgage Guardian API');
    });
  });
});
