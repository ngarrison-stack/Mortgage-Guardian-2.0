/**
 * State Document-Type-to-Statute Relevance Mapping
 *
 * Defines which state statutes are most relevant for each document type/subtype.
 * Mirrors the structure of the federal documentStatuteRelevance.js so the
 * compliance engine can prioritize state statute evaluation based on document type.
 *
 * Covers 6 priority states (CA, NY, TX, FL, IL, MA) with 10-15 document subtypes
 * per state, focusing on subtypes where state law adds material requirements
 * beyond federal (servicing, escrow, foreclosure, correspondence).
 *
 * Statute IDs and section IDs reference stateStatuteTaxonomy.js.
 *
 * This is config data — declarative, no business logic.
 */

// ---------------------------------------------------------------------------
// Default fallback for states/subtypes without specific mapping
// ---------------------------------------------------------------------------
const DEFAULT_STATE_RELEVANCE = {
  primaryStatutes: [],
  relevantSections: [],
  complianceFocus: ['general_state_compliance']
};

// ---------------------------------------------------------------------------
// STATE_DOCUMENT_STATUTE_RELEVANCE — keyed by 2-letter state code
// ---------------------------------------------------------------------------

const STATE_DOCUMENT_STATUTE_RELEVANCE = {

  // =========================================================================
  // CALIFORNIA
  // =========================================================================
  CA: {
    servicing: {
      monthly_statement: {
        primaryStatutes: ['ca_civ', 'ca_hbor'],
        relevantSections: ['ca_civ_escrow_accounts', 'ca_hbor_single_poc'],
        complianceFocus: ['escrow_accuracy', 'impound_limits', 'contact_information']
      },
      escrow_analysis: {
        primaryStatutes: ['ca_civ'],
        relevantSections: ['ca_civ_escrow_accounts'],
        complianceFocus: ['impound_limits', 'surplus_refund', 'escrow_accounting']
      },
      escrow_statement: {
        primaryStatutes: ['ca_civ'],
        relevantSections: ['ca_civ_escrow_accounts'],
        complianceFocus: ['impound_accuracy', 'disbursement_verification']
      },
      payment_history: {
        primaryStatutes: ['ca_civ', 'ca_rosenthal'],
        relevantSections: ['ca_civ_escrow_accounts', 'ca_rosenthal_unfair_practices'],
        complianceFocus: ['payment_crediting', 'fee_assessment', 'collection_practices']
      },
      payoff_statement: {
        primaryStatutes: ['ca_civ'],
        relevantSections: ['ca_civ_payoff_demand'],
        complianceFocus: ['payoff_accuracy', 'timely_delivery', 'fee_verification']
      }
    },
    correspondence: {
      loss_mitigation_application: {
        primaryStatutes: ['ca_hbor'],
        relevantSections: ['ca_hbor_dual_tracking', 'ca_hbor_single_poc', 'ca_hbor_complete_application'],
        complianceFocus: ['dual_tracking_prevention', 'spoc_assignment', 'application_completeness']
      },
      foreclosure_notice: {
        primaryStatutes: ['ca_hbor', 'ca_civ'],
        relevantSections: ['ca_hbor_notice_of_default', 'ca_hbor_dual_tracking', 'ca_civ_transfer_disclosure'],
        complianceFocus: ['pre_foreclosure_contact', 'dual_tracking_prevention', 'notice_requirements']
      },
      default_notice: {
        primaryStatutes: ['ca_hbor'],
        relevantSections: ['ca_hbor_notice_of_default', 'ca_hbor_single_poc'],
        complianceFocus: ['borrower_contact_requirement', 'notice_content', 'spoc_availability']
      },
      collection_notice: {
        primaryStatutes: ['ca_rosenthal'],
        relevantSections: ['ca_rosenthal_prohibited_practices', 'ca_rosenthal_validation', 'ca_rosenthal_original_creditor'],
        complianceFocus: ['validation_notice', 'prohibited_practices', 'original_creditor_coverage']
      },
      loan_modification: {
        primaryStatutes: ['ca_hbor'],
        relevantSections: ['ca_hbor_dual_tracking', 'ca_hbor_single_poc', 'ca_hbor_complete_application'],
        complianceFocus: ['modification_evaluation', 'dual_tracking_prevention', 'spoc_continuity']
      }
    },
    legal: {
      notice_of_default: {
        primaryStatutes: ['ca_hbor', 'ca_civ'],
        relevantSections: ['ca_hbor_notice_of_default', 'ca_hbor_dual_tracking'],
        complianceFocus: ['pre_foreclosure_contact', 'nod_validity', 'dual_tracking']
      }
    },
    origination: {
      closing_disclosure: {
        primaryStatutes: ['ca_rmla', 'ca_civ'],
        relevantSections: ['ca_rmla_licensing', 'ca_civ_escrow_accounts'],
        complianceFocus: ['licensing_compliance', 'escrow_setup', 'fee_disclosure']
      },
      good_faith_estimate: {
        primaryStatutes: ['ca_rmla'],
        relevantSections: ['ca_rmla_licensing', 'ca_rmla_trust_funds'],
        complianceFocus: ['fee_accuracy', 'trust_fund_handling']
      }
    }
  },

  // =========================================================================
  // NEW YORK
  // =========================================================================
  NY: {
    servicing: {
      monthly_statement: {
        primaryStatutes: ['ny_banking'],
        relevantSections: ['ny_banking_servicer_obligations', 'ny_banking_escrow'],
        complianceFocus: ['servicer_obligations', 'escrow_interest', 'fee_limits']
      },
      escrow_analysis: {
        primaryStatutes: ['ny_banking'],
        relevantSections: ['ny_banking_escrow'],
        complianceFocus: ['escrow_interest_payment', 'escrow_limits', 'annual_accounting']
      },
      escrow_statement: {
        primaryStatutes: ['ny_banking'],
        relevantSections: ['ny_banking_escrow'],
        complianceFocus: ['interest_on_escrow', 'balance_accuracy']
      },
      payment_history: {
        primaryStatutes: ['ny_banking', 'ny_gbl'],
        relevantSections: ['ny_banking_servicer_obligations', 'ny_gbl_deceptive_acts'],
        complianceFocus: ['payment_crediting', 'fee_assessment', 'deceptive_practices']
      },
      payoff_statement: {
        primaryStatutes: ['ny_banking'],
        relevantSections: ['ny_banking_servicer_obligations'],
        complianceFocus: ['balance_accuracy', 'fee_verification']
      }
    },
    correspondence: {
      loss_mitigation_application: {
        primaryStatutes: ['ny_banking', 'ny_rpapl'],
        relevantSections: ['ny_banking_loss_mitigation', 'ny_rpapl_settlement_conference'],
        complianceFocus: ['loss_mitigation_evaluation', 'settlement_conference_compliance']
      },
      foreclosure_notice: {
        primaryStatutes: ['ny_rpapl'],
        relevantSections: ['ny_rpapl_notice_requirements', 'ny_rpapl_settlement_conference', 'ny_rpapl_standing'],
        complianceFocus: ['90_day_notice', 'settlement_conference', 'standing_requirements']
      },
      default_notice: {
        primaryStatutes: ['ny_rpapl', 'ny_banking'],
        relevantSections: ['ny_rpapl_notice_requirements', 'ny_banking_servicer_obligations'],
        complianceFocus: ['pre_foreclosure_notice', 'borrower_rights', 'counseling_information']
      },
      collection_notice: {
        primaryStatutes: ['ny_gbl'],
        relevantSections: ['ny_gbl_deceptive_acts', 'ny_gbl_false_advertising'],
        complianceFocus: ['deceptive_practices', 'false_representations', 'consumer_rights']
      },
      loan_modification: {
        primaryStatutes: ['ny_banking'],
        relevantSections: ['ny_banking_loss_mitigation', 'ny_banking_servicer_obligations'],
        complianceFocus: ['modification_evaluation', 'good_faith_negotiation']
      }
    },
    legal: {
      notice_of_default: {
        primaryStatutes: ['ny_rpapl'],
        relevantSections: ['ny_rpapl_notice_requirements', 'ny_rpapl_standing'],
        complianceFocus: ['90_day_notice', 'standing_requirements']
      },
      lis_pendens: {
        primaryStatutes: ['ny_rpapl'],
        relevantSections: ['ny_rpapl_standing', 'ny_rpapl_settlement_conference'],
        complianceFocus: ['standing_verification', 'conference_scheduling']
      }
    },
    origination: {
      closing_disclosure: {
        primaryStatutes: ['ny_banking'],
        relevantSections: ['ny_banking_registration', 'ny_banking_escrow'],
        complianceFocus: ['servicer_registration', 'escrow_setup']
      }
    }
  },

  // =========================================================================
  // TEXAS
  // =========================================================================
  TX: {
    servicing: {
      monthly_statement: {
        primaryStatutes: ['tx_fin'],
        relevantSections: ['tx_fin_payment_processing', 'tx_fin_escrow_requirements'],
        complianceFocus: ['payment_processing', 'escrow_accuracy']
      },
      escrow_analysis: {
        primaryStatutes: ['tx_fin'],
        relevantSections: ['tx_fin_escrow_requirements'],
        complianceFocus: ['escrow_limits', 'accounting_accuracy']
      },
      escrow_statement: {
        primaryStatutes: ['tx_fin'],
        relevantSections: ['tx_fin_escrow_requirements'],
        complianceFocus: ['escrow_accounting', 'disbursement_accuracy']
      },
      payment_history: {
        primaryStatutes: ['tx_fin'],
        relevantSections: ['tx_fin_payment_processing', 'tx_fin_books_records'],
        complianceFocus: ['payment_crediting', 'record_keeping']
      },
      payoff_statement: {
        primaryStatutes: ['tx_fin'],
        relevantSections: ['tx_fin_payment_processing'],
        complianceFocus: ['balance_accuracy', 'fee_verification']
      }
    },
    correspondence: {
      foreclosure_notice: {
        primaryStatutes: ['tx_prop'],
        relevantSections: ['tx_prop_foreclosure_notice', 'tx_prop_acceleration'],
        complianceFocus: ['21_day_notice', 'acceleration_notice', 'cure_period']
      },
      default_notice: {
        primaryStatutes: ['tx_prop'],
        relevantSections: ['tx_prop_acceleration', 'tx_prop_foreclosure_notice'],
        complianceFocus: ['20_day_cure_notice', 'acceleration_requirements']
      },
      collection_notice: {
        primaryStatutes: ['tx_debt'],
        relevantSections: ['tx_debt_false_representation', 'tx_debt_threats', 'tx_debt_harassment'],
        complianceFocus: ['false_representation', 'prohibited_threats', 'harassment_prevention']
      },
      loss_mitigation_application: {
        primaryStatutes: ['tx_prop', 'tx_fin'],
        relevantSections: ['tx_prop_acceleration', 'tx_fin_payment_processing'],
        complianceFocus: ['cure_period_compliance', 'loss_mitigation_review']
      },
      loan_modification: {
        primaryStatutes: ['tx_fin'],
        relevantSections: ['tx_fin_payment_processing', 'tx_fin_books_records'],
        complianceFocus: ['modified_terms_accuracy', 'record_keeping']
      }
    },
    legal: {
      notice_of_default: {
        primaryStatutes: ['tx_prop'],
        relevantSections: ['tx_prop_acceleration', 'tx_prop_foreclosure_notice'],
        complianceFocus: ['cure_notice', 'acceleration_validity']
      }
    },
    origination: {
      closing_disclosure: {
        primaryStatutes: ['tx_fin'],
        relevantSections: ['tx_fin_licensing', 'tx_fin_escrow_requirements'],
        complianceFocus: ['licensing_compliance', 'escrow_setup']
      }
    }
  },

  // =========================================================================
  // FLORIDA
  // =========================================================================
  FL: {
    servicing: {
      monthly_statement: {
        primaryStatutes: ['fl_mla'],
        relevantSections: ['fl_mla_disclosures'],
        complianceFocus: ['disclosure_accuracy', 'fee_transparency']
      },
      escrow_analysis: {
        primaryStatutes: ['fl_mla'],
        relevantSections: ['fl_mla_disclosures'],
        complianceFocus: ['escrow_accounting', 'disclosure_requirements']
      },
      payment_history: {
        primaryStatutes: ['fl_mla', 'fl_ccpa'],
        relevantSections: ['fl_mla_prohibited_practices', 'fl_ccpa_prohibited_practices'],
        complianceFocus: ['payment_crediting', 'prohibited_practices']
      },
      payoff_statement: {
        primaryStatutes: ['fl_mla'],
        relevantSections: ['fl_mla_disclosures'],
        complianceFocus: ['balance_accuracy', 'fee_verification']
      }
    },
    correspondence: {
      foreclosure_notice: {
        primaryStatutes: ['fl_foreclosure'],
        relevantSections: ['fl_foreclosure_complaint', 'fl_foreclosure_mediation', 'fl_lis_pendens', 'fl_foreclosure_service'],
        complianceFocus: ['complaint_verification', 'mediation_requirements', 'service_requirements']
      },
      default_notice: {
        primaryStatutes: ['fl_foreclosure', 'fl_ccpa'],
        relevantSections: ['fl_foreclosure_complaint', 'fl_ccpa_prohibited_practices'],
        complianceFocus: ['pre_suit_notice', 'consumer_protection']
      },
      collection_notice: {
        primaryStatutes: ['fl_ccpa'],
        relevantSections: ['fl_ccpa_prohibited_practices', 'fl_ccpa_harassment', 'fl_ccpa_misrepresentation'],
        complianceFocus: ['prohibited_practices', 'harassment_prevention', 'truthful_representation']
      },
      loss_mitigation_application: {
        primaryStatutes: ['fl_foreclosure', 'fl_mla'],
        relevantSections: ['fl_foreclosure_mediation', 'fl_foreclosure_complaint'],
        complianceFocus: ['mediation_compliance', 'loss_mitigation_certification']
      },
      loan_modification: {
        primaryStatutes: ['fl_mla'],
        relevantSections: ['fl_mla_disclosures', 'fl_mla_prohibited_practices'],
        complianceFocus: ['modified_terms_disclosure', 'prohibited_practices']
      }
    },
    legal: {
      notice_of_default: {
        primaryStatutes: ['fl_foreclosure'],
        relevantSections: ['fl_foreclosure_complaint', 'fl_lis_pendens'],
        complianceFocus: ['complaint_requirements', 'lis_pendens_validity']
      },
      lis_pendens: {
        primaryStatutes: ['fl_foreclosure'],
        relevantSections: ['fl_lis_pendens', 'fl_foreclosure_service'],
        complianceFocus: ['lis_pendens_requirements', 'proper_service']
      }
    },
    origination: {
      closing_disclosure: {
        primaryStatutes: ['fl_mla'],
        relevantSections: ['fl_mla_licensing', 'fl_mla_disclosures'],
        complianceFocus: ['licensing_compliance', 'fee_disclosure']
      }
    }
  },

  // =========================================================================
  // ILLINOIS
  // =========================================================================
  IL: {
    servicing: {
      monthly_statement: {
        primaryStatutes: ['il_rmla'],
        relevantSections: ['il_rmla_disclosures'],
        complianceFocus: ['disclosure_accuracy', 'fee_transparency']
      },
      escrow_analysis: {
        primaryStatutes: ['il_rmla'],
        relevantSections: ['il_rmla_disclosures'],
        complianceFocus: ['escrow_accounting', 'disclosure_requirements']
      },
      payment_history: {
        primaryStatutes: ['il_rmla', 'il_cfa'],
        relevantSections: ['il_rmla_prohibited', 'il_cfa_deceptive_mortgage'],
        complianceFocus: ['payment_crediting', 'deceptive_practices']
      },
      payoff_statement: {
        primaryStatutes: ['il_rmla'],
        relevantSections: ['il_rmla_disclosures'],
        complianceFocus: ['balance_accuracy', 'fee_verification']
      }
    },
    correspondence: {
      foreclosure_notice: {
        primaryStatutes: ['il_foreclosure'],
        relevantSections: ['il_foreclosure_notice', 'il_foreclosure_judicial', 'il_foreclosure_loss_mitigation'],
        complianceFocus: ['grace_period_notice', 'judicial_process', 'loss_mitigation_evaluation']
      },
      default_notice: {
        primaryStatutes: ['il_foreclosure'],
        relevantSections: ['il_foreclosure_notice', 'il_foreclosure_reinstatement'],
        complianceFocus: ['grace_period_notice', 'reinstatement_rights', 'counseling_information']
      },
      collection_notice: {
        primaryStatutes: ['il_cfa'],
        relevantSections: ['il_cfa_unfair_collection', 'il_cfa_consumer_protection', 'il_cfa_deceptive_mortgage'],
        complianceFocus: ['unfair_collection', 'consumer_protection', 'deceptive_practices']
      },
      loss_mitigation_application: {
        primaryStatutes: ['il_foreclosure'],
        relevantSections: ['il_foreclosure_loss_mitigation', 'il_foreclosure_notice'],
        complianceFocus: ['loss_mitigation_evaluation', 'pre_foreclosure_compliance']
      },
      loan_modification: {
        primaryStatutes: ['il_foreclosure', 'il_rmla'],
        relevantSections: ['il_foreclosure_loss_mitigation', 'il_rmla_disclosures'],
        complianceFocus: ['modification_evaluation', 'disclosure_requirements']
      }
    },
    legal: {
      notice_of_default: {
        primaryStatutes: ['il_foreclosure'],
        relevantSections: ['il_foreclosure_notice', 'il_foreclosure_reinstatement'],
        complianceFocus: ['grace_period_compliance', 'reinstatement_information']
      }
    },
    origination: {
      closing_disclosure: {
        primaryStatutes: ['il_rmla'],
        relevantSections: ['il_rmla_licensing', 'il_rmla_disclosures'],
        complianceFocus: ['licensing_compliance', 'fee_disclosure']
      }
    }
  },

  // =========================================================================
  // MASSACHUSETTS
  // =========================================================================
  MA: {
    servicing: {
      monthly_statement: {
        primaryStatutes: ['ma_ch183c'],
        relevantSections: ['ma_ch183c_fee_limits', 'ma_ch183c_disclosures'],
        complianceFocus: ['fee_limits', 'late_fee_compliance', 'disclosure_accuracy']
      },
      escrow_analysis: {
        primaryStatutes: ['ma_ch183c'],
        relevantSections: ['ma_ch183c_fee_limits'],
        complianceFocus: ['escrow_accuracy', 'fee_compliance']
      },
      payment_history: {
        primaryStatutes: ['ma_ch183c', 'ma_93a'],
        relevantSections: ['ma_ch183c_fee_limits', 'ma_93a_unfair_practices'],
        complianceFocus: ['payment_crediting', 'late_fee_limits', 'unfair_practices']
      },
      payoff_statement: {
        primaryStatutes: ['ma_ch183c'],
        relevantSections: ['ma_ch183c_fee_limits'],
        complianceFocus: ['balance_accuracy', 'fee_compliance']
      }
    },
    correspondence: {
      foreclosure_notice: {
        primaryStatutes: ['ma_rtc'],
        relevantSections: ['ma_rtc_150_day_notice', 'ma_rtc_notice_requirements', 'ma_rtc_cure_protections'],
        complianceFocus: ['150_day_notice', 'notice_requirements', 'cure_protections']
      },
      default_notice: {
        primaryStatutes: ['ma_rtc'],
        relevantSections: ['ma_rtc_150_day_notice', 'ma_rtc_cure_protections'],
        complianceFocus: ['right_to_cure', 'notice_content', 'cure_period']
      },
      collection_notice: {
        primaryStatutes: ['ma_93a'],
        relevantSections: ['ma_93a_unfair_practices', 'ma_93a_treble_damages'],
        complianceFocus: ['unfair_practices', 'deceptive_acts', 'consumer_rights']
      },
      loss_mitigation_application: {
        primaryStatutes: ['ma_rtc', 'ma_ch183c'],
        relevantSections: ['ma_rtc_cure_protections', 'ma_ch183c_disclosures'],
        complianceFocus: ['cure_protections', 'loss_mitigation_evaluation']
      },
      loan_modification: {
        primaryStatutes: ['ma_ch183c'],
        relevantSections: ['ma_ch183c_prohibited_terms', 'ma_ch183c_disclosures', 'ma_ch183c_flipping'],
        complianceFocus: ['prohibited_terms', 'disclosure_requirements', 'anti_flipping']
      }
    },
    legal: {
      notice_of_default: {
        primaryStatutes: ['ma_rtc'],
        relevantSections: ['ma_rtc_150_day_notice', 'ma_rtc_notice_requirements'],
        complianceFocus: ['150_day_notice', 'proper_service']
      }
    },
    origination: {
      closing_disclosure: {
        primaryStatutes: ['ma_ch183c'],
        relevantSections: ['ma_ch183c_prohibited_terms', 'ma_ch183c_disclosures', 'ma_ch183c_fee_limits'],
        complianceFocus: ['prohibited_terms', 'fee_limits', 'disclosure_compliance']
      },
      good_faith_estimate: {
        primaryStatutes: ['ma_ch183c'],
        relevantSections: ['ma_ch183c_fee_limits', 'ma_ch183c_disclosures'],
        complianceFocus: ['fee_accuracy', 'disclosure_requirements']
      }
    }
  }
};

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/**
 * Get the relevant state statutes for a document category/subtype.
 *
 * Returns state-specific primary statute IDs, falling back to
 * DEFAULT_STATE_RELEVANCE for unknown states or subtypes.
 *
 * @param {string} stateCode - Two-letter state code (e.g. 'CA', 'NY')
 * @param {string} category - Document category (e.g. 'servicing', 'correspondence')
 * @param {string} subtype - Document subtype (e.g. 'monthly_statement')
 * @returns {string[]} Array of state statute IDs relevant to this document type
 */
function getStateRelevantStatutes(stateCode, category, subtype) {
  const state = STATE_DOCUMENT_STATUTE_RELEVANCE[stateCode];
  if (!state) return DEFAULT_STATE_RELEVANCE.primaryStatutes;
  const cat = state[category];
  if (!cat) return DEFAULT_STATE_RELEVANCE.primaryStatutes;
  const entry = cat[subtype];
  if (!entry) return DEFAULT_STATE_RELEVANCE.primaryStatutes;
  return entry.primaryStatutes;
}

/**
 * Get the relevant state statute sections for a document category/subtype.
 *
 * @param {string} stateCode - Two-letter state code
 * @param {string} category - Document category
 * @param {string} subtype - Document subtype
 * @returns {string[]} Array of section IDs to prioritize during analysis
 */
function getStateRelevantSections(stateCode, category, subtype) {
  const state = STATE_DOCUMENT_STATUTE_RELEVANCE[stateCode];
  if (!state) return DEFAULT_STATE_RELEVANCE.relevantSections;
  const cat = state[category];
  if (!cat) return DEFAULT_STATE_RELEVANCE.relevantSections;
  const entry = cat[subtype];
  if (!entry) return DEFAULT_STATE_RELEVANCE.relevantSections;
  return entry.relevantSections;
}

/**
 * Get the compliance focus areas for a state document category/subtype.
 *
 * @param {string} stateCode - Two-letter state code
 * @param {string} category - Document category
 * @param {string} subtype - Document subtype
 * @returns {string[]} Array of focus area strings for compliance analysis
 */
function getStateComplianceFocus(stateCode, category, subtype) {
  const state = STATE_DOCUMENT_STATUTE_RELEVANCE[stateCode];
  if (!state) return DEFAULT_STATE_RELEVANCE.complianceFocus;
  const cat = state[category];
  if (!cat) return DEFAULT_STATE_RELEVANCE.complianceFocus;
  const entry = cat[subtype];
  if (!entry) return DEFAULT_STATE_RELEVANCE.complianceFocus;
  return entry.complianceFocus;
}

/**
 * Get the list of state codes with document relevance mappings.
 *
 * @returns {string[]} Array of two-letter state codes
 */
function getSupportedRelevanceStates() {
  return Object.keys(STATE_DOCUMENT_STATUTE_RELEVANCE);
}

module.exports = {
  STATE_DOCUMENT_STATUTE_RELEVANCE,
  DEFAULT_STATE_RELEVANCE,
  getStateRelevantStatutes,
  getStateRelevantSections,
  getStateComplianceFocus,
  getSupportedRelevanceStates
};
