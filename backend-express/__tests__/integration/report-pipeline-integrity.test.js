/**
 * Report Pipeline End-to-End Integrity Tests
 *
 * Verifies cross-system data integrity through the full report generation
 * pipeline: aggregation → scoring → assembly → schema validation.
 *
 * Mock strategy:
 *   - caseFileService: mocked (Supabase boundary)
 *   - All other services: REAL — aggregation, scoring, evidence linking,
 *     recommendation generation, schema validation run with actual logic
 *
 * These tests serve as regression protection for Phase 21 fixes:
 *   21-01: Schema allows null breakdown layers, classificationConfidence wired
 *   21-02: Dispute letter service reads from both raw and consolidated formats
 *   21-03: documentAnalysis preserves anomaly details in consolidated report
 */

// ---------------------------------------------------------------------------
// Mocks — only external I/O boundaries
// ---------------------------------------------------------------------------

jest.mock('../../services/caseFileService', () => ({
  getCase: jest.fn(),
  updateCase: jest.fn().mockResolvedValue({})
}));

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

jest.mock('../../utils/logger', () => ({
  createLogger: () => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn()
  })
}));

const caseFileService = require('../../services/caseFileService');
const consolidatedReportService = require('../../services/consolidatedReportService');
const { validateConsolidatedReport } = require('../../schemas/consolidatedReportSchema');

// ---------------------------------------------------------------------------
// Test fixtures — comprehensive case data for end-to-end testing
// ---------------------------------------------------------------------------

function makeFullCaseData() {
  return {
    id: 'case-e2e-001',
    user_id: 'user-e2e-001',
    case_name: 'E2E Integrity Test Case',
    borrower_name: 'Alice Johnson',
    property_address: '789 Oak Ave, Springfield, IL 62701',
    loan_number: 'LN-E2E-99999',
    servicer_name: 'National Mortgage Corp',
    status: 'active',
    created_at: '2026-01-10T08:00:00.000Z',
    documents: [
      {
        document_id: 'doc-e2e-001',
        analysis_report: {
          documentInfo: {
            documentId: 'doc-e2e-001',
            fileName: 'monthly-statement-jan.pdf',
            classificationType: 'mortgage_statement',
            classificationSubtype: 'monthly_statement'
          },
          completeness: { score: 90, totalExpected: 10, totalFound: 9 },
          anomalies: [
            {
              id: 'anom-e2e-001',
              field: 'escrowBalance',
              type: 'amount_mismatch',
              severity: 'high',
              description: 'Escrow balance does not match prior statement'
            },
            {
              id: 'anom-e2e-002',
              field: 'interestRate',
              type: 'calculation_error',
              severity: 'medium',
              description: 'Interest calculation inconsistent with stated rate'
            }
          ],
          summary: {
            riskLevel: 'medium',
            keyFindings: ['Escrow discrepancy', 'Interest calculation error']
          }
        }
      },
      {
        document_id: 'doc-e2e-002',
        analysis_report: {
          documentInfo: {
            documentId: 'doc-e2e-002',
            fileName: 'closing-disclosure.pdf',
            classificationType: 'closing_document',
            classificationSubtype: 'closing_disclosure'
          },
          completeness: { score: 95, totalExpected: 12, totalFound: 11 },
          anomalies: [
            {
              id: 'anom-e2e-003',
              field: 'loanAmount',
              type: 'amount_mismatch',
              severity: 'critical',
              description: 'Loan amount does not match promissory note'
            }
          ],
          summary: {
            riskLevel: 'high',
            keyFindings: ['Loan amount mismatch']
          }
        }
      }
    ],
    forensic_analysis: {
      caseId: 'case-e2e-001',
      analyzedAt: '2026-01-20T12:00:00Z',
      documentsAnalyzed: 2,
      discrepancies: [
        {
          id: 'disc-e2e-001',
          type: 'amount_mismatch',
          severity: 'high',
          description: 'Escrow balance differs between statement and closing disclosure',
          documentA: { documentId: 'doc-e2e-001', field: 'escrowBalance' },
          documentB: { documentId: 'doc-e2e-002', field: 'escrowBalance' }
        },
        {
          id: 'disc-e2e-002',
          type: 'date_inconsistency',
          severity: 'medium',
          description: 'Origination date differs between documents',
          documentA: { documentId: 'doc-e2e-001', field: 'originationDate' },
          documentB: { documentId: 'doc-e2e-002', field: 'closingDate' }
        }
      ],
      timeline: {
        events: [],
        violations: [
          {
            id: 'tv-e2e-001',
            description: 'RESPA response deadline exceeded by 20 days',
            severity: 'critical',
            relatedDocuments: ['doc-e2e-001', 'doc-e2e-002'],
            regulation: 'RESPA Section 6'
          }
        ]
      },
      paymentVerification: {
        verified: true,
        transactionsAnalyzed: 6,
        matchedPayments: [{ id: 'pm-1' }, { id: 'pm-2' }],
        unmatchedDocumentPayments: [{ id: 'pm-3' }],
        unmatchedTransactions: [],
        escrowAnalysis: {},
        feeAnalysis: { irregularities: [] }
      },
      summary: {
        totalDiscrepancies: 2,
        riskLevel: 'high'
      }
    },
    compliance_report: {
      caseId: 'case-e2e-001',
      analyzedAt: '2026-01-21T14:00:00Z',
      violations: [
        {
          id: 'viol-e2e-001',
          statuteId: 'respa',
          sectionId: 'respa_qwr_response',
          statuteName: 'Real Estate Settlement Procedures Act',
          sectionTitle: 'QWR Response Requirements',
          citation: '12 USC 2605(e)',
          severity: 'critical',
          description: 'Servicer failed to respond to QWR within 30 days',
          legalBasis: 'RESPA requires acknowledgment within 5 days and substantive response within 30 days',
          potentialPenalties: 'Actual damages plus statutory damages up to $2,000',
          recommendations: ['File QWR with certified mail']
        }
      ],
      stateViolations: [
        {
          id: 'sviol-e2e-001',
          statuteId: 'il_ica',
          sectionId: 'il_ica_interest',
          statuteName: 'Illinois Interest Act',
          sectionTitle: 'Interest Overcharge',
          citation: '815 ILCS 205/4',
          severity: 'high',
          description: 'Interest overcharge on escrow account',
          legalBasis: 'Illinois law limits interest rates on mortgage escrow accounts',
          jurisdiction: 'IL',
          recommendations: ['Request refund of overcharged interest']
        }
      ],
      jurisdiction: {
        propertyState: 'IL',
        servicerState: 'TX',
        applicableStates: ['IL']
      }
    }
  };
}

function makePartialCaseData() {
  return {
    id: 'case-e2e-partial',
    user_id: 'user-e2e-001',
    case_name: 'Partial Data Case',
    borrower_name: 'Bob Smith',
    property_address: '456 Elm St',
    loan_number: 'LN-PARTIAL-001',
    servicer_name: 'Quick Lending',
    status: 'active',
    created_at: '2026-02-01T10:00:00.000Z',
    documents: [
      {
        document_id: 'doc-partial-001',
        analysis_report: {
          documentInfo: {
            documentId: 'doc-partial-001',
            fileName: 'statement.pdf',
            classificationType: 'mortgage_statement',
            classificationSubtype: 'monthly_statement'
          },
          completeness: { score: 75, totalExpected: 8, totalFound: 6 },
          anomalies: [],
          summary: { riskLevel: 'low', keyFindings: [] }
        }
      }
    ],
    forensic_analysis: null,
    compliance_report: null
  };
}

function makeCaseDataWithClassification() {
  const base = makeFullCaseData();
  base.documents[0].analysis_report.classificationConfidence = 0.92;
  base.documents[1].analysis_report.classificationConfidence = 0.78;
  return base;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

beforeEach(() => {
  jest.clearAllMocks();
  caseFileService.updateCase.mockResolvedValue({});
});

describe('Report Pipeline End-to-End Integrity', () => {

  // =========================================================================
  // Test 1: Full report validates against schema
  // =========================================================================

  it('full report with all data sources validates against schema with zero errors', async () => {
    caseFileService.getCase.mockResolvedValue(makeFullCaseData());

    const report = await consolidatedReportService.generateReport(
      'case-e2e-001', 'user-e2e-001', { skipPersistence: true }
    );

    expect(report.error).toBeUndefined();

    const validation = validateConsolidatedReport(report);
    expect(validation.valid).toBe(true);
    expect(validation.errors).toHaveLength(0);
  });

  // =========================================================================
  // Test 2: Partial report validates (no forensic, no compliance)
  // =========================================================================

  it('partial report (no forensic, no compliance) validates with null breakdown scores', async () => {
    caseFileService.getCase.mockResolvedValue(makePartialCaseData());

    const report = await consolidatedReportService.generateReport(
      'case-e2e-partial', 'user-e2e-001', { skipPersistence: true }
    );

    expect(report.error).toBeUndefined();

    const validation = validateConsolidatedReport(report);
    expect(validation.valid).toBe(true);
    expect(validation.errors).toHaveLength(0);

    // Verify null breakdown layers for absent data sources
    expect(report.confidenceScore.breakdown.forensicAnalysis).toBeNull();
    expect(report.confidenceScore.breakdown.complianceAnalysis).toBeNull();
    // Document analysis should still have a real score
    expect(report.confidenceScore.breakdown.documentAnalysis).toBeGreaterThan(0);
  });

  // =========================================================================
  // Test 3: findingSummary counts match detail sections
  // =========================================================================

  it('findingSummary counts match detail section lengths exactly', async () => {
    caseFileService.getCase.mockResolvedValue(makeFullCaseData());

    const report = await consolidatedReportService.generateReport(
      'case-e2e-001', 'user-e2e-001', { skipPersistence: true }
    );

    expect(report.error).toBeUndefined();

    const { findingSummary, documentAnalysis, forensicFindings, complianceFindings } = report;

    // documentAnomalies = sum of all anomalies across documentAnalysis items
    const totalAnomalies = documentAnalysis.reduce(
      (sum, da) => sum + (da.anomalies ? da.anomalies.length : 0), 0
    );
    expect(findingSummary.byCategory.documentAnomalies).toBe(totalAnomalies);

    // crossDocDiscrepancies = forensicFindings.discrepancies.length
    expect(findingSummary.byCategory.crossDocDiscrepancies).toBe(
      forensicFindings.discrepancies.length
    );

    // timelineViolations = forensicFindings.timelineViolations.length
    expect(findingSummary.byCategory.timelineViolations).toBe(
      forensicFindings.timelineViolations.length
    );

    // federalViolations = complianceFindings.federalViolations.length
    expect(findingSummary.byCategory.federalViolations).toBe(
      complianceFindings.federalViolations.length
    );

    // stateViolations = complianceFindings.stateViolations.length
    expect(findingSummary.byCategory.stateViolations).toBe(
      complianceFindings.stateViolations.length
    );

    // totalFindings = sum of all byCategory values
    const categorySum = Object.values(findingSummary.byCategory).reduce(
      (sum, n) => sum + n, 0
    );
    expect(findingSummary.totalFindings).toBe(categorySum);
  });

  // =========================================================================
  // Test 4: documentAnalysis preserves anomaly details
  // =========================================================================

  it('documentAnalysis preserves anomaly details with id, field, type, severity, description', async () => {
    caseFileService.getCase.mockResolvedValue(makeFullCaseData());

    const report = await consolidatedReportService.generateReport(
      'case-e2e-001', 'user-e2e-001', { skipPersistence: true }
    );

    expect(report.error).toBeUndefined();
    expect(report.documentAnalysis).toHaveLength(2);

    // Verify first document's anomalies are preserved
    const doc1 = report.documentAnalysis.find(d => d.documentId === 'doc-e2e-001');
    expect(doc1).toBeDefined();
    expect(doc1.anomalies).toHaveLength(2);

    const anom1 = doc1.anomalies.find(a => a.id === 'anom-e2e-001');
    expect(anom1).toEqual({
      id: 'anom-e2e-001',
      field: 'escrowBalance',
      type: 'amount_mismatch',
      severity: 'high',
      description: 'Escrow balance does not match prior statement'
    });

    const anom2 = doc1.anomalies.find(a => a.id === 'anom-e2e-002');
    expect(anom2).toEqual({
      id: 'anom-e2e-002',
      field: 'interestRate',
      type: 'calculation_error',
      severity: 'medium',
      description: 'Interest calculation inconsistent with stated rate'
    });

    // Verify second document's anomaly is preserved
    const doc2 = report.documentAnalysis.find(d => d.documentId === 'doc-e2e-002');
    expect(doc2).toBeDefined();
    expect(doc2.anomalies).toHaveLength(1);
    expect(doc2.anomalies[0].id).toBe('anom-e2e-003');
    expect(doc2.anomalies[0].severity).toBe('critical');
  });

  // =========================================================================
  // Test 5: classificationConfidence flows into scoring
  // =========================================================================

  it('classificationConfidence flows through aggregation into confidence scoring', async () => {
    caseFileService.getCase.mockResolvedValue(makeCaseDataWithClassification());

    const report = await consolidatedReportService.generateReport(
      'case-e2e-001', 'user-e2e-001', { skipPersistence: true }
    );

    expect(report.error).toBeUndefined();

    // classificationConfidence of 0.92 and 0.78 → average 0.85 → >= 0.7 → factor 1.0
    expect(report.confidenceScore.classificationImpact).toBeDefined();
    expect(report.confidenceScore.classificationImpact.confidenceUsed).toBeCloseTo(0.85, 2);
    expect(report.confidenceScore.classificationImpact.factor).toBe(1.0);
    expect(report.confidenceScore.classificationImpact.layerAffected).toBe('documentAnalysis');
  });
});
