/**
 * Cross-User Isolation Route-Level Tests
 *
 * Verifies that the application layer enforces strict user isolation
 * for all document and case endpoints. Combined with RLS (Plan 01),
 * storage policies (Plan 02), and encryption (Plan 03-04), this
 * creates a comprehensive defense-in-depth security posture.
 *
 * Key principle: No user should ever be able to access, modify, or
 * delete another user's documents or case files through any API path.
 *
 * Tests cover:
 * - Document isolation: GET, DELETE scoped by userId
 * - Case isolation: GET, PUT, DELETE scoped by req.user.id (JWT)
 * - Cross-user document association prevention
 */

const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');
const mockClaudeService = require('../mocks/mockClaudeService');
const request = require('supertest');

const mockClient = createMockSupabaseClient();

// ============================================================
// MOCKS — set up before any module loads
// ============================================================

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

jest.mock('../../services/claudeService', () => mockClaudeService);

// Document service mock that enforces user isolation (simulates real behavior)
const mockDocumentStore = new Map();
const mockDocumentService = {
  uploadDocument: jest.fn(async ({ documentId, userId, fileName, documentType, content }) => {
    mockDocumentStore.set(documentId, { document_id: documentId, user_id: userId, file_name: fileName });
    return { documentId, storagePath: `documents/${userId}/${documentId}` };
  }),
  getDocumentsByUser: jest.fn(async ({ userId }) => {
    return Array.from(mockDocumentStore.values()).filter(d => d.user_id === userId);
  }),
  getDocument: jest.fn(async ({ documentId, userId }) => {
    const doc = mockDocumentStore.get(documentId);
    // Simulate real service: only return if user_id matches
    if (doc && doc.user_id === userId) return doc;
    return null;
  }),
  deleteDocument: jest.fn(async ({ documentId, userId }) => {
    const doc = mockDocumentStore.get(documentId);
    if (!doc || doc.user_id !== userId) {
      throw new Error('Document not found');
    }
    mockDocumentStore.delete(documentId);
    return { success: true };
  }),
  getContentType: jest.fn().mockReturnValue('application/pdf')
};
jest.mock('../../services/documentService', () => mockDocumentService);

// Case file service mock that enforces user isolation (simulates real behavior)
const mockCaseStore = new Map();
const mockDocCaseMap = new Map();
const mockCaseFileService = {
  createCase: jest.fn(async ({ userId, caseName }) => {
    const id = `case-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
    const caseData = { id, user_id: userId, case_name: caseName, status: 'open' };
    mockCaseStore.set(id, caseData);
    return caseData;
  }),
  getCasesByUser: jest.fn(async ({ userId, status }) => {
    let cases = Array.from(mockCaseStore.values()).filter(c => c.user_id === userId);
    if (status) cases = cases.filter(c => c.status === status);
    return cases;
  }),
  getCase: jest.fn(async ({ caseId, userId }) => {
    const c = mockCaseStore.get(caseId);
    if (c && c.user_id === userId) return { ...c, documents: [] };
    return null;
  }),
  updateCase: jest.fn(async ({ caseId, userId, updates }) => {
    const c = mockCaseStore.get(caseId);
    if (!c || c.user_id !== userId) return null;
    Object.assign(c, updates);
    return c;
  }),
  deleteCase: jest.fn(async ({ caseId, userId }) => {
    const c = mockCaseStore.get(caseId);
    if (!c || c.user_id !== userId) throw new Error('Case not found');
    mockCaseStore.delete(caseId);
    return { success: true };
  }),
  addDocumentToCase: jest.fn(async ({ caseId, documentId, userId }) => {
    const c = mockCaseStore.get(caseId);
    if (!c || c.user_id !== userId) throw new Error('Case not found');
    // Also verify the document belongs to this user
    const doc = mockDocumentStore.get(documentId);
    if (!doc || doc.user_id !== userId) throw new Error('Document not found');
    mockDocCaseMap.set(documentId, caseId);
    return { document_id: documentId, case_id: caseId };
  }),
  removeDocumentFromCase: jest.fn(async ({ documentId, userId }) => {
    mockDocCaseMap.delete(documentId);
    return { document_id: documentId, case_id: null };
  })
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

// ============================================================
// CONSTANTS
// ============================================================

// The mock Supabase auth always returns this user ID for "Bearer valid-token"
const USER_A_ID = 'mock-user-id-12345';
// User-B is a different user who should NOT access User-A's data
const USER_B_ID = 'user-b-different-99999';

// ============================================================
// TEST SETUP
// ============================================================

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
  mockDocumentStore.clear();
  mockCaseStore.clear();
  mockDocCaseMap.clear();
  jest.clearAllMocks();
});

// ============================================================
// CROSS-USER DOCUMENT ISOLATION
// ============================================================
describe('Cross-User Document Isolation', () => {

  test('user cannot access another user\'s document via GET /v1/documents/:id', async () => {
    // Create a document owned by User-A
    mockDocumentStore.set('doc-secret', {
      document_id: 'doc-secret',
      user_id: USER_A_ID,
      file_name: 'secret-mortgage.pdf'
    });

    // User-B tries to access User-A's document
    // Note: document routes use userId from query params
    const res = await request(app)
      .get('/v1/documents/doc-secret')
      .set('Authorization', 'Bearer valid-token')
      .query({ userId: USER_B_ID });

    // Should get 404 — document belongs to User-A, not User-B
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Not Found');

    // Verify the service was called with User-B's ID (correct scoping)
    expect(mockDocumentService.getDocument).toHaveBeenCalledWith({
      documentId: 'doc-secret',
      userId: USER_B_ID
    });
  });

  test('user only sees own documents in GET /v1/documents', async () => {
    // Create documents for both users
    mockDocumentStore.set('doc-a1', { document_id: 'doc-a1', user_id: USER_A_ID, file_name: 'a1.pdf' });
    mockDocumentStore.set('doc-a2', { document_id: 'doc-a2', user_id: USER_A_ID, file_name: 'a2.pdf' });
    mockDocumentStore.set('doc-b1', { document_id: 'doc-b1', user_id: USER_B_ID, file_name: 'b1.pdf' });

    // User-A lists documents
    const resA = await request(app)
      .get('/v1/documents')
      .set('Authorization', 'Bearer valid-token')
      .query({ userId: USER_A_ID });

    expect(resA.status).toBe(200);
    expect(resA.body.documents).toHaveLength(2);
    // All returned documents should belong to User-A
    for (const doc of resA.body.documents) {
      expect(doc.user_id).toBe(USER_A_ID);
    }

    // User-B lists documents
    const resB = await request(app)
      .get('/v1/documents')
      .set('Authorization', 'Bearer valid-token')
      .query({ userId: USER_B_ID });

    expect(resB.status).toBe(200);
    expect(resB.body.documents).toHaveLength(1);
    expect(resB.body.documents[0].user_id).toBe(USER_B_ID);
  });

  test('user cannot delete another user\'s document', async () => {
    // Create a document owned by User-A
    mockDocumentStore.set('doc-protected', {
      document_id: 'doc-protected',
      user_id: USER_A_ID,
      file_name: 'protected.pdf'
    });

    // User-B tries to delete User-A's document
    const res = await request(app)
      .delete('/v1/documents/doc-protected')
      .set('Authorization', 'Bearer valid-token')
      .query({ userId: USER_B_ID });

    // Should fail — document belongs to User-A
    expect(res.status).toBe(500);

    // Verify document still exists
    expect(mockDocumentStore.has('doc-protected')).toBe(true);
  });
});

// ============================================================
// CROSS-USER CASE FILE ISOLATION
// ============================================================
describe('Cross-User Case File Isolation', () => {

  // Helper: Create a case for a specific user by inserting directly into the store
  function createCaseForUser(userId, caseId, caseName) {
    const caseData = { id: caseId, user_id: userId, case_name: caseName, status: 'open' };
    mockCaseStore.set(caseId, caseData);
    return caseData;
  }

  test('user cannot access another user\'s case via GET /v1/cases/:caseId', async () => {
    // Create a case for User-A (same user as JWT mock returns)
    createCaseForUser(USER_A_ID, 'case-private', 'Private Case');

    // Create a case for User-B
    createCaseForUser(USER_B_ID, 'case-b-private', 'User B Private Case');

    // JWT auth returns User-A. Try to access User-B's case.
    // Since cases route uses req.user.id from JWT, User-A cannot access User-B's case.
    const res = await request(app)
      .get('/v1/cases/case-b-private')
      .set('Authorization', 'Bearer valid-token');

    // Should get 404 — User-A (from JWT) doesn't own this case
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Not Found');

    // Verify service was called with JWT user's ID (User-A)
    expect(mockCaseFileService.getCase).toHaveBeenCalledWith({
      caseId: 'case-b-private',
      userId: USER_A_ID
    });
  });

  test('user only sees own case files in GET /v1/cases', async () => {
    // Create cases for both users
    createCaseForUser(USER_A_ID, 'case-a1', 'User A Case 1');
    createCaseForUser(USER_A_ID, 'case-a2', 'User A Case 2');
    createCaseForUser(USER_B_ID, 'case-b1', 'User B Case 1');

    // JWT auth returns User-A
    const res = await request(app)
      .get('/v1/cases')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.cases).toHaveLength(2);
    // All returned cases should belong to User-A (JWT user)
    for (const c of res.body.cases) {
      expect(c.user_id).toBe(USER_A_ID);
    }
    expect(res.body.userId).toBe(USER_A_ID);
  });

  test('user cannot modify another user\'s case file via PUT', async () => {
    // Create a case for User-B
    createCaseForUser(USER_B_ID, 'case-b-readonly', 'User B Read-Only');

    // JWT auth returns User-A. Try to update User-B's case.
    const res = await request(app)
      .put('/v1/cases/case-b-readonly')
      .set('Authorization', 'Bearer valid-token')
      .send({ caseName: 'Hacked By User-A' });

    // Should get 404 — User-A doesn't own this case
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Not Found');

    // Verify the case was not actually modified
    const originalCase = mockCaseStore.get('case-b-readonly');
    expect(originalCase.case_name).toBe('User B Read-Only');
  });

  test('user cannot delete another user\'s case file', async () => {
    // Create a case for User-B
    createCaseForUser(USER_B_ID, 'case-b-delete', 'User B Delete Target');

    // JWT auth returns User-A. Try to delete User-B's case.
    const res = await request(app)
      .delete('/v1/cases/case-b-delete')
      .set('Authorization', 'Bearer valid-token');

    // Should fail — User-A doesn't own this case
    expect(res.status).toBe(500);

    // Verify case still exists
    expect(mockCaseStore.has('case-b-delete')).toBe(true);
  });
});

// ============================================================
// CROSS-USER DOCUMENT ASSOCIATION ISOLATION
// ============================================================
describe('Cross-User Document Association Isolation', () => {

  test('user cannot associate documents across user boundaries', async () => {
    // Create a case for User-A (JWT user)
    const caseA = { id: 'case-a-assoc', user_id: USER_A_ID, case_name: 'User A Case', status: 'open' };
    mockCaseStore.set('case-a-assoc', caseA);

    // Create a document for User-B
    mockDocumentStore.set('doc-b-foreign', {
      document_id: 'doc-b-foreign',
      user_id: USER_B_ID,
      file_name: 'foreign-doc.pdf'
    });

    // JWT auth returns User-A. Try to add User-B's document to User-A's case.
    const res = await request(app)
      .post('/v1/cases/case-a-assoc/documents')
      .set('Authorization', 'Bearer valid-token')
      .send({ documentId: 'doc-b-foreign' });

    // Should fail — the document belongs to User-B, not User-A
    expect(res.status).toBe(500);

    // Verify the document was NOT associated with the case
    expect(mockDocCaseMap.has('doc-b-foreign')).toBe(false);
  });

  test('user can associate their own document to their own case', async () => {
    // Create a case for User-A (JWT user)
    const caseA = { id: 'case-a-own', user_id: USER_A_ID, case_name: 'My Case', status: 'open' };
    mockCaseStore.set('case-a-own', caseA);

    // Create a document for User-A
    mockDocumentStore.set('doc-a-own', {
      document_id: 'doc-a-own',
      user_id: USER_A_ID,
      file_name: 'my-doc.pdf'
    });

    // JWT auth returns User-A. Add own document to own case.
    const res = await request(app)
      .post('/v1/cases/case-a-own/documents')
      .set('Authorization', 'Bearer valid-token')
      .send({ documentId: 'doc-a-own' });

    // Should succeed — both resources belong to User-A
    expect(res.status).toBe(200);
    expect(res.body.document_id).toBe('doc-a-own');
    expect(res.body.case_id).toBe('case-a-own');
  });

  test('user cannot add document to another user\'s case', async () => {
    // Create a case for User-B
    mockCaseStore.set('case-b-target', {
      id: 'case-b-target',
      user_id: USER_B_ID,
      case_name: 'User B Target Case',
      status: 'open'
    });

    // Create a document for User-A (JWT user)
    mockDocumentStore.set('doc-a-inject', {
      document_id: 'doc-a-inject',
      user_id: USER_A_ID,
      file_name: 'inject-doc.pdf'
    });

    // JWT auth returns User-A. Try to add document to User-B's case.
    const res = await request(app)
      .post('/v1/cases/case-b-target/documents')
      .set('Authorization', 'Bearer valid-token')
      .send({ documentId: 'doc-a-inject' });

    // Should fail — User-A doesn't own the case
    expect(res.status).toBe(500);

    // Verify document was NOT associated
    expect(mockDocCaseMap.has('doc-a-inject')).toBe(false);
  });
});
