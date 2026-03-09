/**
 * Federal Statute Taxonomy Configuration
 *
 * Comprehensive taxonomy of federal mortgage lending laws and their requirements.
 * Used by the compliance engine to map forensic findings (discrepancies, anomalies)
 * to specific statutory violations.
 *
 * Each statute contains sections with requirements, violation patterns that map
 * to existing discrepancyType and anomalyType enums, and penalty descriptions.
 *
 * This is config data — declarative, no business logic.
 */

const FEDERAL_STATUTES = {

  // =========================================================================
  // RESPA — Real Estate Settlement Procedures Act
  // =========================================================================
  respa: {
    id: 'respa',
    name: 'Real Estate Settlement Procedures Act (RESPA)',
    citation: '12 U.S.C. § 2601 et seq.',
    regulatoryBody: 'CFPB',
    sections: [
      {
        id: 'respa_s6',
        section: 'Section 6',
        title: 'Qualified Written Requests',
        regulatoryReference: '12 CFR § 1024.35-36',
        requirements: [
          'Servicer must acknowledge QWR within 5 business days',
          'Servicer must respond substantively within 30 business days',
          'No adverse credit reporting during QWR investigation period',
          'Must correct errors or explain why account is correct'
        ],
        violationPatterns: [
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['qwr', 'qualified written request', 'response deadline', 'acknowledgment'],
            severity: 'high'
          },
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['qwr response', 'acknowledgment missing', 'no response'],
            severity: 'critical'
          }
        ],
        penalties: 'Actual damages, statutory damages up to $2,000 for individual actions, attorney fees. Pattern or practice: up to $1,000,000 or 1% of net worth in class actions.'
      },
      {
        id: 'respa_s8',
        section: 'Section 8',
        title: 'Prohibition of Kickbacks and Referral Fees',
        regulatoryReference: '12 CFR § 1024.14',
        requirements: [
          'No kickbacks or referral fees for settlement services',
          'No fee splitting except for services actually performed',
          'No unearned fees for settlement services'
        ],
        violationPatterns: [
          {
            discrepancyType: 'fee_irregularity',
            anomalyType: 'unusual_value',
            keywords: ['referral fee', 'kickback', 'unearned fee', 'fee splitting'],
            severity: 'critical'
          }
        ],
        penalties: 'Fine up to $10,000, imprisonment up to 1 year, or both. Treble damages in private actions.'
      },
      {
        id: 'respa_s10',
        section: 'Section 10',
        title: 'Escrow Account Requirements',
        regulatoryReference: '12 CFR § 1024.17',
        requirements: [
          'Escrow cushion limited to 1/6 of annual disbursements',
          'Annual escrow analysis required',
          'Surplus over $50 must be refunded within 30 days',
          'Shortage spread over at least 12 months if over 1 month payment'
        ],
        violationPatterns: [
          {
            discrepancyType: 'amount_mismatch',
            anomalyType: 'calculation_error',
            keywords: ['escrow', 'cushion', 'surplus', 'shortage', 'escrow analysis'],
            severity: 'high'
          },
          {
            discrepancyType: 'calculation_error',
            anomalyType: 'unusual_value',
            keywords: ['escrow overcharge', 'escrow excess', 'cushion exceeded'],
            severity: 'high'
          }
        ],
        penalties: 'Actual damages, statutory damages up to $2,000 for individual actions, attorney fees and costs.'
      }
    ]
  },

  // =========================================================================
  // TILA — Truth in Lending Act / Regulation Z
  // =========================================================================
  tila: {
    id: 'tila',
    name: 'Truth in Lending Act (TILA) / Regulation Z',
    citation: '15 U.S.C. § 1601 et seq.',
    regulatoryBody: 'CFPB',
    sections: [
      {
        id: 'tila_disclosure',
        section: 'Section 128',
        title: 'Disclosure Requirements for Mortgage Loans',
        regulatoryReference: '12 CFR § 1026.18-19',
        requirements: [
          'APR must be disclosed accurately (within 1/8 of 1% for regular transactions)',
          'Finance charge must include all charges imposed by creditor',
          'Amount financed must be accurately calculated',
          'Total of payments must be disclosed',
          'Payment schedule must be provided'
        ],
        violationPatterns: [
          {
            discrepancyType: 'calculation_error',
            anomalyType: 'calculation_error',
            keywords: ['apr', 'finance charge', 'amount financed', 'total of payments', 'disclosure'],
            severity: 'high'
          },
          {
            discrepancyType: 'amount_mismatch',
            anomalyType: 'inconsistency',
            keywords: ['apr mismatch', 'rate discrepancy', 'payment schedule'],
            severity: 'high'
          }
        ],
        penalties: 'Statutory damages of twice the finance charge (min $400, max $4,000 for individual). Actual damages, attorney fees. Class action: lesser of $1,000,000 or 1% of net worth.'
      },
      {
        id: 'tila_rescission',
        section: 'Section 125',
        title: 'Right of Rescission',
        regulatoryReference: '12 CFR § 1026.23',
        requirements: [
          'Borrower has 3 business days to rescind after closing',
          'Two copies of rescission notice required',
          'Failure to provide notice extends rescission period up to 3 years',
          'Material TILA disclosure errors extend rescission rights'
        ],
        violationPatterns: [
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['rescission', 'right to cancel', 'cancellation notice'],
            severity: 'critical'
          },
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['rescission period', 'cancellation deadline'],
            severity: 'high'
          }
        ],
        penalties: 'Extended rescission rights up to 3 years. Actual damages, statutory damages, attorney fees. Creditor must return all money/property within 20 days of rescission.'
      },
      {
        id: 'tila_arm',
        section: 'Section 128(f)',
        title: 'ARM Adjustment Notices',
        regulatoryReference: '12 CFR § 1026.20(c)-(d)',
        requirements: [
          'Initial rate change notice at least 210 days before first payment at new rate',
          'Subsequent rate change notices at least 60 days before payment change',
          'Notice must include current and new interest rate, payment amount, index value'
        ],
        violationPatterns: [
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['arm adjustment', 'rate change notice', 'adjustment notice'],
            severity: 'medium'
          },
          {
            discrepancyType: 'amount_mismatch',
            anomalyType: 'calculation_error',
            keywords: ['index value', 'margin', 'rate calculation', 'arm rate'],
            severity: 'high'
          }
        ],
        penalties: 'Actual damages, statutory damages, attorney fees. Regulatory enforcement action by CFPB.'
      }
    ]
  },

  // =========================================================================
  // ECOA — Equal Credit Opportunity Act / Regulation B
  // =========================================================================
  ecoa: {
    id: 'ecoa',
    name: 'Equal Credit Opportunity Act (ECOA) / Regulation B',
    citation: '15 U.S.C. § 1691 et seq.',
    regulatoryBody: 'CFPB',
    sections: [
      {
        id: 'ecoa_discrimination',
        section: 'Section 701',
        title: 'Prohibition of Discrimination',
        regulatoryReference: '12 CFR § 1002.4',
        requirements: [
          'Cannot discriminate based on race, color, religion, national origin, sex, marital status, age',
          'Cannot discriminate based on receipt of public assistance',
          'Cannot discourage applications on prohibited basis',
          'Equal treatment in loan terms, conditions, and servicing'
        ],
        violationPatterns: [
          {
            discrepancyType: 'term_contradiction',
            anomalyType: 'unusual_value',
            keywords: ['discrimination', 'disparate treatment', 'unequal terms', 'steering'],
            severity: 'critical'
          }
        ],
        penalties: 'Actual damages, punitive damages up to $10,000 for individual actions. Class action: lesser of $500,000 or 1% of net worth. Injunctive and equitable relief.'
      },
      {
        id: 'ecoa_adverse_action',
        section: 'Section 701(d)',
        title: 'Adverse Action Notices',
        regulatoryReference: '12 CFR § 1002.9',
        requirements: [
          'Written notice required within 30 days of adverse action',
          'Must include specific reasons for adverse action or right to request reasons',
          'Must include ECOA anti-discrimination notice',
          'Must identify the federal supervisory agency'
        ],
        violationPatterns: [
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['adverse action', 'denial notice', 'reasons for denial'],
            severity: 'high'
          },
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['adverse action timing', 'notice deadline'],
            severity: 'medium'
          }
        ],
        penalties: 'Actual damages, punitive damages up to $10,000. Attorney fees and costs. Regulatory enforcement action.'
      }
    ]
  },

  // =========================================================================
  // FDCPA — Fair Debt Collection Practices Act
  // =========================================================================
  fdcpa: {
    id: 'fdcpa',
    name: 'Fair Debt Collection Practices Act (FDCPA)',
    citation: '15 U.S.C. § 1692 et seq.',
    regulatoryBody: 'CFPB / FTC',
    sections: [
      {
        id: 'fdcpa_validation',
        section: 'Section 809',
        title: 'Validation of Debts',
        regulatoryReference: '15 U.S.C. § 1692g',
        requirements: [
          'Written validation notice within 5 days of initial communication',
          'Must include amount of debt, name of creditor',
          'Must inform of right to dispute within 30 days',
          'Must cease collection during validation period if disputed'
        ],
        violationPatterns: [
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['validation notice', 'debt validation', 'collection notice missing'],
            severity: 'high'
          },
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['validation period', 'dispute period', 'collection during dispute'],
            severity: 'high'
          }
        ],
        penalties: 'Actual damages, statutory damages up to $1,000 for individual actions. Class action: lesser of $500,000 or 1% of net worth. Attorney fees and costs.'
      },
      {
        id: 'fdcpa_practices',
        section: 'Section 805-806',
        title: 'Communication and Harassment Restrictions',
        regulatoryReference: '15 U.S.C. § 1692c-d',
        requirements: [
          'No communication at unusual or inconvenient times/places',
          'No harassment, oppression, or abuse',
          'No false, deceptive, or misleading representations',
          'Must cease communication upon written request'
        ],
        violationPatterns: [
          {
            discrepancyType: 'term_contradiction',
            anomalyType: 'regulatory_concern',
            keywords: ['harassment', 'deceptive', 'misleading', 'false representation', 'collection practice'],
            severity: 'high'
          }
        ],
        penalties: 'Actual damages, statutory damages up to $1,000. Attorney fees. State AG enforcement.'
      },
      {
        id: 'fdcpa_amount',
        section: 'Section 807(2)',
        title: 'False Representation of Debt Amount',
        regulatoryReference: '15 U.S.C. § 1692e(2)',
        requirements: [
          'Cannot misrepresent the character, amount, or legal status of debt',
          'Cannot collect amounts not authorized by agreement or law',
          'Fees and charges must be contractually permitted'
        ],
        violationPatterns: [
          {
            discrepancyType: 'amount_mismatch',
            anomalyType: 'unusual_value',
            keywords: ['inflated balance', 'unauthorized fee', 'incorrect amount', 'debt amount'],
            severity: 'critical'
          },
          {
            discrepancyType: 'fee_irregularity',
            anomalyType: 'calculation_error',
            keywords: ['unauthorized charge', 'improper fee', 'inflated fee'],
            severity: 'high'
          }
        ],
        penalties: 'Actual damages, statutory damages up to $1,000. Class action: lesser of $500,000 or 1% of net worth. Attorney fees.'
      }
    ]
  },

  // =========================================================================
  // SCRA — Servicemembers Civil Relief Act
  // =========================================================================
  scra: {
    id: 'scra',
    name: 'Servicemembers Civil Relief Act (SCRA)',
    citation: '50 U.S.C. § 3901 et seq.',
    regulatoryBody: 'DOJ',
    sections: [
      {
        id: 'scra_interest_cap',
        section: 'Section 207',
        title: '6% Interest Rate Cap',
        regulatoryReference: '50 U.S.C. § 3937',
        requirements: [
          'Interest rate capped at 6% during military service for pre-service obligations',
          'Interest above 6% must be forgiven, not deferred',
          'Applies automatically upon written request and military orders',
          'Servicer must adjust monthly payment to reflect reduced rate'
        ],
        violationPatterns: [
          {
            discrepancyType: 'calculation_error',
            anomalyType: 'calculation_error',
            keywords: ['interest rate cap', '6%', 'scra rate', 'military rate reduction'],
            severity: 'critical'
          },
          {
            discrepancyType: 'amount_mismatch',
            anomalyType: 'unusual_value',
            keywords: ['scra payment', 'military payment', 'rate above 6%'],
            severity: 'critical'
          }
        ],
        penalties: 'Actual damages, statutory penalties. DOJ may seek civil penalties up to $55,000 for first violation, $110,000 for subsequent. Private right of action.'
      },
      {
        id: 'scra_foreclosure',
        section: 'Section 303',
        title: 'Foreclosure Protections',
        regulatoryReference: '50 U.S.C. § 3953',
        requirements: [
          'No foreclosure during military service or within 12 months after',
          'Court order required for foreclosure during protected period',
          'Stay of proceedings available upon request',
          'Sale, foreclosure, or seizure void without court order during protected period'
        ],
        violationPatterns: [
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['foreclosure', 'military service', 'scra foreclosure', 'protected period'],
            severity: 'critical'
          },
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['court order', 'scra court approval', 'foreclosure authorization'],
            severity: 'critical'
          }
        ],
        penalties: 'Foreclosure action is void. Actual damages. DOJ civil penalties. Criminal penalties for knowing violations.'
      }
    ]
  },

  // =========================================================================
  // HMDA — Home Mortgage Disclosure Act / Regulation C
  // =========================================================================
  hmda: {
    id: 'hmda',
    name: 'Home Mortgage Disclosure Act (HMDA) / Regulation C',
    citation: '12 U.S.C. § 2801 et seq.',
    regulatoryBody: 'CFPB',
    sections: [
      {
        id: 'hmda_reporting',
        section: 'Section 304',
        title: 'Data Collection and Reporting Requirements',
        regulatoryReference: '12 CFR § 1003.4-5',
        requirements: [
          'Collect and report data on mortgage applications and originations',
          'Report loan-level data including demographics, pricing, loan features',
          'Annual submission of Loan Application Register (LAR)',
          'Accurate geocoding and census tract identification'
        ],
        violationPatterns: [
          {
            discrepancyType: 'term_contradiction',
            anomalyType: 'inconsistency',
            keywords: ['hmda data', 'reporting error', 'lar', 'loan application register'],
            severity: 'medium'
          }
        ],
        penalties: 'Civil money penalties up to $50,000/day for failure to report. Regulatory enforcement. Reputational risk from public data disclosure.'
      },
      {
        id: 'hmda_accuracy',
        section: 'Section 304(b)',
        title: 'Data Accuracy and Integrity',
        regulatoryReference: '12 CFR § 1003.6',
        requirements: [
          'Data must be accurate within regulatory tolerance thresholds',
          'Resubmission required if error rate exceeds threshold',
          'Maintain records for at least 3 years',
          'Quality control procedures must be in place'
        ],
        violationPatterns: [
          {
            discrepancyType: 'amount_mismatch',
            anomalyType: 'calculation_error',
            keywords: ['data accuracy', 'reporting accuracy', 'hmda error'],
            severity: 'medium'
          }
        ],
        penalties: 'Civil money penalties. Required data resubmission. Supervisory action.'
      }
    ]
  },

  // =========================================================================
  // CFPB / Regulation X — Dodd-Frank CFPB Servicing Rules
  // =========================================================================
  cfpb_reg_x: {
    id: 'cfpb_reg_x',
    name: 'CFPB Servicing Rules (Dodd-Frank / Regulation X)',
    citation: '12 CFR Part 1024, Subpart C',
    regulatoryBody: 'CFPB',
    sections: [
      {
        id: 'cfpb_loss_mitigation',
        section: 'Section 1024.41',
        title: 'Loss Mitigation Procedures',
        regulatoryReference: '12 CFR § 1024.41',
        requirements: [
          'Acknowledge receipt of loss mitigation application within 5 business days',
          'Evaluate complete application within 30 days',
          'Provide written determination with specific reasons for denial',
          'Allow 14 days to accept or appeal loss mitigation offer',
          'Cannot require waiver of borrower rights as condition of loss mitigation'
        ],
        violationPatterns: [
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['loss mitigation', 'application review', 'loss mit timeline', 'modification review'],
            severity: 'high'
          },
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['loss mitigation response', 'modification denial', 'application acknowledgment'],
            severity: 'high'
          }
        ],
        penalties: 'Actual damages, statutory damages, attorney fees. CFPB enforcement action with civil money penalties up to $1,000,000/day for knowing violations.'
      },
      {
        id: 'cfpb_dual_tracking',
        section: 'Section 1024.41(g)',
        title: 'Prohibition of Dual Tracking',
        regulatoryReference: '12 CFR § 1024.41(g)',
        requirements: [
          'Cannot initiate foreclosure while loss mitigation application is pending',
          'Cannot move for foreclosure judgment while complete application under review',
          'Must stay foreclosure proceedings during loss mitigation evaluation',
          'First notice/filing cannot occur until borrower is more than 120 days delinquent'
        ],
        violationPatterns: [
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['dual tracking', 'simultaneous foreclosure', 'foreclosure during review', 'pending application'],
            severity: 'critical'
          }
        ],
        penalties: 'Actual damages, statutory damages, attorney fees. CFPB enforcement with civil money penalties.'
      },
      {
        id: 'cfpb_force_placed_insurance',
        section: 'Section 1024.37',
        title: 'Force-Placed Insurance',
        regulatoryReference: '12 CFR § 1024.37',
        requirements: [
          'Two written notices required before charging force-placed insurance',
          'First notice at least 45 days before charging',
          'Reminder notice at least 15 days before charging',
          'Must cancel within 15 days of receiving evidence of existing coverage',
          'Must refund premiums for overlapping coverage period'
        ],
        violationPatterns: [
          {
            discrepancyType: 'fee_irregularity',
            anomalyType: 'unusual_value',
            keywords: ['force-placed', 'lender-placed', 'fpi', 'insurance charge', 'forced insurance'],
            severity: 'high'
          },
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['insurance notice', 'fpi notice', 'force-placed notice'],
            severity: 'high'
          },
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['insurance notice timing', 'fpi timeline', '45 day notice'],
            severity: 'medium'
          }
        ],
        penalties: 'Actual damages, statutory damages, attorney fees. CFPB enforcement action. Refund of improper premiums.'
      },
      {
        id: 'cfpb_error_resolution',
        section: 'Section 1024.35',
        title: 'Error Resolution Procedures',
        regulatoryReference: '12 CFR § 1024.35',
        requirements: [
          'Acknowledge error notice within 5 business days',
          'Complete investigation within 30 business days (extendable to 45)',
          'Correct the error or provide written explanation',
          'Cannot charge fees for error investigation',
          'No adverse credit reporting during investigation'
        ],
        violationPatterns: [
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['error resolution', 'notice of error', 'error investigation', 'error response'],
            severity: 'high'
          },
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['error acknowledgment', 'investigation response', 'error correction'],
            severity: 'high'
          }
        ],
        penalties: 'Actual damages, statutory damages up to $2,000. Pattern or practice: class action damages. Attorney fees and costs.'
      },
      {
        id: 'cfpb_early_intervention',
        section: 'Section 1024.39',
        title: 'Early Intervention for Delinquent Borrowers',
        regulatoryReference: '12 CFR § 1024.39',
        requirements: [
          'Make good faith effort to establish live contact by 36th day of delinquency',
          'Provide written notice with loss mitigation information by 45th day',
          'Written notice must include loss mitigation application and contact information',
          'Cannot charge late fees prohibited by applicable law'
        ],
        violationPatterns: [
          {
            discrepancyType: 'timeline_violation',
            anomalyType: 'regulatory_concern',
            keywords: ['early intervention', 'delinquency contact', '36 day', '45 day notice'],
            severity: 'medium'
          },
          {
            discrepancyType: 'missing_correspondence',
            anomalyType: 'missing_required',
            keywords: ['delinquency notice', 'loss mitigation info', 'early intervention notice'],
            severity: 'medium'
          }
        ],
        penalties: 'Actual damages, statutory damages, attorney fees. CFPB supervisory and enforcement action.'
      }
    ]
  }
};

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/**
 * Look up a federal statute by its short identifier.
 *
 * @param {string} id - Statute identifier (e.g. 'respa', 'tila')
 * @returns {Object|undefined} The statute object, or undefined if not found
 */
function getStatuteById(id) {
  return FEDERAL_STATUTES[id];
}

/**
 * Look up a section by its identifier across all statutes.
 *
 * @param {string} sectionId - Section identifier (e.g. 'respa_s6', 'tila_disclosure')
 * @returns {Object|undefined} The section object, or undefined if not found
 */
function getSectionById(sectionId) {
  for (const statute of Object.values(FEDERAL_STATUTES)) {
    const section = statute.sections.find(s => s.id === sectionId);
    if (section) {
      return section;
    }
  }
  return undefined;
}

/**
 * Get all statute identifiers.
 *
 * @returns {string[]} Array of statute id strings
 */
function getStatuteIds() {
  return Object.keys(FEDERAL_STATUTES);
}

/**
 * Get all section identifiers across all statutes.
 *
 * @returns {string[]} Array of section id strings
 */
function getSectionIds() {
  const ids = [];
  for (const statute of Object.values(FEDERAL_STATUTES)) {
    for (const section of statute.sections) {
      ids.push(section.id);
    }
  }
  return ids;
}

/**
 * Find all sections whose violation patterns match a given discrepancy type.
 *
 * Returns an array of objects with the matching statute, section, and the
 * specific violation pattern that matched.
 *
 * @param {string} type - A discrepancy type (e.g. 'amount_mismatch', 'timeline_violation')
 * @returns {Array<{ statuteId: string, sectionId: string, pattern: Object }>}
 */
function getViolationPatternsForDiscrepancyType(type) {
  const results = [];
  for (const statute of Object.values(FEDERAL_STATUTES)) {
    for (const section of statute.sections) {
      for (const pattern of section.violationPatterns) {
        if (pattern.discrepancyType === type) {
          results.push({
            statuteId: statute.id,
            sectionId: section.id,
            pattern
          });
        }
      }
    }
  }
  return results;
}

module.exports = {
  FEDERAL_STATUTES,
  getStatuteById,
  getSectionById,
  getStatuteIds,
  getSectionIds,
  getViolationPatternsForDiscrepancyType
};
