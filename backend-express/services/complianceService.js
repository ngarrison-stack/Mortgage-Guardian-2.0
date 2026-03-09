/**
 * Compliance Orchestrator Service
 *
 * Coordinates the full federal and state lending law compliance analysis flow:
 *   Step 1:  GATHER FORENSIC DATA — retrieve forensic report and analysis reports
 *   Step 2:  FEDERAL RULE ENGINE EVALUATION — evaluate findings against federal statute rules
 *   Step 2a: DETECT JURISDICTION — determine applicable state(s)
 *   Step 2b: STATE RULE ENGINE — evaluate findings against state statute rules
 *   Step 3:  CLAUDE AI ENHANCEMENT (federal) — optional AI-powered legal analysis
 *   Step 3a: STATE AI ENHANCEMENT — optional AI-powered state legal analysis
 *   Step 4:  ASSEMBLE REPORT — build compliance report matching schema
 *   Step 5:  PERSIST — best-effort save to database
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
   * @param {string[]} [options.statuteFilter] - Only evaluate specific federal statutes
   * @param {string} [options.state] - Manual state override for jurisdiction detection
   * @param {boolean} [options.skipStateAnalysis=false] - Skip state compliance entirely
   * @param {string[]} [options.stateStatuteFilter] - Only evaluate specific state statutes
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
    let caseData;
    const gatherStart = Date.now();

    try {
      const caseFileService = require('./caseFileService');
      caseData = await caseFileService.getCase({ caseId, userId });

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
    // Step 2: RULE ENGINE EVALUATION (federal)
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
    // Step 2a: DETECT JURISDICTION
    // -----------------------------------------------------------------------
    let jurisdiction = null;
    let stateViolations = [];
    let stateStatutesEvaluated = [];

    if (options.skipStateAnalysis) {
      stepMeta.jurisdictionDetection = {
        status: 'skipped',
        duration: 0,
        reason: 'skipStateAnalysis option set'
      };
    } else {
      const jurisdictionStart = Date.now();
      try {
        const JurisdictionService = require('./jurisdictionService');
        const jurisdictionService = new JurisdictionService();
        const jurisdictionOptions = {};
        if (options.state) {
          jurisdictionOptions.manualState = options.state;
        }
        jurisdiction = jurisdictionService.detectJurisdiction(caseData || {}, jurisdictionOptions);

        stepMeta.jurisdictionDetection = {
          status: 'completed',
          duration: Date.now() - jurisdictionStart,
          applicableStates: jurisdiction.applicableStates,
          determinationMethod: jurisdiction.determinationMethod
        };
      } catch (err) {
        warnings.push(`Jurisdiction detection failed: ${err.message}`);
        logger.warn('Jurisdiction detection step failed, skipping state analysis', {
          caseId,
          error: err.message
        });
        stepMeta.jurisdictionDetection = {
          status: 'failed',
          duration: Date.now() - jurisdictionStart,
          error: err.message
        };
      }

      // ---------------------------------------------------------------------
      // Step 2b: STATE RULE ENGINE
      // ---------------------------------------------------------------------
      if (jurisdiction && Array.isArray(jurisdiction.applicableStates) && jurisdiction.applicableStates.length > 0) {
        const stateRuleStart = Date.now();
        try {
          const stateResult = complianceRuleEngine.evaluateStateFindings(
            forensicReport, analysisReports, jurisdiction
          );

          if (stateResult.error) {
            warnings.push(`State rule engine returned error: ${stateResult.error}`);
            stepMeta.stateRuleEngine = {
              status: 'warning',
              duration: Date.now() - stateRuleStart,
              error: stateResult.error
            };
          } else {
            stateViolations = stateResult.stateViolations || [];
            stateStatutesEvaluated = stateResult.stateStatutesEvaluated || [];

            // Apply state statute filter if provided
            if (Array.isArray(options.stateStatuteFilter) && options.stateStatuteFilter.length > 0) {
              stateViolations = stateViolations.filter(v => options.stateStatuteFilter.includes(v.statuteId));
              stateStatutesEvaluated = stateStatutesEvaluated.filter(s => options.stateStatuteFilter.includes(s));
            }

            stepMeta.stateRuleEngine = {
              status: 'completed',
              duration: Date.now() - stateRuleStart,
              stateViolationsFound: stateViolations.length,
              stateStatutesEvaluated: stateStatutesEvaluated.length
            };
          }
        } catch (err) {
          warnings.push(`State rule engine threw: ${err.message}`);
          logger.warn('State rule engine step failed, continuing without state violations', {
            caseId,
            error: err.message
          });
          stepMeta.stateRuleEngine = {
            status: 'failed',
            duration: Date.now() - stateRuleStart,
            error: err.message
          };
        }
      }
    }

    // -----------------------------------------------------------------------
    // Step 3: CLAUDE AI ENHANCEMENT (federal, optional)
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
    // Step 3a: STATE AI ENHANCEMENT (optional)
    // -----------------------------------------------------------------------
    if (!options.skipAiAnalysis && !options.skipStateAnalysis && stateViolations.length > 0) {
      const stateAiStart = Date.now();
      try {
        const caseContext = {
          caseId,
          documentTypes: this._extractDocumentTypes(forensicReport),
          discrepancySummary: this._buildDiscrepancySummary(forensicReport)
        };

        const stateAiResult = await complianceAnalysisService.analyzeStateViolations(
          stateViolations, caseContext
        );

        if (stateAiResult.enhancedViolations && stateAiResult.enhancedViolations.length > 0) {
          stateViolations = stateAiResult.enhancedViolations;
        }

        stepMeta.stateAiEnhancement = {
          status: 'completed',
          duration: Date.now() - stateAiStart,
          claudeCallsMade: stateAiResult.analysisMetadata ? stateAiResult.analysisMetadata.claudeCallsMade : 0
        };
      } catch (err) {
        warnings.push(`State AI enhancement failed: ${err.message}`);
        logger.warn('State AI enhancement step failed, keeping rule-engine state violations', {
          caseId,
          error: err.message
        });
        stepMeta.stateAiEnhancement = {
          status: 'failed',
          duration: Date.now() - stateAiStart,
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

    // Add state compliance fields if jurisdiction was detected
    if (jurisdiction) {
      report.jurisdiction = jurisdiction;
    }
    if (stateViolations.length > 0) {
      report.stateViolations = stateViolations;
    }
    if (stateStatutesEvaluated.length > 0) {
      report.stateStatutesEvaluated = stateStatutesEvaluated;
    }
    if (jurisdiction && !options.skipStateAnalysis) {
      const statesAnalyzed = jurisdiction.applicableStates || [];
      report.stateCompliance = {
        statesAnalyzed: statesAnalyzed.length,
        totalStateViolations: stateViolations.length,
        stateRiskLevel: this._calculateStateRiskLevel(stateViolations)
      };
    }

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
   * Calculate risk level for state violations.
   * @param {Array} stateViolations
   * @returns {string} Risk level
   * @private
   */
  _calculateStateRiskLevel(stateViolations) {
    if (!Array.isArray(stateViolations) || stateViolations.length === 0) return 'low';
    const hasCritical = stateViolations.some(v => v.severity === 'critical');
    const hasHigh = stateViolations.some(v => v.severity === 'high');
    const hasMedium = stateViolations.some(v => v.severity === 'medium');
    if (hasCritical) return 'critical';
    if (hasHigh) return 'high';
    if (hasMedium) return 'medium';
    return 'low';
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
