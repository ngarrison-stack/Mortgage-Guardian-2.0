/**
 * Document-Type-to-Statute Relevance Mapping
 *
 * Defines which federal statutes are most relevant for each document type/subtype
 * from the DOCUMENT_TAXONOMY. Enables the compliance engine to prioritize statute
 * evaluation based on the documents present in a case.
 *
 * Covers all 6 categories and 54 subtypes from documentFieldDefinitions.js.
 * Statute IDs and section IDs reference federalStatuteTaxonomy.js.
 *
 * This is config data — declarative, no business logic.
 */

// ---------------------------------------------------------------------------
// Default fallback for unknown document types
// ---------------------------------------------------------------------------
const DEFAULT_STATUTE_RELEVANCE = {
  primaryStatutes: ['respa', 'tila', 'cfpb_reg_x'],
  relevantSections: [],
  complianceFocus: ['general_compliance']
};

// ---------------------------------------------------------------------------
// DOCUMENT_STATUTE_RELEVANCE
// ---------------------------------------------------------------------------

const DOCUMENT_STATUTE_RELEVANCE = {

  // =========================================================================
  // ORIGINATION DOCUMENTS (12 subtypes)
  // =========================================================================
  origination: {

    loan_application_1003: {
      primaryStatutes: ['tila', 'ecoa', 'hmda'],
      relevantSections: ['tila_disclosure', 'ecoa_discrimination', 'ecoa_adverse_action', 'hmda_reporting'],
      complianceFocus: ['disclosure_accuracy', 'fair_lending', 'data_integrity']
    },

    good_faith_estimate: {
      primaryStatutes: ['respa', 'tila'],
      relevantSections: ['respa_s8', 'respa_s10', 'tila_disclosure'],
      complianceFocus: ['fee_accuracy', 'cost_disclosure', 'settlement_charges']
    },

    loan_estimate: {
      primaryStatutes: ['tila', 'respa'],
      relevantSections: ['tila_disclosure', 'respa_s8', 'respa_s10'],
      complianceFocus: ['apr_disclosure', 'fee_accuracy', 'cost_comparison']
    },

    truth_in_lending: {
      primaryStatutes: ['tila'],
      relevantSections: ['tila_disclosure', 'tila_rescission'],
      complianceFocus: ['apr_disclosure', 'finance_charge_accuracy', 'payment_disclosure']
    },

    promissory_note: {
      primaryStatutes: ['tila', 'scra'],
      relevantSections: ['tila_disclosure', 'tila_arm', 'scra_interest_cap'],
      complianceFocus: ['rate_accuracy', 'payment_terms', 'servicemember_protections']
    },

    deed_of_trust: {
      primaryStatutes: ['respa', 'tila'],
      relevantSections: ['respa_s8', 'tila_disclosure'],
      complianceFocus: ['security_instrument_accuracy', 'recording_compliance']
    },

    mortgage_deed: {
      primaryStatutes: ['respa', 'tila'],
      relevantSections: ['respa_s8', 'tila_disclosure'],
      complianceFocus: ['security_instrument_accuracy', 'recording_compliance']
    },

    hud1_settlement: {
      primaryStatutes: ['respa', 'tila'],
      relevantSections: ['respa_s8', 'respa_s10', 'tila_disclosure'],
      complianceFocus: ['fee_accuracy', 'settlement_charges', 'escrow_setup', 'kickback_detection']
    },

    closing_disclosure: {
      primaryStatutes: ['tila', 'respa'],
      relevantSections: ['tila_disclosure', 'respa_s8', 'respa_s10'],
      complianceFocus: ['fee_accuracy', 'escrow_setup', 'apr_disclosure', 'cash_to_close']
    },

    appraisal_report: {
      primaryStatutes: ['ecoa', 'hmda'],
      relevantSections: ['ecoa_adverse_action', 'hmda_accuracy'],
      complianceFocus: ['valuation_accuracy', 'appraisal_delivery', 'fair_lending']
    },

    title_insurance: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s8'],
      complianceFocus: ['fee_accuracy', 'affiliated_business_disclosure']
    },

    right_to_cancel: {
      primaryStatutes: ['tila'],
      relevantSections: ['tila_rescission'],
      complianceFocus: ['rescission_rights', 'notice_timing', 'cancellation_procedures']
    }
  },

  // =========================================================================
  // SERVICING DOCUMENTS (9 subtypes)
  // =========================================================================
  servicing: {

    monthly_statement: {
      primaryStatutes: ['respa', 'tila', 'cfpb_reg_x'],
      relevantSections: ['cfpb_early_intervention', 'tila_disclosure', 'respa_s10'],
      complianceFocus: ['payment_accuracy', 'escrow_analysis', 'fee_disclosure', 'statement_content']
    },

    escrow_analysis: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s10'],
      complianceFocus: ['escrow_accuracy', 'cushion_limits', 'surplus_refund', 'shortage_spread']
    },

    escrow_statement: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s10'],
      complianceFocus: ['escrow_accuracy', 'disbursement_verification', 'balance_reconciliation']
    },

    payment_history: {
      primaryStatutes: ['respa', 'cfpb_reg_x', 'tila'],
      relevantSections: ['cfpb_early_intervention', 'cfpb_error_resolution', 'respa_s10'],
      complianceFocus: ['payment_crediting', 'fee_assessment', 'application_order']
    },

    arm_adjustment_notice: {
      primaryStatutes: ['tila'],
      relevantSections: ['tila_arm', 'tila_disclosure'],
      complianceFocus: ['rate_change_notice', 'index_accuracy', 'payment_calculation']
    },

    tax_payment_record: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s10'],
      complianceFocus: ['escrow_disbursement', 'timely_payment', 'tax_accuracy']
    },

    insurance_payment_record: {
      primaryStatutes: ['respa', 'cfpb_reg_x'],
      relevantSections: ['respa_s10', 'cfpb_force_placed_insurance'],
      complianceFocus: ['escrow_disbursement', 'force_placed_detection', 'premium_accuracy']
    },

    payoff_statement: {
      primaryStatutes: ['respa', 'tila', 'fdcpa'],
      relevantSections: ['respa_s6', 'tila_disclosure', 'fdcpa_amount'],
      complianceFocus: ['balance_accuracy', 'fee_verification', 'per_diem_calculation']
    },

    annual_escrow_disclosure: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s10'],
      complianceFocus: ['escrow_accuracy', 'cushion_limits', 'disclosure_timing', 'shortage_options']
    }
  },

  // =========================================================================
  // CORRESPONDENCE (11 subtypes)
  // =========================================================================
  correspondence: {

    loss_mitigation_application: {
      primaryStatutes: ['cfpb_reg_x', 'respa'],
      relevantSections: ['cfpb_loss_mitigation', 'cfpb_dual_tracking', 'respa_s6'],
      complianceFocus: ['application_completeness', 'evaluation_timeline', 'dual_tracking_prevention']
    },

    forbearance_agreement: {
      primaryStatutes: ['cfpb_reg_x', 'respa', 'scra'],
      relevantSections: ['cfpb_loss_mitigation', 'respa_s6', 'scra_interest_cap'],
      complianceFocus: ['agreement_terms', 'payment_modification', 'servicemember_protections']
    },

    loan_modification: {
      primaryStatutes: ['cfpb_reg_x', 'tila', 'respa'],
      relevantSections: ['cfpb_loss_mitigation', 'tila_disclosure', 'respa_s6'],
      complianceFocus: ['modified_terms_disclosure', 'rate_accuracy', 'evaluation_timeline']
    },

    qualified_written_request: {
      primaryStatutes: ['respa', 'cfpb_reg_x'],
      relevantSections: ['respa_s6', 'cfpb_error_resolution'],
      complianceFocus: ['response_timeline', 'substantive_response', 'adverse_reporting_prohibition']
    },

    notice_of_error: {
      primaryStatutes: ['cfpb_reg_x', 'respa'],
      relevantSections: ['cfpb_error_resolution', 'respa_s6'],
      complianceFocus: ['error_acknowledgment', 'investigation_timeline', 'correction_requirements']
    },

    information_request: {
      primaryStatutes: ['respa', 'cfpb_reg_x'],
      relevantSections: ['respa_s6', 'cfpb_error_resolution'],
      complianceFocus: ['response_timeline', 'information_completeness']
    },

    collection_notice: {
      primaryStatutes: ['fdcpa', 'cfpb_reg_x'],
      relevantSections: ['fdcpa_validation', 'fdcpa_amount', 'fdcpa_practices'],
      complianceFocus: ['validation_notice', 'amount_accuracy', 'dispute_rights', 'communication_restrictions']
    },

    foreclosure_notice: {
      primaryStatutes: ['cfpb_reg_x', 'scra', 'fdcpa'],
      relevantSections: ['cfpb_dual_tracking', 'cfpb_loss_mitigation', 'scra_foreclosure', 'cfpb_early_intervention'],
      complianceFocus: ['dual_tracking_prevention', 'servicemember_protections', 'pre_foreclosure_requirements', 'loss_mitigation_rights']
    },

    default_notice: {
      primaryStatutes: ['cfpb_reg_x', 'fdcpa', 'scra'],
      relevantSections: ['cfpb_early_intervention', 'fdcpa_validation', 'fdcpa_practices', 'scra_foreclosure'],
      complianceFocus: ['early_intervention', 'notice_content', 'cure_rights', 'servicemember_protections']
    },

    acceleration_letter: {
      primaryStatutes: ['cfpb_reg_x', 'fdcpa', 'scra'],
      relevantSections: ['cfpb_dual_tracking', 'cfpb_loss_mitigation', 'fdcpa_amount', 'scra_foreclosure'],
      complianceFocus: ['acceleration_validity', 'amount_accuracy', 'loss_mitigation_rights', 'servicemember_protections']
    },

    general_correspondence: {
      primaryStatutes: ['respa', 'cfpb_reg_x'],
      relevantSections: ['respa_s6', 'cfpb_error_resolution'],
      complianceFocus: ['response_requirements', 'communication_compliance']
    }
  },

  // =========================================================================
  // LEGAL DOCUMENTS (10 subtypes)
  // =========================================================================
  legal: {

    assignment_of_mortgage: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s6', 'respa_s8'],
      complianceFocus: ['chain_of_title', 'transfer_notification', 'recording_accuracy']
    },

    substitution_of_trustee: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s6'],
      complianceFocus: ['authority_verification', 'notice_requirements']
    },

    notice_of_default: {
      primaryStatutes: ['cfpb_reg_x', 'scra', 'fdcpa'],
      relevantSections: ['cfpb_dual_tracking', 'cfpb_loss_mitigation', 'scra_foreclosure', 'fdcpa_validation'],
      complianceFocus: ['pre_foreclosure_compliance', 'servicemember_protections', 'loss_mitigation_rights']
    },

    lis_pendens: {
      primaryStatutes: ['cfpb_reg_x', 'scra'],
      relevantSections: ['cfpb_dual_tracking', 'scra_foreclosure'],
      complianceFocus: ['foreclosure_timing', 'dual_tracking_prevention', 'servicemember_protections']
    },

    court_judgment: {
      primaryStatutes: ['scra', 'fdcpa'],
      relevantSections: ['scra_foreclosure', 'fdcpa_amount'],
      complianceFocus: ['default_judgment_protections', 'amount_accuracy', 'military_affidavit']
    },

    court_order: {
      primaryStatutes: ['scra', 'cfpb_reg_x'],
      relevantSections: ['scra_foreclosure', 'cfpb_dual_tracking'],
      complianceFocus: ['court_compliance', 'servicemember_protections', 'stay_provisions']
    },

    bankruptcy_filing: {
      primaryStatutes: ['cfpb_reg_x', 'fdcpa'],
      relevantSections: ['cfpb_loss_mitigation', 'fdcpa_practices'],
      complianceFocus: ['automatic_stay_compliance', 'proof_of_claim_accuracy', 'communication_restrictions']
    },

    proof_of_claim: {
      primaryStatutes: ['fdcpa', 'respa'],
      relevantSections: ['fdcpa_amount', 'respa_s10'],
      complianceFocus: ['claim_amount_accuracy', 'fee_verification', 'escrow_accounting']
    },

    satisfaction_of_mortgage: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s6'],
      complianceFocus: ['timely_release', 'recording_compliance']
    },

    release_of_lien: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s6'],
      complianceFocus: ['timely_release', 'recording_compliance']
    }
  },

  // =========================================================================
  // FINANCIAL DOCUMENTS (6 subtypes)
  // =========================================================================
  financial: {

    bank_statement: {
      primaryStatutes: ['tila', 'respa'],
      relevantSections: ['tila_disclosure', 'respa_s10'],
      complianceFocus: ['payment_verification', 'escrow_reconciliation', 'fee_verification']
    },

    tax_return: {
      primaryStatutes: ['ecoa', 'hmda'],
      relevantSections: ['ecoa_discrimination', 'hmda_reporting'],
      complianceFocus: ['income_verification', 'fair_lending', 'underwriting_accuracy']
    },

    income_verification: {
      primaryStatutes: ['ecoa', 'hmda'],
      relevantSections: ['ecoa_discrimination', 'hmda_reporting'],
      complianceFocus: ['income_accuracy', 'fair_lending', 'ability_to_repay']
    },

    credit_report: {
      primaryStatutes: ['ecoa', 'hmda', 'cfpb_reg_x'],
      relevantSections: ['ecoa_adverse_action', 'ecoa_discrimination', 'hmda_reporting'],
      complianceFocus: ['fair_lending', 'adverse_action_basis', 'accurate_reporting']
    },

    profit_loss_statement: {
      primaryStatutes: ['ecoa', 'tila'],
      relevantSections: ['ecoa_discrimination', 'tila_disclosure'],
      complianceFocus: ['income_verification', 'ability_to_repay', 'underwriting_accuracy']
    },

    asset_verification: {
      primaryStatutes: ['ecoa', 'tila'],
      relevantSections: ['ecoa_discrimination', 'tila_disclosure'],
      complianceFocus: ['asset_verification', 'reserves_accuracy', 'underwriting_compliance']
    }
  },

  // =========================================================================
  // REGULATORY NOTICES (6 subtypes)
  // =========================================================================
  regulatory: {

    respa_disclosure: {
      primaryStatutes: ['respa'],
      relevantSections: ['respa_s6', 'respa_s8', 'respa_s10'],
      complianceFocus: ['disclosure_content', 'transfer_notification', 'required_language']
    },

    tila_disclosure: {
      primaryStatutes: ['tila'],
      relevantSections: ['tila_disclosure', 'tila_rescission'],
      complianceFocus: ['apr_accuracy', 'finance_charge_accuracy', 'disclosure_timing']
    },

    ecoa_notice: {
      primaryStatutes: ['ecoa'],
      relevantSections: ['ecoa_adverse_action', 'ecoa_discrimination'],
      complianceFocus: ['adverse_action_compliance', 'reason_specificity', 'anti_discrimination_notice']
    },

    fdcpa_notice: {
      primaryStatutes: ['fdcpa'],
      relevantSections: ['fdcpa_validation', 'fdcpa_amount', 'fdcpa_practices'],
      complianceFocus: ['validation_notice_content', 'amount_accuracy', 'dispute_rights']
    },

    scra_notice: {
      primaryStatutes: ['scra'],
      relevantSections: ['scra_interest_cap', 'scra_foreclosure'],
      complianceFocus: ['rate_cap_compliance', 'protection_notification', 'servicemember_rights']
    },

    state_regulatory_notice: {
      primaryStatutes: ['cfpb_reg_x', 'respa'],
      relevantSections: ['cfpb_error_resolution', 'respa_s6'],
      complianceFocus: ['state_compliance', 'response_requirements', 'regulatory_coordination']
    }
  }
};

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/**
 * Get the relevant federal statutes for a document category/subtype.
 *
 * Gracefully returns default statutes for unknown types.
 *
 * @param {string} category - Document category (e.g. 'servicing', 'origination')
 * @param {string} subtype - Document subtype (e.g. 'monthly_statement')
 * @returns {string[]} Array of statute IDs relevant to this document type
 */
function getRelevantStatutes(category, subtype) {
  const cat = DOCUMENT_STATUTE_RELEVANCE[category];
  if (!cat) {
    return DEFAULT_STATUTE_RELEVANCE.primaryStatutes;
  }
  const entry = cat[subtype];
  if (!entry) {
    return DEFAULT_STATUTE_RELEVANCE.primaryStatutes;
  }
  return entry.primaryStatutes;
}

/**
 * Get the relevant statute sections for a document category/subtype.
 *
 * Gracefully returns empty array for unknown types.
 *
 * @param {string} category - Document category
 * @param {string} subtype - Document subtype
 * @returns {string[]} Array of section IDs to prioritize during analysis
 */
function getRelevantSections(category, subtype) {
  const cat = DOCUMENT_STATUTE_RELEVANCE[category];
  if (!cat) {
    return DEFAULT_STATUTE_RELEVANCE.relevantSections;
  }
  const entry = cat[subtype];
  if (!entry) {
    return DEFAULT_STATUTE_RELEVANCE.relevantSections;
  }
  return entry.relevantSections;
}

/**
 * Get the compliance focus areas for a document category/subtype.
 *
 * Gracefully returns general compliance focus for unknown types.
 *
 * @param {string} category - Document category
 * @param {string} subtype - Document subtype
 * @returns {string[]} Array of focus area strings for compliance analysis
 */
function getComplianceFocus(category, subtype) {
  const cat = DOCUMENT_STATUTE_RELEVANCE[category];
  if (!cat) {
    return DEFAULT_STATUTE_RELEVANCE.complianceFocus;
  }
  const entry = cat[subtype];
  if (!entry) {
    return DEFAULT_STATUTE_RELEVANCE.complianceFocus;
  }
  return entry.complianceFocus;
}

module.exports = {
  DOCUMENT_STATUTE_RELEVANCE,
  DEFAULT_STATUTE_RELEVANCE,
  getRelevantStatutes,
  getRelevantSections,
  getComplianceFocus
};
