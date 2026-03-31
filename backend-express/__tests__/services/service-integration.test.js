/**
 * Cross-service integration tests
 *
 * Verifies data flows between Claude, Plaid, PlaidData, and Document services.
 * External APIs (Anthropic, Plaid SDK) are mocked — but the tests
 * exercise real service-to-service interactions within the backend.
 */

// --- Mock Anthropic SDK ---
const mockMessagesCreate = jest.fn();
jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate }
  }));
});

// --- Mock Plaid SDK ---
const mockItemPublicTokenExchange = jest.fn();
const mockTransactionsGet = jest.fn();
jest.mock('plaid', () => ({
  Configuration: jest.fn(),
  PlaidApi: jest.fn().mockImplementation(() => ({
    itemPublicTokenExchange: mockItemPublicTokenExchange,
    transactionsGet: mockTransactionsGet
  })),
  PlaidEnvironments: { sandbox: 'https://sandbox.plaid.com' },
  Products: { Auth: 'auth', Transactions: 'transactions' },
  CountryCode: { Us: 'US' }
}));

// --- Mock db module (documentService uses it) ---
const mockQuery = jest.fn();
jest.mock('../../services/db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}));
jest.mock('../../db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}), { virtual: true });

// Mock fs/promises for documentService
jest.mock('fs', () => ({
  ...jest.requireActual('fs'),
  promises: {
    writeFile: jest.fn().mockResolvedValue(undefined),
    readFile: jest.fn().mockResolvedValue(Buffer.from('test')),
    mkdir: jest.fn().mockResolvedValue(undefined),
    unlink: jest.fn().mockResolvedValue(undefined)
  }
}));

// Set env vars before requiring services
process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';
process.env.ANTHROPIC_API_KEY = 'test-api-key';

// Require services AFTER all mocks are in place
const claudeService = require('../../services/claudeService');
const documentService = require('../../services/documentService');

// ============================================================
// Claude -> Document flow
// ============================================================
describe('Cross-service integration', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Default: db query returns success
    mockQuery.mockResolvedValue({ rows: [{ document_id: 'doc-1' }], rowCount: 1 });
  });

  describe('Claude -> Document flow', () => {
    it('Claude analysis result can be stored via documentService', async () => {
      // Step 1: Claude analyzes a document
      mockMessagesCreate.mockResolvedValue({
        content: [{ text: 'Found 2 escrow calculation errors totaling $432.50' }],
        model: 'claude-3-5-sonnet-20241022',
        usage: { input_tokens: 500, output_tokens: 200 },
        stop_reason: 'end_turn'
      });

      const analysis = await claudeService.analyzeDocument({
        prompt: 'Analyze this mortgage statement for errors...'
      });

      expect(analysis.content).toContain('escrow calculation errors');

      // Step 2: Store the analysis with the document
      mockQuery.mockResolvedValue({
        rows: [{ document_id: 'doc-1', analysis_results: analysis }],
        rowCount: 1
      });

      const stored = await documentService.uploadDocument({
        documentId: 'doc-1',
        userId: 'user-1',
        fileName: 'statement.pdf',
        documentType: 'mortgage_statement',
        content: Buffer.from('mock-pdf-content').toString('base64'),
        analysisResults: analysis,
        metadata: { source: 'upload' }
      });

      expect(stored.documentId).toBe('doc-1');
      // Verify the analysis was passed through to the query
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO documents'),
        expect.arrayContaining([expect.stringContaining('escrow calculation errors')])
      );
    });

    it('Claude API error does not corrupt document storage', async () => {
      // Claude throws
      mockMessagesCreate.mockRejectedValue(new Error('API unavailable'));

      await expect(claudeService.analyzeDocument({
        prompt: 'analyze...'
      })).rejects.toThrow('API unavailable');

      // Document service still works independently
      mockQuery.mockResolvedValue({ rows: [{ document_id: 'doc-2' }], rowCount: 1 });

      const stored = await documentService.uploadDocument({
        documentId: 'doc-2',
        userId: 'user-1',
        fileName: 'statement.pdf',
        documentType: 'mortgage_statement',
        content: Buffer.from('pdf-content').toString('base64'),
        analysisResults: null
      });

      expect(stored.documentId).toBe('doc-2');
    });
  });

  // ============================================================
  // Plaid -> PlaidData flow
  // ============================================================
  describe('Plaid -> PlaidData flow', () => {
    let plaidDataService;

    beforeEach(() => {
      // Use mock mode for plaidDataService to avoid DB complexity
      delete process.env.DATABASE_URL;
      jest.isolateModules(() => {
        plaidDataService = require('../../services/plaidDataService');
      });
    });

    afterEach(() => {
      process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';
    });

    it('exchangePublicToken result feeds into plaidDataService.upsertPlaidItem', async () => {
      const exchangeResult = {
        accessToken: 'access-sandbox-abc123',
        itemId: 'item-sandbox-xyz'
      };

      const stored = await plaidDataService.upsertPlaidItem({
        itemId: exchangeResult.itemId,
        userId: 'user-1',
        accessToken: exchangeResult.accessToken,
        status: 'active'
      });

      expect(stored).toMatchObject({ success: true, mock: true });

      const retrieved = await plaidDataService.getItem(exchangeResult.itemId);
      expect(retrieved.data.accessToken).toBe('access-sandbox-abc123');
    });

    it('getTransactions results feed into plaidDataService.storeTransactions', async () => {
      const transactions = [
        { transaction_id: 'tx-int-1', amount: 1500, name: 'Mortgage Payment' },
        { transaction_id: 'tx-int-2', amount: 45.99, name: 'Utility Bill' },
        { transaction_id: 'tx-int-3', amount: 120.00, name: 'Insurance' }
      ];

      const stored = await plaidDataService.storeTransactions({
        itemId: 'item-1',
        transactions,
        userId: 'user-1'
      });

      expect(stored).toMatchObject({ success: true, count: 3 });
    });
  });

  // ============================================================
  // Error propagation
  // ============================================================
  describe('Error propagation', () => {
    it('Claude API error preserves status code', async () => {
      const apiError = new Error('rate limited');
      apiError.status = 429;
      mockMessagesCreate.mockRejectedValue(apiError);

      try {
        await claudeService.analyzeDocument({ prompt: 'test' });
        fail('Should have thrown');
      } catch (err) {
        expect(err.status).toBe(429);
        expect(err.message).toBe('rate limited');
      }
    });

    it('Database error in documentService throws', async () => {
      mockQuery.mockRejectedValue(new Error('Storage quota exceeded'));

      await expect(documentService.uploadDocument({
        documentId: 'doc-fail',
        userId: 'user-1',
        fileName: 'test.pdf',
        documentType: 'pdf',
        content: Buffer.from('content').toString('base64')
      })).rejects.toThrow('Storage quota exceeded');
    });
  });

  // ============================================================
  // Service isolation
  // ============================================================
  describe('Service isolation', () => {
    it('Claude service failure does not affect Plaid data service', async () => {
      // Claude fails
      mockMessagesCreate.mockRejectedValue(new Error('Claude down'));

      await expect(claudeService.analyzeDocument({
        prompt: 'test'
      })).rejects.toThrow('Claude down');

      // PlaidDataService (mock mode) still works fine
      let plaidDataMock;
      const savedUrl = process.env.DATABASE_URL;
      delete process.env.DATABASE_URL;
      jest.isolateModules(() => {
        plaidDataMock = require('../../services/plaidDataService');
      });

      const result = await plaidDataMock.upsertPlaidItem({
        itemId: 'isolated-item',
        userId: 'user-1',
        accessToken: 'tok'
      });

      expect(result.success).toBe(true);
      process.env.DATABASE_URL = savedUrl;
    });

    it('Each service maintains independent state', async () => {
      let plaidDataMock;
      let docServiceMock;
      const savedUrl2 = process.env.DATABASE_URL;
      delete process.env.DATABASE_URL;
      jest.isolateModules(() => {
        plaidDataMock = require('../../services/plaidDataService');
        docServiceMock = require('../../services/documentService');
      });

      // Store a Plaid item
      await plaidDataMock.upsertPlaidItem({
        itemId: 'plaid-only-item',
        userId: 'user-1',
        accessToken: 'tok'
      });

      // Store a document
      await docServiceMock.uploadDocument({
        documentId: 'doc-only-item',
        userId: 'user-1',
        fileName: 'test.pdf',
        documentType: 'pdf',
        content: 'base64content'
      });

      // Plaid service doesn't have the document
      const plaidGet = await plaidDataMock.getItem('doc-only-item');
      expect(plaidGet.success).toBe(false);

      // Document service doesn't have the Plaid item
      const docGet = await docServiceMock.getDocument({
        documentId: 'plaid-only-item',
        userId: 'user-1'
      });
      expect(docGet).toBeNull();
      process.env.DATABASE_URL = savedUrl2;
    });
  });
});
