/**
 * Document Route Handler Tests
 *
 * Tests GET /, GET /:documentId, DELETE /:documentId via supertest.
 * POST /upload is already covered by documents-upload-security.test.js.
 *
 * Uses the same mock infrastructure as auth-integration.test.js:
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

const mockDocumentPipeline = {
  processDocument: jest.fn().mockResolvedValue({
    success: true,
    documentId: 'doc-1',
    status: 'review',
    classificationResults: { classificationType: 'servicing' },
    analysisResults: { summary: { riskLevel: 'medium' } },
    caseId: null,
    steps: {}
  }),
  getStatus: jest.fn().mockResolvedValue(null),
  retryDocument: jest.fn().mockResolvedValue({
    success: true,
    documentId: 'doc-1',
    status: 'review',
    steps: {}
  }),
  completeDocument: jest.fn().mockReturnValue({
    success: true,
    documentId: 'doc-1',
    status: 'complete',
    steps: {}
  }),
  getUserPipeline: jest.fn().mockReturnValue([])
};
jest.mock('../../services/documentPipelineService', () => mockDocumentPipeline);

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
  // Restore default mock implementations
  mockDocumentService.getDocumentsByUser.mockResolvedValue([]);
  mockDocumentService.getDocument.mockResolvedValue(null);
  mockDocumentService.deleteDocument.mockResolvedValue({ success: true });
  // Restore pipeline mock defaults
  mockDocumentPipeline.processDocument.mockResolvedValue({
    success: true, documentId: 'doc-1', status: 'review',
    classificationResults: { classificationType: 'servicing' },
    analysisResults: { summary: { riskLevel: 'medium' } },
    caseId: null, steps: {}
  });
  mockDocumentPipeline.getStatus.mockResolvedValue(null);
  mockDocumentPipeline.retryDocument.mockResolvedValue({
    success: true, documentId: 'doc-1', status: 'review', steps: {}
  });
  mockDocumentPipeline.completeDocument.mockReturnValue({
    success: true, documentId: 'doc-1', status: 'complete', steps: {}
  });
  mockDocumentPipeline.getUserPipeline.mockReturnValue([]);
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

// ============================================================
// POST /v1/documents/upload — error branch (lines 68-69)
// ============================================================
describe('POST /v1/documents/upload — error branch', () => {
  it('returns 500 when documentService.uploadDocument throws', async () => {
    mockDocumentService.uploadDocument.mockRejectedValue(new Error('Storage write failed'));

    // Must provide valid base64 content for a valid small PDF-like file
    const content = Buffer.from('%PDF-1.4 fake pdf content').toString('base64');

    const res = await request(app)
      .post('/v1/documents/upload')
      .set('Authorization', 'Bearer valid-token')
      .send({
        documentId: 'doc-upload-err',
        fileName: 'test.pdf',
        content,
        documentType: 'mortgage_statement'
      });

    expect(res.status).toBe(500);
  });
});

// ============================================================
// GET /v1/documents/pipeline (lines 76-86)
// ============================================================
describe('GET /v1/documents/pipeline', () => {
  it('returns 200 with empty documents array', async () => {
    mockDocumentPipeline.getUserPipeline.mockReturnValue([]);

    const res = await request(app)
      .get('/v1/documents/pipeline')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.documents).toEqual([]);
    expect(res.body.total).toBe(0);
    expect(res.body.userId).toBe('mock-user-id-12345');
  });

  it('returns 200 with pipeline documents filtered by status', async () => {
    const pipelineDocs = [
      { documentId: 'doc-1', status: 'review', steps: {} }
    ];
    mockDocumentPipeline.getUserPipeline.mockReturnValue(pipelineDocs);

    const res = await request(app)
      .get('/v1/documents/pipeline')
      .set('Authorization', 'Bearer valid-token')
      .query({ status: 'review' });

    expect(res.status).toBe(200);
    expect(res.body.documents).toHaveLength(1);
    expect(res.body.total).toBe(1);
    expect(mockDocumentPipeline.getUserPipeline).toHaveBeenCalledWith(
      'mock-user-id-12345',
      expect.objectContaining({ status: 'review' })
    );
  });

  it('returns 400 for invalid status query parameter', async () => {
    const res = await request(app)
      .get('/v1/documents/pipeline')
      .set('Authorization', 'Bearer valid-token')
      .query({ status: 'invalid_status' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });
});

// ============================================================
// GET /v1/documents/:documentId/analysis (lines 116-153)
// ============================================================
describe('GET /v1/documents/:documentId/analysis', () => {
  it('returns 200 with analysis when document has results', async () => {
    mockDocumentService.getDocument.mockResolvedValue({
      document_id: 'doc-1',
      analysis_results: { summary: 'Test findings', issues: [] }
    });

    const res = await request(app)
      .get('/v1/documents/doc-1/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.documentId).toBe('doc-1');
    expect(res.body.status).toBe('complete');
    expect(res.body.analysis).toBeDefined();
  });

  it('returns 404 when document not found', async () => {
    mockDocumentService.getDocument.mockResolvedValue(null);

    const res = await request(app)
      .get('/v1/documents/nonexistent/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Document not found');
  });

  it('returns 404 when document has no analysis results', async () => {
    mockDocumentService.getDocument.mockResolvedValue({
      document_id: 'doc-1',
      analysis_results: null
    });

    const res = await request(app)
      .get('/v1/documents/doc-1/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Analysis not available');
  });

  it('returns 422 when analysis has error', async () => {
    mockDocumentService.getDocument.mockResolvedValue({
      document_id: 'doc-1',
      analysis_results: {
        error: true,
        errorMessage: 'Failed to parse document',
        rawResponse: 'raw data'
      }
    });

    const res = await request(app)
      .get('/v1/documents/doc-1/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(422);
    expect(res.body.error).toBe('AnalysisError');
    expect(res.body.message).toBe('Failed to parse document');
    expect(res.body.rawResponse).toBe('raw data');
  });

  it('returns 500 when service throws (lines 152-153)', async () => {
    mockDocumentService.getDocument.mockRejectedValue(new Error('DB error'));

    const res = await request(app)
      .get('/v1/documents/doc-1/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(500);
  });
});

// ============================================================
// POST /v1/documents/process (lines 213-233)
// ============================================================
describe('POST /v1/documents/process', () => {
  it('returns 200 on successful pipeline processing', async () => {
    const res = await request(app)
      .post('/v1/documents/process')
      .set('Authorization', 'Bearer valid-token')
      .send({
        documentId: 'doc-1',
        documentText: 'Monthly mortgage statement...',
        documentType: 'mortgage_statement'
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.documentId).toBe('doc-1');
  });

  it('returns 422 when pipeline processing fails', async () => {
    mockDocumentPipeline.processDocument.mockResolvedValue({
      success: false,
      documentId: 'doc-1',
      status: 'failed',
      error: { message: 'OCR failed' },
      steps: {}
    });

    const res = await request(app)
      .post('/v1/documents/process')
      .set('Authorization', 'Bearer valid-token')
      .send({
        documentId: 'doc-1',
        documentText: 'Some text'
      });

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
  });

  it('returns 500 when pipeline throws unexpected error', async () => {
    mockDocumentPipeline.processDocument.mockRejectedValue(new Error('Internal pipeline crash'));

    const res = await request(app)
      .post('/v1/documents/process')
      .set('Authorization', 'Bearer valid-token')
      .send({
        documentId: 'doc-1',
        documentText: 'Some text'
      });

    expect(res.status).toBe(500);
  });

  it('returns 400 when neither documentText nor fileBuffer is provided', async () => {
    const res = await request(app)
      .post('/v1/documents/process')
      .set('Authorization', 'Bearer valid-token')
      .send({ documentId: 'doc-1' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });
});

// ============================================================
// GET /v1/documents/:documentId/status (lines 238-250)
// ============================================================
describe('GET /v1/documents/:documentId/status', () => {
  it('returns 200 with status when pipeline record exists', async () => {
    mockDocumentPipeline.getStatus.mockResolvedValue({
      documentId: 'doc-1',
      status: 'analyzing',
      steps: { uploaded: { completedAt: '2025-01-01T00:00:00Z' } },
      error: null,
      retryCount: 0
    });

    const res = await request(app)
      .get('/v1/documents/doc-1/status')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.documentId).toBe('doc-1');
    expect(res.body.status).toBe('analyzing');
  });

  it('returns 404 when no pipeline record found', async () => {
    mockDocumentPipeline.getStatus.mockResolvedValue(null);

    const res = await request(app)
      .get('/v1/documents/nonexistent/status')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Not Found');
    expect(res.body.message).toContain('No pipeline record');
  });
});

// ============================================================
// POST /v1/documents/:documentId/retry (lines 254-278)
// ============================================================
describe('POST /v1/documents/:documentId/retry', () => {
  it('returns 200 on successful retry', async () => {
    const res = await request(app)
      .post('/v1/documents/doc-1/retry')
      .set('Authorization', 'Bearer valid-token')
      .send({ documentText: 'Retry with new text' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('returns 422 when retry results in pipeline failure', async () => {
    mockDocumentPipeline.retryDocument.mockResolvedValue({
      success: false,
      documentId: 'doc-1',
      status: 'failed',
      error: { message: 'Still failing' },
      steps: {}
    });

    const res = await request(app)
      .post('/v1/documents/doc-1/retry')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
  });

  it('returns 400 when document is not in failed state', async () => {
    mockDocumentPipeline.retryDocument.mockRejectedValue(
      new Error('Document is not in failed state (current: review)')
    );

    const res = await request(app)
      .post('/v1/documents/doc-1/retry')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
    expect(res.body.message).toContain('not in failed state');
  });

  it('returns 400 when no pipeline found for document', async () => {
    mockDocumentPipeline.retryDocument.mockRejectedValue(
      new Error('No pipeline found for document doc-missing')
    );

    const res = await request(app)
      .post('/v1/documents/doc-missing/retry')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('No pipeline found');
  });

  it('returns 500 for unexpected errors', async () => {
    mockDocumentPipeline.retryDocument.mockRejectedValue(new Error('Unexpected crash'));

    const res = await request(app)
      .post('/v1/documents/doc-1/retry')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(500);
  });
});

// ============================================================
// POST /v1/documents/:documentId/complete (lines 283-302)
// ============================================================
describe('POST /v1/documents/:documentId/complete', () => {
  it('returns 200 on successful completion', async () => {
    const res = await request(app)
      .post('/v1/documents/doc-1/complete')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.status).toBe('complete');
  });

  it('returns 400 when document must be in review state', async () => {
    mockDocumentPipeline.completeDocument.mockImplementation(() => {
      throw new Error('Document must be in review state to complete (current: analyzing)');
    });

    const res = await request(app)
      .post('/v1/documents/doc-1/complete')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
    expect(res.body.message).toContain('must be in review state');
  });

  it('returns 400 when no pipeline found', async () => {
    mockDocumentPipeline.completeDocument.mockImplementation(() => {
      throw new Error('No pipeline found for document doc-missing');
    });

    const res = await request(app)
      .post('/v1/documents/doc-missing/complete')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('No pipeline found');
  });

  it('returns 500 for unexpected errors', async () => {
    mockDocumentPipeline.completeDocument.mockImplementation(() => {
      throw new Error('Unexpected DB crash');
    });

    const res = await request(app)
      .post('/v1/documents/doc-1/complete')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(500);
  });
});
