/**
 * Compliance Orchestrator Service
 *
 * Coordinates the full federal lending law compliance analysis flow:
 *   Step 1: GATHER FORENSIC DATA — retrieve forensic report and analysis reports
 *   Step 2: RULE ENGINE EVALUATION — evaluate findings against federal statute rules
 *   Step 3: CLAUDE AI ENHANCEMENT — optional AI-powered legal analysis
 *   Step 4: ASSEMBLE REPORT — build compliance report matching schema
 *   Step 5: PERSIST — best-effort save to database
 *
 * Design principles:
 *   - Graceful degradation: individual step failures never crash the whole analysis
 *   - Best-effort persistence: log warnings on write failures, continue in-memory
 *   - Schema validation as warnings, not rejections
 *   - Singleton export pattern
 */

const { createLogger } = require('../utils/logger');
const complianceRuleEngine = require('./complianceRuleEngine');
const complianceAnalysisService = require('./complianceAnalysisService');
const { validateComplianceReport, RISK_LEVELS } = require('../schemas/complianceReportSchema');
const { getStatuteIds } = require('../config/federalStatuteTaxonomy');

const logger = createLogger('compliance');

// Severity ordering for risk calculation
const SEVERITY_RANK = { critical: 4, high: 3, medium: 2, low: 1, info: 0 };

class ComplianceService {

  /**
   * Run the full compliance evaluation for a case.
   *
   * @param {string} caseId - Case identifier (required)
   * @param {string} userId - User identifier (required)
   * @param {Object} [options={}] - Evaluation options
   * @param {boolean} [options.skipAiAnalysis=false] - Skip Claude AI enhancement
   * @param {string[]} [options.statuteFilter] - Only evaluate specific statutes
   * @returns {Promise<Object>} Compliance report or error object
   */
  async evaluateCompliance(caseId, userId, options = {}) {
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
    // Step 1: GATHER FORENSIC DATA
    // -----------------------------------------------------------------------
    let forensicReport;
    let analysisReports = [];
    const gatherStart = Date.now();

    try {
      const caseFileService = require('./caseFileService');
      const caseData = await caseFileService.getCase({ caseId, userId });

      if (!caseData || caseData.error) {
        stepMeta.gather = { status: 'failed', duration: Date.now() - gatherStart };
        return {
          error: true,
          errorMessage: 'Case has no forensic analysis. Run forensic analysis first.',
          _metadata: { duration: Date.now() - overallStart, steps: stepMeta, warnings }
        };
      }

      forensicReport = caseData.forensic_analysis || caseData.forensicAnalysis || null;

      if (!forensicReport) {
        stepMeta.gather = { status: 'failed', duration: Date.now() - gatherStart };
        return {
          error: true,
          errorMessage: 'Case has no forensic analysis. Run forensic analysis first.',
          _metadata: { duration: Date.now() - overallStart, steps: stepMeta, warnings }
        };
      }

      // Retrieve individual analysis reports if available
      analysisReports = caseData.analysis_reports || caseData.analysisReports || [];

      stepMeta.gather = {
        status: 'completed',
        duration: Date.now() - gatherStart,
        hasForensicReport: true,
        analysisReportsCount: analysisReports.length
      };
    } catch (err) {
      stepMeta.gather = { status: 'failed', duration: Date.now() - gatherStart };
      logger.error('Gather step failed', { caseId, error: err.message });
      return {
        error: true,
        errorMessage: `Failed to retrieve case data: ${err.message}`,
        _metadata: { duration: Date.now() - overallStart, steps: stepMeta, warnings }
      };
    }

    // -----------------------------------------------------------------------
    // Step 2: RULE ENGINE EVALUATION
    // -----------------------------------------------------------------------
    let violations = [];
    let statutesEvaluated = [];
    let evaluationMeta = {};
    const ruleStart = Date.now();

    try {
      const ruleResult = complianceRuleEngine.evaluateFindings(forensicReport, analysisReports);

      if (ruleResult.error) {
        warnings.push(`Rule engine returned error: ${ruleResult.error}`);
        stepMeta.ruleEngine = {
          status: 'warning',
          duration: Date.now() - ruleStart,
          error: ruleResult.error
        };
      } else {
        violations = ruleResult.violations || [];
        statutesEvaluated = ruleResult.statutesEvaluated || getStatuteIds();
        evaluationMeta = ruleResult.evaluationMeta || {};

        // Apply statute filter if provided
        if (Array.isArray(options.statuteFilter) && options.statuteFilter.length > 0) {
          violations = violations.filter(v => options.statuteFilter.includes(v.statuteId));
          statutesEvaluated = statutesEvaluated.filter(s => options.statuteFilter.includes(s));
        }

        stepMeta.ruleEngine = {
          status: 'completed',
          duration: Date.now() - ruleStart,
          violationsFound: violations.length,
          statutesEvaluated: statutesEvaluated.length
        };
      }
    } catch (err) {
      warnings.push(`Rule engine threw: ${err.message}`);
      logger.error('Rule engine step failed', { caseId, error: err.message });
      stepMeta.ruleEngine = {
        status: 'failed',
        duration: Date.now() - ruleStart,
        error: err.message
      };
    }

    // -----------------------------------------------------------------------
    // Step 3: CLAUDE AI ENHANCEMENT (optional)
    // -----------------------------------------------------------------------
    let legalNarrative = '';
    const aiStart = Date.now();

    if (options.skipAiAnalysis) {
      stepMeta.aiEnhancement = {
        status: 'skipped',
        duration: 0,
        reason: 'skipAiAnalysis option set'
      };
    } else if (violations.length === 0) {
      stepMeta.aiEnhancement = {
        status: 'skipped',
        duration: 0,
        reason: 'No violations to enhance'
      };
    } else {
      try {
        const caseContext = {
          caseId,
          documentTypes: this._extractDocumentTypes(forensicReport),
          discrepancySummary: this._buildDiscrepancySummary(forensicReport)
        };

        // Enhance violations with AI analysis
        const aiResult = await complianceAnalysisService.analyzeViolations(violations, caseContext);

        if (aiResult.enhancedViolations && aiResult.enhancedViolations.length > 0) {
          violations = aiResult.enhancedViolations;
        }

        legalNarrative = aiResult.legalNarrative || '';

        stepMeta.aiEnhancement = {
          status: 'completed',
          duration: Date.now() - aiStart,
          claudeCallsMade: aiResult.analysisMetadata ? aiResult.analysisMetadata.claudeCallsMade : 0
        };
      } catch (err) {
        warnings.push(`Claude AI enhancement failed: ${err.message}`);
        logger.warn('AI enhancement step failed, keeping rule-engine violations', {
          caseId,
          error: err.message
        });
        stepMeta.aiEnhancement = {
          status: 'failed',
          duration: Date.now() - aiStart,
          error: err.message
        };
      }
    }

    // -----------------------------------------------------------------------
    // Step 4: ASSEMBLE REPORT
    // -----------------------------------------------------------------------
    const assembleStart = Date.now();

    const complianceSummary = this._buildComplianceSummary(violations);

    // Use the statutes from rule engine, or fallback to all known statutes
    if (statutesEvaluated.length === 0) {
      statutesEvaluated = getStatuteIds();
    }

    const report = {
      caseId,
      analyzedAt: new Date().toISOString(),
      statutesEvaluated,
      violations,
      complianceSummary,
      legalNarrative: legalNarrative || undefined
    };

    // Schema validation (warnings only, don't reject)
    const { error: validationError } = validateComplianceReport(report);
    if (validationError) {
      warnings.push(`Schema validation warnings: ${validationError.message}`);
      logger.warn('Report schema validation produced warnings', {
        details: validationError.details.map(d => d.message)
      });
    }

    stepMeta.assemble = {
      status: 'completed',
      duration: Date.now() - assembleStart
    };

    // Attach metadata
    report._metadata = {
      duration: Date.now() - overallStart,
      steps: stepMeta,
      warnings
    };

    // -----------------------------------------------------------------------
    // Step 5: PERSIST (best-effort)
    // -----------------------------------------------------------------------
    await this._persistReport(caseId, userId, report);

    return report;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /**
   * Build the compliance summary from violations.
   * @param {Array} violations
   * @returns {Object} complianceSummary matching schema
   * @private
   */
  _buildComplianceSummary(violations) {
    const totalViolations = violations.length;
    const criticalViolations = violations.filter(v => v.severity === 'critical').length;
    const highViolations = violations.filter(v => v.severity === 'high').length;
    const mediumViolations = violations.filter(v => v.severity === 'medium').length;

    // Unique statute IDs with actual violations
    const statutesViolated = [...new Set(violations.map(v => v.statuteId).filter(Boolean))];

    // Overall compliance risk
    let overallComplianceRisk = 'low';
    if (criticalViolations > 0) overallComplianceRisk = 'critical';
    else if (highViolations > 0) overallComplianceRisk = 'high';
    else if (mediumViolations > 0) overallComplianceRisk = 'medium';

    // Key findings — sorted by severity, top 10
    const sorted = [...violations].sort((a, b) => {
      return (SEVERITY_RANK[b.severity] || 0) - (SEVERITY_RANK[a.severity] || 0);
    });
    const keyFindings = sorted.slice(0, 10).map(v => v.description);

    // Recommendations — deduplicated across all violations
    const recSet = new Set();
    for (const v of violations) {
      if (Array.isArray(v.recommendations)) {
        for (const rec of v.recommendations) {
          recSet.add(rec);
        }
      }
    }
    const recommendations = Array.from(recSet);

    return {
      totalViolations,
      criticalViolations,
      highViolations,
      statutesViolated,
      overallComplianceRisk,
      keyFindings,
      recommendations
    };
  }

  /**
   * Extract document types from the forensic report for case context.
   * @param {Object} forensicReport
   * @returns {string[]}
   * @private
   */
  _extractDocumentTypes(forensicReport) {
    if (!forensicReport) return [];
    const types = new Set();

    // From discrepancies
    const discrepancies = forensicReport.discrepancies || [];
    for (const disc of discrepancies) {
      if (disc.documentA && disc.documentA.documentType) types.add(disc.documentA.documentType);
      if (disc.documentB && disc.documentB.documentType) types.add(disc.documentB.documentType);
    }

    return Array.from(types);
  }

  /**
   * Build a brief summary of discrepancies for case context.
   * @param {Object} forensicReport
   * @returns {string}
   * @private
   */
  _buildDiscrepancySummary(forensicReport) {
    if (!forensicReport || !forensicReport.summary) return '';
    const s = forensicReport.summary;
    return `${s.totalDiscrepancies || 0} discrepancies found (${s.criticalFindings || 0} critical, ${s.highFindings || 0} high). Risk level: ${s.riskLevel || 'unknown'}.`;
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
        updates: { compliance_report: report }
      });
      logger.info('Compliance report persisted', { caseId });
    } catch (err) {
      logger.warn('Failed to persist compliance report (best-effort)', {
        caseId,
        error: err.message
      });
    }
  }
}

module.exports = new ComplianceService();
