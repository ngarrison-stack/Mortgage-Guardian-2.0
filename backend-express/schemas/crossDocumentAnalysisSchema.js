const Joi = require('joi');

// ---------------------------------------------------------------------------
// Shared enums
// ---------------------------------------------------------------------------

const DISCREPANCY_TYPES = [
  'amount_mismatch',
  'date_inconsistency',
  'party_mismatch',
  'term_contradiction',
  'timeline_violation',
  'calculation_error',
  'missing_correspondence',
  'fee_irregularity'
];

const SEVERITY_LEVELS = ['critical', 'high', 'medium', 'low', 'info'];

const RISK_LEVELS = ['low', 'medium', 'high', 'critical'];

const SIGNIFICANCE_LEVELS = ['routine', 'notable', 'concerning', 'critical'];

// ---------------------------------------------------------------------------
// Section: Document reference (reused in discrepancy documentA/documentB)
// ---------------------------------------------------------------------------
const documentRefSchema = Joi.object({
  documentId: Joi.string().required(),
  documentType: Joi.string().required(),
  documentSubtype: Joi.string().required(),
  field: Joi.string().required(),
  value: Joi.alternatives().try(
    Joi.string().allow(''),
    Joi.number(),
    Joi.allow(null)
  ).required()
}).required();

// ---------------------------------------------------------------------------
// Section: discrepancies
// Each discrepancy represents a conflict or inconsistency found between two
// documents in the case.
// ---------------------------------------------------------------------------
const discrepancySchema = Joi.object({
  /** Unique identifier within the report (e.g. "disc-001") */
  id: Joi.string().required(),

  /** Category of discrepancy */
  type: Joi.string().valid(...DISCREPANCY_TYPES).required(),

  /** How severe the finding is */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),

  /** Human-readable explanation */
  description: Joi.string().max(1000).required(),

  /** First document in the comparison */
  documentA: documentRefSchema,

  /** Second document in the comparison */
  documentB: documentRefSchema,

  /** Relevant regulation citation (e.g. "RESPA Section 6") */
  regulation: Joi.string().optional(),

  /** Detailed forensic analysis note */
  forensicNote: Joi.string().max(2000).optional()
});

// ---------------------------------------------------------------------------
// Section: timeline
// Chronological event reconstruction across all analyzed documents.
// ---------------------------------------------------------------------------
const timelineEventSchema = Joi.object({
  /** Date of the event (ISO-8601 date string) */
  date: Joi.string().required(),

  /** Which document this event comes from */
  documentId: Joi.string().required(),

  /** Document classification type */
  documentType: Joi.string().required(),

  /** Description of the event */
  event: Joi.string().max(500).required(),

  /** How significant this event is */
  significance: Joi.string().valid(...SIGNIFICANCE_LEVELS).required()
});

const timelineViolationSchema = Joi.object({
  /** Description of the timeline violation */
  description: Joi.string().max(1000).required(),

  /** How severe the violation is */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),

  /** Document IDs involved in the violation */
  relatedDocuments: Joi.array().items(Joi.string()).min(1).required(),

  /** Relevant regulation (if applicable) */
  regulation: Joi.string().optional()
});

const timelineSchema = Joi.object({
  /** Chronological events reconstructed from documents */
  events: Joi.array().items(timelineEventSchema).default([]),

  /** Timeline violations detected */
  violations: Joi.array().items(timelineViolationSchema).default([])
}).required();

// ---------------------------------------------------------------------------
// Section: paymentVerification
// Cross-reference between document-stated payments and Plaid transaction data.
// Null when no Plaid data is available.
// ---------------------------------------------------------------------------
const matchedPaymentSchema = Joi.object({
  documentDate: Joi.string().required(),
  documentAmount: Joi.number().required(),
  transactionDate: Joi.string().required(),
  transactionAmount: Joi.number().required(),
  status: Joi.string().valid('matched', 'close_match', 'mismatch').required(),
  variance: Joi.number().optional()
});

const unmatchedDocumentPaymentSchema = Joi.object({
  date: Joi.string().required(),
  amount: Joi.number().required(),
  documentId: Joi.string().required(),
  description: Joi.string().required()
});

const unmatchedTransactionSchema = Joi.object({
  date: Joi.string().required(),
  amount: Joi.number().required(),
  description: Joi.string().required(),
  possibleMatch: Joi.string().allow(null).required()
});

const escrowDisbursementSchema = Joi.object({
  date: Joi.string().required(),
  amount: Joi.number().required(),
  description: Joi.string().required()
});

const escrowAnalysisSchema = Joi.object({
  documentedMonthlyEscrow: Joi.number().required(),
  actualDisbursements: Joi.array().items(escrowDisbursementSchema).default([]),
  discrepancy: Joi.number().required(),
  findings: Joi.array().items(Joi.string()).default([])
}).allow(null).default(null);

const documentedFeeSchema = Joi.object({
  type: Joi.string().required(),
  amount: Joi.number().required(),
  documentId: Joi.string().required()
});

const transactionFeeSchema = Joi.object({
  type: Joi.string().required(),
  amount: Joi.number().required(),
  transactionDate: Joi.string().required()
});

const feeIrregularitySchema = Joi.object({
  description: Joi.string().required(),
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),
  amount: Joi.number().optional()
});

const feeAnalysisSchema = Joi.object({
  documentedFees: Joi.array().items(documentedFeeSchema).default([]),
  transactionFees: Joi.array().items(transactionFeeSchema).default([]),
  irregularities: Joi.array().items(feeIrregularitySchema).default([])
}).allow(null).default(null);

const paymentVerificationSchema = Joi.object({
  verified: Joi.boolean().required(),
  transactionsAnalyzed: Joi.number().integer().min(0).required(),
  dateRange: Joi.object({
    start: Joi.string().required(),
    end: Joi.string().required()
  }).required(),
  matchedPayments: Joi.array().items(matchedPaymentSchema).default([]),
  unmatchedDocumentPayments: Joi.array().items(unmatchedDocumentPaymentSchema).default([]),
  unmatchedTransactions: Joi.array().items(unmatchedTransactionSchema).default([]),
  escrowAnalysis: escrowAnalysisSchema,
  feeAnalysis: feeAnalysisSchema
}).allow(null).default(null);

// ---------------------------------------------------------------------------
// Section: summary
// High-level overview of cross-document analysis findings.
// ---------------------------------------------------------------------------
const summarySchema = Joi.object({
  /** Total number of discrepancies found */
  totalDiscrepancies: Joi.number().integer().min(0).required(),

  /** Number of critical-severity findings */
  criticalFindings: Joi.number().integer().min(0).required(),

  /** Number of high-severity findings */
  highFindings: Joi.number().integer().min(0).required(),

  /** Overall risk level for this case */
  riskLevel: Joi.string().valid(...RISK_LEVELS).required(),

  /** Top findings from the analysis */
  keyFindings: Joi.array().items(Joi.string()).max(20).default([]),

  /** Suggested follow-up actions */
  recommendations: Joi.array().items(Joi.string()).max(20).default([])
}).required();

// ---------------------------------------------------------------------------
// Top-level cross-document analysis report schema
// ---------------------------------------------------------------------------

/**
 * Joi validation schema for cross-document forensic analysis reports.
 *
 * This is the contract between the cross-document comparison engine and all
 * downstream consumers (API, frontend, reporting, dispute letter generation).
 *
 * Sections:
 *  - caseId:                    case identifier
 *  - analyzedAt:                ISO-8601 timestamp
 *  - documentsAnalyzed:         count of documents in the analysis
 *  - comparisonPairsEvaluated:  count of comparison pairs evaluated
 *  - discrepancies:             conflicts found between documents
 *  - timeline:                  chronological event reconstruction
 *  - paymentVerification:       Plaid cross-reference (null if unavailable)
 *  - summary:                   high-level findings and risk assessment
 */
const crossDocumentAnalysisSchema = Joi.object({
  /** Case identifier */
  caseId: Joi.string().required(),

  /** ISO-8601 timestamp of when analysis was performed */
  analyzedAt: Joi.string().isoDate().required(),

  /** Number of documents included in the analysis */
  documentsAnalyzed: Joi.number().integer().min(2).required(),

  /** Number of comparison pairs that were evaluated */
  comparisonPairsEvaluated: Joi.number().integer().min(0).required(),

  /** Discrepancies found between documents */
  discrepancies: Joi.array().items(discrepancySchema).default([]),

  /** Chronological timeline reconstruction */
  timeline: timelineSchema,

  /** Payment verification against Plaid data (null when unavailable) */
  paymentVerification: paymentVerificationSchema,

  /** High-level analysis summary */
  summary: summarySchema
});

/**
 * Validate a cross-document analysis report object against the schema.
 *
 * @param {Object} data - The cross-document analysis report to validate
 * @returns {{ value: Object, error: import('joi').ValidationError|undefined }}
 *   Validated/coerced value and any validation error
 */
function validateCrossDocumentAnalysis(data) {
  return crossDocumentAnalysisSchema.validate(data, { abortEarly: false });
}

module.exports = {
  crossDocumentAnalysisSchema,
  validateCrossDocumentAnalysis,
  DISCREPANCY_TYPES,
  SEVERITY_LEVELS,
  RISK_LEVELS,
  SIGNIFICANCE_LEVELS
};
