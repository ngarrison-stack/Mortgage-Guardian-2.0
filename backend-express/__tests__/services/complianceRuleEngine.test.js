/**
 * Supplementary tests for ComplianceRuleEngine branch coverage
 *
 * Targets uncovered lines: 400, 412, 508-509, 595-611, 653-705
 * Focus: state anomalies, state payment issues, _extractDate,
 * _extractAmountFromText, and edge-case branches.
 */

const { getStateStatuteIds } = require('../../config/stateStatuteTaxonomy');

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeForensicReport(overrides = {}) {
  return {
    caseId: 'case-branch-001',
    analyzedAt: '2026-04-01T12:00:00.000Z',
    documentsAnalyzed: 2,
    comparisonPairsEvaluated: 1,
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
      documentType: 'origination',
      documentSubtype: 'closing_disclosure',
      field: 'escrowBalance',
      value: 4550
    },
    ...overrides
  };
}

function makeJurisdiction(overrides = {}) {
  return {
    applicableStates: ['CA'],
    ...overrides
  };
}

// ============================================================
// Tests
// ============================================================

describe('ComplianceRuleEngine — branch coverage', () => {
  let engine;

  beforeAll(() => {
    engine = require('../../services/complianceRuleEngine');
  });

  // ================================================================
  // _extractDate — line 400 (true branch)
  // ================================================================
  describe('_extractDate', () => {
    it('returns date string when documentA.value is a date', () => {
      const disc = {
        documentA: { value: '2025-03-15' },
        documentB: { value: 100 }
      };
      const result = engine._extractDate(disc);
      expect(result).toBe('2025-03-15');
    });

    it('returns undefined when documentA.value is not a date string', () => {
      const disc = {
        documentA: { value: 5000 },
        documentB: { value: 4500 }
      };
      const result = engine._extractDate(disc);
      expect(result).toBeUndefined();
    });

    it('returns undefined when documentA is missing', () => {
      const result = engine._extractDate({});
      expect(result).toBeUndefined();
    });

    it('returns undefined when documentA.value is a string without date pattern', () => {
      const disc = { documentA: { value: 'not-a-date' } };
      const result = engine._extractDate(disc);
      expect(result).toBeUndefined();
    });
  });

  // ================================================================
  // _extractAmountFromText — line 412 (match branch)
  // ================================================================
  describe('_extractAmountFromText', () => {
    it('extracts dollar amount from text', () => {
      const result = engine._extractAmountFromText('Payment of $1,250.00 received');
      expect(result).toBe(1250);
    });

    it('extracts simple dollar amount without cents', () => {
      const result = engine._extractAmountFromText('Overcharge of $500 detected');
      expect(result).toBe(500);
    });

    it('returns null when no dollar amount present', () => {
      const result = engine._extractAmountFromText('No amount here');
      expect(result).toBeNull();
    });

    it('returns null for null text', () => {
      const result = engine._extractAmountFromText(null);
      expect(result).toBeNull();
    });

    it('returns null for empty string', () => {
      const result = engine._extractAmountFromText('');
      expect(result).toBeNull();
    });

    it('returns null for undefined text', () => {
      const result = engine._extractAmountFromText(undefined);
      expect(result).toBeNull();
    });
  });

  // ================================================================
  // _resolveAmount
  // ================================================================
  describe('_resolveAmount', () => {
    it('returns numeric amount directly', () => {
      expect(engine._resolveAmount({ amount: 450 })).toBe(450);
    });

    it('falls back to extracting from description', () => {
      expect(engine._resolveAmount({ description: 'Charge of $200.50' })).toBe(200.50);
    });

    it('returns null when no amount available', () => {
      expect(engine._resolveAmount({ description: 'No dollar amount' })).toBeNull();
    });
  });

  // ================================================================
  // _extractAmount — edge cases
  // ================================================================
  describe('_extractAmount', () => {
    it('computes difference when both values are numeric', () => {
      const disc = {
        documentA: { value: 5000 },
        documentB: { value: 4550 }
      };
      expect(engine._extractAmount(disc)).toBe(450);
    });

    it('falls back to text extraction when values are not numeric', () => {
      const disc = {
        documentA: { value: 'five thousand' },
        documentB: { value: 'four thousand' },
        description: 'Difference of $450'
      };
      expect(engine._extractAmount(disc)).toBe(450);
    });

    it('falls back when documentA or documentB is missing', () => {
      const disc = { description: 'Discrepancy of $100' };
      expect(engine._extractAmount(disc)).toBe(100);
    });

    it('returns null when neither method yields a value', () => {
      const disc = { description: 'Generic discrepancy' };
      expect(engine._extractAmount(disc)).toBeNull();
    });
  });

  // ================================================================
  // _isCriticalField — branches
  // ================================================================
  describe('_isCriticalField', () => {
    it('returns true for APR field', () => {
      expect(engine._isCriticalField({ fields: ['apr'] })).toBe(true);
    });

    it('returns true for interestRate field', () => {
      expect(engine._isCriticalField({ fields: ['interestRate'] })).toBe(true);
    });

    it('returns true when isCriticalField is already set', () => {
      expect(engine._isCriticalField({ isCriticalField: true, fields: [] })).toBe(true);
    });

    it('returns false for non-critical fields', () => {
      expect(engine._isCriticalField({ fields: ['borrowerName'] })).toBe(false);
    });

    it('checks documentA.field and documentB.field', () => {
      expect(engine._isCriticalField({
        fields: [],
        documentA: { field: 'principalBalance' },
        documentB: { field: 'otherField' }
      })).toBe(true);
    });
  });

  // ================================================================
  // _fillTemplate
  // ================================================================
  describe('_fillTemplate', () => {
    it('replaces {description}, {amount}, {date} placeholders', () => {
      const template = 'Issue: {description}. Amount: {amount}. Date: {date}.';
      const finding = { description: 'Overcharge', amount: 450, date: '2025-01-15' };
      const result = engine._fillTemplate(template, finding);
      expect(result).toBe('Issue: Overcharge. Amount: $450. Date: 2025-01-15.');
    });

    it('uses N/A for missing values', () => {
      const template = '{description} - {amount} - {date}';
      const result = engine._fillTemplate(template, {});
      expect(result).toBe('N/A - N/A - N/A');
    });

    it('returns empty string for null template', () => {
      expect(engine._fillTemplate(null, {})).toBe('');
    });
  });

  // ================================================================
  // _buildCitation
  // ================================================================
  describe('_buildCitation', () => {
    it('combines statute and section citations', () => {
      const statute = { citation: '12 U.S.C. § 2601' };
      const section = { regulatoryReference: '12 CFR § 1024.17' };
      expect(engine._buildCitation(statute, section)).toBe('12 U.S.C. § 2601; 12 CFR § 1024.17');
    });

    it('returns statute citation only when section is null', () => {
      expect(engine._buildCitation({ citation: '12 U.S.C.' }, null)).toBe('12 U.S.C.');
    });

    it('returns "Unknown citation" when both are null', () => {
      expect(engine._buildCitation(null, null)).toBe('Unknown citation');
    });
  });

  // ================================================================
  // _countPaymentFindings
  // ================================================================
  describe('_countPaymentFindings', () => {
    it('counts unmatched payments and fee irregularities', () => {
      const pv = {
        unmatchedDocumentPayments: [{ amount: 100 }, { amount: 200 }],
        feeAnalysis: { irregularities: [{ amount: 50 }] }
      };
      expect(engine._countPaymentFindings(pv)).toBe(3);
    });

    it('handles missing fields', () => {
      expect(engine._countPaymentFindings({})).toBe(0);
    });
  });

  // ================================================================
  // _shouldElevateSeverity — branch coverage
  // ================================================================
  describe('_shouldElevateSeverity', () => {
    it('elevates when amount exceeds threshold', () => {
      const finding = { amount: 200, description: '' };
      const rule = {
        severityElevation: {
          conditions: ['amount > 100'],
          elevatedSeverity: 'critical'
        }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(true);
    });

    it('does not elevate when amount is below threshold', () => {
      const finding = { amount: 50, description: '' };
      const rule = {
        severityElevation: {
          conditions: ['amount > 100'],
          elevatedSeverity: 'critical'
        }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(false);
    });

    it('elevates for critical_field condition', () => {
      const finding = { isCriticalField: true };
      const rule = {
        severityElevation: {
          conditions: ['critical_field'],
          elevatedSeverity: 'critical'
        }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(true);
    });

    it('does not elevate for critical_field when field is not critical', () => {
      const finding = { isCriticalField: false };
      const rule = {
        severityElevation: {
          conditions: ['critical_field'],
          elevatedSeverity: 'critical'
        }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(false);
    });

    it('skips "repeated" condition without error', () => {
      const finding = { amount: 50 };
      const rule = {
        severityElevation: {
          conditions: ['repeated'],
          elevatedSeverity: 'critical'
        }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(false);
    });

    it('returns false when rule is null', () => {
      expect(engine._shouldElevateSeverity({}, null)).toBe(false);
    });

    it('returns false when no severityElevation', () => {
      expect(engine._shouldElevateSeverity({}, {})).toBe(false);
    });

    it('returns false when conditions array is missing', () => {
      expect(engine._shouldElevateSeverity({}, { severityElevation: {} })).toBe(false);
    });

    it('handles amount from description fallback', () => {
      const finding = { description: 'Overcharge of $200' };
      const rule = {
        severityElevation: {
          conditions: ['amount > 100'],
          elevatedSeverity: 'critical'
        }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(true);
    });

    it('handles null amount (no match)', () => {
      const finding = { description: 'No dollar amount' };
      const rule = {
        severityElevation: {
          conditions: ['amount > 100'],
          elevatedSeverity: 'critical'
        }
      };
      expect(engine._shouldElevateSeverity(finding, rule)).toBe(false);
    });
  });

  // ================================================================
  // _deduplicateViolations
  // ================================================================
  describe('_deduplicateViolations', () => {
    it('keeps higher severity when duplicates found', () => {
      const violations = [
        {
          sectionId: 'respa_s10',
          ruleId: 'rule-001',
          severity: 'medium',
          evidence: [{ sourceId: 'disc-001' }]
        },
        {
          sectionId: 'respa_s10',
          ruleId: 'rule-001',
          severity: 'high',
          evidence: [{ sourceId: 'disc-001' }]
        }
      ];

      const result = engine._deduplicateViolations(violations);
      expect(result).toHaveLength(1);
      expect(result[0].severity).toBe('high');
      expect(result[0].deduplicationNote).toContain('Consolidated 2');
    });

    it('keeps both when ruleId differs', () => {
      const violations = [
        {
          sectionId: 'respa_s10',
          ruleId: 'rule-001',
          severity: 'high',
          evidence: [{ sourceId: 'disc-001' }]
        },
        {
          sectionId: 'respa_s10',
          ruleId: 'rule-002',
          severity: 'medium',
          evidence: [{ sourceId: 'disc-001' }]
        }
      ];

      const result = engine._deduplicateViolations(violations);
      expect(result).toHaveLength(2);
    });

    it('handles violation with no evidence', () => {
      const violations = [
        {
          sectionId: 'respa_s10',
          ruleId: 'rule-001',
          severity: 'high',
          evidence: [null]
        }
      ];
      const result = engine._deduplicateViolations(violations);
      expect(result).toHaveLength(1);
    });

    it('handles unknown severity values', () => {
      const violations = [
        {
          sectionId: 'sec1',
          ruleId: 'rule-1',
          severity: 'unknown_sev',
          evidence: [{ sourceId: 'src1' }]
        },
        {
          sectionId: 'sec1',
          ruleId: 'rule-1',
          severity: 'also_unknown',
          evidence: [{ sourceId: 'src1' }]
        }
      ];
      const result = engine._deduplicateViolations(violations);
      expect(result).toHaveLength(1);
    });
  });

  // ================================================================
  // evaluateStateFindings — state anomalies (lines 508-509, 595-611)
  // ================================================================
  describe('evaluateStateFindings — state anomalies', () => {
    it('evaluates anomalies from analysis reports against state rules', () => {
      const report = makeForensicReport();
      const analysisReports = [
        {
          anomalies: [
            {
              type: 'calculation_error',
              severity: 'high',
              description: 'Escrow calculation error of $300 found in statement',
              field: 'escrowBalance'
            }
          ]
        }
      ];
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, analysisReports, jurisdiction);
      expect(result).not.toHaveProperty('error');
      // Anomalies should be processed — may or may not match CA rules
      expect(result.evaluationMeta.totalFindingsEvaluated).toBeGreaterThanOrEqual(1);
    });

    it('handles anomalies without field property', () => {
      const report = makeForensicReport();
      const analysisReports = [
        {
          anomalies: [
            {
              type: 'unusual_value',
              severity: 'medium',
              description: 'Unusual fee of $500 detected'
            }
          ]
        }
      ];
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, analysisReports, jurisdiction);
      expect(result).not.toHaveProperty('error');
    });

    it('handles multiple anomalies from multiple reports', () => {
      const report = makeForensicReport();
      const analysisReports = [
        {
          anomalies: [
            { type: 'calculation_error', severity: 'high', description: 'Error $200', field: 'escrowBalance' }
          ]
        },
        {
          anomalies: [
            { type: 'unusual_value', severity: 'medium', description: 'Unusual fee $100', field: 'fee' }
          ]
        }
      ];
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, analysisReports, jurisdiction);
      expect(result).not.toHaveProperty('error');
      expect(result.evaluationMeta.totalFindingsEvaluated).toBeGreaterThanOrEqual(2);
    });

    it('skips reports without anomalies array', () => {
      const report = makeForensicReport();
      const analysisReports = [
        { someOtherData: true },
        null,
        { anomalies: [{ type: 'calculation_error', severity: 'high', description: 'Error $300', field: 'escrowBalance' }] }
      ];
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, analysisReports, jurisdiction);
      expect(result).not.toHaveProperty('error');
    });
  });

  // ================================================================
  // evaluateStateFindings — state payment issues (lines 653-705)
  // ================================================================
  describe('evaluateStateFindings — state payment issues', () => {
    it('evaluates unmatched payments against state rules', () => {
      const report = makeForensicReport({
        paymentVerification: {
          unmatchedDocumentPayments: [
            { amount: 1200, date: '2025-03-01', description: 'Unmatched payment of $1200' }
          ],
          feeAnalysis: null
        }
      });
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, [], jurisdiction);
      expect(result).not.toHaveProperty('error');
      expect(result.evaluationMeta.totalFindingsEvaluated).toBeGreaterThanOrEqual(1);
    });

    it('evaluates unmatched payments without description', () => {
      const report = makeForensicReport({
        paymentVerification: {
          unmatchedDocumentPayments: [
            { amount: 500, date: '2025-02-15' }
          ]
        }
      });
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, [], jurisdiction);
      expect(result).not.toHaveProperty('error');
    });

    it('evaluates fee irregularities against state rules', () => {
      const report = makeForensicReport({
        paymentVerification: {
          unmatchedDocumentPayments: [],
          feeAnalysis: {
            irregularities: [
              { amount: 75, severity: 'high', description: 'Late fee of $75 exceeds CA limit' }
            ]
          }
        }
      });
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, [], jurisdiction);
      expect(result).not.toHaveProperty('error');
    });

    it('evaluates fee irregularities without severity or description', () => {
      const report = makeForensicReport({
        paymentVerification: {
          unmatchedDocumentPayments: [],
          feeAnalysis: {
            irregularities: [
              { amount: 50 }
            ]
          }
        }
      });
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, [], jurisdiction);
      expect(result).not.toHaveProperty('error');
    });

    it('handles combined payment issues and fee irregularities', () => {
      const report = makeForensicReport({
        paymentVerification: {
          unmatchedDocumentPayments: [
            { amount: 1000, date: '2025-01-15', description: 'Unmatched $1000 payment' }
          ],
          feeAnalysis: {
            irregularities: [
              { amount: 150, severity: 'medium', description: 'Fee irregularity of $150' },
              { amount: 75, severity: 'low', description: 'Minor fee issue $75' }
            ]
          }
        }
      });
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, [], jurisdiction);
      expect(result).not.toHaveProperty('error');
      expect(result.evaluationMeta.totalFindingsEvaluated).toBeGreaterThanOrEqual(3);
    });

    it('handles null paymentVerification in state evaluation', () => {
      const report = makeForensicReport({ paymentVerification: null });
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, [], jurisdiction);
      expect(result).not.toHaveProperty('error');
    });

    it('evaluates payment issues across multiple states', () => {
      const report = makeForensicReport({
        paymentVerification: {
          unmatchedDocumentPayments: [
            { amount: 800, date: '2025-03-01', description: 'Unmatched payment $800' }
          ],
          feeAnalysis: {
            irregularities: [
              { amount: 100, severity: 'high', description: 'Excessive fee of $100' }
            ]
          }
        }
      });
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA', 'NY'] });

      const result = engine.evaluateStateFindings(report, [], jurisdiction);
      expect(result).not.toHaveProperty('error');
      expect(result.evaluationMeta.statesEvaluated).toBe(2);
    });
  });

  // ================================================================
  // evaluateStateFindings — combined anomalies + payments
  // ================================================================
  describe('evaluateStateFindings — combined finding types', () => {
    it('processes discrepancies, anomalies, timeline, and payments together', () => {
      const disc = makeDiscrepancy({
        id: 'disc-combined-001',
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Escrow overcharge of $300'
      });
      const report = makeForensicReport({
        discrepancies: [disc],
        timeline: {
          events: [],
          violations: [
            { severity: 'high', description: 'Foreclosure deadline exceeded' }
          ]
        },
        paymentVerification: {
          unmatchedDocumentPayments: [
            { amount: 500, date: '2025-01-01' }
          ],
          feeAnalysis: {
            irregularities: [
              { amount: 50, severity: 'medium', description: 'Late fee $50' }
            ]
          }
        }
      });
      const analysisReports = [
        {
          anomalies: [
            { type: 'calculation_error', severity: 'high', description: 'Calculation error $200', field: 'escrowBalance' }
          ]
        }
      ];
      const jurisdiction = makeJurisdiction({ applicableStates: ['CA'] });

      const result = engine.evaluateStateFindings(report, analysisReports, jurisdiction);
      expect(result).not.toHaveProperty('error');
      // 1 disc + 1 anomaly + 1 timeline + 2 payment findings = 5
      expect(result.evaluationMeta.totalFindingsEvaluated).toBe(5);
    });
  });

  // ================================================================
  // evaluateFindings — edge cases for federal path
  // ================================================================
  describe('evaluateFindings — additional edge cases', () => {
    it('handles discrepancy with date value in documentA', () => {
      const disc = makeDiscrepancy({
        id: 'disc-date-001',
        type: 'timeline_violation',
        severity: 'high',
        description: 'Notice deadline missed',
        documentA: { field: 'noticeDate', value: '2025-03-15' },
        documentB: { field: 'noticeDate', value: '2025-02-15' }
      });
      const report = makeForensicReport({ discrepancies: [disc] });

      const result = engine.evaluateFindings(report, []);
      expect(result).not.toHaveProperty('error');
    });

    it('handles fee irregularities in federal evaluation', () => {
      const report = makeForensicReport({
        paymentVerification: {
          unmatchedDocumentPayments: [],
          feeAnalysis: {
            irregularities: [
              { amount: 200, severity: 'high', description: 'Excessive late fee of $200' }
            ]
          }
        }
      });

      const result = engine.evaluateFindings(report, []);
      expect(result).not.toHaveProperty('error');
      expect(result.evaluationMeta.totalFindingsEvaluated).toBeGreaterThanOrEqual(1);
    });

    it('handles analysisReports that is not an array', () => {
      const report = makeForensicReport();
      const result = engine.evaluateFindings(report, 'not-an-array');
      expect(result).not.toHaveProperty('error');
    });

    it('handles analysisReports with null entries', () => {
      const report = makeForensicReport();
      const result = engine.evaluateFindings(report, [null, undefined, {}]);
      expect(result).not.toHaveProperty('error');
    });
  });

  // ================================================================
  // _buildStateViolation
  // ================================================================
  describe('_buildStateViolation', () => {
    it('builds violation with unknown statute/section when not found in taxonomy', () => {
      const finding = {
        description: 'Test violation',
        amount: 100,
        date: '2025-01-01'
      };
      const rule = {
        ruleId: 'rule-zz-001',
        sectionId: 'zz_fake_section',
        violationSeverity: 'medium',
        descriptionTemplate: 'Violation: {description}',
        legalBasisTemplate: 'Some legal basis'
      };
      const evidence = { sourceType: 'test', sourceId: 'test-001', description: 'test' };

      const result = engine._buildStateViolation('ZZ', finding, rule, evidence);

      expect(result.statuteName).toBe('Unknown Statute');
      expect(result.sectionTitle).toBe('Unknown Section');
      expect(result.citation).toBe('Unknown citation');
      expect(result.jurisdiction).toBe('ZZ');
      expect(result.ruleId).toBe('rule-zz-001');
    });
  });
});
