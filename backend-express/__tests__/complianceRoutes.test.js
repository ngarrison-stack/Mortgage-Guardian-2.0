/**
 * Compliance API Route Integration Tests
 *
 * Tests all 4 compliance endpoints via supertest:
 *   POST /v1/cases/:caseId/compliance
 *   GET /v1/cases/:caseId/compliance
 *   GET /v1/compliance/statutes
 *   GET /v1/compliance/statutes/:statuteId
 *   GET /v1/compliance/states
 *   GET /v1/compliance/states/:stateCode/statutes
 *   GET /v1/compliance/states/:stateCode/statutes/:statuteId
 *
 * Mock strategy (consistent with 10-05, 13-06 patterns):
 *   - mockSupabaseClient for auth (Supabase JWT validation)
 *   - complianceService mocked (test HTTP layer, not full pipeline)
 *   - caseFileService mocked (Supabase persistence)
 *   - Joi validation schemas are real (not mocked)
 */

const mockClaudeService = require('./mocks/mockClaudeService');
const request = require('supertest');

// Mock @clerk/backend before any module loads it
const mockVerifyToken = jest.fn();
jest.mock('@clerk/backend', () => ({
  verifyToken: mockVerifyToken
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
process.env.CLERK_SECRET_KEY = 'test-clerk-secret';

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
  mockVerifyToken.mockReset();
  mockVerifyToken.mockResolvedValue({ sub: 'mock-user-id-12345' });
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

  it('returns 422 with error when analysis fails', async () => {
    mockComplianceService.evaluateCompliance.mockResolvedValue({
      error: true,
      errorMessage: 'Case has no forensic analysis. Run forensic analysis first.'
    });

    const res = await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(422);
    expect(res.body.error).toBe('ComplianceError');
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

// ============================================================
// GET /v1/compliance/states
// ============================================================
describe('GET /v1/compliance/states', () => {
  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .get('/v1/compliance/states');

    expect(res.status).toBe(401);
  });

  it('returns 200 with list of supported states', async () => {
    const res = await request(app)
      .get('/v1/compliance/states')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.states).toBeDefined();
    expect(Array.isArray(res.body.states)).toBe(true);
  });

  it('each state has stateCode, stateName, statuteCount', async () => {
    const res = await request(app)
      .get('/v1/compliance/states')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    const state = res.body.states[0];
    expect(state.stateCode).toBeDefined();
    expect(state.stateName).toBeDefined();
    expect(typeof state.statuteCount).toBe('number');
    expect(typeof state.sectionCount).toBe('number');
  });

  it('response includes all 6 priority states', async () => {
    const res = await request(app)
      .get('/v1/compliance/states')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.states.length).toBe(6);

    const codes = res.body.states.map(s => s.stateCode);
    expect(codes).toContain('CA');
    expect(codes).toContain('NY');
    expect(codes).toContain('TX');
    expect(codes).toContain('FL');
    expect(codes).toContain('IL');
    expect(codes).toContain('MA');
  });
});

// ============================================================
// GET /v1/compliance/states/:stateCode/statutes
// ============================================================
describe('GET /v1/compliance/states/:stateCode/statutes', () => {
  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .get('/v1/compliance/states/CA/statutes');

    expect(res.status).toBe(401);
  });

  it('returns 200 with statutes for valid state (CA)', async () => {
    const res = await request(app)
      .get('/v1/compliance/states/CA/statutes')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.stateCode).toBe('CA');
    expect(res.body.stateName).toBe('California');
    expect(Array.isArray(res.body.statutes)).toBe(true);
    expect(res.body.statutes.length).toBeGreaterThan(0);
  });

  it('returns 404 for unsupported state code', async () => {
    const res = await request(app)
      .get('/v1/compliance/states/ZZ/statutes')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
  });

  it('each statute has id, name, citation, enforcementBody, sectionCount', async () => {
    const res = await request(app)
      .get('/v1/compliance/states/CA/statutes')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    const statute = res.body.statutes[0];
    expect(statute.id).toBeDefined();
    expect(statute.name).toBeDefined();
    expect(statute.citation).toBeDefined();
    expect(statute.enforcementBody).toBeDefined();
    expect(typeof statute.sectionCount).toBe('number');
  });
});

// ============================================================
// GET /v1/compliance/states/:stateCode/statutes/:statuteId
// ============================================================
describe('GET /v1/compliance/states/:stateCode/statutes/:statuteId', () => {
  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .get('/v1/compliance/states/CA/statutes/ca_hbor');

    expect(res.status).toBe(401);
  });

  it('returns 200 with detailed statute for valid state + statute', async () => {
    const res = await request(app)
      .get('/v1/compliance/states/CA/statutes/ca_hbor')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.id).toBe('ca_hbor');
    expect(res.body.name).toMatch(/HBOR/);
    expect(res.body.sections).toBeDefined();
    expect(Array.isArray(res.body.sections)).toBe(true);
    expect(res.body.sections.length).toBeGreaterThan(0);
  });

  it('returns 404 for invalid state code', async () => {
    const res = await request(app)
      .get('/v1/compliance/states/ZZ/statutes/ca_hbor')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
    expect(res.body.message).toMatch(/ZZ/);
  });

  it('returns 404 for invalid statute ID within valid state', async () => {
    const res = await request(app)
      .get('/v1/compliance/states/CA/statutes/nonexistent_statute')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
    expect(res.body.message).toMatch(/nonexistent_statute/);
  });
});

// ============================================================
// POST /v1/cases/:caseId/compliance — state options
// ============================================================
describe('POST /v1/cases/:caseId/compliance (state options)', () => {
  it('passes state override option through to service', async () => {
    mockComplianceService.evaluateCompliance.mockResolvedValue(makeComplianceReport());

    await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({ state: 'CA' });

    expect(mockComplianceService.evaluateCompliance).toHaveBeenCalledWith(
      'case-001',
      'mock-user-id-12345',
      expect.objectContaining({ state: 'CA' })
    );
  });

  it('passes skipStateAnalysis option through to service', async () => {
    const report = makeComplianceReport({ stateViolations: [] });
    mockComplianceService.evaluateCompliance.mockResolvedValue(report);

    await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({ skipStateAnalysis: true });

    expect(mockComplianceService.evaluateCompliance).toHaveBeenCalledWith(
      'case-001',
      'mock-user-id-12345',
      expect.objectContaining({ skipStateAnalysis: true })
    );
  });

  it('passes stateStatuteFilter option through to service', async () => {
    mockComplianceService.evaluateCompliance.mockResolvedValue(makeComplianceReport());

    await request(app)
      .post('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token')
      .send({ stateStatuteFilter: ['ca_hbor', 'ca_rmla'] });

    expect(mockComplianceService.evaluateCompliance).toHaveBeenCalledWith(
      'case-001',
      'mock-user-id-12345',
      expect.objectContaining({ stateStatuteFilter: ['ca_hbor', 'ca_rmla'] })
    );
  });
});

// ============================================================
// GET /v1/cases/:caseId/compliance — state data in report
// ============================================================
describe('GET /v1/cases/:caseId/compliance (state data)', () => {
  it('report includes jurisdiction field when state analysis was run', async () => {
    const report = makeComplianceReport({
      jurisdiction: { state: 'CA', stateName: 'California', detectedFrom: 'property_address' }
    });
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      compliance_report: report
    });

    const res = await request(app)
      .get('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.complianceReport.jurisdiction).toBeDefined();
    expect(res.body.complianceReport.jurisdiction.state).toBe('CA');
  });

  it('report includes stateViolations array', async () => {
    const report = makeComplianceReport({
      stateViolations: [
        {
          id: 'sv-001',
          statuteId: 'ca_hbor',
          sectionId: 'ca_hbor_dual_tracking',
          severity: 'high',
          description: 'Dual tracking violation'
        }
      ],
      stateCompliance: {
        totalViolations: 1,
        overallStateComplianceRisk: 'high'
      }
    });
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      compliance_report: report
    });

    const res = await request(app)
      .get('/v1/cases/case-001/compliance')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.complianceReport.stateViolations).toBeDefined();
    expect(res.body.complianceReport.stateViolations).toHaveLength(1);
    expect(res.body.complianceReport.stateViolations[0].statuteId).toBe('ca_hbor');
  });
});
