/**
 * Compliance API Route Integration Tests
 *
 * Tests all 4 compliance endpoints via supertest:
 *   POST /v1/cases/:caseId/compliance
 *   GET /v1/cases/:caseId/compliance
 *   GET /v1/compliance/statutes
 *   GET /v1/compliance/statutes/:statuteId
 *
 * Mock strategy (consistent with 10-05, 13-06 patterns):
 *   - mockSupabaseClient for auth (Supabase JWT validation)
 *   - complianceService mocked (test HTTP layer, not full pipeline)
 *   - caseFileService mocked (Supabase persistence)
 *   - Joi validation schemas are real (not mocked)
 */

const { createMockSupabaseClient } = require('./mocks/mockSupabaseClient');
const mockClaudeService = require('./mocks/mockClaudeService');
const request = require('supertest');

const mockClient = createMockSupabaseClient();

// Mock @supabase/supabase-js before any module loads it
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Mock service modules to prevent real API calls
jest.mock('../services/claudeService', () => mockClaudeService);

const mockDocumentService = {
  uploadDocument: jest.fn().mockResolvedValue({ documentId: 'doc-1', storagePath: 'mock/path' }),
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true }),
  getContentType: jest.fn().mockReturnValue('application/pdf')
};
jest.mock('../services/documentService', () => mockDocumentService);

const mockCaseFileService = {
  createCase: jest.fn(),
  getCasesByUser: jest.fn(),
  getCase: jest.fn(),
  updateCase: jest.fn(),
  deleteCase: jest.fn(),
  addDocumentToCase: jest.fn(),
  removeDocumentFromCase: jest.fn()
};
jest.mock('../services/caseFileService', () => mockCaseFileService);

const mockComplianceService = {
  evaluateCompliance: jest.fn()
};
jest.mock('../services/complianceService', () => mockComplianceService);

jest.mock('../services/plaidService', () => ({
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

jest.mock('../services/plaidDataService', () => ({
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
  const serverPath = require.resolve('../server');
  const routePaths = [
    require.resolve('../routes/claude'),
    require.resolve('../routes/plaid'),
    require.resolve('../routes/documents'),
    require.resolve('../routes/cases'),
    require.resolve('../routes/compliance'),
    require.resolve('../routes/health')
  ];
  delete require.cache[serverPath];
  for (const routePath of routePaths) {
    delete require.cache[routePath];
  }
  const authPath = require.resolve('../middleware/auth');
  delete require.cache[authPath];

  app = require('../server');
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
// Helper: build a mock compliance report
// ============================================================
function makeComplianceReport(overrides = {}) {
  return {
    caseId: 'case-001',
    analyzedAt: '2026-03-09T12:00:00.000Z',
    statutesEvaluated: ['respa', 'tila'],
    violations: [
      {
        id: 'viol-001',
        statuteId: 'respa',
        sectionId: 'respa_s10',
        severity: 'high',
        description: 'Escrow account violation detected.'
      }
    ],
    complianceSummary: {
      totalViolations: 1,
      criticalViolations: 0,
      highViolations: 1,
      overallComplianceRisk: 'high',
      statutesViolated: ['respa'],
      keyFindings: ['Escrow account violation detected.'],
      recommendations: ['Review escrow accounting procedures']
    },
    _metadata: {
      duration: 150,
      steps: {},
      warnings: []
    },
    ...overrides
  };
}

// ============================================================
// POST /v1/cases/:caseId/compliance
// ============================================================
describe('POST /v1/cases/:caseId/compliance', () => {
  it('returns 200 with compliance report on success', async () => {
    const report = makeComplianceReport();
    mockComplianceService.evaluateCompliance.mockResolvedValue(report);

    const res = await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.caseId).toBe('case-001');
    expect(res.body.status).toBe('completed');
    expect(res.body.complianceReport).toBeDefined();
    expect(res.body.complianceReport.violations).toHaveLength(1);
  });

  it('returns 200 with status error when analysis fails', async () => {
    mockComplianceService.evaluateCompliance.mockResolvedValue({
      error: true,
      errorMessage: 'Case has no forensic analysis. Run forensic analysis first.'
    });

    const res = await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toMatch(/forensic analysis/);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/cases/case-001/compliance')
      .send({});

    expect(res.status).toBe(401);
  });

  it('returns 400 with invalid statuteFilter values', async () => {
    const res = await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({ statuteFilter: ['invalid_statute'] });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('passes skipAiAnalysis option through to service', async () => {
    mockComplianceService.evaluateCompliance.mockResolvedValue(makeComplianceReport());

    await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({ skipAiAnalysis: true });

    expect(mockComplianceService.evaluateCompliance).toHaveBeenCalledWith(
      'case-001',
      'mock-user-id-12345',
      expect.objectContaining({ skipAiAnalysis: true })
    );
  });

  it('passes statuteFilter option through to service', async () => {
    mockComplianceService.evaluateCompliance.mockResolvedValue(makeComplianceReport());

    await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({ statuteFilter: ['respa', 'tila'] });

    expect(mockComplianceService.evaluateCompliance).toHaveBeenCalledWith(
      'case-001',
      'mock-user-id-12345',
      expect.objectContaining({ statuteFilter: ['respa', 'tila'] })
    );
  });

  it('uses req.user.id for userId, not request body', async () => {
    mockComplianceService.evaluateCompliance.mockResolvedValue(makeComplianceReport());

    await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({ userId: 'attacker-user-id' });

    expect(mockComplianceService.evaluateCompliance).toHaveBeenCalledWith(
      'case-001',
      'mock-user-id-12345',
      expect.any(Object)
    );
  });

  it('returns 500 on unexpected service error', async () => {
    mockComplianceService.evaluateCompliance.mockRejectedValue(new Error('Unexpected'));

    const res = await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(500);
  });
});

// ============================================================
// GET /v1/cases/:caseId/compliance
// ============================================================
describe('GET /v1/cases/:caseId/compliance', () => {
  it('returns 200 with stored report when exists', async () => {
    const report = makeComplianceReport();
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      compliance_report: report
    });

    const res = await request(app)
      .get('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.caseId).toBe('case-001');
    expect(res.body.status).toBe('completed');
    expect(res.body.complianceReport).toBeDefined();
  });

  it('returns 404 when case not found', async () => {
    mockCaseFileService.getCase.mockResolvedValue(null);

    const res = await request(app)
      .get('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
  });

  it('returns 404 when no compliance report exists', async () => {
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      compliance_report: null
    });

    const res = await request(app)
      .get('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.message).toMatch(/No compliance report/);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .get('/v1/cases/case-001/compliance');

    expect(res.status).toBe(401);
  });

  it('returns 500 on service error', async () => {
    mockCaseFileService.getCase.mockRejectedValue(new Error('DB error'));

    const res = await request(app)
      .get('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(500);
  });
});

// ============================================================
// GET /v1/compliance/statutes
// ============================================================
describe('GET /v1/compliance/statutes', () => {
  it('returns 200 with statute list', async () => {
    const res = await request(app)
      .get('/v1/compliance/statutes')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.statutes).toBeDefined();
    expect(Array.isArray(res.body.statutes)).toBe(true);
  });

  it('response includes all 7 statutes', async () => {
    const res = await request(app)
      .get('/v1/compliance/statutes')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    // 7 statutes: respa, tila, ecoa, fdcpa, scra, hmda, cfpb_reg_x
    expect(res.body.statutes.length).toBe(7);

    const ids = res.body.statutes.map(s => s.id);
    expect(ids).toContain('respa');
    expect(ids).toContain('tila');
    expect(ids).toContain('ecoa');
    expect(ids).toContain('fdcpa');
    expect(ids).toContain('scra');
    expect(ids).toContain('hmda');
    expect(ids).toContain('cfpb_reg_x');
  });

  it('filters statutes by category query parameter', async () => {
    const res = await request(app)
      .get('/v1/compliance/statutes')
      .set('Authorization', 'Bearer valid-token')
      .query({ category: 'DOJ' });

    expect(res.status).toBe(200);
    // Only SCRA has DOJ as regulatory body
    expect(res.body.statutes.length).toBe(1);
    expect(res.body.statutes[0].id).toBe('scra');
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .get('/v1/compliance/statutes');

    expect(res.status).toBe(401);
  });
});

// ============================================================
// GET /v1/compliance/statutes/:statuteId
// ============================================================
describe('GET /v1/compliance/statutes/:statuteId', () => {
  it('returns 200 with statute details for valid ID', async () => {
    const res = await request(app)
      .get('/v1/compliance/statutes/respa')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.id).toBe('respa');
    expect(res.body.name).toMatch(/RESPA/);
    expect(res.body.sections).toBeDefined();
    expect(Array.isArray(res.body.sections)).toBe(true);
    expect(res.body.sections.length).toBeGreaterThan(0);
  });

  it('returns 404 for invalid statute ID', async () => {
    const res = await request(app)
      .get('/v1/compliance/statutes/nonexistent')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
    expect(res.body.message).toMatch(/nonexistent/);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .get('/v1/compliance/statutes/respa');

    expect(res.status).toBe(401);
  });

  it('returns full section details including violation patterns', async () => {
    const res = await request(app)
      .get('/v1/compliance/statutes/tila')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.id).toBe('tila');
    expect(res.body.citation).toBeDefined();
    expect(res.body.regulatoryBody).toBe('CFPB');

    const section = res.body.sections[0];
    expect(section.id).toBeDefined();
    expect(section.title).toBeDefined();
    expect(section.requirements).toBeDefined();
    expect(section.violationPatterns).toBeDefined();
    expect(section.penalties).toBeDefined();
  });
});
