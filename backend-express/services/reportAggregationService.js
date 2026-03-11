/**
 * Report Data Aggregation Service
 *
 * Gathers findings from all upstream analysis services (individual document
 * analysis, cross-document forensic analysis, federal/state compliance
 * analysis) and normalizes them into the consolidated report structure
 * defined in consolidatedReportSchema.js.
 *
 * Design principles:
 *   - Graceful degradation: any upstream report can be null/partial; returns
 *     whatever data is available without throwing
 *   - Never throws: returns error objects on complete failures
 *   - Mock-friendly: external boundaries (caseFileService, Supabase) are
 *     accessed through service singletons
 *   - Singleton export pattern (consistent with forensicAnalysisService,
 *     complianceService)
 */

const { createLogger } = require('../utils/logger');
const logger = createLogger('report-aggregation');

class ReportAggregationService {

  /**
   * Gather all case findings from upstream analysis services.
   *
   * @param {string} caseId - Case identifier
   * @param {string} userId - User identifier
   * @returns {Promise<Object>} Aggregated findings or error object
   */
  async gatherCaseFindings(caseId, userId) {
    const errors = [];

    // --- Retrieve case data ---
    let caseData;
    try {
      const caseFileService = require('./caseFileService');
      caseData = await caseFileService.getCase({ caseId, userId });
    } catch (err) {
      logger.error('Failed to retrieve case data', { caseId, error: err.message });
      return { error: true, errorMessage: `Failed to retrieve case: ${err.message}` };
    }

    if (!caseData) {
      return { error: true, errorMessage: `Case not found: ${caseId}` };
    }

    // --- Build case info ---
    const caseInfo = {
      caseId: caseData.id,
      caseName: caseData.case_name,
      borrowerName: caseData.borrower_name,
      propertyAddress: caseData.property_address,
      loanNumber: caseData.loan_number,
      servicerName: caseData.servicer_name,
      status: caseData.status,
      createdAt: caseData.created_at,
      documentCount: Array.isArray(caseData.documents) ? caseData.documents.length : 0
    };

    // --- Normalize document analyses ---
    const documents = caseData.documents || [];
    const documentAnalyses = documents
      .filter(doc => doc.analysis_report)
      .map(doc => this.normalizeDocumentAnalysis(doc.analysis_report));

    // --- Retrieve forensic report ---
    let forensicReport = caseData.forensic_analysis || caseData.forensicAnalysis || null;

    if (!forensicReport) {
      errors.push('No forensic analysis available for this case');
    } else if (forensicReport._metadata && Array.isArray(forensicReport._metadata.warnings) &&
               forensicReport._metadata.warnings.length > 0) {
      errors.push('Forensic analysis has partial results (some comparisons failed)');
    }

    // --- Retrieve compliance report ---
    let complianceReport = caseData.compliance_report || caseData.complianceReport || null;

    if (!complianceReport) {
      errors.push('No compliance analysis available for this case');
    }

    logger.info('Case findings gathered', {
      caseId,
      documentCount: documentAnalyses.length,
      hasForensic: !!forensicReport,
      hasCompliance: !!complianceReport,
      errorCount: errors.length
    });

    return {
      caseInfo,
      documentAnalyses,
      forensicReport,
      complianceReport,
      errors
    };
  }

  /**
   * Normalize a single document analysis report into the consolidated
   * report shape (matching documentAnalysisItemSchema).
   *
   * @param {Object|null} analysisReport - Raw analysis report from pipeline
   * @returns {Object} Normalized document analysis
   */
  normalizeDocumentAnalysis(analysisReport) {
    if (!analysisReport) {
      return {
        documentId: 'unknown',
        documentName: 'unknown',
        type: 'unknown',
        subtype: 'unknown',
        completenessScore: 0,
        anomalyCount: 0,
        anomalies: [],
        keyFindings: []
      };
    }

    const docInfo = analysisReport.documentInfo || {};
    const completeness = analysisReport.completeness || {};
    const anomalies = Array.isArray(analysisReport.anomalies) ? analysisReport.anomalies : [];
    const summary = analysisReport.summary || {};

    return {
      documentId: docInfo.documentId || 'unknown',
      documentName: docInfo.fileName || 'unknown',
      type: docInfo.classificationType || 'unknown',
      subtype: docInfo.classificationSubtype || 'unknown',
      completenessScore: completeness.score || 0,
      anomalyCount: anomalies.length,
      anomalies: anomalies.map(a => ({
        id: a.id,
        field: a.field,
        type: a.type,
        severity: a.severity,
        description: a.description
      })),
      keyFindings: Array.isArray(summary.keyFindings) ? summary.keyFindings : []
    };
  }

  /**
   * Extract aggregate finding counts from all analysis sources.
   *
   * @param {Array} documentAnalyses - Normalized document analyses
   * @param {Object|null} forensicReport - Raw forensic report
   * @param {Object|null} complianceReport - Raw compliance report
   * @returns {Object} Finding summary matching findingSummarySchema
   */
  extractFindingSummary(documentAnalyses, forensicReport, complianceReport) {
    const bySeverity = { critical: 0, high: 0, medium: 0, low: 0, info: 0 };
    const byCategory = {
      documentAnomalies: 0,
      crossDocDiscrepancies: 0,
      timelineViolations: 0,
      paymentIssues: 0,
      federalViolations: 0,
      stateViolations: 0
    };

    // --- Document anomalies ---
    for (const doc of documentAnalyses) {
      const anomalies = doc.anomalies || [];
      byCategory.documentAnomalies += anomalies.length;
      for (const a of anomalies) {
        if (a.severity && bySeverity[a.severity] !== undefined) {
          bySeverity[a.severity]++;
        }
      }
    }

    // --- Forensic findings ---
    if (forensicReport) {
      // Discrepancies
      const discrepancies = forensicReport.discrepancies || [];
      byCategory.crossDocDiscrepancies = discrepancies.length;
      for (const d of discrepancies) {
        if (d.severity && bySeverity[d.severity] !== undefined) {
          bySeverity[d.severity]++;
        }
      }

      // Timeline violations
      const timelineViolations = (forensicReport.timeline && forensicReport.timeline.violations) || [];
      byCategory.timelineViolations = timelineViolations.length;
      for (const tv of timelineViolations) {
        if (tv.severity && bySeverity[tv.severity] !== undefined) {
          bySeverity[tv.severity]++;
        }
      }

      // Payment issues
      let paymentIssueCount = 0;
      if (forensicReport.paymentVerification) {
        const pv = forensicReport.paymentVerification;
        const unmatched = Array.isArray(pv.unmatchedDocumentPayments) ? pv.unmatchedDocumentPayments.length : 0;
        const feeIrregularities = (pv.feeAnalysis && Array.isArray(pv.feeAnalysis.irregularities))
          ? pv.feeAnalysis.irregularities.length : 0;
        paymentIssueCount = unmatched + feeIrregularities;
      }
      byCategory.paymentIssues = paymentIssueCount;
      // Payment issues don't have individual severity levels, count as medium
      bySeverity.medium += paymentIssueCount;
    }

    // --- Compliance findings ---
    if (complianceReport) {
      // Federal violations
      const federalViolations = complianceReport.violations || [];
      byCategory.federalViolations = federalViolations.length;
      for (const v of federalViolations) {
        if (v.severity && bySeverity[v.severity] !== undefined) {
          bySeverity[v.severity]++;
        }
      }

      // State violations
      const stateViolations = complianceReport.stateViolations || [];
      byCategory.stateViolations = stateViolations.length;
      for (const sv of stateViolations) {
        if (sv.severity && bySeverity[sv.severity] !== undefined) {
          bySeverity[sv.severity]++;
        }
      }
    }

    const totalFindings = Object.values(byCategory).reduce((sum, n) => sum + n, 0);

    return {
      totalFindings,
      bySeverity,
      byCategory
    };
  }
}

module.exports = new ReportAggregationService();
