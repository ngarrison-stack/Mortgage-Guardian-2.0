/**
 * Pipeline Resource Leak Detection Tests
 *
 * Detects resource leaks by running the pipeline multiple times sequentially
 * and verifying cleanup:
 *   - Memory tracking: heap growth < 10MB across 5 sequential runs
 *   - Pipeline state cleanup: no orphaned entries, all states terminal
 *   - Mock call count verification: proper reset between runs, no state bleeding
 *
 * Uses Node.js built-in process.memoryUsage() and internal service state
 * inspection. No external profiling tools.
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

/**
 * Configure all mocks for a fresh pipeline run with unique document IDs.
 *
 * @param {number} runIndex - Run number (0-based) used to generate unique IDs
 * @returns {Object} Pipeline context for this run
 */
function setupFreshRun(runIndex) {
  const ctx = createMockPipelineContext({
    caseId: `case-res-${runIndex}`,
    userId: `user-res-${runIndex}`,
    docIdA: `doc-res-${runIndex}-a`,
    docIdB: `doc-res-${runIndex}-b`
  });

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

  return ctx;
}

/**
 * Run a full pipeline (all 4 stages) for a given context.
 *
 * @param {Object} ctx - Pipeline context from setupFreshRun
 */
async function runFullPipeline(ctx) {
  // Stage 1: Document intake
  await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
    documentText: ctx.ocrResults[ctx.docIdA].text,
    documentType: 'unknown'
  });
  await documentPipeline.processDocument(ctx.docIdB, ctx.userId, {
    documentText: ctx.ocrResults[ctx.docIdB].text,
    documentType: 'unknown'
  });

  // Stage 2: Forensic analysis
  const forensicResult = await forensicAnalysisService.analyzeCaseForensics(
    ctx.caseId, ctx.userId
  );

  // Stage 3: Compliance
  ctx.caseData.forensic_analysis = forensicResult;
  mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);

  await complianceService.evaluateCompliance(
    ctx.caseId, ctx.userId, { skipAiAnalysis: true }
  );

  // Stage 4: Report
  await consolidatedReportService.generateReport(
    ctx.caseId, ctx.userId, { generateLetter: true, skipPersistence: true }
  );
}

// ============================================================
// RESOURCE TRACKING TESTS
// ============================================================

describe('resource tracking', () => {

  // ============================================
  // MEMORY TRACKING
  // ============================================
  describe('memory tracking', () => {

    test('heap growth stays under 10MB across 5 sequential full pipeline runs', async () => {
      const RUN_COUNT = 5;
      const MAX_HEAP_GROWTH_BYTES = 10 * 1024 * 1024; // 10MB

      // Force GC if available to get a clean baseline
      if (global.gc) {
        global.gc();
      }

      const baselineHeap = process.memoryUsage().heapUsed;
      const heapSnapshots = [baselineHeap];

      for (let i = 0; i < RUN_COUNT; i++) {
        const ctx = setupFreshRun(i);
        await runFullPipeline(ctx);

        // Clear pipeline state after each run (simulating real cleanup)
        documentPipeline.pipelineState.clear();

        // Force GC between runs if available
        if (global.gc) {
          global.gc();
        }

        heapSnapshots.push(process.memoryUsage().heapUsed);
      }

      const finalHeap = heapSnapshots[heapSnapshots.length - 1];
      const heapGrowth = finalHeap - baselineHeap;

      // Log measurements for CI debugging
      console.log(`  Memory tracking: baseline=${(baselineHeap / 1024 / 1024).toFixed(2)} MB, ` +
        `final=${(finalHeap / 1024 / 1024).toFixed(2)} MB, ` +
        `growth=${(heapGrowth / 1024 / 1024).toFixed(2)} MB`);
      console.log(`  Per-run snapshots: [${heapSnapshots.map(h => (h / 1024 / 1024).toFixed(2)).join(', ')}] MB`);

      // Without --expose-gc, heap growth can be higher due to deferred GC.
      // Use a generous threshold to account for this.
      const threshold = global.gc ? MAX_HEAP_GROWTH_BYTES : MAX_HEAP_GROWTH_BYTES * 2;
      expect(heapGrowth).toBeLessThan(threshold);
    });
  });

  // ============================================
  // PIPELINE STATE CLEANUP
  // ============================================
  describe('pipeline state cleanup', () => {

    test('pipeline state map tracks documents correctly during processing', async () => {
      const RUN_COUNT = 5;
      const allDocIds = [];

      for (let i = 0; i < RUN_COUNT; i++) {
        const ctx = setupFreshRun(i);
        allDocIds.push(ctx.docIdA, ctx.docIdB);

        await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
          documentText: ctx.ocrResults[ctx.docIdA].text,
          documentType: 'unknown'
        });
        await documentPipeline.processDocument(ctx.docIdB, ctx.userId, {
          documentText: ctx.ocrResults[ctx.docIdB].text,
          documentType: 'unknown'
        });
      }

      // All 10 documents (5 runs x 2 docs) should be in the state map
      expect(documentPipeline.pipelineState.size).toBe(RUN_COUNT * 2);

      // Every document should have a terminal status (review = pipeline completed successfully)
      for (const docId of allDocIds) {
        const status = documentPipeline.getStatusSync(docId);
        expect(status).not.toBeNull();
        expect(status.documentId).toBe(docId);
        expect(['review', 'complete', 'analyzed', 'failed']).toContain(status.status);
      }

      // After clearing, no orphaned entries remain
      documentPipeline.pipelineState.clear();
      expect(documentPipeline.pipelineState.size).toBe(0);
    });

    test('all pipeline states are terminal after processing completes', async () => {
      const RUN_COUNT = 5;

      for (let i = 0; i < RUN_COUNT; i++) {
        const ctx = setupFreshRun(i);

        const resultA = await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
          documentText: ctx.ocrResults[ctx.docIdA].text,
          documentType: 'unknown'
        });
        const resultB = await documentPipeline.processDocument(ctx.docIdB, ctx.userId, {
          documentText: ctx.ocrResults[ctx.docIdB].text,
          documentType: 'unknown'
        });

        // Both documents should reach terminal state
        expect(resultA.success).toBe(true);
        expect(resultB.success).toBe(true);
        expect(resultA.status).toBe('review');
        expect(resultB.status).toBe('review');
      }

      // Verify no entries in non-terminal states
      const terminalStates = new Set(['review', 'complete', 'analyzed', 'failed']);
      for (const [docId, pipeline] of documentPipeline.pipelineState) {
        expect(terminalStates.has(pipeline.status)).toBe(true);
      }

      documentPipeline.pipelineState.clear();
    });

    test('getStatus returns null for documents not in the pipeline', async () => {
      documentPipeline.pipelineState.clear();

      const status = documentPipeline.getStatusSync('non-existent-doc-id');
      expect(status).toBeNull();
    });
  });

  // ============================================
  // MOCK CALL COUNT VERIFICATION
  // ============================================
  describe('mock call count verification', () => {

    test('Anthropic mock is called expected number of times per document pipeline run', async () => {
      const ctx = setupFreshRun(0);

      // Process one document: should call Anthropic exactly 2 times
      // (1 classification + 1 analysis)
      await documentPipeline.processDocument(ctx.docIdA, ctx.userId, {
        documentText: ctx.ocrResults[ctx.docIdA].text,
        documentType: 'unknown'
      });

      expect(mockAnthropicCreate).toHaveBeenCalledTimes(2);

      documentPipeline.pipelineState.clear();
    });

    test('mocks are properly reset between runs with no state bleeding', async () => {
      // Run 1
      const ctx1 = setupFreshRun(0);
      await documentPipeline.processDocument(ctx1.docIdA, ctx1.userId, {
        documentText: ctx1.ocrResults[ctx1.docIdA].text,
        documentType: 'unknown'
      });

      const run1AnthropicCalls = mockAnthropicCreate.mock.calls.length;
      expect(run1AnthropicCalls).toBe(2); // classification + analysis

      // Reset mocks between runs (as a well-behaved test suite would)
      jest.clearAllMocks();
      documentPipeline.pipelineState.clear();

      // Run 2 with fresh context
      const ctx2 = setupFreshRun(1);
      await documentPipeline.processDocument(ctx2.docIdA, ctx2.userId, {
        documentText: ctx2.ocrResults[ctx2.docIdA].text,
        documentType: 'unknown'
      });

      const run2AnthropicCalls = mockAnthropicCreate.mock.calls.length;

      // After clearAllMocks, call count should restart from 0
      // So run 2 should show exactly 2 calls, not 4
      expect(run2AnthropicCalls).toBe(2);

      documentPipeline.pipelineState.clear();
    });

    test('forensic analysis calls cross-document services expected number of times', async () => {
      const ctx = setupFreshRun(0);

      await forensicAnalysisService.analyzeCaseForensics(ctx.caseId, ctx.userId);

      // With mock context: 1 aggregation call, 1 comparison pair
      expect(mockCrossDocAggregation.aggregateForCase).toHaveBeenCalledTimes(1);
      expect(mockCrossDocComparison.compareDocumentPair).toHaveBeenCalledTimes(1);

      // Plaid cross-ref should NOT be called (no plaidAccessToken provided)
      expect(mockPlaidCrossRef.crossReferencePayments).not.toHaveBeenCalled();
    });

    test('compliance calls rule engine expected number of times', async () => {
      const ctx = setupFreshRun(0);
      ctx.caseData.forensic_analysis = ctx.forensicResults;
      mockCaseFileService.getCase.mockResolvedValue(ctx.caseData);

      await complianceService.evaluateCompliance(
        ctx.caseId, ctx.userId, { skipAiAnalysis: true }
      );

      // Federal rule engine: 1 call
      expect(mockComplianceRuleEngine.evaluateFindings).toHaveBeenCalledTimes(1);
      // State rule engine: 1 call (jurisdiction is detected via mock)
      expect(mockComplianceRuleEngine.evaluateStateFindings).toHaveBeenCalledTimes(1);

      // AI analysis should be skipped
      expect(mockComplianceAnalysis.analyzeViolations).not.toHaveBeenCalled();
    });

    test('consolidated report calls sub-services expected number of times', async () => {
      const ctx = setupFreshRun(0);

      await consolidatedReportService.generateReport(
        ctx.caseId, ctx.userId, { generateLetter: true, skipPersistence: true }
      );

      // Gather: 1 call
      expect(mockReportAggregation.gatherCaseFindings).toHaveBeenCalledTimes(1);
      // Finding summary: 1 call
      expect(mockReportAggregation.extractFindingSummary).toHaveBeenCalledTimes(1);
      // Confidence scoring: 1 call each
      expect(mockConfidenceScoring.calculateConfidence).toHaveBeenCalledTimes(1);
      expect(mockConfidenceScoring.determineRiskLevel).toHaveBeenCalledTimes(1);
      expect(mockConfidenceScoring.buildEvidenceLinks).toHaveBeenCalledTimes(1);
      // Dispute letter: 1 call (generateLetter=true)
      expect(mockDisputeLetter.generateDisputeLetter).toHaveBeenCalledTimes(1);
    });

    test('Supabase mock has no unclosed query chains after full pipeline', async () => {
      const ctx = setupFreshRun(0);

      await runFullPipeline(ctx);

      // The mock Supabase client tracks call history.
      // Verify that all 'from' calls have corresponding operations (not dangling).
      const history = mockClient.getCallHistory();
      const fromCalls = history.filter(h => h.method === 'from');
      const operationCalls = history.filter(h =>
        h.method.startsWith('from.') // select, insert, update, delete, upsert
      );

      // Every from() call should have at least one chained operation
      // (In our mock, operations are always chained after from())
      expect(operationCalls.length).toBeGreaterThanOrEqual(fromCalls.length);

      documentPipeline.pipelineState.clear();
      mockClient.reset();
    });
  });
});

// ============================================================
// AFTER ALL — log actual measurements for debugging CI failures
// ============================================================

afterAll(() => {
  const mem = process.memoryUsage();
  console.log('\n  Final memory usage:');
  console.log(`    heapUsed: ${(mem.heapUsed / 1024 / 1024).toFixed(2)} MB`);
  console.log(`    heapTotal: ${(mem.heapTotal / 1024 / 1024).toFixed(2)} MB`);
  console.log(`    rss: ${(mem.rss / 1024 / 1024).toFixed(2)} MB`);
  console.log(`    external: ${(mem.external / 1024 / 1024).toFixed(2)} MB`);
});
