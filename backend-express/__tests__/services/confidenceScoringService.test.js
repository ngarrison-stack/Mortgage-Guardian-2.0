/**
 * Confidence Scoring & Evidence Linking Service Tests
 *
 * Tests calculateConfidence(), documentAnalysisScore(), forensicAnalysisScore(),
 * complianceAnalysisScore(), determineRiskLevel(), and buildEvidenceLinks()
 * covering clean, degraded, mixed, missing layer, and edge cases.
 *
 * No mocks needed — this is pure calculation logic.
 */

const {
  SCORING_WEIGHTS,
  LAYER_SCORING_FACTORS,
  RISK_THRESHOLDS,
  EVIDENCE_CATEGORIES
} = require('../../config/consolidatedReportConfig');

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

function makeCleanAggregatedData() {
  return {
    documentAnalyses: [
      {
        documentId: 'doc-001',
        documentName: 'statement-jan.pdf',
        type: 'mortgage_statement',
        subtype: 'monthly_statement',
        completenessScore: 95,
        anomalyCount: 0,
        anomalies: [],
        keyFindings: []
      },
      {
        documentId: 'doc-002',
        documentName: 'closing-disclosure.pdf',
        type: 'closing_disclosure',
        subtype: 'initial',
        completenessScore: 100,
        anomalyCount: 0,
        anomalies: [],
        keyFindings: []
      }
    ],
    forensicReport: {
      discrepancies: [],
      timeline: { violations: [] },
      paymentVerification: {
        verified: true,
        unmatchedDocumentPayments: [],
        feeAnalysis: { irregularities: [] }
      }
    },
    complianceReport: {
      violations: [],
      stateViolations: []
    }
  };
}

function makeDegradedAggregatedData() {
  return {
    documentAnalyses: [
      {
        documentId: 'doc-001',
        documentName: 'statement.pdf',
        type: 'mortgage_statement',
        subtype: 'monthly_statement',
        completenessScore: 30,
        anomalyCount: 5,
        anomalies: [
          { id: 'anom-001', field: 'paymentAmount', type: 'unexpected_change', severity: 'critical', description: 'Payment doubled' },
          { id: 'anom-002', field: 'interestRate', type: 'calculation_error', severity: 'high', description: 'Rate mismatch' },
          { id: 'anom-003', field: 'escrowBalance', type: 'missing_data', severity: 'high', description: 'Escrow missing' },
          { id: 'anom-004', field: 'lateCharges', type: 'unexpected_value', severity: 'medium', description: 'Unexpected late fees' },
          { id: 'anom-005', field: 'principalBalance', type: 'calculation_error', severity: 'critical', description: 'Principal wrong' }
        ],
        keyFindings: ['Major issues detected']
      }
    ],
    forensicReport: {
      discrepancies: [
        {
          id: 'disc-001',
          type: 'amount_mismatch',
          severity: 'critical',
          description: 'Payment mismatch',
          documentA: { documentId: 'doc-001' },
          documentB: { documentId: 'doc-002' }
        },
        {
          id: 'disc-002',
          type: 'date_inconsistency',
          severity: 'high',
          description: 'Date mismatch',
          documentA: { documentId: 'doc-001' },
          documentB: { documentId: 'doc-003' }
        },
        {
          id: 'disc-003',
          type: 'rate_mismatch',
          severity: 'critical',
          description: 'Rate mismatch',
          documentA: { documentId: 'doc-002' },
          documentB: { documentId: 'doc-003' }
        }
      ],
      timeline: {
        violations: [
          {
            severity: 'critical',
            description: 'RESPA deadline exceeded',
            relatedDocuments: ['doc-001', 'doc-003'],
            regulation: 'RESPA Section 6'
          }
        ]
      },
      paymentVerification: {
        verified: true,
        unmatchedDocumentPayments: [{ id: 'pm-1' }, { id: 'pm-2' }],
        feeAnalysis: { irregularities: [{ id: 'fee-1' }] }
      }
    },
    complianceReport: {
      violations: [
        {
          id: 'viol-001',
          statuteId: 'respa',
          sectionId: 'respa_qwr_response',
          statuteName: 'Real Estate Settlement Procedures Act',
          sectionTitle: 'QWR Response Requirements',
          citation: '12 USC 2605(e)',
          severity: 'critical',
          description: 'QWR response failure',
          legalBasis: 'RESPA requires response within 30 days',
          sourceDocumentIds: ['doc-001']
        },
        {
          id: 'viol-002',
          statuteId: 'tila',
          sectionId: 'tila_disclosure',
          statuteName: 'Truth in Lending Act',
          sectionTitle: 'Disclosure Requirements',
          citation: '15 USC 1601',
          severity: 'high',
          description: 'Missing disclosure',
          legalBasis: 'TILA requires clear disclosure',
          sourceDocumentIds: ['doc-002']
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
          description: 'Dual tracking violation',
          legalBasis: 'CA HBOR prohibits dual tracking',
          jurisdiction: 'CA',
          sourceDocumentIds: ['doc-001', 'doc-003']
        }
      ]
    }
  };
}

function makeMixedAggregatedData() {
  return {
    documentAnalyses: [
      {
        documentId: 'doc-001',
        documentName: 'statement.pdf',
        type: 'mortgage_statement',
        subtype: 'monthly_statement',
        completenessScore: 70,
        anomalyCount: 2,
        anomalies: [
          { id: 'anom-001', field: 'paymentAmount', type: 'unexpected_change', severity: 'medium', description: 'Minor discrepancy' },
          { id: 'anom-002', field: 'escrowBalance', type: 'missing_data', severity: 'low', description: 'Escrow not shown' }
        ],
        keyFindings: ['Some issues']
      }
    ],
    forensicReport: {
      discrepancies: [
        {
          id: 'disc-001',
          type: 'amount_mismatch',
          severity: 'medium',
          description: 'Minor amount difference',
          documentA: { documentId: 'doc-001' },
          documentB: { documentId: 'doc-002' }
        }
      ],
      timeline: { violations: [] },
      paymentVerification: {
        verified: true,
        unmatchedDocumentPayments: [],
        feeAnalysis: { irregularities: [] }
      }
    },
    complianceReport: {
      violations: [],
      stateViolations: []
    }
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ConfidenceScoringService', () => {
  let service;

  beforeEach(() => {
    jest.isolateModules(() => {
      service = require('../../services/confidenceScoringService');
    });
  });

  // =========================================================================
  // documentAnalysisScore
  // =========================================================================

  describe('documentAnalysisScore', () => {
    it('should return ~100 for complete docs with no anomalies', () => {
      const docs = [
        { completenessScore: 100, anomalyCount: 0, anomalies: [] },
        { completenessScore: 95, anomalyCount: 0, anomalies: [] }
      ];
      const score = service.documentAnalysisScore(docs);
      expect(score).toBeGreaterThanOrEqual(95);
      expect(score).toBeLessThanOrEqual(100);
    });

    it('should return low score for low completeness and many anomalies', () => {
      const docs = [
        {
          completenessScore: 20,
          anomalyCount: 5,
          anomalies: [
            { severity: 'critical' },
            { severity: 'critical' },
            { severity: 'high' },
            { severity: 'high' },
            { severity: 'medium' }
          ]
        }
      ];
      const score = service.documentAnalysisScore(docs);
      expect(score).toBeLessThan(40);
      expect(score).toBeGreaterThanOrEqual(0);
    });

    it('should return 100 for empty array (no docs = no negative evidence)', () => {
      const score = service.documentAnalysisScore([]);
      expect(score).toBe(100);
    });

    it('should penalize more for higher severity anomalies', () => {
      const criticalDocs = [
        {
          completenessScore: 80,
          anomalyCount: 1,
          anomalies: [{ severity: 'critical' }]
        }
      ];
      const lowDocs = [
        {
          completenessScore: 80,
          anomalyCount: 1,
          anomalies: [{ severity: 'low' }]
        }
      ];
      const criticalScore = service.documentAnalysisScore(criticalDocs);
      const lowScore = service.documentAnalysisScore(lowDocs);
      expect(criticalScore).toBeLessThan(lowScore);
    });
  });

  // =========================================================================
  // forensicAnalysisScore
  // =========================================================================

  describe('forensicAnalysisScore', () => {
    it('should return ~100 for no discrepancies, no violations, no payment issues', () => {
      const forensicReport = {
        discrepancies: [],
        timeline: { violations: [] },
        paymentVerification: {
          verified: true,
          unmatchedDocumentPayments: [],
          feeAnalysis: { irregularities: [] }
        }
      };
      const score = service.forensicAnalysisScore(forensicReport);
      expect(score).toBeGreaterThanOrEqual(95);
      expect(score).toBeLessThanOrEqual(100);
    });

    it('should heavily penalize critical discrepancies', () => {
      const forensicReport = {
        discrepancies: [
          { id: 'disc-001', severity: 'critical' },
          { id: 'disc-002', severity: 'critical' }
        ],
        timeline: { violations: [] },
        paymentVerification: {
          verified: true,
          unmatchedDocumentPayments: [],
          feeAnalysis: { irregularities: [] }
        }
      };
      const score = service.forensicAnalysisScore(forensicReport);
      // 2 critical discrepancies (30pts each = 60pts), component drops to 40
      // Weighted: 0.5*40 + 0.3*100 + 0.2*100 = 70
      expect(score).toBeLessThan(75);
    });

    it('should return null for null input (missing, not bad)', () => {
      const score = service.forensicAnalysisScore(null);
      expect(score).toBeNull();
    });

    it('should penalize timeline violations', () => {
      const withViolations = {
        discrepancies: [],
        timeline: {
          violations: [
            { severity: 'critical', description: 'Deadline exceeded' },
            { severity: 'high', description: 'Late notice' }
          ]
        },
        paymentVerification: {
          verified: true,
          unmatchedDocumentPayments: [],
          feeAnalysis: { irregularities: [] }
        }
      };
      const clean = {
        discrepancies: [],
        timeline: { violations: [] },
        paymentVerification: {
          verified: true,
          unmatchedDocumentPayments: [],
          feeAnalysis: { irregularities: [] }
        }
      };
      const violationScore = service.forensicAnalysisScore(withViolations);
      const cleanScore = service.forensicAnalysisScore(clean);
      expect(violationScore).toBeLessThan(cleanScore);
    });

    it('should penalize payment issues', () => {
      const withPaymentIssues = {
        discrepancies: [],
        timeline: { violations: [] },
        paymentVerification: {
          verified: true,
          unmatchedDocumentPayments: [{ id: 'pm-1' }, { id: 'pm-2' }],
          feeAnalysis: { irregularities: [{ id: 'fee-1' }] }
        }
      };
      const clean = {
        discrepancies: [],
        timeline: { violations: [] },
        paymentVerification: {
          verified: true,
          unmatchedDocumentPayments: [],
          feeAnalysis: { irregularities: [] }
        }
      };
      const issueScore = service.forensicAnalysisScore(withPaymentIssues);
      const cleanScore = service.forensicAnalysisScore(clean);
      expect(issueScore).toBeLessThan(cleanScore);
    });
  });

  // =========================================================================
  // complianceAnalysisScore
  // =========================================================================

  describe('complianceAnalysisScore', () => {
    it('should return ~100 for no violations', () => {
      const complianceReport = {
        violations: [],
        stateViolations: []
      };
      const score = service.complianceAnalysisScore(complianceReport);
      expect(score).toBeGreaterThanOrEqual(95);
      expect(score).toBeLessThanOrEqual(100);
    });

    it('should heavily penalize critical federal violations', () => {
      const complianceReport = {
        violations: [
          { id: 'viol-001', severity: 'critical' },
          { id: 'viol-002', severity: 'critical' }
        ],
        stateViolations: []
      };
      const score = service.complianceAnalysisScore(complianceReport);
      // 2 critical violations (38pts each = 76pts), component = 24
      // Score = 0.7*24 + 0.3*100 = 46.8
      expect(score).toBeLessThan(50);
    });

    it('should return null for null input (missing, not bad)', () => {
      const score = service.complianceAnalysisScore(null);
      expect(score).toBeNull();
    });

    it('should compound state violations on top of federal', () => {
      const federalOnly = {
        violations: [{ id: 'viol-001', severity: 'high' }],
        stateViolations: []
      };
      const federalAndState = {
        violations: [{ id: 'viol-001', severity: 'high' }],
        stateViolations: [{ id: 'sviol-001', severity: 'high', jurisdiction: 'CA' }]
      };
      const federalScore = service.complianceAnalysisScore(federalOnly);
      const combinedScore = service.complianceAnalysisScore(federalAndState);
      expect(combinedScore).toBeLessThan(federalScore);
    });

    it('should apply severity multiplier (critical > high > medium > low)', () => {
      const critical = {
        violations: [{ id: 'v1', severity: 'critical' }],
        stateViolations: []
      };
      const high = {
        violations: [{ id: 'v1', severity: 'high' }],
        stateViolations: []
      };
      const medium = {
        violations: [{ id: 'v1', severity: 'medium' }],
        stateViolations: []
      };
      const low = {
        violations: [{ id: 'v1', severity: 'low' }],
        stateViolations: []
      };

      const criticalScore = service.complianceAnalysisScore(critical);
      const highScore = service.complianceAnalysisScore(high);
      const mediumScore = service.complianceAnalysisScore(medium);
      const lowScore = service.complianceAnalysisScore(low);

      expect(criticalScore).toBeLessThan(highScore);
      expect(highScore).toBeLessThan(mediumScore);
      expect(mediumScore).toBeLessThan(lowScore);
    });
  });

  // =========================================================================
  // determineRiskLevel
  // =========================================================================

  describe('determineRiskLevel', () => {
    it('should return critical for score 0-30', () => {
      expect(service.determineRiskLevel(0)).toBe('critical');
      expect(service.determineRiskLevel(15)).toBe('critical');
      expect(service.determineRiskLevel(30)).toBe('critical');
    });

    it('should return high for score 31-55', () => {
      expect(service.determineRiskLevel(31)).toBe('high');
      expect(service.determineRiskLevel(40)).toBe('high');
      expect(service.determineRiskLevel(55)).toBe('high');
    });

    it('should return medium for score 56-75', () => {
      expect(service.determineRiskLevel(56)).toBe('medium');
      expect(service.determineRiskLevel(65)).toBe('medium');
      expect(service.determineRiskLevel(75)).toBe('medium');
    });

    it('should return low for score 76-92', () => {
      expect(service.determineRiskLevel(76)).toBe('low');
      expect(service.determineRiskLevel(85)).toBe('low');
      expect(service.determineRiskLevel(92)).toBe('low');
    });

    it('should return clean for score 93-100', () => {
      expect(service.determineRiskLevel(93)).toBe('clean');
      expect(service.determineRiskLevel(95)).toBe('clean');
      expect(service.determineRiskLevel(100)).toBe('clean');
    });

    it('should correctly classify boundary values (30/55/75/92)', () => {
      // Exact boundary values
      expect(service.determineRiskLevel(30)).toBe('critical');
      expect(service.determineRiskLevel(31)).toBe('high');
      expect(service.determineRiskLevel(55)).toBe('high');
      expect(service.determineRiskLevel(56)).toBe('medium');
      expect(service.determineRiskLevel(75)).toBe('medium');
      expect(service.determineRiskLevel(76)).toBe('low');
      expect(service.determineRiskLevel(92)).toBe('low');
      expect(service.determineRiskLevel(93)).toBe('clean');
    });
  });

  // =========================================================================
  // calculateConfidence
  // =========================================================================

  describe('calculateConfidence', () => {
    it('should return high overall score for clean case', () => {
      const data = makeCleanAggregatedData();
      const result = service.calculateConfidence(data);

      expect(result.overall).toBeGreaterThanOrEqual(95);
      expect(result.overall).toBeLessThanOrEqual(100);
      expect(result.breakdown.documentAnalysis).toBeGreaterThanOrEqual(95);
      expect(result.breakdown.forensicAnalysis).toBeGreaterThanOrEqual(95);
      expect(result.breakdown.complianceAnalysis).toBeGreaterThanOrEqual(95);
    });

    it('should return degraded overall score for high anomalies + discrepancies', () => {
      const data = makeDegradedAggregatedData();
      const result = service.calculateConfidence(data);

      expect(result.overall).toBeGreaterThanOrEqual(0);
      expect(result.overall).toBeLessThanOrEqual(40);
      expect(result.breakdown.documentAnalysis).toBeLessThan(50);
      expect(result.breakdown.forensicAnalysis).toBeLessThan(50);
      expect(result.breakdown.complianceAnalysis).toBeLessThan(50);
    });

    it('should return proportional score for mixed case', () => {
      const data = makeMixedAggregatedData();
      const result = service.calculateConfidence(data);

      // Mixed: some anomalies, one discrepancy, no compliance issues
      expect(result.overall).toBeGreaterThan(40);
      expect(result.overall).toBeLessThan(95);
      // Compliance should be high (no violations)
      expect(result.breakdown.complianceAnalysis).toBeGreaterThanOrEqual(95);
    });

    it('should handle missing forensic data with weight redistribution', () => {
      const data = makeCleanAggregatedData();
      data.forensicReport = null;

      const result = service.calculateConfidence(data);

      expect(result.breakdown.forensicAnalysis).toBeNull();
      // Overall should still be calculated from available layers
      expect(result.overall).toBeGreaterThanOrEqual(95);
      expect(result.overall).toBeLessThanOrEqual(100);
      expect(result.breakdown.documentAnalysis).toBeGreaterThanOrEqual(95);
      expect(result.breakdown.complianceAnalysis).toBeGreaterThanOrEqual(95);
    });

    it('should handle missing compliance data with weight redistribution', () => {
      const data = makeCleanAggregatedData();
      data.complianceReport = null;

      const result = service.calculateConfidence(data);

      expect(result.breakdown.complianceAnalysis).toBeNull();
      expect(result.overall).toBeGreaterThanOrEqual(95);
      expect(result.overall).toBeLessThanOrEqual(100);
    });

    it('should return overall 100 for empty case (no problems = clean)', () => {
      const data = {
        documentAnalyses: [],
        forensicReport: null,
        complianceReport: null
      };

      const result = service.calculateConfidence(data);

      expect(result.overall).toBe(100);
      expect(result.breakdown.documentAnalysis).toBe(100);
      expect(result.breakdown.forensicAnalysis).toBeNull();
      expect(result.breakdown.complianceAnalysis).toBeNull();
    });

    it('should return scores clamped between 0 and 100', () => {
      const data = makeDegradedAggregatedData();
      const result = service.calculateConfidence(data);

      expect(result.overall).toBeGreaterThanOrEqual(0);
      expect(result.overall).toBeLessThanOrEqual(100);
      if (result.breakdown.documentAnalysis !== null) {
        expect(result.breakdown.documentAnalysis).toBeGreaterThanOrEqual(0);
        expect(result.breakdown.documentAnalysis).toBeLessThanOrEqual(100);
      }
      if (result.breakdown.forensicAnalysis !== null) {
        expect(result.breakdown.forensicAnalysis).toBeGreaterThanOrEqual(0);
        expect(result.breakdown.forensicAnalysis).toBeLessThanOrEqual(100);
      }
      if (result.breakdown.complianceAnalysis !== null) {
        expect(result.breakdown.complianceAnalysis).toBeGreaterThanOrEqual(0);
        expect(result.breakdown.complianceAnalysis).toBeLessThanOrEqual(100);
      }
    });

    it('should be deterministic (same input = same output)', () => {
      const data = makeMixedAggregatedData();
      const result1 = service.calculateConfidence(data);
      const result2 = service.calculateConfidence(data);

      expect(result1.overall).toBe(result2.overall);
      expect(result1.breakdown).toEqual(result2.breakdown);
    });
  });

  // =========================================================================
  // buildEvidenceLinks
  // =========================================================================

  describe('buildEvidenceLinks', () => {
    it('should return empty array when no findings', () => {
      const data = makeCleanAggregatedData();
      const links = service.buildEvidenceLinks(data);

      expect(links).toEqual([]);
    });

    it('should create evidence link for anomaly with source documentId', () => {
      const data = {
        documentAnalyses: [
          {
            documentId: 'doc-001',
            anomalies: [
              { id: 'anom-001', field: 'paymentAmount', type: 'unexpected_change', severity: 'high', description: 'Payment doubled' }
            ]
          }
        ],
        forensicReport: null,
        complianceReport: null
      };

      const links = service.buildEvidenceLinks(data);

      expect(links).toHaveLength(1);
      expect(links[0].findingId).toBe('anom-001');
      expect(links[0].findingType).toBe('anomaly');
      expect(links[0].sourceDocumentIds).toContain('doc-001');
      expect(links[0].severity).toBe('high');
      expect(links[0].evidenceDescription).toBeDefined();
      expect(links[0].evidenceDescription.length).toBeGreaterThan(0);
    });

    it('should create evidence link for discrepancy with both document IDs', () => {
      const data = {
        documentAnalyses: [],
        forensicReport: {
          discrepancies: [
            {
              id: 'disc-001',
              type: 'amount_mismatch',
              severity: 'high',
              description: 'Payment differs',
              documentA: { documentId: 'doc-001' },
              documentB: { documentId: 'doc-002' }
            }
          ],
          timeline: { violations: [] },
          paymentVerification: { unmatchedDocumentPayments: [], feeAnalysis: { irregularities: [] } }
        },
        complianceReport: null
      };

      const links = service.buildEvidenceLinks(data);

      expect(links).toHaveLength(1);
      expect(links[0].findingId).toBe('disc-001');
      expect(links[0].findingType).toBe('discrepancy');
      expect(links[0].sourceDocumentIds).toContain('doc-001');
      expect(links[0].sourceDocumentIds).toContain('doc-002');
      expect(links[0].severity).toBe('high');
    });

    it('should create evidence link for timeline violation', () => {
      const data = {
        documentAnalyses: [],
        forensicReport: {
          discrepancies: [],
          timeline: {
            violations: [
              {
                severity: 'critical',
                description: 'RESPA deadline exceeded',
                relatedDocuments: ['doc-001', 'doc-003'],
                regulation: 'RESPA Section 6'
              }
            ]
          },
          paymentVerification: { unmatchedDocumentPayments: [], feeAnalysis: { irregularities: [] } }
        },
        complianceReport: null
      };

      const links = service.buildEvidenceLinks(data);

      expect(links).toHaveLength(1);
      expect(links[0].findingType).toBe('timelineViolation');
      expect(links[0].sourceDocumentIds).toContain('doc-001');
      expect(links[0].sourceDocumentIds).toContain('doc-003');
      expect(links[0].severity).toBe('critical');
    });

    it('should create evidence link for payment issue', () => {
      const data = {
        documentAnalyses: [],
        forensicReport: {
          discrepancies: [],
          timeline: { violations: [] },
          paymentVerification: {
            unmatchedDocumentPayments: [
              { id: 'pm-1', documentId: 'doc-001', transactionId: 'txn-001' }
            ],
            feeAnalysis: { irregularities: [] }
          }
        },
        complianceReport: null
      };

      const links = service.buildEvidenceLinks(data);

      expect(links).toHaveLength(1);
      expect(links[0].findingType).toBe('paymentIssue');
      expect(links[0].severity).toBeDefined();
    });

    it('should create evidence link for federal violation with statute info', () => {
      const data = {
        documentAnalyses: [],
        forensicReport: null,
        complianceReport: {
          violations: [
            {
              id: 'viol-001',
              statuteId: 'respa',
              sectionId: 'respa_qwr_response',
              statuteName: 'Real Estate Settlement Procedures Act',
              citation: '12 USC 2605(e)',
              severity: 'critical',
              description: 'QWR failure',
              sourceDocumentIds: ['doc-001']
            }
          ],
          stateViolations: []
        }
      };

      const links = service.buildEvidenceLinks(data);

      expect(links).toHaveLength(1);
      expect(links[0].findingId).toBe('viol-001');
      expect(links[0].findingType).toBe('federalViolation');
      expect(links[0].severity).toBe('critical');
      expect(links[0].evidenceDescription).toContain('Federal');
    });

    it('should create evidence link for state violation with jurisdiction', () => {
      const data = {
        documentAnalyses: [],
        forensicReport: null,
        complianceReport: {
          violations: [],
          stateViolations: [
            {
              id: 'sviol-001',
              statuteId: 'ca_hbor',
              sectionId: 'ca_hbor_dual_tracking',
              statuteName: 'California Homeowner Bill of Rights',
              citation: 'Cal. Civ. Code §2924.18',
              severity: 'high',
              description: 'Dual tracking violation',
              jurisdiction: 'CA',
              sourceDocumentIds: ['doc-001', 'doc-003']
            }
          ]
        }
      };

      const links = service.buildEvidenceLinks(data);

      expect(links).toHaveLength(1);
      expect(links[0].findingId).toBe('sviol-001');
      expect(links[0].findingType).toBe('stateViolation');
      expect(links[0].sourceDocumentIds).toContain('doc-001');
      expect(links[0].sourceDocumentIds).toContain('doc-003');
      expect(links[0].severity).toBe('high');
      expect(links[0].evidenceDescription).toContain('State');
    });

    it('should create evidence links for all finding types in degraded case', () => {
      const data = makeDegradedAggregatedData();
      const links = service.buildEvidenceLinks(data);

      // Should have links for: 5 anomalies + 3 discrepancies + 1 timeline + 3 payment issues + 2 federal + 1 state = 15
      const types = links.map(l => l.findingType);
      expect(types).toContain('anomaly');
      expect(types).toContain('discrepancy');
      expect(types).toContain('timelineViolation');
      expect(types).toContain('paymentIssue');
      expect(types).toContain('federalViolation');
      expect(types).toContain('stateViolation');

      // Each link should have required fields
      for (const link of links) {
        expect(link.findingId).toBeDefined();
        expect(link.findingType).toBeDefined();
        expect(link.sourceDocumentIds).toBeDefined();
        expect(Array.isArray(link.sourceDocumentIds)).toBe(true);
        expect(link.evidenceDescription).toBeDefined();
        expect(link.severity).toBeDefined();
      }
    });

    it('should handle null forensic and compliance reports', () => {
      const data = {
        documentAnalyses: [
          {
            documentId: 'doc-001',
            anomalies: [
              { id: 'anom-001', severity: 'low', description: 'Minor issue' }
            ]
          }
        ],
        forensicReport: null,
        complianceReport: null
      };

      const links = service.buildEvidenceLinks(data);

      expect(links).toHaveLength(1);
      expect(links[0].findingType).toBe('anomaly');
    });
  });

  // =========================================================================
  // Classification confidence impact (Phase 20-05)
  // =========================================================================

  describe('Classification confidence impact', () => {
    it('high classification confidence (0.9) should not reduce documentAnalysis score', () => {
      const data = makeMixedAggregatedData();
      const withoutConf = service.calculateConfidence(data);
      const withConf = service.calculateConfidence(data, { classificationConfidence: 0.9 });

      expect(withConf.breakdown.documentAnalysis).toBe(withoutConf.breakdown.documentAnalysis);
      expect(withConf.classificationImpact.factor).toBe(1.0);
    });

    it('medium classification confidence (0.55) should reduce documentAnalysis score by 15%', () => {
      const data = makeMixedAggregatedData();
      const withoutConf = service.calculateConfidence(data);
      const withConf = service.calculateConfidence(data, { classificationConfidence: 0.55 });

      const expectedDocScore = Math.round(withoutConf.breakdown.documentAnalysis * 0.85 * 100) / 100;
      expect(withConf.breakdown.documentAnalysis).toBe(expectedDocScore);
      expect(withConf.classificationImpact.factor).toBe(0.85);
    });

    it('low classification confidence (0.3) should reduce documentAnalysis score by 35%', () => {
      const data = makeMixedAggregatedData();
      const withoutConf = service.calculateConfidence(data);
      const withConf = service.calculateConfidence(data, { classificationConfidence: 0.3 });

      const expectedDocScore = Math.round(withoutConf.breakdown.documentAnalysis * 0.65 * 100) / 100;
      expect(withConf.breakdown.documentAnalysis).toBe(expectedDocScore);
      expect(withConf.classificationImpact.factor).toBe(0.65);
    });

    it('no classification confidence should default to factor 1.0 (backward compatible)', () => {
      const data = makeMixedAggregatedData();
      const result = service.calculateConfidence(data);

      // No classificationImpact field when not provided
      expect(result.classificationImpact).toBeUndefined();

      // Score should match a high-confidence call
      const withHighConf = service.calculateConfidence(data, { classificationConfidence: 0.9 });
      expect(result.overall).toBe(withHighConf.overall);
    });

    it('classificationImpact field should be present in scoring response when confidence provided', () => {
      const data = makeCleanAggregatedData();
      const result = service.calculateConfidence(data, { classificationConfidence: 0.45 });

      expect(result.classificationImpact).toBeDefined();
      expect(result.classificationImpact.confidenceUsed).toBe(0.45);
      expect(result.classificationImpact.factor).toBe(0.85);
      expect(result.classificationImpact.layerAffected).toBe('documentAnalysis');
    });

    it('low classification confidence should reduce overall score', () => {
      const data = makeMixedAggregatedData();
      const highConf = service.calculateConfidence(data, { classificationConfidence: 0.9 });
      const lowConf = service.calculateConfidence(data, { classificationConfidence: 0.2 });

      expect(lowConf.overall).toBeLessThan(highConf.overall);
    });

    it('classification confidence should not affect forensic or compliance scores', () => {
      const data = makeDegradedAggregatedData();
      const withoutConf = service.calculateConfidence(data);
      const withConf = service.calculateConfidence(data, { classificationConfidence: 0.3 });

      expect(withConf.breakdown.forensicAnalysis).toBe(withoutConf.breakdown.forensicAnalysis);
      expect(withConf.breakdown.complianceAnalysis).toBe(withoutConf.breakdown.complianceAnalysis);
    });

    it('boundary: confidence exactly 0.7 should use factor 1.0', () => {
      const data = makeCleanAggregatedData();
      const result = service.calculateConfidence(data, { classificationConfidence: 0.7 });
      expect(result.classificationImpact.factor).toBe(1.0);
    });

    it('boundary: confidence exactly 0.4 should use factor 0.85', () => {
      const data = makeCleanAggregatedData();
      const result = service.calculateConfidence(data, { classificationConfidence: 0.4 });
      expect(result.classificationImpact.factor).toBe(0.85);
    });
  });

  // =========================================================================
  // Penalty calibration tests (Phase 20-04)
  // =========================================================================

  describe('Penalty calibration', () => {
    it('1 critical anomaly drops document analysis score ~30 points from component baseline', () => {
      const docs = [
        {
          completenessScore: 95,
          anomalies: [{ severity: 'critical' }]
        }
      ];
      const score = service.documentAnalysisScore(docs);
      // Anomaly component: 100 - 30 = 70. Layer: 0.4*95 + 0.6*70 = 38+42 = 80
      // Baseline (no anomalies): 0.4*95 + 0.6*100 = 38+60 = 98
      // Drop ≈ 18 on layer, 30 on anomaly component
      const baselineDocs = [{ completenessScore: 95, anomalies: [] }];
      const baselineScore = service.documentAnalysisScore(baselineDocs);
      const drop = baselineScore - score;
      expect(drop).toBeGreaterThanOrEqual(15);
      expect(drop).toBeLessThanOrEqual(25);
    });

    it('3 medium anomalies total penalty is close to 1 critical anomaly', () => {
      const criticalDocs = [
        {
          completenessScore: 95,
          anomalies: [{ severity: 'critical' }]
        }
      ];
      const mediumDocs = [
        {
          completenessScore: 95,
          anomalies: [
            { severity: 'medium' },
            { severity: 'medium' },
            { severity: 'medium' }
          ]
        }
      ];
      const criticalScore = service.documentAnalysisScore(criticalDocs);
      const mediumScore = service.documentAnalysisScore(mediumDocs);
      // 3 medium (3*12=36) should be in same ballpark as 1 critical (30)
      // The scores should be within 20% of each other in terms of drop
      const baselineDocs = [{ completenessScore: 95, anomalies: [] }];
      const baseline = service.documentAnalysisScore(baselineDocs);
      const criticalDrop = baseline - criticalScore;
      const mediumDrop = baseline - mediumScore;
      // 3 medium drop should be >= critical drop (slightly more penalty)
      expect(mediumDrop).toBeGreaterThanOrEqual(criticalDrop * 0.8);
      expect(mediumDrop).toBeLessThanOrEqual(criticalDrop * 1.5);
    });

    it('clean document with no findings scores 95-100', () => {
      const data = makeCleanAggregatedData();
      const result = service.calculateConfidence(data);
      expect(result.overall).toBeGreaterThanOrEqual(95);
      expect(result.overall).toBeLessThanOrEqual(100);
    });

    it('floor drag activates at 35 (not 45)', () => {
      // Create a forensic report where discrepancy component bottoms out at 0
      // but other components are at 100
      const forensicReport = {
        discrepancies: [
          { id: 'disc-001', severity: 'critical' },
          { id: 'disc-002', severity: 'critical' },
          { id: 'disc-003', severity: 'critical' },
          { id: 'disc-004', severity: 'critical' }
        ],
        timeline: { violations: [] },
        paymentVerification: {
          verified: true,
          unmatchedDocumentPayments: [],
          feeAnalysis: { irregularities: [] }
        }
      };
      const score = service.forensicAnalysisScore(forensicReport);
      // 4 critical discrepancies = 120pts penalty, component = 0
      // Floor drag should cap at 35
      expect(score).toBeLessThanOrEqual(35);
    });
  });
});
