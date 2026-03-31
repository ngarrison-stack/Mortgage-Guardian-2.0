/**
 * Consolidated Report Orchestrator Service
 *
 * Coordinates the full consolidated report generation flow:
 *   Step 1: GATHER — collect and normalize all case findings
 *   Step 2: SCORE — calculate confidence scores and determine risk level
 *   Step 3: LINK — build evidence links connecting findings to source documents
 *   Step 4: GENERATE RECOMMENDATIONS — build prioritized recommendations from findings
 *   Step 5: DISPUTE LETTER (optional) — generate RESPA-compliant dispute letter
 *   Step 6: ASSEMBLE — build final report matching consolidatedReportSchema
 *   Step 7: VALIDATE — run schema validation, attach warnings
 *   Step 8: PERSIST — best-effort save to Supabase consolidated_reports table
 *
 * Design principles:
 *   - Graceful degradation: individual step failures never crash the whole generation
 *   - Best-effort persistence: log warnings on Supabase write failures, continue in-memory
 *   - Schema validation as warnings, not rejections
 *   - Singleton export pattern
 */

const { randomUUID } = require('crypto');
const { createLogger } = require('../utils/logger');
const reportAggregationService = require('./reportAggregationService');
const confidenceScoringService = require('./confidenceScoringService');
const disputeLetterService = require('./disputeLetterService');
const { validateConsolidatedReport } = require('../schemas/consolidatedReportSchema');
const { RECOMMENDATION_PRIORITY } = require('../config/consolidatedReportConfig');

const logger = createLogger('consolidated-report');

// Severity ordering for sorting recommendations
const SEVERITY_RANK = { critical: 4, high: 3, medium: 2, low: 1, info: 0 };

// ---------------------------------------------------------------------------
// Recommendation category mappings — maps finding types to action categories
// ---------------------------------------------------------------------------

const FINDING_RECOMMENDATION_MAP = {
  amount_mismatch: {
    category: 'payment_verification',
    action: 'Request detailed payment application history from servicer'
  },
  date_inconsistency: {
    category: 'documentation',
    action: 'Request complete servicing timeline with supporting documentation'
  },
  term_contradiction: {
    category: 'loan_terms',
    action: 'Compare original loan documents against current servicing terms'
  },
  calculation_error: {
    category: 'calculation_review',
    action: "Request servicer's calculation methodology and verify independently"
  },
  fee_irregularity: {
    category: 'fee_review',
    action: 'Request itemized fee breakdown and supporting documentation per RESPA Section 6'
  },
  timeline_violation: {
    category: 'timeline',
    action: 'Document timeline with certified mail receipts for regulatory complaint'
  },
  missing_correspondence: {
    category: 'correspondence',
    action: 'Request complete correspondence log per CFPB Regulation X'
  },
  party_mismatch: {
    category: 'title_review',
    action: 'Verify chain of title and servicing transfer documentation'
  }
};

// Default recommendation for compliance violations without a specific mapping
const DEFAULT_VIOLATION_RECOMMENDATION = {
  category: 'compliance',
  action: 'Consult with legal counsel regarding identified regulatory violation'
};

// ---------------------------------------------------------------------------
// ConsolidatedReportService
// ---------------------------------------------------------------------------

class ConsolidatedReportService {

  /**
   * Generate a consolidated audit report for a case.
   *
   * @param {string} caseId - Case identifier (required)
   * @param {string} userId - User identifier (required)
   * @param {Object} [options={}] - Generation options
   * @param {boolean} [options.generateLetter=false] - Generate RESPA dispute letter
   * @param {string} [options.letterType='qualified_written_request'] - Letter type
   * @param {boolean} [options.skipPersistence=false] - Skip Supabase persistence
   * @returns {Promise<Object>} Consolidated report or error object
   */
  async generateReport(caseId, userId, options = {}) {
    const overallStart = Date.now();
    const warnings = [];
    const stepMeta = {};

    // --- Input validation ---
    if (!caseId) {
      return { error: true, errorMessage: 'Missing required parameter: caseId' };
    }
    if (!userId) {
      return { error: true, errorMessage: 'Missing required parameter: userId' };
    }

    const reportId = randomUUID();

    // -----------------------------------------------------------------------
    // Step 1: GATHER
    // -----------------------------------------------------------------------
    let aggregatedData;
    const gatherStart = Date.now();

    try {
      aggregatedData = await reportAggregationService.gatherCaseFindings(caseId, userId);

      if (aggregatedData.error) {
        stepMeta.gather = { status: 'failed', duration: Date.now() - gatherStart };
        logger.error('Gather step returned error', { caseId, error: aggregatedData.errorMessage });
        return {
          error: true,
          errorMessage: aggregatedData.errorMessage,
          _metadata: {
            duration: Date.now() - overallStart,
            steps: stepMeta,
            warnings
          }
        };
      }

      // Collect any partial-data warnings from aggregation
      if (Array.isArray(aggregatedData.errors) && aggregatedData.errors.length > 0) {
        for (const e of aggregatedData.errors) {
          warnings.push(e);
        }
      }

      stepMeta.gather = {
        status: 'completed',
        duration: Date.now() - gatherStart,
        documentCount: aggregatedData.documentAnalyses ? aggregatedData.documentAnalyses.length : 0,
        hasForensic: !!aggregatedData.forensicReport,
        hasCompliance: !!aggregatedData.complianceReport
      };
    } catch (err) {
      stepMeta.gather = { status: 'failed', duration: Date.now() - gatherStart };
      logger.error('Gather step failed', { caseId, error: err.message });
      return {
        error: true,
        errorMessage: `Failed to gather case findings: ${err.message}`,
        _metadata: {
          duration: Date.now() - overallStart,
          steps: stepMeta,
          warnings
        }
      };
    }

    // -----------------------------------------------------------------------
    // Step 2: SCORE
    // -----------------------------------------------------------------------
    let confidenceScore = { overall: 100, breakdown: { documentAnalysis: null, forensicAnalysis: null, complianceAnalysis: null } };
    let overallRiskLevel = 'clean';
    const scoreStart = Date.now();

    try {
      // Pass classification confidence from pipeline results into scoring.
      // aggregatedData.classificationConfidence is set by the aggregation service
      // when document classification results are available.
      const scoringOptions = {};
      if (aggregatedData.classificationConfidence !== undefined) {
        scoringOptions.classificationConfidence = aggregatedData.classificationConfidence;
      }
      confidenceScore = confidenceScoringService.calculateConfidence(aggregatedData, scoringOptions);
      overallRiskLevel = confidenceScoringService.determineRiskLevel(confidenceScore.overall);

      stepMeta.score = {
        status: 'completed',
        duration: Date.now() - scoreStart,
        overallScore: confidenceScore.overall,
        riskLevel: overallRiskLevel
      };
    } catch (err) {
      warnings.push(`Confidence scoring failed: ${err.message}`);
      logger.warn('Scoring step failed, using defaults', { caseId, error: err.message });
      stepMeta.score = {
        status: 'failed',
        duration: Date.now() - scoreStart,
        error: err.message
      };
    }

    // -----------------------------------------------------------------------
    // Step 3: LINK
    // -----------------------------------------------------------------------
    let evidenceLinks = [];
    const linkStart = Date.now();

    try {
      evidenceLinks = confidenceScoringService.buildEvidenceLinks(aggregatedData);

      stepMeta.link = {
        status: 'completed',
        duration: Date.now() - linkStart,
        linksGenerated: evidenceLinks.length
      };
    } catch (err) {
      warnings.push(`Evidence linking failed: ${err.message}`);
      logger.warn('Link step failed', { caseId, error: err.message });
      stepMeta.link = {
        status: 'failed',
        duration: Date.now() - linkStart,
        error: err.message
      };
    }

    // -----------------------------------------------------------------------
    // Step 4: GENERATE RECOMMENDATIONS
    // -----------------------------------------------------------------------
    let recommendations = [];
    const recStart = Date.now();

    try {
      recommendations = this._generateRecommendations(aggregatedData);

      stepMeta.recommendations = {
        status: 'completed',
        duration: Date.now() - recStart,
        recommendationCount: recommendations.length
      };
    } catch (err) {
      warnings.push(`Recommendation generation failed: ${err.message}`);
      logger.warn('Recommendation step failed', { caseId, error: err.message });
      stepMeta.recommendations = {
        status: 'failed',
        duration: Date.now() - recStart,
        error: err.message
      };
    }

    // -----------------------------------------------------------------------
    // Step 5: DISPUTE LETTER (optional)
    // -----------------------------------------------------------------------
    let disputeLetter = null;
    let disputeLetterAvailable = false;

    if (options.generateLetter) {
      const letterStart = Date.now();
      const letterType = options.letterType || 'qualified_written_request';

      try {
        // Build a partial report object for the letter service
        const partialReport = {
          caseSummary: aggregatedData.caseInfo ? {
            borrowerName: aggregatedData.caseInfo.borrowerName,
            propertyAddress: aggregatedData.caseInfo.propertyAddress,
            loanNumber: aggregatedData.caseInfo.loanNumber,
            servicerName: aggregatedData.caseInfo.servicerName
          } : {},
          documentAnalyses: aggregatedData.documentAnalyses || [],
          forensicReport: aggregatedData.forensicReport,
          complianceReport: aggregatedData.complianceReport
        };

        const letterResult = await disputeLetterService.generateDisputeLetter(letterType, partialReport);

        if (letterResult.error) {
          warnings.push(`Dispute letter generation returned error: ${letterResult.errorMessage}`);
          stepMeta.disputeLetter = {
            status: 'failed',
            duration: Date.now() - letterStart,
            error: letterResult.errorMessage
          };
        } else {
          disputeLetter = letterResult;
          disputeLetterAvailable = true;
          stepMeta.disputeLetter = {
            status: 'completed',
            duration: Date.now() - letterStart,
            letterType
          };
        }
      } catch (err) {
        warnings.push(`Dispute letter generation failed: ${err.message}`);
        logger.warn('Dispute letter step failed', { caseId, error: err.message });
        stepMeta.disputeLetter = {
          status: 'failed',
          duration: Date.now() - letterStart,
          error: err.message
        };
      }
    } else {
      stepMeta.disputeLetter = {
        status: 'skipped',
        duration: 0,
        reason: 'generateLetter option not set'
      };
    }

    // -----------------------------------------------------------------------
    // Step 6: ASSEMBLE
    // -----------------------------------------------------------------------
    const assembleStart = Date.now();

    const caseInfo = aggregatedData.caseInfo || {};
    const findingSummary = reportAggregationService.extractFindingSummary(
      aggregatedData.documentAnalyses || [],
      aggregatedData.forensicReport,
      aggregatedData.complianceReport
    );

    // Build forensicFindings section
    const forensicReport = aggregatedData.forensicReport;
    const forensicFindings = {
      discrepancies: this._normalizeForensicDiscrepancies(forensicReport),
      timelineViolations: this._normalizeTimelineViolations(forensicReport),
      paymentVerification: this._normalizePaymentVerification(forensicReport)
    };

    // Build complianceFindings section
    const complianceReport = aggregatedData.complianceReport;
    const complianceFindings = {
      federalViolations: complianceReport && Array.isArray(complianceReport.violations)
        ? complianceReport.violations : [],
      stateViolations: complianceReport && Array.isArray(complianceReport.stateViolations)
        ? complianceReport.stateViolations : [],
      jurisdiction: complianceReport && complianceReport.jurisdiction
        ? complianceReport.jurisdiction : null
    };

    const report = {
      reportId,
      caseId,
      userId,
      generatedAt: new Date().toISOString(),
      reportVersion: '1.0',
      caseSummary: {
        borrowerName: caseInfo.borrowerName || 'Unknown',
        propertyAddress: caseInfo.propertyAddress || 'Unknown',
        loanNumber: caseInfo.loanNumber || 'Unknown',
        servicerName: caseInfo.servicerName || 'Unknown',
        documentCount: caseInfo.documentCount || 0,
        caseCreatedAt: caseInfo.createdAt || new Date().toISOString()
      },
      overallRiskLevel,
      confidenceScore,
      findingSummary,
      documentAnalysis: (aggregatedData.documentAnalyses || []).map(da => ({
        documentId: da.documentId,
        documentName: da.documentName,
        type: da.type,
        subtype: da.subtype,
        completenessScore: da.completenessScore,
        anomalyCount: da.anomalyCount,
        anomalies: da.anomalies || [],
        keyFindings: da.keyFindings || []
      })),
      forensicFindings,
      complianceFindings,
      evidenceLinks,
      recommendations,
      disputeLetterAvailable,
      disputeLetter
    };

    stepMeta.assemble = {
      status: 'completed',
      duration: Date.now() - assembleStart
    };

    // -----------------------------------------------------------------------
    // Step 7: VALIDATE
    // -----------------------------------------------------------------------
    const validateStart = Date.now();

    const validation = validateConsolidatedReport(report);
    if (!validation.valid) {
      warnings.push(`Schema validation warnings: ${validation.errors.join('; ')}`);
      logger.warn('Report schema validation produced warnings', {
        errors: validation.errors
      });
    }

    stepMeta.validate = {
      status: validation.valid ? 'completed' : 'warning',
      duration: Date.now() - validateStart,
      valid: validation.valid,
      errorCount: validation.errors.length
    };

    // Attach metadata
    const stepsCompleted = Object.keys(stepMeta).filter(
      k => stepMeta[k].status === 'completed'
    );

    report._metadata = {
      generationDurationMs: Date.now() - overallStart,
      stepsCompleted,
      warnings
    };

    // -----------------------------------------------------------------------
    // Step 8: PERSIST (best-effort)
    // -----------------------------------------------------------------------
    if (!options.skipPersistence) {
      await this._persistReport(caseId, userId, report);
    } else {
      stepMeta.persist = { status: 'skipped', duration: 0, reason: 'skipPersistence option set' };
    }

    return report;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /**
   * Generate prioritized recommendations from all findings.
   *
   * @param {Object} aggregatedData - { documentAnalyses, forensicReport, complianceReport }
   * @returns {Array<{ priority, category, action, legalBasis, relatedFindingIds }>}
   * @private
   */
  _generateRecommendations(aggregatedData) {
    const { documentAnalyses = [], forensicReport = null, complianceReport = null } = aggregatedData;
    const recMap = new Map(); // key: action text → recommendation object

    // --- From document anomalies ---
    for (const doc of documentAnalyses) {
      const anomalies = doc.anomalies || [];
      for (const anomaly of anomalies) {
        const mapping = FINDING_RECOMMENDATION_MAP[anomaly.type];
        if (mapping) {
          this._addRecommendation(recMap, mapping, anomaly.severity, anomaly.id);
        }
      }
    }

    // --- From forensic discrepancies ---
    if (forensicReport) {
      const discrepancies = forensicReport.discrepancies || [];
      for (const disc of discrepancies) {
        const mapping = FINDING_RECOMMENDATION_MAP[disc.type];
        if (mapping) {
          this._addRecommendation(recMap, mapping, disc.severity, disc.id);
        }
      }

      // From timeline violations
      const timelineViolations = (forensicReport.timeline && forensicReport.timeline.violations) || [];
      for (const tv of timelineViolations) {
        const mapping = FINDING_RECOMMENDATION_MAP.timeline_violation;
        if (mapping) {
          this._addRecommendation(recMap, mapping, tv.severity, tv.id);
        }
      }
    }

    // --- From compliance violations ---
    if (complianceReport) {
      const federalViolations = complianceReport.violations || [];
      for (const v of federalViolations) {
        const mapping = DEFAULT_VIOLATION_RECOMMENDATION;
        const legalBasis = v.citation || v.legalBasis || null;
        this._addRecommendation(recMap, mapping, v.severity, v.id, legalBasis);
      }

      const stateViolations = complianceReport.stateViolations || [];
      for (const sv of stateViolations) {
        const mapping = DEFAULT_VIOLATION_RECOMMENDATION;
        const legalBasis = sv.citation || sv.legalBasis || null;
        this._addRecommendation(recMap, mapping, sv.severity, sv.id, legalBasis);
      }
    }

    // Convert map to array, sort by priority (lower number = higher priority)
    const recommendations = Array.from(recMap.values());
    recommendations.sort((a, b) => a.priority - b.priority);

    return recommendations;
  }

  /**
   * Add or merge a recommendation into the map.
   * Deduplicates by action text; upgrades priority if a higher-severity finding maps to the same action.
   *
   * @param {Map} recMap - Recommendation map
   * @param {{ category: string, action: string }} mapping - Recommendation mapping
   * @param {string} severity - Finding severity
   * @param {string} [findingId] - Finding identifier
   * @param {string} [legalBasis] - Legal citation (for compliance violations)
   * @private
   */
  _addRecommendation(recMap, mapping, severity, findingId, legalBasis) {
    const priority = RECOMMENDATION_PRIORITY[severity] || 5;
    const key = mapping.action;

    if (recMap.has(key)) {
      const existing = recMap.get(key);
      // Upgrade priority (lower number = higher)
      if (priority < existing.priority) {
        existing.priority = priority;
      }
      // Merge finding IDs
      if (findingId && !existing.relatedFindingIds.includes(findingId)) {
        existing.relatedFindingIds.push(findingId);
      }
      // Merge legal basis
      if (legalBasis && !existing.legalBasis) {
        existing.legalBasis = legalBasis;
      }
    } else {
      recMap.set(key, {
        priority,
        category: mapping.category,
        action: mapping.action,
        legalBasis: legalBasis || null,
        relatedFindingIds: findingId ? [findingId] : []
      });
    }
  }

  /**
   * Normalize forensic discrepancies into the consolidated report shape.
   *
   * @param {Object|null} forensicReport
   * @returns {Array}
   * @private
   */
  _normalizeForensicDiscrepancies(forensicReport) {
    if (!forensicReport || !Array.isArray(forensicReport.discrepancies)) return [];

    return forensicReport.discrepancies.map(disc => {
      const docIds = [];
      if (disc.documentA && disc.documentA.documentId) docIds.push(disc.documentA.documentId);
      if (disc.documentB && disc.documentB.documentId) docIds.push(disc.documentB.documentId);

      return {
        id: disc.id || 'unknown',
        type: disc.type || 'unknown',
        severity: disc.severity || 'medium',
        description: disc.description || '',
        documentIds: docIds.length > 0 ? docIds : ['unknown'],
        regulation: disc.regulation || undefined
      };
    });
  }

  /**
   * Normalize timeline violations from forensic report.
   *
   * @param {Object|null} forensicReport
   * @returns {Array}
   * @private
   */
  _normalizeTimelineViolations(forensicReport) {
    if (!forensicReport || !forensicReport.timeline || !Array.isArray(forensicReport.timeline.violations)) return [];

    return forensicReport.timeline.violations.map(tv => ({
      description: tv.description || '',
      severity: tv.severity || 'medium',
      relatedDocuments: tv.relatedDocuments || ['unknown'],
      regulation: tv.regulation || undefined
    }));
  }

  /**
   * Normalize payment verification from forensic report.
   *
   * @param {Object|null} forensicReport
   * @returns {Object|null}
   * @private
   */
  _normalizePaymentVerification(forensicReport) {
    if (!forensicReport || !forensicReport.paymentVerification) return null;

    const pv = forensicReport.paymentVerification;
    const unmatchedCount = Array.isArray(pv.unmatchedDocumentPayments)
      ? pv.unmatchedDocumentPayments.length : 0;
    const matchedCount = Array.isArray(pv.matchedPayments)
      ? pv.matchedPayments.length : 0;

    const findings = [];
    if (unmatchedCount > 0) {
      findings.push(`${unmatchedCount} document payment(s) not found in bank records`);
    }
    if (pv.feeAnalysis && Array.isArray(pv.feeAnalysis.irregularities) && pv.feeAnalysis.irregularities.length > 0) {
      findings.push(`${pv.feeAnalysis.irregularities.length} fee irregularity(ies) detected`);
    }

    return {
      verified: pv.verified || false,
      transactionsAnalyzed: pv.transactionsAnalyzed || 0,
      matchedCount,
      unmatchedCount,
      findings
    };
  }

  /**
   * Best-effort persistence to Supabase. Logs warning on failure, never throws.
   *
   * @param {string} caseId
   * @param {string} userId
   * @param {Object} report
   * @private
   */
  async _persistReport(caseId, userId, report) {
    try {
      const caseFileService = require('./caseFileService');
      await caseFileService.updateCase({
        caseId,
        userId,
        updates: { consolidated_report: report }
      });
      logger.info('Consolidated report persisted', { caseId, reportId: report.reportId });
    } catch (err) {
      logger.warn('Failed to persist consolidated report (best-effort)', {
        caseId,
        error: err.message
      });
    }
  }
}

module.exports = new ConsolidatedReportService();
