/**
 * State Statute Taxonomy Configuration
 *
 * Comprehensive taxonomy of state mortgage lending laws and their requirements.
 * Organized by 2-letter state code with the same data shape as
 * federalStatuteTaxonomy.js so the compliance rule engine can process state
 * rules identically to federal ones.
 *
 * Each state entry contains statutes → sections → requirements/violationPatterns,
 * mirroring the federal structure for code reuse with matchRules().
 *
 * Priority states are scaffolded here with empty statute arrays.
 * Actual statute data is populated in plans 15-03 and 15-04.
 *
 * This is config data — declarative, no business logic.
 */

// =========================================================================
// STATE_STATUTES — keyed by 2-letter state code
//
// Shape per state:
//   { stateCode, stateName, statutes: { [statuteId]: { id, name, citation,
//     enforcementBody, sections: [{ id, section, title, regulatoryReference,
//     requirements: [], violationPatterns: [{ discrepancyType, anomalyType,
//     keywords, severity }], penalties }] } } }
// =========================================================================

const STATE_STATUTES = {

  // -----------------------------------------------------------------------
  // California
  // -----------------------------------------------------------------------
  CA: {
    stateCode: 'CA',
    stateName: 'California',
    statutes: {}
  },

  // -----------------------------------------------------------------------
  // New York
  // -----------------------------------------------------------------------
  NY: {
    stateCode: 'NY',
    stateName: 'New York',
    statutes: {}
  },

  // -----------------------------------------------------------------------
  // Texas
  // -----------------------------------------------------------------------
  TX: {
    stateCode: 'TX',
    stateName: 'Texas',
    statutes: {}
  },

  // -----------------------------------------------------------------------
  // Florida
  // -----------------------------------------------------------------------
  FL: {
    stateCode: 'FL',
    stateName: 'Florida',
    statutes: {}
  },

  // -----------------------------------------------------------------------
  // Illinois
  // -----------------------------------------------------------------------
  IL: {
    stateCode: 'IL',
    stateName: 'Illinois',
    statutes: {}
  },

  // -----------------------------------------------------------------------
  // Massachusetts
  // -----------------------------------------------------------------------
  MA: {
    stateCode: 'MA',
    stateName: 'Massachusetts',
    statutes: {}
  }
};

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/**
 * Get all statutes for a given state.
 *
 * @param {string} stateCode - 2-letter state code (e.g. 'CA')
 * @returns {Object|undefined} Object keyed by statute id, or undefined if state not found
 */
function getStateStatutes(stateCode) {
  const entry = STATE_STATUTES[stateCode];
  return entry ? entry.statutes : undefined;
}

/**
 * Look up a specific statute within a state by its identifier.
 *
 * @param {string} stateCode - 2-letter state code
 * @param {string} statuteId - Statute identifier (e.g. 'ca_hbor')
 * @returns {Object|undefined} The statute object, or undefined if not found
 */
function getStateStatuteById(stateCode, statuteId) {
  const statutes = getStateStatutes(stateCode);
  return statutes ? statutes[statuteId] : undefined;
}

/**
 * Look up a section by its identifier across all statutes within a state.
 *
 * @param {string} stateCode - 2-letter state code
 * @param {string} sectionId - Section identifier (e.g. 'ca_hbor_s2923_6')
 * @returns {Object|undefined} The section object, or undefined if not found
 */
function getStateSectionById(stateCode, sectionId) {
  const statutes = getStateStatutes(stateCode);
  if (!statutes) return undefined;

  for (const statute of Object.values(statutes)) {
    const section = statute.sections.find(s => s.id === sectionId);
    if (section) {
      return section;
    }
  }
  return undefined;
}

/**
 * Get all state codes that have statute data in the taxonomy.
 *
 * @returns {string[]} Array of 2-letter state codes
 */
function getSupportedStates() {
  return Object.keys(STATE_STATUTES);
}

/**
 * Get all statute identifiers for a given state.
 *
 * @param {string} stateCode - 2-letter state code
 * @returns {string[]} Array of statute id strings, or empty array if state not found
 */
function getStateStatuteIds(stateCode) {
  const statutes = getStateStatutes(stateCode);
  return statutes ? Object.keys(statutes) : [];
}

/**
 * Check whether a state code is present in the taxonomy.
 *
 * @param {string} stateCode - 2-letter state code
 * @returns {boolean} True if the state has an entry in STATE_STATUTES
 */
function isStateSupported(stateCode) {
  return stateCode in STATE_STATUTES;
}

module.exports = {
  STATE_STATUTES,
  getStateStatutes,
  getStateStatuteById,
  getStateSectionById,
  getSupportedStates,
  getStateStatuteIds,
  isStateSupported
};
