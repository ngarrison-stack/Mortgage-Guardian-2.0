/**
 * Cross-Document Comparison Configuration
 *
 * Defines which document types should be compared in cross-document forensic
 * analysis, what fields to compare, and which discrepancy types are relevant.
 *
 * This configuration drives the comparison engine's behavior — it determines
 * which document pairs are evaluated and how discrepancies are classified.
 *
 * Used by: cross-document analysis orchestrator, comparison engine, severity
 * assessment, and forensic report generation.
 */

// ---------------------------------------------------------------------------
// Comparison Pairs
//
// Each pair defines a relationship between two document types/subtypes and
// specifies what to compare and what to look for. The comparison engine
// iterates over these pairs for each case's documents.
// ---------------------------------------------------------------------------

const COMPARISON_PAIRS = [
  {
    id: 'stmt-vs-stmt',
    docTypeA: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    docTypeB: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    bidirectional: false,
    comparisonFields: ['amounts', 'dates', 'rates'],
    discrepancyTypes: ['amount_mismatch', 'calculation_error', 'fee_irregularity', 'date_inconsistency'],
    description: 'Compare sequential monthly statements to detect balance calculation errors, unexplained fee increases, and payment amount changes without modification notice.',
    forensicSignificance: 'high'
  },

  {
    id: 'stmt-vs-closing',
    docTypeA: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    docTypeB: { classificationType: 'origination', classificationSubtype: 'closing_disclosure' },
    bidirectional: true,
    comparisonFields: ['rates', 'amounts'],
    discrepancyTypes: ['amount_mismatch', 'term_contradiction', 'calculation_error'],
    description: 'Compare current servicing terms against original closing disclosure to detect rate changes without ARM adjustment and payment discrepancies versus original loan terms.',
    forensicSignificance: 'high'
  },

  {
    id: 'stmt-vs-paymenthistory',
    docTypeA: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    docTypeB: { classificationType: 'servicing', classificationSubtype: 'payment_history' },
    bidirectional: true,
    comparisonFields: ['amounts', 'dates'],
    discrepancyTypes: ['amount_mismatch', 'date_inconsistency', 'fee_irregularity'],
    description: 'Cross-reference monthly statements with payment history to detect misapplied payments and phantom late fees.',
    forensicSignificance: 'high'
  },

  {
    id: 'stmt-vs-escrow',
    docTypeA: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    docTypeB: { classificationType: 'servicing', classificationSubtype: 'escrow_analysis' },
    bidirectional: true,
    comparisonFields: ['amounts'],
    discrepancyTypes: ['amount_mismatch', 'calculation_error'],
    description: 'Compare statement escrow balances against escrow analysis to detect escrow shortage miscalculation and improper escrow accounting.',
    forensicSignificance: 'medium'
  },

  {
    id: 'stmt-vs-modification',
    docTypeA: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    docTypeB: { classificationType: 'correspondence', classificationSubtype: 'loan_modification' },
    bidirectional: true,
    comparisonFields: ['amounts', 'rates'],
    discrepancyTypes: ['amount_mismatch', 'term_contradiction', 'timeline_violation'],
    description: 'Verify that loan modification terms are correctly applied in subsequent statements — catches continued collection at old payment amounts.',
    forensicSignificance: 'high'
  },

  {
    id: 'closing-vs-note',
    docTypeA: { classificationType: 'origination', classificationSubtype: 'closing_disclosure' },
    docTypeB: { classificationType: 'origination', classificationSubtype: 'promissory_note' },
    bidirectional: true,
    comparisonFields: ['amounts', 'rates', 'terms'],
    discrepancyTypes: ['amount_mismatch', 'term_contradiction'],
    description: 'Compare closing disclosure against promissory note to detect inconsistent loan terms between origination documents.',
    forensicSignificance: 'high'
  },

  {
    id: 'stmt-vs-armadjust',
    docTypeA: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    docTypeB: { classificationType: 'servicing', classificationSubtype: 'arm_adjustment_notice' },
    bidirectional: true,
    comparisonFields: ['rates', 'dates', 'amounts'],
    discrepancyTypes: ['amount_mismatch', 'date_inconsistency', 'term_contradiction'],
    description: 'Verify that ARM rate adjustments announced in notices are correctly reflected in subsequent statements.',
    forensicSignificance: 'medium'
  },

  {
    id: 'correspondence-vs-stmt',
    docTypeA: { classificationType: 'correspondence', classificationSubtype: '*' },
    docTypeB: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    bidirectional: true,
    comparisonFields: ['amounts', 'dates', 'identifiers'],
    discrepancyTypes: ['amount_mismatch', 'date_inconsistency', 'missing_correspondence', 'timeline_violation'],
    description: 'Compare servicer correspondence claims against actual statement records to detect inconsistencies between stated and actual account status.',
    forensicSignificance: 'medium'
  },

  {
    id: 'legal-vs-stmt',
    docTypeA: { classificationType: 'legal', classificationSubtype: '*' },
    docTypeB: { classificationType: 'servicing', classificationSubtype: 'monthly_statement' },
    bidirectional: true,
    comparisonFields: ['amounts', 'dates'],
    discrepancyTypes: ['amount_mismatch', 'date_inconsistency', 'timeline_violation', 'calculation_error'],
    description: 'Cross-reference legal filings with servicing records to verify foreclosure amounts and default amount accuracy.',
    forensicSignificance: 'high'
  }
];

// ---------------------------------------------------------------------------
// Discrepancy Severity Rules
//
// Maps each discrepancy type to a default severity and provides field-based
// elevation rules. The comparison engine uses these to assign appropriate
// severity when a discrepancy is detected.
//
// Elevation rules reference field tiers from documentFieldDefinitions.js:
//   critical tier fields → elevate severity
//   payment-related dates → elevate date discrepancies
//   regulatory deadlines → elevate timeline violations
// ---------------------------------------------------------------------------

const DISCREPANCY_SEVERITY_RULES = {
  amount_mismatch: {
    defaultSeverity: 'high',
    elevationRules: [
      {
        condition: 'field_in_critical_tier',
        elevatedSeverity: 'critical',
        description: 'Elevate to critical when mismatched field is in the critical tier (e.g. principalBalance, monthlyPayment, loanAmount)'
      }
    ]
  },

  date_inconsistency: {
    defaultSeverity: 'medium',
    elevationRules: [
      {
        condition: 'involves_payment_dates',
        elevatedSeverity: 'high',
        description: 'Elevate to high when discrepancy involves payment due dates, statement dates, or effective dates'
      }
    ]
  },

  party_mismatch: {
    defaultSeverity: 'medium',
    elevationRules: []
  },

  term_contradiction: {
    defaultSeverity: 'high',
    elevationRules: []
  },

  timeline_violation: {
    defaultSeverity: 'high',
    elevationRules: [
      {
        condition: 'regulatory_deadline_involved',
        elevatedSeverity: 'critical',
        description: 'Elevate to critical when a regulatory deadline is involved (e.g. RESPA response deadlines, foreclosure notice periods)'
      }
    ]
  },

  calculation_error: {
    defaultSeverity: 'critical',
    elevationRules: []
  },

  missing_correspondence: {
    defaultSeverity: 'medium',
    elevationRules: []
  },

  fee_irregularity: {
    defaultSeverity: 'high',
    elevationRules: []
  }
};

// ---------------------------------------------------------------------------
// Helper Functions
// ---------------------------------------------------------------------------

/**
 * Check if a document type/subtype matches a comparison pair's type spec.
 *
 * Supports wildcard matching: a spec with classificationSubtype "*" matches
 * any subtype within the given classificationType.
 *
 * @param {string} classificationType - Document classification type
 * @param {string} classificationSubtype - Document classification subtype
 * @param {{ classificationType: string, classificationSubtype: string }} spec - Pair type spec
 * @returns {boolean}
 */
function matchesTypeSpec(classificationType, classificationSubtype, spec) {
  if (spec.classificationType !== classificationType) {
    return false;
  }
  if (spec.classificationSubtype === '*') {
    return true;
  }
  return spec.classificationSubtype === classificationSubtype;
}

/**
 * Get all comparison pairs that apply to a given pair of document types.
 *
 * Handles bidirectional matching: if a pair is marked bidirectional and defines
 * A=servicing/monthly_statement, B=origination/closing_disclosure, it will
 * match when called with those types in either order.
 *
 * Also handles wildcard subtypes: a pair with classificationSubtype "*"
 * matches any subtype within that classificationType.
 *
 * @param {string} typeA - Classification type of first document
 * @param {string} subtypeA - Classification subtype of first document
 * @param {string} typeB - Classification type of second document
 * @param {string} subtypeB - Classification subtype of second document
 * @returns {Array} Matching comparison pair configurations
 */
function getComparisonPairsForDocTypes(typeA, subtypeA, typeB, subtypeB) {
  return COMPARISON_PAIRS.filter(pair => {
    // Forward match: A matches docTypeA and B matches docTypeB
    const forwardMatch =
      matchesTypeSpec(typeA, subtypeA, pair.docTypeA) &&
      matchesTypeSpec(typeB, subtypeB, pair.docTypeB);

    if (forwardMatch) {
      return true;
    }

    // Reverse match (only for bidirectional pairs): A matches docTypeB and B matches docTypeA
    if (pair.bidirectional) {
      const reverseMatch =
        matchesTypeSpec(typeA, subtypeA, pair.docTypeB) &&
        matchesTypeSpec(typeB, subtypeB, pair.docTypeA);

      if (reverseMatch) {
        return true;
      }
    }

    return false;
  });
}

module.exports = {
  COMPARISON_PAIRS,
  DISCREPANCY_SEVERITY_RULES,
  getComparisonPairsForDocTypes
};
