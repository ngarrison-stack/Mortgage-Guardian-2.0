/**
 * Pipeline Performance Benchmark Tests
 *
 * Measures execution time of each pipeline orchestrator with mocked externals
 * and asserts completion within generous canary thresholds. These thresholds
 * catch order-of-magnitude regressions (e.g., accidental sync loops, N+1 queries)
 * but are NOT production performance targets.
 *
 * Since all external services are mocked, we measure internal orchestration
 * logic only. Thresholds are 10x expected time to prevent CI flakiness.
 *
 * Thresholds (with mocked externals):
 *   - processDocument: < 500ms per document
 *   - analyzeCaseForensics: < 500ms for a 2-document case
 *   - evaluateCompliance: < 500ms
 *   - generateReport: < 500ms
 *   - Full pipeline (all 4 stages): < 2000ms
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

const mockAnthropicCreate = jest.fn();
jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockAnthropicCreate }
  }));
});

jest.mock('pdf-parse', () => {
  return jest.fn().mockResolvedValue({
    text: 'Mock PDF text',
    numpages: 1,
    info: { Title: 'Mock' }
  });
});

const mockClaudeService = require('../mocks/mockClaudeService');
jest.mock('../../services/claudeService', () => mockClaudeService);

jest.mock('../../services/documentService', () => ({
  uploadDocument: jest.fn().mockResolvedValue({ documentId: 'doc-1', storagePath: 'mock/path' }),
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true }),
  getContentType: jest.fn().mockReturnValue('application/pdf')
}));

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

const mockCrossDocAggregation = { aggregateForCase: jest.fn() };
jest.mock('../../services/crossDocumentAggregationService', () => mockCrossDocAggregation);

const mockCrossDocComparison = { compareDocumentPair: jest.fn() };
jest.mock('../../services/crossDocumentComparisonService', () => mockCrossDocComparison);

const mockPlaidCrossRef = {
  extractPaymentsFromAnalysis: jest.fn().mockReturnValue([]),
  crossReferencePayments: jest.fn().mockReturnValue({
    matchedPayments: [], unmatchedDocumentPayments: [], unmatchedTransactions: [],
    summary: { totalDocumentPayments: 0, totalPlaidTransactions: 0, matched: 0, paymentVerified: true }
  })
};
jest.mock('../../services/plaidCrossReferenceService', () => mockPlaidCrossRef);

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

const mockDisputeLetter = { generateDisputeLetter: jest.fn() };
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

/**
 * Reset all mocks and create fresh pipeline context before each test.
 */
function resetMocks() {
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
}

beforeEach(() => {
  resetMocks();
});

// ============================================================
// HELPERS
// ============================================================

/**
 * Run a function 3 times and return the median duration in milliseconds.
 * Uses performance.now() for sub-millisecond precision.
 *
 * @param {Function} fn - Async function to measure
 * @returns {Promise<{ median: number, durations: number[] }>}
 */
async function measureMedian(fn) {
  const durations = [];

  for (let i = 0; i < 3; i++) {
    // Reset mocks between measurement runs to ensure clean state
    resetMocks();

    const start = performance.now();
    await fn();
    const end = performance.now();
    durations.push(end - start);
  }

  // Sort and take the median (index 1 of 3 sorted values)
  const sorted = [...durations].sort((a, b) => a - b);
  return { median: sorted[1], durations: sorted };
}

/**
 * Set up forensic analysis prerequisites on the context.
 * Updates caseData with forensic results for compliance step.
 */
function setupForensicPrereqs() {
  ctx.caseData.forensic_analysis = ctx.forensicResults;
  mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);
}

// ============================================================
// PERFORMANCE BENCHMARKS
// ============================================================

describe('performance benchmarks', () => {

  test('document pipeline (processDocument) completes within 500ms', async () => {
    const { median, durations } = await measureMedian(async () => {
      const result = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
        documentText: ctx.ocrResults[ctx.docIdA].text,
        documentType: 'unknown'
      });
      expect(result.success).toBe(true);
    });

    // Log for CI debugging
    console.log(`  processDocument durations: [${durations.map(d => d.toFixed(1)).join(', ')}] ms, median: ${median.toFixed(1)} ms`);

    expect(median).toBeLessThan(500);
  });

  test('forensic analysis (analyzeCaseForensics) completes within 500ms', async () => {
    const { median, durations } = await measureMedian(async () => {
      const result = await forensicAnalysisService.analyzeCaseForensics(
        ctx.caseId, ctx.userId
      );
      expect(result.error).toBeUndefined();
      expect(result.caseId).toBe(ctx.caseId);
    });

    console.log(`  analyzeCaseForensics durations: [${durations.map(d => d.toFixed(1)).join(', ')}] ms, median: ${median.toFixed(1)} ms`);

    expect(median).toBeLessThan(500);
  });

  test('compliance evaluation (evaluateCompliance) completes within 500ms', async () => {
    const { median, durations } = await measureMedian(async () => {
      setupForensicPrereqs();

      const result = await complianceService.evaluateCompliance(
        ctx.caseId, ctx.userId, { skipAiAnalysis: true }
      );
      expect(result.error).toBeUndefined();
      expect(result.caseId).toBe(ctx.caseId);
    });

    console.log(`  evaluateCompliance durations: [${durations.map(d => d.toFixed(1)).join(', ')}] ms, median: ${median.toFixed(1)} ms`);

    expect(median).toBeLessThan(500);
  });

  test('consolidated report (generateReport) completes within 500ms', async () => {
    const { median, durations } = await measureMedian(async () => {
      const result = await consolidatedReportService.generateReport(
        ctx.caseId, ctx.userId, { generateLetter: true, skipPersistence: true }
      );
      expect(result.error).toBeUndefined();
      expect(result.caseId).toBe(ctx.caseId);
    });

    console.log(`  generateReport durations: [${durations.map(d => d.toFixed(1)).join(', ')}] ms, median: ${median.toFixed(1)} ms`);

    expect(median).toBeLessThan(500);
  });

  test('full pipeline (intake through report) completes within 2000ms', async () => {
    const { median, durations } = await measureMedian(async () => {
      // Stage 1: Document intake + analysis (2 documents)
      const resultA = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
        documentText: ctx.ocrResults[ctx.docIdA].text,
        documentType: 'unknown'
      });
      expect(resultA.success).toBe(true);

      const resultB = await documentPipeline.processDocument(ctx.docIdB, ctx.userId, {
        documentText: ctx.ocrResults[ctx.docIdB].text,
        documentType: 'unknown'
      });
      expect(resultB.success).toBe(true);

      // Stage 2: Forensic analysis
      const forensicResult = await forensicAnalysisService.analyzeCaseForensics(
        ctx.caseId, ctx.userId
      );
      expect(forensicResult.error).toBeUndefined();

      // Stage 3: Compliance evaluation
      ctx.caseData.forensic_analysis = forensicResult;
      mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);

      const complianceResult = await complianceService.evaluateCompliance(
        ctx.caseId, ctx.userId, { skipAiAnalysis: true }
      );
      expect(complianceResult.error).toBeUndefined();

      // Stage 4: Consolidated report
      ctx.caseData.compliance_report = complianceResult;

      const report = await consolidatedReportService.generateReport(
        ctx.caseId, ctx.userId, { generateLetter: true, skipPersistence: true }
      );
      expect(report.error).toBeUndefined();
      expect(report.reportId).toBeDefined();
    });

    console.log(`  full pipeline durations: [${durations.map(d => d.toFixed(1)).join(', ')}] ms, median: ${median.toFixed(1)} ms`);

    expect(median).toBeLessThan(2000);
  });
});
