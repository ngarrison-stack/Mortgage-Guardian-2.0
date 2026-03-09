/**
 * State Compliance Rule Mappings Configuration
 *
 * Maps forensic analysis findings to state-specific statute violations, mirroring
 * the structure and matching logic of the federal complianceRuleMappings.js.
 *
 * Each rule follows the identical shape as federal rules so the compliance engine
 * can process state rules with the same code path.
 *
 * Section IDs reference stateStatuteTaxonomy.js.
 * Total: ~34 rules across 6 priority states (CA, NY, TX, FL, IL, MA).
 */

// ---------------------------------------------------------------------------
// Severity ordering (identical to federal complianceRuleMappings.js)
// ---------------------------------------------------------------------------
const SEVERITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3, info: 4 };

// ---------------------------------------------------------------------------
// STATE_COMPLIANCE_RULE_MAPPINGS — keyed by 2-letter state code
// ---------------------------------------------------------------------------

const STATE_COMPLIANCE_RULE_MAPPINGS = {

  // =========================================================================
  // CALIFORNIA — 8 rules
  // =========================================================================
  CA: [

    // CA HBOR — Dual Tracking
    {
      ruleId: 'rule-ca-hbor-001',
      sectionId: 'ca_hbor_dual_tracking',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation'],
        anomalyTypes: ['regulatory_concern'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['dual tracking', 'foreclosure during review', 'simultaneous foreclosure', 'pending application', 'loss mitigation pending'],
        fieldPatterns: ['foreclosure*', 'lossMit*', 'dualTrack*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'CA HBOR dual tracking violation: {description}. Foreclosure proceedings advanced while loss mitigation application was pending.',
      legalBasisTemplate: 'Cal. Civ. Code § 2924.11 prohibits recording a notice of default or notice of sale while a complete first lien loss mitigation application is pending. Borrower may obtain injunctive relief and recover damages.'
    },

    // CA HBOR — Single Point of Contact
    {
      ruleId: 'rule-ca-hbor-002',
      sectionId: 'ca_hbor_single_poc',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['missing_correspondence'],
        anomalyTypes: ['missing_required', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['single point of contact', 'spoc', 'contact person', 'assigned representative', 'no contact'],
        fieldPatterns: ['contact*', 'spoc*', 'representative*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'CA HBOR single point of contact violation: {description}. Servicer failed to provide or maintain required single point of contact.',
      legalBasisTemplate: 'Cal. Civ. Code § 2923.7 requires servicers to assign a single point of contact upon borrower request for foreclosure prevention alternative. SPOC must be knowledgeable about the borrower\'s situation and available alternatives.'
    },

    // CA Civil Code — Escrow Accounts
    {
      ruleId: 'rule-ca-civ-001',
      sectionId: 'ca_civ_escrow_accounts',
      category: 'escrow',
      matchCriteria: {
        discrepancyTypes: ['amount_mismatch', 'calculation_error'],
        anomalyTypes: ['calculation_error', 'unusual_value'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['escrow', 'impound account', 'escrow overcharge', 'escrow surplus', 'cushion'],
        fieldPatterns: ['escrow*', 'impound*', 'cushion*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 100', 'repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'CA escrow account violation: {description}. Escrow impound account discrepancy of {amount} identified.',
      legalBasisTemplate: 'Cal. Civ. Code § 2954 limits impound accounts to amounts reasonably necessary for taxes, insurance, and other charges. Excess amounts must be returned to the borrower within 30 days.'
    },

    // CA Civil Code — Payoff Demand
    {
      ruleId: 'rule-ca-civ-002',
      sectionId: 'ca_civ_payoff_demand',
      category: 'disclosure',
      matchCriteria: {
        discrepancyTypes: ['amount_mismatch', 'timeline_violation'],
        anomalyTypes: ['inconsistency', 'regulatory_concern'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['payoff demand', 'payoff statement', 'payoff delay', 'beneficiary statement'],
        fieldPatterns: ['payoff*', 'beneficiary*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'CA payoff demand violation: {description}. Payoff demand statement not provided within required timeframe or contains inaccuracies.',
      legalBasisTemplate: 'Cal. Civ. Code § 2943 requires beneficiary to provide payoff demand statement within 21 days of written request. Failure subjects beneficiary to $500 penalty plus actual damages.'
    },

    // CA Civil Code — Transfer Disclosure
    {
      ruleId: 'rule-ca-civ-003',
      sectionId: 'ca_civ_transfer_disclosure',
      category: 'disclosure',
      matchCriteria: {
        discrepancyTypes: ['party_mismatch', 'missing_correspondence'],
        anomalyTypes: ['missing_required', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['servicing transfer', 'transfer notice', 'new servicer', 'goodbye letter', 'hello letter'],
        fieldPatterns: ['servicer*', 'transfer*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'CA servicing transfer disclosure violation: {description}. Required transfer notices not properly provided under California law.',
      legalBasisTemplate: 'Cal. Civ. Code § 2937 requires written notice to borrower when servicing is transferred. Notice must include new servicer contact information and be provided prior to or within 30 days of transfer.'
    },

    // CA Rosenthal Fair Debt Collection — Prohibited Practices
    {
      ruleId: 'rule-ca-rosenthal-001',
      sectionId: 'ca_rosenthal_prohibited_practices',
      category: 'collections',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'amount_mismatch'],
        anomalyTypes: ['unusual_value', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['collection threat', 'harassment', 'unfair collection', 'prohibited practice', 'abusive collection'],
        fieldPatterns: ['collection*', 'fee*', 'charge*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated', 'amount > 100'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'CA Rosenthal Act violation: {description}. Prohibited debt collection practice detected involving mortgage servicing.',
      legalBasisTemplate: 'Cal. Civ. Code § 1788.10-1788.15 (Rosenthal Fair Debt Collection Practices Act) prohibits threats, harassment, unfair practices, and false representations by debt collectors including original creditors collecting their own debts.'
    },

    // CA HBOR — Notice of Default
    {
      ruleId: 'rule-ca-hbor-003',
      sectionId: 'ca_hbor_notice_of_default',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['notice of default', 'nod', 'pre-foreclosure', 'default recording', '30 day contact'],
        fieldPatterns: ['default*', 'foreclosure*', 'nod*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'CA notice of default violation: {description}. Required pre-foreclosure contact or notice requirements not met.',
      legalBasisTemplate: 'Cal. Civ. Code § 2923.5 requires servicer to contact borrower by phone or in person 30 days before recording NOD to assess financial situation and explore alternatives. Failure renders NOD voidable.'
    },

    // CA Rosenthal — Validation of Debt
    {
      ruleId: 'rule-ca-rosenthal-002',
      sectionId: 'ca_rosenthal_validation',
      category: 'collections',
      matchCriteria: {
        discrepancyTypes: ['missing_correspondence'],
        anomalyTypes: ['missing_required'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['debt validation', 'validation notice', 'debt verification', 'collection notice missing'],
        fieldPatterns: ['validation*', 'collection*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'CA debt validation violation: {description}. Required debt validation notice not provided under California law.',
      legalBasisTemplate: 'Cal. Civ. Code § 1788.14(d) (Rosenthal Act) requires debt validation including amount, original creditor, and dispute rights. Applies to original creditors collecting their own debts, unlike federal FDCPA.'
    }
  ],

  // =========================================================================
  // NEW YORK — 6 rules
  // =========================================================================
  NY: [

    // NY RPAPL — Settlement Conference
    {
      ruleId: 'rule-ny-rpapl-001',
      sectionId: 'ny_rpapl_settlement_conference',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['settlement conference', 'mandatory conference', 'foreclosure conference', 'court conference'],
        fieldPatterns: ['settlement*', 'conference*', 'foreclosure*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'NY mandatory settlement conference violation: {description}. Required pre-foreclosure settlement conference not conducted or improperly handled.',
      legalBasisTemplate: 'NY RPAPL § 1304-1305 requires mandatory settlement conference in residential foreclosure cases. Court must schedule conference, and lender must negotiate in good faith. Failure may result in case dismissal.'
    },

    // NY RPAPL — Notice Requirements (90-day pre-foreclosure)
    {
      ruleId: 'rule-ny-rpapl-002',
      sectionId: 'ny_rpapl_notice_requirements',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['90-day notice', 'pre-foreclosure notice', 'rpapl 1304', 'foreclosure warning'],
        fieldPatterns: ['notice*', 'foreclosure*', 'preForeclosure*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'NY 90-day pre-foreclosure notice violation: {description}. Required 90-day notice not served or served improperly.',
      legalBasisTemplate: 'NY RPAPL § 1304 requires 90-day pre-foreclosure notice to borrower by registered or certified mail and first-class mail. Notice must include specific language about housing counseling and legal aid. Non-compliance is a condition precedent to foreclosure.'
    },

    // NY Banking Law — Servicer Obligations
    {
      ruleId: 'rule-ny-banking-001',
      sectionId: 'ny_banking_servicer_obligations',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'amount_mismatch'],
        anomalyTypes: ['unusual_value', 'calculation_error'],
        timelineViolation: false,
        paymentIssue: true,
        keywords: ['servicer obligation', 'payment processing', 'late fee', 'excessive fee', 'unauthorized charge'],
        fieldPatterns: ['fee*', 'payment*', 'charge*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 100', 'repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'NY servicer obligation violation: {description}. Servicer practices do not meet New York Banking Law requirements.',
      legalBasisTemplate: 'NY Banking Law § 6-l imposes obligations on mortgage servicers including reasonable fee limits, proper payment crediting, and timely response to borrower inquiries. DFS enforces compliance.'
    },

    // NY Banking Law — Loss Mitigation
    {
      ruleId: 'rule-ny-banking-002',
      sectionId: 'ny_banking_loss_mitigation',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['loss mitigation', 'modification review', 'application acknowledgment', 'loss mit timeline'],
        fieldPatterns: ['lossMit*', 'modification*', 'application*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'NY loss mitigation violation: {description}. Servicer failed to meet New York loss mitigation evaluation requirements.',
      legalBasisTemplate: 'NY Banking Law § 6-l(2) requires servicers to evaluate borrowers for all available loss mitigation options, provide written determinations, and allow appeal of denials. DFS regulations mandate specific timelines.'
    },

    // NY Banking Law — Escrow
    {
      ruleId: 'rule-ny-banking-003',
      sectionId: 'ny_banking_escrow',
      category: 'escrow',
      matchCriteria: {
        discrepancyTypes: ['amount_mismatch', 'calculation_error'],
        anomalyTypes: ['calculation_error', 'unusual_value'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['escrow', 'escrow account', 'impound', 'escrow interest', 'escrow surplus'],
        fieldPatterns: ['escrow*', 'impound*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 100', 'repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'NY escrow account violation: {description}. Escrow account discrepancy of {amount} under New York Banking Law.',
      legalBasisTemplate: 'NY Banking Law § 14-b requires interest on escrow accounts at rate set by Banking Board and limits escrow amounts. Servicer must provide annual accounting of escrow funds.'
    },

    // NY GBL — Deceptive Acts
    {
      ruleId: 'rule-ny-gbl-001',
      sectionId: 'ny_gbl_deceptive_acts',
      category: 'collections',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'term_contradiction'],
        anomalyTypes: ['unusual_value', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['deceptive', 'misleading', 'unfair practice', 'false representation', 'consumer fraud'],
        fieldPatterns: ['fee*', 'charge*', 'term*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'NY deceptive acts violation: {description}. Mortgage servicing practice may constitute deceptive act under GBL § 349.',
      legalBasisTemplate: 'NY General Business Law § 349 prohibits deceptive acts and practices in the conduct of business, including mortgage servicing. Consumers may recover actual damages, treble damages up to $1,000, and attorney fees.'
    }
  ],

  // =========================================================================
  // TEXAS — 5 rules
  // =========================================================================
  TX: [

    // TX Property Code — Foreclosure Notice
    {
      ruleId: 'rule-tx-prop-001',
      sectionId: 'tx_prop_foreclosure_notice',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['foreclosure notice', 'notice of sale', '21-day notice', 'certified mail', 'posting notice'],
        fieldPatterns: ['foreclosure*', 'notice*', 'sale*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'TX foreclosure notice violation: {description}. Required 21-day pre-sale notice not properly served.',
      legalBasisTemplate: 'TX Property Code § 51.002 requires at least 21 days notice before foreclosure sale by certified mail to debtor. Notice must also be posted at courthouse door and filed with county clerk. Non-compliance voids sale.'
    },

    // TX Property Code — Acceleration
    {
      ruleId: 'rule-tx-prop-002',
      sectionId: 'tx_prop_acceleration',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['acceleration', 'demand letter', 'cure notice', '20-day cure', 'acceleration notice'],
        fieldPatterns: ['acceleration*', 'cure*', 'demand*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'TX acceleration notice violation: {description}. Required pre-acceleration notice and cure period not provided.',
      legalBasisTemplate: 'TX Property Code § 51.002(d) requires at least 20 days notice to cure default before acceleration. Notice must be sent by certified mail and specify the default and actions required to cure.'
    },

    // TX Finance Code — Escrow Requirements
    {
      ruleId: 'rule-tx-fin-001',
      sectionId: 'tx_fin_escrow_requirements',
      category: 'escrow',
      matchCriteria: {
        discrepancyTypes: ['amount_mismatch', 'calculation_error'],
        anomalyTypes: ['calculation_error', 'unusual_value'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['escrow', 'tax escrow', 'insurance escrow', 'escrow overcharge', 'escrow accounting'],
        fieldPatterns: ['escrow*', 'tax*', 'insurance*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 100', 'repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'TX escrow requirements violation: {description}. Escrow account discrepancy of {amount} under Texas Finance Code.',
      legalBasisTemplate: 'TX Finance Code § 343.010 governs escrow accounts for residential mortgage loans. Servicers must maintain proper accounting and may not charge excessive escrow amounts beyond what is reasonably necessary.'
    },

    // TX Finance Code — Payment Processing
    {
      ruleId: 'rule-tx-fin-002',
      sectionId: 'tx_fin_payment_processing',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['date_inconsistency', 'amount_mismatch'],
        anomalyTypes: ['inconsistency', 'calculation_error'],
        timelineViolation: false,
        paymentIssue: true,
        keywords: ['payment crediting', 'payment application', 'late posting', 'payment misapplication', 'payment date'],
        fieldPatterns: ['payment*', 'posting*', 'credit*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated', 'amount > 50'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'TX payment processing violation: {description}. Payment of {amount} not properly credited under Texas Finance Code.',
      legalBasisTemplate: 'TX Finance Code § 343.105 requires servicers to credit payments on the date received and properly apply payments to principal, interest, and escrow. Misapplication may trigger penalties.'
    },

    // TX Debt Collection — False Representation
    {
      ruleId: 'rule-tx-debt-001',
      sectionId: 'tx_debt_false_representation',
      category: 'collections',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'amount_mismatch'],
        anomalyTypes: ['unusual_value', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['false representation', 'misleading', 'deceptive collection', 'inflated amount', 'unauthorized fee'],
        fieldPatterns: ['collection*', 'fee*', 'amount*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 100', 'repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'TX debt collection violation: {description}. False or misleading representation in mortgage debt collection.',
      legalBasisTemplate: 'TX Finance Code § 392.304 (Texas Debt Collection Act) prohibits false, deceptive, or misleading representations in debt collection including misrepresenting the amount or status of a debt.'
    }
  ],

  // =========================================================================
  // FLORIDA — 5 rules
  // =========================================================================
  FL: [

    // FL Foreclosure — Complaint Requirements
    {
      ruleId: 'rule-fl-foreclosure-001',
      sectionId: 'fl_foreclosure_complaint',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['missing_correspondence', 'timeline_violation'],
        anomalyTypes: ['missing_required', 'regulatory_concern'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['foreclosure complaint', 'verification', 'standing', 'original note', 'lost note'],
        fieldPatterns: ['foreclosure*', 'complaint*', 'standing*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'FL foreclosure complaint violation: {description}. Foreclosure complaint does not meet Florida statutory requirements.',
      legalBasisTemplate: 'FL Stat. § 702.015 requires foreclosure complaints to include verification of standing and compliance with pre-suit notice requirements. Plaintiff must file certification of good-faith compliance with loss mitigation requirements.'
    },

    // FL Foreclosure — Mediation
    {
      ruleId: 'rule-fl-foreclosure-002',
      sectionId: 'fl_foreclosure_mediation',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['mediation', 'foreclosure mediation', 'managed mediation', 'good faith negotiation'],
        fieldPatterns: ['mediation*', 'foreclosure*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'FL foreclosure mediation violation: {description}. Required mediation process not followed in foreclosure proceedings.',
      legalBasisTemplate: 'FL Stat. § 702.12 provides for court-ordered mediation in residential foreclosure cases. Servicer must participate in good faith and have authority to negotiate loss mitigation options.'
    },

    // FL CCPA — Prohibited Practices
    {
      ruleId: 'rule-fl-ccpa-001',
      sectionId: 'fl_ccpa_prohibited_practices',
      category: 'collections',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'amount_mismatch'],
        anomalyTypes: ['unusual_value', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['prohibited practice', 'unfair collection', 'deceptive', 'abusive', 'consumer protection'],
        fieldPatterns: ['collection*', 'fee*', 'charge*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated', 'amount > 100'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'FL consumer collection practices violation: {description}. Prohibited debt collection practice under Florida CCPA.',
      legalBasisTemplate: 'FL Stat. § 559.72 (Florida Consumer Collection Practices Act) prohibits threats, harassment, false representations, and unfair practices in debt collection. Violators face actual damages plus attorney fees.'
    },

    // FL MLA — Disclosures
    {
      ruleId: 'rule-fl-mla-001',
      sectionId: 'fl_mla_disclosures',
      category: 'disclosure',
      matchCriteria: {
        discrepancyTypes: ['missing_correspondence', 'amount_mismatch'],
        anomalyTypes: ['missing_required', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['disclosure', 'lending disclosure', 'loan terms', 'rate disclosure', 'fee disclosure'],
        fieldPatterns: ['disclosure*', 'rate*', 'fee*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'FL mortgage lending disclosure violation: {description}. Required disclosures not provided or contain inaccuracies.',
      legalBasisTemplate: 'FL Stat. § 494.00791 requires mortgage lenders and servicers to provide accurate disclosures of loan terms, rates, and fees. The Florida Office of Financial Regulation enforces compliance.'
    },

    // FL MLA — Prohibited Practices
    {
      ruleId: 'rule-fl-mla-002',
      sectionId: 'fl_mla_prohibited_practices',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'term_contradiction'],
        anomalyTypes: ['unusual_value', 'regulatory_concern'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['prohibited lending', 'predatory', 'excessive fee', 'unfair term', 'unconscionable'],
        fieldPatterns: ['fee*', 'term*', 'rate*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 500'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'FL mortgage lending prohibited practice: {description}. Practice violates Florida Mortgage Lending Act restrictions.',
      legalBasisTemplate: 'FL Stat. § 494.00795 prohibits mortgage lenders from engaging in unfair or deceptive practices, charging excessive fees, or steering borrowers to disadvantageous loan products.'
    }
  ],

  // =========================================================================
  // ILLINOIS — 5 rules
  // =========================================================================
  IL: [

    // IL Foreclosure — Notice Requirements
    {
      ruleId: 'rule-il-foreclosure-001',
      sectionId: 'il_foreclosure_notice',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['foreclosure notice', 'grace period notice', '30-day notice', 'pre-foreclosure'],
        fieldPatterns: ['foreclosure*', 'notice*', 'gracePeriod*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'IL foreclosure notice violation: {description}. Required pre-foreclosure notice not properly served under Illinois law.',
      legalBasisTemplate: 'IL 735 ILCS 5/15-1502.5 requires a grace period notice at least 30 days before filing foreclosure complaint. Notice must include information about housing counseling, legal assistance, and loss mitigation options.'
    },

    // IL Foreclosure — Reinstatement
    {
      ruleId: 'rule-il-foreclosure-002',
      sectionId: 'il_foreclosure_reinstatement',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['amount_mismatch', 'timeline_violation'],
        anomalyTypes: ['calculation_error', 'regulatory_concern'],
        timelineViolation: true,
        paymentIssue: true,
        keywords: ['reinstatement', 'cure', 'reinstatement amount', 'reinstatement period', 'right to reinstate'],
        fieldPatterns: ['reinstatement*', 'cure*', 'payoff*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 100', 'repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'IL reinstatement rights violation: {description}. Borrower\'s right to reinstate not properly honored or reinstatement amount is inaccurate.',
      legalBasisTemplate: 'IL 735 ILCS 5/15-1602 provides borrowers the right to reinstate the mortgage up to 90 days after service of the foreclosure summons. Servicer must provide accurate reinstatement amount including all authorized fees.'
    },

    // IL Foreclosure — Loss Mitigation
    {
      ruleId: 'rule-il-foreclosure-003',
      sectionId: 'il_foreclosure_loss_mitigation',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['loss mitigation', 'modification', 'hardship', 'workout', 'loss mit review'],
        fieldPatterns: ['lossMit*', 'modification*', 'hardship*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'IL loss mitigation violation: {description}. Servicer failed to meet Illinois loss mitigation evaluation requirements.',
      legalBasisTemplate: 'IL 735 ILCS 5/15-1503.1 requires servicers to evaluate borrowers for loss mitigation options before proceeding with foreclosure. Borrower must be given opportunity to submit a complete application.'
    },

    // IL RMLA — Prohibited Practices
    {
      ruleId: 'rule-il-rmla-001',
      sectionId: 'il_rmla_prohibited',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'term_contradiction'],
        anomalyTypes: ['unusual_value', 'regulatory_concern'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['prohibited practice', 'predatory lending', 'excessive fee', 'unfair term', 'abusive lending'],
        fieldPatterns: ['fee*', 'term*', 'rate*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 500'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'IL residential mortgage prohibited practice: {description}. Practice violates Illinois Residential Mortgage License Act.',
      legalBasisTemplate: 'IL 205 ILCS 635/3-6 (Residential Mortgage License Act) prohibits deceptive practices, excessive fees, and other unfair lending conduct. IDFPR enforces compliance and may impose penalties.'
    },

    // IL CFA — Deceptive Mortgage Practices
    {
      ruleId: 'rule-il-cfa-001',
      sectionId: 'il_cfa_deceptive_mortgage',
      category: 'collections',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'amount_mismatch'],
        anomalyTypes: ['unusual_value', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['deceptive', 'consumer fraud', 'misleading', 'unfair practice', 'false representation'],
        fieldPatterns: ['fee*', 'charge*', 'collection*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'IL consumer fraud violation: {description}. Deceptive or unfair mortgage servicing practice under Illinois Consumer Fraud Act.',
      legalBasisTemplate: 'IL 815 ILCS 505/2 (Consumer Fraud and Deceptive Business Practices Act) prohibits unfair or deceptive acts in mortgage servicing. Consumers may recover actual damages and the court may award punitive damages.'
    }
  ],

  // =========================================================================
  // MASSACHUSETTS — 5 rules
  // =========================================================================
  MA: [

    // MA Ch. 183C — Prohibited Terms (Predatory Lending)
    {
      ruleId: 'rule-ma-183c-001',
      sectionId: 'ma_ch183c_prohibited_terms',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['term_contradiction', 'fee_irregularity'],
        anomalyTypes: ['unusual_value', 'regulatory_concern'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['predatory lending', 'high-cost mortgage', 'prohibited term', 'balloon payment', 'prepayment penalty'],
        fieldPatterns: ['term*', 'rate*', 'fee*', 'penalty*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'MA predatory lending violation: {description}. Loan contains prohibited terms under Massachusetts high-cost mortgage law.',
      legalBasisTemplate: 'MA G.L. c. 183C § 4 prohibits certain terms in high-cost home mortgage loans including balloon payments within first 7 years, prepayment penalties after 36 months, and negative amortization. Violations render loan terms unenforceable.'
    },

    // MA Ch. 183C — Fee Limits
    {
      ruleId: 'rule-ma-183c-002',
      sectionId: 'ma_ch183c_fee_limits',
      category: 'fees',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'amount_mismatch'],
        anomalyTypes: ['unusual_value', 'calculation_error'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['excessive fee', 'late fee', 'fee limit', 'points and fees', 'origination fee'],
        fieldPatterns: ['fee*', 'charge*', 'points*', 'late*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['amount > 100', 'repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'MA fee limit violation: {description}. Fee of {amount} exceeds Massachusetts statutory limits.',
      legalBasisTemplate: 'MA G.L. c. 183C § 3-4 limits points and fees on high-cost mortgages and restricts late charges. Late fees cannot exceed 3% of the payment amount and cannot be assessed within 15 days of due date.'
    },

    // MA Right to Cure — 150-Day Notice
    {
      ruleId: 'rule-ma-rtc-001',
      sectionId: 'ma_rtc_150_day_notice',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
        anomalyTypes: ['regulatory_concern', 'missing_required'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['right to cure', '150-day notice', 'cure notice', 'pre-foreclosure notice', '150 day'],
        fieldPatterns: ['cure*', 'notice*', 'foreclosure*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'MA right to cure violation: {description}. Required 150-day right to cure notice not properly served.',
      legalBasisTemplate: 'MA G.L. c. 244 § 35A requires 150-day right to cure notice before foreclosure. Notice must be sent by registered mail or certified mail and include specific information about the default and borrower\'s rights. Failure voids foreclosure.'
    },

    // MA Right to Cure — Notice Requirements
    {
      ruleId: 'rule-ma-rtc-002',
      sectionId: 'ma_rtc_notice_requirements',
      category: 'servicing',
      matchCriteria: {
        discrepancyTypes: ['missing_correspondence', 'timeline_violation'],
        anomalyTypes: ['missing_required', 'regulatory_concern'],
        timelineViolation: true,
        paymentIssue: false,
        keywords: ['foreclosure notice', 'publication notice', 'notice of sale', 'power of sale'],
        fieldPatterns: ['notice*', 'sale*', 'foreclosure*'],
        minSeverity: 'high'
      },
      violationSeverity: 'critical',
      severityElevation: {
        conditions: ['critical_field'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'MA foreclosure notice violation: {description}. Required foreclosure notice requirements not met under Massachusetts law.',
      legalBasisTemplate: 'MA G.L. c. 244 § 14 requires notice of foreclosure sale by publication for 3 consecutive weeks and mailing to mortgagor at least 14 days before sale. Non-compliance renders sale void.'
    },

    // MA 93A — Unfair Practices
    {
      ruleId: 'rule-ma-93a-001',
      sectionId: 'ma_93a_unfair_practices',
      category: 'collections',
      matchCriteria: {
        discrepancyTypes: ['fee_irregularity', 'amount_mismatch'],
        anomalyTypes: ['unusual_value', 'inconsistency'],
        timelineViolation: false,
        paymentIssue: false,
        keywords: ['unfair practice', 'deceptive', 'consumer protection', 'unfair collection', 'misleading'],
        fieldPatterns: ['fee*', 'charge*', 'collection*'],
        minSeverity: 'medium'
      },
      violationSeverity: 'high',
      severityElevation: {
        conditions: ['repeated'],
        elevatedSeverity: 'critical'
      },
      descriptionTemplate: 'MA unfair practices violation: {description}. Mortgage servicing practice may constitute unfair or deceptive act under Chapter 93A.',
      legalBasisTemplate: 'MA G.L. c. 93A § 2 prohibits unfair or deceptive acts in trade or commerce, including mortgage servicing. Consumers may recover actual damages, treble damages for willful violations, and attorney fees under § 9.'
    }
  ]
};

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/**
 * Get all rules for a specific state.
 *
 * @param {string} stateCode - Two-letter state code (e.g. 'CA', 'NY')
 * @returns {Array<Object>} Array of rule objects, or empty array if state not found
 */
function getStateRules(stateCode) {
  return STATE_COMPLIANCE_RULE_MAPPINGS[stateCode] || [];
}

/**
 * Get rules for a specific state and section.
 *
 * @param {string} stateCode - Two-letter state code
 * @param {string} sectionId - Section ID from stateStatuteTaxonomy (e.g. 'ca_hbor_dual_tracking')
 * @returns {Array<Object>} Array of matching rule objects
 */
function getStateRulesForSection(stateCode, sectionId) {
  const rules = STATE_COMPLIANCE_RULE_MAPPINGS[stateCode];
  if (!rules) return [];
  return rules.filter(rule => rule.sectionId === sectionId);
}

/**
 * Match state rules against a forensic finding.
 *
 * Uses IDENTICAL matching logic to the federal matchRules() in
 * complianceRuleMappings.js. A rule matches if ANY of these conditions are met:
 *   - finding.discrepancyType is in the rule's discrepancyTypes
 *   - finding.anomalyType is in the rule's anomalyTypes
 *   - finding.isTimelineViolation is true AND the rule's timelineViolation is true
 *   - finding.isPaymentIssue is true AND the rule's paymentIssue is true
 *   - Any of the rule's keywords appear in the finding's description (case-insensitive)
 *   - Any of the rule's fieldPatterns match the finding's fields
 *
 * Finding severity must meet or exceed the rule's minSeverity.
 * Results are sorted by violationSeverity (highest first).
 *
 * @param {string} stateCode - Two-letter state code
 * @param {Object} finding - A finding object (same shape as federal matchRules)
 * @returns {Array<Object>} Matched rules sorted by severity (highest first)
 */
function matchStateRules(stateCode, finding) {
  const rules = STATE_COMPLIANCE_RULE_MAPPINGS[stateCode];
  if (!rules) return [];

  const severityMeetsMinimum = (findingSeverity, minSeverity) => {
    const order = SEVERITY_ORDER;
    const findingLevel = order[findingSeverity];
    const minLevel = order[minSeverity];
    return (findingLevel !== undefined ? findingLevel : 4) <= (minLevel !== undefined ? minLevel : 4);
  };

  const fieldMatchesPattern = (fieldName, pattern) => {
    if (!pattern.includes('*')) {
      return fieldName === pattern;
    }
    const prefix = pattern.replace('*', '');
    return fieldName.toLowerCase().startsWith(prefix.toLowerCase());
  };

  const matched = rules.filter(rule => {
    const criteria = rule.matchCriteria;

    // Check severity threshold first
    if (finding.severity && !severityMeetsMinimum(finding.severity, criteria.minSeverity)) {
      return false;
    }

    let hasMatch = false;

    // Check discrepancy type
    if (finding.discrepancyType && criteria.discrepancyTypes.length > 0) {
      if (criteria.discrepancyTypes.includes(finding.discrepancyType)) {
        hasMatch = true;
      }
    }

    // Check anomaly type
    if (finding.anomalyType && criteria.anomalyTypes.length > 0) {
      if (criteria.anomalyTypes.includes(finding.anomalyType)) {
        hasMatch = true;
      }
    }

    // Check timeline violation
    if (finding.isTimelineViolation && criteria.timelineViolation) {
      hasMatch = true;
    }

    // Check payment issue
    if (finding.isPaymentIssue && criteria.paymentIssue) {
      hasMatch = true;
    }

    // Check keywords in description
    if (finding.description && criteria.keywords.length > 0) {
      const descLower = finding.description.toLowerCase();
      if (criteria.keywords.some(kw => descLower.includes(kw.toLowerCase()))) {
        hasMatch = true;
      }
    }

    // Check field patterns
    if (finding.fields && Array.isArray(finding.fields) && criteria.fieldPatterns.length > 0) {
      if (finding.fields.some(field =>
        criteria.fieldPatterns.some(pattern => fieldMatchesPattern(field, pattern))
      )) {
        hasMatch = true;
      }
    }

    return hasMatch;
  });

  // Sort by severity (highest first)
  matched.sort((a, b) => {
    return (SEVERITY_ORDER[a.violationSeverity] || 4) - (SEVERITY_ORDER[b.violationSeverity] || 4);
  });

  return matched;
}

/**
 * Get the list of state codes that have compliance rules defined.
 *
 * @returns {string[]} Array of two-letter state codes
 */
function getSupportedRuleStates() {
  return Object.keys(STATE_COMPLIANCE_RULE_MAPPINGS);
}

module.exports = {
  STATE_COMPLIANCE_RULE_MAPPINGS,
  getStateRules,
  getStateRulesForSection,
  matchStateRules,
  getSupportedRuleStates
};
