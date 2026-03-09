/**
 * Jurisdiction Detection Service
 *
 * Determines which state lending laws apply to a given case based on
 * property location, servicer location, manual override, and case metadata.
 *
 * Priority order: manual override > property state > case metadata > servicer state
 *
 * Returns a structured jurisdiction object matching the jurisdictionSchema
 * from complianceReportSchema.js.
 */

const { isStateSupported } = require('../config/stateStatuteTaxonomy');

class JurisdictionService {

  /**
   * Detect which state jurisdictions apply to a case.
   *
   * @param {Object} [caseData={}] - Case data containing state information
   * @param {string} [caseData.propertyState] - 2-letter state code for property location
   * @param {string} [caseData.servicerState] - 2-letter state code for servicer location
   * @param {Object} [options={}] - Detection options
   * @param {string} [options.manualState] - Manual state override (highest priority)
   * @returns {{ propertyState: string|null, servicerState: string|null, applicableStates: string[], determinationMethod: string, confidence: string }}
   */
  detectJurisdiction(caseData, options) {
    caseData = caseData || {};
    options = options || {};

    const propertyState = this._normalizeStateCode(caseData.propertyState);
    const servicerState = this._normalizeStateCode(caseData.servicerState);
    const manualState = this._normalizeStateCode(options.manualState);

    // --- Manual override (highest priority) ---
    if (manualState) {
      const supported = isStateSupported(manualState) ? [manualState] : [];
      return {
        propertyState: propertyState || null,
        servicerState: servicerState || null,
        applicableStates: supported,
        determinationMethod: 'manual',
        confidence: supported.length > 0 ? 'high' : 'low'
      };
    }

    // --- No state info at all ---
    if (!propertyState && !servicerState) {
      return {
        propertyState: null,
        servicerState: null,
        applicableStates: [],
        determinationMethod: 'default',
        confidence: 'none'
      };
    }

    // --- Build applicable states with deduplication ---
    const seen = new Set();
    const applicableStates = [];

    // Property state first (higher priority)
    if (propertyState && isStateSupported(propertyState)) {
      applicableStates.push(propertyState);
      seen.add(propertyState);
    }

    // Servicer state second
    if (servicerState && isStateSupported(servicerState) && !seen.has(servicerState)) {
      applicableStates.push(servicerState);
      seen.add(servicerState);
    }

    // --- Determine method and confidence ---
    if (propertyState) {
      // Property state was provided (may or may not be supported)
      const anySupported = applicableStates.length > 0;
      return {
        propertyState,
        servicerState: servicerState || null,
        applicableStates,
        determinationMethod: 'property_location',
        confidence: anySupported ? 'high' : 'low'
      };
    }

    // Only servicer state provided
    return {
      propertyState: null,
      servicerState,
      applicableStates,
      determinationMethod: 'servicer_location',
      confidence: applicableStates.length > 0 ? 'medium' : 'low'
    };
  }

  /**
   * Normalize a state code: trim, uppercase, validate format.
   * Returns null for invalid/empty values.
   *
   * @param {*} code - Raw state code input
   * @returns {string|null} Normalized 2-letter uppercase code or null
   * @private
   */
  _normalizeStateCode(code) {
    if (code == null || typeof code !== 'string') return null;
    const trimmed = code.trim().toUpperCase();
    if (trimmed.length === 0) return null;
    // Must be exactly 2 alpha characters
    if (!/^[A-Z]{2}$/.test(trimmed)) return null;
    return trimmed;
  }
}

module.exports = JurisdictionService;
