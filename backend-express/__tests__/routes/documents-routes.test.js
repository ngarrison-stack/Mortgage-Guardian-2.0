/**
 * Document Route Handler Tests
 *
 * Tests GET /, GET /:documentId, DELETE /:documentId via supertest.
 * POST /upload is already covered by documents-upload-security.test.js.
 *
 * Uses @clerk/backend mock for auth, mocked services for business logic.
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
process.env.CLERK_SECRET_KEY = 'test-clerk-secret';
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
  mockVerifyToken.mockReset();
  mockClaudeService.reset();
  jest.clearAllMocks();
  // Default: valid token
  mockVerifyToken.mockResolvedValue({ sub: 'mock-user-id-12345' });
  // Restore default mock implementations
  mockDocumentService.getDocumentsByUser.mockResolvedValue([]);
  mockDocumentService.getDocument.mockResolvedValue(null);
  mockDocumentService.deleteDocument.mockResolvedValue({ success: true });
});

// ============================================================
// GET /v1/documents
// ============================================================
describe('GET /v1/documents', () => {
  it('returns 200 with documents array', async () => {
    const docs = [
      { document_id: 'doc-1', file_name: 'stmt.pdf' },
      { document_id: 'doc-2', file_name: 'tax.pdf' }
    ];
    mockDocumentService.getDocumentsByUser.mockResolvedValue(docs);

    const res = await request(app)
      .get('/v1/documents')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.documents).toHaveLength(2);
    expect(res.body.total).toBe(2);
    expect(res.body.userId).toBe('mock-user-id-12345');
  });

  it('passes userId from auth context, limit, offset to service', async () => {
    mockDocumentService.getDocumentsByUser.mockResolvedValue([]);

    await request(app)
      .get('/v1/documents')
      .set('Authorization', 'Bearer valid-token')
      .query({ limit: '10', offset: '5' });

    expect(mockDocumentService.getDocumentsByUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'mock-user-id-12345',
        limit: 10,
        offset: 5
      })
    );
  });

  it('returns 200 even without query params (userId from auth)', async () => {
    mockDocumentService.getDocumentsByUser.mockResolvedValue([]);

    const res = await request(app)
      .get('/v1/documents')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
  });

  it('returns 500 on service error', async () => {
    mockDocumentService.getDocumentsByUser.mockRejectedValue(new Error('DB unavailable'));

    const res = await request(app)
      .get('/v1/documents')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(500);
  });
});

// ============================================================
// GET /v1/documents/:documentId
// ============================================================
describe('GET /v1/documents/:documentId', () => {
  it('returns 200 with document data (userId from auth)', async () => {
    const doc = {
      document_id: 'doc-1',
      file_name: 'stmt.pdf',
      content: 'base64data'
    };
    mockDocumentService.getDocument.mockResolvedValue(doc);

    const res = await request(app)
      .get('/v1/documents/doc-1')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.document_id).toBe('doc-1');
    expect(res.body.file_name).toBe('stmt.pdf');
  });

  it('returns 404 when document not found', async () => {
    mockDocumentService.getDocument.mockResolvedValue(null);

    const res = await request(app)
      .get('/v1/documents/nonexistent')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Not Found');
  });

  it('uses auth context userId, not query param', async () => {
    mockDocumentService.getDocument.mockResolvedValue({ document_id: 'doc-1' });

    await request(app)
      .get('/v1/documents/doc-1')
      .set('Authorization', 'Bearer valid-token');

    expect(mockDocumentService.getDocument).toHaveBeenCalledWith({
      documentId: 'doc-1',
      userId: 'mock-user-id-12345'
    });
  });

  it('returns 500 on service error', async () => {
    mockDocumentService.getDocument.mockRejectedValue(new Error('Storage timeout'));

    const res = await request(app)
      .get('/v1/documents/doc-1')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(500);
  });
});

// ============================================================
// DELETE /v1/documents/:documentId
// ============================================================
describe('DELETE /v1/documents/:documentId', () => {
  it('returns 200 with success message (userId from auth)', async () => {
    mockDocumentService.deleteDocument.mockResolvedValue({ success: true });

    const res = await request(app)
      .delete('/v1/documents/doc-1')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toBe('Document deleted successfully');
    expect(mockDocumentService.deleteDocument).toHaveBeenCalledWith({
      documentId: 'doc-1',
      userId: 'mock-user-id-12345'
    });
  });

  it('returns 500 on service error', async () => {
    mockDocumentService.deleteDocument.mockRejectedValue(new Error('Document not found'));

    const res = await request(app)
      .delete('/v1/documents/doc-1')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(500);
  });
});
