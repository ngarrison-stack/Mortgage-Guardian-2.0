/**
 * Compliance Rule Mappings Configuration
 *
 * Maps forensic analysis findings (discrepancies, anomalies, timeline violations,
 * payment issues) to specific federal statute violations. This is the "rule book"
 * the compliance engine uses to determine which laws may have been violated.
 *
 * Each rule defines match criteria that fire when a forensic finding satisfies
 * the conditions. Rules reference section IDs from federalStatuteTaxonomy.js
 * and use discrepancy/anomaly types from crossDocumentAnalysisSchema.js and
 * analysisReportSchema.js.
 *
 * Total: 32 rules across 7 federal statutes.
 */

// ---------------------------------------------------------------------------
// Severity ordering (used for sorting matched rules)
// ---------------------------------------------------------------------------
const SEVERITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3, info: 4 };

// ---------------------------------------------------------------------------
// COMPLIANCE_RULE_MAPPINGS
// ---------------------------------------------------------------------------

const COMPLIANCE_RULE_MAPPINGS = [

  // =========================================================================
  // RESPA — Real Estate Settlement Procedures Act (8 rules)
  // =========================================================================

  {
    ruleId: 'rule-respa-001',
    sectionId: 'respa_s10',
    category: 'escrow',
    matchCriteria: {
      discrepancyTypes: ['amount_mismatch', 'calculation_error'],
      anomalyTypes: ['calculation_error', 'unusual_value'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['escrow', 'cushion', 'surplus', 'shortage', 'escrow analysis', 'escrow overcharge'],
      fieldPatterns: ['escrow*', 'cushion*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 100', 'repeated', 'critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Escrow account violation detected: {description}. Escrow balance discrepancy of {amount} identified on {date}.',
    legalBasisTemplate: 'RESPA Section 10 (12 CFR § 1024.17) limits escrow cushions to 1/6 of annual disbursements and requires annual escrow analysis with surplus refunds within 30 days.'
  },

  {
    ruleId: 'rule-respa-002',
    sectionId: 'respa_s10',
    category: 'escrow',
    matchCriteria: {
      discrepancyTypes: ['amount_mismatch'],
      anomalyTypes: ['unusual_value'],
      timelineViolation: false,
      paymentIssue: true,
      keywords: ['escrow surplus', 'refund', 'escrow excess', 'surplus not refunded'],
      fieldPatterns: ['escrow*', 'surplus*', 'refund*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 50', 'repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Escrow surplus exceeding $50 not refunded within required timeframe. Surplus amount: {amount}.',
    legalBasisTemplate: 'RESPA Section 10 (12 CFR § 1024.17(f)(2)) requires refund of surplus over $50 within 30 days of escrow analysis.'
  },

  {
    ruleId: 'rule-respa-003',
    sectionId: 'respa_s8',
    category: 'fees',
    matchCriteria: {
      discrepancyTypes: ['fee_irregularity'],
      anomalyTypes: ['unusual_value'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['referral fee', 'kickback', 'unearned fee', 'fee splitting', 'settlement service fee'],
      fieldPatterns: ['fee*', 'referral*', 'kickback*'],
      minSeverity: 'high'
    },
    violationSeverity: 'critical',
    severityElevation: {
      conditions: ['amount > 500'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Prohibited fee arrangement detected: {description}. Fee amount of {amount} may constitute an unearned fee or kickback.',
    legalBasisTemplate: 'RESPA Section 8 (12 CFR § 1024.14) prohibits kickbacks, referral fees, and fee splitting for settlement services not actually performed.'
  },

  {
    ruleId: 'rule-respa-004',
    sectionId: 'respa_s8',
    category: 'fees',
    matchCriteria: {
      discrepancyTypes: ['fee_irregularity', 'amount_mismatch'],
      anomalyTypes: ['unusual_value', 'calculation_error'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['excessive fee', 'late fee', 'unauthorized fee', 'service charge', 'junk fee'],
      fieldPatterns: ['fee*', 'charge*', 'late*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 100', 'repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Fee irregularity detected: {description}. Unauthorized or excessive fee of {amount}.',
    legalBasisTemplate: 'RESPA Section 8 prohibits unearned fees. Fees must correspond to services actually rendered and be reasonable in amount.'
  },

  {
    ruleId: 'rule-respa-005',
    sectionId: 'respa_s6',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation'],
      anomalyTypes: ['regulatory_concern'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['qwr', 'qualified written request', 'response deadline', 'acknowledgment'],
      fieldPatterns: ['qwr*', 'request*', 'response*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'QWR response timeline violation: {description}. Servicer failed to meet required response deadline.',
    legalBasisTemplate: 'RESPA Section 6 (12 CFR § 1024.35-36) requires acknowledgment within 5 business days and substantive response within 30 business days of QWR receipt.'
  },

  {
    ruleId: 'rule-respa-006',
    sectionId: 'respa_s6',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['missing_correspondence'],
      anomalyTypes: ['missing_required'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['qwr response', 'acknowledgment missing', 'no response', 'qualified written request'],
      fieldPatterns: ['qwr*', 'response*', 'acknowledgment*'],
      minSeverity: 'high'
    },
    violationSeverity: 'critical',
    severityElevation: {
      conditions: ['repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Missing QWR response: {description}. Required correspondence not provided to borrower.',
    legalBasisTemplate: 'RESPA Section 6 requires servicers to acknowledge and substantively respond to QWRs. Failure to respond may result in actual and statutory damages.'
  },

  {
    ruleId: 'rule-respa-007',
    sectionId: 'respa_s6',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['amount_mismatch'],
      anomalyTypes: ['inconsistency', 'calculation_error'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['settlement', 'closing costs', 'hud-1', 'settlement statement', 'cash to close'],
      fieldPatterns: ['settlement*', 'closing*', 'hud*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 100', 'critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Settlement statement error: {description}. Amount discrepancy of {amount} in closing documents.',
    legalBasisTemplate: 'RESPA requires accurate settlement statements. Misrepresented settlement charges may violate Sections 4, 5, and 8.'
  },

  {
    ruleId: 'rule-respa-008',
    sectionId: 'respa_s6',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['party_mismatch', 'missing_correspondence'],
      anomalyTypes: ['missing_required', 'inconsistency'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['servicing transfer', 'new servicer', 'transfer notice', 'goodbye letter', 'hello letter'],
      fieldPatterns: ['servicer*', 'transfer*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Servicing transfer notification failure: {description}. Required transfer notices not properly provided.',
    legalBasisTemplate: 'RESPA Section 6 (12 CFR § 1024.33) requires both transferor and transferee servicers to provide notice of loan transfer at least 15 days before effective date.'
  },

  // =========================================================================
  // TILA / Reg Z — Truth in Lending Act (6 rules)
  // =========================================================================

  {
    ruleId: 'rule-tila-001',
    sectionId: 'tila_disclosure',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['calculation_error', 'amount_mismatch'],
      anomalyTypes: ['calculation_error', 'inconsistency'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['apr', 'annual percentage rate', 'apr disclosure', 'apr mismatch', 'rate discrepancy'],
      fieldPatterns: ['apr*', 'rate*', 'annualPercentage*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 0.125', 'critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'APR disclosure error: {description}. Disclosed APR deviates from calculated APR beyond regulatory tolerance.',
    legalBasisTemplate: 'TILA Section 128 (12 CFR § 1026.18-19) requires APR disclosure within 1/8 of 1% accuracy for regular transactions and 1/4 of 1% for irregular transactions.'
  },

  {
    ruleId: 'rule-tila-002',
    sectionId: 'tila_disclosure',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['amount_mismatch'],
      anomalyTypes: ['inconsistency', 'calculation_error'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['payment amount', 'monthly payment', 'payment disclosure', 'payment schedule'],
      fieldPatterns: ['payment*', 'monthlyPayment*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 50', 'critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Payment disclosure error: {description}. Disclosed payment amount of {amount} does not match calculated amount.',
    legalBasisTemplate: 'TILA Section 128 (12 CFR § 1026.18) requires accurate disclosure of payment amounts, payment schedule, and total of payments.'
  },

  {
    ruleId: 'rule-tila-003',
    sectionId: 'tila_rescission',
    category: 'timing',
    matchCriteria: {
      discrepancyTypes: ['missing_correspondence'],
      anomalyTypes: ['missing_required'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['rescission', 'right to cancel', 'cancellation notice', 'right of rescission'],
      fieldPatterns: ['rescission*', 'cancel*'],
      minSeverity: 'high'
    },
    violationSeverity: 'critical',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Right of rescission violation: {description}. Required rescission notice not provided to borrower.',
    legalBasisTemplate: 'TILA Section 125 (12 CFR § 1026.23) requires two copies of rescission notice. Failure extends rescission period up to 3 years from consummation.'
  },

  {
    ruleId: 'rule-tila-004',
    sectionId: 'tila_rescission',
    category: 'timing',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation'],
      anomalyTypes: ['regulatory_concern'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['rescission period', 'cancellation deadline', '3 business days', 'rescission timing'],
      fieldPatterns: ['rescission*', 'cancel*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Rescission period timing violation: {description}. Transaction proceeded before rescission period expired.',
    legalBasisTemplate: 'TILA Section 125 provides 3 business days to rescind. Material disclosure errors extend rescission rights. Creditor must honor timely rescission requests.'
  },

  {
    ruleId: 'rule-tila-005',
    sectionId: 'tila_disclosure',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['calculation_error', 'amount_mismatch'],
      anomalyTypes: ['calculation_error'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['finance charge', 'total interest', 'interest cost', 'total of payments'],
      fieldPatterns: ['financeCharge*', 'totalInterest*', 'totalOfPayments*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 100', 'critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Finance charge error: {description}. Finance charge or total of payments calculation discrepancy of {amount}.',
    legalBasisTemplate: 'TILA Section 128 (12 CFR § 1026.18) requires accurate finance charge disclosure including all charges imposed by the creditor as a condition of the loan.'
  },

  {
    ruleId: 'rule-tila-006',
    sectionId: 'tila_arm',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
      anomalyTypes: ['regulatory_concern', 'missing_required'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['arm adjustment', 'rate change notice', 'adjustment notice', 'variable rate', 'index value'],
      fieldPatterns: ['arm*', 'adjustment*', 'rateChange*', 'index*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'ARM adjustment notification failure: {description}. Required rate change notice not provided within mandated timeframe.',
    legalBasisTemplate: 'TILA Section 128(f) (12 CFR § 1026.20(c)-(d)) requires initial rate change notice at least 210 days before first new payment, and subsequent notices at least 60 days before payment change.'
  },

  // =========================================================================
  // ECOA — Equal Credit Opportunity Act (3 rules)
  // =========================================================================

  {
    ruleId: 'rule-ecoa-001',
    sectionId: 'ecoa_adverse_action',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['missing_correspondence'],
      anomalyTypes: ['missing_required'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['adverse action', 'denial notice', 'reasons for denial', 'adverse action notice'],
      fieldPatterns: ['adverseAction*', 'denial*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Adverse action notice failure: {description}. Required notice not provided within 30 days of adverse action.',
    legalBasisTemplate: 'ECOA Section 701(d) (12 CFR § 1002.9) requires written adverse action notice within 30 days with specific reasons and ECOA anti-discrimination statement.'
  },

  {
    ruleId: 'rule-ecoa-002',
    sectionId: 'ecoa_discrimination',
    category: 'discrimination',
    matchCriteria: {
      discrepancyTypes: ['term_contradiction'],
      anomalyTypes: ['unusual_value', 'inconsistency'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['discrimination', 'disparate treatment', 'unequal terms', 'steering', 'discriminatory'],
      fieldPatterns: ['term*', 'rate*', 'condition*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'critical',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Potential discriminatory terms detected: {description}. Loan terms may reflect disparate treatment.',
    legalBasisTemplate: 'ECOA Section 701 (12 CFR § 1002.4) prohibits discrimination in any aspect of a credit transaction based on race, color, religion, national origin, sex, marital status, or age.'
  },

  {
    ruleId: 'rule-ecoa-003',
    sectionId: 'ecoa_adverse_action',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['missing_correspondence'],
      anomalyTypes: ['missing_required'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['appraisal copy', 'appraisal delivery', 'valuation copy', 'appraisal notice'],
      fieldPatterns: ['appraisal*', 'valuation*'],
      minSeverity: 'low'
    },
    violationSeverity: 'medium',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'high'
    },
    descriptionTemplate: 'Appraisal copy requirement violation: {description}. Applicant not provided copy of appraisal report as required.',
    legalBasisTemplate: 'ECOA (12 CFR § 1002.14) requires creditors to provide applicants a copy of all appraisals and valuations developed in connection with the application.'
  },

  // =========================================================================
  // FDCPA — Fair Debt Collection Practices Act (4 rules)
  // =========================================================================

  {
    ruleId: 'rule-fdcpa-001',
    sectionId: 'fdcpa_validation',
    category: 'collections',
    matchCriteria: {
      discrepancyTypes: ['missing_correspondence'],
      anomalyTypes: ['missing_required'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['validation notice', 'debt validation', 'collection notice missing', 'initial notice'],
      fieldPatterns: ['validation*', 'collection*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Debt validation notice failure: {description}. Required validation notice not provided within 5 days of initial communication.',
    legalBasisTemplate: 'FDCPA Section 809 (15 U.S.C. § 1692g) requires written validation notice within 5 days including debt amount, creditor name, and dispute rights.'
  },

  {
    ruleId: 'rule-fdcpa-002',
    sectionId: 'fdcpa_amount',
    category: 'collections',
    matchCriteria: {
      discrepancyTypes: ['amount_mismatch'],
      anomalyTypes: ['unusual_value', 'inconsistency'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['inflated balance', 'unauthorized fee', 'incorrect amount', 'debt amount', 'false representation'],
      fieldPatterns: ['amount*', 'balance*', 'debt*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 100', 'repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'False/misleading debt representation: {description}. Stated amount of {amount} does not match verified debt.',
    legalBasisTemplate: 'FDCPA Section 807(2) (15 U.S.C. § 1692e(2)) prohibits misrepresentation of the character, amount, or legal status of any debt.'
  },

  {
    ruleId: 'rule-fdcpa-003',
    sectionId: 'fdcpa_amount',
    category: 'collections',
    matchCriteria: {
      discrepancyTypes: ['fee_irregularity'],
      anomalyTypes: ['unusual_value', 'calculation_error'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['unauthorized charge', 'improper fee', 'inflated fee', 'collection fee', 'unfair practice'],
      fieldPatterns: ['fee*', 'charge*', 'collection*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 100', 'repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Unfair collection practice: {description}. Unauthorized or improper fee of {amount} assessed.',
    legalBasisTemplate: 'FDCPA Section 808 (15 U.S.C. § 1692f) prohibits collecting amounts not authorized by agreement or law, including unauthorized fees and charges.'
  },

  {
    ruleId: 'rule-fdcpa-004',
    sectionId: 'fdcpa_practices',
    category: 'collections',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation'],
      anomalyTypes: ['regulatory_concern'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['communication violation', 'collection timing', 'harassment', 'collection during dispute', 'cease communication'],
      fieldPatterns: ['communication*', 'contact*', 'collection*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Collection communication violation: {description}. Collection activity occurred in violation of timing or method restrictions.',
    legalBasisTemplate: 'FDCPA Sections 805-806 (15 U.S.C. § 1692c-d) restrict communications to appropriate times/places, prohibit harassment, and require cessation upon written request.'
  },

  // =========================================================================
  // SCRA — Servicemembers Civil Relief Act (3 rules)
  // =========================================================================

  {
    ruleId: 'rule-scra-001',
    sectionId: 'scra_interest_cap',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['calculation_error', 'amount_mismatch'],
      anomalyTypes: ['calculation_error', 'unusual_value'],
      timelineViolation: false,
      paymentIssue: true,
      keywords: ['interest rate cap', '6%', 'scra rate', 'military rate reduction', 'rate above 6%'],
      fieldPatterns: ['interest*', 'rate*', 'scra*'],
      minSeverity: 'high'
    },
    violationSeverity: 'critical',
    severityElevation: {
      conditions: ['amount > 0'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'SCRA interest rate cap violation: {description}. Interest rate exceeds 6% cap for active-duty servicemember.',
    legalBasisTemplate: 'SCRA Section 207 (50 U.S.C. § 3937) caps interest at 6% during military service for pre-service obligations. Excess interest must be forgiven, not deferred.'
  },

  {
    ruleId: 'rule-scra-002',
    sectionId: 'scra_foreclosure',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation'],
      anomalyTypes: ['regulatory_concern'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['foreclosure', 'military service', 'scra foreclosure', 'protected period', 'servicemember foreclosure'],
      fieldPatterns: ['foreclosure*', 'scra*', 'military*'],
      minSeverity: 'high'
    },
    violationSeverity: 'critical',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'SCRA foreclosure protection violation: {description}. Foreclosure action during protected military service period.',
    legalBasisTemplate: 'SCRA Section 303 (50 U.S.C. § 3953) prohibits foreclosure during military service and within 12 months after without court order. Violations render foreclosure void.'
  },

  {
    ruleId: 'rule-scra-003',
    sectionId: 'scra_foreclosure',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
      anomalyTypes: ['regulatory_concern', 'missing_required'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['default judgment', 'scra court', 'court order', 'scra protection', 'military default'],
      fieldPatterns: ['judgment*', 'court*', 'default*'],
      minSeverity: 'high'
    },
    violationSeverity: 'critical',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'SCRA default judgment protection violation: {description}. Default judgment entered without required protections for servicemember.',
    legalBasisTemplate: 'SCRA Section 201 (50 U.S.C. § 3931) requires courts to appoint attorney for absent servicemembers and stay proceedings upon request. Default judgments without military status affidavit are voidable.'
  },

  // =========================================================================
  // HMDA — Home Mortgage Disclosure Act (2 rules)
  // =========================================================================

  {
    ruleId: 'rule-hmda-001',
    sectionId: 'hmda_accuracy',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['term_contradiction', 'amount_mismatch'],
      anomalyTypes: ['inconsistency', 'calculation_error'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['hmda data', 'reporting error', 'lar', 'loan application register', 'data accuracy', 'reporting accuracy'],
      fieldPatterns: ['hmda*', 'reporting*', 'lar*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'medium',
    severityElevation: {
      conditions: ['repeated'],
      elevatedSeverity: 'high'
    },
    descriptionTemplate: 'HMDA reporting accuracy violation: {description}. Loan data inconsistencies may result in inaccurate HMDA reporting.',
    legalBasisTemplate: 'HMDA Section 304(b) (12 CFR § 1003.6) requires data accuracy within regulatory tolerance. Errors exceeding threshold require resubmission.'
  },

  {
    ruleId: 'rule-hmda-002',
    sectionId: 'hmda_reporting',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['calculation_error'],
      anomalyTypes: ['calculation_error'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['rate spread', 'apor', 'higher-priced', 'hpml', 'rate spread reporting'],
      fieldPatterns: ['rateSpread*', 'apor*', 'spread*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'medium',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'high'
    },
    descriptionTemplate: 'HMDA rate spread reporting error: {description}. Rate spread calculation does not match expected APOR-based calculation.',
    legalBasisTemplate: 'HMDA (12 CFR § 1003.4(a)(12)) requires accurate rate spread reporting comparing transaction APR to APOR. Errors affect fair lending analysis.'
  },

  // =========================================================================
  // CFPB / Reg X — Dodd-Frank Servicing Rules (6 rules)
  // =========================================================================

  {
    ruleId: 'rule-cfpb-001',
    sectionId: 'cfpb_force_placed_insurance',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['fee_irregularity', 'missing_correspondence'],
      anomalyTypes: ['unusual_value', 'missing_required'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['force-placed', 'lender-placed', 'fpi', 'insurance charge', 'forced insurance', 'fpi notice'],
      fieldPatterns: ['insurance*', 'fpi*', 'forcePlaced*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['amount > 500', 'critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Force-placed insurance violation: {description}. Insurance charged without required notices or at excessive cost.',
    legalBasisTemplate: 'CFPB Reg X (12 CFR § 1024.37) requires two written notices (45 and 15 days) before charging force-placed insurance. Must cancel within 15 days of evidence of existing coverage and refund overlapping premiums.'
  },

  {
    ruleId: 'rule-cfpb-002',
    sectionId: 'cfpb_dual_tracking',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation'],
      anomalyTypes: ['regulatory_concern'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['dual tracking', 'simultaneous foreclosure', 'foreclosure during review', 'pending application', 'loss mitigation pending'],
      fieldPatterns: ['foreclosure*', 'lossMit*', 'dualTrack*'],
      minSeverity: 'high'
    },
    violationSeverity: 'critical',
    severityElevation: {
      conditions: ['critical_field'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Dual tracking violation: {description}. Foreclosure proceedings advanced while loss mitigation application was pending.',
    legalBasisTemplate: 'CFPB Reg X (12 CFR § 1024.41(g)) prohibits initiating foreclosure while a complete loss mitigation application is under review. First notice cannot occur until borrower is 120+ days delinquent.'
  },

  {
    ruleId: 'rule-cfpb-003',
    sectionId: 'cfpb_loss_mitigation',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
      anomalyTypes: ['regulatory_concern', 'missing_required'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['loss mitigation', 'application review', 'loss mit timeline', 'modification review', 'application acknowledgment'],
      fieldPatterns: ['lossMit*', 'modification*', 'application*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Loss mitigation timeline failure: {description}. Servicer failed to meet required evaluation or response deadlines.',
    legalBasisTemplate: 'CFPB Reg X (12 CFR § 1024.41) requires acknowledgment within 5 business days, evaluation of complete application within 30 days, and 14-day acceptance period for offers.'
  },

  {
    ruleId: 'rule-cfpb-004',
    sectionId: 'cfpb_error_resolution',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['timeline_violation', 'missing_correspondence'],
      anomalyTypes: ['regulatory_concern', 'missing_required'],
      timelineViolation: true,
      paymentIssue: false,
      keywords: ['error resolution', 'notice of error', 'error investigation', 'error response', 'error acknowledgment'],
      fieldPatterns: ['error*', 'resolution*', 'investigation*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['repeated'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Error resolution response failure: {description}. Servicer failed to acknowledge or resolve error within required timeframe.',
    legalBasisTemplate: 'CFPB Reg X (12 CFR § 1024.35) requires error acknowledgment within 5 business days, investigation within 30 days (extendable to 45), and correction or written explanation. No fees for investigation.'
  },

  {
    ruleId: 'rule-cfpb-005',
    sectionId: 'cfpb_early_intervention',
    category: 'servicing',
    matchCriteria: {
      discrepancyTypes: ['date_inconsistency', 'amount_mismatch'],
      anomalyTypes: ['inconsistency', 'calculation_error'],
      timelineViolation: false,
      paymentIssue: true,
      keywords: ['payment crediting', 'payment application', 'payment posting', 'late posting', 'payment date', 'payment applied'],
      fieldPatterns: ['payment*', 'posting*', 'credit*'],
      minSeverity: 'medium'
    },
    violationSeverity: 'high',
    severityElevation: {
      conditions: ['repeated', 'amount > 50'],
      elevatedSeverity: 'critical'
    },
    descriptionTemplate: 'Payment crediting violation: {description}. Payment of {amount} not credited on date received or applied incorrectly.',
    legalBasisTemplate: 'CFPB Reg X (12 CFR § 1024.35(b)(6)) and Reg Z (12 CFR § 1026.36(c)) require payments to be credited on the date of receipt. Misapplication of payments is a covered error.'
  },

  {
    ruleId: 'rule-cfpb-006',
    sectionId: 'cfpb_early_intervention',
    category: 'disclosure',
    matchCriteria: {
      discrepancyTypes: ['amount_mismatch', 'date_inconsistency', 'calculation_error'],
      anomalyTypes: ['inconsistency', 'calculation_error'],
      timelineViolation: false,
      paymentIssue: false,
      keywords: ['periodic statement', 'monthly statement', 'statement error', 'statement accuracy', 'billing statement'],
      fieldPatterns: ['statement*', 'periodic*', 'billing*'],
      minSeverity: 'low'
    },
    violationSeverity: 'medium',
    severityElevation: {
      conditions: ['repeated', 'amount > 100'],
      elevatedSeverity: 'high'
    },
    descriptionTemplate: 'Periodic statement error: {description}. Statement contains inaccurate amounts or dates affecting borrower payment records.',
    legalBasisTemplate: 'CFPB Reg X (12 CFR § 1026.41) requires accurate periodic statements including payment amount due, fees, transaction activity, and contact information for borrower assistance.'
  }
];

// ---------------------------------------------------------------------------
// Keyword and field pattern matching helpers (word-boundary-aware)
// ---------------------------------------------------------------------------

/**
 * Escape special regex characters in a string so it can be used as a literal
 * pattern inside a RegExp constructor.
 *
 * @param {string} str - Raw string that may contain regex-special chars
 * @returns {string} Escaped string safe for new RegExp(...)
 */
function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Match a keyword against text using word boundaries (case-insensitive).
 * Replaces simple substring matching to reduce false positives.
 *
 * "escrow" matches "escrow account" but NOT "escrowed"
 * "APR" matches "The APR is 4.5%" but NOT "APRIL"
 *
 * @param {string} text - The text to search within
 * @param {string} keyword - The keyword to find (may contain regex-special chars)
 * @returns {boolean} True if keyword appears as a whole word/phrase in text
 */
function _matchKeyword(text, keyword) {
  const pattern = new RegExp(`\\b${escapeRegex(keyword)}\\b`, 'i');
  return pattern.test(text);
}

/**
 * Match a field name against a field pattern, supporting wildcards.
 *
 * - 'escrow*'  -> matches fields starting with "escrow" (case-insensitive)
 * - '*Balance' -> matches fields ending with "Balance" (case-insensitive)
 * - 'apr'      -> exact match only (case-sensitive equality)
 *
 * @param {string} fieldName - The field name to test
 * @param {string} pattern - The pattern (may include leading/trailing '*')
 * @returns {boolean} True if fieldName matches the pattern
 */
function _matchFieldPattern(fieldName, pattern) {
  if (pattern.startsWith('*') && pattern.endsWith('*')) {
    // *foo* -> contains (case-insensitive)
    const inner = pattern.slice(1, -1);
    return fieldName.toLowerCase().includes(inner.toLowerCase());
  }
  if (pattern.endsWith('*')) {
    // foo* -> starts with (case-insensitive)
    const prefix = pattern.slice(0, -1);
    return fieldName.toLowerCase().startsWith(prefix.toLowerCase());
  }
  if (pattern.startsWith('*')) {
    // *Bar -> ends with (case-insensitive)
    const suffix = pattern.slice(1);
    return fieldName.toLowerCase().endsWith(suffix.toLowerCase());
  }
  // Exact match (strict equality)
  return fieldName === pattern;
}

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/**
 * Get all rules that reference a specific statute section.
 *
 * @param {string} sectionId - Section ID from federalStatuteTaxonomy (e.g. 'respa_s10')
 * @returns {Array<Object>} Array of matching rule objects
 */
function getRulesForSection(sectionId) {
  return COMPLIANCE_RULE_MAPPINGS.filter(rule => rule.sectionId === sectionId);
}

/**
 * Get all rules in a specific category.
 *
 * @param {string} category - Category string (e.g. 'escrow', 'fees', 'disclosure')
 * @returns {Array<Object>} Array of matching rule objects
 */
function getRulesForCategory(category) {
  return COMPLIANCE_RULE_MAPPINGS.filter(rule => rule.category === category);
}

/**
 * Match rules against a forensic finding.
 *
 * Accepts a finding object and returns all rules whose matchCriteria are
 * satisfied. A rule matches if ANY of these conditions are met:
 *   - finding.discrepancyType is in the rule's discrepancyTypes
 *   - finding.anomalyType is in the rule's anomalyTypes
 *   - finding.isTimelineViolation is true AND the rule's timelineViolation is true
 *   - finding.isPaymentIssue is true AND the rule's paymentIssue is true
 *   - Any of the rule's keywords appear in the finding's description (case-insensitive)
 *   - Any of the rule's fieldPatterns match the finding's fields
 *
 * Additionally, the finding severity must meet or exceed the rule's minSeverity.
 *
 * Results are sorted by violationSeverity (highest first).
 *
 * @param {Object} finding - A finding object with optional properties:
 *   @param {string} [finding.type] - General finding type
 *   @param {string} [finding.severity] - Finding severity level
 *   @param {string} [finding.description] - Human-readable description
 *   @param {string[]} [finding.fields] - Field names involved in the finding
 *   @param {string} [finding.discrepancyType] - Discrepancy type enum value
 *   @param {string} [finding.anomalyType] - Anomaly type enum value
 *   @param {boolean} [finding.isTimelineViolation] - Whether this is a timeline violation
 *   @param {boolean} [finding.isPaymentIssue] - Whether this is a payment issue
 * @returns {Array<Object>} Matched rules sorted by severity (highest first)
 */
function matchRules(finding) {
  const severityMeetsMinimum = (findingSeverity, minSeverity) => {
    const order = SEVERITY_ORDER;
    const findingLevel = order[findingSeverity];
    const minLevel = order[minSeverity];
    // Lower number = higher severity; undefined defaults to info (4)
    return (findingLevel !== undefined ? findingLevel : 4) <= (minLevel !== undefined ? minLevel : 4);
  };

  const matched = COMPLIANCE_RULE_MAPPINGS.filter(rule => {
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

    // Check keywords in description (word-boundary matching)
    if (finding.description && criteria.keywords.length > 0) {
      if (criteria.keywords.some(kw => _matchKeyword(finding.description, kw))) {
        hasMatch = true;
      }
    }

    // Check field patterns (proper wildcard regex)
    if (finding.fields && Array.isArray(finding.fields) && criteria.fieldPatterns.length > 0) {
      if (finding.fields.some(field =>
        criteria.fieldPatterns.some(pattern => _matchFieldPattern(field, pattern))
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

module.exports = {
  COMPLIANCE_RULE_MAPPINGS,
  getRulesForSection,
  getRulesForCategory,
  matchRules,
  // Exported for testing precision
  _matchKeyword,
  _matchFieldPattern,
  escapeRegex
};
