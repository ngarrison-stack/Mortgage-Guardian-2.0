/**
 * Consolidated Report Configuration
 *
 * Defines confidence scoring weights, risk thresholds, evidence linking
 * categories, recommendation priority mappings, and RESPA dispute letter
 * configuration for the consolidated audit report generation engine.
 *
 * This is config data — declarative, no business logic.
 *
 * Used by: consolidated report aggregation service, confidence scoring
 * engine, evidence linker, recommendation generator, dispute letter builder.
 */

// ---------------------------------------------------------------------------
// Confidence Scoring Weights
//
// How much each analysis layer contributes to the overall confidence score.
// Values must sum to 1.0.
// ---------------------------------------------------------------------------

/**
 * Top-level weights for each analysis layer.
 * Forensic and compliance analysis are weighted slightly higher because they
 * synthesize findings across documents and against legal standards.
 */
const SCORING_WEIGHTS = {
  documentAnalysis: 0.30,
  forensicAnalysis: 0.35,
  complianceAnalysis: 0.35
};

/**
 * Per-layer scoring factors that determine how sub-components within each
 * analysis layer affect the layer's confidence score.
 *
 * For each layer, factor weights sum to 1.0. Higher values in "penalty"
 * factors mean the presence of issues reduces confidence more steeply.
 */
const LAYER_SCORING_FACTORS = {
  documentAnalysis: {
    /** Higher completeness = higher confidence */
    completenessWeight: 0.4,
    /** More anomalies = lower confidence */
    anomalyPenalty: 0.6
  },

  forensicAnalysis: {
    /** Discrepancies between documents reduce confidence */
    discrepancyPenalty: 0.5,
    /** Timeline violations reduce confidence */
    timelinePenalty: 0.3,
    /** Payment verification issues reduce confidence */
    paymentPenalty: 0.2
  },

  complianceAnalysis: {
    /** Statutory violations reduce confidence */
    violationPenalty: 0.7,
    /**
     * Multiplier applied per violation based on severity.
     * A critical violation has 4x the impact of a low violation.
     */
    severityMultiplier: {
      critical: 4,
      high: 3,
      medium: 2,
      low: 1,
      info: 0
    }
  }
};

// ---------------------------------------------------------------------------
// Risk Level Thresholds
//
// Map overall confidence score ranges to risk levels. A lower confidence
// score indicates higher risk (more issues found).
//
// Evaluated in order: if score <= maxScore, that risk level applies.
// ---------------------------------------------------------------------------

/**
 * Confidence score thresholds for each risk level.
 * Evaluated from most severe to least severe:
 *   score <= 25 → critical
 *   score <= 50 → high
 *   score <= 70 → medium
 *   score <= 90 → low
 *   score <= 100 → clean
 */
const RISK_THRESHOLDS = {
  critical: { maxScore: 25 },
  high: { maxScore: 50 },
  medium: { maxScore: 70 },
  low: { maxScore: 90 },
  clean: { maxScore: 100 }
};

// ---------------------------------------------------------------------------
// Evidence Linking Categories
//
// Maps each finding type to metadata used when creating evidence links
// in the consolidated report. Source description templates use {id}
// placeholders that the linker replaces with actual finding identifiers.
// ---------------------------------------------------------------------------

/**
 * Evidence category definitions for each finding type.
 * The `sourceDescriptionTemplate` is a human-readable template string
 * with `{id}` placeholder for the finding identifier.
 */
const EVIDENCE_CATEGORIES = {
  anomaly: {
    findingType: 'anomaly',
    sourceLayer: 'documentAnalysis',
    sourceDescriptionTemplate: 'Document anomaly {id} detected during individual document analysis',
    relevantFields: ['field', 'type', 'severity', 'description']
  },

  discrepancy: {
    findingType: 'discrepancy',
    sourceLayer: 'forensicAnalysis',
    sourceDescriptionTemplate: 'Cross-document discrepancy {id} found during forensic comparison',
    relevantFields: ['type', 'severity', 'documentA', 'documentB']
  },

  timelineViolation: {
    findingType: 'timelineViolation',
    sourceLayer: 'forensicAnalysis',
    sourceDescriptionTemplate: 'Timeline violation detected in forensic timeline reconstruction',
    relevantFields: ['severity', 'relatedDocuments', 'regulation']
  },

  paymentIssue: {
    findingType: 'paymentIssue',
    sourceLayer: 'forensicAnalysis',
    sourceDescriptionTemplate: 'Payment verification issue identified during Plaid cross-reference',
    relevantFields: ['status', 'variance', 'documentDate', 'transactionDate']
  },

  federalViolation: {
    findingType: 'federalViolation',
    sourceLayer: 'complianceAnalysis',
    sourceDescriptionTemplate: 'Federal statutory violation {id} under {statuteName}',
    relevantFields: ['statuteId', 'sectionId', 'citation', 'severity']
  },

  stateViolation: {
    findingType: 'stateViolation',
    sourceLayer: 'complianceAnalysis',
    sourceDescriptionTemplate: 'State statutory violation {id} under {statuteName} ({jurisdiction})',
    relevantFields: ['statuteId', 'sectionId', 'citation', 'jurisdiction', 'severity']
  }
};

// ---------------------------------------------------------------------------
// Recommendation Priority Mapping
//
// Maps severity levels to recommendation priority numbers (1 = highest).
// Used by the recommendation generator to sort and prioritize actions.
// ---------------------------------------------------------------------------

/**
 * Severity-to-priority mapping. Lower number = higher priority.
 */
const RECOMMENDATION_PRIORITY = {
  critical: 1,
  high: 2,
  medium: 3,
  low: 4,
  info: 5
};

// ---------------------------------------------------------------------------
// RESPA Dispute Letter Configuration
//
// Defines the types of dispute letters the platform can generate and
// the required sections for each letter type.
// ---------------------------------------------------------------------------

/**
 * Available dispute letter types under RESPA.
 */
const LETTER_TYPES = [
  'qualified_written_request',
  'notice_of_error',
  'request_for_information'
];

/**
 * Required sections for each dispute letter type.
 * Each section has an id, title, and description of what content is expected.
 */
const LETTER_SECTIONS = {
  qualified_written_request: [
    {
      id: 'header',
      title: 'Letter Header',
      description: 'Date, borrower information, loan number, servicer address'
    },
    {
      id: 'qwr_declaration',
      title: 'QWR Declaration',
      description: 'Explicit statement that this is a Qualified Written Request under RESPA Section 6'
    },
    {
      id: 'account_identification',
      title: 'Account Identification',
      description: 'Loan number, property address, and borrower identification'
    },
    {
      id: 'error_description',
      title: 'Error Description',
      description: 'Detailed description of the servicing errors identified'
    },
    {
      id: 'supporting_evidence',
      title: 'Supporting Evidence',
      description: 'Reference to specific documents and findings that support the claim'
    },
    {
      id: 'requested_action',
      title: 'Requested Action',
      description: 'Specific corrective actions requested from the servicer'
    },
    {
      id: 'legal_notice',
      title: 'Legal Notice',
      description: 'Citation of applicable statutes and servicer obligations under RESPA'
    },
    {
      id: 'closing',
      title: 'Closing',
      description: 'Response deadline, contact information, signature block'
    }
  ],

  notice_of_error: [
    {
      id: 'header',
      title: 'Letter Header',
      description: 'Date, borrower information, loan number, servicer address'
    },
    {
      id: 'noe_declaration',
      title: 'Notice of Error Declaration',
      description: 'Statement that this is a Notice of Error under 12 CFR 1024.35'
    },
    {
      id: 'account_identification',
      title: 'Account Identification',
      description: 'Loan number, property address, and borrower identification'
    },
    {
      id: 'error_specification',
      title: 'Error Specification',
      description: 'Identification of the specific error category under 12 CFR 1024.35(b)'
    },
    {
      id: 'error_details',
      title: 'Error Details',
      description: 'Detailed explanation of the error with supporting data'
    },
    {
      id: 'requested_correction',
      title: 'Requested Correction',
      description: 'Specific correction requested and expected timeline'
    },
    {
      id: 'legal_notice',
      title: 'Legal Notice',
      description: 'Servicer obligations under Regulation X and response deadlines'
    },
    {
      id: 'closing',
      title: 'Closing',
      description: 'Response deadline (30 business days), contact information, signature block'
    }
  ],

  request_for_information: [
    {
      id: 'header',
      title: 'Letter Header',
      description: 'Date, borrower information, loan number, servicer address'
    },
    {
      id: 'rfi_declaration',
      title: 'RFI Declaration',
      description: 'Statement that this is a Request for Information under 12 CFR 1024.36'
    },
    {
      id: 'account_identification',
      title: 'Account Identification',
      description: 'Loan number, property address, and borrower identification'
    },
    {
      id: 'information_requested',
      title: 'Information Requested',
      description: 'Specific information being requested with sufficient detail'
    },
    {
      id: 'purpose',
      title: 'Purpose of Request',
      description: 'Explanation of why the information is needed'
    },
    {
      id: 'legal_notice',
      title: 'Legal Notice',
      description: 'Servicer obligations under Regulation X and response deadlines'
    },
    {
      id: 'closing',
      title: 'Closing',
      description: 'Response deadline (30 business days), contact information, signature block'
    }
  ]
};

module.exports = {
  SCORING_WEIGHTS,
  LAYER_SCORING_FACTORS,
  RISK_THRESHOLDS,
  EVIDENCE_CATEGORIES,
  RECOMMENDATION_PRIORITY,
  LETTER_TYPES,
  LETTER_SECTIONS
};
