/**
 * Compliance Orchestrator Service Tests
 *
 * Unit tests for ComplianceService.evaluateCompliance() — the orchestrator
 * that coordinates rule engine evaluation, Claude AI analysis, and report
 * assembly into a unified compliance report.
 *
 * Mock strategy:
 *   - caseFileService: mocked (Supabase persistence)
 *   - complianceRuleEngine: mocked (business logic)
 *   - complianceAnalysisService: mocked (Claude AI)
 *   - federalStatuteTaxonomy / complianceRuleMappings: real config (not mocked)
 */

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

jest.mock('../services/caseFileService', () => ({
  getCase: jest.fn(),
  updateCase: jest.fn()
}));

jest.mock('../services/complianceRuleEngine', () => ({
  evaluateFindings: jest.fn(),
  evaluateStateFindings: jest.fn()
}));

jest.mock('../services/complianceAnalysisService', () => ({
  analyzeViolations: jest.fn(),
  analyzeStateViolations: jest.fn(),
  generateLegalNarrative: jest.fn()
}));

const mockDetectJurisdiction = jest.fn();
jest.mock('../services/jurisdictionService', () => {
  return jest.fn().mockImplementation(() => ({
    detectJurisdiction: mockDetectJurisdiction
  }));
});

const caseFileService = require('../services/caseFileService');
const complianceRuleEngine = require('../services/complianceRuleEngine');
const complianceAnalysisService = require('../services/complianceAnalysisService');
const complianceService = require('../services/complianceService');

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeForensicReport(overrides = {}) {
  return {
    caseId: 'case-001',
    analyzedAt: '2026-03-09T12:00:00.000Z',
    documentsAnalyzed: 3,
    comparisonPairsEvaluated: 3,
    discrepancies: [
      {
        id: 'disc-001',
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Escrow balance discrepancy of $450',
        documentA: { documentId: 'doc-1', documentType: 'servicing', field: 'escrowBalance', value: 5000 },
        documentB: { documentId: 'doc-2', documentType: 'origination', field: 'escrowBalance', value: 5450 }
      }
    ],
    timeline: { events: [], violations: [] },
    paymentVerification: null,
    summary: {
      totalDiscrepancies: 1,
      criticalFindings: 0,
      highFindings: 1,
      riskLevel: 'high',
      keyFindings: ['Escrow balance discrepancy of $450'],
      recommendations: []
    },
    ...overrides
  };
}

function makeViolation(overrides = {}) {
  return {
    id: 'viol-001',
    statuteId: 'respa',
    sectionId: 'respa_s10',
    statuteName: 'Real Estate Settlement Procedures Act (RESPA)',
    sectionTitle: 'Escrow Account Requirements',
    citation: '12 U.S.C. § 2601 et seq.; 12 CFR § 1024.17',
    severity: 'high',
    description: 'Escrow account violation detected.',
    evidence: [{ sourceType: 'discrepancy', sourceId: 'disc-001', description: 'Escrow mismatch' }],
    legalBasis: 'RESPA Section 10 limits escrow cushions.',
    potentialPenalties: 'Actual damages, statutory damages.',
    recommendations: ['Review escrow accounting procedures'],
    ...overrides
  };
}

function makeCriticalViolation(overrides = {}) {
  return makeViolation({
    id: 'viol-002',
    severity: 'critical',
    statuteId: 'tila',
    sectionId: 'tila_disclosure',
    description: 'Critical TILA disclosure violation.',
    recommendations: ['Immediate servicer notification'],
    ...overrides
  });
}

function makeStateViolation(overrides = {}) {
  return {
    id: 'state-viol-001',
    statuteId: 'ca_hbor',
    sectionId: 'ca_hbor_dual_tracking',
    statuteName: 'California Homeowner Bill of Rights (HBOR)',
    sectionTitle: 'Dual Tracking Prohibition',
    citation: 'Cal. Civ. Code § 2923.6',
    severity: 'high',
    description: 'Dual tracking violation detected under CA HBOR.',
    evidence: [{ sourceType: 'discrepancy', sourceId: 'disc-001', description: 'Escrow mismatch' }],
    legalBasis: 'CA HBOR prohibits dual tracking during loss mitigation.',
    potentialPenalties: 'Actual damages, injunctive relief, attorney fees.',
    recommendations: ['Halt foreclosure proceedings during loss mitigation review'],
    jurisdiction: 'CA',
    ...overrides
  };
}

function makeJurisdiction(overrides = {}) {
  return {
    propertyState: 'CA',
    servicerState: null,
    applicableStates: ['CA'],
    determinationMethod: 'property_location',
    confidence: 'high',
    ...overrides
  };
}

function setupHappyPath() {
  const forensicReport = makeForensicReport();
  const violations = [makeViolation(), makeCriticalViolation()];

  caseFileService.getCase.mockResolvedValue({
    forensic_analysis: forensicReport,
    analysis_reports: []
  });

  complianceRuleEngine.evaluateFindings.mockReturnValue({
    violations,
    statutesEvaluated: ['respa', 'tila', 'ecoa', 'fdcpa', 'fcra', 'cfpb_reg_x'],
    evaluationMeta: { totalFindingsEvaluated: 1, rulesChecked: 32 }
  });

  const enhancedViolations = violations.map(v => ({
    ...v,
    legalBasis: `Enhanced: ${v.legalBasis}`,
    recommendations: [...v.recommendations, 'AI-generated recommendation']
  }));

  complianceAnalysisService.analyzeViolations.mockResolvedValue({
    enhancedViolations,
    legalNarrative: '## Legal Narrative\n\nThis case presents significant compliance concerns.',
    analysisMetadata: { claudeCallsMade: 2, durationMs: 500 }
  });

  caseFileService.updateCase.mockResolvedValue({});

  return { forensicReport, violations, enhancedViolations };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

beforeEach(() => {
  jest.clearAllMocks();
});

describe('ComplianceService.evaluateCompliance()', () => {

  // =========================================================================
  // 1. Input validation
  // =========================================================================

  describe('input validation', () => {
    test('returns error when caseId is missing', async () => {
      const result = await complianceService.evaluateCompliance(null, 'user-001');
      expect(result.error).toBe(true);
      expect(result.errorMessage).toMatch(/caseId/);
    });

    test('returns error when userId is missing', async () => {
      const result = await complianceService.evaluateCompliance('case-001', '');
      expect(result.error).toBe(true);
      expect(result.errorMessage).toMatch(/userId/);
    });
  });

  // =========================================================================
  // 2. Happy path
  // =========================================================================

  describe('happy path', () => {
    test('produces a complete compliance report', async () => {
      setupHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result.error).toBeUndefined();
      expect(result.caseId).toBe('case-001');
      expect(result.analyzedAt).toBeDefined();
      expect(result.statutesEvaluated).toEqual(expect.arrayContaining(['respa', 'tila']));
      expect(result.violations).toHaveLength(2);
      expect(result.complianceSummary).toBeDefined();
      expect(result.legalNarrative).toContain('Legal Narrative');
    });

    test('report matches complianceReportSchema structure', async () => {
      setupHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      // The report should have the expected top-level keys
      expect(result).toHaveProperty('caseId');
      expect(result).toHaveProperty('analyzedAt');
      expect(result).toHaveProperty('statutesEvaluated');
      expect(result).toHaveProperty('violations');
      expect(result).toHaveProperty('complianceSummary');
      expect(result).toHaveProperty('_metadata');
    });

    test('violations have enhanced data from Claude AI', async () => {
      setupHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      // Violations should have the enhanced legal basis
      expect(result.violations[0].legalBasis).toMatch(/^Enhanced:/);
      expect(result.violations[0].recommendations).toContain('AI-generated recommendation');
    });

    test('complianceSummary is correctly calculated', async () => {
      setupHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');
      const summary = result.complianceSummary;

      expect(summary.totalViolations).toBe(2);
      expect(summary.criticalViolations).toBe(1);
      expect(summary.highViolations).toBe(1);
      expect(summary.overallComplianceRisk).toBe('critical');
      expect(summary.statutesViolated).toEqual(expect.arrayContaining(['respa', 'tila']));
      expect(summary.keyFindings.length).toBeGreaterThan(0);
      expect(summary.keyFindings.length).toBeLessThanOrEqual(10);
    });

    test('persists report via caseFileService', async () => {
      setupHappyPath();

      await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(caseFileService.updateCase).toHaveBeenCalledWith({
        caseId: 'case-001',
        userId: 'user-001',
        updates: { compliance_report: expect.objectContaining({ caseId: 'case-001' }) }
      });
    });
  });

  // =========================================================================
  // 3. Step failures (graceful degradation)
  // =========================================================================

  describe('graceful degradation', () => {
    test('returns error when no forensic report exists', async () => {
      caseFileService.getCase.mockResolvedValue({ forensic_analysis: null });

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result.error).toBe(true);
      expect(result.errorMessage).toMatch(/forensic analysis/i);
    });

    test('returns error when getCase throws', async () => {
      caseFileService.getCase.mockRejectedValue(new Error('DB connection failed'));

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result.error).toBe(true);
      expect(result.errorMessage).toMatch(/DB connection failed/);
      expect(result._metadata.steps.gather.status).toBe('failed');
    });

    test('returns partial result when rule engine throws', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockImplementation(() => {
        throw new Error('Rule engine crashed');
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      // Should NOT be an error — graceful degradation returns empty violations
      expect(result.error).toBeUndefined();
      expect(result.violations).toEqual([]);
      expect(result._metadata.warnings).toEqual(
        expect.arrayContaining([expect.stringMatching(/Rule engine threw/)])
      );
      expect(result._metadata.steps.ruleEngine.status).toBe('failed');
    });

    test('returns rule-engine violations when Claude AI fails', async () => {
      const violations = [makeViolation()];
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      complianceAnalysisService.analyzeViolations.mockRejectedValue(
        new Error('API key invalid')
      );
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result.error).toBeUndefined();
      // Violations should be the original rule-engine output (not enhanced)
      expect(result.violations).toEqual(violations);
      expect(result._metadata.warnings).toEqual(
        expect.arrayContaining([expect.stringMatching(/Claude AI enhancement failed/)])
      );
      expect(result._metadata.steps.aiEnhancement.status).toBe('failed');
    });

    test('returns report when persistence fails', async () => {
      setupHappyPath();
      caseFileService.updateCase.mockRejectedValue(new Error('DB write failed'));

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      // Report should still be returned successfully
      expect(result.error).toBeUndefined();
      expect(result.caseId).toBe('case-001');
      expect(result.violations.length).toBeGreaterThan(0);
    });

    test('returns error when rule engine returns error object', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        error: 'forensicReport.caseId is required'
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      // Should still produce a report (with empty violations) but add warning
      expect(result.error).toBeUndefined();
      expect(result.violations).toEqual([]);
      expect(result._metadata.warnings).toEqual(
        expect.arrayContaining([expect.stringMatching(/Rule engine returned error/)])
      );
    });
  });

  // =========================================================================
  // 4. Options
  // =========================================================================

  describe('options', () => {
    test('skipAiAnalysis=true skips Claude step entirely', async () => {
      const violations = [makeViolation()];
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(complianceAnalysisService.analyzeViolations).not.toHaveBeenCalled();
      expect(result._metadata.steps.aiEnhancement.status).toBe('skipped');
      expect(result._metadata.steps.aiEnhancement.reason).toMatch(/skipAiAnalysis/);
      // Violations should be the original rule-engine output
      expect(result.violations).toEqual(violations);
    });

    test('statuteFilter limits evaluation to specified statutes', async () => {
      const respaViolation = makeViolation({ statuteId: 'respa' });
      const tilaViolation = makeCriticalViolation({ statuteId: 'tila' });

      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [respaViolation, tilaViolation],
        statutesEvaluated: ['respa', 'tila', 'ecoa'],
        evaluationMeta: {}
      });
      complianceAnalysisService.analyzeViolations.mockResolvedValue({
        enhancedViolations: [respaViolation],
        legalNarrative: '',
        analysisMetadata: { claudeCallsMade: 1 }
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        statuteFilter: ['respa']
      });

      // Only RESPA violations should remain
      expect(result.violations.every(v => v.statuteId === 'respa')).toBe(true);
      // statutesEvaluated should also be filtered
      expect(result.statutesEvaluated).toEqual(['respa']);
    });
  });

  // =========================================================================
  // 5. Report assembly
  // =========================================================================

  describe('report assembly', () => {
    test('overallComplianceRisk = critical when critical violations exist', async () => {
      const violations = [makeViolation(), makeCriticalViolation()];
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa', 'tila'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.complianceSummary.overallComplianceRisk).toBe('critical');
    });

    test('overallComplianceRisk = high when only high violations exist', async () => {
      const violations = [makeViolation({ severity: 'high' })];
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.complianceSummary.overallComplianceRisk).toBe('high');
    });

    test('overallComplianceRisk = low when no violations', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.complianceSummary.overallComplianceRisk).toBe('low');
      expect(result.complianceSummary.totalViolations).toBe(0);
    });

    test('statutesViolated only includes statutes with actual violations', async () => {
      const violations = [makeViolation({ statuteId: 'respa' })];
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa', 'tila', 'ecoa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.complianceSummary.statutesViolated).toEqual(['respa']);
    });

    test('keyFindings limited to top 10', async () => {
      // Create 15 violations
      const violations = Array.from({ length: 15 }, (_, i) =>
        makeViolation({ id: `viol-${i}`, description: `Violation ${i}`, severity: 'medium' })
      );
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.complianceSummary.keyFindings.length).toBe(10);
    });

    test('recommendations are deduplicated', async () => {
      const violations = [
        makeViolation({ recommendations: ['Fix escrow', 'Review procedures'] }),
        makeViolation({ id: 'viol-002', recommendations: ['Fix escrow', 'Contact servicer'] })
      ];
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      const recs = result.complianceSummary.recommendations;
      // 'Fix escrow' should appear only once
      expect(recs.filter(r => r === 'Fix escrow').length).toBe(1);
      expect(recs).toContain('Review procedures');
      expect(recs).toContain('Contact servicer');
      expect(recs.length).toBe(3);
    });
  });

  // =========================================================================
  // 6. Metadata
  // =========================================================================

  describe('metadata', () => {
    test('_metadata includes duration, steps, and warnings', async () => {
      setupHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result._metadata).toBeDefined();
      expect(typeof result._metadata.duration).toBe('number');
      expect(result._metadata.duration).toBeGreaterThanOrEqual(0);
      expect(result._metadata.steps).toBeDefined();
      expect(result._metadata.steps.gather).toBeDefined();
      expect(result._metadata.steps.ruleEngine).toBeDefined();
      expect(result._metadata.steps.aiEnhancement).toBeDefined();
      expect(result._metadata.steps.assemble).toBeDefined();
      expect(Array.isArray(result._metadata.warnings)).toBe(true);
    });

    test('each step has status and duration', async () => {
      setupHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');
      const steps = result._metadata.steps;

      for (const stepName of ['gather', 'ruleEngine', 'aiEnhancement', 'assemble']) {
        expect(steps[stepName].status).toBeDefined();
        expect(typeof steps[stepName].duration).toBe('number');
      }
    });

    test('warnings accumulate across steps', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      // Rule engine returns error object (adds warning)
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        error: 'Some rule issue'
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result._metadata.warnings.length).toBeGreaterThan(0);
    });
  });

  // =========================================================================
  // 7. AI step skipped when no violations
  // =========================================================================

  describe('edge cases', () => {
    test('AI step skipped when rule engine produces zero violations', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(complianceAnalysisService.analyzeViolations).not.toHaveBeenCalled();
      expect(result._metadata.steps.aiEnhancement.status).toBe('skipped');
      expect(result._metadata.steps.aiEnhancement.reason).toMatch(/No violations/);
    });

    test('handles forensicAnalysis camelCase field name', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensicAnalysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.error).toBeUndefined();
      expect(result.caseId).toBe('case-001');
    });
  });

  // =========================================================================
  // 8. State compliance evaluation
  // =========================================================================

  describe('state compliance evaluation', () => {

    function setupStateHappyPath() {
      const forensicReport = makeForensicReport();
      const violations = [makeViolation()];
      const stateViolations = [makeStateViolation()];
      const jurisdiction = makeJurisdiction();

      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: forensicReport,
        analysis_reports: [],
        propertyState: 'CA'
      });

      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa'],
        evaluationMeta: { totalFindingsEvaluated: 1, rulesChecked: 32 }
      });

      mockDetectJurisdiction.mockReturnValue(jurisdiction);

      complianceRuleEngine.evaluateStateFindings.mockReturnValue({
        stateViolations,
        stateStatutesEvaluated: ['ca_hbor'],
        evaluationMeta: { totalFindingsEvaluated: 1, statesEvaluated: 1, rulesChecked: 4 }
      });

      const enhancedStateViolations = stateViolations.map(v => ({
        ...v,
        legalBasis: `Enhanced: ${v.legalBasis}`
      }));

      complianceAnalysisService.analyzeViolations.mockResolvedValue({
        enhancedViolations: violations,
        legalNarrative: '## Legal Narrative',
        analysisMetadata: { claudeCallsMade: 1 }
      });

      complianceAnalysisService.analyzeStateViolations.mockResolvedValue({
        enhancedViolations: enhancedStateViolations,
        analysisMetadata: { claudeCallsMade: 1 }
      });

      caseFileService.updateCase.mockResolvedValue({});

      return { forensicReport, violations, stateViolations, jurisdiction, enhancedStateViolations };
    }

    test('state analysis happy path includes jurisdiction and state violations', async () => {
      setupStateHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result.error).toBeUndefined();
      expect(result.jurisdiction).toBeDefined();
      expect(result.jurisdiction.applicableStates).toEqual(['CA']);
      expect(result.stateViolations).toBeDefined();
      expect(result.stateViolations.length).toBe(1);
      expect(result.stateStatutesEvaluated).toEqual(['ca_hbor']);
      expect(result.stateCompliance).toBeDefined();
      expect(result.stateCompliance.statesAnalyzed).toBe(1);
      expect(result.stateCompliance.totalStateViolations).toBe(1);
    });

    test('skipStateAnalysis option skips jurisdiction detection entirely', async () => {
      const violations = [makeViolation()];
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations,
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true,
        skipStateAnalysis: true
      });

      expect(result.error).toBeUndefined();
      expect(mockDetectJurisdiction).not.toHaveBeenCalled();
      expect(complianceRuleEngine.evaluateStateFindings).not.toHaveBeenCalled();
      expect(result.jurisdiction).toBeUndefined();
      expect(result.stateViolations).toBeUndefined();
      expect(result._metadata.steps.jurisdictionDetection.status).toBe('skipped');
    });

    test('jurisdiction detection failure degrades gracefully', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [makeViolation()],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      mockDetectJurisdiction.mockImplementation(() => {
        throw new Error('Jurisdiction service unavailable');
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.error).toBeUndefined();
      expect(result.jurisdiction).toBeUndefined();
      expect(result.stateViolations).toBeUndefined();
      expect(result._metadata.steps.jurisdictionDetection.status).toBe('failed');
      expect(result._metadata.warnings).toEqual(
        expect.arrayContaining([expect.stringMatching(/Jurisdiction detection failed/)])
      );
    });

    test('state rule engine failure degrades gracefully', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [makeViolation()],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      mockDetectJurisdiction.mockReturnValue(makeJurisdiction());
      complianceRuleEngine.evaluateStateFindings.mockImplementation(() => {
        throw new Error('State rule engine crashed');
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.error).toBeUndefined();
      expect(result.jurisdiction).toBeDefined();
      expect(result.stateViolations).toBeUndefined();
      expect(result._metadata.steps.stateRuleEngine.status).toBe('failed');
      expect(result._metadata.warnings).toEqual(
        expect.arrayContaining([expect.stringMatching(/State rule engine threw/)])
      );
    });

    test('state AI failure degrades gracefully — keeps un-enhanced state violations', async () => {
      const stateViolations = [makeStateViolation()];
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport(),
        analysis_reports: []
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [makeViolation()],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      mockDetectJurisdiction.mockReturnValue(makeJurisdiction());
      complianceRuleEngine.evaluateStateFindings.mockReturnValue({
        stateViolations,
        stateStatutesEvaluated: ['ca_hbor'],
        evaluationMeta: {}
      });
      complianceAnalysisService.analyzeViolations.mockResolvedValue({
        enhancedViolations: [makeViolation()],
        legalNarrative: '',
        analysisMetadata: { claudeCallsMade: 1 }
      });
      complianceAnalysisService.analyzeStateViolations.mockRejectedValue(
        new Error('State AI API error')
      );
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result.error).toBeUndefined();
      // State violations should be the original un-enhanced output
      expect(result.stateViolations).toEqual(stateViolations);
      expect(result._metadata.steps.stateAiEnhancement.status).toBe('failed');
      expect(result._metadata.warnings).toEqual(
        expect.arrayContaining([expect.stringMatching(/State AI enhancement failed/)])
      );
    });

    test('manual state override is passed to jurisdiction service', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      mockDetectJurisdiction.mockReturnValue(makeJurisdiction({
        determinationMethod: 'manual',
        applicableStates: ['TX']
      }));
      complianceRuleEngine.evaluateStateFindings.mockReturnValue({
        stateViolations: [],
        stateStatutesEvaluated: [],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true,
        state: 'TX'
      });

      expect(mockDetectJurisdiction).toHaveBeenCalledWith(
        expect.any(Object),
        expect.objectContaining({ manualState: 'TX' })
      );
      expect(result.jurisdiction.determinationMethod).toBe('manual');
    });

    test('stateStatuteFilter limits state evaluation to specified statutes', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      mockDetectJurisdiction.mockReturnValue(makeJurisdiction());

      const caHborViolation = makeStateViolation({ statuteId: 'ca_hbor' });
      const caCivViolation = makeStateViolation({
        id: 'state-viol-002',
        statuteId: 'ca_civ',
        sectionId: 'ca_civ_escrow_accounts'
      });

      complianceRuleEngine.evaluateStateFindings.mockReturnValue({
        stateViolations: [caHborViolation, caCivViolation],
        stateStatutesEvaluated: ['ca_hbor', 'ca_civ'],
        evaluationMeta: {}
      });
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true,
        stateStatuteFilter: ['ca_hbor']
      });

      expect(result.stateViolations.every(v => v.statuteId === 'ca_hbor')).toBe(true);
      expect(result.stateStatutesEvaluated).toEqual(['ca_hbor']);
    });

    test('state compliance risk level calculated correctly', async () => {
      setupStateHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result.stateCompliance.stateRiskLevel).toBe('high');
    });

    test('no state violations when jurisdiction has no applicable states', async () => {
      caseFileService.getCase.mockResolvedValue({
        forensic_analysis: makeForensicReport()
      });
      complianceRuleEngine.evaluateFindings.mockReturnValue({
        violations: [makeViolation()],
        statutesEvaluated: ['respa'],
        evaluationMeta: {}
      });
      mockDetectJurisdiction.mockReturnValue(makeJurisdiction({
        applicableStates: [],
        confidence: 'none'
      }));
      caseFileService.updateCase.mockResolvedValue({});

      const result = await complianceService.evaluateCompliance('case-001', 'user-001', {
        skipAiAnalysis: true
      });

      expect(result.error).toBeUndefined();
      // State rule engine should not have been called
      expect(complianceRuleEngine.evaluateStateFindings).not.toHaveBeenCalled();
      expect(result.stateViolations).toBeUndefined();
      expect(result.stateCompliance.totalStateViolations).toBe(0);
    });

    test('state AI enhanced violations replace original state violations', async () => {
      const { enhancedStateViolations } = setupStateHappyPath();

      const result = await complianceService.evaluateCompliance('case-001', 'user-001');

      expect(result.stateViolations[0].legalBasis).toMatch(/^Enhanced:/);
      expect(complianceAnalysisService.analyzeStateViolations).toHaveBeenCalled();
    });
  });
});
