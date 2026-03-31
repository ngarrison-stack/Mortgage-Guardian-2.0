/**
 * Case Route Handler Tests
 *
 * Tests all 7 case file endpoints via supertest.
 * Uses @clerk/backend mock for auth, mocked services for business logic.
 */

const mockClaudeService = require('../mocks/mockClaudeService');
const request = require('supertest');

const mockVerifyToken = jest.fn();
jest.mock('@clerk/backend', () => ({ verifyToken: mockVerifyToken }));

jest.mock('../../services/claudeService', () => mockClaudeService);

const mockDocumentService = {
  uploadDocument: jest.fn().mockResolvedValue({ documentId: 'doc-1', storagePath: 'mock/path' }),
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true }),
  getContentType: jest.fn().mockReturnValue('application/pdf')
};
jest.mock('../../services/documentService', () => mockDocumentService);

const mockCaseFileService = {
  createCase: jest.fn(),
  getCasesByUser: jest.fn(),
  getCase: jest.fn(),
  updateCase: jest.fn(),
  deleteCase: jest.fn(),
  addDocumentToCase: jest.fn(),
  removeDocumentFromCase: jest.fn()
};
jest.mock('../../services/caseFileService', () => mockCaseFileService);

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

process.env.CLERK_SECRET_KEY = 'test-clerk-secret';
process.env.NODE_ENV = 'production';
process.env.VERCEL = '1';

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
  for (const routePath of routePaths) { delete require.cache[routePath]; }
  delete require.cache[require.resolve('../../middleware/auth')];
  app = require('../../server');
  process.env.NODE_ENV = 'test';
});

afterAll(() => { delete process.env.VERCEL; });

beforeEach(() => {
  mockVerifyToken.mockReset();
  mockClaudeService.reset();
  jest.clearAllMocks();
  mockVerifyToken.mockResolvedValue({ sub: 'mock-user-id-12345' });
});

describe('POST /v1/cases', () => {
  it('returns 201 with created case', async () => {
    const createdCase = { id: 'case-1', user_id: 'mock-user-id-12345', case_name: 'Test Case', status: 'open', created_at: '2026-01-01T00:00:00.000Z' };
    mockCaseFileService.createCase.mockResolvedValue(createdCase);
    const res = await request(app).post('/v1/cases').set('Authorization', 'Bearer valid-token').send({ caseName: 'Test Case' });
    expect(res.status).toBe(201);
    expect(res.body.id).toBe('case-1');
    expect(mockCaseFileService.createCase).toHaveBeenCalledWith(expect.objectContaining({ userId: 'mock-user-id-12345', caseName: 'Test Case' }));
  });

  it('passes optional fields to service', async () => {
    mockCaseFileService.createCase.mockResolvedValue({ id: 'case-2' });
    await request(app).post('/v1/cases').set('Authorization', 'Bearer valid-token').send({ caseName: 'Full Case', borrowerName: 'John Doe', propertyAddress: '123 Main St', loanNumber: 'LN-001', servicerName: 'Bank Corp', notes: 'Test notes' });
    expect(mockCaseFileService.createCase).toHaveBeenCalledWith(expect.objectContaining({ caseName: 'Full Case', borrowerName: 'John Doe', propertyAddress: '123 Main St', loanNumber: 'LN-001', servicerName: 'Bank Corp', notes: 'Test notes' }));
  });

  it('returns 400 when caseName is missing', async () => { const res = await request(app).post('/v1/cases').set('Authorization', 'Bearer valid-token').send({}); expect(res.status).toBe(400); expect(res.body.error).toBe('Bad Request'); });
  it('returns 400 when caseName exceeds 200 chars', async () => { const res = await request(app).post('/v1/cases').set('Authorization', 'Bearer valid-token').send({ caseName: 'x'.repeat(201) }); expect(res.status).toBe(400); });
  it('returns 401 without auth token', async () => { const res = await request(app).post('/v1/cases').send({ caseName: 'Test Case' }); expect(res.status).toBe(401); });
  it('returns 500 on service error', async () => { mockCaseFileService.createCase.mockRejectedValue(new Error('DB error')); const res = await request(app).post('/v1/cases').set('Authorization', 'Bearer valid-token').send({ caseName: 'Test Case' }); expect(res.status).toBe(500); });
});

describe('GET /v1/cases', () => {
  it('returns 200 with array of cases', async () => {
    const cases = [{ id: 'case-1', case_name: 'Case A' }, { id: 'case-2', case_name: 'Case B' }];
    mockCaseFileService.getCasesByUser.mockResolvedValue(cases);
    const res = await request(app).get('/v1/cases').set('Authorization', 'Bearer valid-token');
    expect(res.status).toBe(200);
    expect(res.body.cases).toHaveLength(2);
    expect(res.body.total).toBe(2);
    expect(res.body.userId).toBe('mock-user-id-12345');
  });

  it('passes status filter to service', async () => { mockCaseFileService.getCasesByUser.mockResolvedValue([]); await request(app).get('/v1/cases').set('Authorization', 'Bearer valid-token').query({ status: 'open' }); expect(mockCaseFileService.getCasesByUser).toHaveBeenCalledWith(expect.objectContaining({ userId: 'mock-user-id-12345', status: 'open' })); });
  it('passes limit and offset to service', async () => { mockCaseFileService.getCasesByUser.mockResolvedValue([]); await request(app).get('/v1/cases').set('Authorization', 'Bearer valid-token').query({ limit: '10', offset: '5' }); expect(mockCaseFileService.getCasesByUser).toHaveBeenCalledWith(expect.objectContaining({ limit: 10, offset: 5 })); });
  it('returns 400 for invalid status value', async () => { const res = await request(app).get('/v1/cases').set('Authorization', 'Bearer valid-token').query({ status: 'invalid_status' }); expect(res.status).toBe(400); });
  it('returns 401 without auth token', async () => { const res = await request(app).get('/v1/cases'); expect(res.status).toBe(401); });
  it('returns 500 on service error', async () => { mockCaseFileService.getCasesByUser.mockRejectedValue(new Error('DB unavailable')); const res = await request(app).get('/v1/cases').set('Authorization', 'Bearer valid-token'); expect(res.status).toBe(500); });
});

describe('GET /v1/cases/:caseId', () => {
  it('returns 200 with case and documents', async () => { mockCaseFileService.getCase.mockResolvedValue({ id: 'case-1', case_name: 'Test Case', documents: [{ document_id: 'doc-1' }] }); const res = await request(app).get('/v1/cases/case-1').set('Authorization', 'Bearer valid-token'); expect(res.status).toBe(200); expect(res.body.id).toBe('case-1'); expect(res.body.documents).toHaveLength(1); });
  it('returns 404 when case not found', async () => { mockCaseFileService.getCase.mockResolvedValue(null); const res = await request(app).get('/v1/cases/nonexistent').set('Authorization', 'Bearer valid-token'); expect(res.status).toBe(404); expect(res.body.error).toBe('Not Found'); });
  it('passes userId from JWT to service', async () => { mockCaseFileService.getCase.mockResolvedValue({ id: 'case-1' }); await request(app).get('/v1/cases/case-1').set('Authorization', 'Bearer valid-token'); expect(mockCaseFileService.getCase).toHaveBeenCalledWith({ caseId: 'case-1', userId: 'mock-user-id-12345' }); });
  it('returns 401 without auth token', async () => { const res = await request(app).get('/v1/cases/case-1'); expect(res.status).toBe(401); });
  it('returns 500 on service error', async () => { mockCaseFileService.getCase.mockRejectedValue(new Error('DB timeout')); const res = await request(app).get('/v1/cases/case-1').set('Authorization', 'Bearer valid-token'); expect(res.status).toBe(500); });
});

describe('PUT /v1/cases/:caseId', () => {
  it('returns 200 with updated case', async () => { mockCaseFileService.updateCase.mockResolvedValue({ id: 'case-1', case_name: 'Updated Case', status: 'in_review' }); const res = await request(app).put('/v1/cases/case-1').set('Authorization', 'Bearer valid-token').send({ caseName: 'Updated Case', status: 'in_review' }); expect(res.status).toBe(200); expect(res.body.case_name).toBe('Updated Case'); });
  it('returns 404 when case not found', async () => { mockCaseFileService.updateCase.mockResolvedValue(null); const res = await request(app).put('/v1/cases/nonexistent').set('Authorization', 'Bearer valid-token').send({ caseName: 'Updated' }); expect(res.status).toBe(404); expect(res.body.error).toBe('Not Found'); });
  it('returns 400 when no fields provided', async () => { const res = await request(app).put('/v1/cases/case-1').set('Authorization', 'Bearer valid-token').send({}); expect(res.status).toBe(400); });
  it('returns 400 for invalid status value', async () => { const res = await request(app).put('/v1/cases/case-1').set('Authorization', 'Bearer valid-token').send({ status: 'bogus' }); expect(res.status).toBe(400); });
  it('passes updates and userId to service', async () => { mockCaseFileService.updateCase.mockResolvedValue({ id: 'case-1' }); await request(app).put('/v1/cases/case-1').set('Authorization', 'Bearer valid-token').send({ caseName: 'New Name', notes: 'Updated notes' }); expect(mockCaseFileService.updateCase).toHaveBeenCalledWith({ caseId: 'case-1', userId: 'mock-user-id-12345', updates: { caseName: 'New Name', notes: 'Updated notes' } }); });
  it('returns 401 without auth token', async () => { const res = await request(app).put('/v1/cases/case-1').send({ caseName: 'Updated' }); expect(res.status).toBe(401); });
  it('returns 500 on service error', async () => { mockCaseFileService.updateCase.mockRejectedValue(new Error('DB error')); const res = await request(app).put('/v1/cases/case-1').set('Authorization', 'Bearer valid-token').send({ caseName: 'Updated' }); expect(res.status).toBe(500); });
});

describe('DELETE /v1/cases/:caseId', () => {
  it('returns 200 with success', async () => { mockCaseFileService.deleteCase.mockResolvedValue({ success: true }); const res = await request(app).delete('/v1/cases/case-1').set('Authorization', 'Bearer valid-token'); expect(res.status).toBe(200); expect(res.body.success).toBe(true); expect(mockCaseFileService.deleteCase).toHaveBeenCalledWith({ caseId: 'case-1', userId: 'mock-user-id-12345' }); });
  it('returns 401 without auth token', async () => { const res = await request(app).delete('/v1/cases/case-1'); expect(res.status).toBe(401); });
  it('returns 500 on service error', async () => { mockCaseFileService.deleteCase.mockRejectedValue(new Error('Case not found')); const res = await request(app).delete('/v1/cases/case-1').set('Authorization', 'Bearer valid-token'); expect(res.status).toBe(500); });
});

describe('POST /v1/cases/:caseId/documents', () => {
  it('returns 200 with association result', async () => { mockCaseFileService.addDocumentToCase.mockResolvedValue({ document_id: 'doc-1', case_id: 'case-1' }); const res = await request(app).post('/v1/cases/case-1/documents').set('Authorization', 'Bearer valid-token').send({ documentId: 'doc-1' }); expect(res.status).toBe(200); expect(res.body.document_id).toBe('doc-1'); expect(mockCaseFileService.addDocumentToCase).toHaveBeenCalledWith({ caseId: 'case-1', documentId: 'doc-1', userId: 'mock-user-id-12345' }); });
  it('returns 400 when documentId is missing', async () => { const res = await request(app).post('/v1/cases/case-1/documents').set('Authorization', 'Bearer valid-token').send({}); expect(res.status).toBe(400); expect(res.body.error).toBe('Bad Request'); });
  it('returns 401 without auth token', async () => { const res = await request(app).post('/v1/cases/case-1/documents').send({ documentId: 'doc-1' }); expect(res.status).toBe(401); });
  it('returns 500 on service error', async () => { mockCaseFileService.addDocumentToCase.mockRejectedValue(new Error('Case not found')); const res = await request(app).post('/v1/cases/case-1/documents').set('Authorization', 'Bearer valid-token').send({ documentId: 'doc-1' }); expect(res.status).toBe(500); });
});

describe('DELETE /v1/cases/:caseId/documents/:documentId', () => {
  it('returns 200 with removal result', async () => { mockCaseFileService.removeDocumentFromCase.mockResolvedValue({ document_id: 'doc-1', case_id: null }); const res = await request(app).delete('/v1/cases/case-1/documents/doc-1').set('Authorization', 'Bearer valid-token'); expect(res.status).toBe(200); expect(res.body.document_id).toBe('doc-1'); expect(res.body.case_id).toBeNull(); expect(mockCaseFileService.removeDocumentFromCase).toHaveBeenCalledWith({ documentId: 'doc-1', userId: 'mock-user-id-12345' }); });
  it('returns 401 without auth token', async () => { const res = await request(app).delete('/v1/cases/case-1/documents/doc-1'); expect(res.status).toBe(401); });
  it('returns 500 on service error', async () => { mockCaseFileService.removeDocumentFromCase.mockRejectedValue(new Error('Document not found')); const res = await request(app).delete('/v1/cases/case-1/documents/doc-1').set('Authorization', 'Bearer valid-token'); expect(res.status).toBe(500); });
});
