const Joi = require('joi');

// ---------------------------------------------------------------------------
// Flexible value type for extracted data fields.
// Documents vary widely — a field value can be a string, number, boolean,
// null, or an array of those primitives (e.g. multiple dates).
// ---------------------------------------------------------------------------
const flexibleValue = Joi.alternatives().try(
  Joi.string().allow(''),
  Joi.number(),
  Joi.boolean(),
  Joi.allow(null),
  Joi.array().items(
    Joi.alternatives().try(
      Joi.string().allow(''),
      Joi.number(),
      Joi.boolean(),
      Joi.allow(null)
    )
  )
);

/**
 * Flexible key-value pattern for extracted data sections.
 * Keys are always strings; values are flexible primitives or arrays thereof.
 */
const flexibleObjectPattern = Joi.object().pattern(Joi.string(), flexibleValue);

// ---------------------------------------------------------------------------
// Section: documentInfo
// Metadata about the classification and analysis run itself.
// ---------------------------------------------------------------------------
const documentInfoSchema = Joi.object({
  /** Broad classification type (e.g. "servicing", "origination") */
  documentType: Joi.string().required(),

  /** Specific subtype (e.g. "monthly_statement", "closing_disclosure") */
  documentSubtype: Joi.string().required(),

  /** ISO-8601 timestamp of when analysis was performed */
  analyzedAt: Joi.string().isoDate().required(),

  /** Claude model identifier used for analysis */
  modelUsed: Joi.string().required(),

  /** Overall confidence score for the analysis (0-1) */
  confidence: Joi.number().min(0).max(1).required()
}).required();

// ---------------------------------------------------------------------------
// Section: extractedData
// Structured fields pulled from the document text by Claude. Each sub-object
// uses pattern matching so any field name is accepted — different document
// types will produce different field names.
// ---------------------------------------------------------------------------
const extractedDataSchema = Joi.object({
  /** Named date fields (e.g. statementDate, paymentDueDate) */
  dates: flexibleObjectPattern.default({}),

  /** Named dollar amounts (e.g. principalBalance, monthlyPayment) */
  amounts: flexibleObjectPattern.default({}),

  /** Named percentage rates (e.g. interestRate, apr) */
  rates: flexibleObjectPattern.default({}),

  /** Named parties (e.g. borrower, lender, servicer) */
  parties: flexibleObjectPattern.default({}),

  /** Account/loan identifiers and addresses */
  identifiers: flexibleObjectPattern.default({}),

  /** Loan/document terms (e.g. loanType, amortizationType) */
  terms: flexibleObjectPattern.default({}),

  /** Type-specific fields that don't fit the above categories */
  custom: flexibleObjectPattern.default({})
}).required();

// ---------------------------------------------------------------------------
// Section: anomalies
// Issues, inconsistencies, or concerns detected during analysis.
// ---------------------------------------------------------------------------
const ANOMALY_TYPES = [
  'unusual_value',
  'inconsistency',
  'missing_required',
  'calculation_error',
  'regulatory_concern'
];

const SEVERITY_LEVELS = ['critical', 'high', 'medium', 'low', 'info'];

const anomalyItemSchema = Joi.object({
  /** Which extracted field is anomalous */
  field: Joi.string().required(),

  /** Category of anomaly */
  type: Joi.string().valid(...ANOMALY_TYPES).required(),

  /** How severe the finding is */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),

  /** Human-readable explanation of the anomaly */
  description: Joi.string().required(),

  /** What was expected (if applicable) */
  expectedValue: Joi.any().optional(),

  /** What was actually found (if applicable) */
  actualValue: Joi.any().optional(),

  /** Relevant regulation citation (e.g. "RESPA Section 6") */
  regulation: Joi.string().optional()
});

const anomaliesSchema = Joi.array().items(anomalyItemSchema).default([]);

// ---------------------------------------------------------------------------
// Section: completeness
// How thoroughly the document was able to be extracted, measured against
// the expected fields for this document type/subtype.
// ---------------------------------------------------------------------------
const completenessSchema = Joi.object({
  /** Percentage of expected fields that were present (0-100) */
  score: Joi.number().min(0).max(100).required(),

  /** Total number of fields expected for this document type */
  totalExpectedFields: Joi.number().integer().min(0).required(),

  /** Field names that were successfully extracted */
  presentFields: Joi.array().items(Joi.string()).required(),

  /** Field names that were NOT found in the document */
  missingFields: Joi.array().items(Joi.string()).required(),

  /** Subset of missingFields that are critical for document validity */
  missingCritical: Joi.array().items(Joi.string()).required()
}).required();

// ---------------------------------------------------------------------------
// Section: summary
// High-level analysis narrative and risk assessment.
// ---------------------------------------------------------------------------
const RISK_LEVELS = ['low', 'medium', 'high', 'critical'];

const summarySchema = Joi.object({
  /** 2-3 sentence overview of the analysis */
  overview: Joi.string().required(),

  /** Top findings from the analysis */
  keyFindings: Joi.array().items(Joi.string()).required(),

  /** Overall risk level for this document */
  riskLevel: Joi.string().valid(...RISK_LEVELS).required(),

  /** Suggested follow-up actions */
  recommendations: Joi.array().items(Joi.string()).required()
}).required();

// ---------------------------------------------------------------------------
// Top-level analysis report schema
// ---------------------------------------------------------------------------

/**
 * Joi validation schema for analysis reports.
 *
 * This is the contract between the Claude AI analysis engine and all
 * downstream consumers (pipeline, API, frontend, cross-document analysis).
 *
 * Sections:
 *  - documentInfo:  classification metadata and confidence
 *  - extractedData: structured fields pulled from the document
 *  - anomalies:     detected issues, inconsistencies, or concerns
 *  - completeness:  field extraction coverage metrics
 *  - summary:       narrative overview and risk assessment
 */
const analysisReportSchema = Joi.object({
  documentInfo: documentInfoSchema,
  extractedData: extractedDataSchema,
  anomalies: anomaliesSchema,
  completeness: completenessSchema,
  summary: summarySchema
});

/**
 * Validate an analysis report object against the schema.
 *
 * @param {Object} data - The analysis report object to validate
 * @returns {{ value: Object, error: import('joi').ValidationError|undefined }}
 *   Validated/coerced value and any validation error
 */
function validateAnalysisReport(data) {
  return analysisReportSchema.validate(data, { abortEarly: false });
}

module.exports = {
  analysisReportSchema,
  validateAnalysisReport,
  ANOMALY_TYPES,
  SEVERITY_LEVELS,
  RISK_LEVELS
};
