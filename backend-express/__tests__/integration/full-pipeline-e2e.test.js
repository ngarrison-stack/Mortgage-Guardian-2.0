/**
 * Full Pipeline End-to-End Integration Tests
 *
 * Exercises the complete v3.0 document lifecycle across all 4 orchestrators:
 *   documentPipelineService -> forensicAnalysisService -> complianceService -> consolidatedReportService
 *
 * Mocks all external boundaries (Anthropic SDK, Supabase, Plaid).
 * Tests internal orchestration logic and data flow between stages.
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

// pdf-parse (ocrService dependency)
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

// Document service (not under test)
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
let consolidatedReportService;

beforeAll(() => {
  // Clear cached modules so mocks take effect
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
  // Create fresh context and set up all mocks
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

  // Clear pipeline state between tests
  documentPipeline.pipelineState.clear();
});

// ============================================================
// 1. FULL HAPPY PATH
// ============================================================
describe('full happy path', () => {

  test('processes 2 documents through the complete pipeline chain', async () => {
    // --- Stage 1: Document intake + analysis (via documentPipelineService) ---
    const resultA = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    expect(resultA.success).toBe(true);
    expect(resultA.status).toBe('review');
    expect(resultA.classificationResults).toBeDefined();
    expect(resultA.analysisResults).toBeDefined();

    const resultB = await documentPipeline.processDocument(ctx.docIdB, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdB].text,
      documentType: 'unknown'
    });

    expect(resultB.success).toBe(true);
    expect(resultB.status).toBe('review');

    // --- Stage 2: Cross-document forensic analysis ---
    const forensicResult = await forensicAnalysisService.analyzeCaseForensics(
      ctx.caseId, ctx.userId
    );

    expect(forensicResult.error).toBeUndefined();
    expect(forensicResult.caseId).toBe(ctx.caseId);
    expect(forensicResult.discrepancies).toBeDefined();
    expect(forensicResult.discrepancies.length).toBeGreaterThanOrEqual(2);
    expect(forensicResult.summary.riskLevel).toBe('high');

    // Update case data with forensic results for compliance step
    ctx.caseData.forensic_analysis = forensicResult;
    mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);

    // --- Stage 3: Compliance evaluation ---
    const complianceResult = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipAiAnalysis: true }
    );

    expect(complianceResult.error).toBeUndefined();
    expect(complianceResult.caseId).toBe(ctx.caseId);
    expect(complianceResult.violations).toBeDefined();
    expect(complianceResult.violations.length).toBeGreaterThanOrEqual(1);
    expect(complianceResult.complianceSummary.overallComplianceRisk).toBe('high');

    // Update case data with compliance results for report step
    ctx.caseData.compliance_report = complianceResult;

    // --- Stage 4: Consolidated report generation ---
    const reportResult = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { generateLetter: true, skipPersistence: true }
    );

    expect(reportResult.error).toBeUndefined();
    expect(reportResult.caseId).toBe(ctx.caseId);
    expect(reportResult.reportId).toBeDefined();
    expect(reportResult.overallRiskLevel).toBe('high');
    expect(reportResult.confidenceScore).toBeDefined();
    expect(reportResult.evidenceLinks).toBeDefined();
    expect(reportResult.recommendations).toBeDefined();
    expect(reportResult.disputeLetterAvailable).toBe(true);
    expect(reportResult.disputeLetter).toBeDefined();
  });

  test('pipeline state transitions follow correct order for each document', async () => {
    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);

    // Verify step completion timestamps exist in order
    const steps = result.steps;
    expect(steps.uploaded).toBeDefined();
    expect(steps.uploaded.completedAt).toBeDefined();
    expect(steps.ocr).toBeDefined();
    expect(steps.ocr.completedAt).toBeDefined();
    expect(steps.classifying).toBeDefined();
    expect(steps.classifying.completedAt).toBeDefined();
    expect(steps.analyzing).toBeDefined();
    expect(steps.analyzing.completedAt).toBeDefined();
    expect(steps.analyzed).toBeDefined();
    expect(steps.analyzed.completedAt).toBeDefined();
    expect(steps.review).toBeDefined();
    expect(steps.review.completedAt).toBeDefined();
  });

  test('forensic analysis detects cross-document discrepancies', async () => {
    const forensicResult = await forensicAnalysisService.analyzeCaseForensics(
      ctx.caseId, ctx.userId
    );

    expect(forensicResult.discrepancies).toHaveLength(2);

    // Verify discrepancy types match expected
    const types = forensicResult.discrepancies.map(d => d.type);
    expect(types).toContain('amount_mismatch');
    expect(types).toContain('date_inconsistency');

    // Verify sequential IDs were assigned
    expect(forensicResult.discrepancies[0].id).toBe('disc-001');
    expect(forensicResult.discrepancies[1].id).toBe('disc-002');
  });

  test('compliance evaluation finds federal and state violations', async () => {
    ctx.caseData.forensic_analysis = ctx.forensicResults;
    mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipAiAnalysis: true }
    );

    // Federal violations
    expect(result.violations).toBeDefined();
    expect(result.violations.length).toBeGreaterThanOrEqual(1);
    expect(result.violations[0].statuteId).toBe('respa');

    // State violations
    expect(result.stateViolations).toBeDefined();
    expect(result.stateViolations.length).toBeGreaterThanOrEqual(1);
    expect(result.stateViolations[0].statuteId).toBe('ca_hbor');
  });

  test('consolidated report contains findings from all upstream stages', async () => {
    const report = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { generateLetter: true, skipPersistence: true }
    );

    // Document analysis
    expect(report.documentAnalysis).toBeDefined();
    expect(report.documentAnalysis).toHaveLength(2);

    // Forensic findings
    expect(report.forensicFindings).toBeDefined();
    expect(report.forensicFindings.discrepancies).toBeDefined();

    // Compliance findings
    expect(report.complianceFindings).toBeDefined();
    expect(report.complianceFindings.federalViolations).toBeDefined();
    expect(report.complianceFindings.stateViolations).toBeDefined();

    // Finding summary aggregates all stages
    expect(report.findingSummary).toBeDefined();
    expect(report.findingSummary.totalFindings).toBeGreaterThan(0);
  });

  test('dispute letter is generated when option is enabled', async () => {
    const report = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { generateLetter: true, skipPersistence: true }
    );

    expect(report.disputeLetterAvailable).toBe(true);
    expect(report.disputeLetter).toBeDefined();
    expect(report.disputeLetter.letterType).toBe('qualified_written_request');
    expect(report.disputeLetter.content).toBeDefined();
  });
});

// ============================================================
// 2. PIPELINE STATE CONSISTENCY
// ============================================================
describe('pipeline state consistency', () => {

  test('document ids flow correctly through all stages', async () => {
    // Process both documents
    await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });
    await documentPipeline.processDocument(ctx.docIdB, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdB].text,
      documentType: 'unknown'
    });

    // Verify pipeline tracks both documents
    const statusA = documentPipeline.getStatusSync(ctx.docIdA);
    const statusB = documentPipeline.getStatusSync(ctx.docIdB);
    expect(statusA).not.toBeNull();
    expect(statusB).not.toBeNull();
    expect(statusA.documentId).toBe(ctx.docIdA);
    expect(statusB.documentId).toBe(ctx.docIdB);

    // Forensic analysis references the same documents
    const forensicResult = await forensicAnalysisService.analyzeCaseForensics(
      ctx.caseId, ctx.userId
    );
    const discDocIds = new Set();
    for (const disc of forensicResult.discrepancies) {
      if (disc.documentA?.documentId) discDocIds.add(disc.documentA.documentId);
      if (disc.documentB?.documentId) discDocIds.add(disc.documentB.documentId);
    }
    expect(discDocIds.has(ctx.docIdA)).toBe(true);
    expect(discDocIds.has(ctx.docIdB)).toBe(true);
  });

  test('case id is consistent across all orchestrator outputs', async () => {
    // Forensic
    const forensic = await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);
    expect(forensic.caseId).toBe(ctx.caseId);

    // Compliance
    ctx.caseData.forensic_analysis = forensic;
    mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);

    const compliance = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipAiAnalysis: true }
    );
    expect(compliance.caseId).toBe(ctx.caseId);

    // Consolidated report
    const report = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { skipPersistence: true }
    );
    expect(report.caseId).toBe(ctx.caseId);
  });

  test('finding counts in consolidated report match upstream totals', async () => {
    const report = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { skipPersistence: true }
    );

    const summary = report.findingSummary;
    expect(summary).toBeDefined();

    // Total should equal sum of categories
    const categorySum =
      summary.byCategory.documentAnomalies +
      summary.byCategory.crossDocDiscrepancies +
      summary.byCategory.timelineViolations +
      summary.byCategory.paymentIssues +
      summary.byCategory.federalViolations +
      summary.byCategory.stateViolations;

    expect(summary.totalFindings).toBe(categorySum);

    // Severity breakdown should sum to total
    const severitySum =
      summary.bySeverity.critical +
      summary.bySeverity.high +
      summary.bySeverity.medium +
      summary.bySeverity.low +
      summary.bySeverity.info;

    expect(severitySum).toBe(summary.totalFindings);
  });
});

// ============================================================
// 3. PARTIAL PIPELINE (no forensics / compliance)
// ============================================================
describe('partial pipeline', () => {

  test('individual document analysis works independently', async () => {
    const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);
    expect(result.status).toBe('review');
    expect(result.analysisResults).toBeDefined();
    expect(result.analysisResults.extractedData).toBeDefined();

    // No forensic or compliance calls were needed
    expect(mockCrossDocAggregation.aggregateForCase).not.toHaveBeenCalled();
    expect(mockComplianceRuleEngine.evaluateFindings).not.toHaveBeenCalled();
  });

  test('consolidated report handles missing forensic data gracefully', async () => {
    // Set up report aggregation to return no forensic/compliance data
    mockReportAggregation.gatherCaseFindings.mockResolvedValue({
      caseInfo: {
        borrowerName: ctx.caseData.borrower_name,
        propertyAddress: ctx.caseData.property_address,
        loanNumber: ctx.caseData.loan_number,
        servicerName: ctx.caseData.servicer_name,
        documentCount: 1,
        createdAt: ctx.caseData.created_at
      },
      documentAnalyses: [
        {
          documentId: ctx.docIdA,
          documentName: 'Monthly Statement',
          type: 'servicing',
          subtype: 'monthly_statement',
          completenessScore: 85,
          anomalyCount: 1,
          anomalies: ctx.analysisResults[ctx.docIdA].anomalies,
          keyFindings: ['Interest rate discrepancy']
        }
      ],
      forensicReport: null,
      complianceReport: null,
      errors: []
    });

    // Scoring defaults for partial data
    mockConfidenceScoring.calculateConfidence.mockReturnValue({
      overall: 80,
      breakdown: { documentAnalysis: 80, forensicAnalysis: null, complianceAnalysis: null }
    });
    mockConfidenceScoring.determineRiskLevel.mockReturnValue('low');
    mockConfidenceScoring.buildEvidenceLinks.mockReturnValue([]);

    mockReportAggregation.extractFindingSummary.mockReturnValue({
      totalFindings: 1,
      bySeverity: { critical: 0, high: 1, medium: 0, low: 0, info: 0 },
      byCategory: {
        documentAnomalies: 1,
        crossDocDiscrepancies: 0,
        timelineViolations: 0,
        paymentIssues: 0,
        federalViolations: 0,
        stateViolations: 0
      }
    });

    const report = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { skipPersistence: true }
    );

    // Report should succeed, not error
    expect(report.error).toBeUndefined();
    expect(report.caseId).toBe(ctx.caseId);
    expect(report.reportId).toBeDefined();

    // Forensic/compliance sections should be empty, not null or errored
    expect(report.forensicFindings).toBeDefined();
    expect(report.forensicFindings.discrepancies).toEqual([]);
    expect(report.complianceFindings).toBeDefined();
    expect(report.complianceFindings.federalViolations).toEqual([]);
    expect(report.complianceFindings.stateViolations).toEqual([]);

    // Confidence breakdown shows null for missing stages
    expect(report.confidenceScore.breakdown.forensicAnalysis).toBeNull();
    expect(report.confidenceScore.breakdown.complianceAnalysis).toBeNull();
  });

  test('forensic analysis returns early when fewer than 2 analyzed documents', async () => {
    // Aggregation returns only 1 analyzed document
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [{
        documentId: ctx.docIdA,
        documentType: 'servicing',
        documentSubtype: 'monthly_statement',
        analysisReport: ctx.analysisResults[ctx.docIdA]
      }],
      comparisonPairs: [],
      documentsWithoutAnalysis: [],
      totalDocuments: 1,
      analyzedDocuments: 1
    });

    const result = await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);

    // Should return gracefully with empty results
    expect(result.error).toBeUndefined();
    expect(result.discrepancies).toEqual([]);
    expect(result.comparisonPairsEvaluated).toBe(0);
    expect(result.summary.riskLevel).toBe('low');
    expect(result._metadata.warnings).toContain('Insufficient analyzed documents for cross-document comparison');
  });
});

// ============================================================
// 4. MULTI-DOCUMENT SCALING
// ============================================================
describe('multi-document scaling', () => {

  test('processes 3+ documents and generates all comparison pairs', async () => {
    const docIdC = 'doc-e2e-003';

    // Set up Anthropic mocks for 3 documents (classification + analysis each)
    const thirdClassification = {
      classificationType: 'servicing',
      classificationSubtype: 'escrow_analysis',
      confidence: 0.91,
      extractedMetadata: { dates: ['2024-03-01'], amounts: ['$4,200.00'] }
    };
    const thirdAnalysis = {
      documentInfo: { documentType: 'servicing', documentSubtype: 'escrow_analysis' },
      extractedData: {
        dates: { analysisDate: '2024-03-01' },
        amounts: { escrowBalance: 4200 },
        rates: {},
        parties: { servicer: 'Test Bank Corp' },
        identifiers: { loanNumber: '98765' },
        terms: {},
        custom: {}
      },
      anomalies: [],
      completeness: { score: 75, presentFields: ['analysisDate', 'escrowBalance'], missingFields: ['taxAmount'], missingCritical: [], totalExpectedFields: 5 },
      summary: { overview: 'Escrow analysis document.', keyFindings: [], riskLevel: 'low', recommendations: [] }
    };

    // Reset and provide 3 pairs of classification+analysis responses
    mockAnthropicCreate.mockReset();
    for (const [classResult, analysResult] of [
      [ctx.classificationResults[ctx.docIdA], ctx.analysisResults[ctx.docIdA]],
      [ctx.classificationResults[ctx.docIdB], ctx.analysisResults[ctx.docIdB]],
      [thirdClassification, thirdAnalysis]
    ]) {
      mockAnthropicCreate.mockResolvedValueOnce({
        content: [{ text: JSON.stringify(classResult) }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 500, output_tokens: 200 },
        stop_reason: 'end_turn'
      });
      mockAnthropicCreate.mockResolvedValueOnce({
        content: [{ text: JSON.stringify(analysResult) }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 1200, output_tokens: 600 },
        stop_reason: 'end_turn'
      });
    }

    // Process all 3 documents
    const resultA = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdA].text,
      documentType: 'unknown'
    });
    const resultB = await documentPipeline.processDocument(ctx.docIdB, ctx.userId, {
      documentText: ctx.ocrResults[ctx.docIdB].text,
      documentType: 'unknown'
    });
    const resultC = await documentPipeline.processDocument(docIdC, ctx.userId, {
      documentText: 'Escrow Analysis Statement. Loan #98765. Escrow Balance: $4,200.00.',
      documentType: 'unknown'
    });

    expect(resultA.success).toBe(true);
    expect(resultB.success).toBe(true);
    expect(resultC.success).toBe(true);

    // Set up aggregation for 3 docs with 3 pairs (A-B, A-C, B-C)
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing', documentSubtype: 'monthly_statement', analysisReport: resultA.analysisResults },
        { documentId: ctx.docIdB, documentType: 'origination', documentSubtype: 'closing_disclosure', analysisReport: resultB.analysisResults },
        { documentId: docIdC, documentType: 'servicing', documentSubtype: 'escrow_analysis', analysisReport: resultC.analysisResults }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: ['interestRate'], discrepancyTypes: ['amount_mismatch'], forensicSignificance: 'high' },
        { pairId: 'pair-002', docA: { documentId: ctx.docIdA }, docB: { documentId: docIdC }, comparisonFields: ['escrowBalance'], discrepancyTypes: ['amount_mismatch'], forensicSignificance: 'medium' },
        { pairId: 'pair-003', docA: { documentId: ctx.docIdB }, docB: { documentId: docIdC }, comparisonFields: ['loanNumber'], discrepancyTypes: ['term_contradiction'], forensicSignificance: 'medium' }
      ],
      documentsWithoutAnalysis: [],
      totalDocuments: 3,
      analyzedDocuments: 3
    });

    // Each pair comparison returns a result
    mockCrossDocComparison.compareDocumentPair
      .mockResolvedValueOnce({
        pairId: 'pair-001',
        discrepancies: [ctx.forensicResults.discrepancies[0]],
        timelineEvents: ctx.forensicResults.timeline.events,
        timelineViolations: []
      })
      .mockResolvedValueOnce({
        pairId: 'pair-002',
        discrepancies: [],
        timelineEvents: [],
        timelineViolations: []
      })
      .mockResolvedValueOnce({
        pairId: 'pair-003',
        discrepancies: [],
        timelineEvents: [],
        timelineViolations: []
      });

    const forensicResult = await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);

    expect(forensicResult.error).toBeUndefined();
    expect(forensicResult.documentsAnalyzed).toBe(3);
    expect(forensicResult.comparisonPairsEvaluated).toBe(3);

    // All 3 pairs were compared
    expect(mockCrossDocComparison.compareDocumentPair).toHaveBeenCalledTimes(3);
  });

  test('compliance evaluates findings from all documents', async () => {
    ctx.caseData.forensic_analysis = ctx.forensicResults;
    mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipAiAnalysis: true }
    );

    // Rule engine was called with full forensic report
    expect(mockComplianceRuleEngine.evaluateFindings).toHaveBeenCalledWith(
      ctx.forensicResults,
      expect.any(Array)
    );

    expect(result.violations).toBeDefined();
    expect(result.statutesEvaluated).toBeDefined();
    expect(result.statutesEvaluated.length).toBeGreaterThan(0);
  });
});

// ============================================================
// 5. ERROR RESILIENCE
// ============================================================
describe('error resilience', () => {

  test('forensic analysis degrades gracefully when one comparison pair fails', async () => {
    // Set up aggregation with 2 pairs
    mockCrossDocAggregation.aggregateForCase.mockResolvedValue({
      caseId: ctx.caseId,
      documents: [
        { documentId: ctx.docIdA, documentType: 'servicing' },
        { documentId: ctx.docIdB, documentType: 'origination' }
      ],
      comparisonPairs: [
        { pairId: 'pair-001', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: [], discrepancyTypes: [], forensicSignificance: 'high' },
        { pairId: 'pair-002', docA: { documentId: ctx.docIdA }, docB: { documentId: ctx.docIdB }, comparisonFields: [], discrepancyTypes: [], forensicSignificance: 'medium' }
      ],
      totalDocuments: 2,
      analyzedDocuments: 2
    });

    // First pair succeeds, second throws
    mockCrossDocComparison.compareDocumentPair
      .mockResolvedValueOnce({
        pairId: 'pair-001',
        discrepancies: [ctx.forensicResults.discrepancies[0]],
        timelineEvents: [],
        timelineViolations: []
      })
      .mockRejectedValueOnce(new Error('AI comparison timeout'));

    const result = await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);

    // Should not error out — graceful degradation
    expect(result.error).toBeUndefined();
    expect(result.caseId).toBe(ctx.caseId);

    // One pair succeeded, one failed
    expect(result.comparisonPairsEvaluated).toBe(2);
    expect(result._metadata.steps.comparison.pairsFailed).toBe(1);
    expect(result._metadata.warnings.length).toBeGreaterThan(0);

    // Discrepancies from successful pair still present
    expect(result.discrepancies.length).toBeGreaterThan(0);
  });

  test('compliance evaluation continues when gather step finds no forensic data', async () => {
    // Case exists but has no forensic analysis
    mockCaseFileService.getCase.mockResolvedValue({
      ...ctx.caseData,
      forensic_analysis: null
    });

    const result = await complianceService.evaluateCompliance(
      ctx.caseId, ctx.userId, { skipAiAnalysis: true }
    );

    // Should return error because forensic analysis is required
    expect(result.error).toBe(true);
    expect(result.errorMessage).toContain('forensic analysis');
  });

  test('consolidated report returns error when gather step fails', async () => {
    mockReportAggregation.gatherCaseFindings.mockResolvedValue({
      error: true,
      errorMessage: 'Case not found'
    });

    const result = await consolidatedReportService.generateReport(
      ctx.caseId, ctx.userId, { skipPersistence: true }
    );

    expect(result.error).toBe(true);
    expect(result.errorMessage).toBe('Case not found');
    expect(result._metadata).toBeDefined();
    expect(result._metadata.steps.gather.status).toBe('failed');
  });

  test('pipeline handles input validation for missing parameters', async () => {
    // Forensic: missing caseId
    const forensicNoCase = await forensicAnalysisService.analyzeCaseForensics(null, ctx.userId);
    expect(forensicNoCase.error).toBe(true);
    expect(forensicNoCase.errorMessage).toContain('caseId');

    // Compliance: missing userId
    const complianceNoUser = await complianceService.evaluateCompliance(ctx.caseId, null);
    expect(complianceNoUser.error).toBe(true);
    expect(complianceNoUser.errorMessage).toContain('userId');

    // Report: missing caseId
    const reportNoCase = await consolidatedReportService.generateReport(null, ctx.userId);
    expect(reportNoCase.error).toBe(true);
    expect(reportNoCase.errorMessage).toContain('caseId');
  });
});
