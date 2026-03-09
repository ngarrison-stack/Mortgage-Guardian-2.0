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
    statutes: {

      // -------------------------------------------------------------------
      // California Homeowner Bill of Rights (HBOR)
      // -------------------------------------------------------------------
      ca_hbor: {
        id: 'ca_hbor',
        name: 'California Homeowner Bill of Rights (HBOR)',
        citation: 'Cal. Civ. Code §§ 2923.4-2924.12',
        enforcementBody: 'CA DFPI / Private Right of Action',
        sections: [
          {
            id: 'ca_hbor_dual_tracking',
            section: '§ 2924.11',
            title: 'Prohibition of Dual Tracking',
            regulatoryReference: 'Cal. Civ. Code § 2924.11',
            requirements: [
              'Servicer must not record notice of default while loss mitigation application is pending',
              'Servicer must not conduct trustee sale while borrower is in an approved modification trial plan',
              'Written determination must be provided before advancing foreclosure',
              'Borrower must be given 30 days to appeal denial before foreclosure proceeds'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['dual tracking', 'simultaneous foreclosure', 'foreclosure during review', 'pending modification'],
                severity: 'critical'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['modification denial notice', 'appeal period', 'loss mitigation determination'],
                severity: 'high'
              }
            ],
            penalties: 'Injunctive relief to enjoin material violation. Actual economic damages. Treble damages for intentional violations in pattern or practice. Attorney fees and costs.'
          },
          {
            id: 'ca_hbor_single_poc',
            section: '§ 2923.7',
            title: 'Single Point of Contact',
            regulatoryReference: 'Cal. Civ. Code § 2923.7',
            requirements: [
              'Servicer must assign single point of contact (SPOC) when borrower requests loss mitigation',
              'SPOC must be knowledgeable about the borrower\'s situation and loan',
              'SPOC must coordinate document collection and ensure timely processing',
              'SPOC must have ability to stop foreclosure proceedings if warranted'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['single point of contact', 'spoc', 'contact person', 'assigned representative'],
                severity: 'medium'
              }
            ],
            penalties: 'Injunctive relief. Actual economic damages. Attorney fees and costs.'
          },
          {
            id: 'ca_hbor_complete_application',
            section: '§ 2924.10',
            title: 'Acknowledgment of Loss Mitigation Application',
            regulatoryReference: 'Cal. Civ. Code § 2924.10',
            requirements: [
              'Written acknowledgment within 5 business days of receiving application',
              'Must describe loss mitigation options available',
              'Must identify any missing documents needed to complete application',
              'Must provide deadline for submitting missing documents'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['application acknowledgment', 'loss mitigation acknowledgment', '5 day acknowledgment'],
                severity: 'high'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['acknowledgment letter', 'missing document notice', 'application status'],
                severity: 'high'
              }
            ],
            penalties: 'Injunctive relief. Actual economic damages. Attorney fees and costs.'
          },
          {
            id: 'ca_hbor_notice_of_default',
            section: '§ 2923.5',
            title: 'Contact Requirements Before Notice of Default',
            regulatoryReference: 'Cal. Civ. Code § 2923.5',
            requirements: [
              'Servicer must contact borrower or exercise due diligence 30 days before recording notice of default',
              'Must explore options to avoid foreclosure during contact',
              'Declaration of compliance must accompany notice of default',
              'Due diligence requires first-class letter, certified letter, and three phone calls on different days'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['pre-default contact', 'notice of default', '30 day contact', 'due diligence'],
                severity: 'high'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['due diligence declaration', 'compliance declaration', 'borrower contact attempt'],
                severity: 'high'
              }
            ],
            penalties: 'Notice of default is voidable. Postponement of sale. Actual economic damages. Attorney fees and costs.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // California Civil Code — Mortgage Servicing
      // -------------------------------------------------------------------
      ca_civ_code_servicing: {
        id: 'ca_civ_code_servicing',
        name: 'California Civil Code — Mortgage Servicing',
        citation: 'Cal. Civ. Code §§ 2954-2955',
        enforcementBody: 'CA DFPI / Private Right of Action',
        sections: [
          {
            id: 'ca_civ_escrow_accounts',
            section: '§ 2954',
            title: 'Escrow Account Limitations',
            regulatoryReference: 'Cal. Civ. Code § 2954',
            requirements: [
              'Impound account charges limited to amounts reasonably necessary for taxes and insurance',
              'Annual accounting of impound account disbursements required',
              'Excess funds must be returned to borrower within 30 days',
              'Borrower may request cancellation of impound account under certain conditions'
            ],
            violationPatterns: [
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'calculation_error',
                keywords: ['escrow', 'impound', 'escrow excess', 'impound overcharge'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['impound fee', 'escrow surplus', 'impound account charge'],
                severity: 'medium'
              }
            ],
            penalties: 'Refund of excess impound amounts. Actual damages. Attorney fees and costs. Statutory penalties for willful violations.'
          },
          {
            id: 'ca_civ_payoff_demand',
            section: '§ 2943',
            title: 'Payoff Demand Statement Requirements',
            regulatoryReference: 'Cal. Civ. Code § 2943',
            requirements: [
              'Payoff demand statement must be provided within 21 days of written request',
              'Statement must include total amount required to pay off the loan',
              'Must itemize all charges included in the payoff amount',
              'Fee for payoff statement cannot exceed statutory maximum'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['payoff demand', 'payoff statement', '21 day payoff', 'payoff delay'],
                severity: 'medium'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['payoff fee', 'statement fee', 'payoff overcharge'],
                severity: 'medium'
              }
            ],
            penalties: 'Liability for actual damages and $500 penalty for each willful violation. Attorney fees and costs.'
          },
          {
            id: 'ca_civ_transfer_disclosure',
            section: '§ 2937',
            title: 'Loan Servicing Transfer Disclosure',
            regulatoryReference: 'Cal. Civ. Code § 2937',
            requirements: [
              'Borrower must receive notice of servicing transfer at least 15 days before effective date',
              'Notice must include name and address of new servicer',
              'Must provide toll-free number for new servicer',
              'No late fees for 60 days following transfer if payment sent to prior servicer'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['servicing transfer', 'transfer notice', 'new servicer', 'servicing change'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['late fee after transfer', 'transfer late charge', 'servicing transfer fee'],
                severity: 'medium'
              }
            ],
            penalties: 'Actual damages. Late fees charged during 60-day grace period must be refunded. Attorney fees and costs.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // California Financial Code — Residential Mortgage Lending Act
      // -------------------------------------------------------------------
      ca_rmla: {
        id: 'ca_rmla',
        name: 'California Residential Mortgage Lending Act (RMLA)',
        citation: 'Cal. Fin. Code §§ 50000-50706',
        enforcementBody: 'CA DFPI',
        sections: [
          {
            id: 'ca_rmla_licensing',
            section: '§ 50002',
            title: 'Licensing Requirements for Mortgage Servicers',
            regulatoryReference: 'Cal. Fin. Code § 50002',
            requirements: [
              'Servicer must hold a valid RMLA license to service residential mortgages in California',
              'License must be renewed annually with DFPI',
              'Servicer must maintain minimum net worth and surety bond requirements'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['unlicensed servicer', 'rmla license', 'licensing violation', 'servicer registration'],
                severity: 'critical'
              }
            ],
            penalties: 'Administrative penalties up to $25,000 per violation. License suspension or revocation. Injunctive relief. Criminal penalties for willful violations.'
          },
          {
            id: 'ca_rmla_books_records',
            section: '§ 50310',
            title: 'Books and Records Requirements',
            regulatoryReference: 'Cal. Fin. Code § 50310',
            requirements: [
              'Servicer must maintain accurate books and records for each loan serviced',
              'Records must be available for inspection by DFPI',
              'Loan payment records must be retained for a minimum of 3 years',
              'Trust account records must be maintained separately'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['missing records', 'recordkeeping', 'books and records', 'document retention'],
                severity: 'medium'
              }
            ],
            penalties: 'Administrative penalties up to $25,000 per violation. License suspension. Consent order or cease and desist.'
          },
          {
            id: 'ca_rmla_trust_funds',
            section: '§ 50510',
            title: 'Trust Fund Handling',
            regulatoryReference: 'Cal. Fin. Code § 50510',
            requirements: [
              'Borrower funds must be deposited in federally insured trust accounts',
              'Trust funds cannot be commingled with servicer operating funds',
              'Timely disbursement of trust funds for taxes and insurance required',
              'Monthly trust account reconciliation required'
            ],
            violationPatterns: [
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['trust fund', 'commingling', 'escrow disbursement', 'trust account'],
                severity: 'critical'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['late disbursement', 'trust fund delay', 'tax payment late', 'insurance payment late'],
                severity: 'high'
              }
            ],
            penalties: 'Administrative penalties up to $25,000 per violation. License revocation. Criminal penalties for misappropriation. Restitution to borrowers.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // California Rosenthal Fair Debt Collection Practices Act
      // -------------------------------------------------------------------
      ca_rosenthal: {
        id: 'ca_rosenthal',
        name: 'California Rosenthal Fair Debt Collection Practices Act',
        citation: 'Cal. Civ. Code §§ 1788-1788.33',
        enforcementBody: 'CA AG / Private Right of Action',
        sections: [
          {
            id: 'ca_rosenthal_prohibited_practices',
            section: '§ 1788.10-1788.11',
            title: 'Prohibited Debt Collection Practices',
            regulatoryReference: 'Cal. Civ. Code §§ 1788.10-1788.11',
            requirements: [
              'No threats of violence or criminal prosecution',
              'No obscene or abusive language in collection communications',
              'No repeated telephone calls made with intent to harass',
              'No false or misleading representations about debt',
              'No communication with debtor known to be represented by attorney'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['harassment', 'threatening', 'abusive collection', 'misleading representation'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages. Statutory penalties up to $1,000 per violation. Injunctive relief. Attorney fees and costs.'
          },
          {
            id: 'ca_rosenthal_original_creditor',
            section: '§ 1788.2(c)',
            title: 'Coverage of Original Creditors',
            regulatoryReference: 'Cal. Civ. Code § 1788.2(c)',
            requirements: [
              'Original creditors (including mortgage servicers) are covered as debt collectors',
              'Servicers collecting their own debts must comply with Rosenthal Act',
              'Same restrictions apply regardless of whether debt is assigned or original'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['original creditor', 'servicer collection', 'debt collector status'],
                severity: 'medium'
              }
            ],
            penalties: 'Actual damages. Statutory penalties up to $1,000 per violation. Attorney fees and costs.'
          },
          {
            id: 'ca_rosenthal_validation',
            section: '§ 1788.14',
            title: 'Debt Validation Requirements',
            regulatoryReference: 'Cal. Civ. Code § 1788.14',
            requirements: [
              'Must provide written validation notice within 5 days of initial communication',
              'Must include amount of debt and name of creditor',
              'Must inform debtor of right to dispute within 30 days',
              'Must cease collection activity during validation period if debt is disputed'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['validation notice', 'debt validation', 'rosenthal notice'],
                severity: 'high'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['validation period', 'dispute period', 'collection during dispute'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages. Statutory penalties up to $1,000 per violation. Class action penalties. Attorney fees and costs.'
          },
          {
            id: 'ca_rosenthal_unfair_practices',
            section: '§ 1788.13',
            title: 'Unfair or Deceptive Practices',
            regulatoryReference: 'Cal. Civ. Code § 1788.13',
            requirements: [
              'Cannot collect any amount not authorized by the agreement or permitted by law',
              'Cannot misrepresent the character, amount, or legal status of a debt',
              'Cannot add unauthorized interest, fees, or charges to debt balance'
            ],
            violationPatterns: [
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['unauthorized fee', 'inflated balance', 'incorrect amount', 'unauthorized charge'],
                severity: 'critical'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'calculation_error',
                keywords: ['improper fee', 'unauthorized interest', 'inflated charge'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages. Statutory penalties up to $1,000 per violation. Treble damages for willful violations. Attorney fees and costs.'
          }
        ]
      }

    }
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
