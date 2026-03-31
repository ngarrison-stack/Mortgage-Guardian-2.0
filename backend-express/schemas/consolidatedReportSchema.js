const Joi = require('joi');

// ---------------------------------------------------------------------------
// Shared enums
// ---------------------------------------------------------------------------

const SEVERITY_LEVELS = ['critical', 'high', 'medium', 'low', 'info'];

const OVERALL_RISK_LEVELS = ['critical', 'high', 'medium', 'low', 'clean'];

/**
 * Numeric priority for each risk level — lower number = higher priority.
 * Used to compare/sort risk levels programmatically.
 */
const RISK_LEVEL_PRIORITY = {
  critical: 1,
  high: 2,
  medium: 3,
  low: 4,
  clean: 5
};

/**
 * Categories of findings that can appear in a consolidated report.
 * Each maps to a specific upstream analysis source.
 */
const FINDING_CATEGORIES = [
  'documentAnomalies',
  'crossDocDiscrepancies',
  'timelineViolations',
  'paymentIssues',
  'federalViolations',
  'stateViolations'
];

const FINDING_TYPES = [
  'anomaly',
  'discrepancy',
  'timelineViolation',
  'paymentIssue',
  'federalViolation',
  'stateViolation'
];

// ---------------------------------------------------------------------------
// Section: caseSummary
// High-level metadata about the case being reported on.
// ---------------------------------------------------------------------------
const caseSummarySchema = Joi.object({
  /** Borrower's name */
  borrowerName: Joi.string().required(),

  /** Property address */
  propertyAddress: Joi.string().required(),

  /** Loan number */
  loanNumber: Joi.string().required(),

  /** Name of the mortgage servicer */
  servicerName: Joi.string().required(),

  /** Total number of documents in the case */
  documentCount: Joi.number().integer().min(0).required(),

  /** ISO-8601 timestamp of when the case was created */
  caseCreatedAt: Joi.string().isoDate().required()
}).required();

// ---------------------------------------------------------------------------
// Section: confidenceScore
// Composite confidence score with per-layer breakdown.
// ---------------------------------------------------------------------------
const confidenceBreakdownSchema = Joi.object({
  /** Confidence from individual document analysis (0-100) */
  documentAnalysis: Joi.number().min(0).max(100).required(),

  /** Confidence from cross-document forensic analysis (0-100, null when absent) */
  forensicAnalysis: Joi.number().min(0).max(100).allow(null).required(),

  /** Confidence from compliance analysis (0-100, null when absent) */
  complianceAnalysis: Joi.number().min(0).max(100).allow(null).required()
}).required();

const confidenceScoreSchema = Joi.object({
  /** Overall weighted confidence score (0-100) */
  overall: Joi.number().min(0).max(100).required(),

  /** Per-layer confidence breakdown */
  breakdown: confidenceBreakdownSchema,

  /** Classification confidence impact on scoring (present when classificationConfidence provided) */
  classificationImpact: Joi.object({
    confidenceUsed: Joi.number().min(0).max(1).required(),
    factor: Joi.number().required(),
    layerAffected: Joi.string().required()
  }).optional()
}).required();

// ---------------------------------------------------------------------------
// Section: findingSummary
// Aggregate counts of findings by severity and category.
// ---------------------------------------------------------------------------
const bySeveritySchema = Joi.object({
  critical: Joi.number().integer().min(0).required(),
  high: Joi.number().integer().min(0).required(),
  medium: Joi.number().integer().min(0).required(),
  low: Joi.number().integer().min(0).required(),
  info: Joi.number().integer().min(0).required()
}).required();

const byCategorySchema = Joi.object({
  documentAnomalies: Joi.number().integer().min(0).required(),
  crossDocDiscrepancies: Joi.number().integer().min(0).required(),
  timelineViolations: Joi.number().integer().min(0).required(),
  paymentIssues: Joi.number().integer().min(0).required(),
  federalViolations: Joi.number().integer().min(0).required(),
  stateViolations: Joi.number().integer().min(0).required()
}).required();

const findingSummarySchema = Joi.object({
  /** Total number of findings across all categories */
  totalFindings: Joi.number().integer().min(0).required(),

  /** Counts broken down by severity level */
  bySeverity: bySeveritySchema,

  /** Counts broken down by finding category */
  byCategory: byCategorySchema
}).required();

// ---------------------------------------------------------------------------
// Section: documentAnalysis
// Per-document summary from individual document analysis.
// ---------------------------------------------------------------------------
const documentAnalysisItemSchema = Joi.object({
  /** Document identifier */
  documentId: Joi.string().required(),

  /** Display name of the document */
  documentName: Joi.string().required(),

  /** Document classification type */
  type: Joi.string().required(),

  /** Document classification subtype */
  subtype: Joi.string().required(),

  /** Completeness score from extraction (0-100) */
  completenessScore: Joi.number().min(0).max(100).required(),

  /** Number of anomalies detected */
  anomalyCount: Joi.number().integer().min(0).required(),

  /** Anomaly details */
  anomalies: Joi.array().items(Joi.object({
    id: Joi.string().optional(),
    field: Joi.string().optional(),
    type: Joi.string().optional(),
    severity: Joi.string().valid('critical', 'high', 'medium', 'low', 'info').optional(),
    description: Joi.string().optional()
  })).default([]),

  /** Top findings from individual analysis */
  keyFindings: Joi.array().items(Joi.string()).default([])
});

// ---------------------------------------------------------------------------
// Section: forensicFindings
// Aggregated results from cross-document forensic analysis.
// ---------------------------------------------------------------------------
const forensicDiscrepancySchema = Joi.object({
  /** Unique discrepancy identifier */
  id: Joi.string().required(),

  /** Category of discrepancy */
  type: Joi.string().required(),

  /** Severity level */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),

  /** Human-readable description */
  description: Joi.string().max(1000).required(),

  /** Document IDs involved */
  documentIds: Joi.array().items(Joi.string()).min(1).required(),

  /** Relevant regulation citation */
  regulation: Joi.string().optional()
});

const forensicTimelineViolationSchema = Joi.object({
  /** Description of the timeline violation */
  description: Joi.string().max(1000).required(),

  /** Severity level */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),

  /** Related document IDs */
  relatedDocuments: Joi.array().items(Joi.string()).min(1).required(),

  /** Relevant regulation */
  regulation: Joi.string().optional()
});

const forensicPaymentVerificationSchema = Joi.object({
  /** Whether payment data was verified against bank records */
  verified: Joi.boolean().required(),

  /** Number of transactions analyzed */
  transactionsAnalyzed: Joi.number().integer().min(0).required(),

  /** Number of matched payments */
  matchedCount: Joi.number().integer().min(0).required(),

  /** Number of unmatched payments */
  unmatchedCount: Joi.number().integer().min(0).required(),

  /** Key findings from payment verification */
  findings: Joi.array().items(Joi.string()).default([])
}).allow(null).default(null);

const forensicFindingsSchema = Joi.object({
  /** Discrepancies found between documents */
  discrepancies: Joi.array().items(forensicDiscrepancySchema).default([]),

  /** Timeline violations detected */
  timelineViolations: Joi.array().items(forensicTimelineViolationSchema).default([]),

  /** Payment verification summary (null when no Plaid data) */
  paymentVerification: forensicPaymentVerificationSchema
}).required();

// ---------------------------------------------------------------------------
// Section: complianceFindings
// Aggregated results from federal and state compliance analysis.
// ---------------------------------------------------------------------------
const complianceViolationSchema = Joi.object({
  /** Unique violation identifier */
  id: Joi.string().required(),

  /** Statute short identifier */
  statuteId: Joi.string().required(),

  /** Section identifier */
  sectionId: Joi.string().required(),

  /** Full statute name */
  statuteName: Joi.string().required(),

  /** Section title */
  sectionTitle: Joi.string().required(),

  /** Statutory/regulatory citation */
  citation: Joi.string().required(),

  /** Violation severity */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),

  /** Human-readable description */
  description: Joi.string().max(2000).required(),

  /** Legal basis for the violation */
  legalBasis: Joi.string().max(2000).required(),

  /** Potential penalties */
  potentialPenalties: Joi.string().optional(),

  /** Recommended corrective actions */
  recommendations: Joi.array().items(Joi.string()).default([])
});

const stateComplianceViolationSchema = complianceViolationSchema.keys({
  /** 2-letter state code for the jurisdiction */
  jurisdiction: Joi.string().length(2).uppercase().required()
});

const complianceJurisdictionSchema = Joi.object({
  /** Property state */
  propertyState: Joi.string().length(2).uppercase().optional(),

  /** Servicer state */
  servicerState: Joi.string().length(2).uppercase().optional(),

  /** States whose laws apply */
  applicableStates: Joi.array().items(Joi.string().length(2).uppercase()).default([])
}).allow(null).default(null);

const complianceFindingsSchema = Joi.object({
  /** Federal statutory violations */
  federalViolations: Joi.array().items(complianceViolationSchema).default([]),

  /** State statutory violations */
  stateViolations: Joi.array().items(stateComplianceViolationSchema).default([]),

  /** Jurisdiction information */
  jurisdiction: complianceJurisdictionSchema
}).required();

// ---------------------------------------------------------------------------
// Section: evidenceLinks
// Cross-references between findings and source documents.
// ---------------------------------------------------------------------------
const evidenceLinkSchema = Joi.object({
  /** Identifier of the finding this evidence supports */
  findingId: Joi.string().required(),

  /** Type of finding */
  findingType: Joi.string().valid(...FINDING_TYPES).required(),

  /** Source document IDs providing evidence */
  sourceDocumentIds: Joi.array().items(Joi.string()).min(1).required(),

  /** Description of the evidence */
  evidenceDescription: Joi.string().required(),

  /** Severity of the linked finding */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required()
});

// ---------------------------------------------------------------------------
// Section: recommendations
// Prioritized list of recommended actions.
// ---------------------------------------------------------------------------
const recommendationSchema = Joi.object({
  /** Priority level (1 = highest, 5 = lowest) */
  priority: Joi.number().integer().min(1).max(5).required(),

  /** Category of the recommendation */
  category: Joi.string().required(),

  /** Description of the recommended action */
  action: Joi.string().required(),

  /** Legal basis for the recommendation (if applicable) */
  legalBasis: Joi.string().allow(null).default(null),

  /** IDs of related findings */
  relatedFindingIds: Joi.array().items(Joi.string()).default([])
});

// ---------------------------------------------------------------------------
// Section: disputeLetter
// Optional generated RESPA dispute letter.
// ---------------------------------------------------------------------------
const disputeLetterContentSchema = Joi.object({
  subject: Joi.string().allow('').required(),
  salutation: Joi.string().allow('').required(),
  body: Joi.string().allow('').required(),
  demands: Joi.array().items(Joi.string()).default([]),
  legalCitations: Joi.array().items(Joi.string()).default([]),
  responseDeadline: Joi.string().allow('').required(),
  closingStatement: Joi.string().allow('').required()
}).required();

const disputeLetterSchema = Joi.object({
  /** Type of dispute letter */
  letterType: Joi.string().required(),

  /** ISO-8601 timestamp of letter generation */
  generatedAt: Joi.string().isoDate().required(),

  /** Structured letter content from Claude AI */
  content: disputeLetterContentSchema,

  /** Recipient/servicer information */
  recipientInfo: Joi.object({
    servicerName: Joi.string().required(),
    servicerAddress: Joi.string().required()
  }).required()
}).allow(null).default(null);

// ---------------------------------------------------------------------------
// Section: metadata
// Optional metadata about the report generation run.
// ---------------------------------------------------------------------------
const metadataSchema = Joi.object({
  /** Duration of report generation in milliseconds */
  generationDurationMs: Joi.number().integer().min(0).optional(),

  /** Processing steps completed */
  stepsCompleted: Joi.array().items(Joi.string()).default([]),

  /** Warnings generated during report generation */
  warnings: Joi.array().items(Joi.string()).default([])
}).optional();

// ---------------------------------------------------------------------------
// Top-level consolidated report schema
// ---------------------------------------------------------------------------

/**
 * Joi validation schema for consolidated audit reports.
 *
 * This is the contract between the report aggregation engine and all
 * downstream consumers (API, frontend, PDF generation, dispute letter
 * generation). It unifies findings from three upstream sources:
 *
 *  1. Individual document analysis (analysisReportSchema)
 *  2. Cross-document forensic analysis (crossDocumentAnalysisSchema)
 *  3. Federal + state compliance analysis (complianceReportSchema)
 *
 * Sections:
 *  - reportId:              unique report identifier (UUID)
 *  - caseId:                case identifier
 *  - userId:                user who requested the report
 *  - generatedAt:           ISO-8601 timestamp of report generation
 *  - reportVersion:         schema version
 *  - caseSummary:           high-level case metadata
 *  - overallRiskLevel:      composite risk assessment
 *  - confidenceScore:       weighted confidence with per-layer breakdown
 *  - findingSummary:        aggregate finding counts
 *  - documentAnalysis:      per-document analysis summaries
 *  - forensicFindings:      cross-document forensic results
 *  - complianceFindings:    federal + state compliance results
 *  - evidenceLinks:         cross-references between findings and documents
 *  - recommendations:       prioritized recommended actions
 *  - disputeLetterAvailable: whether a dispute letter can be generated
 *  - disputeLetter:         optional generated dispute letter
 *  - _metadata:             optional generation run metadata
 */
const consolidatedReportSchema = Joi.object({
  /** Unique report identifier (UUID) */
  reportId: Joi.string().guid({ version: 'uuidv4' }).required(),

  /** Case identifier */
  caseId: Joi.string().required(),

  /** User who requested the report */
  userId: Joi.string().required(),

  /** ISO-8601 timestamp of when report was generated */
  generatedAt: Joi.string().isoDate().required(),

  /** Schema version */
  reportVersion: Joi.string().default('1.0'),

  /** High-level case metadata */
  caseSummary: caseSummarySchema,

  /** Overall risk assessment */
  overallRiskLevel: Joi.string().valid(...OVERALL_RISK_LEVELS).required(),

  /** Weighted confidence score with breakdown */
  confidenceScore: confidenceScoreSchema,

  /** Aggregate finding counts by severity and category */
  findingSummary: findingSummarySchema,

  /** Per-document analysis summaries */
  documentAnalysis: Joi.array().items(documentAnalysisItemSchema).default([]),

  /** Cross-document forensic findings */
  forensicFindings: forensicFindingsSchema,

  /** Federal + state compliance findings */
  complianceFindings: complianceFindingsSchema,

  /** Evidence cross-references */
  evidenceLinks: Joi.array().items(evidenceLinkSchema).default([]),

  /** Prioritized recommendations */
  recommendations: Joi.array().items(recommendationSchema).default([]),

  /** Whether a dispute letter is available for this report */
  disputeLetterAvailable: Joi.boolean().default(false),

  /** Generated dispute letter (null when not available) */
  disputeLetter: disputeLetterSchema,

  /** Report generation metadata */
  _metadata: metadataSchema
});

// ---------------------------------------------------------------------------
// Validation helper
// ---------------------------------------------------------------------------

/**
 * Validate a consolidated report object against the schema.
 *
 * Returns a { valid, errors, warnings } object instead of throwing.
 * Minor deviations are captured as warnings; structural problems as errors.
 *
 * @param {Object} report - The consolidated report object to validate
 * @returns {{ valid: boolean, errors: string[], warnings: string[] }}
 */
function validateConsolidatedReport(report) {
  const { error, value } = consolidatedReportSchema.validate(report, {
    abortEarly: false
  });

  const errors = error
    ? error.details.map(d => d.message)
    : [];

  return {
    valid: !error,
    value,
    errors,
    warnings: []
  };
}

module.exports = {
  consolidatedReportSchema,
  validateConsolidatedReport,
  RISK_LEVEL_PRIORITY,
  FINDING_CATEGORIES,
  FINDING_TYPES,
  OVERALL_RISK_LEVELS,
  SEVERITY_LEVELS
};
