/**
 * Claude Route Handler Tests
 *
 * Tests all Claude AI endpoints via supertest:
 *   POST /v1/ai/claude/analyze — success, validation, error branches
 *   POST /v1/ai/claude/test   — success and error branches
 *
 * Uses the same mock infrastructure as documents-routes.test.js:
 * mockSupabaseClient for auth, mockClaudeService for AI responses.
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

jest.mock('../../services/plaidService', () => ({
  createLinkToken: jest.fn().mockResolvedValue({ link_token: 'mock', expiration: '2025-01-01T00:00:00Z', request_id: 'req' }),
  exchangePublicToken: jest.fn().mockResolvedValue({ accessToken: 'tok', itemId: 'item', requestId: 'req' }),
  getAccounts: jest.fn().mockResolvedValue({ accounts: [], item: {}, request_id: 'req' }),
  getTransactions: jest.fn().mockResolvedValue({ transactions: [], total_transactions: 0, accounts: [], request_id: 'req' }),
  getItem: jest.fn().mockResolvedValue({ itemId: 'item', institutionId: 'inst' }),
  removeItem: jest.fn().mockResolvedValue({ removed: true, request_id: 'req' }),
  updateWebhook: jest.fn().mockResolvedValue({ itemId: 'item', webhook: 'https://mock' }),
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

// Set env vars so modules initialize properly
process.env.SUPABASE_URL = 'https://mock.supabase.co';
process.env.SUPABASE_ANON_KEY = 'mock-anon-key';
process.env.NODE_ENV = 'production';
process.env.VERCEL = '1';

let app;

beforeAll(() => {
  // Clear cached modules so mocks take effect
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
});

// ============================================================
// POST /v1/ai/claude/analyze
// ============================================================
describe('POST /v1/ai/claude/analyze', () => {
  it('returns 200 with analysis when prompt is provided', async () => {
    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .set('Authorization', 'Bearer valid-token')
      .send({ prompt: 'Analyze this mortgage statement' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.analysis).toBeDefined();
    expect(res.body.model).toBeDefined();
    expect(res.body.usage).toBeDefined();
    expect(res.body.timestamp).toBeDefined();
  });

  it('builds analysis prompt from documentText when no prompt provided', async () => {
    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .set('Authorization', 'Bearer valid-token')
      .send({
        documentText: 'Monthly mortgage statement for account 12345...',
        documentType: 'mortgage_statement'
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    // Verify buildMortgageAnalysisPrompt was called
    expect(mockClaudeService.getCallCount('buildMortgageAnalysisPrompt')).toBe(1);
  });

  it('uses provided prompt even when documentText is also present', async () => {
    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .set('Authorization', 'Bearer valid-token')
      .send({
        prompt: 'Custom prompt',
        documentText: 'Some document text'
      });

    expect(res.status).toBe(200);
    // buildMortgageAnalysisPrompt should NOT be called when prompt is provided
    expect(mockClaudeService.getCallCount('buildMortgageAnalysisPrompt')).toBe(0);
  });

  it('returns 400 when neither prompt nor documentText is provided', async () => {
    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .set('Authorization', 'Bearer valid-token')
      .send({ model: 'claude-3-5-sonnet-20241022' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('returns 401 when Claude API key is invalid', async () => {
    const error = new Error('Invalid API key');
    error.status = 401;
    mockClaudeService.setError(error);

    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .set('Authorization', 'Bearer valid-token')
      .send({ prompt: 'Analyze this' });

    expect(res.status).toBe(401);
    expect(res.body.error).toBe('Authentication Error');
    expect(res.body.message).toContain('ANTHROPIC_API_KEY');
  });

  it('returns 429 when Claude API rate limit is exceeded', async () => {
    const error = new Error('Rate limit exceeded');
    error.status = 429;
    mockClaudeService.setError(error);

    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .set('Authorization', 'Bearer valid-token')
      .send({ prompt: 'Analyze this' });

    expect(res.status).toBe(429);
    expect(res.body.error).toBe('Rate Limit Exceeded');
    expect(res.body.message).toContain('try again later');
  });

  it('passes generic errors to next() error handler (500)', async () => {
    const error = new Error('Unexpected server error');
    // No .status property — should fall through to next(error)
    mockClaudeService.setError(error);

    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .set('Authorization', 'Bearer valid-token')
      .send({ prompt: 'Analyze this' });

    expect(res.status).toBe(500);
  });

  it('passes optional model, maxTokens, temperature to service', async () => {
    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .set('Authorization', 'Bearer valid-token')
      .send({
        prompt: 'Analyze',
        model: 'claude-3-5-sonnet-20241022',
        maxTokens: 2000,
        temperature: 0.5
      });

    expect(res.status).toBe(200);
    const history = mockClaudeService.getCallHistory();
    const analyzeCall = history.find(c => c.method === 'analyzeDocument');
    expect(analyzeCall.args.model).toBe('claude-3-5-sonnet-20241022');
    expect(analyzeCall.args.maxTokens).toBe(2000);
    expect(analyzeCall.args.temperature).toBe(0.5);
  });

  it('returns 401 when no auth token is provided', async () => {
    const res = await request(app)
      .post('/v1/ai/claude/analyze')
      .send({ prompt: 'Analyze this' });

    expect(res.status).toBe(401);
  });
});

// ============================================================
// POST /v1/ai/claude/test
// ============================================================
describe('POST /v1/ai/claude/test', () => {
  it('returns 200 with success message when API works', async () => {
    const res = await request(app)
      .post('/v1/ai/claude/test')
      .set('Authorization', 'Bearer valid-token')
      .send();

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toBe('Claude API is working!');
    expect(res.body.response).toBeDefined();
    expect(res.body.timestamp).toBeDefined();
  });

  it('passes error to next() when Claude API fails (500)', async () => {
    const error = new Error('Service unavailable');
    mockClaudeService.setError(error);

    const res = await request(app)
      .post('/v1/ai/claude/test')
      .set('Authorization', 'Bearer valid-token')
      .send();

    expect(res.status).toBe(500);
  });

  it('returns 401 when no auth token is provided', async () => {
    const res = await request(app)
      .post('/v1/ai/claude/test')
      .send();

    expect(res.status).toBe(401);
  });
});
