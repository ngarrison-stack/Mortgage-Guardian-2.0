/**
 * Document Field Definitions for Completeness Scoring
 *
 * Maps every document type/subtype from DOCUMENT_TAXONOMY to its expected
 * fields. Used by the analysis service to calculate completeness scores and
 * flag missing critical information.
 *
 * Field tiers:
 *  - critical:  Essential for document validity — missing = high-severity anomaly
 *  - expected:  Normally present in this document type — missing = medium-severity finding
 *  - optional:  Sometimes present — missing = info-level note only
 *
 * Covers all 6 categories and 54 subtypes defined in classificationService.js.
 */

const DOCUMENT_FIELD_DEFINITIONS = {

  // =========================================================================
  // ORIGINATION DOCUMENTS (12 subtypes)
  // =========================================================================
  origination: {

    loan_application_1003: {
      critical: ['borrowerName', 'propertyAddress', 'loanAmount', 'loanPurpose', 'applicationDate'],
      expected: ['employerName', 'monthlyIncome', 'totalAssets', 'totalLiabilities', 'coBorrower', 'propertyType'],
      optional: ['previousAddress', 'yearsAtJob', 'dependentsCount', 'housingExpense']
    },

    good_faith_estimate: {
      critical: ['loanAmount', 'interestRate', 'monthlyPayment', 'estimatedClosingCosts', 'preparedDate'],
      expected: ['borrower', 'lender', 'propertyAddress', 'loanTerm', 'originationCharges', 'escrowDeposit'],
      optional: ['titleCharges', 'transferTaxes', 'recordingFees', 'inspectionFees']
    },

    loan_estimate: {
      critical: ['loanAmount', 'interestRate', 'monthlyPayment', 'estimatedClosingCosts', 'issuedDate'],
      expected: ['borrower', 'lender', 'propertyAddress', 'loanTerm', 'apr', 'totalInterestPercentage', 'estimatedTaxesInsurance'],
      optional: ['comparisons', 'otherConsiderations', 'adjustableRateDetails', 'prepaymentPenalty']
    },

    truth_in_lending: {
      critical: ['apr', 'financeCharge', 'amountFinanced', 'totalOfPayments', 'disclosureDate'],
      expected: ['borrower', 'lender', 'monthlyPayment', 'paymentSchedule', 'lateChargeTerms'],
      optional: ['demandFeature', 'variableRateFeature', 'insuranceRequirements', 'securityInterest']
    },

    promissory_note: {
      critical: ['principalAmount', 'interestRate', 'maturityDate', 'borrower', 'lender', 'monthlyPayment'],
      expected: ['executionDate', 'loanNumber', 'propertyAddress', 'lateChargeTerms', 'prepaymentTerms'],
      optional: ['cosigner', 'rateAdjustmentTerms', 'assumabilityTerms']
    },

    deed_of_trust: {
      critical: ['borrower', 'lender', 'trustee', 'propertyAddress', 'legalDescription', 'executionDate'],
      expected: ['loanAmount', 'recordingInfo', 'riderAttachments', 'loanNumber'],
      optional: ['covenants', 'condemnationClause', 'accelerationTerms', 'reinstateTerms']
    },

    mortgage_deed: {
      critical: ['borrower', 'lender', 'propertyAddress', 'legalDescription', 'executionDate', 'loanAmount'],
      expected: ['recordingInfo', 'loanNumber', 'maturityDate', 'notaryInfo'],
      optional: ['witnesses', 'riderAttachments', 'specialCovenants']
    },

    hud1_settlement: {
      critical: ['borrower', 'seller', 'propertyAddress', 'settlementDate', 'totalSettlementCharges', 'loanAmount'],
      expected: ['lender', 'grossAmountDueSeller', 'cashToClose', 'realEstateBrokerFees', 'originationCharges', 'titleCharges'],
      optional: ['governmentRecordingCharges', 'transferTaxes', 'adjustmentsForItems', 'additionalCharges']
    },

    closing_disclosure: {
      critical: ['loanAmount', 'interestRate', 'monthlyPayment', 'closingDate', 'cashToClose', 'apr'],
      expected: ['borrower', 'seller', 'lender', 'propertyAddress', 'loanType', 'loanTerm', 'totalClosingCosts', 'totalInterestCost'],
      optional: ['prepaymentPenalty', 'balloonPayment', 'escrowMonthly']
    },

    appraisal_report: {
      critical: ['propertyAddress', 'appraisedValue', 'appraisalDate', 'appraiser'],
      expected: ['propertyType', 'squareFootage', 'yearBuilt', 'comparableSales', 'lotSize', 'condition'],
      optional: ['zoning', 'floodZone', 'environmentalConcerns', 'neighborhoodDescription']
    },

    title_insurance: {
      critical: ['propertyAddress', 'insuredAmount', 'policyDate', 'insurer'],
      expected: ['policyNumber', 'legalDescription', 'exceptions', 'borrower', 'lender'],
      optional: ['endorsements', 'surveyReference', 'priorPolicies']
    },

    right_to_cancel: {
      critical: ['borrower', 'propertyAddress', 'transactionDate', 'cancellationDeadline'],
      expected: ['lender', 'loanAmount', 'noticeDate', 'howToCancel'],
      optional: ['effectsOfCancellation', 'additionalDisclosures']
    }
  },

  // =========================================================================
  // SERVICING DOCUMENTS (9 subtypes)
  // =========================================================================
  servicing: {

    monthly_statement: {
      critical: ['principalBalance', 'monthlyPayment', 'interestRate', 'paymentDueDate', 'statementDate'],
      expected: ['escrowBalance', 'lateCharges', 'unpaidFees', 'borrower', 'loanNumber', 'servicer', 'propertyAddress'],
      optional: ['nextPaymentAmount', 'payoffAmount', 'suspenseBalance', 'deferredBalance']
    },

    escrow_analysis: {
      critical: ['escrowBalance', 'projectedBalance', 'annualEscrowAmount', 'monthlyEscrowPayment', 'effectiveDate'],
      expected: ['propertyTaxAmount', 'insurancePremium', 'shortageAmount', 'surplusAmount', 'borrower', 'loanNumber'],
      optional: ['floodInsurance', 'pmiAmount', 'hoaDues']
    },

    escrow_statement: {
      critical: ['escrowBalance', 'monthlyEscrowPayment', 'statementDate', 'statementPeriod'],
      expected: ['propertyTaxDisbursements', 'insuranceDisbursements', 'borrower', 'loanNumber', 'shortageAmount'],
      optional: ['surplusAmount', 'pmiDisbursements', 'otherDisbursements', 'projectedActivity']
    },

    payment_history: {
      critical: ['paymentDates', 'paymentAmounts', 'principalApplied', 'interestApplied'],
      expected: ['escrowApplied', 'lateFees', 'totalPaid', 'beginningBalance', 'endingBalance', 'loanNumber'],
      optional: ['suspenseActivity', 'feeBreakdown']
    },

    arm_adjustment_notice: {
      critical: ['currentRate', 'newRate', 'effectiveDate', 'newPaymentAmount', 'indexValue'],
      expected: ['margin', 'rateCap', 'borrower', 'loanNumber', 'nextAdjustmentDate'],
      optional: ['lifetimeCap', 'floorRate', 'lookbackPeriod', 'paymentChangeDate']
    },

    tax_payment_record: {
      critical: ['taxAmount', 'paymentDate', 'taxYear', 'propertyAddress'],
      expected: ['taxingAuthority', 'parcelNumber', 'loanNumber', 'borrower', 'paymentSource'],
      optional: ['delinquentAmount', 'nextDueDate', 'exemptions']
    },

    insurance_payment_record: {
      critical: ['premiumAmount', 'paymentDate', 'coveragePeriod', 'insuranceType'],
      expected: ['insuranceCompany', 'policyNumber', 'borrower', 'loanNumber', 'propertyAddress'],
      optional: ['deductible', 'coverageAmount', 'agentInfo']
    },

    payoff_statement: {
      critical: ['payoffAmount', 'goodThroughDate', 'principalBalance', 'perDiemInterest'],
      expected: ['unpaidInterest', 'escrowBalance', 'fees', 'borrower', 'loanNumber', 'servicer'],
      optional: ['recordingFees', 'wireInstructions', 'prepaymentPenalty', 'suspenseBalance']
    },

    annual_escrow_disclosure: {
      critical: ['currentMonthlyEscrow', 'newMonthlyEscrow', 'effectiveDate', 'disclosureDate'],
      expected: ['projectedDisbursements', 'projectedBalances', 'shortageAmount', 'surplusAmount', 'borrower', 'loanNumber'],
      optional: ['cushionAmount', 'spreadOption', 'paymentOptions']
    }
  },

  // =========================================================================
  // CORRESPONDENCE (11 subtypes)
  // =========================================================================
  correspondence: {

    loss_mitigation_application: {
      critical: ['borrower', 'propertyAddress', 'applicationDate', 'hardshipType', 'requestedRelief'],
      expected: ['monthlyIncome', 'monthlyExpenses', 'loanNumber', 'servicer', 'currentPayment'],
      optional: ['coBorrower', 'additionalIncome', 'hardshipDetails', 'supportingDocuments']
    },

    forbearance_agreement: {
      critical: ['borrower', 'forbearancePeriod', 'startDate', 'endDate', 'modifiedPaymentAmount'],
      expected: ['loanNumber', 'servicer', 'propertyAddress', 'originalPayment', 'resumptionTerms'],
      optional: ['deferredAmount', 'extensionOptions', 'defaultTriggers']
    },

    loan_modification: {
      critical: ['borrower', 'newInterestRate', 'newMonthlyPayment', 'effectiveDate', 'modifiedPrincipal'],
      expected: ['originalTerms', 'loanNumber', 'servicer', 'propertyAddress', 'newMaturityDate', 'trialPeriod'],
      optional: ['principalForgiveness', 'deferredBalance', 'rateStepSchedule', 'escrowChanges']
    },

    qualified_written_request: {
      critical: ['borrower', 'requestDate', 'requestType', 'specificIssue'],
      expected: ['loanNumber', 'servicer', 'propertyAddress', 'responseDeadline'],
      optional: ['supportingEvidence', 'priorCommunications', 'regulatoryCitation']
    },

    notice_of_error: {
      critical: ['borrower', 'noticeDate', 'errorDescription', 'correctionRequested'],
      expected: ['loanNumber', 'servicer', 'propertyAddress', 'responseDeadline', 'affectedAmount'],
      optional: ['supportingDocuments', 'regulatoryCitation', 'priorNotices']
    },

    information_request: {
      critical: ['borrower', 'requestDate', 'informationRequested'],
      expected: ['loanNumber', 'servicer', 'propertyAddress', 'responseDeadline'],
      optional: ['purposeOfRequest', 'format', 'priorRequests']
    },

    collection_notice: {
      critical: ['borrower', 'amountOwed', 'noticeDate', 'creditor'],
      expected: ['loanNumber', 'propertyAddress', 'debtDescription', 'disputeRights', 'responseDeadline'],
      optional: ['originalCreditor', 'validationNotice', 'fdcpaDisclosure']
    },

    foreclosure_notice: {
      critical: ['noticeDate', 'defaultAmount', 'cureDeadline', 'borrower', 'propertyAddress'],
      expected: ['loanNumber', 'servicer', 'rightToCure', 'legalCounselInfo', 'totalAmountDue'],
      optional: ['saleDate', 'militaryServiceNotice', 'housingCounselorInfo']
    },

    default_notice: {
      critical: ['borrower', 'noticeDate', 'defaultAmount', 'defaultReason', 'cureDeadline'],
      expected: ['loanNumber', 'servicer', 'propertyAddress', 'consequencesOfDefault'],
      optional: ['paymentBreakdown', 'lateCharges', 'lossmitigationOptions']
    },

    acceleration_letter: {
      critical: ['borrower', 'letterDate', 'acceleratedBalance', 'paymentDeadline'],
      expected: ['loanNumber', 'servicer', 'propertyAddress', 'defaultHistory', 'totalAmountDue'],
      optional: ['reinstatementOption', 'legalAction', 'rightToContest']
    },

    general_correspondence: {
      critical: ['sender', 'recipient', 'correspondenceDate', 'subject'],
      expected: ['loanNumber', 'propertyAddress', 'contentSummary'],
      optional: ['attachments', 'responseRequested', 'followUpDate']
    }
  },

  // =========================================================================
  // LEGAL DOCUMENTS (10 subtypes)
  // =========================================================================
  legal: {

    assignment_of_mortgage: {
      critical: ['assignor', 'assignee', 'assignmentDate', 'propertyAddress', 'legalDescription'],
      expected: ['originalMortgageDate', 'recordingInfo', 'loanAmount', 'borrower', 'notaryInfo'],
      optional: ['mers', 'considerationAmount', 'effectiveDate']
    },

    substitution_of_trustee: {
      critical: ['originalTrustee', 'newTrustee', 'substitutionDate', 'propertyAddress'],
      expected: ['lender', 'borrower', 'recordingInfo', 'loanNumber', 'legalDescription'],
      optional: ['notaryInfo', 'effectiveDate', 'reasonForSubstitution']
    },

    notice_of_default: {
      critical: ['borrower', 'defaultDate', 'defaultAmount', 'propertyAddress', 'recordingDate'],
      expected: ['trustee', 'beneficiary', 'loanNumber', 'legalDescription', 'cureDeadline'],
      optional: ['recordingInfo', 'contactInfo', 'reinstatementRights']
    },

    lis_pendens: {
      critical: ['plaintiff', 'defendant', 'filingDate', 'propertyAddress', 'caseNumber'],
      expected: ['court', 'legalDescription', 'claimType', 'recordingInfo'],
      optional: ['attorney', 'reliefSought', 'hearingDate']
    },

    court_judgment: {
      critical: ['plaintiff', 'defendant', 'judgmentDate', 'judgmentAmount', 'caseNumber'],
      expected: ['court', 'judge', 'propertyAddress', 'judgmentType'],
      optional: ['interestRate', 'costs', 'attorneyFees', 'enforcementTerms']
    },

    court_order: {
      critical: ['court', 'orderDate', 'orderType', 'caseNumber', 'parties'],
      expected: ['judge', 'propertyAddress', 'orderTerms', 'complianceDeadline'],
      optional: ['sanctions', 'nextHearingDate', 'stayProvisions']
    },

    bankruptcy_filing: {
      critical: ['debtor', 'filingDate', 'chapter', 'caseNumber', 'court'],
      expected: ['trustee', 'scheduleOfDebts', 'propertyAddress', 'loanNumber', 'automaticStayDate'],
      optional: ['planPayment', 'cramdownAmount', 'dischargDate', 'reaffirmation']
    },

    proof_of_claim: {
      critical: ['creditor', 'debtorName', 'claimAmount', 'filingDate', 'caseNumber'],
      expected: ['basisForClaim', 'securedAmount', 'unsecuredAmount', 'arrearsAmount', 'propertyAddress'],
      optional: ['attachedDocuments', 'interestRate', 'feesOwed']
    },

    satisfaction_of_mortgage: {
      critical: ['borrower', 'lender', 'satisfactionDate', 'propertyAddress', 'legalDescription'],
      expected: ['originalMortgageDate', 'recordingInfo', 'loanNumber', 'notaryInfo'],
      optional: ['considerationPaid', 'effectiveDate']
    },

    release_of_lien: {
      critical: ['lienholder', 'borrower', 'releaseDate', 'propertyAddress', 'legalDescription'],
      expected: ['originalLienDate', 'lienAmount', 'recordingInfo', 'loanNumber'],
      optional: ['notaryInfo', 'conditions', 'effectiveDate']
    }
  },

  // =========================================================================
  // FINANCIAL DOCUMENTS (6 subtypes)
  // =========================================================================
  financial: {

    bank_statement: {
      critical: ['accountHolder', 'accountNumber', 'statementPeriod', 'endingBalance'],
      expected: ['beginningBalance', 'totalDeposits', 'totalWithdrawals', 'bankName', 'accountType'],
      optional: ['averageBalance', 'interestEarned', 'fees', 'overdraftCount']
    },

    tax_return: {
      critical: ['taxpayerName', 'taxYear', 'adjustedGrossIncome', 'taxableIncome', 'filingStatus'],
      expected: ['totalIncome', 'totalDeductions', 'taxOwed', 'taxPaid', 'refundAmount'],
      optional: ['selfEmploymentIncome', 'rentalIncome', 'capitalGains', 'dependents']
    },

    income_verification: {
      critical: ['employeeName', 'employerName', 'annualIncome', 'verificationDate'],
      expected: ['positionTitle', 'employmentStartDate', 'payFrequency', 'ytdEarnings', 'basePayRate'],
      optional: ['overtimeIncome', 'bonusIncome', 'commissionIncome', 'probabilityOfContinuance']
    },

    credit_report: {
      critical: ['borrowerName', 'reportDate', 'creditScore', 'totalAccounts'],
      expected: ['openAccounts', 'closedAccounts', 'totalDebt', 'monthlyPayments', 'delinquencies', 'reportingAgency'],
      optional: ['inquiries', 'publicRecords', 'collections', 'utilizationRate']
    },

    profit_loss_statement: {
      critical: ['businessName', 'statementPeriod', 'totalRevenue', 'totalExpenses', 'netIncome'],
      expected: ['grossProfit', 'operatingExpenses', 'preparedBy', 'preparedDate'],
      optional: ['costOfGoodsSold', 'depreciation', 'interestExpense', 'taxes']
    },

    asset_verification: {
      critical: ['accountHolder', 'institutionName', 'accountType', 'currentBalance', 'verificationDate'],
      expected: ['accountNumber', 'averageBalance', 'sourceOfDeposits'],
      optional: ['maturityDate', 'interestRate', 'liquidationValue', 'restrictions']
    }
  },

  // =========================================================================
  // REGULATORY NOTICES (6 subtypes)
  // =========================================================================
  regulatory: {

    respa_disclosure: {
      critical: ['disclosureDate', 'disclosureType', 'servicer', 'borrower'],
      expected: ['loanNumber', 'propertyAddress', 'transferDate', 'newServicerInfo', 'requiredLanguage'],
      optional: ['disputeRights', 'contactInfo', 'effectiveDate']
    },

    tila_disclosure: {
      critical: ['disclosureDate', 'apr', 'financeCharge', 'amountFinanced', 'totalOfPayments'],
      expected: ['borrower', 'lender', 'paymentSchedule', 'lateChargeTerms', 'securityInterest'],
      optional: ['variableRateDisclosure', 'demandFeature', 'insuranceRequirements']
    },

    ecoa_notice: {
      critical: ['noticeDate', 'applicant', 'actionTaken', 'actionDate'],
      expected: ['creditor', 'reasonForAction', 'ecoaStatement', 'applicantRights'],
      optional: ['contactInfo', 'agencyAddress', 'additionalInfo']
    },

    fdcpa_notice: {
      critical: ['noticeDate', 'debtCollector', 'borrower', 'amountOwed'],
      expected: ['originalCreditor', 'validationRights', 'disputeDeadline', 'debtDescription'],
      optional: ['miniMiranda', 'stateDisclosures', 'communicationPreferences']
    },

    scra_notice: {
      critical: ['noticeDate', 'servicemember', 'propertyAddress', 'protectionType'],
      expected: ['servicer', 'loanNumber', 'interestRateCap', 'effectiveDate', 'expirationDate'],
      optional: ['activedutyOrders', 'additionalProtections', 'contactInfo']
    },

    state_regulatory_notice: {
      critical: ['noticeDate', 'issuingAgency', 'borrower', 'noticeType'],
      expected: ['propertyAddress', 'loanNumber', 'servicer', 'requiredAction', 'stateStatute'],
      optional: ['responseDeadline', 'hearingDate', 'penaltyAmount', 'appealRights']
    }
  }
};

// ---------------------------------------------------------------------------
// Generic fallback for unknown or unrecognized subtypes
// ---------------------------------------------------------------------------
const GENERIC_FIELD_DEFINITION = {
  critical: ['documentDate', 'parties', 'documentPurpose'],
  expected: ['loanNumber', 'propertyAddress', 'amounts'],
  optional: ['additionalTerms', 'signatures', 'attachments']
};

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/**
 * Get the field definition for a document type/subtype.
 *
 * Returns the specific definition if both type and subtype are known,
 * otherwise falls back to the generic definition.
 *
 * @param {string} classificationType - Broad category (e.g. "servicing")
 * @param {string} classificationSubtype - Specific subtype (e.g. "monthly_statement")
 * @returns {{ critical: string[], expected: string[], optional: string[] }}
 */
function getFieldDefinition(classificationType, classificationSubtype) {
  const category = DOCUMENT_FIELD_DEFINITIONS[classificationType];
  if (!category) {
    return GENERIC_FIELD_DEFINITION;
  }
  const definition = category[classificationSubtype];
  if (!definition) {
    return GENERIC_FIELD_DEFINITION;
  }
  return definition;
}

/**
 * Get the count of expected fields (critical + expected) for a document type.
 *
 * This count is used as the denominator for completeness scoring. Optional
 * fields are excluded because their absence is not a concern.
 *
 * @param {string} classificationType - Broad category
 * @param {string} classificationSubtype - Specific subtype
 * @returns {number} Count of critical + expected fields
 */
function getExpectedFieldCount(classificationType, classificationSubtype) {
  const definition = getFieldDefinition(classificationType, classificationSubtype);
  return definition.critical.length + definition.expected.length;
}

/**
 * Categorize a field name for a given document type/subtype.
 *
 * Returns which tier the field belongs to, or 'unknown' if the field is not
 * in any tier's definition.
 *
 * @param {string} fieldName - The field name to categorize
 * @param {string} classificationType - Broad category
 * @param {string} classificationSubtype - Specific subtype
 * @returns {'critical'|'expected'|'optional'|'unknown'}
 */
function categorizeField(fieldName, classificationType, classificationSubtype) {
  const definition = getFieldDefinition(classificationType, classificationSubtype);

  if (definition.critical.includes(fieldName)) {
    return 'critical';
  }
  if (definition.expected.includes(fieldName)) {
    return 'expected';
  }
  if (definition.optional.includes(fieldName)) {
    return 'optional';
  }
  return 'unknown';
}

module.exports = {
  DOCUMENT_FIELD_DEFINITIONS,
  GENERIC_FIELD_DEFINITION,
  getFieldDefinition,
  getExpectedFieldCount,
  categorizeField
};
