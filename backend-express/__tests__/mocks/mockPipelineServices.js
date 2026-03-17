/**
 * Pipeline-Wide Mock Infrastructure
 *
 * Produces coordinated mock responses across all 4 orchestrators so that
 * document IDs, case IDs, and findings flow correctly from one stage to the next:
 *   documentPipelineService -> forensicAnalysisService -> complianceService -> consolidatedReportService
 *
 * Exports:
 *   - createMockPipelineContext()  -- returns a complete set of cross-referenced mock data
 *   - setupPipelineMocks(context) -- configures jest.mock for all external boundaries
 */

// ---------------------------------------------------------------------------
// createMockPipelineContext
// ---------------------------------------------------------------------------

/**
 * Build a complete set of mock data representing a 2-document case.
 * Every ID referenced downstream matches something produced upstream.
 *
 * @param {Object} [overrides] - Optional overrides for any section
 * @returns {Object} Pipeline context with all stages
 */
function createMockPipelineContext(overrides = {}) {
  const caseId = overrides.caseId || 'case-e2e-001';
  const userId = overrides.userId || 'user-e2e-001';
  const docIdA = overrides.docIdA || 'doc-e2e-001';
  const docIdB = overrides.docIdB || 'doc-e2e-002';

  // -- OCR results --
  const ocrResults = {
    [docIdA]: {
      text: 'Monthly Mortgage Statement. Loan #98765. Borrower: Jane Doe. ' +
            'Principal Balance: $245,000.00. Interest Rate: 4.5%. Monthly Payment: $1,500.00. ' +
            'Statement Date: 2024-01-15. Payment Due: 2024-02-01. Servicer: Test Bank Corp.',
      method: 'client-provided',
      textLength: 220
    },
    [docIdB]: {
      text: 'Closing Disclosure. Loan #98765. Borrower: Jane Doe. ' +
            'Loan Amount: $250,000.00. Interest Rate: 4.25%. Monthly Payment: $1,229.85. ' +
            'Closing Date: 2023-06-15. Lender: Original Lending LLC. Property: 123 Main St.',
      method: 'client-provided',
      textLength: 210
    }
  };

  // -- Classification results --
  const classificationResults = {
    [docIdA]: {
      classificationType: 'servicing',
      classificationSubtype: 'monthly_statement',
      confidence: 0.94,
      extractedMetadata: {
        dates: ['2024-01-15'],
        amounts: ['$1,500.00', '$245,000.00'],
        parties: ['Test Bank Corp'],
        accountNumbers: ['98765']
      }
    },
    [docIdB]: {
      classificationType: 'origination',
      classificationSubtype: 'closing_disclosure',
      confidence: 0.96,
      extractedMetadata: {
        dates: ['2023-06-15'],
        amounts: ['$250,000.00', '$1,229.85'],
        parties: ['Original Lending LLC'],
        accountNumbers: ['98765']
      }
    }
  };

  // -- Individual analysis results --
  const analysisResults = {
    [docIdA]: {
      documentInfo: { documentType: 'servicing', documentSubtype: 'monthly_statement' },
      extractedData: {
        dates: { statementDate: '2024-01-15', paymentDueDate: '2024-02-01' },
        amounts: { principalBalance: 245000, monthlyPayment: 1500 },
        rates: { interestRate: 4.5 },
        parties: { borrower: 'Jane Doe', servicer: 'Test Bank Corp' },
        identifiers: { loanNumber: '98765' },
        terms: {},
        custom: {}
      },
      anomalies: [
        {
          id: 'anom-001',
          field: 'interestRate',
          type: 'amount_mismatch',
          severity: 'high',
          description: 'Interest rate 4.5% does not match closing disclosure rate of 4.25%',
          expectedValue: '4.25%',
          actualValue: '4.5%'
        }
      ],
      completeness: {
        score: 85,
        presentFields: ['statementDate', 'paymentDueDate', 'principalBalance', 'monthlyPayment', 'interestRate', 'borrower', 'servicer', 'loanNumber'],
        missingFields: ['escrowBalance', 'lateCharges'],
        missingCritical: [],
        totalExpectedFields: 10
      },
      summary: {
        overview: 'Monthly mortgage statement with interest rate discrepancy detected.',
        keyFindings: ['Interest rate does not match origination documents'],
        riskLevel: 'medium',
        recommendations: ['Request rate adjustment documentation from servicer']
      }
    },
    [docIdB]: {
      documentInfo: { documentType: 'origination', documentSubtype: 'closing_disclosure' },
      extractedData: {
        dates: { closingDate: '2023-06-15' },
        amounts: { loanAmount: 250000, monthlyPayment: 1229.85 },
        rates: { interestRate: 4.25 },
        parties: { borrower: 'Jane Doe', lender: 'Original Lending LLC' },
        identifiers: { loanNumber: '98765' },
        terms: {},
        custom: {}
      },
      anomalies: [],
      completeness: {
        score: 90,
        presentFields: ['closingDate', 'loanAmount', 'monthlyPayment', 'interestRate', 'borrower', 'lender', 'loanNumber'],
        missingFields: ['propertyTax', 'insurance'],
        missingCritical: [],
        totalExpectedFields: 9
      },
      summary: {
        overview: 'Closing disclosure appears complete with no anomalies detected.',
        keyFindings: [],
        riskLevel: 'low',
        recommendations: []
      }
    }
  };

  // -- Forensic analysis results (cross-document) --
  const forensicResults = {
    caseId,
    analyzedAt: '2024-02-01T12:00:00.000Z',
    documentsAnalyzed: 2,
    comparisonPairsEvaluated: 1,
    discrepancies: [
      {
        id: 'disc-001',
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Interest rate changed from 4.25% (closing) to 4.5% (statement) without documentation',
        documentA: { documentId: docIdA, documentType: 'monthly_statement', field: 'interestRate', value: '4.5%' },
        documentB: { documentId: docIdB, documentType: 'closing_disclosure', field: 'interestRate', value: '4.25%' }
      },
      {
        id: 'disc-002',
        type: 'date_inconsistency',
        severity: 'medium',
        description: 'Monthly payment amount $1,500 does not match closing disclosure amount $1,229.85',
        documentA: { documentId: docIdA, documentType: 'monthly_statement', field: 'monthlyPayment', value: '$1,500.00' },
        documentB: { documentId: docIdB, documentType: 'closing_disclosure', field: 'monthlyPayment', value: '$1,229.85' }
      }
    ],
    timeline: {
      events: [
        { date: '2023-06-15', documentId: docIdB, documentType: 'closing_disclosure', event: 'Loan closed', significance: 'high' },
        { date: '2024-01-15', documentId: docIdA, documentType: 'monthly_statement', event: 'Statement issued', significance: 'medium' }
      ],
      violations: []
    },
    paymentVerification: null,
    summary: {
      totalDiscrepancies: 2,
      criticalFindings: 0,
      highFindings: 1,
      riskLevel: 'high',
      keyFindings: [
        'Interest rate changed from 4.25% (closing) to 4.5% (statement) without documentation',
        'Monthly payment amount $1,500 does not match closing disclosure amount $1,229.85'
      ],
      recommendations: [
        'Request detailed payment application history from servicer',
        'Request complete servicing timeline with supporting documentation'
      ]
    },
    _metadata: {
      duration: 150,
      steps: {
        aggregation: { status: 'completed', duration: 50, documentsFound: 2, pairsGenerated: 1 },
        comparison: { status: 'completed', duration: 80, pairsCompared: 1, pairsFailed: 0 },
        plaidCrossReference: { status: 'skipped', duration: 0, reason: 'No plaidAccessToken provided' },
        consolidation: { status: 'completed', duration: 20 }
      },
      warnings: []
    }
  };

  // -- Compliance results --
  const complianceResults = {
    caseId,
    analyzedAt: '2024-02-01T12:05:00.000Z',
    statutesEvaluated: ['respa', 'tila', 'ecoa', 'fdcpa', 'scra', 'hmda', 'cfpb_reg_x'],
    violations: [
      {
        id: 'viol-001',
        statuteId: 'respa',
        sectionId: 'respa_section_6',
        statuteName: 'Real Estate Settlement Procedures Act',
        sectionTitle: 'Servicing Disclosure',
        citation: '12 U.S.C. 2605(e)',
        severity: 'high',
        description: 'Servicer failed to provide adequate notice of interest rate change as required by RESPA',
        evidence: ['disc-001'],
        legalBasis: 'RESPA Section 6 requires servicers to respond to qualified written requests',
        recommendations: ['File qualified written request under RESPA Section 6']
      }
    ],
    complianceSummary: {
      totalViolations: 1,
      criticalViolations: 0,
      highViolations: 1,
      statutesViolated: ['respa'],
      overallComplianceRisk: 'high',
      keyFindings: ['Servicer failed to provide adequate notice of interest rate change as required by RESPA'],
      recommendations: ['File qualified written request under RESPA Section 6']
    },
    jurisdiction: {
      propertyState: 'CA',
      servicerState: null,
      applicableStates: ['CA'],
      determinationMethod: 'property_address',
      confidence: 0.8
    },
    stateViolations: [
      {
        id: 'sviol-001',
        statuteId: 'ca_hbor',
        sectionId: 'ca_hbor_2924_17',
        statuteName: 'California Homeowner Bill of Rights',
        sectionTitle: 'Single Point of Contact',
        citation: 'Cal. Civ. Code 2924.17',
        severity: 'medium',
        description: 'Servicer may not have maintained single point of contact as required by CA HBOR',
        evidence: ['disc-002'],
        legalBasis: 'CA Civil Code 2924.17 requires servicers to provide single point of contact',
        recommendations: ['Request servicer designate single point of contact per CA HBOR']
      }
    ],
    stateStatutesEvaluated: ['ca_hbor'],
    stateCompliance: {
      statesAnalyzed: 1,
      totalStateViolations: 1,
      stateRiskLevel: 'medium'
    },
    _metadata: {
      duration: 200,
      steps: {
        gather: { status: 'completed', duration: 30, hasForensicReport: true, analysisReportsCount: 2 },
        ruleEngine: { status: 'completed', duration: 60, violationsFound: 1, statutesEvaluated: 7 },
        jurisdictionDetection: { status: 'completed', duration: 10, applicableStates: ['CA'], determinationMethod: 'property_address' },
        stateRuleEngine: { status: 'completed', duration: 40, stateViolationsFound: 1, stateStatutesEvaluated: 1 },
        aiEnhancement: { status: 'skipped', duration: 0, reason: 'skipAiAnalysis option set' },
        assemble: { status: 'completed', duration: 20 }
      },
      warnings: []
    }
  };

  // -- Consolidated report results --
  const consolidatedReport = {
    reportId: 'rpt-e2e-001',
    caseId,
    userId,
    generatedAt: '2024-02-01T12:10:00.000Z',
    reportVersion: '1.0',
    caseSummary: {
      borrowerName: 'Jane Doe',
      propertyAddress: '123 Main St',
      loanNumber: '98765',
      servicerName: 'Test Bank Corp',
      documentCount: 2,
      caseCreatedAt: '2024-01-01T00:00:00.000Z'
    },
    overallRiskLevel: 'high',
    confidenceScore: {
      overall: 42,
      breakdown: { documentAnalysis: 60, forensicAnalysis: 35, complianceAnalysis: 30 }
    },
    findingSummary: {
      totalFindings: 5,
      bySeverity: { critical: 0, high: 2, medium: 2, low: 0, info: 1 },
      byCategory: {
        documentAnomalies: 1,
        crossDocDiscrepancies: 2,
        timelineViolations: 0,
        paymentIssues: 0,
        federalViolations: 1,
        stateViolations: 1
      }
    },
    documentAnalysis: [
      { documentId: docIdA, documentName: 'Monthly Statement', type: 'servicing', subtype: 'monthly_statement', completenessScore: 85, anomalyCount: 1, keyFindings: ['Interest rate does not match origination documents'] },
      { documentId: docIdB, documentName: 'Closing Disclosure', type: 'origination', subtype: 'closing_disclosure', completenessScore: 90, anomalyCount: 0, keyFindings: [] }
    ],
    forensicFindings: {
      discrepancies: [
        { id: 'disc-001', type: 'amount_mismatch', severity: 'high', description: 'Interest rate changed from 4.25% to 4.5%', documentIds: [docIdA, docIdB] },
        { id: 'disc-002', type: 'date_inconsistency', severity: 'medium', description: 'Monthly payment mismatch', documentIds: [docIdA, docIdB] }
      ],
      timelineViolations: [],
      paymentVerification: null
    },
    complianceFindings: {
      federalViolations: complianceResults.violations,
      stateViolations: complianceResults.stateViolations,
      jurisdiction: complianceResults.jurisdiction
    },
    evidenceLinks: [
      { findingId: 'disc-001', findingType: 'forensic_discrepancy', sourceDocumentIds: [docIdA, docIdB], evidenceDescription: 'Interest rate mismatch between documents', severity: 'high' },
      { findingId: 'viol-001', findingType: 'compliance_violation', sourceDocumentIds: [docIdA], evidenceDescription: 'RESPA violation based on rate change without notice', severity: 'high' }
    ],
    recommendations: [
      { priority: 2, category: 'payment_verification', action: 'Request detailed payment application history from servicer', legalBasis: null, relatedFindingIds: ['disc-001'] },
      { priority: 3, category: 'documentation', action: 'Request complete servicing timeline with supporting documentation', legalBasis: null, relatedFindingIds: ['disc-002'] },
      { priority: 2, category: 'compliance', action: 'Consult with legal counsel regarding identified regulatory violation', legalBasis: '12 U.S.C. 2605(e)', relatedFindingIds: ['viol-001'] }
    ],
    disputeLetterAvailable: true,
    disputeLetter: {
      letterType: 'qualified_written_request',
      generatedAt: '2024-02-01T12:10:00.000Z',
      content: {
        subject: 'Qualified Written Request Under RESPA Section 6',
        salutation: 'Dear Loan Servicing Department,',
        body: 'I am writing to formally request information regarding my mortgage loan #98765...',
        demands: ['Provide documentation of interest rate change from 4.25% to 4.5%'],
        legalCitations: ['12 U.S.C. 2605(e)'],
        responseDeadline: '30 business days',
        closingStatement: 'Please acknowledge receipt of this qualified written request within 5 business days.'
      },
      recipientInfo: { servicerName: 'Test Bank Corp', servicerAddress: null }
    },
    _metadata: {
      generationDurationMs: 300,
      stepsCompleted: ['gather', 'score', 'link', 'recommendations', 'disputeLetter', 'assemble', 'validate'],
      warnings: []
    }
  };

  // -- Case data (used by caseFileService.getCase) --
  const caseData = {
    id: caseId,
    user_id: userId,
    case_name: 'E2E Pipeline Test Case',
    borrower_name: 'Jane Doe',
    property_address: '123 Main St',
    loan_number: '98765',
    servicer_name: 'Test Bank Corp',
    status: 'open',
    notes: null,
    created_at: '2024-01-01T00:00:00.000Z',
    updated_at: '2024-02-01T12:00:00.000Z',
    documents: [
      { document_id: docIdA, case_id: caseId },
      { document_id: docIdB, case_id: caseId }
    ],
    forensic_analysis: null,   // Populated after forensic step
    compliance_report: null,   // Populated after compliance step
    consolidated_report: null  // Populated after report step
  };

  return {
    caseId,
    userId,
    docIdA,
    docIdB,
    ocrResults,
    classificationResults,
    analysisResults,
    forensicResults,
    complianceResults,
    consolidatedReport,
    caseData
  };
}

// ---------------------------------------------------------------------------
// setupPipelineMocks
// ---------------------------------------------------------------------------

/**
 * Configure jest.mock spies/stubs for all external boundaries so the
 * 4 orchestrators can be called without hitting real services.
 *
 * This does NOT call jest.mock() (which must be hoisted). Instead it sets up
 * mock implementations on already-mocked modules. The test file is responsible
 * for calling jest.mock() at the top level for each module.
 *
 * @param {Object} ctx - Pipeline context from createMockPipelineContext()
 * @param {Object} mocks - References to the mocked modules
 * @param {Object} mocks.mockAnthropicCreate - jest.fn() for Anthropic SDK messages.create
 * @param {Object} mocks.mockSupabaseClient - Mock Supabase client instance
 * @param {Object} [mocks.caseFileService] - Already-mocked caseFileService module
 * @param {Object} [mocks.crossDocAggregation] - Already-mocked crossDocumentAggregationService
 * @param {Object} [mocks.crossDocComparison] - Already-mocked crossDocumentComparisonService
 * @param {Object} [mocks.plaidCrossRef] - Already-mocked plaidCrossReferenceService
 * @param {Object} [mocks.complianceRuleEngine] - Already-mocked complianceRuleEngine
 * @param {Object} [mocks.complianceAnalysis] - Already-mocked complianceAnalysisService
 * @param {Object} [mocks.jurisdictionService] - Already-mocked jurisdictionService
 * @param {Object} [mocks.reportAggregation] - Already-mocked reportAggregationService
 * @param {Object} [mocks.confidenceScoring] - Already-mocked confidenceScoringService
 * @param {Object} [mocks.disputeLetter] - Already-mocked disputeLetterService
 */
function setupPipelineMocks(ctx, mocks) {
  const {
    mockAnthropicCreate,
    mockSupabaseClient,
    caseFileService,
    crossDocAggregation,
    crossDocComparison,
    plaidCrossRef,
    complianceRuleEngine,
    complianceAnalysis,
    jurisdictionService,
    reportAggregation,
    confidenceScoring,
    disputeLetter
  } = mocks;

  // -- Anthropic SDK: return classification then analysis for each document --
  if (mockAnthropicCreate) {
    // Build Anthropic responses for each document: classification, then analysis
    const anthropicResponses = [];
    for (const docId of [ctx.docIdA, ctx.docIdB]) {
      // Classification response
      anthropicResponses.push({
        content: [{ text: JSON.stringify(ctx.classificationResults[docId]) }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 500, output_tokens: 200 },
        stop_reason: 'end_turn'
      });
      // Analysis response
      anthropicResponses.push({
        content: [{ text: JSON.stringify(ctx.analysisResults[docId]) }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 1200, output_tokens: 600 },
        stop_reason: 'end_turn'
      });
    }

    mockAnthropicCreate.mockReset();
    for (const resp of anthropicResponses) {
      mockAnthropicCreate.mockResolvedValueOnce(resp);
    }
  }

  // -- Supabase: accept writes silently, return empty data --
  if (mockSupabaseClient) {
    mockSupabaseClient.reset();
  }

  // -- caseFileService --
  if (caseFileService) {
    if (caseFileService.getCase) {
      caseFileService.getCase.mockReset();
      caseFileService.getCase.mockResolvedValue(ctx.caseData);
    }
    if (caseFileService.getCasesByUser) {
      caseFileService.getCasesByUser.mockReset();
      caseFileService.getCasesByUser.mockResolvedValue([ctx.caseData]);
    }
    if (caseFileService.updateCase) {
      caseFileService.updateCase.mockReset();
      caseFileService.updateCase.mockResolvedValue(ctx.caseData);
    }
    if (caseFileService.addDocumentToCase) {
      caseFileService.addDocumentToCase.mockReset();
      caseFileService.addDocumentToCase.mockResolvedValue({
        document_id: ctx.docIdA,
        case_id: ctx.caseId
      });
    }
  }

  // -- crossDocumentAggregationService --
  if (crossDocAggregation) {
    if (crossDocAggregation.aggregateForCase) {
      crossDocAggregation.aggregateForCase.mockReset();
      crossDocAggregation.aggregateForCase.mockResolvedValue({
        caseId: ctx.caseId,
        documents: [
          {
            documentId: ctx.docIdA,
            documentType: 'servicing',
            documentSubtype: 'monthly_statement',
            analysisReport: ctx.analysisResults[ctx.docIdA],
            extractedData: ctx.analysisResults[ctx.docIdA].extractedData,
            anomalies: ctx.analysisResults[ctx.docIdA].anomalies,
            completeness: ctx.analysisResults[ctx.docIdA].completeness
          },
          {
            documentId: ctx.docIdB,
            documentType: 'origination',
            documentSubtype: 'closing_disclosure',
            analysisReport: ctx.analysisResults[ctx.docIdB],
            extractedData: ctx.analysisResults[ctx.docIdB].extractedData,
            anomalies: ctx.analysisResults[ctx.docIdB].anomalies,
            completeness: ctx.analysisResults[ctx.docIdB].completeness
          }
        ],
        comparisonPairs: [
          {
            pairId: 'pair-001',
            docA: { documentId: ctx.docIdA, documentType: 'monthly_statement' },
            docB: { documentId: ctx.docIdB, documentType: 'closing_disclosure' },
            comparisonFields: ['interestRate', 'monthlyPayment', 'loanNumber'],
            discrepancyTypes: ['amount_mismatch', 'date_inconsistency', 'term_contradiction'],
            forensicSignificance: 'high'
          }
        ],
        documentsWithoutAnalysis: [],
        totalDocuments: 2,
        analyzedDocuments: 2
      });
    }
  }

  // -- crossDocumentComparisonService --
  if (crossDocComparison) {
    if (crossDocComparison.compareDocumentPair) {
      crossDocComparison.compareDocumentPair.mockReset();
      crossDocComparison.compareDocumentPair.mockResolvedValue({
        pairId: 'pair-001',
        discrepancies: ctx.forensicResults.discrepancies,
        timelineEvents: ctx.forensicResults.timeline.events,
        timelineViolations: ctx.forensicResults.timeline.violations,
        comparisonSummary: { fieldsCompared: 3, discrepanciesFound: 2 }
      });
    }
  }

  // -- plaidCrossReferenceService --
  if (plaidCrossRef) {
    if (plaidCrossRef.extractPaymentsFromAnalysis) {
      plaidCrossRef.extractPaymentsFromAnalysis.mockReset();
      plaidCrossRef.extractPaymentsFromAnalysis.mockReturnValue([]);
    }
    if (plaidCrossRef.crossReferencePayments) {
      plaidCrossRef.crossReferencePayments.mockReset();
      plaidCrossRef.crossReferencePayments.mockReturnValue({
        matchedPayments: [],
        unmatchedDocumentPayments: [],
        unmatchedTransactions: [],
        summary: { totalDocumentPayments: 0, totalPlaidTransactions: 0, matched: 0, paymentVerified: true }
      });
    }
  }

  // -- complianceRuleEngine --
  if (complianceRuleEngine) {
    if (complianceRuleEngine.evaluateFindings) {
      complianceRuleEngine.evaluateFindings.mockReset();
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: ctx.complianceResults.violations,
        statutesEvaluated: ctx.complianceResults.statutesEvaluated,
        evaluationMeta: { totalFindingsEvaluated: 3, rulesChecked: 7 }
      });
    }
    if (complianceRuleEngine.evaluateStateFindings) {
      complianceRuleEngine.evaluateStateFindings.mockReset();
      complianceRuleEngine.evaluateStateFindings.mockReturnValue({
        stateViolations: ctx.complianceResults.stateViolations,
        stateStatutesEvaluated: ctx.complianceResults.stateStatutesEvaluated,
        evaluationMeta: { totalFindingsEvaluated: 3, rulesChecked: 2 }
      });
    }
  }

  // -- complianceAnalysisService (AI enhancement) --
  if (complianceAnalysis) {
    if (complianceAnalysis.analyzeViolations) {
      complianceAnalysis.analyzeViolations.mockReset();
      complianceAnalysis.analyzeViolations.mockResolvedValue({
        enhancedViolations: ctx.complianceResults.violations,
        legalNarrative: 'The identified RESPA violation warrants immediate attention.',
        analysisMetadata: { totalViolations: 1, claudeCallsMade: 1, durationMs: 500 }
      });
    }
    if (complianceAnalysis.analyzeStateViolations) {
      complianceAnalysis.analyzeStateViolations.mockReset();
      complianceAnalysis.analyzeStateViolations.mockResolvedValue({
        enhancedViolations: ctx.complianceResults.stateViolations,
        analysisMetadata: { totalViolations: 1, claudeCallsMade: 1, durationMs: 300 }
      });
    }
  }

  // -- jurisdictionService --
  if (jurisdictionService) {
    if (jurisdictionService.mockImplementation) {
      jurisdictionService.mockReset();
      jurisdictionService.mockImplementation(() => ({
        detectJurisdiction: jest.fn().mockReturnValue(ctx.complianceResults.jurisdiction)
      }));
    }
  }

  // -- reportAggregationService --
  if (reportAggregation) {
    if (reportAggregation.gatherCaseFindings) {
      reportAggregation.gatherCaseFindings.mockReset();
      reportAggregation.gatherCaseFindings.mockResolvedValue({
        caseInfo: {
          borrowerName: ctx.caseData.borrower_name,
          propertyAddress: ctx.caseData.property_address,
          loanNumber: ctx.caseData.loan_number,
          servicerName: ctx.caseData.servicer_name,
          documentCount: 2,
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
            keyFindings: ['Interest rate does not match origination documents']
          },
          {
            documentId: ctx.docIdB,
            documentName: 'Closing Disclosure',
            type: 'origination',
            subtype: 'closing_disclosure',
            completenessScore: 90,
            anomalyCount: 0,
            anomalies: [],
            keyFindings: []
          }
        ],
        forensicReport: ctx.forensicResults,
        complianceReport: ctx.complianceResults,
        errors: []
      });
    }
    if (reportAggregation.extractFindingSummary) {
      reportAggregation.extractFindingSummary.mockReset();
      reportAggregation.extractFindingSummary.mockReturnValue(ctx.consolidatedReport.findingSummary);
    }
  }

  // -- confidenceScoringService --
  if (confidenceScoring) {
    if (confidenceScoring.calculateConfidence) {
      confidenceScoring.calculateConfidence.mockReset();
      confidenceScoring.calculateConfidence.mockReturnValue(ctx.consolidatedReport.confidenceScore);
    }
    if (confidenceScoring.determineRiskLevel) {
      confidenceScoring.determineRiskLevel.mockReset();
      confidenceScoring.determineRiskLevel.mockReturnValue(ctx.consolidatedReport.overallRiskLevel);
    }
    if (confidenceScoring.buildEvidenceLinks) {
      confidenceScoring.buildEvidenceLinks.mockReset();
      confidenceScoring.buildEvidenceLinks.mockReturnValue(ctx.consolidatedReport.evidenceLinks);
    }
  }

  // -- disputeLetterService --
  if (disputeLetter) {
    if (disputeLetter.generateDisputeLetter) {
      disputeLetter.generateDisputeLetter.mockReset();
      disputeLetter.generateDisputeLetter.mockResolvedValue(ctx.consolidatedReport.disputeLetter);
    }
  }
}

module.exports = { createMockPipelineContext, setupPipelineMocks };
