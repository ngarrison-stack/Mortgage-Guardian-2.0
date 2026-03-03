/**
 * Unit tests for CrossDocumentAggregationService
 * (services/crossDocumentAggregationService.js)
 *
 * Tests aggregateForCase() — collecting analyzed documents in a case,
 * building normalized document records, and generating typed comparison pairs.
 *
 * Covers all 8 behavior cases from the TDD plan:
 * 1. Case with 3 analyzed monthly_statements -> 3 stmt-vs-stmt pairs (A-B, A-C, B-C)
 * 2. Case with 1 monthly_statement + 1 closing_disclosure -> 1 stmt-vs-closing pair
 * 3. Case with 1 document without analysis -> in documentsWithoutAnalysis, excluded from pairs
 * 4. Case with 0 or 1 analyzed documents -> empty comparisonPairs array
 * 5. Case with no documents -> throws "No documents found in case"
 * 6. Case not found -> throws "Case not found"
 * 7. Documents match multiple comparison pair types -> all matching pairs included
 * 8. Bidirectional pair matching works regardless of document order
 */

// ---------------------------------------------------------------------------
// Mocks — must be hoisted above require()
// ---------------------------------------------------------------------------

const mockGetCase = jest.fn();
const mockGetStatus = jest.fn();

jest.mock('../../services/caseFileService', () => ({
  getCase: mockGetCase
}));

jest.mock('../../services/documentPipelineService', () => ({
  getStatus: mockGetStatus
}));

const crossDocumentAggregationService = require('../../services/crossDocumentAggregationService');

// ---------------------------------------------------------------------------
// Test data helpers
// ---------------------------------------------------------------------------

/**
 * Create a mock analysis report conforming to the analysisReportSchema.
 */
function createMockAnalysisReport(overrides = {}) {
  return {
    documentInfo: {
      documentType: overrides.documentType || 'servicing',
      documentSubtype: overrides.documentSubtype || 'monthly_statement',
      analyzedAt: overrides.analyzedAt || '2025-01-15T10:00:00.000Z',
      modelUsed: 'claude-sonnet-4-5',
      confidence: 0.95
    },
    extractedData: overrides.extractedData || {
      dates: { statementDate: '2025-01-01', paymentDueDate: '2025-02-01' },
      amounts: { principalBalance: 245000, monthlyPayment: 1523.47 },
      rates: { interestRate: 6.5 },
      parties: { borrower: 'John Smith', servicer: 'Wells Fargo' },
      identifiers: { loanNumber: '****1234' },
      terms: {},
      custom: {}
    },
    anomalies: overrides.anomalies || [],
    completeness: overrides.completeness || {
      score: 85,
      totalExpectedFields: 12,
      presentFields: ['principalBalance', 'monthlyPayment', 'interestRate'],
      missingFields: ['escrowBalance'],
      missingCritical: []
    },
    summary: overrides.summary || {
      overview: 'Monthly statement analysis.',
      keyFindings: [],
      riskLevel: 'low',
      recommendations: []
    }
  };
}

/**
 * Create a mock Supabase document record as returned by caseFileService.getCase().
 */
function createMockDocument({
  documentId = 'doc-001',
  analysisResults = null,
  classificationType = null,
  classificationSubtype = null
} = {}) {
  return {
    document_id: documentId,
    user_id: 'user-123',
    case_id: 'case-001',
    file_name: `${documentId}.pdf`,
    document_type: 'mortgage_document',
    status: 'processed',
    analysis_results: analysisResults,
    metadata: {},
    created_at: '2025-01-01T00:00:00.000Z',
    updated_at: '2025-01-01T00:00:00.000Z'
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('CrossDocumentAggregationService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Default: pipeline returns null (no in-memory analysis)
    mockGetStatus.mockResolvedValue(null);
  });

  describe('aggregateForCase()', () => {

    // -----------------------------------------------------------------------
    // Case 1: 3 analyzed monthly_statements -> 3 stmt-vs-stmt pairs (A-B, A-C, B-C)
    // -----------------------------------------------------------------------
    test('generates 3 statement-vs-statement pairs from 3 analyzed monthly statements', async () => {
      const analysisA = createMockAnalysisReport({ documentType: 'servicing', documentSubtype: 'monthly_statement', analyzedAt: '2025-01-15T10:00:00.000Z' });
      const analysisB = createMockAnalysisReport({ documentType: 'servicing', documentSubtype: 'monthly_statement', analyzedAt: '2025-02-15T10:00:00.000Z' });
      const analysisC = createMockAnalysisReport({ documentType: 'servicing', documentSubtype: 'monthly_statement', analyzedAt: '2025-03-15T10:00:00.000Z' });

      mockGetCase.mockResolvedValue({
        id: 'case-001',
        user_id: 'user-123',
        case_name: 'Test Case',
        documents: [
          createMockDocument({ documentId: 'doc-A', analysisResults: analysisA }),
          createMockDocument({ documentId: 'doc-B', analysisResults: analysisB }),
          createMockDocument({ documentId: 'doc-C', analysisResults: analysisC })
        ]
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-001', 'user-123');

      expect(result.caseId).toBe('case-001');
      expect(result.totalDocuments).toBe(3);
      expect(result.analyzedDocuments).toBe(3);
      expect(result.documents).toHaveLength(3);
      expect(result.documentsWithoutAnalysis).toHaveLength(0);

      // N choose 2: 3 documents -> 3 pairs (A-B, A-C, B-C)
      expect(result.comparisonPairs).toHaveLength(3);

      // All pairs should be stmt-vs-stmt
      for (const pair of result.comparisonPairs) {
        expect(pair.pairId).toBe('stmt-vs-stmt');
        expect(pair.docA.documentType).toBe('servicing');
        expect(pair.docA.documentSubtype).toBe('monthly_statement');
        expect(pair.docB.documentType).toBe('servicing');
        expect(pair.docB.documentSubtype).toBe('monthly_statement');
        expect(pair.comparisonFields).toEqual(expect.arrayContaining(['amounts', 'dates', 'rates']));
        expect(pair.forensicSignificance).toBe('high');
      }

      // Verify all unique pairs are present
      const pairDocIds = result.comparisonPairs.map(p =>
        [p.docA.documentId, p.docB.documentId].sort().join('-')
      );
      expect(pairDocIds).toContain('doc-A-doc-B');
      expect(pairDocIds).toContain('doc-A-doc-C');
      expect(pairDocIds).toContain('doc-B-doc-C');
    });

    // -----------------------------------------------------------------------
    // Case 2: 1 monthly_statement + 1 closing_disclosure -> 1 stmt-vs-closing pair
    // -----------------------------------------------------------------------
    test('generates 1 stmt-vs-closing pair from statement and closing disclosure', async () => {
      const stmtAnalysis = createMockAnalysisReport({
        documentType: 'servicing',
        documentSubtype: 'monthly_statement'
      });
      const closingAnalysis = createMockAnalysisReport({
        documentType: 'origination',
        documentSubtype: 'closing_disclosure'
      });

      mockGetCase.mockResolvedValue({
        id: 'case-002',
        user_id: 'user-123',
        case_name: 'Test Case 2',
        documents: [
          createMockDocument({ documentId: 'doc-stmt', analysisResults: stmtAnalysis }),
          createMockDocument({ documentId: 'doc-closing', analysisResults: closingAnalysis })
        ]
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-002', 'user-123');

      expect(result.caseId).toBe('case-002');
      expect(result.totalDocuments).toBe(2);
      expect(result.analyzedDocuments).toBe(2);
      expect(result.comparisonPairs).toHaveLength(1);
      expect(result.comparisonPairs[0].pairId).toBe('stmt-vs-closing');
      expect(result.comparisonPairs[0].comparisonFields).toEqual(expect.arrayContaining(['rates', 'amounts']));
      expect(result.comparisonPairs[0].forensicSignificance).toBe('high');
    });

    // -----------------------------------------------------------------------
    // Case 3: 1 document without analysis -> in documentsWithoutAnalysis
    // -----------------------------------------------------------------------
    test('includes documents without analysis in documentsWithoutAnalysis and excludes from pairs', async () => {
      const stmtAnalysis = createMockAnalysisReport({
        documentType: 'servicing',
        documentSubtype: 'monthly_statement'
      });

      // Second document has no analysis_results and pipeline returns null
      mockGetCase.mockResolvedValue({
        id: 'case-003',
        user_id: 'user-123',
        case_name: 'Test Case 3',
        documents: [
          createMockDocument({ documentId: 'doc-analyzed', analysisResults: stmtAnalysis }),
          createMockDocument({ documentId: 'doc-no-analysis', analysisResults: null })
        ]
      });

      mockGetStatus.mockResolvedValue(null); // No in-memory analysis either

      const result = await crossDocumentAggregationService.aggregateForCase('case-003', 'user-123');

      expect(result.totalDocuments).toBe(2);
      expect(result.analyzedDocuments).toBe(1);
      expect(result.documentsWithoutAnalysis).toContain('doc-no-analysis');
      expect(result.documentsWithoutAnalysis).not.toContain('doc-analyzed');

      // Only 1 analyzed document, so no pairs possible
      expect(result.comparisonPairs).toHaveLength(0);

      // Verify document record for unanalyzed document
      const unanalyzedDoc = result.documents.find(d => d.documentId === 'doc-no-analysis');
      expect(unanalyzedDoc.analysisReport).toBeNull();
      expect(unanalyzedDoc.extractedData).toEqual({});
      expect(unanalyzedDoc.anomalies).toEqual([]);
      expect(unanalyzedDoc.completeness).toBeNull();
      expect(unanalyzedDoc.analyzedAt).toBeNull();
    });

    // -----------------------------------------------------------------------
    // Case 3 variant: pipeline fallback provides analysis for document
    // -----------------------------------------------------------------------
    test('falls back to pipeline getStatus for analysis when not in Supabase record', async () => {
      const pipelineAnalysis = createMockAnalysisReport({
        documentType: 'servicing',
        documentSubtype: 'monthly_statement'
      });

      mockGetCase.mockResolvedValue({
        id: 'case-003b',
        user_id: 'user-123',
        case_name: 'Test Case 3b',
        documents: [
          createMockDocument({ documentId: 'doc-pipeline', analysisResults: null }),
          createMockDocument({ documentId: 'doc-supabase', analysisResults: pipelineAnalysis })
        ]
      });

      // Pipeline has analysis for doc-pipeline
      mockGetStatus.mockImplementation(async (docId) => {
        if (docId === 'doc-pipeline') {
          return {
            documentId: 'doc-pipeline',
            status: 'analyzed',
            hasAnalysis: true,
            hasClassification: true,
            analysisResults: pipelineAnalysis,
            classificationResults: {
              classificationType: 'servicing',
              classificationSubtype: 'monthly_statement',
              confidence: 0.9
            }
          };
        }
        return null;
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-003b', 'user-123');

      expect(result.analyzedDocuments).toBe(2);
      expect(result.documentsWithoutAnalysis).toHaveLength(0);

      // Both are monthly_statements, should get 1 stmt-vs-stmt pair
      expect(result.comparisonPairs).toHaveLength(1);
      expect(result.comparisonPairs[0].pairId).toBe('stmt-vs-stmt');
    });

    // -----------------------------------------------------------------------
    // Case 4: 0 or 1 analyzed documents -> empty comparisonPairs
    // -----------------------------------------------------------------------
    test('returns empty comparisonPairs when only 1 analyzed document exists', async () => {
      const analysis = createMockAnalysisReport({
        documentType: 'servicing',
        documentSubtype: 'monthly_statement'
      });

      mockGetCase.mockResolvedValue({
        id: 'case-004',
        user_id: 'user-123',
        case_name: 'Test Case 4',
        documents: [
          createMockDocument({ documentId: 'doc-solo', analysisResults: analysis })
        ]
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-004', 'user-123');

      expect(result.totalDocuments).toBe(1);
      expect(result.analyzedDocuments).toBe(1);
      expect(result.comparisonPairs).toEqual([]);
    });

    test('returns empty comparisonPairs when 0 documents are analyzed', async () => {
      mockGetCase.mockResolvedValue({
        id: 'case-004b',
        user_id: 'user-123',
        case_name: 'Test Case 4b',
        documents: [
          createMockDocument({ documentId: 'doc-unanalyzed-1', analysisResults: null }),
          createMockDocument({ documentId: 'doc-unanalyzed-2', analysisResults: null })
        ]
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-004b', 'user-123');

      expect(result.totalDocuments).toBe(2);
      expect(result.analyzedDocuments).toBe(0);
      expect(result.comparisonPairs).toEqual([]);
      expect(result.documentsWithoutAnalysis).toHaveLength(2);
    });

    // -----------------------------------------------------------------------
    // Case 5: Case with no documents -> throws "No documents found in case"
    // -----------------------------------------------------------------------
    test('throws "No documents found in case" when case has empty documents array', async () => {
      mockGetCase.mockResolvedValue({
        id: 'case-005',
        user_id: 'user-123',
        case_name: 'Empty Case',
        documents: []
      });

      await expect(
        crossDocumentAggregationService.aggregateForCase('case-005', 'user-123')
      ).rejects.toThrow('No documents found in case');
    });

    // -----------------------------------------------------------------------
    // Case 6: Case not found -> throws "Case not found"
    // -----------------------------------------------------------------------
    test('throws "Case not found" when caseFileService.getCase returns null', async () => {
      mockGetCase.mockResolvedValue(null);

      await expect(
        crossDocumentAggregationService.aggregateForCase('nonexistent-case', 'user-123')
      ).rejects.toThrow('Case not found');
    });

    // -----------------------------------------------------------------------
    // Case 7: Documents match multiple comparison pair types
    // -----------------------------------------------------------------------
    test('includes all matching comparison pair types for documents', async () => {
      // A monthly_statement + a closing_disclosure + a promissory_note
      // This should produce:
      // - stmt-vs-closing (statement + closing_disclosure)
      // - closing-vs-note (closing_disclosure + promissory_note)
      const stmtAnalysis = createMockAnalysisReport({
        documentType: 'servicing',
        documentSubtype: 'monthly_statement'
      });
      const closingAnalysis = createMockAnalysisReport({
        documentType: 'origination',
        documentSubtype: 'closing_disclosure'
      });
      const noteAnalysis = createMockAnalysisReport({
        documentType: 'origination',
        documentSubtype: 'promissory_note'
      });

      mockGetCase.mockResolvedValue({
        id: 'case-007',
        user_id: 'user-123',
        case_name: 'Multi-Type Case',
        documents: [
          createMockDocument({ documentId: 'doc-stmt', analysisResults: stmtAnalysis }),
          createMockDocument({ documentId: 'doc-closing', analysisResults: closingAnalysis }),
          createMockDocument({ documentId: 'doc-note', analysisResults: noteAnalysis })
        ]
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-007', 'user-123');

      expect(result.totalDocuments).toBe(3);
      expect(result.analyzedDocuments).toBe(3);

      // Should have at least 2 pairs: stmt-vs-closing and closing-vs-note
      const pairIds = result.comparisonPairs.map(p => p.pairId);
      expect(pairIds).toContain('stmt-vs-closing');
      expect(pairIds).toContain('closing-vs-note');
      expect(result.comparisonPairs.length).toBeGreaterThanOrEqual(2);
    });

    // -----------------------------------------------------------------------
    // Case 8: Bidirectional pair matching regardless of document order
    // -----------------------------------------------------------------------
    test('bidirectional matching works regardless of document order', async () => {
      // Put closing_disclosure first, monthly_statement second
      // stmt-vs-closing is bidirectional, so should match even in reverse order
      const closingAnalysis = createMockAnalysisReport({
        documentType: 'origination',
        documentSubtype: 'closing_disclosure'
      });
      const stmtAnalysis = createMockAnalysisReport({
        documentType: 'servicing',
        documentSubtype: 'monthly_statement'
      });

      mockGetCase.mockResolvedValue({
        id: 'case-008',
        user_id: 'user-123',
        case_name: 'Reverse Order Case',
        documents: [
          createMockDocument({ documentId: 'doc-closing', analysisResults: closingAnalysis }),
          createMockDocument({ documentId: 'doc-stmt', analysisResults: stmtAnalysis })
        ]
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-008', 'user-123');

      expect(result.comparisonPairs).toHaveLength(1);
      expect(result.comparisonPairs[0].pairId).toBe('stmt-vs-closing');
      expect(result.comparisonPairs[0].docA).toEqual(expect.objectContaining({ documentId: expect.any(String) }));
      expect(result.comparisonPairs[0].docB).toEqual(expect.objectContaining({ documentId: expect.any(String) }));
    });

    // -----------------------------------------------------------------------
    // Output structure validation
    // -----------------------------------------------------------------------
    test('returns correct output structure with all expected fields', async () => {
      const analysis = createMockAnalysisReport({
        documentType: 'servicing',
        documentSubtype: 'monthly_statement',
        analyzedAt: '2025-01-15T10:00:00.000Z'
      });

      mockGetCase.mockResolvedValue({
        id: 'case-struct',
        user_id: 'user-123',
        case_name: 'Structure Test',
        documents: [
          createMockDocument({ documentId: 'doc-s1', analysisResults: analysis }),
          createMockDocument({ documentId: 'doc-s2', analysisResults: analysis })
        ]
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-struct', 'user-123');

      // Top-level structure
      expect(result).toEqual(expect.objectContaining({
        caseId: 'case-struct',
        documents: expect.any(Array),
        comparisonPairs: expect.any(Array),
        documentsWithoutAnalysis: expect.any(Array),
        totalDocuments: expect.any(Number),
        analyzedDocuments: expect.any(Number)
      }));

      // Document record structure
      const doc = result.documents[0];
      expect(doc).toEqual(expect.objectContaining({
        documentId: expect.any(String),
        documentType: 'servicing',
        documentSubtype: 'monthly_statement',
        analysisReport: expect.any(Object),
        extractedData: expect.any(Object),
        anomalies: expect.any(Array),
        completeness: expect.any(Object),
        analyzedAt: expect.any(String)
      }));

      // Comparison pair structure
      const pair = result.comparisonPairs[0];
      expect(pair).toEqual(expect.objectContaining({
        pairId: expect.any(String),
        docA: expect.objectContaining({
          documentId: expect.any(String),
          documentType: expect.any(String),
          documentSubtype: expect.any(String)
        }),
        docB: expect.objectContaining({
          documentId: expect.any(String),
          documentType: expect.any(String),
          documentSubtype: expect.any(String)
        }),
        comparisonFields: expect.any(Array),
        discrepancyTypes: expect.any(Array),
        forensicSignificance: expect.any(String)
      }));
    });

    // -----------------------------------------------------------------------
    // Wildcard matching (correspondence/* vs monthly_statement)
    // -----------------------------------------------------------------------
    test('wildcard subtype matching works for correspondence documents', async () => {
      const stmtAnalysis = createMockAnalysisReport({
        documentType: 'servicing',
        documentSubtype: 'monthly_statement'
      });
      const correspondenceAnalysis = createMockAnalysisReport({
        documentType: 'correspondence',
        documentSubtype: 'general_correspondence'
      });

      mockGetCase.mockResolvedValue({
        id: 'case-wildcard',
        user_id: 'user-123',
        case_name: 'Wildcard Test',
        documents: [
          createMockDocument({ documentId: 'doc-stmt', analysisResults: stmtAnalysis }),
          createMockDocument({ documentId: 'doc-corr', analysisResults: correspondenceAnalysis })
        ]
      });

      const result = await crossDocumentAggregationService.aggregateForCase('case-wildcard', 'user-123');

      // Should match correspondence-vs-stmt pair (wildcard *)
      const corrPair = result.comparisonPairs.find(p => p.pairId === 'correspondence-vs-stmt');
      expect(corrPair).toBeDefined();
      expect(corrPair.forensicSignificance).toBe('medium');
    });

  });
});
