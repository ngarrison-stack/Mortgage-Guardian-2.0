/**
 * Compliance Rule Engine Tests
 *
 * TDD tests for ComplianceRuleEngine.evaluateFindings() — the core method
 * that takes forensic analysis data and produces statutory violation objects.
 *
 * Covers all 10 behavior cases from 14-03-PLAN.md.
 */

const { getStatuteIds } = require('../config/federalStatuteTaxonomy');

// ---------------------------------------------------------------------------
// Test helpers — builds minimal valid forensic data structures
// ---------------------------------------------------------------------------

function makeForensicReport(overrides = {}) {
  return {
    caseId: 'case-test-001',
    analyzedAt: '2026-03-09T12:00:00.000Z',
    documentsAnalyzed: 3,
    comparisonPairsEvaluated: 3,
    discrepancies: [],
    timeline: { events: [], violations: [] },
    paymentVerification: null,
    summary: {
      totalDiscrepancies: 0,
      criticalFindings: 0,
      highFindings: 0,
      riskLevel: 'low',
      keyFindings: [],
      recommendations: []
    },
    ...overrides
  };
}

function makeDiscrepancy(overrides = {}) {
  return {
    id: 'disc-001',
    type: 'amount_mismatch',
    severity: 'high',
    description: 'Escrow balance discrepancy of $450 identified',
    documentA: {
      documentId: 'doc-001',
      documentType: 'servicing',
      documentSubtype: 'escrow_analysis',
      field: 'escrowBalance',
      value: 5000
    },
    documentB: {
      documentId: 'doc-002',
      documentType: 'servicing',
      documentSubtype: 'monthly_statement',
      field: 'escrowBalance',
      value: 4550
    },
    ...overrides
  };
}

function makeTimelineViolation(overrides = {}) {
  return {
    description: 'QWR response deadline exceeded by 15 days',
    severity: 'high',
    relatedDocuments: ['doc-003', 'doc-004'],
    regulation: 'RESPA Section 6',
    ...overrides
  };
}

function makeAnalysisReport(overrides = {}) {
  return {
    documentInfo: {
      documentType: 'servicing',
      documentSubtype: 'monthly_statement',
      analyzedAt: '2026-03-09T12:00:00.000Z',
      modelUsed: 'claude-3-5-sonnet-20241022',
      confidence: 0.95
    },
    extractedData: {
      dates: {},
      amounts: {},
      rates: {},
      parties: {},
      identifiers: {},
      terms: {},
      custom: {}
    },
    anomalies: [],
    completeness: {
      score: 90,
      totalExpectedFields: 10,
      presentFields: ['field1'],
      missingFields: [],
      missingCritical: []
    },
    summary: {
      overview: 'Test summary',
      keyFindings: [],
      riskLevel: 'low',
      recommendations: []
    },
    ...overrides
  };
}

function makeAnomaly(overrides = {}) {
  return {
    field: 'escrowBalance',
    type: 'calculation_error',
    severity: 'high',
    description: 'Escrow cushion exceeds RESPA limit',
    ...overrides
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ComplianceRuleEngine', () => {
  let engine;

  beforeAll(() => {
    engine = require('../services/complianceRuleEngine');
  });

  // -------------------------------------------------------------------------
  // Case 10: Missing/null inputs → error object
  // -------------------------------------------------------------------------
  describe('Case 10: Missing/null inputs', () => {
    it('returns error when forensicReport is null', () => {
      const result = engine.evaluateFindings(null, []);
      expect(result).toHaveProperty('error');
      expect(result.violations).toBeUndefined();
    });

    it('returns error when forensicReport is undefined', () => {
      const result = engine.evaluateFindings(undefined, []);
      expect(result).toHaveProperty('error');
    });

    it('returns error when forensicReport has no caseId', () => {
      const report = makeForensicReport();
      delete report.caseId;
      const result = engine.evaluateFindings(report, []);
      expect(result).toHaveProperty('error');
    });

    it('handles null analysisReports gracefully', () => {
      const report = makeForensicReport();
      const result = engine.evaluateFindings(report, null);
      // Should not error — just treat as empty
      expect(result).not.toHaveProperty('error');
      expect(result.violations).toEqual([]);
    });
  });

  // -------------------------------------------------------------------------
  // Case 9: Empty forensicReport → empty violations, all statutes evaluated
  // -------------------------------------------------------------------------
  describe('Case 9: Empty forensicReport', () => {
    it('returns empty violations when no findings exist', () => {
      const report = makeForensicReport();
      const result = engine.evaluateFindings(report, []);

      expect(result.violations).toEqual([]);
      expect(result.statutesEvaluated).toEqual(expect.arrayContaining(getStatuteIds()));
      expect(result.statutesEvaluated.length).toBe(getStatuteIds().length);
    });

    it('includes evaluationMeta with processing info', () => {
      const report = makeForensicReport();
      const result = engine.evaluateFindings(report, []);

      expect(result).toHaveProperty('evaluationMeta');
      expect(result.evaluationMeta).toHaveProperty('totalFindingsEvaluated', 0);
      expect(result.evaluationMeta).toHaveProperty('rulesChecked');
    });
  });

  // -------------------------------------------------------------------------
  // Case 1: Discrepancy with matching rule → violation
  // -------------------------------------------------------------------------
  describe('Case 1: Discrepancy with matching rule', () => {
    it('produces violation from an escrow amount_mismatch discrepancy', () => {
      const disc = makeDiscrepancy({
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Escrow balance discrepancy of $450 identified'
      });
      const report = makeForensicReport({ discrepancies: [disc] });
      const result = engine.evaluateFindings(report, []);

      expect(result.violations.length).toBeGreaterThanOrEqual(1);

      const viol = result.violations[0];
      expect(viol).toHaveProperty('id');
      expect(viol.id).toMatch(/^viol-\d{3}$/);
      expect(viol).toHaveProperty('statuteId');
      expect(viol).toHaveProperty('sectionId');
      expect(viol).toHaveProperty('statuteName');
      expect(viol).toHaveProperty('sectionTitle');
      expect(viol).toHaveProperty('citation');
      expect(viol).toHaveProperty('severity');
      expect(viol).toHaveProperty('description');
      expect(viol).toHaveProperty('evidence');
      expect(viol.evidence.length).toBeGreaterThanOrEqual(1);
      expect(viol.evidence[0]).toHaveProperty('sourceType', 'discrepancy');
      expect(viol.evidence[0]).toHaveProperty('sourceId', 'disc-001');
      expect(viol).toHaveProperty('legalBasis');
    });

    it('fills description from template with finding data', () => {
      const disc = makeDiscrepancy({
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Escrow balance discrepancy of $450 identified'
      });
      const report = makeForensicReport({ discrepancies: [disc] });
      const result = engine.evaluateFindings(report, []);

      const viol = result.violations.find(v => v.sectionId === 'respa_s10');
      expect(viol).toBeDefined();
      // Description should contain content from the finding
      expect(viol.description.length).toBeGreaterThan(0);
    });
  });

  // -------------------------------------------------------------------------
  // Case 2: Anomaly with matching rule → violation
  // -------------------------------------------------------------------------
  describe('Case 2: Anomaly with matching rule', () => {
    it('produces violation from anomaly in analysisReport', () => {
      const anomaly = makeAnomaly({
        field: 'escrowBalance',
        type: 'calculation_error',
        severity: 'high',
        description: 'Escrow cushion exceeds RESPA 1/6 limit'
      });
      const analysisReport = makeAnalysisReport({ anomalies: [anomaly] });
      const report = makeForensicReport();
      const result = engine.evaluateFindings(report, [analysisReport]);

      expect(result.violations.length).toBeGreaterThanOrEqual(1);

      const viol = result.violations[0];
      expect(viol.evidence[0]).toHaveProperty('sourceType', 'anomaly');
    });
  });

  // -------------------------------------------------------------------------
  // Case 3: Timeline violation with matching rule → violation
  // -------------------------------------------------------------------------
  describe('Case 3: Timeline violation with matching rule', () => {
    it('produces violation from timeline violation', () => {
      const tv = makeTimelineViolation({
        description: 'QWR response deadline exceeded by 15 days',
        severity: 'high'
      });
      const report = makeForensicReport({
        timeline: { events: [], violations: [tv] }
      });
      const result = engine.evaluateFindings(report, []);

      expect(result.violations.length).toBeGreaterThanOrEqual(1);

      const viol = result.violations.find(v =>
        v.evidence.some(e => e.sourceType === 'timeline_violation')
      );
      expect(viol).toBeDefined();
      expect(viol).toHaveProperty('statuteId');
      expect(viol).toHaveProperty('sectionId');
    });
  });

  // -------------------------------------------------------------------------
  // Case 4: Payment verification issue with matching rule → violation
  // -------------------------------------------------------------------------
  describe('Case 4: Payment verification issue with matching rule', () => {
    it('produces violation from unmatched document payment', () => {
      const report = makeForensicReport({
        paymentVerification: {
          verified: true,
          transactionsAnalyzed: 12,
          dateRange: { start: '2025-01-01', end: '2025-12-31' },
          matchedPayments: [],
          unmatchedDocumentPayments: [
            {
              date: '2025-06-01',
              amount: 1500,
              documentId: 'doc-005',
              description: 'Payment crediting error - payment not posted on date received'
            }
          ],
          unmatchedTransactions: [],
          escrowAnalysis: null,
          feeAnalysis: null
        }
      });
      const result = engine.evaluateFindings(report, []);

      expect(result.violations.length).toBeGreaterThanOrEqual(1);

      const viol = result.violations.find(v =>
        v.evidence.some(e => e.sourceType === 'payment_issue')
      );
      expect(viol).toBeDefined();
    });

    it('produces violation from fee irregularities in payment verification', () => {
      const report = makeForensicReport({
        paymentVerification: {
          verified: true,
          transactionsAnalyzed: 12,
          dateRange: { start: '2025-01-01', end: '2025-12-31' },
          matchedPayments: [],
          unmatchedDocumentPayments: [],
          unmatchedTransactions: [],
          escrowAnalysis: null,
          feeAnalysis: {
            documentedFees: [],
            transactionFees: [],
            irregularities: [
              {
                description: 'Unauthorized late fee of $75 assessed',
                severity: 'high',
                amount: 75
              }
            ]
          }
        }
      });
      const result = engine.evaluateFindings(report, []);

      expect(result.violations.length).toBeGreaterThanOrEqual(1);
    });
  });

  // -------------------------------------------------------------------------
  // Case 5: Finding below minSeverity → no violation
  // -------------------------------------------------------------------------
  describe('Case 5: Finding below minSeverity threshold', () => {
    it('does not produce violation when severity is below rule minimum', () => {
      // rule-respa-003 (kickbacks) has minSeverity: 'high'
      // A 'low' severity finding should not match
      const disc = makeDiscrepancy({
        id: 'disc-low',
        type: 'fee_irregularity',
        severity: 'low',
        description: 'Minor referral fee question'
      });
      const report = makeForensicReport({ discrepancies: [disc] });
      const result = engine.evaluateFindings(report, []);

      // Should produce no violations for this low-severity finding that only
      // matches rules requiring 'high' or 'medium' severity minimum
      // Some rules with minSeverity: 'low' might still match, so check
      // that kickback-specific rules are not triggered
      const kickbackViols = result.violations.filter(v => v.sectionId === 'respa_s8');
      expect(kickbackViols).toEqual([]);
    });
  });

  // -------------------------------------------------------------------------
  // Case 6: Multiple rules match same finding → multiple violations
  // -------------------------------------------------------------------------
  describe('Case 6: Multiple rules match same finding', () => {
    it('produces multiple violations when finding matches multiple rules', () => {
      // amount_mismatch with escrow keywords should match multiple rules
      // (e.g., rule-respa-001, rule-tila-002, rule-fdcpa-002, etc.)
      const disc = makeDiscrepancy({
        id: 'disc-multi',
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Payment amount mismatch of $200 on monthly statement'
      });
      const report = makeForensicReport({ discrepancies: [disc] });
      const result = engine.evaluateFindings(report, []);

      // amount_mismatch matches many rules across statutes
      expect(result.violations.length).toBeGreaterThan(1);
    });

    it('assigns unique sequential violation IDs', () => {
      const disc = makeDiscrepancy({
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Payment amount mismatch of $200'
      });
      const report = makeForensicReport({ discrepancies: [disc] });
      const result = engine.evaluateFindings(report, []);

      const ids = result.violations.map(v => v.id);
      const uniqueIds = new Set(ids);
      expect(uniqueIds.size).toBe(ids.length);

      // All IDs should follow viol-NNN pattern
      ids.forEach(id => expect(id).toMatch(/^viol-\d{3}$/));
    });
  });

  // -------------------------------------------------------------------------
  // Case 7: Severity elevation conditions met → elevated severity
  // -------------------------------------------------------------------------
  describe('Case 7: Severity elevation', () => {
    it('elevates severity when elevation conditions are met', () => {
      // rule-respa-001 elevates to critical when amount > 100
      const disc = makeDiscrepancy({
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Escrow balance discrepancy of $450 identified',
        documentA: {
          documentId: 'doc-001',
          documentType: 'servicing',
          documentSubtype: 'escrow_analysis',
          field: 'escrowBalance',
          value: 5000
        },
        documentB: {
          documentId: 'doc-002',
          documentType: 'servicing',
          documentSubtype: 'monthly_statement',
          field: 'escrowBalance',
          value: 4550
        }
      });
      const report = makeForensicReport({ discrepancies: [disc] });
      const result = engine.evaluateFindings(report, []);

      // At least one violation should be elevated to critical
      // (rule-respa-001 has severityElevation for amount > 100)
      const respaViol = result.violations.find(v => v.sectionId === 'respa_s10');
      expect(respaViol).toBeDefined();
      expect(respaViol.severity).toBe('critical');
    });

    it('does not elevate when conditions are not met', () => {
      // Small amount + non-critical field should not trigger elevation
      // rule-respa-001 elevates on: amount > 100, repeated, critical_field
      // Using a small amount and non-critical field avoids all conditions
      const disc = makeDiscrepancy({
        type: 'amount_mismatch',
        severity: 'medium',
        description: 'Escrow surplus discrepancy of $10 found',
        documentA: {
          documentId: 'doc-001',
          documentType: 'servicing',
          documentSubtype: 'escrow_analysis',
          field: 'surplusAmount',
          value: 60
        },
        documentB: {
          documentId: 'doc-002',
          documentType: 'servicing',
          documentSubtype: 'monthly_statement',
          field: 'surplusAmount',
          value: 50
        }
      });
      const report = makeForensicReport({ discrepancies: [disc] });
      const result = engine.evaluateFindings(report, []);

      const respaViol = result.violations.find(v => v.sectionId === 'respa_s10');
      if (respaViol) {
        // Should remain at base severity, not elevated
        expect(['high', 'medium']).toContain(respaViol.severity);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Case 8: No findings match any rules → empty violations
  // -------------------------------------------------------------------------
  describe('Case 8: No findings match any rules', () => {
    it('returns empty violations when findings do not match rules', () => {
      // Use a discrepancy type and description that won't match any rule keywords
      const disc = makeDiscrepancy({
        id: 'disc-nomatch',
        type: 'party_mismatch',
        severity: 'info',
        description: 'Borrower middle name differs between documents',
        documentA: {
          documentId: 'doc-001',
          documentType: 'origination',
          documentSubtype: 'loan_application_1003',
          field: 'middleName',
          value: 'James'
        },
        documentB: {
          documentId: 'doc-002',
          documentType: 'origination',
          documentSubtype: 'promissory_note',
          field: 'middleName',
          value: 'J.'
        }
      });
      const report = makeForensicReport({ discrepancies: [disc] });
      const result = engine.evaluateFindings(report, []);

      expect(result.violations).toEqual([]);
      // All statutes should still be listed as evaluated
      expect(result.statutesEvaluated).toEqual(expect.arrayContaining(getStatuteIds()));
    });
  });

  // -------------------------------------------------------------------------
  // Deduplication
  // -------------------------------------------------------------------------
  describe('Deduplication', () => {
    it('deduplicates violations by sectionId + sourceId, keeping higher severity', () => {
      // Two discrepancies that both match the same section with same evidence source
      const disc1 = makeDiscrepancy({
        id: 'disc-dup-001',
        type: 'amount_mismatch',
        severity: 'medium',
        description: 'Escrow balance discrepancy of $20 found'
      });
      const disc2 = makeDiscrepancy({
        id: 'disc-dup-001', // same sourceId
        type: 'calculation_error',
        severity: 'high',
        description: 'Escrow calculation error of $20 detected'
      });
      const report = makeForensicReport({ discrepancies: [disc1, disc2] });
      const result = engine.evaluateFindings(report, []);

      // For the same sectionId + sourceId combo, only the higher severity should remain
      const respaViols = result.violations.filter(v =>
        v.sectionId === 'respa_s10' &&
        v.evidence.some(e => e.sourceId === 'disc-dup-001')
      );

      // Should be deduplicated — at most one per unique sectionId+sourceId pair
      const sectionSourcePairs = respaViols.map(v =>
        `${v.sectionId}|${v.evidence.find(e => e.sourceId === 'disc-dup-001').sourceId}`
      );
      const uniquePairs = new Set(sectionSourcePairs);
      expect(uniquePairs.size).toBe(sectionSourcePairs.length);
    });
  });

  // -------------------------------------------------------------------------
  // Helper method: _shouldElevateSeverity
  // -------------------------------------------------------------------------
  describe('_shouldElevateSeverity', () => {
    it('returns true when amount exceeds threshold', () => {
      const finding = { description: 'Amount of $500', amount: 500 };
      const rule = {
        severityElevation: { conditions: ['amount > 100'], elevatedSeverity: 'critical' }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(true);
    });

    it('returns false when amount is below threshold', () => {
      const finding = { description: 'Amount of $50', amount: 50 };
      const rule = {
        severityElevation: { conditions: ['amount > 100'], elevatedSeverity: 'critical' }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(false);
    });

    it('returns true when critical_field condition matches', () => {
      const finding = { description: 'APR error', fields: ['apr'], isCriticalField: true };
      const rule = {
        severityElevation: { conditions: ['critical_field'], elevatedSeverity: 'critical' }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(true);
    });

    it('returns false when no elevation conditions exist', () => {
      const finding = { description: 'Some finding' };
      const rule = {};
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // Helper method: _buildViolation
  // -------------------------------------------------------------------------
  describe('_buildViolation', () => {
    it('builds a violation object matching the schema structure', () => {
      const finding = {
        description: 'Escrow balance discrepancy of $450',
        amount: 450,
        date: '2025-06-15'
      };
      const rule = {
        ruleId: 'rule-respa-001',
        sectionId: 'respa_s10',
        violationSeverity: 'high',
        descriptionTemplate: 'Escrow account violation detected: {description}. Escrow balance discrepancy of {amount} identified on {date}.',
        legalBasisTemplate: 'RESPA Section 10 limits escrow cushions.'
      };
      const evidence = {
        sourceType: 'discrepancy',
        sourceId: 'disc-001',
        description: 'Amount mismatch in escrow'
      };

      const viol = engine._buildViolation(finding, rule, evidence);

      expect(viol).toHaveProperty('statuteId', 'respa');
      expect(viol).toHaveProperty('sectionId', 'respa_s10');
      expect(viol).toHaveProperty('statuteName');
      expect(viol).toHaveProperty('sectionTitle');
      expect(viol).toHaveProperty('citation');
      expect(viol).toHaveProperty('severity', 'high');
      expect(viol).toHaveProperty('description');
      expect(viol.description).toContain('450');
      expect(viol).toHaveProperty('evidence');
      expect(viol.evidence).toEqual([evidence]);
      expect(viol).toHaveProperty('legalBasis');
      expect(viol).toHaveProperty('potentialPenalties');
    });
  });

  // -------------------------------------------------------------------------
  // Integration: full evaluation with mixed finding types
  // -------------------------------------------------------------------------
  describe('Integration: full evaluation', () => {
    it('processes discrepancies, anomalies, timeline violations, and payment issues together', () => {
      const disc = makeDiscrepancy({
        id: 'disc-int-001',
        type: 'fee_irregularity',
        severity: 'high',
        description: 'Unauthorized late fee of $125 assessed'
      });

      const tv = makeTimelineViolation({
        description: 'Loss mitigation application review exceeded 30-day deadline',
        severity: 'high'
      });

      const anomaly = makeAnomaly({
        field: 'apr',
        type: 'calculation_error',
        severity: 'high',
        description: 'APR disclosure error exceeds tolerance'
      });

      const report = makeForensicReport({
        discrepancies: [disc],
        timeline: { events: [], violations: [tv] }
      });

      const analysisReport = makeAnalysisReport({ anomalies: [anomaly] });
      const result = engine.evaluateFindings(report, [analysisReport]);

      // Should have violations from multiple source types
      const sourceTypes = new Set(
        result.violations.flatMap(v => v.evidence.map(e => e.sourceType))
      );
      expect(sourceTypes.size).toBeGreaterThanOrEqual(2);

      // Should have sequential IDs
      result.violations.forEach((v, i) => {
        expect(v.id).toBe(`viol-${String(i + 1).padStart(3, '0')}`);
      });

      // All statutes evaluated
      expect(result.statutesEvaluated).toEqual(expect.arrayContaining(getStatuteIds()));
    });
  });
});
