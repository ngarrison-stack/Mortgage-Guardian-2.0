/**
 * Plaid / Supabase Boundary Failure Tests
 *
 * Validates graceful degradation at every data service boundary:
 *   - Plaid: token expiry, empty transactions, API timeout
 *   - Supabase: write failures, read failures, null case queries
 *   - Compound: multiple boundaries failing simultaneously
 *
 * Every test verifies error objects in the response — no test validates by
 * catching thrown exceptions.
 *
 * Constraining decisions:
 *   - Phase 10-04: Pipeline never blocks on Supabase write failures
 *   - Phase 13-05: Per-step error objects instead of throws
 *   - Phase 16-05: Step 1 (GATHER) failure returns error; all other steps degrade gracefully
 */

// ============================================================
// MOCKS — hoisted before any module imports
// ============================================================

const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');
const { createMockPipelineContext, setupPipelineMocks } = require('../mocks/mockPipelineServices');

const mockClient = createMockSupabaseClient();

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Anthropic SDK
const mockAnthropicCreate = jest.fn();
jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockAnthropicCreate }
  }));
});

// pdf-parse
jest.mock('pdf-parse', () => {
  return jest.fn().mockResolvedValue({
    text: 'Mock PDF text',
    numpages: 1,
    info: { Title: 'Mock' }
  });
});

// Claude service (legacy import in pipeline)
const mockClaudeService = require('../mocks/mockClaudeService');
jest.mock('../../services/claudeService', () => mockClaudeService);

// Document service
jest.mock('../../services/documentService', () => ({
  uploadDocument: jest.fn().mockResolvedValue({ documentId: 'doc-1', storagePath: 'mock/path' }),
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true }),
  getContentType: jest.fn().mockReturnValue('application/pdf')
}));

// Plaid services
const mockPlaidService = {
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
};
jest.mock('../../services/plaidService', () => mockPlaidService);

jest.mock('../../services/plaidDataService', () => ({
  upsertPlaidItem: jest.fn().mockResolvedValue({ success: true }),
  getItem: jest.fn().mockResolvedValue({ success: true, data: { access_token: 'mock', user_id: 'mock' } }),
  storeTransactions: jest.fn().mockResolvedValue({ success: true }),
  upsertAccounts: jest.fn().mockResolvedValue({ success: true }),
  createNotification: jest.fn().mockResolvedValue({ success: true }),
  removeTransactions: jest.fn().mockResolvedValue({ success: true }),
  updateItemStatus: jest.fn().mockResolvedValue({ success: true })
}));

// -- Forensic orchestrator dependencies --
const mockCrossDocAggregation = {
  aggregateForCase: jest.fn()
};
jest.mock('../../services/crossDocumentAggregationService', () => mockCrossDocAggregation);

const mockCrossDocComparison = {
  compareDocumentPair: jest.fn()
};
jest.mock('../../services/crossDocumentComparisonService', () => mockCrossDocComparison);

const mockPlaidCrossRef = {
  extractPaymentsFromAnalysis: jest.fn().mockReturnValue([]),
  crossReferencePayments: jest.fn().mockReturnValue({
    matchedPayments: [], unmatchedDocumentPayments: [], unmatchedTransactions: [],
    summary: { totalDocumentPayments: 0, totalPlaidTransactions: 0, matched: 0, paymentVerified: true }
  })
};
jest.mock('../../services/plaidCrossReferenceService', () => mockPlaidCrossRef);

// -- Compliance orchestrator dependencies --
const mockComplianceRuleEngine = {
  evaluateFindings: jest.fn(),
  evaluateStateFindings: jest.fn()
};
jest.mock('../../services/complianceRuleEngine', () => mockComplianceRuleEngine);

const mockComplianceAnalysis = {
  analyzeViolations: jest.fn(),
  analyzeStateViolations: jest.fn()
};
jest.mock('../../services/complianceAnalysisService', () => mockComplianceAnalysis);

const mockJurisdictionService = jest.fn();
jest.mock('../../services/jurisdictionService', () => mockJurisdictionService);

const mockCaseFileService = {
  getCase: jest.fn(),
  getCasesByUser: jest.fn(),
  createCase: jest.fn(),
  updateCase: jest.fn(),
  addDocumentToCase: jest.fn()
};
jest.mock('../../services/caseFileService', () => mockCaseFileService);

// -- Consolidated report orchestrator dependencies --
const mockReportAggregation = {
  gatherCaseFindings: jest.fn(),
  extractFindingSummary: jest.fn()
};
jest.mock('../../services/reportAggregationService', () => mockReportAggregation);

const mockConfidenceScoring = {
  calculateConfidence: jest.fn(),
  determineRiskLevel: jest.fn(),
  buildEvidenceLinks: jest.fn()
};
jest.mock('../../services/confidenceScoringService', () => mockConfidenceScoring);

const mockDisputeLetter = {
  generateDisputeLetter: jest.fn()
};
jest.mock('../../services/disputeLetterService', () => mockDisputeLetter);

// ============================================================
// SETUP
// ============================================================

process.env.SUPABASE_URL = 'https://mock.supabase.co';
process.env.SUPABASE_ANON_KEY = 'mock-anon-key';
process.env.SUPABASE_SERVICE_KEY = 'mock-service-key';
process.env.ANTHROPIC_API_KEY = 'test-key';
process.env.NODE_ENV = 'test';

let documentPipeline;
let forensicAnalysisService;
let complianceService;
let consolidatedReportService;

beforeAll(() => {
  const modulesToClear = [
    '../../services/documentPipelineService',
    '../../services/classificationService',
    '../../services/documentAnalysisService',
    '../../services/ocrService',
    '../../services/forensicAnalysisService',
    '../../services/complianceService',
    '../../services/consolidatedReportService'
  ];

  for (const mod of modulesToClear) {
    try { delete require.cache[require.resolve(mod)]; } catch { /* not cached */ }
  }

  documentPipeline = require('../../services/documentPipelineService');
  forensicAnalysisService = require('../../services/forensicAnalysisService');
  complianceService = require('../../services/complianceService');
  consolidatedReportService = require('../../services/consolidatedReportService');
});

afterAll(() => {
  delete process.env.SUPABASE_SERVICE_KEY;
  delete process.env.ANTHROPIC_API_KEY;
});

let ctx;

beforeEach(() => {
  ctx = createMockPipelineContext();

  setupPipelineMocks(ctx, {
    mockAnthropicCreate,
    mockSupabaseClient: mockClient,
    caseFileService: mockCaseFileService,
    crossDocAggregation: mockCrossDocAggregation,
    crossDocComparison: mockCrossDocComparison,
    plaidCrossRef: mockPlaidCrossRef,
    complianceRuleEngine: mockComplianceRuleEngine,
    complianceAnalysis: mockComplianceAnalysis,
    jurisdictionService: mockJurisdictionService,
    reportAggregation: mockReportAggregation,
    confidenceScoring: mockConfidenceScoring,
    disputeLetter: mockDisputeLetter
  });

  mockClaudeService.reset();
  jest.clearAllMocks();

  // Re-apply mocks after clearAllMocks
  setupPipelineMocks(ctx, {
    mockAnthropicCreate,
    mockSupabaseClient: mockClient,
    caseFileService: mockCaseFileService,
    crossDocAggregation: mockCrossDocAggregation,
    crossDocComparison: mockCrossDocComparison,
    plaidCrossRef: mockPlaidCrossRef,
    complianceRuleEngine: mockComplianceRuleEngine,
    complianceAnalysis: mockComplianceAnalysis,
    jurisdictionService: mockJurisdictionService,
    reportAggregation: mockReportAggregation,
    confidenceScoring: mockConfidenceScoring,
    disputeLetter: mockDisputeLetter
  });

  documentPipeline.pipelineState.clear();
});

// ============================================================
// PLAID FAILURES
// ============================================================
describe('Plaid boundary failures', () => {

  test('Plaid access token expired — forensic analysis skips Plaid step, returns results without payment verification', async () => {
    // Set up aggregation for forensic step
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing', analysisReport: ctx.analysisResults[ctx.docIdA] },
        { documentId: ctx.docIdB, documentType: 'origination', analysisReport: ctx.analysisResults[ctx.docIdB] }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: ['interestRate'], discrepancyTypes: ['amount_mismatch'], forensicSignificance: 'high' }
      ],
      documentsWithoutAnalysis: [],
      totalDocuments: 2,
      analyzedDocuments: 2
    });

    mockCrossDocComparison.compareDocumentPair.mockResolvedValue({
      pairId: 'pair-001',
      discrepancies: ctx.forensicResults.discrepancies,
      timelineEvents: ctx.forensicResults.timeline.events,
      timelineViolations: []
    });

    // Plaid getTransactions fails with token expired error
    mockPlaidService.getTransactions.mockRejectedValue(
      new Error('ITEM_LOGIN_REQUIRED: Access token has expired')
    );

    const result = await forensicAnalysisService.analyzeCaseForensics(
      ctx.caseId, ctx.userId,
      { plaidAccessToken: 'expired-token-123' }
    );

    // Should NOT error — graceful degradation, Plaid step skipped
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // Document-based results should be present
    expect(result.discrepancies.length).toBeGreaterThan(0);

    // Payment verification should be null (skipped)
    expect(result.paymentVerification).toBeNull();

    // Metadata should record Plaid failure
    expect(result._metadata.steps.plaidCrossReference.status).toBe('failed');
    expect(result._metadata.warnings.some(w => w.includes('Plaid cross-reference failed'))).toBe(true);
  });

  test('Plaid returns empty transactions — payment matching returns zero matches, not error', async () => {
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing', analysisReport: ctx.analysisResults[ctx.docIdA] },
        { documentId: ctx.docIdB, documentType: 'origination', analysisReport: ctx.analysisResults[ctx.docIdB] }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: [], discrepancyTypes: [], forensicSignificance: 'high' }
      ],
      documentsWithoutAnalysis: [],
      totalDocuments: 2,
      analyzedDocuments: 2
    });

    mockCrossDocComparison.compareDocumentPair.mockResolvedValue({
      pairId: 'pair-001',
      discrepancies: [],
      timelineEvents: [],
      timelineViolations: []
    });

    // Plaid returns empty transactions (valid response, just no data)
    mockPlaidService.getTransactions.mockResolvedValue({
      transactions: [],
      total_transactions: 0,
      accounts: [],
      request_id: 'req-empty'
    });

    // Cross-reference returns zero matches
    mockPlaidCrossRef.extractPaymentsFromAnalysis.mockReturnValue([]);
    mockPlaidCrossRef.crossReferencePayments.mockReturnValue({
      matchedPayments: [],
      unmatchedDocumentPayments: [],
      unmatchedTransactions: [],
      summary: { totalDocumentPayments: 0, totalPlaidTransactions: 0, matched: 0, paymentVerified: true }
    });

    const result = await forensicAnalysisService.analyzeCaseForensics(
      ctx.caseId, ctx.userId,
      { plaidAccessToken: 'valid-token-123' }
    );

    // Should succeed — empty transactions is not an error
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // Payment verification should exist but show zero matches
    expect(result.paymentVerification).toBeDefined();
    expect(result.paymentVerification.transactionsAnalyzed).toBe(0);
    expect(result.paymentVerification.matchedPayments).toEqual([]);
    expect(result.paymentVerification.verified).toBe(true);

    // Plaid step should be completed (not failed)
    expect(result._metadata.steps.plaidCrossReference.status).toBe('completed');
  });

  test('Plaid API timeout — forensic orchestrator degrades gracefully (Step 3 skipped)', async () => {
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing', analysisReport: ctx.analysisResults[ctx.docIdA] },
        { documentId: ctx.docIdB, documentType: 'origination', analysisReport: ctx.analysisResults[ctx.docIdB] }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: [], discrepancyTypes: [], forensicSignificance: 'high' }
      ],
      documentsWithoutAnalysis: [],
      totalDocuments: 2,
      analyzedDocuments: 2
    });

    mockCrossDocComparison.compareDocumentPair.mockResolvedValue({
      pairId: 'pair-001',
      discrepancies: ctx.forensicResults.discrepancies,
      timelineEvents: [],
      timelineViolations: []
    });

    // Plaid times out
    const timeoutError = new Error('Request timed out after 30000ms');
    timeoutError.code = 'ETIMEDOUT';
    mockPlaidService.getTransactions.mockRejectedValue(timeoutError);

    const result = await forensicAnalysisService.analyzeCaseForensics(
      ctx.caseId, ctx.userId,
      { plaidAccessToken: 'valid-token' }
    );

    // Should NOT error — Plaid step degrades gracefully
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // Document comparison results should still be present
    expect(result.discrepancies.length).toBeGreaterThan(0);

    // Payment verification null (Plaid failed)
    expect(result.paymentVerification).toBeNull();

    // Metadata records Plaid timeout
    expect(result._metadata.steps.plaidCrossReference.status).toBe('failed');
    expect(result._metadata.steps.plaidCrossReference.reason).toContain('timed out');
  });
});

// ============================================================
// SUPABASE FAILURES
// ============================================================
describe('Supabase boundary failures', () => {

  test('Supabase write fails during pipeline state persistence — pipeline continues in-memory (Phase 10-04)', async () => {
    // Make Supabase writes fail
    mockClient.setError('from', { message: 'Database connection lost', code: '08006' });

    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    // Pipeline should succeed — Supabase writes are best-effort
    expect(result.success).toBe(true);
    expect(result.status).toBe('review');
    expect(result.classificationResults).toBeDefined();
    expect(result.analysisResults).toBeDefined();

    // Verify the document is still tracked in-memory
    const status = documentPipeline.getStatusSync(ctx.docIdA);
    expect(status).not.toBeNull();
    expect(status.status).toBe('review');

    // Reset Supabase for other tests
    mockClient.reset();
  });

  test('Supabase read fails when loading case data — compliance returns appropriate error', async () => {
    // caseFileService.getCase throws (simulates Supabase read failure)
    mockCaseFileService.getCase.mockRejectedValue(
      new Error('Supabase: connection refused')
    );

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipAiAnalysis: true }
    );

    // Should return error — GATHER step failure returns error per Phase 16-05
    expect(result.error).toBe(true);
    expect(result.errorMessage).toBeDefined();
    expect(result.errorMessage.length).toBeGreaterThan(0);
    expect(result.errorMessage).toContain('Failed to retrieve case data');
    expect(result._metadata).toBeDefined();
    expect(result._metadata.steps.gather.status).toBe('failed');
  });

  test('Supabase write fails during report persistence — report returned to caller despite persistence failure', async () => {
    // Set up report generation to succeed but persistence to fail
    mockReportAggregation.gatherCaseFindings.mockResolvedValue({
      caseInfo: {
        borrowerName: ctx.caseData.borrower_name,
        propertyAddress: ctx.caseData.property_address,
        loanNumber: ctx.caseData.loan_number,
        servicerName: ctx.caseData.servicer_name,
        documentCount: 2,
        createdAt: ctx.caseData.created_at
      },
      documentAnalyses: [],
      forensicReport: null,
      complianceReport: null,
      errors: []
    });
    mockReportAggregation.extractFindingSummary.mockReturnValue({
      totalFindings: 0,
      bySeverity: { critical: 0, high: 0, medium: 0, low: 0, info: 0 },
      byCategory: { documentAnomalies: 0, crossDocDiscrepancies: 0, timelineViolations: 0, paymentIssues: 0, federalViolations: 0, stateViolations: 0 }
    });
    mockConfidenceScoring.calculateConfidence.mockReturnValue({
      overall: 100,
      breakdown: { documentAnalysis: null, forensicAnalysis: null, complianceAnalysis: null }
    });
    mockConfidenceScoring.determineRiskLevel.mockReturnValue('clean');
    mockConfidenceScoring.buildEvidenceLinks.mockReturnValue([]);

    // Make persistence fail
    mockCaseFileService.updateCase.mockRejectedValue(
      new Error('Supabase: table not found')
    );

    // Don't skip persistence this time
    const result = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { skipPersistence: false }
    );

    // Report should still be returned to caller (best-effort persistence)
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);
    expect(result.reportId).toBeDefined();
    expect(result.overallRiskLevel).toBeDefined();
  });

  test('Supabase returns null for case query — compliance returns appropriate error, not crash', async () => {
    // caseFileService.getCase returns null (case not found)
    mockCaseFileService.getCase.mockResolvedValue(null);

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipAiAnalysis: true }
    );

    // Should return error — not a crash
    expect(result.error).toBe(true);
    expect(result.errorMessage).toBeDefined();
    expect(result.errorMessage.length).toBeGreaterThan(0);
    expect(result._metadata).toBeDefined();
    expect(result._metadata.steps.gather.status).toBe('failed');
  });

  test('Supabase write fails during forensic analysis persistence — report still returned', async () => {
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing', analysisReport: ctx.analysisResults[ctx.docIdA] },
        { documentId: ctx.docIdB, documentType: 'origination', analysisReport: ctx.analysisResults[ctx.docIdB] }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: [], discrepancyTypes: [], forensicSignificance: 'high' }
      ],
      documentsWithoutAnalysis: [],
      totalDocuments: 2,
      analyzedDocuments: 2
    });

    mockCrossDocComparison.compareDocumentPair.mockResolvedValue({
      pairId: 'pair-001',
      discrepancies: ctx.forensicResults.discrepancies,
      timelineEvents: [],
      timelineViolations: []
    });

    // Persistence fails
    mockCaseFileService.updateCase.mockRejectedValue(
      new Error('Supabase: write timeout')
    );

    const result = await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);

    // Should NOT error — persistence is best-effort
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);
    expect(result.discrepancies.length).toBeGreaterThan(0);
    expect(result._metadata).toBeDefined();
  });
});

// ============================================================
// COMPOUND FAILURES (multiple boundaries failing)
// ============================================================
describe('Cross-boundary compound failures', () => {

  test('Both Claude AND Plaid fail — forensic analysis returns partial results (document-based only)', async () => {
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing', analysisReport: ctx.analysisResults[ctx.docIdA] },
        { documentId: ctx.docIdB, documentType: 'origination', analysisReport: ctx.analysisResults[ctx.docIdB] }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: [], discrepancyTypes: [], forensicSignificance: 'high' }
      ],
      documentsWithoutAnalysis: [],
      totalDocuments: 2,
      analyzedDocuments: 2
    });

    // Claude comparison fails
    mockCrossDocComparison.compareDocumentPair.mockRejectedValue(
      new Error('Claude API: 500 Internal Server Error')
    );

    // Plaid also fails
    mockPlaidService.getTransactions.mockRejectedValue(
      new Error('ITEM_LOGIN_REQUIRED: Access token expired')
    );

    const result = await forensicAnalysisService.analyzeCaseForensics(
      ctx.caseId, ctx.userId,
      { plaidAccessToken: 'expired-token' }
    );

    // Should NOT crash — graceful degradation on both fronts
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // No AI comparison results (all pairs failed)
    expect(result.discrepancies).toEqual([]);

    // No Plaid results
    expect(result.paymentVerification).toBeNull();

    // Both failures should be recorded
    expect(result._metadata.steps.comparison.pairsFailed).toBe(1);
    expect(result._metadata.steps.plaidCrossReference.status).toBe('failed');
    expect(result._metadata.warnings.length).toBeGreaterThanOrEqual(2);
  });

  test('Supabase read succeeds but all Claude calls fail — pipeline returns structured error with case data intact', async () => {
    // Case data loads successfully from Supabase
    ctx.caseData.forensic_analysis = ctx.forensicResults;
    mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);

    // Rule engine works (no Claude needed)
    // But AI enhancement fails
    mockComplianceAnalysis.analyzeViolations.mockRejectedValue(
      new Error('Claude API: connection reset')
    );
    mockComplianceAnalysis.analyzeStateViolations.mockRejectedValue(
      new Error('Claude API: connection reset')
    );

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId
    );

    // Should NOT error — case data is intact, only AI enhancement failed
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // Rule-engine results should be present (no Claude needed for those)
    expect(result.violations).toBeDefined();
    expect(result.violations.length).toBeGreaterThanOrEqual(1);

    // AI enhancement failures recorded
    expect(result._metadata.steps.aiEnhancement.status).toBe('failed');
    expect(result._metadata.warnings.length).toBeGreaterThanOrEqual(1);
  });

  test('Supabase write fails AND Plaid fails — forensic still returns comparison results', async () => {
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing', analysisReport: ctx.analysisResults[ctx.docIdA] },
        { documentId: ctx.docIdB, documentType: 'origination', analysisReport: ctx.analysisResults[ctx.docIdB] }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: ['interestRate'], discrepancyTypes: ['amount_mismatch'], forensicSignificance: 'high' }
      ],
      documentsWithoutAnalysis: [],
      totalDocuments: 2,
      analyzedDocuments: 2
    });

    // Comparison succeeds (Claude works)
    mockCrossDocComparison.compareDocumentPair.mockResolvedValue({
      pairId: 'pair-001',
      discrepancies: ctx.forensicResults.discrepancies,
      timelineEvents: ctx.forensicResults.timeline.events,
      timelineViolations: []
    });

    // Plaid fails
    mockPlaidService.getTransactions.mockRejectedValue(
      new Error('Plaid API: 503 Service Unavailable')
    );

    // Supabase persistence fails
    mockCaseFileService.updateCase.mockRejectedValue(
      new Error('Supabase: connection lost')
    );

    const result = await forensicAnalysisService.analyzeCaseForensics(
      ctx.caseId, ctx.userId,
      { plaidAccessToken: 'valid-token' }
    );

    // Should succeed — comparison results intact despite Plaid + Supabase failures
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);
    expect(result.discrepancies.length).toBeGreaterThan(0);
    expect(result.paymentVerification).toBeNull();
    expect(result._metadata.steps.plaidCrossReference.status).toBe('failed');
  });

  test('Report generation succeeds despite Supabase persistence and scoring failures — all graceful degradation', async () => {
    // Gather succeeds
    mockReportAggregation.gatherCaseFindings.mockResolvedValue({
      caseInfo: {
        borrowerName: ctx.caseData.borrower_name,
        propertyAddress: ctx.caseData.property_address,
        loanNumber: ctx.caseData.loan_number,
        servicerName: ctx.caseData.servicer_name,
        documentCount: 2,
        createdAt: ctx.caseData.created_at
      },
      documentAnalyses: [],
      forensicReport: ctx.forensicResults,
      complianceReport: ctx.complianceResults,
      errors: []
    });

    // Scoring throws
    mockConfidenceScoring.calculateConfidence.mockImplementation(() => {
      throw new Error('Scoring calculation error');
    });
    mockConfidenceScoring.determineRiskLevel.mockReturnValue('clean');
    mockConfidenceScoring.buildEvidenceLinks.mockReturnValue([]);
    mockReportAggregation.extractFindingSummary.mockReturnValue({
      totalFindings: 0,
      bySeverity: { critical: 0, high: 0, medium: 0, low: 0, info: 0 },
      byCategory: { documentAnomalies: 0, crossDocDiscrepancies: 0, timelineViolations: 0, paymentIssues: 0, federalViolations: 0, stateViolations: 0 }
    });

    // Persistence fails
    mockCaseFileService.updateCase.mockRejectedValue(
      new Error('Supabase: table not found')
    );

    const result = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { skipPersistence: false }
    );

    // Should still return a report — scoring uses defaults, persistence is best-effort
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);
    expect(result.reportId).toBeDefined();

    // Scoring should have fallen back to defaults
    expect(result.confidenceScore).toBeDefined();

    // Warning about scoring failure should be recorded
    expect(result._metadata.warnings.some(w => w.includes('Confidence scoring failed'))).toBe(true);
  });
});
