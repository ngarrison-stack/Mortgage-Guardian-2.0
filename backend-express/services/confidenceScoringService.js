/**
 * Confidence Scoring & Evidence Linking Service
 *
 * Calculates overall and per-layer confidence scores from aggregated findings,
 * determines risk levels, and builds evidence links connecting findings to
 * source documents.
 *
 * Design principles:
 *   - Pure calculation logic — no external I/O, no side effects
 *   - Config-driven: all weights, thresholds, and categories from
 *     consolidatedReportConfig.js
 *   - Deterministic: same input always produces same output
 *   - Graceful with missing layers: null layers get null scores, weights
 *     redistribute to available layers
 *   - Singleton export pattern (consistent with other services)
 */

const {
  SCORING_WEIGHTS,
  LAYER_SCORING_FACTORS,
  RISK_THRESHOLDS,
  EVIDENCE_CATEGORIES
} = require('../config/consolidatedReportConfig');

const confidenceScoringService = {

  /**
   * Calculate overall confidence score and per-layer breakdown.
   *
   * @param {Object} aggregatedData - { documentAnalyses, forensicReport, complianceReport }
   * @returns {{ overall: number, breakdown: { documentAnalysis: number|null, forensicAnalysis: number|null, complianceAnalysis: number|null } }}
   */
  calculateConfidence(aggregatedData) {
    const { documentAnalyses = [], forensicReport = null, complianceReport = null } = aggregatedData;

    const docScore = this.documentAnalysisScore(documentAnalyses);
    const forensicScore = this.forensicAnalysisScore(forensicReport);
    const complianceScore = this.complianceAnalysisScore(complianceReport);

    // Build weighted average, redistributing weights for missing layers
    const layers = [
      { key: 'documentAnalysis', score: docScore, weight: SCORING_WEIGHTS.documentAnalysis },
      { key: 'forensicAnalysis', score: forensicScore, weight: SCORING_WEIGHTS.forensicAnalysis },
      { key: 'complianceAnalysis', score: complianceScore, weight: SCORING_WEIGHTS.complianceAnalysis }
    ];

    const availableLayers = layers.filter(l => l.score !== null);
    const totalAvailableWeight = availableLayers.reduce((sum, l) => sum + l.weight, 0);

    let overall;
    if (availableLayers.length === 0) {
      // No data at all — no evidence of problems = clean
      overall = 100;
    } else {
      overall = availableLayers.reduce((sum, l) => {
        const redistributedWeight = l.weight / totalAvailableWeight;
        return sum + l.score * redistributedWeight;
      }, 0);
    }

    overall = clamp(Math.round(overall * 100) / 100, 0, 100);

    return {
      overall,
      breakdown: {
        documentAnalysis: docScore,
        forensicAnalysis: forensicScore,
        complianceAnalysis: complianceScore
      }
    };
  },

  /**
   * Score individual document analyses. Starts at 100, penalizes for low
   * completeness and anomalies weighted by severity.
   *
   * @param {Array} documentAnalyses - Normalized document analysis objects
   * @returns {number} Score 0-100
   */
  documentAnalysisScore(documentAnalyses) {
    if (!documentAnalyses || documentAnalyses.length === 0) {
      return 100; // No docs = no negative evidence
    }

    const factors = LAYER_SCORING_FACTORS.documentAnalysis;
    const severityMultiplier = LAYER_SCORING_FACTORS.complianceAnalysis.severityMultiplier;

    // Average completeness across all docs (0-100)
    const avgCompleteness = documentAnalyses.reduce(
      (sum, doc) => sum + (doc.completenessScore || 0), 0
    ) / documentAnalyses.length;

    // Completeness contribution: how much of the max completeness we have
    const completenessComponent = avgCompleteness; // already 0-100

    // Anomaly penalty: sum of severity-weighted anomaly counts across all docs
    let totalAnomalyPenalty = 0;
    for (const doc of documentAnalyses) {
      const anomalies = doc.anomalies || [];
      for (const anomaly of anomalies) {
        const multiplier = severityMultiplier[anomaly.severity] || 1;
        totalAnomalyPenalty += multiplier * 10; // 10 points per unit of severity
      }
    }

    // Anomaly component: start at 100, subtract penalties, floor at 0
    const anomalyComponent = Math.max(0, 100 - totalAnomalyPenalty);

    // Weighted combination
    const score = factors.completenessWeight * completenessComponent +
                  factors.anomalyPenalty * anomalyComponent;

    return clamp(Math.round(score * 100) / 100, 0, 100);
  },

  /**
   * Score forensic analysis report. Starts at 100 per sub-factor,
   * penalizes for discrepancies, timeline violations, and payment issues.
   *
   * @param {Object|null} forensicReport - Forensic report object
   * @returns {number|null} Score 0-100, or null if no forensic data
   */
  forensicAnalysisScore(forensicReport) {
    if (!forensicReport) {
      return null;
    }

    const factors = LAYER_SCORING_FACTORS.forensicAnalysis;
    const severityMultiplier = LAYER_SCORING_FACTORS.complianceAnalysis.severityMultiplier;

    // Discrepancy penalty
    const discrepancies = forensicReport.discrepancies || [];
    let discrepancyPenalty = 0;
    for (const d of discrepancies) {
      const multiplier = severityMultiplier[d.severity] || 1;
      discrepancyPenalty += multiplier * 20;
    }
    const discrepancyComponent = Math.max(0, 100 - discrepancyPenalty);

    // Timeline penalty
    const timelineViolations = (forensicReport.timeline && forensicReport.timeline.violations) || [];
    let timelinePenalty = 0;
    for (const tv of timelineViolations) {
      const multiplier = severityMultiplier[tv.severity] || 1;
      timelinePenalty += multiplier * 15;
    }
    const timelineComponent = Math.max(0, 100 - timelinePenalty);

    // Payment penalty
    let paymentIssueCount = 0;
    if (forensicReport.paymentVerification) {
      const pv = forensicReport.paymentVerification;
      const unmatched = Array.isArray(pv.unmatchedDocumentPayments) ? pv.unmatchedDocumentPayments.length : 0;
      const feeIrregularities = (pv.feeAnalysis && Array.isArray(pv.feeAnalysis.irregularities))
        ? pv.feeAnalysis.irregularities.length : 0;
      paymentIssueCount = unmatched + feeIrregularities;
    }
    const paymentComponent = Math.max(0, 100 - paymentIssueCount * 15);

    // Weighted combination
    const weightedScore = factors.discrepancyPenalty * discrepancyComponent +
                          factors.timelinePenalty * timelineComponent +
                          factors.paymentPenalty * paymentComponent;

    // Apply floor drag: if any component bottoms out, cap overall score
    const minComponent = Math.min(discrepancyComponent, timelineComponent, paymentComponent);
    const score = minComponent === 0
      ? Math.min(weightedScore, 45)
      : weightedScore;

    return clamp(Math.round(score * 100) / 100, 0, 100);
  },

  /**
   * Score compliance analysis report. Penalizes violations using
   * severity multiplier from config.
   *
   * @param {Object|null} complianceReport - Compliance report object
   * @returns {number|null} Score 0-100, or null if no compliance data
   */
  complianceAnalysisScore(complianceReport) {
    if (!complianceReport) {
      return null;
    }

    const factors = LAYER_SCORING_FACTORS.complianceAnalysis;
    const severityMultiplier = factors.severityMultiplier;

    // Combine all violations (federal + state)
    const federalViolations = complianceReport.violations || [];
    const stateViolations = complianceReport.stateViolations || [];
    const allViolations = [...federalViolations, ...stateViolations];

    // Calculate total penalty from all violations
    let totalPenalty = 0;
    for (const v of allViolations) {
      const multiplier = severityMultiplier[v.severity] || 1;
      totalPenalty += multiplier * 12;
    }

    // Violation component
    const violationComponent = Math.max(0, 100 - totalPenalty);

    // The non-violation portion stays at 100 (no findings in other factors)
    const nonViolationWeight = 1 - factors.violationPenalty;
    const score = factors.violationPenalty * violationComponent +
                  nonViolationWeight * 100;

    return clamp(Math.round(score * 100) / 100, 0, 100);
  },

  /**
   * Determine risk level from overall confidence score using
   * RISK_THRESHOLDS config.
   *
   * @param {number} overallScore - Overall confidence score (0-100)
   * @returns {'critical'|'high'|'medium'|'low'|'clean'}
   */
  determineRiskLevel(overallScore) {
    // Evaluate thresholds in order from most severe
    const levels = ['critical', 'high', 'medium', 'low', 'clean'];
    for (const level of levels) {
      if (overallScore <= RISK_THRESHOLDS[level].maxScore) {
        return level;
      }
    }
    return 'clean';
  },

  /**
   * Build evidence links connecting findings to source documents.
   *
   * @param {Object} aggregatedData - { documentAnalyses, forensicReport, complianceReport }
   * @returns {Array<{ findingId, findingType, sourceDocumentIds, evidenceDescription, severity }>}
   */
  buildEvidenceLinks(aggregatedData) {
    const { documentAnalyses = [], forensicReport = null, complianceReport = null } = aggregatedData;
    const links = [];

    // --- Anomalies from document analyses ---
    for (const doc of documentAnalyses) {
      const anomalies = doc.anomalies || [];
      for (const anomaly of anomalies) {
        const template = EVIDENCE_CATEGORIES.anomaly.sourceDescriptionTemplate;
        links.push({
          findingId: anomaly.id || `anomaly-${links.length}`,
          findingType: 'anomaly',
          sourceDocumentIds: [doc.documentId],
          evidenceDescription: template.replace('{id}', anomaly.id || 'unknown'),
          severity: anomaly.severity || 'medium'
        });
      }
    }

    if (forensicReport) {
      // --- Discrepancies ---
      const discrepancies = forensicReport.discrepancies || [];
      for (const disc of discrepancies) {
        const docIds = [];
        if (disc.documentA && disc.documentA.documentId) docIds.push(disc.documentA.documentId);
        if (disc.documentB && disc.documentB.documentId) docIds.push(disc.documentB.documentId);
        const template = EVIDENCE_CATEGORIES.discrepancy.sourceDescriptionTemplate;
        links.push({
          findingId: disc.id || `discrepancy-${links.length}`,
          findingType: 'discrepancy',
          sourceDocumentIds: docIds.length > 0 ? docIds : ['unknown'],
          evidenceDescription: template.replace('{id}', disc.id || 'unknown'),
          severity: disc.severity || 'medium'
        });
      }

      // --- Timeline violations ---
      const timelineViolations = (forensicReport.timeline && forensicReport.timeline.violations) || [];
      for (let i = 0; i < timelineViolations.length; i++) {
        const tv = timelineViolations[i];
        const template = EVIDENCE_CATEGORIES.timelineViolation.sourceDescriptionTemplate;
        links.push({
          findingId: tv.id || `timeline-violation-${i}`,
          findingType: 'timelineViolation',
          sourceDocumentIds: tv.relatedDocuments || ['unknown'],
          evidenceDescription: template,
          severity: tv.severity || 'medium'
        });
      }

      // --- Payment issues ---
      if (forensicReport.paymentVerification) {
        const pv = forensicReport.paymentVerification;
        const unmatchedPayments = Array.isArray(pv.unmatchedDocumentPayments) ? pv.unmatchedDocumentPayments : [];
        for (let i = 0; i < unmatchedPayments.length; i++) {
          const pm = unmatchedPayments[i];
          const template = EVIDENCE_CATEGORIES.paymentIssue.sourceDescriptionTemplate;
          const docIds = [];
          if (pm.documentId) docIds.push(pm.documentId);
          if (pm.transactionId) docIds.push(pm.transactionId);
          links.push({
            findingId: pm.id || `payment-issue-${i}`,
            findingType: 'paymentIssue',
            sourceDocumentIds: docIds.length > 0 ? docIds : ['unmatched-payment'],
            evidenceDescription: template,
            severity: 'medium'
          });
        }

        const irregularities = (pv.feeAnalysis && Array.isArray(pv.feeAnalysis.irregularities))
          ? pv.feeAnalysis.irregularities : [];
        for (let i = 0; i < irregularities.length; i++) {
          const fee = irregularities[i];
          const template = EVIDENCE_CATEGORIES.paymentIssue.sourceDescriptionTemplate;
          links.push({
            findingId: fee.id || `fee-irregularity-${i}`,
            findingType: 'paymentIssue',
            sourceDocumentIds: fee.documentId ? [fee.documentId] : ['fee-analysis'],
            evidenceDescription: template,
            severity: 'medium'
          });
        }
      }
    }

    if (complianceReport) {
      // --- Federal violations ---
      const federalViolations = complianceReport.violations || [];
      for (const v of federalViolations) {
        const template = EVIDENCE_CATEGORIES.federalViolation.sourceDescriptionTemplate;
        const description = template
          .replace('{id}', v.id || 'unknown')
          .replace('{statuteName}', v.statuteName || 'unknown');
        links.push({
          findingId: v.id || `federal-violation-${links.length}`,
          findingType: 'federalViolation',
          sourceDocumentIds: v.sourceDocumentIds || ['compliance-analysis'],
          evidenceDescription: description,
          severity: v.severity || 'medium'
        });
      }

      // --- State violations ---
      const stateViolations = complianceReport.stateViolations || [];
      for (const sv of stateViolations) {
        const template = EVIDENCE_CATEGORIES.stateViolation.sourceDescriptionTemplate;
        const description = template
          .replace('{id}', sv.id || 'unknown')
          .replace('{statuteName}', sv.statuteName || 'unknown')
          .replace('{jurisdiction}', sv.jurisdiction || 'unknown');
        links.push({
          findingId: sv.id || `state-violation-${links.length}`,
          findingType: 'stateViolation',
          sourceDocumentIds: sv.sourceDocumentIds || ['compliance-analysis'],
          evidenceDescription: description,
          severity: sv.severity || 'medium'
        });
      }
    }

    return links;
  }
};

/**
 * Clamp a value between min and max.
 * @param {number} value
 * @param {number} min
 * @param {number} max
 * @returns {number}
 */
function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

module.exports = confidenceScoringService;
