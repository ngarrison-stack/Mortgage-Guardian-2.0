/**
 * Forensic Analysis Orchestrator Service
 *
 * Coordinates the full cross-document forensic analysis flow:
 *   Step 1: AGGREGATE — collect and normalize case documents
 *   Step 2: COMPARE PAIRS — run forensic comparison on each document pair
 *   Step 3: PLAID CROSS-REFERENCE — optionally verify payments against bank data
 *   Step 4: CONSOLIDATE — merge findings into a unified forensic report
 *
 * Design principles:
 *   - Graceful degradation: individual step/pair failures never crash the whole analysis
 *   - Best-effort persistence: log warnings on Supabase write failures, continue in-memory
 *   - Schema validation as warnings, not rejections
 *   - Singleton export pattern
 */

const { createLogger } = require('../utils/logger');
const crossDocumentAggregationService = require('./crossDocumentAggregationService');
const crossDocumentComparisonService = require('./crossDocumentComparisonService');
const plaidCrossReferenceService = require('./plaidCrossReferenceService');
const plaidService = require('./plaidService');
const { validateCrossDocumentAnalysis } = require('../schemas/crossDocumentAnalysisSchema');

const logger = createLogger('forensic-analysis');

// ---------------------------------------------------------------------------
// Recommendation mappings
// ---------------------------------------------------------------------------

const RECOMMENDATION_MAP = {
  amount_mismatch: 'Request detailed payment application history from servicer',
  date_inconsistency: 'Request complete servicing timeline with supporting documentation',
  term_contradiction: 'Compare original loan documents against current servicing terms',
  calculation_error: "Request servicer's calculation methodology and verify independently",
  fee_irregularity: 'Request itemized fee breakdown and supporting documentation per RESPA Section 6',
  timeline_violation: 'Document timeline with certified mail receipts for regulatory complaint',
  missing_correspondence: 'Request complete correspondence log per CFPB Regulation X',
  party_mismatch: 'Verify chain of title and servicing transfer documentation'
};

const PLAID_UNMATCHED_RECOMMENDATION =
  'Request payment posting details for dates where payments were sent but not credited';

// ---------------------------------------------------------------------------
// ForensicAnalysisService
// ---------------------------------------------------------------------------

class ForensicAnalysisService {

  /**
   * Run the full forensic analysis for a case.
   *
   * @param {string} caseId - Case identifier (required)
   * @param {string} userId - User identifier (required)
   * @param {Object} [options={}] - Analysis options
   * @param {string} [options.plaidAccessToken] - Plaid access token (enables Step 3)
   * @param {{ start: string, end: string }} [options.transactionDateRange] - Date range for Plaid
   * @param {number} [options.dateTolerance] - Days tolerance for Plaid matching
   * @param {number} [options.amountTolerance] - Dollar tolerance for Plaid matching
   * @returns {Promise<Object>} Forensic analysis report
   */
  async analyzeCaseForensics(caseId, userId, options = {}) {
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

    // -----------------------------------------------------------------------
    // Step 1: AGGREGATE
    // -----------------------------------------------------------------------
    let aggregation;
    const aggStart = Date.now();

    try {
      aggregation = await crossDocumentAggregationService.aggregateForCase(caseId, userId);
      stepMeta.aggregation = {
        status: 'completed',
        duration: Date.now() - aggStart,
        documentsFound: aggregation.totalDocuments,
        pairsGenerated: aggregation.comparisonPairs.length
      };
    } catch (err) {
      stepMeta.aggregation = { status: 'failed', duration: Date.now() - aggStart };
      logger.error('Aggregation step failed', { caseId, error: err.message });
      return {
        error: true,
        errorMessage: err.message,
        _metadata: {
          duration: Date.now() - overallStart,
          steps: stepMeta,
          warnings
        }
      };
    }

    // Check minimum analyzed documents
    if (aggregation.analyzedDocuments < 2) {
      warnings.push('Insufficient analyzed documents for cross-document comparison');
      stepMeta.aggregation.status = 'warning';

      return {
        caseId,
        analyzedAt: new Date().toISOString(),
        documentsAnalyzed: aggregation.analyzedDocuments,
        comparisonPairsEvaluated: 0,
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
        _metadata: {
          duration: Date.now() - overallStart,
          steps: stepMeta,
          warnings
        }
      };
    }

    // -----------------------------------------------------------------------
    // Step 2: COMPARE PAIRS
    // -----------------------------------------------------------------------
    const cmpStart = Date.now();
    const allDiscrepancies = [];
    const allTimelineEvents = [];
    const allTimelineViolations = [];
    let pairsCompared = 0;
    let pairsFailed = 0;

    for (const pair of aggregation.comparisonPairs) {
      // Find document data for each side
      const docA = aggregation.documents.find(d => d.documentId === pair.docA.documentId);
      const docB = aggregation.documents.find(d => d.documentId === pair.docB.documentId);

      try {
        const result = await crossDocumentComparisonService.compareDocumentPair(docA, docB, {
          pairId: pair.pairId,
          comparisonFields: pair.comparisonFields,
          discrepancyTypes: pair.discrepancyTypes,
          forensicSignificance: pair.forensicSignificance
        });

        pairsCompared++;

        if (result.error) {
          pairsFailed++;
          warnings.push(`Comparison pair ${pair.pairId} returned error: ${result.errorMessage}`);
          continue;
        }

        // Collect results
        if (Array.isArray(result.discrepancies)) {
          allDiscrepancies.push(...result.discrepancies);
        }
        if (Array.isArray(result.timelineEvents)) {
          allTimelineEvents.push(...result.timelineEvents);
        }
        if (Array.isArray(result.timelineViolations)) {
          allTimelineViolations.push(...result.timelineViolations);
        }
      } catch (err) {
        pairsCompared++;
        pairsFailed++;
        warnings.push(`Comparison pair ${pair.pairId} threw: ${err.message}`);
        logger.warn('Comparison pair failed', { pairId: pair.pairId, error: err.message });
      }
    }

    // Deduplicate discrepancies: same field + same documents → keep higher severity
    const deduped = this._deduplicateDiscrepancies(allDiscrepancies);

    // Assign sequential IDs
    deduped.forEach((disc, i) => {
      disc.id = `disc-${String(i + 1).padStart(3, '0')}`;
    });

    stepMeta.comparison = {
      status: pairsFailed === pairsCompared && pairsCompared > 0 ? 'failed' : 'completed',
      duration: Date.now() - cmpStart,
      pairsCompared,
      pairsFailed
    };

    // -----------------------------------------------------------------------
    // Step 3: PLAID CROSS-REFERENCE (optional)
    // -----------------------------------------------------------------------
    let paymentVerification = null;
    const plaidStart = Date.now();

    if (options.plaidAccessToken) {
      try {
        // Determine date range
        const dateRange = options.transactionDateRange || this._defaultDateRange();

        // Fetch transactions from Plaid
        const txnResult = await plaidService.getTransactions({
          accessToken: options.plaidAccessToken,
          startDate: dateRange.start,
          endDate: dateRange.end
        });

        // Extract payments from analysis reports
        const analysisReports = aggregation.documents.filter(d => d.analysisReport);
        const documentPayments = plaidCrossReferenceService.extractPaymentsFromAnalysis(analysisReports);

        // Cross-reference
        const crossRefOptions = {};
        if (options.dateTolerance != null) crossRefOptions.dateTolerance = options.dateTolerance;
        if (options.amountTolerance != null) crossRefOptions.amountTolerance = options.amountTolerance;

        const crossRefResult = plaidCrossReferenceService.crossReferencePayments(
          documentPayments,
          txnResult.transactions,
          crossRefOptions
        );

        paymentVerification = {
          verified: crossRefResult.summary.paymentVerified,
          transactionsAnalyzed: txnResult.transactions.length,
          dateRange,
          matchedPayments: crossRefResult.matchedPayments,
          unmatchedDocumentPayments: crossRefResult.unmatchedDocumentPayments,
          unmatchedTransactions: crossRefResult.unmatchedTransactions,
          escrowAnalysis: crossRefResult.escrowAnalysis,
          feeAnalysis: crossRefResult.feeAnalysis
        };

        stepMeta.plaidCrossReference = {
          status: 'completed',
          duration: Date.now() - plaidStart
        };
      } catch (err) {
        paymentVerification = null;
        warnings.push(`Plaid cross-reference failed: ${err.message}`);
        logger.warn('Plaid cross-reference step failed', { error: err.message });
        stepMeta.plaidCrossReference = {
          status: 'failed',
          duration: Date.now() - plaidStart,
          reason: err.message
        };
      }
    } else {
      stepMeta.plaidCrossReference = {
        status: 'skipped',
        duration: 0,
        reason: 'No plaidAccessToken provided'
      };
    }

    // -----------------------------------------------------------------------
    // Step 4: CONSOLIDATE
    // -----------------------------------------------------------------------
    const consStart = Date.now();

    // Merge timeline events sorted by date
    const sortedEvents = [...allTimelineEvents].sort((a, b) =>
      (a.date || '').localeCompare(b.date || '')
    );

    // Deduplicate timeline violations
    const dedupedViolations = this._deduplicateViolations(allTimelineViolations);

    // Calculate summary
    const summary = this._buildSummary(deduped, paymentVerification);

    stepMeta.consolidation = {
      status: 'completed',
      duration: Date.now() - consStart
    };

    // Build report
    const report = {
      caseId,
      analyzedAt: new Date().toISOString(),
      documentsAnalyzed: aggregation.analyzedDocuments,
      comparisonPairsEvaluated: pairsCompared,
      discrepancies: deduped,
      timeline: {
        events: sortedEvents,
        violations: dedupedViolations
      },
      paymentVerification,
      summary
    };

    // Schema validation (warnings only)
    const { error: validationError } = validateCrossDocumentAnalysis(report);
    if (validationError) {
      warnings.push(`Schema validation warnings: ${validationError.message}`);
      logger.warn('Report schema validation produced warnings', {
        details: validationError.details.map(d => d.message)
      });
    }

    // Attach metadata
    report._metadata = {
      duration: Date.now() - overallStart,
      steps: stepMeta,
      warnings
    };

    // Best-effort persistence
    await this._persistReport(caseId, userId, report);

    return report;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /**
   * Deduplicate discrepancies by field + documents, keeping higher severity.
   * @param {Array} discrepancies
   * @returns {Array} Deduplicated discrepancies
   * @private
   */
  _deduplicateDiscrepancies(discrepancies) {
    const severityRank = { critical: 4, high: 3, medium: 2, low: 1, info: 0 };
    const map = new Map();

    for (const disc of discrepancies) {
      const fieldA = disc.documentA?.field || 'unknown';
      const fieldB = disc.documentB?.field || 'unknown';
      const key = `${fieldA}|${fieldB}|${disc.type || ''}`;

      const existing = map.get(key);
      if (!existing || (severityRank[disc.severity] || 0) > (severityRank[existing.severity] || 0)) {
        map.set(key, disc);
      }
    }

    return Array.from(map.values());
  }

  /**
   * Deduplicate timeline violations by description.
   * @param {Array} violations
   * @returns {Array}
   * @private
   */
  _deduplicateViolations(violations) {
    const seen = new Set();
    return violations.filter(v => {
      const key = v.description || '';
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  /**
   * Build the summary section of the report.
   * @param {Array} discrepancies
   * @param {Object|null} paymentVerification
   * @returns {Object} Summary
   * @private
   */
  _buildSummary(discrepancies, paymentVerification) {
    const totalDiscrepancies = discrepancies.length;
    const criticalFindings = discrepancies.filter(d => d.severity === 'critical').length;
    const highFindings = discrepancies.filter(d => d.severity === 'high').length;
    const mediumFindings = discrepancies.filter(d => d.severity === 'medium').length;

    // Risk level
    let riskLevel = 'low';
    if (criticalFindings > 0) riskLevel = 'critical';
    else if (highFindings > 0) riskLevel = 'high';
    else if (mediumFindings > 0) riskLevel = 'medium';

    // Key findings — critical first, then high, top 10
    const sorted = [...discrepancies].sort((a, b) => {
      const rank = { critical: 4, high: 3, medium: 2, low: 1, info: 0 };
      return (rank[b.severity] || 0) - (rank[a.severity] || 0);
    });
    const keyFindings = sorted.slice(0, 10).map(d => d.description);

    // Add Plaid findings if applicable
    if (paymentVerification) {
      if (paymentVerification.unmatchedDocumentPayments && paymentVerification.unmatchedDocumentPayments.length > 0) {
        keyFindings.push(
          `${paymentVerification.unmatchedDocumentPayments.length} document payment(s) not found in bank records`
        );
      }
      if (paymentVerification.feeAnalysis && paymentVerification.feeAnalysis.irregularities && paymentVerification.feeAnalysis.irregularities.length > 0) {
        keyFindings.push(
          `${paymentVerification.feeAnalysis.irregularities.length} fee irregularity(ies) detected via Plaid verification`
        );
      }
    }

    // Recommendations — deduplicate
    const recommendations = this._generateRecommendations(discrepancies, paymentVerification);

    return {
      totalDiscrepancies,
      criticalFindings,
      highFindings,
      riskLevel,
      keyFindings,
      recommendations
    };
  }

  /**
   * Generate recommendations based on discrepancy types and Plaid results.
   * @param {Array} discrepancies
   * @param {Object|null} paymentVerification
   * @returns {Array<string>}
   * @private
   */
  _generateRecommendations(discrepancies, paymentVerification) {
    const recSet = new Set();

    for (const disc of discrepancies) {
      const rec = RECOMMENDATION_MAP[disc.type];
      if (rec) recSet.add(rec);
    }

    // Plaid-specific recommendation
    if (paymentVerification &&
        paymentVerification.unmatchedDocumentPayments &&
        paymentVerification.unmatchedDocumentPayments.length > 0) {
      recSet.add(PLAID_UNMATCHED_RECOMMENDATION);
    }

    return Array.from(recSet);
  }

  /**
   * Default date range: 12 months back from today.
   * @returns {{ start: string, end: string }}
   * @private
   */
  _defaultDateRange() {
    const end = new Date();
    const start = new Date();
    start.setFullYear(start.getFullYear() - 1);

    return {
      start: start.toISOString().slice(0, 10),
      end: end.toISOString().slice(0, 10)
    };
  }

  /**
   * Best-effort persistence to Supabase. Logs warning on failure, never throws.
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
        updates: { forensic_analysis: report }
      });
      logger.info('Forensic analysis persisted', { caseId });
    } catch (err) {
      logger.warn('Failed to persist forensic analysis (best-effort)', {
        caseId,
        error: err.message
      });
    }
  }
}

module.exports = new ForensicAnalysisService();
