/**
 * Compliance Rule Engine
 *
 * Evaluates forensic analysis findings against federal statute rules
 * to produce violation objects. Core business logic for Phase 14.
 *
 * Input:  forensicReport (cross-document analysis), analysisReports (individual doc analyses)
 * Output: { violations[], statutesEvaluated[], evaluationMeta }
 */

const { getStatuteById, getSectionById, getStatuteIds } = require('../config/federalStatuteTaxonomy');
const { matchRules } = require('../config/complianceRuleMappings');
const { matchStateRules } = require('../config/stateComplianceRuleMappings');
const { getStateStatuteById, getStateSectionById, getStateStatuteIds, isStateSupported } = require('../config/stateStatuteTaxonomy');

// Severity ordering for comparison (lower = more severe)
const SEVERITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3, info: 4 };

class ComplianceRuleEngine {

  /**
   * Main entry point — evaluates forensic findings against federal statute rules.
   *
   * @param {Object} forensicReport - Cross-document analysis output
   * @param {Array} analysisReports - Array of individual document analyses
   * @returns {Object} { violations, statutesEvaluated, evaluationMeta } or { error }
   */
  evaluateFindings(forensicReport, analysisReports) {
    // --- Input validation ---
    if (!forensicReport || typeof forensicReport !== 'object') {
      return { error: 'forensicReport is required and must be an object' };
    }
    if (!forensicReport.caseId) {
      return { error: 'forensicReport.caseId is required' };
    }

    const reports = Array.isArray(analysisReports) ? analysisReports : [];

    // --- Extract and evaluate each finding category ---
    const discrepancies = forensicReport.discrepancies || [];
    const timelineViolations = (forensicReport.timeline && forensicReport.timeline.violations) || [];
    const paymentVerification = forensicReport.paymentVerification || null;

    // Collect anomalies from individual analysis reports
    const anomalies = [];
    for (const report of reports) {
      if (report && Array.isArray(report.anomalies)) {
        anomalies.push(...report.anomalies);
      }
    }

    let allViolations = [];

    allViolations.push(...this._evaluateDiscrepancies(discrepancies));
    allViolations.push(...this._evaluateAnomalies(anomalies));
    allViolations.push(...this._evaluateTimelineViolations(timelineViolations));
    allViolations.push(...this._evaluatePaymentIssues(paymentVerification));

    // --- Deduplicate by sectionId + evidence sourceId (keep higher severity) ---
    allViolations = this._deduplicateViolations(allViolations);

    // --- Assign sequential IDs ---
    allViolations.forEach((v, i) => {
      v.id = `viol-${String(i + 1).padStart(3, '0')}`;
    });

    const totalFindingsEvaluated = discrepancies.length + anomalies.length
      + timelineViolations.length
      + (paymentVerification ? this._countPaymentFindings(paymentVerification) : 0);

    return {
      violations: allViolations,
      statutesEvaluated: getStatuteIds(),
      evaluationMeta: {
        totalFindingsEvaluated,
        rulesChecked: 32,
        discrepanciesEvaluated: discrepancies.length,
        anomaliesEvaluated: anomalies.length,
        timelineViolationsEvaluated: timelineViolations.length
      }
    };
  }

  /**
   * Evaluate discrepancies from forensic report.
   * @param {Array} discrepancies
   * @returns {Array} violations
   */
  _evaluateDiscrepancies(discrepancies) {
    const violations = [];
    for (const disc of discrepancies) {
      const finding = {
        discrepancyType: disc.type,
        severity: disc.severity,
        description: disc.description || '',
        fields: this._extractFields(disc),
        amount: this._extractAmount(disc),
        date: this._extractDate(disc),
        isCriticalField: this._isCriticalField(disc)
      };

      const matchedRules = matchRules(finding);
      for (const rule of matchedRules) {
        const evidence = {
          sourceType: 'discrepancy',
          sourceId: disc.id,
          description: disc.description || ''
        };
        violations.push(this._buildViolation(finding, rule, evidence));
      }
    }
    return violations;
  }

  /**
   * Evaluate anomalies from individual analysis reports.
   * @param {Array} anomalies
   * @returns {Array} violations
   */
  _evaluateAnomalies(anomalies) {
    const violations = [];
    for (const anom of anomalies) {
      const finding = {
        anomalyType: anom.type,
        severity: anom.severity,
        description: anom.description || '',
        fields: anom.field ? [anom.field] : [],
        amount: this._extractAmountFromText(anom.description),
        isCriticalField: this._isCriticalField({ fields: anom.field ? [anom.field] : [] })
      };

      const matchedRules = matchRules(finding);
      for (const rule of matchedRules) {
        const evidence = {
          sourceType: 'anomaly',
          sourceId: anom.field ? `anom-${anom.field}` : 'anom-unknown',
          description: anom.description || ''
        };
        violations.push(this._buildViolation(finding, rule, evidence));
      }
    }
    return violations;
  }

  /**
   * Evaluate timeline violations from forensic report.
   * @param {Array} timelineViolations
   * @returns {Array} violations
   */
  _evaluateTimelineViolations(timelineViolations) {
    const violations = [];
    for (let i = 0; i < timelineViolations.length; i++) {
      const tv = timelineViolations[i];
      const finding = {
        discrepancyType: 'timeline_violation',
        isTimelineViolation: true,
        severity: tv.severity,
        description: tv.description || '',
        fields: [],
        amount: this._extractAmountFromText(tv.description),
        isCriticalField: false
      };

      const matchedRules = matchRules(finding);
      for (const rule of matchedRules) {
        const evidence = {
          sourceType: 'timeline_violation',
          sourceId: `tv-${String(i + 1).padStart(3, '0')}`,
          description: tv.description || ''
        };
        violations.push(this._buildViolation(finding, rule, evidence));
      }
    }
    return violations;
  }

  /**
   * Evaluate payment verification issues.
   * @param {Object|null} paymentVerification
   * @returns {Array} violations
   */
  _evaluatePaymentIssues(paymentVerification) {
    if (!paymentVerification) return [];

    const violations = [];

    // Unmatched document payments → potential payment crediting issues
    const unmatchedPayments = paymentVerification.unmatchedDocumentPayments || [];
    for (let i = 0; i < unmatchedPayments.length; i++) {
      const payment = unmatchedPayments[i];
      const finding = {
        discrepancyType: 'amount_mismatch',
        isPaymentIssue: true,
        severity: 'high',
        description: payment.description || `Unmatched payment of $${payment.amount}`,
        fields: ['payment'],
        amount: payment.amount,
        isCriticalField: false
      };

      const matchedRules = matchRules(finding);
      for (const rule of matchedRules) {
        const evidence = {
          sourceType: 'payment_issue',
          sourceId: `pay-${String(i + 1).padStart(3, '0')}`,
          description: payment.description || `Payment of $${payment.amount} on ${payment.date} not verified`
        };
        violations.push(this._buildViolation(finding, rule, evidence));
      }
    }

    // Fee irregularities from fee analysis
    const feeAnalysis = paymentVerification.feeAnalysis;
    if (feeAnalysis && Array.isArray(feeAnalysis.irregularities)) {
      for (let i = 0; i < feeAnalysis.irregularities.length; i++) {
        const irreg = feeAnalysis.irregularities[i];
        const finding = {
          discrepancyType: 'fee_irregularity',
          isPaymentIssue: true,
          severity: irreg.severity || 'medium',
          description: irreg.description || 'Fee irregularity detected',
          fields: ['fee'],
          amount: irreg.amount,
          isCriticalField: false
        };

        const matchedRules = matchRules(finding);
        for (const rule of matchedRules) {
          const evidence = {
            sourceType: 'payment_issue',
            sourceId: `fee-${String(i + 1).padStart(3, '0')}`,
            description: irreg.description || 'Fee irregularity'
          };
          violations.push(this._buildViolation(finding, rule, evidence));
        }
      }
    }

    return violations;
  }

  /**
   * Build a violation object from a finding, matched rule, and evidence.
   *
   * @param {Object} finding - Normalized finding
   * @param {Object} rule - Matched compliance rule
   * @param {Object} evidence - Evidence linking
   * @returns {Object} Violation object (without id — assigned later)
   */
  _buildViolation(finding, rule, evidence) {
    const sectionId = rule.sectionId;
    const section = getSectionById(sectionId);
    const statuteId = sectionId.split('_')[0] === 'cfpb' ? 'cfpb_reg_x' : sectionId.replace(/_.*/, '');
    const statute = getStatuteById(statuteId);

    // Determine severity (with possible elevation)
    let severity = rule.violationSeverity;
    if (this._shouldElevateSeverity(finding, rule)) {
      severity = rule.severityElevation.elevatedSeverity;
    }

    // Fill description template
    const description = this._fillTemplate(rule.descriptionTemplate, finding);
    const legalBasis = rule.legalBasisTemplate;

    return {
      id: null, // assigned after deduplication
      statuteId,
      sectionId,
      statuteName: statute ? statute.name : 'Unknown Statute',
      sectionTitle: section ? section.title : 'Unknown Section',
      citation: this._buildCitation(statute, section),
      severity,
      description,
      evidence: [evidence],
      legalBasis,
      potentialPenalties: section ? section.penalties : undefined,
      recommendations: []
    };
  }

  /**
   * Check whether severity should be elevated for a finding+rule pair.
   *
   * @param {Object} finding - Normalized finding
   * @param {Object} rule - Compliance rule
   * @returns {boolean}
   */
  _shouldElevateSeverity(finding, rule) {
    if (!rule || !rule.severityElevation || !Array.isArray(rule.severityElevation.conditions)) {
      return false;
    }

    for (const condition of rule.severityElevation.conditions) {
      // Check amount threshold conditions like "amount > 100"
      const amountMatch = condition.match(/^amount\s*>\s*(\d+(?:\.\d+)?)$/);
      if (amountMatch) {
        const threshold = parseFloat(amountMatch[1]);
        const amount = this._resolveAmount(finding);
        if (amount !== null && amount > threshold) {
          return true;
        }
        continue;
      }

      // Check critical_field condition
      if (condition === 'critical_field' && finding.isCriticalField) {
        return true;
      }

      // Check repeated condition (not evaluated at single-finding level, skip)
      if (condition === 'repeated') {
        continue;
      }
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /**
   * Deduplicate violations by sectionId + primary evidence sourceId.
   * Keeps the higher severity violation.
   */
  _deduplicateViolations(violations) {
    const map = new Map();
    for (const v of violations) {
      const sourceId = v.evidence[0] ? v.evidence[0].sourceId : '';
      const key = `${v.sectionId}|${sourceId}`;
      const existing = map.get(key);
      if (!existing) {
        map.set(key, v);
      } else {
        // Keep higher severity (lower number in SEVERITY_ORDER)
        const existingSev = SEVERITY_ORDER[existing.severity] ?? 4;
        const newSev = SEVERITY_ORDER[v.severity] ?? 4;
        if (newSev < existingSev) {
          map.set(key, v);
        }
      }
    }
    return Array.from(map.values());
  }

  /**
   * Extract field names from a discrepancy.
   */
  _extractFields(disc) {
    const fields = [];
    if (disc.documentA && disc.documentA.field) fields.push(disc.documentA.field);
    if (disc.documentB && disc.documentB.field) fields.push(disc.documentB.field);
    return fields;
  }

  /**
   * Extract a numeric amount from a discrepancy (difference between values).
   */
  _extractAmount(disc) {
    if (disc.documentA && disc.documentB) {
      const a = typeof disc.documentA.value === 'number' ? disc.documentA.value : null;
      const b = typeof disc.documentB.value === 'number' ? disc.documentB.value : null;
      if (a !== null && b !== null) {
        return Math.abs(a - b);
      }
    }
    // Fallback: extract from description
    return this._extractAmountFromText(disc.description);
  }

  /**
   * Extract the first date-like value from a discrepancy.
   */
  _extractDate(disc) {
    if (disc.documentA && typeof disc.documentA.value === 'string' && /\d{4}-\d{2}-\d{2}/.test(disc.documentA.value)) {
      return disc.documentA.value;
    }
    return undefined;
  }

  /**
   * Extract a dollar amount from text (e.g. "$450" → 450).
   */
  _extractAmountFromText(text) {
    if (!text) return null;
    const match = text.match(/\$([0-9,]+(?:\.\d{2})?)/);
    if (match) {
      return parseFloat(match[1].replace(/,/g, ''));
    }
    return null;
  }

  /**
   * Resolve the numeric amount from a finding.
   */
  _resolveAmount(finding) {
    if (typeof finding.amount === 'number') return finding.amount;
    return this._extractAmountFromText(finding.description);
  }

  /**
   * Check if a finding involves a critical field.
   */
  _isCriticalField(item) {
    if (item && item.isCriticalField) return true;
    const criticalFields = ['apr', 'interestRate', 'principalBalance', 'escrowBalance', 'monthlyPayment', 'totalOfPayments', 'financeCharge'];
    const fields = item.fields || [];
    if (item.documentA && item.documentA.field) fields.push(item.documentA.field);
    if (item.documentB && item.documentB.field) fields.push(item.documentB.field);
    return fields.some(f => criticalFields.includes(f));
  }

  /**
   * Fill a template string with finding data.
   * Replaces {description}, {amount}, {date} placeholders.
   */
  _fillTemplate(template, finding) {
    if (!template) return '';
    return template
      .replace(/\{description\}/g, finding.description || 'N/A')
      .replace(/\{amount\}/g, finding.amount != null ? `$${finding.amount}` : 'N/A')
      .replace(/\{date\}/g, finding.date || 'N/A');
  }

  /**
   * Build a citation string from statute and section.
   */
  _buildCitation(statute, section) {
    const parts = [];
    if (statute && statute.citation) parts.push(statute.citation);
    if (section && section.regulatoryReference) parts.push(section.regulatoryReference);
    return parts.join('; ') || 'Unknown citation';
  }

  /**
   * Count payment-related findings.
   */
  _countPaymentFindings(pv) {
    let count = 0;
    if (pv.unmatchedDocumentPayments) count += pv.unmatchedDocumentPayments.length;
    if (pv.feeAnalysis && pv.feeAnalysis.irregularities) count += pv.feeAnalysis.irregularities.length;
    return count;
  }

  // ===========================================================================
  // State Compliance Evaluation
  // ===========================================================================

  /**
   * Evaluate forensic findings against state-specific statute rules.
   *
   * @param {Object} forensicReport - Cross-document analysis output
   * @param {Array} analysisReports - Array of individual document analyses
   * @param {Object} jurisdiction - Jurisdiction config with applicableStates[]
   * @returns {Object} { stateViolations, stateStatutesEvaluated, evaluationMeta } or { error }
   */
  evaluateStateFindings(forensicReport, analysisReports, jurisdiction) {
    // --- Input validation ---
    if (!jurisdiction || typeof jurisdiction !== 'object') {
      return { error: 'jurisdiction is required and must be an object' };
    }
    if (!forensicReport || typeof forensicReport !== 'object') {
      return { error: 'forensicReport is required and must be an object' };
    }

    const applicableStates = Array.isArray(jurisdiction.applicableStates) ? jurisdiction.applicableStates : [];
    if (applicableStates.length === 0) {
      return {
        stateViolations: [],
        stateStatutesEvaluated: [],
        evaluationMeta: { totalFindingsEvaluated: 0, statesEvaluated: 0, rulesChecked: 0 }
      };
    }

    const reports = Array.isArray(analysisReports) ? analysisReports : [];

    // --- Extract findings (same logic as evaluateFindings) ---
    const discrepancies = forensicReport.discrepancies || [];
    const timelineViolations = (forensicReport.timeline && forensicReport.timeline.violations) || [];
    const paymentVerification = forensicReport.paymentVerification || null;

    const anomalies = [];
    for (const report of reports) {
      if (report && Array.isArray(report.anomalies)) {
        anomalies.push(...report.anomalies);
      }
    }

    let allViolations = [];
    let allStatutesEvaluated = [];
    let totalRulesChecked = 0;
    let statesEvaluated = 0;

    for (const stateCode of applicableStates) {
      if (!isStateSupported(stateCode)) {
        continue; // skip unsupported states gracefully
      }

      statesEvaluated++;

      // Evaluate each finding category against state rules
      allViolations.push(...this._evaluateStateDiscrepancies(stateCode, discrepancies));
      allViolations.push(...this._evaluateStateAnomalies(stateCode, anomalies));
      allViolations.push(...this._evaluateStateTimelineViolations(stateCode, timelineViolations));
      allViolations.push(...this._evaluateStatePaymentIssues(stateCode, paymentVerification));

      // Track evaluated statutes
      const stateStatuteIds = getStateStatuteIds(stateCode);
      allStatutesEvaluated.push(...stateStatuteIds);
      totalRulesChecked += stateStatuteIds.length;
    }

    // --- Deduplicate by sectionId + evidence sourceId (keep higher severity) ---
    allViolations = this._deduplicateViolations(allViolations);

    // --- Assign state-specific sequential IDs ---
    allViolations.forEach((v, i) => {
      v.id = `state-viol-${String(i + 1).padStart(3, '0')}`;
    });

    const totalFindingsEvaluated = discrepancies.length + anomalies.length
      + timelineViolations.length
      + (paymentVerification ? this._countPaymentFindings(paymentVerification) : 0);

    return {
      stateViolations: allViolations,
      stateStatutesEvaluated: allStatutesEvaluated,
      evaluationMeta: {
        totalFindingsEvaluated,
        statesEvaluated,
        rulesChecked: totalRulesChecked
      }
    };
  }

  /**
   * Evaluate discrepancies against state-specific rules.
   */
  _evaluateStateDiscrepancies(stateCode, discrepancies) {
    const violations = [];
    for (const disc of discrepancies) {
      const finding = {
        discrepancyType: disc.type,
        severity: disc.severity,
        description: disc.description || '',
        fields: this._extractFields(disc),
        amount: this._extractAmount(disc),
        date: this._extractDate(disc),
        isCriticalField: this._isCriticalField(disc)
      };

      const matchedRules = matchStateRules(stateCode, finding);
      for (const rule of matchedRules) {
        const evidence = {
          sourceType: 'discrepancy',
          sourceId: disc.id,
          description: disc.description || ''
        };
        violations.push(this._buildStateViolation(stateCode, finding, rule, evidence));
      }
    }
    return violations;
  }

  /**
   * Evaluate anomalies against state-specific rules.
   */
  _evaluateStateAnomalies(stateCode, anomalies) {
    const violations = [];
    for (const anom of anomalies) {
      const finding = {
        anomalyType: anom.type,
        severity: anom.severity,
        description: anom.description || '',
        fields: anom.field ? [anom.field] : [],
        amount: this._extractAmountFromText(anom.description),
        isCriticalField: this._isCriticalField({ fields: anom.field ? [anom.field] : [] })
      };

      const matchedRules = matchStateRules(stateCode, finding);
      for (const rule of matchedRules) {
        const evidence = {
          sourceType: 'anomaly',
          sourceId: anom.field ? `anom-${anom.field}` : 'anom-unknown',
          description: anom.description || ''
        };
        violations.push(this._buildStateViolation(stateCode, finding, rule, evidence));
      }
    }
    return violations;
  }

  /**
   * Evaluate timeline violations against state-specific rules.
   */
  _evaluateStateTimelineViolations(stateCode, timelineViolations) {
    const violations = [];
    for (let i = 0; i < timelineViolations.length; i++) {
      const tv = timelineViolations[i];
      const finding = {
        discrepancyType: 'timeline_violation',
        isTimelineViolation: true,
        severity: tv.severity,
        description: tv.description || '',
        fields: [],
        amount: this._extractAmountFromText(tv.description),
        isCriticalField: false
      };

      const matchedRules = matchStateRules(stateCode, finding);
      for (const rule of matchedRules) {
        const evidence = {
          sourceType: 'timeline_violation',
          sourceId: `tv-${String(i + 1).padStart(3, '0')}`,
          description: tv.description || ''
        };
        violations.push(this._buildStateViolation(stateCode, finding, rule, evidence));
      }
    }
    return violations;
  }

  /**
   * Evaluate payment verification issues against state-specific rules.
   */
  _evaluateStatePaymentIssues(stateCode, paymentVerification) {
    if (!paymentVerification) return [];

    const violations = [];

    const unmatchedPayments = paymentVerification.unmatchedDocumentPayments || [];
    for (let i = 0; i < unmatchedPayments.length; i++) {
      const payment = unmatchedPayments[i];
      const finding = {
        discrepancyType: 'amount_mismatch',
        isPaymentIssue: true,
        severity: 'high',
        description: payment.description || `Unmatched payment of $${payment.amount}`,
        fields: ['payment'],
        amount: payment.amount,
        isCriticalField: false
      };

      const matchedRules = matchStateRules(stateCode, finding);
      for (const rule of matchedRules) {
        const evidence = {
          sourceType: 'payment_issue',
          sourceId: `pay-${String(i + 1).padStart(3, '0')}`,
          description: payment.description || `Payment of $${payment.amount} on ${payment.date} not verified`
        };
        violations.push(this._buildStateViolation(stateCode, finding, rule, evidence));
      }
    }

    const feeAnalysis = paymentVerification.feeAnalysis;
    if (feeAnalysis && Array.isArray(feeAnalysis.irregularities)) {
      for (let i = 0; i < feeAnalysis.irregularities.length; i++) {
        const irreg = feeAnalysis.irregularities[i];
        const finding = {
          discrepancyType: 'fee_irregularity',
          isPaymentIssue: true,
          severity: irreg.severity || 'medium',
          description: irreg.description || 'Fee irregularity detected',
          fields: ['fee'],
          amount: irreg.amount,
          isCriticalField: false
        };

        const matchedRules = matchStateRules(stateCode, finding);
        for (const rule of matchedRules) {
          const evidence = {
            sourceType: 'payment_issue',
            sourceId: `fee-${String(i + 1).padStart(3, '0')}`,
            description: irreg.description || 'Fee irregularity'
          };
          violations.push(this._buildStateViolation(stateCode, finding, rule, evidence));
        }
      }
    }

    return violations;
  }

  /**
   * Build a state violation object from a finding, matched state rule, and evidence.
   *
   * @param {string} stateCode - 2-letter state code
   * @param {Object} finding - Normalized finding
   * @param {Object} rule - Matched state compliance rule
   * @param {Object} evidence - Evidence linking
   * @returns {Object} State violation object (without id — assigned later)
   */
  _buildStateViolation(stateCode, finding, rule, evidence) {
    const sectionId = rule.sectionId;
    const section = getStateSectionById(stateCode, sectionId);

    // Derive statuteId from sectionId: take first two underscore-separated segments
    // e.g. 'ca_hbor_dual_tracking' → 'ca_hbor', 'ca_civ_escrow_accounts' → 'ca_civ'
    const parts = sectionId.split('_');
    const statuteId = parts.length >= 2 ? `${parts[0]}_${parts[1]}` : sectionId;
    const statute = getStateStatuteById(stateCode, statuteId);

    // Determine severity (with possible elevation)
    let severity = rule.violationSeverity;
    if (this._shouldElevateSeverity(finding, rule)) {
      severity = rule.severityElevation.elevatedSeverity;
    }

    // Fill description template
    const description = this._fillTemplate(rule.descriptionTemplate, finding);
    const legalBasis = rule.legalBasisTemplate;

    return {
      id: null, // assigned after deduplication
      statuteId,
      sectionId,
      statuteName: statute ? statute.name : 'Unknown Statute',
      sectionTitle: section ? section.title : 'Unknown Section',
      citation: this._buildCitation(statute, section),
      severity,
      description,
      evidence: [evidence],
      legalBasis,
      potentialPenalties: section ? section.penalties : undefined,
      recommendations: [],
      jurisdiction: stateCode
    };
  }
}

module.exports = new ComplianceRuleEngine();
