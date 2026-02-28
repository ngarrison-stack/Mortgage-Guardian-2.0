/**
 * Document Analysis Pipeline Integration Tests
 *
 * Verifies the analysis service integration through the pipeline and API:
 * 1. Pipeline calls documentAnalysisService with classification results
 * 2. GET /v1/documents/:documentId/analysis returns structured reports
 * 3. End-to-end flow: process -> analyze -> retrieve
 *
 * Mocks external boundaries only: Supabase, Anthropic SDK, pdf-parse.
 * Tests the real integration between pipeline, analysis service, and routes.
 */

// ============================================================
// MOCKS — set up before any module imports
// ============================================================

const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');
const mockClaudeService = require('../mocks/mockClaudeService');
const request = require('supertest');

const mockClient = createMockSupabaseClient();

// Mock @supabase/supabase-js before any module loads it
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Mock claudeService for pipeline backward-compat (import still exists)
jest.mock('../../services/claudeService', () => mockClaudeService);

// Mock Anthropic SDK (used by documentAnalysisService and classificationService)
const mockAnthropicCreate = jest.fn();
jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockAnthropicCreate }
  }));
});

// Mock pdf-parse (used by ocrService)
jest.mock('pdf-parse', () => {
  return jest.fn().mockResolvedValue({
    text: 'Mortgage statement for loan #12345. Monthly payment: $1,500.00. Interest rate: 4.5%. Borrower: Jane Doe.',
    numpages: 2,
    info: { Title: 'Mortgage Statement' }
  });
});

// Mock documentService for route-level tests
const mockDocumentService = {
  uploadDocument: jest.fn().mockResolvedValue({ documentId: 'doc-1', storagePath: 'mock/path' }),
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true }),
  getContentType: jest.fn().mockReturnValue('application/pdf')
};
jest.mock('../../services/documentService', () => mockDocumentService);

// Mock plaid services to prevent initialization errors
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
// TEST FIXTURES
// ============================================================

/** Sample structured analysis report matching analysisReportSchema */
const MOCK_ANALYSIS_REPORT = {
  extractedData: {
    dates: { statementDate: '2024-01-15', paymentDueDate: '2024-02-01' },
    amounts: { principalBalance: 245000, monthlyPayment: 1500 },
    rates: { interestRate: 4.5 },
    parties: { borrower: 'Jane Doe', servicer: 'Test Bank' },
    identifiers: { loanNumber: '12345' },
    terms: {},
    custom: {}
  },
  anomalies: [
    {
      field: 'monthlyPayment',
      type: 'unusual_value',
      severity: 'medium',
      description: 'Monthly payment appears lower than expected for current balance and rate',
      expectedValue: '$1,575.00',
      actualValue: '$1,500.00'
    }
  ],
  summary: {
    overview: 'Monthly mortgage statement with one potential payment discrepancy identified.',
    keyFindings: ['Payment amount may not match current amortization schedule'],
    riskLevel: 'medium',
    recommendations: ['Request payment amortization schedule from servicer']
  }
};

/** Classification response for Anthropic mock */
const MOCK_CLASSIFICATION_RESPONSE = {
  content: [{
    text: JSON.stringify({
      classificationType: 'servicing',
      classificationSubtype: 'monthly_statement',
      confidence: 0.92,
      keyMetadata: {
        dates: ['2024-01-15'],
        amounts: ['$1,500.00'],
        parties: ['Test Bank'],
        accountNumbers: ['12345']
      },
      summary: 'Monthly mortgage servicing statement'
    })
  }],
  model: 'claude-sonnet-4-5-20250514',
  usage: { input_tokens: 500, output_tokens: 200 },
  stop_reason: 'end_turn'
};

/** Analysis response for Anthropic mock (returned by documentAnalysisService via SDK) */
const MOCK_ANALYSIS_RESPONSE = {
  content: [{
    text: JSON.stringify(MOCK_ANALYSIS_REPORT)
  }],
  model: 'claude-sonnet-4-5-20250514',
  usage: { input_tokens: 1200, output_tokens: 600 },
  stop_reason: 'end_turn'
};

/**
 * Helper: set up Anthropic mock to return classification then analysis responses.
 */
function setupAnthropicMocks(overrides = {}) {
  const classificationResp = overrides.classification || MOCK_CLASSIFICATION_RESPONSE;
  const analysisResp = overrides.analysis || MOCK_ANALYSIS_RESPONSE;

  mockAnthropicCreate.mockReset();
  mockAnthropicCreate
    .mockResolvedValueOnce(classificationResp)
    .mockResolvedValueOnce(analysisResp);
}

// ============================================================
// SETUP
// ============================================================

// Set env vars so modules initialize properly
process.env.SUPABASE_URL = 'https://mock.supabase.co';
process.env.SUPABASE_ANON_KEY = 'mock-anon-key';
process.env.ANTHROPIC_API_KEY = 'test-key';
process.env.NODE_ENV = 'production';
process.env.VERCEL = '1';

let app;
let documentPipeline;

beforeAll(() => {
  // Clear cached modules so mocks take effect
  const modulesToClear = [
    '../../server',
    '../../routes/claude',
    '../../routes/plaid',
    '../../routes/documents',
    '../../routes/cases',
    '../../routes/health',
    '../../middleware/auth',
    '../../services/documentPipelineService',
    '../../services/classificationService',
    '../../services/documentAnalysisService',
    '../../services/ocrService',
    '../../services/caseFileService'
  ];

  for (const mod of modulesToClear) {
    try {
      delete require.cache[require.resolve(mod)];
    } catch {
      // Not cached yet
    }
  }

  app = require('../../server');
  documentPipeline = require('../../services/documentPipelineService');
  process.env.NODE_ENV = 'test';
});

afterAll(() => {
  delete process.env.VERCEL;
  delete process.env.ANTHROPIC_API_KEY;
});

beforeEach(() => {
  mockClient.reset();
  mockClaudeService.reset();
  mockAnthropicCreate.mockReset();
  jest.clearAllMocks();
  // Clear pipeline state between tests
  documentPipeline.pipelineState.clear();
  // Restore default mock implementations
  mockDocumentService.getDocumentsByUser.mockResolvedValue([]);
  mockDocumentService.getDocument.mockResolvedValue(null);
  mockDocumentService.deleteDocument.mockResolvedValue({ success: true });
});

// ============================================================
// 1. PIPELINE ANALYSIS INTEGRATION
// ============================================================
describe('Pipeline Analysis Integration', () => {

  test('pipeline processDocument triggers analysis with classification results', async () => {
    setupAnthropicMocks();

    const docId = 'doc-analysis-001';
    const userId = 'user-1';

    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Mortgage statement for loan #12345. Monthly payment: $1,500.00.',
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);
    expect(result.status).toBe('review');

    // Verify analysis results contain the structured report
    expect(result.analysisResults).toBeDefined();
    expect(result.analysisResults.documentInfo).toBeDefined();
    expect(result.analysisResults.documentInfo.documentType).toBe('servicing');
    expect(result.analysisResults.documentInfo.documentSubtype).toBe('monthly_statement');
    expect(result.analysisResults.extractedData).toBeDefined();
    expect(result.analysisResults.anomalies).toBeDefined();
    expect(result.analysisResults.completeness).toBeDefined();
    expect(result.analysisResults.summary).toBeDefined();

    // Verify Anthropic was called twice: classification + analysis
    expect(mockAnthropicCreate).toHaveBeenCalledTimes(2);
  });

  test('pipeline passes classification results to analysis service', async () => {
    setupAnthropicMocks();

    const docId = 'doc-analysis-002';
    const userId = 'user-1';

    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Monthly mortgage statement content.',
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);

    // Verify classification was performed first
    expect(result.classificationResults).toBeDefined();
    expect(result.classificationResults.classificationType).toBe('servicing');

    // The analysis call (second Anthropic call) should reference the document type
    const analysisCall = mockAnthropicCreate.mock.calls[1];
    expect(analysisCall).toBeDefined();
    const analysisPrompt = analysisCall[0].messages[0].content;
    expect(analysisPrompt).toContain('monthly_statement');
    expect(analysisPrompt).toContain('servicing');
  });

  test('pipeline handles analysis service error without crashing', async () => {
    // Classification succeeds, analysis API call fails
    // The documentAnalysisService catches API errors internally and returns
    // an error object { error: true, errorMessage: ... } instead of throwing.
    // The pipeline stores this as analysisResults and continues.
    mockAnthropicCreate
      .mockResolvedValueOnce(MOCK_CLASSIFICATION_RESPONSE)
      .mockRejectedValueOnce(new Error('Claude API rate limit exceeded'));

    const docId = 'doc-analysis-error';
    const userId = 'user-1';

    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Mortgage statement for error testing.',
      documentType: 'unknown'
    });

    // Pipeline succeeds because analysis service catches errors gracefully
    expect(result.success).toBe(true);
    expect(result.status).toBe('review');

    // Analysis results contain the error information
    expect(result.analysisResults).toBeDefined();
    expect(result.analysisResults.error).toBe(true);
    expect(result.analysisResults.errorMessage).toContain('rate limit');
  });

  test('pipeline stores analysis results with structured report format', async () => {
    setupAnthropicMocks();

    const docId = 'doc-analysis-stored';
    const userId = 'user-1';

    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Monthly mortgage statement for storage test.',
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);

    // Verify the pipeline state contains the analysis results
    const pipeline = documentPipeline.pipelineState.get(docId);
    expect(pipeline).toBeDefined();
    expect(pipeline.analysisResults).toBeDefined();
    expect(pipeline.analysisResults.summary).toBeDefined();
    expect(pipeline.analysisResults.summary.riskLevel).toBe('medium');
    expect(pipeline.analysisResults.anomalies).toHaveLength(1);
  });

  test('pipeline skips analysis when OCR fails (no extracted text)', async () => {
    const docId = 'doc-no-text';
    const userId = 'user-1';

    // Provide neither documentText nor fileBuffer -- should fail at OCR
    const result = await documentPipeline.processDocument(docId, userId, {
      documentType: 'unknown'
    });

    // Pipeline should fail at OCR step, never reaching analysis
    expect(result.success).toBe(false);
    expect(result.status).toBe('failed');

    // Analysis service should not have been called
    expect(mockAnthropicCreate).not.toHaveBeenCalled();
  });
});

// ============================================================
// 2. GET /v1/documents/:documentId/analysis
// ============================================================
describe('GET /v1/documents/:documentId/analysis', () => {

  test('returns analysis report for analyzed document', async () => {
    const analysisResults = {
      documentInfo: { documentType: 'servicing', documentSubtype: 'monthly_statement' },
      extractedData: { amounts: { principalBalance: 245000 } },
      anomalies: [],
      completeness: { score: 85, presentFields: [], missingFields: [], missingCritical: [], totalExpectedFields: 10 },
      summary: { overview: 'Clean document', keyFindings: [], riskLevel: 'low', recommendations: [] }
    };

    mockDocumentService.getDocument.mockResolvedValue({
      document_id: 'doc-123',
      user_id: 'mock-user-id-12345',
      analysis_results: analysisResults
    });

    const res = await request(app)
      .get('/v1/documents/doc-123/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.documentId).toBe('doc-123');
    expect(res.body.status).toBe('complete');
    expect(res.body.analysis).toBeDefined();
    expect(res.body.analysis.summary.riskLevel).toBe('low');
  });

  test('returns 404 when document not found', async () => {
    mockDocumentService.getDocument.mockResolvedValue(null);

    const res = await request(app)
      .get('/v1/documents/nonexistent/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Document not found');
  });

  test('returns 404 when document has no analysis', async () => {
    mockDocumentService.getDocument.mockResolvedValue({
      document_id: 'doc-no-analysis',
      user_id: 'mock-user-id-12345',
      analysis_results: null
    });

    const res = await request(app)
      .get('/v1/documents/doc-no-analysis/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Analysis not available');
    expect(res.body.message).toContain('not been analyzed yet');
  });

  test('returns error status when analysis failed', async () => {
    mockDocumentService.getDocument.mockResolvedValue({
      document_id: 'doc-failed-analysis',
      user_id: 'mock-user-id-12345',
      analysis_results: {
        error: true,
        errorMessage: 'Claude API timeout during analysis',
        rawResponse: null
      }
    });

    const res = await request(app)
      .get('/v1/documents/doc-failed-analysis/analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('error');
    expect(res.body.error).toBe('Claude API timeout during analysis');
    expect(res.body.documentId).toBe('doc-failed-analysis');
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app)
      .get('/v1/documents/doc-123/analysis');

    expect(res.status).toBe(401);
  });

  test('respects user isolation via documentService.getDocument', async () => {
    mockDocumentService.getDocument.mockResolvedValue({
      document_id: 'doc-isolated',
      user_id: 'mock-user-id-12345',
      analysis_results: { summary: { riskLevel: 'low' } }
    });

    await request(app)
      .get('/v1/documents/doc-isolated/analysis')
      .set('Authorization', 'Bearer valid-token');

    // Verify getDocument was called with userId from JWT (mock-user-id-12345)
    expect(mockDocumentService.getDocument).toHaveBeenCalledWith({
      documentId: 'doc-isolated',
      userId: 'mock-user-id-12345'
    });
  });
});

// ============================================================
// 3. END-TO-END ANALYSIS FLOW
// ============================================================
describe('End-to-End Analysis Flow', () => {

  test('complete flow: process through pipeline then retrieve via API', async () => {
    setupAnthropicMocks();

    const docId = 'doc-e2e-001';
    const userId = 'mock-user-id-12345';

    // Step 1: Process document through pipeline
    const pipelineResult = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Mortgage statement for loan #12345. Monthly payment: $1,500.00. Interest rate: 4.5%.',
      documentType: 'unknown'
    });

    expect(pipelineResult.success).toBe(true);
    expect(pipelineResult.analysisResults).toBeDefined();

    // Step 2: Mock documentService to return the pipeline's analysis results
    mockDocumentService.getDocument.mockResolvedValue({
      document_id: docId,
      user_id: userId,
      analysis_results: pipelineResult.analysisResults
    });

    // Step 3: Retrieve analysis via API
    const res = await request(app)
      .get(`/v1/documents/${docId}/analysis`)
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.documentId).toBe(docId);
    expect(res.body.status).toBe('complete');
    expect(res.body.analysis).toBeDefined();

    // Verify the report structure matches what the pipeline produced
    expect(res.body.analysis.documentInfo).toBeDefined();
    expect(res.body.analysis.documentInfo.documentType).toBe('servicing');
    expect(res.body.analysis.documentInfo.documentSubtype).toBe('monthly_statement');
  });

  test('analysis report includes completeness score with present and missing fields', async () => {
    setupAnthropicMocks();

    const docId = 'doc-e2e-completeness';
    const userId = 'mock-user-id-12345';

    const pipelineResult = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Mortgage statement for completeness test.',
      documentType: 'unknown'
    });

    expect(pipelineResult.success).toBe(true);

    // Verify completeness scoring was applied
    const completeness = pipelineResult.analysisResults.completeness;
    expect(completeness).toBeDefined();
    expect(typeof completeness.score).toBe('number');
    expect(completeness.score).toBeGreaterThanOrEqual(0);
    expect(completeness.score).toBeLessThanOrEqual(100);
    expect(Array.isArray(completeness.presentFields)).toBe(true);
    expect(Array.isArray(completeness.missingFields)).toBe(true);
    expect(typeof completeness.totalExpectedFields).toBe('number');
  });

  test('analysis report includes anomalies with severity categorization', async () => {
    setupAnthropicMocks();

    const docId = 'doc-e2e-anomalies';
    const userId = 'mock-user-id-12345';

    const pipelineResult = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Mortgage statement for anomaly test.',
      documentType: 'unknown'
    });

    expect(pipelineResult.success).toBe(true);

    // Verify anomalies are present and properly structured
    const anomalies = pipelineResult.analysisResults.anomalies;
    expect(Array.isArray(anomalies)).toBe(true);
    expect(anomalies.length).toBeGreaterThan(0);

    // Each anomaly should have required fields
    for (const anomaly of anomalies) {
      expect(anomaly.field).toBeDefined();
      expect(anomaly.type).toBeDefined();
      expect(anomaly.severity).toBeDefined();
      expect(anomaly.description).toBeDefined();
      expect(['critical', 'high', 'medium', 'low', 'info']).toContain(anomaly.severity);
    }
  });
});
