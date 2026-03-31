/**
 * Consolidated Report API Integration Tests
 *
 * Tests all 3 report endpoints via supertest:
 *   POST /v1/cases/:caseId/report       — generate consolidated report
 *   GET  /v1/cases/:caseId/report       — retrieve latest report
 *   POST /v1/cases/:caseId/report/letter — generate dispute letter
 *
 * Mock strategy (consistent with complianceRoutes.test.js, forensic-analysis.test.js):
 *   - mockSupabaseClient for auth (Supabase JWT validation)
 *   - consolidatedReportService mocked (test HTTP layer, not full pipeline)
 *   - disputeLetterService mocked (test route logic, not AI calls)
 *   - caseFileService mocked (Supabase persistence)
 *   - Joi validation schemas are real (not mocked)
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

const mockConsolidatedReportService = {
  generateReport: jest.fn()
};
jest.mock('../../services/consolidatedReportService', () => mockConsolidatedReportService);

const mockDisputeLetterService = {
  generateDisputeLetter: jest.fn()
};
jest.mock('../../services/disputeLetterService', () => mockDisputeLetterService);

const mockComplianceService = {
  evaluateCompliance: jest.fn()
};
jest.mock('../../services/complianceService', () => mockComplianceService);

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
  const modulesToClear = [
    '../../server',
    '../../routes/claude',
    '../../routes/plaid',
    '../../routes/documents',
    '../../routes/cases',
    '../../routes/compliance',
    '../../routes/reports',
    '../../routes/health',
    '../../middleware/auth'
  ];

  for (const mod of modulesToClear) {
    try {
      delete require.cache[require.resolve(mod)];
    } catch {
      // Not cached yet
    }
  }

  app = require('../../server');
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
// Helper: build a mock consolidated report
// ============================================================
function makeConsolidatedReport(overrides = {}) {
  return {
    reportId: 'rpt-001',
    caseId: 'case-001',
    userId: 'mock-user-id-12345',
    generatedAt: '2026-03-13T01:00:00.000Z',
    reportVersion: '1.0',
    caseSummary: {
      borrowerName: 'Jane Doe',
      propertyAddress: '123 Main St',
      loanNumber: '12345',
      servicerName: 'Test Bank',
      documentCount: 3,
      caseCreatedAt: '2026-01-01T00:00:00.000Z'
    },
    overallRiskLevel: 'high',
    confidenceScore: 0.82,
    findingSummary: {
      totalFindings: 5,
      criticalCount: 1,
      highCount: 2,
      mediumCount: 1,
      lowCount: 1
    },
    documentAnalysis: [],
    forensicFindings: {
      discrepancies: [],
      timelineViolations: [],
      paymentVerification: null
    },
    complianceFindings: {
      federalViolations: [],
      stateViolations: [],
      jurisdiction: null
    },
    evidenceLinks: [],
    recommendations: [
      { priority: 1, category: 'payment_verification', action: 'Request payment history' }
    ],
    disputeLetterAvailable: false,
    disputeLetter: null,
    _metadata: {
      generationDurationMs: 150,
      stepsCompleted: ['gather', 'score', 'link', 'recommendations', 'assemble', 'validate'],
      warnings: []
    },
    ...overrides
  };
}

// ============================================================
// Helper: build a mock dispute letter
// ============================================================
function makeDisputeLetter(overrides = {}) {
  return {
    letterType: 'qualified_written_request',
    generatedAt: '2026-03-13T02:00:00.000Z',
    content: 'Dear Servicer,\n\nPursuant to RESPA Section 6...',
    recipientInfo: {
      servicerName: 'Test Bank',
      servicerAddress: '456 Bank Ave'
    },
    ...overrides
  };
}

// ============================================================
// POST /v1/cases/:caseId/report
// ============================================================
describe('POST /v1/cases/:caseId/report', () => {
  it('returns 200 with consolidated report on success', async () => {
    const report = makeConsolidatedReport();
    mockConsolidatedReportService.generateReport.mockResolvedValue(report);

    const res = await request(app)
      .post('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.report).toBeDefined();
    expect(res.body.report.reportId).toBe('rpt-001');
    expect(res.body.report.overallRiskLevel).toBe('high');
  });

  it('returns 200 with report including dispute letter when generateLetter: true', async () => {
    const letter = makeDisputeLetter();
    const report = makeConsolidatedReport({
      disputeLetterAvailable: true,
      disputeLetter: letter
    });
    mockConsolidatedReportService.generateReport.mockResolvedValue(report);

    const res = await request(app)
      .post('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token')
      .send({ generateLetter: true });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.report.disputeLetterAvailable).toBe(true);
    expect(res.body.report.disputeLetter).toBeDefined();
    expect(res.body.report.disputeLetter.letterType).toBe('qualified_written_request');
  });

  it('returns 422 with error when service returns error', async () => {
    mockConsolidatedReportService.generateReport.mockResolvedValue({
      error: true,
      errorMessage: 'Case has no analyzed documents. Run document analysis first.'
    });

    const res = await request(app)
      .post('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(422);
    expect(res.body.error).toBe('ReportError');
    expect(res.body.message).toMatch(/analyzed documents/);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/cases/case-001/report')
      .send({});

    expect(res.status).toBe(401);
  });

  it('returns 400 with invalid letterType', async () => {
    const res = await request(app)
      .post('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token')
      .send({ letterType: 'invalid_type' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('passes options through to service', async () => {
    mockConsolidatedReportService.generateReport.mockResolvedValue(makeConsolidatedReport());

    await request(app)
      .post('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token')
      .send({
        generateLetter: true,
        letterType: 'notice_of_error',
        skipPersistence: true
      });

    expect(mockConsolidatedReportService.generateReport).toHaveBeenCalledWith(
      'case-001',
      'mock-user-id-12345',
      expect.objectContaining({
        generateLetter: true,
        letterType: 'notice_of_error',
        skipPersistence: true
      })
    );
  });

  it('returns 500 on unexpected service error', async () => {
    mockConsolidatedReportService.generateReport.mockRejectedValue(new Error('Unexpected'));

    const res = await request(app)
      .post('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(500);
  });
});

// ============================================================
// GET /v1/cases/:caseId/report
// ============================================================
describe('GET /v1/cases/:caseId/report', () => {
  it('returns 200 with stored report when exists', async () => {
    const report = makeConsolidatedReport();
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      consolidated_report: report
    });

    const res = await request(app)
      .get('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.report).toBeDefined();
    expect(res.body.report.reportId).toBe('rpt-001');
  });

  it('returns 404 when case not found', async () => {
    mockCaseFileService.getCase.mockResolvedValue(null);

    const res = await request(app)
      .get('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
    expect(res.body.message).toMatch(/Case not found/);
  });

  it('returns 404 when no consolidated report exists', async () => {
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      consolidated_report: null
    });

    const res = await request(app)
      .get('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
    expect(res.body.message).toMatch(/No consolidated report/);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .get('/v1/cases/case-001/report');

    expect(res.status).toBe(401);
  });

  it('returns 500 on service error', async () => {
    mockCaseFileService.getCase.mockRejectedValue(new Error('DB error'));

    const res = await request(app)
      .get('/v1/cases/case-001/report')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(500);
  });
});

// ============================================================
// POST /v1/cases/:caseId/report/letter
// ============================================================
describe('POST /v1/cases/:caseId/report/letter', () => {
  it('returns 200 with generated letter on success', async () => {
    const report = makeConsolidatedReport();
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      consolidated_report: report
    });

    const letter = makeDisputeLetter();
    mockDisputeLetterService.generateDisputeLetter.mockResolvedValue(letter);

    const res = await request(app)
      .post('/v1/cases/case-001/report/letter')
      .set('Authorization', 'Bearer valid-token')
      .send({ letterType: 'qualified_written_request' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.letter).toBeDefined();
    expect(res.body.letter.letterType).toBe('qualified_written_request');
    expect(res.body.letter.content).toBeDefined();
  });

  it('returns 422 with error when letter generation fails', async () => {
    const report = makeConsolidatedReport();
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      consolidated_report: report
    });

    mockDisputeLetterService.generateDisputeLetter.mockResolvedValue({
      error: true,
      errorMessage: 'Anthropic API key not configured'
    });

    const res = await request(app)
      .post('/v1/cases/case-001/report/letter')
      .set('Authorization', 'Bearer valid-token')
      .send({ letterType: 'notice_of_error' });

    expect(res.status).toBe(422);
    expect(res.body.error).toBe('LetterError');
    expect(res.body.message).toMatch(/Anthropic/);
  });

  it('returns 404 when case not found', async () => {
    mockCaseFileService.getCase.mockResolvedValue(null);

    const res = await request(app)
      .post('/v1/cases/case-001/report/letter')
      .set('Authorization', 'Bearer valid-token')
      .send({ letterType: 'qualified_written_request' });

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
    expect(res.body.message).toMatch(/Case not found/);
  });

  it('returns 404 when no consolidated report exists', async () => {
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      consolidated_report: null
    });

    const res = await request(app)
      .post('/v1/cases/case-001/report/letter')
      .set('Authorization', 'Bearer valid-token')
      .send({ letterType: 'qualified_written_request' });

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
    expect(res.body.message).toMatch(/Generate a report first/);
  });

  it('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/v1/cases/case-001/report/letter')
      .send({ letterType: 'qualified_written_request' });

    expect(res.status).toBe(401);
  });

  it('returns 400 with missing letterType', async () => {
    const res = await request(app)
      .post('/v1/cases/case-001/report/letter')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('returns 400 with invalid letterType', async () => {
    const res = await request(app)
      .post('/v1/cases/case-001/report/letter')
      .set('Authorization', 'Bearer valid-token')
      .send({ letterType: 'cease_and_desist' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  it('passes correct letterType and report to service', async () => {
    const report = makeConsolidatedReport();
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      consolidated_report: report
    });
    mockDisputeLetterService.generateDisputeLetter.mockResolvedValue(makeDisputeLetter({
      letterType: 'request_for_information'
    }));

    await request(app)
      .post('/v1/cases/case-001/report/letter')
      .set('Authorization', 'Bearer valid-token')
      .send({ letterType: 'request_for_information' });

    expect(mockDisputeLetterService.generateDisputeLetter).toHaveBeenCalledWith(
      'request_for_information',
      report
    );
  });

  it('returns 500 on unexpected service error', async () => {
    const report = makeConsolidatedReport();
    mockCaseFileService.getCase.mockResolvedValue({
      id: 'case-001',
      consolidated_report: report
    });
    mockDisputeLetterService.generateDisputeLetter.mockRejectedValue(new Error('Unexpected'));

    const res = await request(app)
      .post('/v1/cases/case-001/report/letter')
      .set('Authorization', 'Bearer valid-token')
      .send({ letterType: 'qualified_written_request' });

    expect(res.status).toBe(500);
  });
});
