/**
 * Claude API Boundary Failure Tests
 *
 * Validates graceful degradation at every pipeline stage where Claude AI is called:
 *   Stage 1: Classification (classificationService)
 *   Stage 2: Individual Analysis (documentAnalysisService)
 *   Stage 3: Cross-Document Comparison (crossDocumentComparisonService)
 *   Stage 4: Compliance AI Enhancement (complianceAnalysisService)
 *
 * Every test verifies error objects in the response — no test validates by
 * catching thrown exceptions.
 *
 * Constraining decisions:
 *   - Phase 10-03: Graceful JSON parse fallback on Claude responses
 *   - Phase 12-02: Schema validation as warnings not rejections
 *   - Phase 13-05: Per-step error objects instead of throws
 *   - Phase 14-04: Graceful degradation on Claude API failure
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
// STAGE 1: CLASSIFICATION FAILURES (classificationService)
// ============================================================
describe('Stage 1 — Classification boundary failures', () => {

  test('Claude returns 429 (rate limited) — pipeline returns failure with meaningful error', async () => {
    const rateLimitError = new Error('429 Too Many Requests');
    rateLimitError.status = 429;
    mockAnthropicCreate.mockReset();
    mockAnthropicCreate.mockRejectedValue(rateLimitError);

    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    expect(result.success).toBe(false);
    expect(result.status).toBe('failed');
    expect(result.error).toBeDefined();
    expect(result.error.message).toContain('429');
    expect(result.error.message.length).toBeGreaterThan(0);
  });

  test('Claude returns malformed JSON — pipeline handles via JSON parse fallback (Phase 10-03)', async () => {
    mockAnthropicCreate.mockReset();

    // Classification returns malformed JSON
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: 'This is not JSON at all, just plain text response' }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 500, output_tokens: 200 },
      stop_reason: 'end_turn'
    });

    // Analysis response (in case classification fallback lets it continue)
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(ctx.analysisResults[ctx.docIdA]) }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 1200, output_tokens: 600 },
      stop_reason: 'end_turn'
    });

    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    // Classification parse fallback should store the raw response + parseError
    // The pipeline should continue (not crash) - it will have classification results
    // with parseError set, and the document type remains as original
    expect(result.success).toBe(true);
    expect(result.classificationResults).toBeDefined();
    expect(result.classificationResults.parseError).toBeDefined();
    expect(result.classificationResults.rawResponse).toBeDefined();
  });

  test('Claude times out — pipeline returns failure with timeout error', async () => {
    const timeoutError = new Error('Request timed out after 60000ms');
    timeoutError.code = 'ETIMEDOUT';
    mockAnthropicCreate.mockReset();
    mockAnthropicCreate.mockRejectedValue(timeoutError);

    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    expect(result.success).toBe(false);
    expect(result.status).toBe('failed');
    expect(result.error).toBeDefined();
    expect(result.error.message).toContain('timed out');
  });
});

// ============================================================
// STAGE 2: INDIVIDUAL ANALYSIS FAILURES (documentAnalysisService)
// ============================================================
describe('Stage 2 — Analysis boundary failures', () => {

  test('Claude returns 500 on analysis — analysis returns error status, not throw', async () => {
    mockAnthropicCreate.mockReset();

    // Classification succeeds
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(ctx.classificationResults[ctx.docIdA]) }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 500, output_tokens: 200 },
      stop_reason: 'end_turn'
    });

    // Analysis fails with 500
    const serverError = new Error('500 Internal Server Error');
    serverError.status = 500;
    mockAnthropicCreate.mockRejectedValueOnce(serverError);

    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    // documentAnalysisService returns error object (not throw) per Phase 13-05
    // but the pipeline treats it as a successful completion with error-shaped analysis
    // OR the pipeline catches and returns failure
    if (result.success) {
      // Analysis service returned error object which pipeline stored as results
      expect(result.analysisResults).toBeDefined();
      expect(result.analysisResults.error).toBe(true);
      expect(result.analysisResults.errorMessage).toBeDefined();
      expect(result.analysisResults.errorMessage.length).toBeGreaterThan(0);
    } else {
      // Pipeline caught the error and returned failure
      expect(result.status).toBe('failed');
      expect(result.error).toBeDefined();
      expect(result.error.message).toBeDefined();
    }
  });

  test('Claude returns empty response — analysis handles gracefully', async () => {
    mockAnthropicCreate.mockReset();

    // Classification succeeds
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(ctx.classificationResults[ctx.docIdA]) }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 500, output_tokens: 200 },
      stop_reason: 'end_turn'
    });

    // Analysis returns empty content
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: '' }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 1200, output_tokens: 0 },
      stop_reason: 'end_turn'
    });

    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    // Should handle gracefully — either parse fallback or error object
    expect(result.success).toBe(true);
    expect(result.analysisResults).toBeDefined();
    // Parse fallback should trigger since empty string is not valid JSON
    expect(result.analysisResults.parseError).toBeDefined();
  });

  test('Claude returns valid JSON but missing required fields — schema validation as warnings (Phase 12-02)', async () => {
    mockAnthropicCreate.mockReset();

    // Classification succeeds
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(ctx.classificationResults[ctx.docIdA]) }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 500, output_tokens: 200 },
      stop_reason: 'end_turn'
    });

    // Analysis returns valid JSON but missing required fields
    const incompleteAnalysis = {
      extractedData: {
        dates: { statementDate: '2024-01-15' }
        // Missing: amounts, rates, parties, identifiers, terms, custom
      }
      // Missing: anomalies, summary
    };

    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(incompleteAnalysis) }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 1200, output_tokens: 300 },
      stop_reason: 'end_turn'
    });

    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    // Should succeed — schema validation produces warnings, not rejections
    expect(result.success).toBe(true);
    expect(result.analysisResults).toBeDefined();

    // The enrichment step fills in defaults for missing fields
    expect(result.analysisResults.extractedData).toBeDefined();
    expect(result.analysisResults.anomalies).toBeDefined();
    expect(Array.isArray(result.analysisResults.anomalies)).toBe(true);
    expect(result.analysisResults.summary).toBeDefined();
    expect(result.analysisResults.completeness).toBeDefined();
  });
});

// ============================================================
// STAGE 3: CROSS-DOCUMENT COMPARISON FAILURES (crossDocumentComparisonService)
// ============================================================
describe('Stage 3 — Cross-document comparison boundary failures', () => {

  test('Claude fails mid-comparison — forensic orchestrator includes successful pairs and logs failures', async () => {
    // Set up aggregation with 2 comparison pairs
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing', analysisReport: ctx.analysisResults[ctx.docIdA] },
        { documentId: ctx.docIdB, documentType: 'origination', analysisReport: ctx.analysisResults[ctx.docIdB] }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: ['interestRate'], discrepancyTypes: ['amount_mismatch'], forensicSignificance: 'high' },
        { pairId: 'pair-002', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: ['monthlyPayment'], discrepancyTypes: ['amount_mismatch'], forensicSignificance: 'medium' }
      ],
      documentsWithoutAnalysis: [],
      totalDocuments: 2,
      analyzedDocuments: 2
    });

    // First pair succeeds
    mockCrossDocComparison.compareDocumentPair.mockResolvedValueOnce({
      pairId: 'pair-001',
      discrepancies: [ctx.forensicResults.discrepancies[0]],
      timelineEvents: ctx.forensicResults.timeline.events,
      timelineViolations: []
    });

    // Second pair fails (simulates Claude failure mid-comparison)
    mockCrossDocComparison.compareDocumentPair.mockRejectedValueOnce(
      new Error('Claude API: 500 Internal Server Error')
    );

    const result = await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);

    // Should NOT error out — graceful degradation
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // Successful pair results should be included
    expect(result.discrepancies.length).toBeGreaterThan(0);

    // Metadata should record the failure
    expect(result._metadata.steps.comparison.pairsFailed).toBe(1);
    expect(result._metadata.warnings.length).toBeGreaterThan(0);
    expect(result._metadata.warnings.some(w => w.includes('pair-002'))).toBe(true);
  });

  test('All comparison pairs fail — forensic report returns empty findings with warnings', async () => {
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

    // Comparison throws
    mockCrossDocComparison.compareDocumentPair.mockRejectedValue(
      new Error('Claude API unreachable')
    );

    const result = await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);

    // Should NOT error — graceful degradation, just empty findings
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);
    expect(result.discrepancies).toEqual([]);
    expect(result._metadata.steps.comparison.pairsFailed).toBe(1);
    expect(result._metadata.warnings.length).toBeGreaterThan(0);
  });

  test('Cross-document comparison returns error object — forensic orchestrator handles it as pair failure', async () => {
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

    // Returns error object instead of throwing
    mockCrossDocComparison.compareDocumentPair.mockResolvedValue({
      error: true,
      errorMessage: 'Claude returned malformed JSON for comparison'
    });

    const result = await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);

    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);
    expect(result.discrepancies).toEqual([]);
    expect(result._metadata.steps.comparison.pairsFailed).toBe(1);
    expect(result._metadata.warnings.length).toBeGreaterThan(0);
  });
});

// ============================================================
// STAGE 4: COMPLIANCE AI ENHANCEMENT FAILURES (complianceAnalysisService)
// ============================================================
describe('Stage 4 — Compliance AI enhancement boundary failures', () => {

  beforeEach(() => {
    // Set up case data with forensic analysis for compliance step
    ctx.caseData.forensic_analysis = ctx.forensicResults;
    mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);
  });

  test('Claude AI enhancement fails entirely — original rule-engine violations returned unchanged (Phase 14-04)', async () => {
    // Make the AI enhancement throw
    mockComplianceAnalysis.analyzeViolations.mockRejectedValue(
      new Error('Claude API: 503 Service Unavailable')
    );

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipStateAnalysis: true }
    );

    // Should NOT error — compliance returns rule-engine results without AI enhancement
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // Original rule-engine violations should be present
    expect(result.violations).toBeDefined();
    expect(result.violations.length).toBeGreaterThanOrEqual(1);
    expect(result.violations[0].statuteId).toBe('respa');

    // Metadata should record AI enhancement failure
    expect(result._metadata.steps.aiEnhancement.status).toBe('failed');
    expect(result._metadata.warnings.some(w => w.includes('Claude AI enhancement failed'))).toBe(true);
  });

  test('Claude returns partial enhancement — graceful merge of enhanced + unenhanced', async () => {
    // AI enhancement returns only partial data (enhancedViolations but empty array)
    mockComplianceAnalysis.analyzeViolations.mockResolvedValue({
      enhancedViolations: [], // No enhancements returned
      legalNarrative: '',
      analysisMetadata: { totalViolations: 1, claudeCallsMade: 1, durationMs: 500 }
    });

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipStateAnalysis: true }
    );

    // Should NOT error
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // Violations from rule engine should still be present (AI didn't override with empty)
    expect(result.violations).toBeDefined();
    expect(result.violations.length).toBeGreaterThanOrEqual(1);

    // AI enhancement should be recorded as completed
    expect(result._metadata.steps.aiEnhancement.status).toBe('completed');
  });

  test('State AI enhancement fails — state violations from rule engine preserved', async () => {
    // Federal AI works fine
    mockComplianceAnalysis.analyzeViolations.mockResolvedValue({
      enhancedViolations: ctx.complianceResults.violations,
      legalNarrative: 'Analysis complete.',
      analysisMetadata: { totalViolations: 1, claudeCallsMade: 1, durationMs: 500 }
    });

    // State AI enhancement fails
    mockComplianceAnalysis.analyzeStateViolations.mockRejectedValue(
      new Error('Claude API rate limit exceeded')
    );

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId
    );

    // Should NOT error
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // Federal violations should be enhanced
    expect(result.violations).toBeDefined();
    expect(result.violations.length).toBeGreaterThanOrEqual(1);

    // State violations should be from rule engine (unenhanced but present)
    expect(result.stateViolations).toBeDefined();
    expect(result.stateViolations.length).toBeGreaterThanOrEqual(1);

    // Metadata should record state AI failure
    expect(result._metadata.steps.stateAiEnhancement.status).toBe('failed');
    expect(result._metadata.warnings.some(w => w.includes('State AI enhancement failed'))).toBe(true);
  });

  test('Both federal and state AI enhancement fail — all rule-engine violations preserved', async () => {
    mockComplianceAnalysis.analyzeViolations.mockRejectedValue(
      new Error('Claude API connection refused')
    );
    mockComplianceAnalysis.analyzeStateViolations.mockRejectedValue(
      new Error('Claude API connection refused')
    );

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId
    );

    // Should NOT error — full graceful degradation
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // All violations from rule engine should be present
    expect(result.violations).toBeDefined();
    expect(result.violations.length).toBeGreaterThanOrEqual(1);
    expect(result.stateViolations).toBeDefined();

    // Both AI enhancement steps should be recorded as failed
    expect(result._metadata.steps.aiEnhancement.status).toBe('failed');
    expect(result._metadata.warnings.length).toBeGreaterThanOrEqual(2);
  });
});

// ============================================================
// COMPOUND: CLASSIFICATION + ANALYSIS FAILURES
// ============================================================
describe('Compound Claude failures across pipeline stages', () => {

  test('Claude fails on classification but second document succeeds — pipeline handles independently', async () => {
    mockAnthropicCreate.mockReset();

    // Doc A: classification fails
    mockAnthropicCreate.mockRejectedValueOnce(new Error('Claude API timeout'));

    const resultA = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    // Doc A should fail
    expect(resultA.success).toBe(false);
    expect(resultA.status).toBe('failed');

    // Reset for Doc B
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(ctx.classificationResults[ctx.docIdB]) }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 500, output_tokens: 200 },
      stop_reason: 'end_turn'
    });
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(ctx.analysisResults[ctx.docIdB]) }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 1200, output_tokens: 600 },
      stop_reason: 'end_turn'
    });

    const resultB = await documentPipeline.processDocument(ctx.docIdB, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdB].text,
      documentType: 'unknown'
    });

    // Doc B should succeed independently
    expect(resultB.success).toBe(true);
    expect(resultB.status).toBe('review');
  });

  test('Claude returns malformed JSON for both classification and analysis — pipeline still has useful state', async () => {
    mockAnthropicCreate.mockReset();

    // Classification: malformed JSON (fallback path)
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: '{"classificationType": servicing, broken JSON' }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 500, output_tokens: 200 },
      stop_reason: 'end_turn'
    });

    // Analysis: also malformed JSON
    mockAnthropicCreate.mockResolvedValueOnce({
      content: [{ text: 'Not JSON at all - just analysis text' }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 1200, output_tokens: 600 },
      stop_reason: 'end_turn'
    });

    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    // Pipeline should complete (not crash) — parse fallbacks handle both
    expect(result.success).toBe(true);

    // Classification should have parseError
    expect(result.classificationResults).toBeDefined();
    expect(result.classificationResults.parseError).toBeDefined();

    // Analysis should have parseError
    expect(result.analysisResults).toBeDefined();
    expect(result.analysisResults.parseError).toBeDefined();
  });
});
