/**
 * Report Aggregation Service Tests
 *
 * Tests gatherCaseFindings(), normalizeDocumentAnalysis(), and
 * extractFindingSummary() covering full data, partial data, missing
 * data, and error edge cases.
 *
 * Mocks: caseFileService, Supabase (external boundaries)
 * Real: normalization logic, finding summary calculation
 */

// Mock caseFileService before requiring service under test
jest.mock('../../services/caseFileService', () => ({
  getCase: jest.fn()
}));

// Mock Supabase client creation
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => ({
    from: jest.fn(() => ({
      select: jest.fn(() => ({
        eq: jest.fn(() => ({
          eq: jest.fn(() => ({
            single: jest.fn(() => ({ data: null, error: null })),
            order: jest.fn(() => ({ data: [], error: null }))
          })),
          single: jest.fn(() => ({ data: null, error: null }))
        }))
      }))
    }))
  }))
}));

// Mock logger
jest.mock('../../utils/logger', () => ({
  createLogger: () => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn()
  })
}));

const caseFileService = require('../../services/caseFileService');

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

function makeCaseData(overrides = {}) {
  return {
    id: 'case-001',
    user_id: 'user-001',
    case_name: 'Test Case',
    borrower_name: 'John Doe',
    property_address: '123 Main St',
    loan_number: 'LN-123456',
    servicer_name: 'ABC Mortgage',
    status: 'open',
    created_at: '2026-01-15T10:00:00Z',
    documents: [],
    ...overrides
  };
}

function makeAnalysisReport(overrides = {}) {
  return {
    documentInfo: {
      documentId: 'doc-001',
      fileName: 'statement-jan.pdf',
      classificationType: 'mortgage_statement',
      classificationSubtype: 'monthly_statement'
    },
    completeness: {
      score: 85,
      totalExpected: 10,
      totalFound: 8,
      missingFields: ['escrowBalance', 'lateCharges']
    },
    anomalies: [
      {
        id: 'anom-001',
        field: 'paymentAmount',
        type: 'unexpected_change',
        severity: 'high',
        description: 'Payment amount increased without notice'
      },
      {
        id: 'anom-002',
        field: 'interestRate',
        type: 'calculation_error',
        severity: 'medium',
        description: 'Interest rate does not match amortization schedule'
      }
    ],
    extractedData: {
      paymentAmount: 1500.00,
      principalBalance: 250000.00,
      interestRate: 4.5
    },
    summary: {
      riskLevel: 'medium',
      keyFindings: ['Payment increased without notice', 'Interest rate mismatch']
    },
    ...overrides
  };
}

function makeForensicReport(overrides = {}) {
  return {
    caseId: 'case-001',
    analyzedAt: '2026-01-20T12:00:00Z',
    documentsAnalyzed: 3,
    discrepancies: [
      {
        id: 'disc-001',
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Payment amount differs between statement and closing disclosure',
        documentA: { documentId: 'doc-001', field: 'paymentAmount' },
        documentB: { documentId: 'doc-002', field: 'monthlyPayment' }
      },
      {
        id: 'disc-002',
        type: 'date_inconsistency',
        severity: 'medium',
        description: 'Origination date differs between documents',
        documentA: { documentId: 'doc-001', field: 'originationDate' },
        documentB: { documentId: 'doc-003', field: 'closingDate' }
      }
    ],
    timeline: {
      events: [],
      violations: [
        {
          description: 'RESPA response deadline exceeded by 15 days',
          severity: 'critical',
          relatedDocuments: ['doc-001', 'doc-003'],
          regulation: 'RESPA Section 6'
        }
      ]
    },
    paymentVerification: {
      verified: true,
      transactionsAnalyzed: 12,
      matchedPayments: [{ id: 'pm-1' }],
      unmatchedDocumentPayments: [{ id: 'pm-2' }],
      unmatchedTransactions: [],
      escrowAnalysis: {},
      feeAnalysis: { irregularities: [] }
    },
    summary: {
      totalDiscrepancies: 2,
      criticalFindings: 0,
      highFindings: 1,
      riskLevel: 'high',
      keyFindings: ['Payment mismatch', 'Date inconsistency'],
      recommendations: []
    },
    ...overrides
  };
}

function makeComplianceReport(overrides = {}) {
  return {
    caseId: 'case-001',
    analyzedAt: '2026-01-21T14:00:00Z',
    violations: [
      {
        id: 'viol-001',
        statuteId: 'respa',
        sectionId: 'respa_qwr_response',
        statuteName: 'Real Estate Settlement Procedures Act',
        sectionTitle: 'QWR Response Requirements',
        citation: '12 USC 2605(e)',
        severity: 'critical',
        description: 'Servicer failed to respond to QWR within 30 days',
        legalBasis: 'RESPA requires acknowledgment within 5 days and substantive response within 30 days',
        potentialPenalties: 'Actual damages plus statutory damages up to $2,000',
        recommendations: ['File QWR with certified mail', 'Document all correspondence']
      }
    ],
    stateViolations: [
      {
        id: 'sviol-001',
        statuteId: 'ca_hbor',
        sectionId: 'ca_hbor_dual_tracking',
        statuteName: 'California Homeowner Bill of Rights',
        sectionTitle: 'Dual Tracking Prohibition',
        citation: 'Cal. Civ. Code §2924.18',
        severity: 'high',
        description: 'Servicer continued foreclosure while loss mitigation pending',
        legalBasis: 'CA HBOR prohibits dual tracking',
        jurisdiction: 'CA',
        recommendations: ['Request halt to foreclosure proceedings']
      }
    ],
    jurisdiction: {
      propertyState: 'CA',
      servicerState: 'TX',
      applicableStates: ['CA']
    },
    complianceSummary: {
      totalViolations: 1,
      criticalViolations: 1,
      highViolations: 0,
      statutesViolated: ['respa'],
      overallComplianceRisk: 'critical',
      keyFindings: ['QWR response failure'],
      recommendations: ['File QWR with certified mail']
    },
    ...overrides
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ReportAggregationService', () => {
  let service;

  beforeEach(() => {
    jest.clearAllMocks();
    // Fresh instance for each test
    jest.isolateModules(() => {
      service = require('../../services/reportAggregationService');
    });
  });

  // =========================================================================
  // normalizeDocumentAnalysis
  // =========================================================================

  describe('normalizeDocumentAnalysis', () => {
    it('should normalize a complete analysis report', () => {
      const report = makeAnalysisReport();
      const result = service.normalizeDocumentAnalysis(report);

      expect(result).toEqual({
        documentId: 'doc-001',
        documentName: 'statement-jan.pdf',
        type: 'mortgage_statement',
        subtype: 'monthly_statement',
        completenessScore: 85,
        anomalyCount: 2,
        anomalies: [
          {
            id: 'anom-001',
            field: 'paymentAmount',
            type: 'unexpected_change',
            severity: 'high',
            description: 'Payment amount increased without notice'
          },
          {
            id: 'anom-002',
            field: 'interestRate',
            type: 'calculation_error',
            severity: 'medium',
            description: 'Interest rate does not match amortization schedule'
          }
        ],
        keyFindings: ['Payment increased without notice', 'Interest rate mismatch']
      });
    });

    it('should handle missing extractedData with empty keyFindings', () => {
      const report = makeAnalysisReport({
        extractedData: undefined,
        summary: undefined
      });
      const result = service.normalizeDocumentAnalysis(report);

      expect(result.keyFindings).toEqual([]);
    });

    it('should handle missing anomalies', () => {
      const report = makeAnalysisReport({ anomalies: undefined });
      const result = service.normalizeDocumentAnalysis(report);

      expect(result.anomalies).toEqual([]);
      expect(result.anomalyCount).toBe(0);
    });

    it('should handle null report gracefully', () => {
      const result = service.normalizeDocumentAnalysis(null);

      expect(result).toEqual({
        documentId: 'unknown',
        documentName: 'unknown',
        type: 'unknown',
        subtype: 'unknown',
        completenessScore: 0,
        anomalyCount: 0,
        anomalies: [],
        keyFindings: []
      });
    });
  });

  // =========================================================================
  // extractFindingSummary
  // =========================================================================

  describe('extractFindingSummary', () => {
    it('should count findings from all three sources', () => {
      const docAnalyses = [
        {
          anomalyCount: 2,
          anomalies: [
            { severity: 'high' },
            { severity: 'medium' }
          ]
        }
      ];

      const forensicReport = {
        discrepancies: [
          { severity: 'high' },
          { severity: 'medium' }
        ],
        timeline: {
          violations: [
            { severity: 'critical' }
          ]
        },
        paymentVerification: {
          unmatchedDocumentPayments: [{ id: 'p1' }],
          feeAnalysis: { irregularities: [{ id: 'f1' }] }
        }
      };

      const complianceReport = {
        violations: [
          { severity: 'critical' }
        ],
        stateViolations: [
          { severity: 'high' }
        ]
      };

      const result = service.extractFindingSummary(docAnalyses, forensicReport, complianceReport);

      expect(result.totalFindings).toBe(9);
      expect(result.bySeverity.critical).toBe(2);
      expect(result.bySeverity.high).toBe(3);
      // 2 from doc+forensic discrepancies + 2 payment issues counted as medium
      expect(result.bySeverity.medium).toBe(4);
      expect(result.byCategory.documentAnomalies).toBe(2);
      expect(result.byCategory.crossDocDiscrepancies).toBe(2);
      expect(result.byCategory.timelineViolations).toBe(1);
      expect(result.byCategory.paymentIssues).toBe(2);
      expect(result.byCategory.federalViolations).toBe(1);
      expect(result.byCategory.stateViolations).toBe(1);
    });

    it('should handle null forensic report', () => {
      const docAnalyses = [
        { anomalyCount: 1, anomalies: [{ severity: 'low' }] }
      ];

      const result = service.extractFindingSummary(docAnalyses, null, null);

      expect(result.totalFindings).toBe(1);
      expect(result.byCategory.crossDocDiscrepancies).toBe(0);
      expect(result.byCategory.timelineViolations).toBe(0);
      expect(result.byCategory.paymentIssues).toBe(0);
      expect(result.byCategory.federalViolations).toBe(0);
      expect(result.byCategory.stateViolations).toBe(0);
    });

    it('should handle null compliance report', () => {
      const docAnalyses = [];
      const forensicReport = {
        discrepancies: [{ severity: 'medium' }],
        timeline: { violations: [] },
        paymentVerification: null
      };

      const result = service.extractFindingSummary(docAnalyses, forensicReport, null);

      expect(result.totalFindings).toBe(1);
      expect(result.byCategory.federalViolations).toBe(0);
      expect(result.byCategory.stateViolations).toBe(0);
    });

    it('should handle all sources empty', () => {
      const result = service.extractFindingSummary([], null, null);

      expect(result.totalFindings).toBe(0);
      expect(result.bySeverity).toEqual({
        critical: 0, high: 0, medium: 0, low: 0, info: 0
      });
      expect(result.byCategory).toEqual({
        documentAnomalies: 0,
        crossDocDiscrepancies: 0,
        timelineViolations: 0,
        paymentIssues: 0,
        federalViolations: 0,
        stateViolations: 0
      });
    });
  });

  // =========================================================================
  // gatherCaseFindings
  // =========================================================================

  describe('gatherCaseFindings', () => {
    it('should gather all data for a full case', async () => {
      const caseData = makeCaseData({
        documents: [
          { document_id: 'doc-001' },
          { document_id: 'doc-002' }
        ],
        forensic_analysis: makeForensicReport(),
        compliance_report: makeComplianceReport()
      });

      caseFileService.getCase.mockResolvedValue(caseData);

      const result = await service.gatherCaseFindings('case-001', 'user-001');

      expect(result.error).toBeFalsy();
      expect(result.caseInfo).toBeDefined();
      expect(result.caseInfo.caseId).toBe('case-001');
      expect(result.caseInfo.borrowerName).toBe('John Doe');
      expect(result.forensicReport).toBeDefined();
      expect(result.forensicReport.discrepancies).toHaveLength(2);
      expect(result.complianceReport).toBeDefined();
      expect(result.complianceReport.violations).toHaveLength(1);
    });

    it('should handle case with no forensic report', async () => {
      const caseData = makeCaseData({
        documents: [{ document_id: 'doc-001' }],
        forensic_analysis: null,
        compliance_report: makeComplianceReport()
      });

      caseFileService.getCase.mockResolvedValue(caseData);

      const result = await service.gatherCaseFindings('case-001', 'user-001');

      expect(result.error).toBeFalsy();
      expect(result.forensicReport).toBeNull();
      expect(result.errors).toContainEqual(expect.stringContaining('forensic'));
      expect(result.complianceReport).toBeDefined();
    });

    it('should handle case with no compliance report', async () => {
      const caseData = makeCaseData({
        documents: [{ document_id: 'doc-001' }],
        forensic_analysis: makeForensicReport(),
        compliance_report: null
      });

      caseFileService.getCase.mockResolvedValue(caseData);

      const result = await service.gatherCaseFindings('case-001', 'user-001');

      expect(result.error).toBeFalsy();
      expect(result.complianceReport).toBeNull();
      expect(result.errors).toContainEqual(expect.stringContaining('compliance'));
      expect(result.forensicReport).toBeDefined();
    });

    it('should handle empty case (no documents)', async () => {
      const caseData = makeCaseData({
        documents: [],
        forensic_analysis: null,
        compliance_report: null
      });

      caseFileService.getCase.mockResolvedValue(caseData);

      const result = await service.gatherCaseFindings('case-001', 'user-001');

      expect(result.error).toBeFalsy();
      expect(result.documentAnalyses).toEqual([]);
      expect(result.forensicReport).toBeNull();
      expect(result.complianceReport).toBeNull();
    });

    it('should return error for invalid caseId', async () => {
      caseFileService.getCase.mockResolvedValue(null);

      const result = await service.gatherCaseFindings('bad-case', 'user-001');

      expect(result.error).toBe(true);
      expect(result.errorMessage).toBeDefined();
    });

    it('should handle caseFileService throwing', async () => {
      caseFileService.getCase.mockRejectedValue(new Error('DB connection failed'));

      const result = await service.gatherCaseFindings('case-001', 'user-001');

      expect(result.error).toBe(true);
      expect(result.errorMessage).toContain('DB connection failed');
    });

    it('should include document analyses from pipeline state', async () => {
      const analysisReport = makeAnalysisReport();
      const caseData = makeCaseData({
        documents: [
          {
            document_id: 'doc-001',
            analysis_report: analysisReport
          }
        ],
        forensic_analysis: makeForensicReport(),
        compliance_report: makeComplianceReport()
      });

      caseFileService.getCase.mockResolvedValue(caseData);

      const result = await service.gatherCaseFindings('case-001', 'user-001');

      expect(result.documentAnalyses).toHaveLength(1);
      expect(result.documentAnalyses[0].documentId).toBe('doc-001');
      expect(result.documentAnalyses[0].completenessScore).toBe(85);
      expect(result.documentAnalyses[0].anomalyCount).toBe(2);
    });

    it('should handle partial forensic report (some pair failures)', async () => {
      const forensic = makeForensicReport();
      forensic._metadata = {
        warnings: ['Comparison pair stmt_closing threw: timeout']
      };

      const caseData = makeCaseData({
        documents: [{ document_id: 'doc-001' }],
        forensic_analysis: forensic,
        compliance_report: null
      });

      caseFileService.getCase.mockResolvedValue(caseData);

      const result = await service.gatherCaseFindings('case-001', 'user-001');

      expect(result.forensicReport).toBeDefined();
      expect(result.errors).toContainEqual(expect.stringContaining('partial'));
    });
  });
});
