/**
 * Unit tests for ForensicAnalysisService
 *
 * Tests the forensic analysis orchestrator — all dependent services are mocked
 * at the module boundary (aggregation, comparison, plaidCrossReference, plaid).
 */

// ---------------------------------------------------------------------------
// Mocks — hoisted before require()
// ---------------------------------------------------------------------------

jest.mock('../../services/crossDocumentAggregationService', () => ({
  aggregateForCase: jest.fn()
}));

jest.mock('../../services/crossDocumentComparisonService', () => ({
  compareDocumentPair: jest.fn()
}));

jest.mock('../../services/plaidCrossReferenceService', () => ({
  extractPaymentsFromAnalysis: jest.fn(),
  crossReferencePayments: jest.fn()
}));

jest.mock('../../services/plaidService', () => ({
  getTransactions: jest.fn()
}));

jest.mock('../../services/caseFileService', () => ({
  updateCase: jest.fn().mockResolvedValue({})
}));

// Mock Anthropic SDK (required by crossDocumentComparisonService at import time)
jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: jest.fn() }
  }));
});

const forensicAnalysisService = require('../../services/forensicAnalysisService');
const aggregationService = require('../../services/crossDocumentAggregationService');
const comparisonService = require('../../services/crossDocumentComparisonService');
const plaidCrossRefService = require('../../services/plaidCrossReferenceService');
const plaidService = require('../../services/plaidService');
const caseFileService = require('../../services/caseFileService');

// ---------------------------------------------------------------------------
// Mock data factories
// ---------------------------------------------------------------------------

function mockAggregationResult(overrides = {}) {
  return {
    caseId: 'case-001',
    documents: [
      {
        documentId: 'doc-001',
        documentType: 'servicing',
        documentSubtype: 'monthly_statement',
        analysisReport: { documentInfo: { documentType: 'servicing' }, extractedData: { amounts: { monthlyPayment: 1500 } } },
        extractedData: { amounts: { monthlyPayment: 1500 } },
        anomalies: [],
        completeness: { score: 90 },
        analyzedAt: '2024-01-15T00:00:00Z'
      },
      {
        documentId: 'doc-002',
        documentType: 'origination',
        documentSubtype: 'closing_disclosure',
        analysisReport: { documentInfo: { documentType: 'origination' }, extractedData: { amounts: { loanAmount: 250000 } } },
        extractedData: { amounts: { loanAmount: 250000 } },
        anomalies: [],
        completeness: { score: 92 },
        analyzedAt: '2024-01-10T00:00:00Z'
      }
    ],
    comparisonPairs: [
      {
        pairId: 'stmt-vs-closing',
        docA: { documentId: 'doc-001', documentType: 'servicing', documentSubtype: 'monthly_statement' },
        docB: { documentId: 'doc-002', documentType: 'origination', documentSubtype: 'closing_disclosure' },
        comparisonFields: ['amounts', 'rates'],
        discrepancyTypes: ['amount_mismatch', 'term_contradiction'],
        forensicSignificance: 'high'
      }
    ],
    documentsWithoutAnalysis: [],
    totalDocuments: 2,
    analyzedDocuments: 2,
    ...overrides
  };
}

function mockComparisonResult(overrides = {}) {
  return {
    pairId: 'stmt-vs-closing',
    documentA: { documentId: 'doc-001', documentType: 'servicing', documentSubtype: 'monthly_statement' },
    documentB: { documentId: 'doc-002', documentType: 'origination', documentSubtype: 'closing_disclosure' },
    discrepancies: [
      {
        id: 'disc-001',
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Monthly payment differs from closing disclosure',
        documentA: { field: 'monthlyPayment', value: 1500 },
        documentB: { field: 'monthlyPayment', value: 1498.23 }
      }
    ],
    timelineEvents: [
      {
        date: '2024-01-15',
        documentId: 'doc-001',
        documentType: 'servicing',
        event: 'Statement issued',
        significance: 'routine'
      }
    ],
    timelineViolations: [],
    comparisonSummary: 'Payment amount differs slightly',
    ...overrides
  };
}

function mockPlaidTransactions() {
  return {
    transactions: [
      { transactionId: 'txn-001', amount: 1500, date: '2024-01-01', name: 'MORTGAGE', category: ['Payment'], pending: false },
      { transactionId: 'txn-002', amount: 1500, date: '2024-02-01', name: 'MORTGAGE', category: ['Payment'], pending: false }
    ],
    totalTransactions: 2,
    accounts: []
  };
}

function mockCrossReferenceResult(overrides = {}) {
  return {
    matchedPayments: [
      { documentDate: '2024-01-01', documentAmount: 1500, transactionDate: '2024-01-01', transactionAmount: 1500, status: 'matched', variance: 0 }
    ],
    unmatchedDocumentPayments: [],
    unmatchedTransactions: [
      { date: '2024-02-01', amount: 1500, transactionId: 'txn-002', name: 'MORTGAGE', possibleMatch: null }
    ],
    escrowAnalysis: null,
    feeAnalysis: null,
    summary: {
      totalDocumentPayments: 1,
      totalPlaidTransactions: 2,
      matched: 1,
      closeMatches: 0,
      unmatched: 0,
      paymentVerified: true
    },
    ...overrides
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ForensicAnalysisService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('analyzeCaseForensics', () => {

    // =====================================================================
    // Aggregation step
    // =====================================================================
    describe('aggregation step', () => {

      test('should call aggregationService with caseId and userId', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());

        await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(aggregationService.aggregateForCase).toHaveBeenCalledWith('case-001', 'user-001');
      });

      test('should return error when case not found', async () => {
        aggregationService.aggregateForCase.mockRejectedValue(new Error('Case not found'));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-missing', 'user-001');

        expect(result.error).toBe(true);
        expect(result.errorMessage).toBe('Case not found');
      });

      test('should return warning when fewer than 2 analyzed documents', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(
          mockAggregationResult({ analyzedDocuments: 1, comparisonPairs: [] })
        );

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.error).toBeUndefined();
        expect(result._metadata.warnings).toContain(
          'Insufficient analyzed documents for cross-document comparison'
        );
        expect(result.discrepancies).toEqual([]);
        expect(result.comparisonPairsEvaluated).toBe(0);
      });

      test('should proceed with 2+ analyzed documents', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.caseId).toBe('case-001');
        expect(result.documentsAnalyzed).toBe(2);
        expect(result.discrepancies.length).toBeGreaterThan(0);
      });
    });

    // =====================================================================
    // Comparison step
    // =====================================================================
    describe('comparison step', () => {

      test('should call comparisonService for each comparison pair', async () => {
        const agg = mockAggregationResult();
        agg.comparisonPairs.push({
          pairId: 'stmt-vs-stmt',
          docA: { documentId: 'doc-001', documentType: 'servicing', documentSubtype: 'monthly_statement' },
          docB: { documentId: 'doc-002', documentType: 'origination', documentSubtype: 'closing_disclosure' },
          comparisonFields: ['amounts'],
          discrepancyTypes: ['amount_mismatch'],
          forensicSignificance: 'high'
        });
        aggregationService.aggregateForCase.mockResolvedValue(agg);
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());

        await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(comparisonService.compareDocumentPair).toHaveBeenCalledTimes(2);
      });

      test('should collect discrepancies from all pair comparisons', async () => {
        const agg = mockAggregationResult();
        agg.comparisonPairs.push({
          pairId: 'stmt-vs-stmt',
          docA: { documentId: 'doc-001' },
          docB: { documentId: 'doc-002' },
          comparisonFields: ['amounts'],
          discrepancyTypes: ['amount_mismatch'],
          forensicSignificance: 'high'
        });
        aggregationService.aggregateForCase.mockResolvedValue(agg);

        // Two different comparisons with different discrepancies
        comparisonService.compareDocumentPair
          .mockResolvedValueOnce(mockComparisonResult())
          .mockResolvedValueOnce(mockComparisonResult({
            discrepancies: [{
              id: 'disc-002',
              type: 'fee_irregularity',
              severity: 'medium',
              description: 'Unexplained fee',
              documentA: { field: 'fee', value: 50 },
              documentB: { field: 'fee', value: 0 }
            }]
          }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.discrepancies.length).toBe(2);
      });

      test('should continue when individual comparison fails (graceful degradation)', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(
          mockComparisonResult({ error: true, errorMessage: 'API timeout', discrepancies: [] })
        );

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.error).toBeUndefined();
        expect(result._metadata.warnings.length).toBeGreaterThan(0);
        expect(result._metadata.steps.comparison.pairsFailed).toBe(1);
      });

      test('should deduplicate discrepancies with same field+documents', async () => {
        const agg = mockAggregationResult();
        agg.comparisonPairs.push({
          pairId: 'stmt-vs-stmt',
          docA: { documentId: 'doc-001' },
          docB: { documentId: 'doc-002' },
          comparisonFields: ['amounts'],
          discrepancyTypes: ['amount_mismatch'],
          forensicSignificance: 'high'
        });
        aggregationService.aggregateForCase.mockResolvedValue(agg);

        const sameDisc = {
          id: 'disc-001',
          type: 'amount_mismatch',
          severity: 'high',
          description: 'Same field mismatch',
          documentA: { field: 'monthlyPayment', value: 1500 },
          documentB: { field: 'monthlyPayment', value: 1498 }
        };

        comparisonService.compareDocumentPair
          .mockResolvedValueOnce(mockComparisonResult({ discrepancies: [sameDisc] }))
          .mockResolvedValueOnce(mockComparisonResult({
            discrepancies: [{ ...sameDisc, severity: 'critical', description: 'Critical version' }]
          }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        // Should keep the critical one (higher severity)
        expect(result.discrepancies.length).toBe(1);
        expect(result.discrepancies[0].severity).toBe('critical');
      });

      test('should assign sequential discrepancy IDs across pairs', async () => {
        const agg = mockAggregationResult();
        agg.comparisonPairs.push({
          pairId: 'stmt-vs-stmt',
          docA: { documentId: 'doc-001' },
          docB: { documentId: 'doc-002' },
          comparisonFields: ['amounts'],
          discrepancyTypes: ['fee_irregularity'],
          forensicSignificance: 'high'
        });
        aggregationService.aggregateForCase.mockResolvedValue(agg);

        comparisonService.compareDocumentPair
          .mockResolvedValueOnce(mockComparisonResult())
          .mockResolvedValueOnce(mockComparisonResult({
            discrepancies: [{
              id: 'old-id',
              type: 'fee_irregularity',
              severity: 'medium',
              description: 'Different field',
              documentA: { field: 'lateFee', value: 50 },
              documentB: { field: 'lateFee', value: 0 }
            }]
          }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.discrepancies[0].id).toBe('disc-001');
        expect(result.discrepancies[1].id).toBe('disc-002');
      });

      test('should merge timeline events from all comparisons sorted by date', async () => {
        const agg = mockAggregationResult();
        agg.comparisonPairs.push({
          pairId: 'stmt-vs-stmt',
          docA: { documentId: 'doc-001' },
          docB: { documentId: 'doc-002' },
          comparisonFields: ['amounts'],
          discrepancyTypes: ['amount_mismatch'],
          forensicSignificance: 'high'
        });
        aggregationService.aggregateForCase.mockResolvedValue(agg);

        comparisonService.compareDocumentPair
          .mockResolvedValueOnce(mockComparisonResult({
            timelineEvents: [{ date: '2024-03-01', documentId: 'doc-001', documentType: 'servicing', event: 'Late event', significance: 'routine' }]
          }))
          .mockResolvedValueOnce(mockComparisonResult({
            timelineEvents: [{ date: '2024-01-01', documentId: 'doc-002', documentType: 'origination', event: 'Early event', significance: 'notable' }]
          }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.timeline.events[0].date).toBe('2024-01-01');
        expect(result.timeline.events[result.timeline.events.length - 1].date).toBe('2024-03-01');
      });
    });

    // =====================================================================
    // Plaid cross-reference step
    // =====================================================================
    describe('Plaid cross-reference step', () => {

      test('should skip when no plaidAccessToken provided', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(plaidService.getTransactions).not.toHaveBeenCalled();
        expect(result.paymentVerification).toBeNull();
        expect(result._metadata.steps.plaidCrossReference.status).toBe('skipped');
      });

      test('should call plaidService.getTransactions when token provided', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());
        plaidService.getTransactions.mockResolvedValue(mockPlaidTransactions());
        plaidCrossRefService.extractPaymentsFromAnalysis.mockReturnValue([]);
        plaidCrossRefService.crossReferencePayments.mockReturnValue(mockCrossReferenceResult());

        await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001', {
          plaidAccessToken: 'access-test-token'
        });

        expect(plaidService.getTransactions).toHaveBeenCalledWith(
          expect.objectContaining({ accessToken: 'access-test-token' })
        );
      });

      test('should call plaidCrossReference.crossReferencePayments with extracted payments', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());
        plaidService.getTransactions.mockResolvedValue(mockPlaidTransactions());

        const extractedPayments = [{ date: '2024-01-01', amount: 1500, documentId: 'doc-001' }];
        plaidCrossRefService.extractPaymentsFromAnalysis.mockReturnValue(extractedPayments);
        plaidCrossRefService.crossReferencePayments.mockReturnValue(mockCrossReferenceResult());

        await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001', {
          plaidAccessToken: 'access-test-token'
        });

        expect(plaidCrossRefService.crossReferencePayments).toHaveBeenCalledWith(
          extractedPayments,
          mockPlaidTransactions().transactions,
          {}
        );
      });

      test('should set paymentVerification to null when Plaid call fails', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());
        plaidService.getTransactions.mockRejectedValue(new Error('Plaid API down'));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001', {
          plaidAccessToken: 'access-test-token'
        });

        expect(result.paymentVerification).toBeNull();
        expect(result._metadata.steps.plaidCrossReference.status).toBe('failed');
        expect(result._metadata.warnings).toEqual(
          expect.arrayContaining([expect.stringContaining('Plaid cross-reference failed')])
        );
      });

      test('should use custom date range when provided', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());
        plaidService.getTransactions.mockResolvedValue(mockPlaidTransactions());
        plaidCrossRefService.extractPaymentsFromAnalysis.mockReturnValue([]);
        plaidCrossRefService.crossReferencePayments.mockReturnValue(mockCrossReferenceResult());

        await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001', {
          plaidAccessToken: 'access-test-token',
          transactionDateRange: { start: '2023-06-01', end: '2024-06-01' }
        });

        expect(plaidService.getTransactions).toHaveBeenCalledWith(
          expect.objectContaining({ startDate: '2023-06-01', endDate: '2024-06-01' })
        );
      });

      test('should use custom tolerances when provided', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());
        plaidService.getTransactions.mockResolvedValue(mockPlaidTransactions());
        plaidCrossRefService.extractPaymentsFromAnalysis.mockReturnValue([]);
        plaidCrossRefService.crossReferencePayments.mockReturnValue(mockCrossReferenceResult());

        await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001', {
          plaidAccessToken: 'access-test-token',
          dateTolerance: 10,
          amountTolerance: 5.00
        });

        expect(plaidCrossRefService.crossReferencePayments).toHaveBeenCalledWith(
          expect.anything(),
          expect.anything(),
          { dateTolerance: 10, amountTolerance: 5.00 }
        );
      });
    });

    // =====================================================================
    // Consolidation step
    // =====================================================================
    describe('consolidation step', () => {

      test('should calculate correct summary totals', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult({
          discrepancies: [
            { id: 'd1', type: 'amount_mismatch', severity: 'critical', description: 'Critical one', documentA: { field: 'a', value: 1 }, documentB: { field: 'a', value: 2 } },
            { id: 'd2', type: 'fee_irregularity', severity: 'high', description: 'High one', documentA: { field: 'b', value: 1 }, documentB: { field: 'b', value: 2 } },
            { id: 'd3', type: 'date_inconsistency', severity: 'medium', description: 'Medium one', documentA: { field: 'c', value: 1 }, documentB: { field: 'c', value: 2 } }
          ]
        }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.summary.totalDiscrepancies).toBe(3);
        expect(result.summary.criticalFindings).toBe(1);
        expect(result.summary.highFindings).toBe(1);
      });

      test('should set riskLevel to "critical" when critical findings exist', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult({
          discrepancies: [
            { id: 'd1', type: 'amount_mismatch', severity: 'critical', description: 'Critical', documentA: { field: 'a', value: 1 }, documentB: { field: 'a', value: 2 } }
          ]
        }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');
        expect(result.summary.riskLevel).toBe('critical');
      });

      test('should set riskLevel to "high" when high findings exist (no critical)', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult({
          discrepancies: [
            { id: 'd1', type: 'amount_mismatch', severity: 'high', description: 'High', documentA: { field: 'a', value: 1 }, documentB: { field: 'a', value: 2 } }
          ]
        }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');
        expect(result.summary.riskLevel).toBe('high');
      });

      test('should set riskLevel to "medium" when only medium findings', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult({
          discrepancies: [
            { id: 'd1', type: 'date_inconsistency', severity: 'medium', description: 'Medium', documentA: { field: 'a', value: 1 }, documentB: { field: 'a', value: 2 } }
          ]
        }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');
        expect(result.summary.riskLevel).toBe('medium');
      });

      test('should set riskLevel to "low" when no significant findings', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult({
          discrepancies: []
        }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');
        expect(result.summary.riskLevel).toBe('low');
      });

      test('should generate recommendations based on discrepancy types', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult({
          discrepancies: [
            { id: 'd1', type: 'amount_mismatch', severity: 'high', description: 'Amount issue', documentA: { field: 'a', value: 1 }, documentB: { field: 'b', value: 2 } },
            { id: 'd2', type: 'fee_irregularity', severity: 'medium', description: 'Fee issue', documentA: { field: 'c', value: 3 }, documentB: { field: 'd', value: 4 } }
          ]
        }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.summary.recommendations).toContain(
          'Request detailed payment application history from servicer'
        );
        expect(result.summary.recommendations).toContain(
          'Request itemized fee breakdown and supporting documentation per RESPA Section 6'
        );
      });

      test('should deduplicate recommendations', async () => {
        const agg = mockAggregationResult();
        agg.comparisonPairs.push({
          pairId: 'stmt-vs-stmt',
          docA: { documentId: 'doc-001' },
          docB: { documentId: 'doc-002' },
          comparisonFields: ['amounts'],
          discrepancyTypes: ['amount_mismatch'],
          forensicSignificance: 'high'
        });
        aggregationService.aggregateForCase.mockResolvedValue(agg);

        // Both pairs return amount_mismatch discrepancies with different fields
        comparisonService.compareDocumentPair
          .mockResolvedValueOnce(mockComparisonResult({
            discrepancies: [{ id: 'd1', type: 'amount_mismatch', severity: 'high', description: 'Issue 1', documentA: { field: 'a', value: 1 }, documentB: { field: 'b', value: 2 } }]
          }))
          .mockResolvedValueOnce(mockComparisonResult({
            discrepancies: [{ id: 'd2', type: 'amount_mismatch', severity: 'high', description: 'Issue 2', documentA: { field: 'x', value: 3 }, documentB: { field: 'y', value: 4 } }]
          }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        // Same recommendation should only appear once
        const amountRecs = result.summary.recommendations.filter(r =>
          r === 'Request detailed payment application history from servicer'
        );
        expect(amountRecs.length).toBe(1);
      });

      test('should include Plaid findings in keyFindings when available', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult({ discrepancies: [] }));
        plaidService.getTransactions.mockResolvedValue(mockPlaidTransactions());
        plaidCrossRefService.extractPaymentsFromAnalysis.mockReturnValue([]);
        plaidCrossRefService.crossReferencePayments.mockReturnValue(mockCrossReferenceResult({
          unmatchedDocumentPayments: [
            { date: '2024-03-01', amount: 1500, documentId: 'doc-001', description: 'Payment', reason: 'no_matching_transaction' }
          ],
          summary: { totalDocumentPayments: 1, totalPlaidTransactions: 2, matched: 0, closeMatches: 0, unmatched: 1, paymentVerified: false }
        }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001', {
          plaidAccessToken: 'access-test-token'
        });

        const plaidFinding = result.summary.keyFindings.find(f => f.includes('not found in bank records'));
        expect(plaidFinding).toBeDefined();
      });

      test('should validate against schema (attach warnings, do not reject)', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        // Result should always be returned regardless of validation
        expect(result.caseId).toBe('case-001');
        expect(result.summary).toBeDefined();
        // If there are validation warnings they should be in _metadata.warnings
        expect(Array.isArray(result._metadata.warnings)).toBe(true);
      });
    });

    // =====================================================================
    // Metadata tracking
    // =====================================================================
    describe('metadata tracking', () => {

      test('should record duration for each step', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result._metadata.duration).toBeGreaterThanOrEqual(0);
        expect(result._metadata.steps.aggregation.duration).toBeGreaterThanOrEqual(0);
        expect(result._metadata.steps.comparison.duration).toBeGreaterThanOrEqual(0);
        expect(result._metadata.steps.consolidation.duration).toBeGreaterThanOrEqual(0);
      });

      test('should track pairs compared and pairs failed', async () => {
        const agg = mockAggregationResult();
        agg.comparisonPairs.push({
          pairId: 'stmt-vs-stmt',
          docA: { documentId: 'doc-001' },
          docB: { documentId: 'doc-002' },
          comparisonFields: ['amounts'],
          discrepancyTypes: ['amount_mismatch'],
          forensicSignificance: 'high'
        });
        aggregationService.aggregateForCase.mockResolvedValue(agg);

        comparisonService.compareDocumentPair
          .mockResolvedValueOnce(mockComparisonResult())
          .mockResolvedValueOnce(mockComparisonResult({ error: true, errorMessage: 'Timeout', discrepancies: [] }));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result._metadata.steps.comparison.pairsCompared).toBe(2);
        expect(result._metadata.steps.comparison.pairsFailed).toBe(1);
      });

      test('should record Plaid step status (completed/skipped/failed)', async () => {
        // Skipped case
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());

        const skipped = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');
        expect(skipped._metadata.steps.plaidCrossReference.status).toBe('skipped');

        // Completed case
        plaidService.getTransactions.mockResolvedValue(mockPlaidTransactions());
        plaidCrossRefService.extractPaymentsFromAnalysis.mockReturnValue([]);
        plaidCrossRefService.crossReferencePayments.mockReturnValue(mockCrossReferenceResult());

        const completed = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001', {
          plaidAccessToken: 'access-test-token'
        });
        expect(completed._metadata.steps.plaidCrossReference.status).toBe('completed');

        // Failed case
        plaidService.getTransactions.mockRejectedValue(new Error('API error'));

        const failed = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001', {
          plaidAccessToken: 'access-test-token'
        });
        expect(failed._metadata.steps.plaidCrossReference.status).toBe('failed');
      });
    });

    // =====================================================================
    // Error handling
    // =====================================================================
    describe('error handling', () => {

      test('should return error object for missing caseId', async () => {
        const result = await forensicAnalysisService.analyzeCaseForensics(null, 'user-001');

        expect(result.error).toBe(true);
        expect(result.errorMessage).toContain('caseId');
      });

      test('should return error object for missing userId', async () => {
        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', null);

        expect(result.error).toBe(true);
        expect(result.errorMessage).toContain('userId');
      });

      test('should handle aggregation service throwing (catch and return error)', async () => {
        aggregationService.aggregateForCase.mockRejectedValue(new Error('Database connection failed'));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.error).toBe(true);
        expect(result.errorMessage).toBe('Database connection failed');
        expect(result._metadata).toBeDefined();
      });

      test('should handle all comparisons failing (return partial result with warnings)', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockRejectedValue(new Error('Service unavailable'));

        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        // Should still return a result, not throw
        expect(result.caseId).toBe('case-001');
        expect(result._metadata.steps.comparison.pairsFailed).toBe(1);
        expect(result._metadata.warnings.length).toBeGreaterThan(0);
        expect(result.discrepancies).toEqual([]);
      });

      test('should handle Supabase persistence failure gracefully', async () => {
        aggregationService.aggregateForCase.mockResolvedValue(mockAggregationResult());
        comparisonService.compareDocumentPair.mockResolvedValue(mockComparisonResult());
        caseFileService.updateCase.mockRejectedValue(new Error('Supabase timeout'));

        // Should not throw
        const result = await forensicAnalysisService.analyzeCaseForensics('case-001', 'user-001');

        expect(result.caseId).toBe('case-001');
        expect(result.summary).toBeDefined();
      });
    });
  });
});
