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
    statutes: {

      // -------------------------------------------------------------------
      // RPAPL — Real Property Actions and Proceedings Law
      // -------------------------------------------------------------------
      ny_rpapl: {
        id: 'ny_rpapl',
        name: 'New York Real Property Actions and Proceedings Law (RPAPL)',
        citation: 'RPAPL §§ 1301-1311',
        enforcementBody: 'NY DFS / NY Courts',
        sections: [
          {
            id: 'ny_rpapl_settlement_conference',
            section: '§ 1302-a',
            title: 'Mandatory Settlement Conference',
            regulatoryReference: 'RPAPL § 1302-a',
            requirements: [
              'Mandatory settlement conference required in residential foreclosure actions',
              'Servicer must appear at settlement conference with authority to settle',
              'Servicer must bring all relevant loan documents to conference',
              'Good faith participation in settlement negotiations required'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['settlement conference', 'mandatory conference', 'foreclosure conference', 'good faith negotiation'],
                severity: 'high'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['conference notice', 'settlement documents', 'foreclosure settlement'],
                severity: 'high'
              }
            ],
            penalties: 'Dismissal of foreclosure action. Sanctions for bad faith participation. Tolling of interest and fees during non-compliance.'
          },
          {
            id: 'ny_rpapl_notice_requirements',
            section: '§ 1303-1304',
            title: 'Pre-Foreclosure Notice Requirements',
            regulatoryReference: 'RPAPL §§ 1303-1304',
            requirements: [
              'Must serve 90-day pre-foreclosure notice before commencing action',
              'Notice must include list of at least 5 HUD-approved housing counseling agencies',
              'Notice must be in prescribed statutory format and language',
              'Must file proof of service of 90-day notice with the court',
              'Notice must include statement of borrower rights'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['90 day notice', 'pre-foreclosure notice', 'rpapl 1304', 'housing counseling notice'],
                severity: 'critical'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['90 day requirement', 'pre-foreclosure timing', 'notice timing'],
                severity: 'critical'
              }
            ],
            penalties: 'Foreclosure action dismissed without prejudice. Servicer must restart process with proper notice. Attorney fees to borrower.'
          },
          {
            id: 'ny_rpapl_standing',
            section: '§ 1302',
            title: 'Standing and Chain of Title Requirements',
            regulatoryReference: 'RPAPL § 1302',
            requirements: [
              'Plaintiff must demonstrate physical possession of note or status as holder',
              'Chain of assignments must be documented and complete',
              'Standing must exist at time of filing foreclosure action',
              'MERS assignments must be properly executed'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'inconsistency',
                keywords: ['standing', 'chain of title', 'note holder', 'assignment', 'mers'],
                severity: 'critical'
              }
            ],
            penalties: 'Dismissal of foreclosure action for lack of standing. Attorney fees and costs to borrower.'
          },
          {
            id: 'ny_rpapl_surplus_money',
            section: '§ 1361',
            title: 'Surplus Money Proceedings',
            regulatoryReference: 'RPAPL § 1361',
            requirements: [
              'Surplus money from foreclosure sale must be paid to former owner or junior lienholders',
              'Referee must file surplus money report within specified timeframe',
              'Former owner must be notified of right to claim surplus funds'
            ],
            violationPatterns: [
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['surplus money', 'foreclosure surplus', 'excess proceeds', 'surplus funds'],
                severity: 'high'
              }
            ],
            penalties: 'Court order for distribution of surplus. Interest on undistributed surplus. Sanctions for non-compliance.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // NY Banking Law — Mortgage Servicing
      // -------------------------------------------------------------------
      ny_banking_law: {
        id: 'ny_banking_law',
        name: 'New York Banking Law — Mortgage Servicing',
        citation: 'NY Banking Law §§ 6-l, 6-m, 595-b',
        enforcementBody: 'NY DFS',
        sections: [
          {
            id: 'ny_banking_servicer_obligations',
            section: '§ 6-l',
            title: 'Mortgage Servicer Obligations',
            regulatoryReference: 'NY Banking Law § 6-l',
            requirements: [
              'Servicer must credit payments as of the date received',
              'Must provide accurate periodic statements with payment breakdown',
              'Must maintain toll-free telephone number for borrower inquiries',
              'Must respond to borrower inquiries within 10 business days',
              'Must notify borrower of any servicing transfer at least 15 days in advance'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['payment crediting', 'late crediting', 'inquiry response', 'response time'],
                severity: 'high'
              },
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'calculation_error',
                keywords: ['payment application', 'payment misapplication', 'statement error', 'payment breakdown'],
                severity: 'high'
              }
            ],
            penalties: 'DFS enforcement action. Civil money penalties up to $10,000 per violation. License suspension or revocation. Restitution to borrowers.'
          },
          {
            id: 'ny_banking_loss_mitigation',
            section: '§ 6-m',
            title: 'Loss Mitigation Requirements',
            regulatoryReference: 'NY Banking Law § 6-m',
            requirements: [
              'Servicer must evaluate borrowers for all available loss mitigation options',
              'Must provide written determination within 30 days of receiving complete application',
              'Denial must include specific reasons and notice of appeal rights',
              'Cannot charge fees for loss mitigation review or processing'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['loss mitigation determination', 'modification denial', 'appeal rights notice'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['modification fee', 'loss mitigation fee', 'processing fee'],
                severity: 'medium'
              }
            ],
            penalties: 'DFS enforcement action. Civil money penalties. Refund of improperly charged fees. License sanctions.'
          },
          {
            id: 'ny_banking_registration',
            section: '§ 595-b',
            title: 'Mortgage Servicer Registration',
            regulatoryReference: 'NY Banking Law § 595-b',
            requirements: [
              'All mortgage servicers must register with NY DFS',
              'Must maintain minimum net worth and surety bond requirements',
              'Annual renewal of registration required',
              'Must submit annual reports to DFS on servicing portfolio'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['unregistered servicer', 'servicer registration', 'dfs registration'],
                severity: 'critical'
              }
            ],
            penalties: 'Civil penalty up to $5,000 per violation. Cease and desist orders. Injunctive relief. Criminal referral for willful violations.'
          },
          {
            id: 'ny_banking_escrow',
            section: '§ 6-l(5)',
            title: 'Escrow Account Management',
            regulatoryReference: 'NY Banking Law § 6-l(5)',
            requirements: [
              'Servicer must pay minimum 2% annual interest on escrow accounts',
              'Annual escrow analysis statement required',
              'Escrow surplus over $50 must be refunded within 30 days',
              'Cannot require excessive escrow deposits beyond amounts needed for taxes and insurance'
            ],
            violationPatterns: [
              {
                discrepancyType: 'calculation_error',
                anomalyType: 'calculation_error',
                keywords: ['escrow interest', 'escrow analysis', 'escrow surplus', 'escrow overcharge'],
                severity: 'high'
              },
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['escrow excess', 'missing escrow interest', 'escrow refund'],
                severity: 'medium'
              }
            ],
            penalties: 'DFS enforcement action. Refund of excess escrow amounts plus interest. Civil money penalties.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // NY General Business Law § 349
      // -------------------------------------------------------------------
      ny_gbl_349: {
        id: 'ny_gbl_349',
        name: 'New York General Business Law — Deceptive Acts and Practices',
        citation: 'NY Gen. Bus. Law § 349',
        enforcementBody: 'NY AG / Private Right of Action',
        sections: [
          {
            id: 'ny_gbl_deceptive_acts',
            section: '§ 349(a)',
            title: 'Prohibition of Deceptive Business Practices',
            regulatoryReference: 'NY Gen. Bus. Law § 349(a)',
            requirements: [
              'Deceptive acts or practices in mortgage servicing are unlawful',
              'Misleading statements about loan terms, fees, or borrower options are prohibited',
              'Servicer must provide accurate and truthful information to borrowers',
              'Unfair practices that cause injury to consumers are actionable'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['deceptive practice', 'misleading statement', 'unfair practice', 'consumer deception'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['hidden fee', 'undisclosed charge', 'deceptive fee', 'misleading charge'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages or $50 statutory damages (whichever is greater). Treble damages up to $1,000 for willful or knowing violations. Injunctive relief. Attorney fees.'
          },
          {
            id: 'ny_gbl_false_advertising',
            section: '§ 349(h)',
            title: 'Private Right of Action for Consumer Injury',
            regulatoryReference: 'NY Gen. Bus. Law § 349(h)',
            requirements: [
              'Consumer need not prove reliance — only that practice was deceptive and consumer-oriented',
              'Injury must be to the public interest, not just individual borrower',
              'Pattern of deceptive conduct toward multiple borrowers strengthens claim'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'inconsistency',
                keywords: ['pattern of practice', 'consumer injury', 'public interest', 'systematic deception'],
                severity: 'critical'
              }
            ],
            penalties: 'Actual damages or $50 statutory minimum. Treble damages up to $1,000 for willful violations. Injunctive relief. Attorney fees and costs.'
          },
          {
            id: 'ny_gbl_mortgage_representations',
            section: '§ 349-a',
            title: 'Mortgage-Specific Deceptive Practices',
            regulatoryReference: 'NY Gen. Bus. Law § 349',
            requirements: [
              'Cannot misrepresent borrower\'s default status or amounts owed',
              'Cannot make false statements about foreclosure timeline or options',
              'Cannot misrepresent availability of loss mitigation programs',
              'Cannot provide inaccurate payoff amounts'
            ],
            violationPatterns: [
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['false default', 'incorrect balance', 'misrepresented amount', 'inaccurate payoff'],
                severity: 'critical'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['loss mitigation options', 'foreclosure options', 'modification availability'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages or $50 statutory minimum. Treble damages up to $1,000. NY AG enforcement action. Injunctive relief. Attorney fees.'
          }
        ]
      }

    }
  },

  // -----------------------------------------------------------------------
  // Texas
  // -----------------------------------------------------------------------
  TX: {
    stateCode: 'TX',
    stateName: 'Texas',
    statutes: {

      // -------------------------------------------------------------------
      // Texas Property Code — Foreclosure Procedures
      // -------------------------------------------------------------------
      tx_property_code: {
        id: 'tx_property_code',
        name: 'Texas Property Code — Foreclosure Procedures',
        citation: 'Tex. Prop. Code §§ 51.001-51.016',
        enforcementBody: 'TX OCCC / TX Courts',
        sections: [
          {
            id: 'tx_prop_foreclosure_notice',
            section: '§ 51.002',
            title: 'Notice of Foreclosure Sale',
            regulatoryReference: 'Tex. Prop. Code § 51.002',
            requirements: [
              'Written notice of default and intent to accelerate must be sent by certified mail',
              'Borrower must be given at least 20 days to cure default before acceleration',
              'Notice of sale must be posted at courthouse door, filed with county clerk, and served on borrower at least 21 days before sale',
              'Sale must occur on first Tuesday of the month between 10 AM and 4 PM'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['foreclosure notice', 'cure period', '20 day cure', 'notice of sale', 'first tuesday'],
                severity: 'critical'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['default notice', 'acceleration notice', 'sale posting', 'certified mail'],
                severity: 'critical'
              }
            ],
            penalties: 'Foreclosure sale is voidable. Wrongful foreclosure damages. Quiet title action. Attorney fees and costs.'
          },
          {
            id: 'tx_prop_acceleration',
            section: '§ 51.002(d)',
            title: 'Acceleration and Right to Cure',
            regulatoryReference: 'Tex. Prop. Code § 51.002(d)',
            requirements: [
              'Separate notice of intent to accelerate required before notice of acceleration',
              'Borrower must have opportunity to cure before acceleration takes effect',
              'Notice must specify the default and the action required to cure',
              'Acceleration is void without proper notice sequence'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['acceleration notice', 'intent to accelerate', 'cure notice', 'acceleration sequence'],
                severity: 'critical'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['acceleration timing', 'cure period', 'premature acceleration'],
                severity: 'high'
              }
            ],
            penalties: 'Acceleration is void. Foreclosure sale set aside. Actual damages. Attorney fees.'
          },
          {
            id: 'tx_prop_rescue_fraud',
            section: '§ 51.016',
            title: 'Foreclosure Rescue Transaction Protections',
            regulatoryReference: 'Tex. Prop. Code § 51.016',
            requirements: [
              'Foreclosure rescue transactions must be in writing',
              'Homeowner has right to cancel within specified period',
              'Equity purchaser must provide fair consideration',
              'Prohibited from taking unconscionable advantage of homeowner in foreclosure'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'unusual_value',
                keywords: ['rescue fraud', 'equity stripping', 'foreclosure rescue', 'unconscionable'],
                severity: 'critical'
              }
            ],
            penalties: 'Transaction is voidable. Actual damages. Exemplary damages. Attorney fees and court costs.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // Texas Finance Code — Mortgage Servicer Licensing
      // -------------------------------------------------------------------
      tx_finance_code: {
        id: 'tx_finance_code',
        name: 'Texas Finance Code — Residential Mortgage Loan Servicers',
        citation: 'Tex. Fin. Code §§ 156.001-157.031',
        enforcementBody: 'TX SML / TX OCCC',
        sections: [
          {
            id: 'tx_fin_licensing',
            section: '§ 156.201',
            title: 'Mortgage Servicer Licensing Requirements',
            regulatoryReference: 'Tex. Fin. Code § 156.201',
            requirements: [
              'Mortgage servicers must obtain license from TX SML before servicing loans in Texas',
              'Must maintain minimum net worth and surety bond requirements',
              'Annual license renewal and reporting to SML required',
              'Must designate qualified individual as responsible for servicing operations'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['unlicensed servicer', 'servicer license', 'sml registration'],
                severity: 'critical'
              }
            ],
            penalties: 'Administrative penalties up to $25,000 per violation per day. License revocation. Cease and desist orders. Criminal penalties for willful violations.'
          },
          {
            id: 'tx_fin_escrow_requirements',
            section: '§ 156.303',
            title: 'Escrow and Trust Account Requirements',
            regulatoryReference: 'Tex. Fin. Code § 156.303',
            requirements: [
              'Must maintain borrower escrow funds in federally insured depository',
              'Cannot commingle escrow funds with operating funds',
              'Must make timely disbursement of escrow funds for taxes and insurance',
              'Must provide annual escrow analysis statement to borrower'
            ],
            violationPatterns: [
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['escrow fund', 'commingling', 'escrow disbursement', 'trust account'],
                severity: 'critical'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['late disbursement', 'escrow delay', 'tax payment late', 'insurance payment late'],
                severity: 'high'
              }
            ],
            penalties: 'Administrative penalties up to $25,000 per violation. License suspension or revocation. Restitution to borrowers.'
          },
          {
            id: 'tx_fin_books_records',
            section: '§ 157.012',
            title: 'Books and Records Requirements',
            regulatoryReference: 'Tex. Fin. Code § 157.012',
            requirements: [
              'Must maintain books and records for each mortgage loan serviced',
              'Records must be available for examination by SML',
              'Must retain records for at least 4 years after loan payoff',
              'Must maintain proper accounting of all borrower payments'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['missing records', 'recordkeeping', 'books and records', 'payment records'],
                severity: 'medium'
              }
            ],
            penalties: 'Administrative penalties. License suspension. Consent order or cease and desist.'
          },
          {
            id: 'tx_fin_payment_processing',
            section: '§ 156.304',
            title: 'Payment Processing Standards',
            regulatoryReference: 'Tex. Fin. Code § 156.304',
            requirements: [
              'Must credit payments as of the date received',
              'Must apply payments in order specified by loan documents',
              'Cannot charge late fee if payment received within grace period',
              'Must provide receipt or confirmation of payment upon request'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['payment crediting', 'late crediting', 'payment processing delay'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'calculation_error',
                keywords: ['improper late fee', 'grace period', 'late charge', 'payment misapplication'],
                severity: 'high'
              }
            ],
            penalties: 'Administrative penalties up to $25,000 per violation. Refund of improper fees. License sanctions.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // Texas Debt Collection Act
      // -------------------------------------------------------------------
      tx_debt_collection: {
        id: 'tx_debt_collection',
        name: 'Texas Debt Collection Act',
        citation: 'Tex. Fin. Code §§ 392.001-392.404',
        enforcementBody: 'TX AG / Private Right of Action',
        sections: [
          {
            id: 'tx_debt_threats',
            section: '§ 392.301',
            title: 'Threats or Coercion',
            regulatoryReference: 'Tex. Fin. Code § 392.301',
            requirements: [
              'No threats of violence or criminal prosecution to collect debt',
              'No threats to take action that cannot legally be taken',
              'No threat to seize property without proper legal authority',
              'No oppressive or abusive collection methods'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['threat', 'coercion', 'abusive collection', 'unlawful threat'],
                severity: 'high'
              }
            ],
            penalties: 'Injunctive relief. Actual damages. Statutory penalty determined by court. Attorney fees. AG enforcement action up to $20,000 per violation.'
          },
          {
            id: 'tx_debt_harassment',
            section: '§ 392.302',
            title: 'Harassment and Abuse',
            regulatoryReference: 'Tex. Fin. Code § 392.302',
            requirements: [
              'No use of profane or obscene language in collection communications',
              'No unreasonable publication of consumer debt information',
              'No communication at unreasonable hours (before 8 AM or after 9 PM)'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['harassment', 'abusive language', 'unreasonable contact', 'collection abuse'],
                severity: 'medium'
              }
            ],
            penalties: 'Injunctive relief. Actual damages. Attorney fees. AG enforcement up to $20,000 per violation.'
          },
          {
            id: 'tx_debt_false_representation',
            section: '§ 392.304',
            title: 'Fraudulent, Deceptive, or Misleading Representations',
            regulatoryReference: 'Tex. Fin. Code § 392.304',
            requirements: [
              'Cannot misrepresent the character, extent, or amount of debt',
              'Cannot falsely represent that debt collection is authorized by government',
              'Cannot use false or deceptive means to collect or attempt to collect debt',
              'Cannot misrepresent the status or urgency of legal proceedings'
            ],
            violationPatterns: [
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['false representation', 'incorrect amount', 'misrepresented debt', 'deceptive collection'],
                severity: 'critical'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'calculation_error',
                keywords: ['unauthorized fee', 'inflated amount', 'improper charge', 'deceptive charge'],
                severity: 'high'
              }
            ],
            penalties: 'Injunctive relief. Actual damages. Statutory penalties. Attorney fees and costs. AG enforcement up to $20,000 per violation.'
          }
        ]
      }

    }
  },

  // -----------------------------------------------------------------------
  // Florida
  // -----------------------------------------------------------------------
  FL: {
    stateCode: 'FL',
    stateName: 'Florida',
    statutes: {

      // -------------------------------------------------------------------
      // Florida Fair Foreclosure Act
      // -------------------------------------------------------------------
      fl_fair_foreclosure: {
        id: 'fl_fair_foreclosure',
        name: 'Florida Fair Foreclosure Act',
        citation: 'Fla. Stat. §§ 702.01-702.15',
        enforcementBody: 'FL OFR / FL Courts',
        sections: [
          {
            id: 'fl_foreclosure_complaint',
            section: '§ 702.015',
            title: 'Foreclosure Complaint Requirements',
            regulatoryReference: 'Fla. Stat. § 702.015',
            requirements: [
              'Complaint must include certification of compliance with pre-suit notice requirements',
              'Plaintiff must attach the original note or establish lost-note standing',
              'Complaint must identify the holder of the note and the servicer',
              'Plaintiff must verify the accuracy of the amounts alleged in the complaint'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['foreclosure complaint', 'original note', 'lost note', 'standing to foreclose'],
                severity: 'critical'
              },
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['complaint verification', 'amount accuracy', 'foreclosure standing'],
                severity: 'high'
              }
            ],
            penalties: 'Defective foreclosure is voidable. Dismissal of complaint. Sanctions for filing without standing. Attorney fees and costs.'
          },
          {
            id: 'fl_foreclosure_mediation',
            section: '§ 702.12',
            title: 'Foreclosure Mediation Program',
            regulatoryReference: 'Fla. Stat. § 702.12',
            requirements: [
              'Servicer must participate in court-ordered mediation in good faith',
              'Servicer representative must have authority to modify loan terms at mediation',
              'Required documents must be provided to borrower at least 10 days before mediation',
              'Servicer must consider all available loss mitigation options during mediation'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['mediation documents', 'mediation notice', 'loss mitigation mediation'],
                severity: 'high'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['mediation deadline', 'mediation scheduling', '10 day mediation'],
                severity: 'medium'
              }
            ],
            penalties: 'Sanctions for bad faith. Court may dismiss foreclosure action. Attorney fees and costs awarded to borrower.'
          },
          {
            id: 'fl_lis_pendens',
            section: '§ 48.23',
            title: 'Lis Pendens Requirements',
            regulatoryReference: 'Fla. Stat. § 48.23',
            requirements: [
              'Lis pendens must be recorded in the county where the property is located',
              'Must include a description of the property sufficient for identification',
              'Must be served on all parties with an interest in the property',
              'Lis pendens expires after one year unless extended by court order'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['lis pendens', 'property notice', 'foreclosure filing', 'public record'],
                severity: 'medium'
              }
            ],
            penalties: 'Lis pendens may be discharged. Foreclosure sale may be set aside. Actual damages for improper recording.'
          },
          {
            id: 'fl_foreclosure_service',
            section: '§ 702.06',
            title: 'Service of Process in Foreclosure',
            regulatoryReference: 'Fla. Stat. § 702.06',
            requirements: [
              'All parties with an interest in the property must be properly served',
              'Service by publication allowed only after diligent search and inquiry',
              'Affidavit of diligent search must document all search efforts',
              'Default may not be entered until proper service is completed'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['service of process', 'diligent search', 'foreclosure service', 'default entry'],
                severity: 'high'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['service affidavit', 'process server', 'service documentation'],
                severity: 'high'
              }
            ],
            penalties: 'Foreclosure judgment is voidable. Default may be set aside. Actual damages for defective service.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // Florida Consumer Collection Practices Act
      // -------------------------------------------------------------------
      fl_consumer_collection: {
        id: 'fl_consumer_collection',
        name: 'Florida Consumer Collection Practices Act',
        citation: 'Fla. Stat. §§ 559.55-559.785',
        enforcementBody: 'FL OFR / FL Attorney General',
        sections: [
          {
            id: 'fl_ccpa_prohibited_practices',
            section: '§ 559.72',
            title: 'Prohibited Debt Collection Practices',
            regulatoryReference: 'Fla. Stat. § 559.72',
            requirements: [
              'Debt collector must not simulate legal process or government authority',
              'Must not disclose debt information to unauthorized third parties',
              'Must not use threats of criminal prosecution for civil debts',
              'Must not misrepresent the character, amount, or legal status of the debt'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['simulated process', 'false representation', 'debt misrepresentation', 'unauthorized disclosure'],
                severity: 'critical'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['debt validation', 'collection notice', 'amount verification'],
                severity: 'high'
              }
            ],
            penalties: 'Statutory damages $500 to $1,000 per violation. Actual damages. Attorney fees and court costs. Injunctive relief.'
          },
          {
            id: 'fl_ccpa_harassment',
            section: '§ 559.72(7)',
            title: 'Prohibition of Harassment and Abuse',
            regulatoryReference: 'Fla. Stat. § 559.72(7)',
            requirements: [
              'Must not use obscene or profane language in communications',
              'Must not call at unreasonable hours (before 8 a.m. or after 9 p.m.)',
              'Must not engage in repeated phone calls intended to harass',
              'Must not threaten violence or harm to person, reputation, or property'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'pattern_anomaly',
                keywords: ['harassment', 'repeated calls', 'unreasonable hours', 'abusive communication'],
                severity: 'high'
              }
            ],
            penalties: 'Statutory damages $500 to $1,000 per violation. Actual damages. Criminal penalties for willful violations. Attorney fees.'
          },
          {
            id: 'fl_ccpa_misrepresentation',
            section: '§ 559.72(9)',
            title: 'Prohibition of Misrepresentation',
            regulatoryReference: 'Fla. Stat. § 559.72(9)',
            requirements: [
              'Must not claim or threaten legal action that is not actually intended',
              'Must not misrepresent affiliation with government agencies',
              'Must accurately disclose the creditor and amount owed',
              'Must not use deceptive forms or documents that simulate court process'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['misrepresentation', 'false claim', 'deceptive form', 'simulated process'],
                severity: 'high'
              }
            ],
            penalties: 'Statutory damages $500 to $1,000. Actual damages. Attorney fees and costs. AG enforcement action.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // Florida Mortgage Lending Act
      // -------------------------------------------------------------------
      fl_mortgage_lending: {
        id: 'fl_mortgage_lending',
        name: 'Florida Mortgage Lending Act',
        citation: 'Fla. Stat. §§ 494.001-494.0079',
        enforcementBody: 'FL OFR',
        sections: [
          {
            id: 'fl_mla_licensing',
            section: '§ 494.003',
            title: 'Mortgage Servicer Licensing Requirements',
            regulatoryReference: 'Fla. Stat. § 494.003',
            requirements: [
              'Mortgage servicers must hold a valid Florida license to service loans secured by Florida property',
              'License application must include surety bond and financial statements',
              'Servicer must maintain minimum net worth requirements',
              'License must be renewed annually with the Office of Financial Regulation'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['unlicensed servicer', 'florida license', 'ofr registration', 'servicer licensing'],
                severity: 'critical'
              }
            ],
            penalties: 'Administrative fines up to $10,000 per violation. License suspension or revocation. Cease and desist orders.'
          },
          {
            id: 'fl_mla_disclosures',
            section: '§ 494.0038',
            title: 'Mortgage Lending Disclosure Requirements',
            regulatoryReference: 'Fla. Stat. § 494.0038',
            requirements: [
              'Must provide good-faith estimate of all charges and fees before closing',
              'Disclosure must include annual percentage rate and total finance charges',
              'Must disclose whether servicing rights may be transferred',
              'Written disclosure of mortgage broker fees and compensation required'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['disclosure failure', 'good faith estimate', 'fee disclosure', 'servicing transfer disclosure'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['undisclosed fee', 'broker compensation', 'hidden charge', 'finance charge'],
                severity: 'high'
              }
            ],
            penalties: 'Administrative fines. License revocation. Borrower entitled to actual damages and attorney fees.'
          },
          {
            id: 'fl_mla_prohibited_practices',
            section: '§ 494.0042',
            title: 'Prohibited Mortgage Lending Practices',
            regulatoryReference: 'Fla. Stat. § 494.0042',
            requirements: [
              'Must not charge excessive fees beyond those disclosed at origination',
              'Must not induce borrower to refinance for sole benefit of servicer',
              'Must not misrepresent material terms of the loan',
              'Must not engage in fraud, misrepresentation, or deceit in mortgage transactions'
            ],
            violationPatterns: [
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['excessive fee', 'prohibited charge', 'undisclosed cost', 'loan churning'],
                severity: 'high'
              },
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['misrepresentation', 'loan fraud', 'deceptive practice', 'material misstatement'],
                severity: 'critical'
              }
            ],
            penalties: 'Administrative fines up to $10,000 per violation. License suspension or revocation. Criminal penalties for fraud. Borrower damages.'
          }
        ]
      }

    }
  },

  // -----------------------------------------------------------------------
  // Illinois
  // -----------------------------------------------------------------------
  IL: {
    stateCode: 'IL',
    stateName: 'Illinois',
    statutes: {

      // -------------------------------------------------------------------
      // Illinois Mortgage Foreclosure Law
      // -------------------------------------------------------------------
      il_foreclosure_law: {
        id: 'il_foreclosure_law',
        name: 'Illinois Mortgage Foreclosure Law',
        citation: '735 ILCS 5/15-1101 through 15-1605',
        enforcementBody: 'IL IDFPR / IL Courts',
        sections: [
          {
            id: 'il_foreclosure_notice',
            section: '§ 15-1502.5',
            title: 'Grace Period and Pre-Foreclosure Notice',
            regulatoryReference: '735 ILCS 5/15-1502.5',
            requirements: [
              'Servicer must provide 30-day grace period notice before filing foreclosure',
              'Notice must include total amount required to cure the default',
              'Notice must inform borrower of available housing counseling resources',
              'Notice must be sent by certified mail and first-class mail to last known address'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['30 day grace period', 'pre-foreclosure notice', 'cure period', 'grace period notice'],
                severity: 'critical'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['foreclosure notice', 'cure notice', 'housing counseling', 'certified mail'],
                severity: 'high'
              }
            ],
            penalties: 'Foreclosure action may be dismissed. Borrower entitled to reinstatement. Attorney fees and costs.'
          },
          {
            id: 'il_foreclosure_reinstatement',
            section: '§ 15-1602',
            title: 'Right to Reinstate Mortgage',
            regulatoryReference: '735 ILCS 5/15-1602',
            requirements: [
              'Borrower has right to reinstate by curing default up to 90 days after service of summons',
              'Reinstatement requires payment of all amounts due plus reasonable costs and attorney fees',
              'Servicer must provide accurate reinstatement amount upon written request',
              'Servicer must accept reinstatement payment and cease foreclosure proceedings'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['reinstatement right', 'reinstatement period', '90 day reinstatement', 'cure default'],
                severity: 'high'
              },
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['reinstatement amount', 'cure amount', 'reinstatement calculation', 'payoff error'],
                severity: 'high'
              }
            ],
            penalties: 'Borrower may reinstate despite servicer refusal. Foreclosure sale may be set aside. Actual damages and attorney fees.'
          },
          {
            id: 'il_foreclosure_judicial',
            section: '§ 15-1506',
            title: 'Judicial Foreclosure Requirements',
            regulatoryReference: '735 ILCS 5/15-1506',
            requirements: [
              'All foreclosures must proceed through judicial process in Illinois',
              'Complaint must include the original or a copy of the note and mortgage',
              'Servicer must demonstrate standing by establishing chain of assignments',
              'Court must enter judgment of foreclosure before any sale may occur'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['judicial foreclosure', 'foreclosure complaint', 'note and mortgage', 'chain of assignments'],
                severity: 'critical'
              },
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['foreclosure standing', 'assignment chain', 'note holder', 'mortgage holder'],
                severity: 'high'
              }
            ],
            penalties: 'Foreclosure judgment is voidable. Dismissal of complaint for lack of standing. Attorney fees and costs.'
          },
          {
            id: 'il_foreclosure_loss_mitigation',
            section: '§ 15-1502.5(c)',
            title: 'Loss Mitigation and Mediation Requirements',
            regulatoryReference: '735 ILCS 5/15-1502.5(c)',
            requirements: [
              'Servicer must provide information about loss mitigation options in pre-foreclosure notice',
              'Must inform borrower of right to request loss mitigation review',
              'Servicer must evaluate borrower for all available workout options',
              'Mediation may be ordered by the court in counties with mediation programs'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['loss mitigation', 'workout options', 'mediation program', 'foreclosure prevention'],
                severity: 'high'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['loss mitigation review', 'mediation deadline', 'workout evaluation'],
                severity: 'medium'
              }
            ],
            penalties: 'Court may stay foreclosure proceedings. Dismissal if loss mitigation not offered. Attorney fees.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // Illinois Residential Mortgage License Act
      // -------------------------------------------------------------------
      il_mortgage_license: {
        id: 'il_mortgage_license',
        name: 'Illinois Residential Mortgage License Act',
        citation: '205 ILCS 635',
        enforcementBody: 'IL IDFPR',
        sections: [
          {
            id: 'il_rmla_licensing',
            section: '§ 635/1-4',
            title: 'Mortgage Servicer Licensing Requirements',
            regulatoryReference: '205 ILCS 635/1-4',
            requirements: [
              'All mortgage servicers operating in Illinois must be licensed by IDFPR',
              'License application must include surety bond and audited financial statements',
              'Servicer must maintain minimum net worth as prescribed by IDFPR rules',
              'License must be renewed annually and servicer must report material changes'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['unlicensed servicer', 'idfpr license', 'servicer registration', 'licensing requirement'],
                severity: 'critical'
              }
            ],
            penalties: 'Administrative fines up to $25,000. License suspension or revocation. Cease and desist orders. Criminal penalties for willful violations.'
          },
          {
            id: 'il_rmla_prohibited',
            section: '§ 635/3-2',
            title: 'Prohibited Servicing Practices',
            regulatoryReference: '205 ILCS 635/3-2',
            requirements: [
              'Must not charge fees not authorized by the loan documents or applicable law',
              'Must not pyramid late charges on top of previously assessed late fees',
              'Must not misapply payments or fail to credit payments as of the date received',
              'Must not force-place insurance without proper notice and opportunity to provide own coverage'
            ],
            violationPatterns: [
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['unauthorized fee', 'pyramided late fee', 'force-placed insurance', 'improper charge'],
                severity: 'high'
              },
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['payment misapplication', 'payment crediting', 'late fee pyramid', 'insurance overcharge'],
                severity: 'high'
              }
            ],
            penalties: 'Administrative fines. License revocation. Borrower entitled to actual damages and statutory penalties. Attorney fees.'
          },
          {
            id: 'il_rmla_disclosures',
            section: '§ 635/3-5',
            title: 'Disclosure and Reporting Requirements',
            regulatoryReference: '205 ILCS 635/3-5',
            requirements: [
              'Must provide annual escrow account statements to borrowers',
              'Must disclose all fees and charges assessed against the loan',
              'Must provide periodic statements showing payment application and balances',
              'Must notify borrower of servicing transfer at least 15 days before effective date'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['escrow statement', 'fee disclosure', 'periodic statement', 'transfer notice'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['undisclosed fee', 'escrow discrepancy', 'statement error', 'balance discrepancy'],
                severity: 'medium'
              }
            ],
            penalties: 'Administrative penalties. Corrective action orders. Borrower damages for undisclosed fees.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // Illinois Consumer Fraud and Deceptive Business Practices Act
      // -------------------------------------------------------------------
      il_consumer_fraud: {
        id: 'il_consumer_fraud',
        name: 'Illinois Consumer Fraud and Deceptive Business Practices Act',
        citation: '815 ILCS 505',
        enforcementBody: 'IL Attorney General / IL Courts',
        sections: [
          {
            id: 'il_cfa_deceptive_mortgage',
            section: '§ 505/2',
            title: 'Deceptive Practices in Mortgage Servicing',
            regulatoryReference: '815 ILCS 505/2',
            requirements: [
              'Servicer must not engage in unfair or deceptive acts in mortgage servicing',
              'Must not make false or misleading statements regarding loan terms or status',
              'Must not conceal material facts from borrowers about their loans',
              'Must not employ deceptive methods to collect payments or fees'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['deceptive practice', 'misleading statement', 'concealed fact', 'unfair act'],
                severity: 'critical'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['material disclosure', 'loan status', 'concealment', 'borrower notification'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages. Punitive damages for willful or wanton violations. Attorney fees and costs. AG civil penalties up to $50,000.'
          },
          {
            id: 'il_cfa_unfair_collection',
            section: '§ 505/2AA',
            title: 'Unfair Mortgage Collection Practices',
            regulatoryReference: '815 ILCS 505/2AA',
            requirements: [
              'Must not misrepresent the amount owed on a mortgage obligation',
              'Must not threaten foreclosure action that is not actually intended',
              'Must not assess charges or fees not authorized by the loan agreement',
              'Must accurately report payment history to credit reporting agencies'
            ],
            violationPatterns: [
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['amount misrepresentation', 'balance discrepancy', 'payment history error', 'credit reporting'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['unauthorized charge', 'improper fee', 'collection fee', 'unfair assessment'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages. Statutory damages. Punitive damages. Attorney fees and costs. Injunctive relief.'
          },
          {
            id: 'il_cfa_consumer_protection',
            section: '§ 505/10a',
            title: 'Consumer Protection Remedies',
            regulatoryReference: '815 ILCS 505/10a',
            requirements: [
              'Private right of action available for any person damaged by violation',
              'Class actions permitted for pattern or practice violations',
              'Borrower must provide 30-day written demand letter before filing suit',
              'Attorney General may pursue enforcement for systemic violations'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'pattern_anomaly',
                keywords: ['pattern violation', 'systemic practice', 'repeated violation', 'class action'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages or $100 per violation (whichever is greater). Attorney fees and costs. Injunctive relief. AG penalties up to $50,000.'
          }
        ]
      }

    }
  },

  // -----------------------------------------------------------------------
  // Massachusetts
  // -----------------------------------------------------------------------
  MA: {
    stateCode: 'MA',
    stateName: 'Massachusetts',
    statutes: {

      // -------------------------------------------------------------------
      // Predatory Home Loan Practices Act
      // -------------------------------------------------------------------
      ma_predatory_lending: {
        id: 'ma_predatory_lending',
        name: 'Predatory Home Loan Practices Act',
        citation: 'Mass. Gen. Laws ch. 183C',
        enforcementBody: 'MA DOB / MA Attorney General',
        sections: [
          {
            id: 'ma_ch183c_prohibited_terms',
            section: '§ 183C-3',
            title: 'Prohibited Loan Terms',
            regulatoryReference: 'Mass. Gen. Laws ch. 183C § 3',
            requirements: [
              'High-cost home mortgage loans must not include prepayment penalties exceeding 2% of amount prepaid',
              'Must not include balloon payments due in less than 7 years',
              'Must not finance credit insurance or debt cancellation products',
              'Must not include negative amortization provisions in high-cost loans'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['prepayment penalty', 'balloon payment', 'credit insurance', 'negative amortization'],
                severity: 'critical'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['prohibited term', 'high-cost loan', 'financed insurance', 'excessive prepayment'],
                severity: 'critical'
              }
            ],
            penalties: 'Loan terms are unenforceable. Borrower entitled to actual damages. Attorney fees and costs. AG enforcement.'
          },
          {
            id: 'ma_ch183c_disclosures',
            section: '§ 183C-4',
            title: 'Disclosure Requirements for High-Cost Loans',
            regulatoryReference: 'Mass. Gen. Laws ch. 183C § 4',
            requirements: [
              'Must provide written notice that loan qualifies as a high-cost home mortgage loan',
              'Must disclose the annual percentage rate and total cost of the loan',
              'Borrower must receive disclosures at least 3 days before closing',
              'Must advise borrower in writing to seek independent legal counsel'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['high-cost disclosure', 'apr disclosure', 'pre-closing notice', 'legal counsel advisory'],
                severity: 'high'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['3 day disclosure', 'closing disclosure timing', 'pre-closing period'],
                severity: 'high'
              }
            ],
            penalties: 'Loan may be rescinded. Actual damages. Statutory penalties. Attorney fees and costs.'
          },
          {
            id: 'ma_ch183c_fee_limits',
            section: '§ 183C-5',
            title: 'Fee Limitations',
            regulatoryReference: 'Mass. Gen. Laws ch. 183C § 5',
            requirements: [
              'Points and fees must not exceed 5% of the total loan amount for high-cost loans',
              'Late payment charges limited to 4% of the overdue payment amount',
              'Must not charge fees for payoff statement preparation',
              'Must not charge fees for providing account information to borrower'
            ],
            violationPatterns: [
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['excessive points', 'fee limit', 'late charge limit', 'payoff statement fee'],
                severity: 'high'
              },
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['points and fees', 'fee calculation', 'late fee percentage', 'fee threshold'],
                severity: 'high'
              }
            ],
            penalties: 'Refund of excess fees. Actual damages. Attorney fees. Administrative penalties by DOB.'
          },
          {
            id: 'ma_ch183c_flipping',
            section: '§ 183C-6',
            title: 'Prohibition of Loan Flipping',
            regulatoryReference: 'Mass. Gen. Laws ch. 183C § 6',
            requirements: [
              'Must not refinance a high-cost loan within 60 months unless refinancing provides net tangible benefit',
              'Net tangible benefit must be documented and provided to borrower in writing',
              'Must not encourage default on an existing loan to facilitate refinancing',
              'Must verify borrower ability to repay before refinancing'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'pattern_anomaly',
                keywords: ['loan flipping', 'serial refinancing', 'net tangible benefit', 'encouraged default'],
                severity: 'critical'
              }
            ],
            penalties: 'Refinanced loan terms unenforceable. Actual damages. Treble damages for willful violations. Attorney fees.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // Right to Cure Law
      // -------------------------------------------------------------------
      ma_right_to_cure: {
        id: 'ma_right_to_cure',
        name: 'Right to Cure Law',
        citation: 'Mass. Gen. Laws ch. 244 § 35A',
        enforcementBody: 'MA DOB / MA Courts',
        sections: [
          {
            id: 'ma_rtc_150_day_notice',
            section: '§ 244-35A(a)',
            title: '150-Day Right to Cure Notice',
            regulatoryReference: 'Mass. Gen. Laws ch. 244 § 35A(a)',
            requirements: [
              'Servicer must send 150-day right to cure notice before accelerating the mortgage',
              'Notice must specify the nature of the default and amount required to cure',
              'Notice must inform borrower of right to dispute the debt and request verification',
              'Must include information about available housing counseling services'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['150 day notice', 'right to cure', 'pre-acceleration notice', 'cure period'],
                severity: 'critical'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['cure notice', 'default notice', 'cure amount', 'housing counseling notice'],
                severity: 'critical'
              }
            ],
            penalties: 'Foreclosure is void and unenforceable. Borrower entitled to damages. Attorney fees and costs.'
          },
          {
            id: 'ma_rtc_notice_requirements',
            section: '§ 244-35A(b)',
            title: 'Cure Notice Content and Delivery Requirements',
            regulatoryReference: 'Mass. Gen. Laws ch. 244 § 35A(b)',
            requirements: [
              'Notice must be sent by registered or certified mail and by first-class mail',
              'Must include a description of the action required to cure the default',
              'Must specify the date by which the borrower must cure the default',
              'Must include a statement that the borrower has the right to bring a court action'
            ],
            violationPatterns: [
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['registered mail', 'certified mail', 'cure instructions', 'court action notice'],
                severity: 'high'
              },
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['cure deadline', 'notice timing', 'delivery requirement', 'cure date'],
                severity: 'high'
              }
            ],
            penalties: 'Foreclosure sale may be set aside. Actual damages. Attorney fees and costs.'
          },
          {
            id: 'ma_rtc_cure_protections',
            section: '§ 244-35A(c)',
            title: 'Borrower Cure Period Protections',
            regulatoryReference: 'Mass. Gen. Laws ch. 244 § 35A(c)',
            requirements: [
              'Servicer must accept cure payment tendered within the 150-day period',
              'Must not accelerate the loan while the cure period is active',
              'Must not initiate foreclosure proceedings during the cure period',
              'Cure payment must restore the loan to current status as of the date of the default'
            ],
            violationPatterns: [
              {
                discrepancyType: 'timeline_violation',
                anomalyType: 'regulatory_concern',
                keywords: ['premature acceleration', 'cure period violation', 'early foreclosure', 'cure rejection'],
                severity: 'critical'
              },
              {
                discrepancyType: 'amount_mismatch',
                anomalyType: 'unusual_value',
                keywords: ['cure amount error', 'reinstatement calculation', 'cure payment', 'balance discrepancy'],
                severity: 'high'
              }
            ],
            penalties: 'Foreclosure is void. Borrower entitled to actual damages. Treble damages for willful violations. Attorney fees.'
          }
        ]
      },

      // -------------------------------------------------------------------
      // Consumer Protection Act (Chapter 93A)
      // -------------------------------------------------------------------
      ma_chapter_93a: {
        id: 'ma_chapter_93a',
        name: 'Consumer Protection Act (Chapter 93A)',
        citation: 'Mass. Gen. Laws ch. 93A',
        enforcementBody: 'MA Attorney General / MA Courts',
        sections: [
          {
            id: 'ma_93a_unfair_practices',
            section: '§ 93A-2',
            title: 'Unfair or Deceptive Practices in Mortgage Servicing',
            regulatoryReference: 'Mass. Gen. Laws ch. 93A § 2',
            requirements: [
              'Servicer must not engage in unfair or deceptive acts in mortgage servicing',
              'Must not misrepresent the terms, status, or balance of a mortgage loan',
              'Must not use deceptive methods to collect payments or foreclose',
              'Must respond to consumer complaints within 30 days'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'regulatory_concern',
                keywords: ['unfair practice', 'deceptive act', 'misrepresentation', 'balance misstatement'],
                severity: 'critical'
              },
              {
                discrepancyType: 'missing_correspondence',
                anomalyType: 'missing_required',
                keywords: ['complaint response', 'consumer complaint', '30 day response', 'borrower inquiry'],
                severity: 'high'
              }
            ],
            penalties: 'Actual damages or $25 per violation (whichever is greater). Treble damages up to $25,000 for willful or knowing violations. Attorney fees and costs.'
          },
          {
            id: 'ma_93a_treble_damages',
            section: '§ 93A-9',
            title: 'Treble Damages and Enforcement',
            regulatoryReference: 'Mass. Gen. Laws ch. 93A § 9',
            requirements: [
              'Consumer must send 30-day demand letter before filing suit under Chapter 93A',
              'Servicer must make reasonable settlement offer within 30 days of demand letter',
              'Failure to make reasonable offer may result in treble damages',
              'Court may award up to three times actual damages for willful or knowing violations'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'pattern_anomaly',
                keywords: ['demand letter', 'settlement offer', 'willful violation', 'knowing violation'],
                severity: 'high'
              },
              {
                discrepancyType: 'fee_irregularity',
                anomalyType: 'unusual_value',
                keywords: ['treble damages', 'punitive damages', 'settlement refusal', 'enforcement action'],
                severity: 'high'
              }
            ],
            penalties: 'Treble damages (up to 3x actual damages). Minimum $25 per violation. Attorney fees and costs. Injunctive relief.'
          },
          {
            id: 'ma_93a_ag_enforcement',
            section: '§ 93A-4',
            title: 'Attorney General Enforcement Authority',
            regulatoryReference: 'Mass. Gen. Laws ch. 93A § 4',
            requirements: [
              'Attorney General may investigate unfair or deceptive practices by mortgage servicers',
              'AG may seek civil penalties for pattern or practice violations',
              'AG may obtain injunctive relief to prevent ongoing violations',
              'Servicer must cooperate with AG investigation and produce requested records'
            ],
            violationPatterns: [
              {
                discrepancyType: 'term_contradiction',
                anomalyType: 'pattern_anomaly',
                keywords: ['ag investigation', 'pattern violation', 'systemic practice', 'regulatory enforcement'],
                severity: 'high'
              }
            ],
            penalties: 'Civil penalties up to $5,000 per violation. Injunctive relief. Restitution. Dissolution of business for repeated violations.'
          }
        ]
      }

    }
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
