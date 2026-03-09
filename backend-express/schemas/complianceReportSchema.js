const Joi = require('joi');

// ---------------------------------------------------------------------------
// Shared enums
// ---------------------------------------------------------------------------

const SEVERITY_LEVELS = ['critical', 'high', 'medium', 'low', 'info'];

const RISK_LEVELS = ['low', 'medium', 'high', 'critical'];

const EVIDENCE_SOURCE_TYPES = [
  'discrepancy',
  'anomaly',
  'timeline_violation',
  'payment_issue'
];

// ---------------------------------------------------------------------------
// Section: evidence
// Each piece of evidence links a violation to a specific forensic finding.
// ---------------------------------------------------------------------------
const evidenceSchema = Joi.object({
  /** Source type of the evidence */
  sourceType: Joi.string().valid(...EVIDENCE_SOURCE_TYPES).required(),

  /** Identifier of the source finding (e.g. "disc-001", "anom-003") */
  sourceId: Joi.string().required(),

  /** Human-readable description of the evidence */
  description: Joi.string().required()
});

// ---------------------------------------------------------------------------
// Shared: US state codes (2-letter)
// ---------------------------------------------------------------------------
const US_STATE_CODES = [
  'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
  'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
  'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
  'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
  'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
  'DC'
];

const JURISDICTION_DETERMINATION_METHODS = [
  'property_location',
  'servicer_location',
  'case_metadata',
  'manual',
  'default'
];

// ---------------------------------------------------------------------------
// Section: jurisdiction
// Tracks which state laws apply to a compliance analysis.
// ---------------------------------------------------------------------------
const jurisdictionSchema = Joi.object({
  /** 2-letter state code where the property is located */
  propertyState: Joi.string().valid(...US_STATE_CODES).optional(),

  /** 2-letter state code where the servicer is located */
  servicerState: Joi.string().valid(...US_STATE_CODES).optional(),

  /** Which states' laws apply to this case */
  applicableStates: Joi.array().items(
    Joi.string().valid(...US_STATE_CODES)
  ).default([]),

  /** How the applicable states were determined */
  determinationMethod: Joi.string()
    .valid(...JURISDICTION_DETERMINATION_METHODS)
    .default('default')
});

// ---------------------------------------------------------------------------
// Section: violation
// A single statutory violation detected during compliance analysis.
// ---------------------------------------------------------------------------
const violationSchema = Joi.object({
  /** Unique violation identifier within the report (e.g. "viol-001") */
  id: Joi.string().required(),

  /** Statute short identifier (e.g. "respa", "tila") */
  statuteId: Joi.string().required(),

  /** Section identifier (e.g. "respa_s6", "tila_disclosure") */
  sectionId: Joi.string().required(),

  /** Full statute name */
  statuteName: Joi.string().required(),

  /** Section title */
  sectionTitle: Joi.string().required(),

  /** Statutory/regulatory citation (e.g. "12 U.S.C. § 2607; 12 CFR § 1024.14") */
  citation: Joi.string().required(),

  /** Violation severity */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),

  /** Human-readable description of the violation */
  description: Joi.string().max(2000).required(),

  /** Supporting evidence from forensic findings */
  evidence: Joi.array().items(evidenceSchema).min(1).required(),

  /** Legal basis explaining why this constitutes a violation */
  legalBasis: Joi.string().max(2000).required(),

  /** Description of potential penalties */
  potentialPenalties: Joi.string().optional(),

  /** Recommended actions to address this violation */
  recommendations: Joi.array().items(Joi.string()).default([])
});

// ---------------------------------------------------------------------------
// Section: state violation
// A statutory violation under state lending law — same as violationSchema but
// with an additional jurisdiction field identifying which state's law applies.
// ---------------------------------------------------------------------------
const stateViolationSchema = Joi.object({
  /** Unique violation identifier within the report (e.g. "sviol-001") */
  id: Joi.string().required(),

  /** Statute short identifier (e.g. "ca_hbor", "ny_rpapl") */
  statuteId: Joi.string().required(),

  /** Section identifier (e.g. "ca_hbor_s2923_6") */
  sectionId: Joi.string().required(),

  /** Full statute name */
  statuteName: Joi.string().required(),

  /** Section title */
  sectionTitle: Joi.string().required(),

  /** Statutory/regulatory citation */
  citation: Joi.string().required(),

  /** 2-letter state code for the jurisdiction */
  jurisdiction: Joi.string().valid(...US_STATE_CODES).required(),

  /** Violation severity */
  severity: Joi.string().valid(...SEVERITY_LEVELS).required(),

  /** Human-readable description of the violation */
  description: Joi.string().max(2000).required(),

  /** Supporting evidence from forensic findings */
  evidence: Joi.array().items(evidenceSchema).min(1).required(),

  /** Legal basis explaining why this constitutes a violation */
  legalBasis: Joi.string().max(2000).required(),

  /** Description of potential penalties */
  potentialPenalties: Joi.string().optional(),

  /** Recommended actions to address this violation */
  recommendations: Joi.array().items(Joi.string()).default([])
});

// ---------------------------------------------------------------------------
// Section: stateStatuteEvaluated
// Tracks which state statutes were checked during analysis.
// ---------------------------------------------------------------------------
const stateStatuteEvaluatedSchema = Joi.object({
  /** Statute short identifier */
  statuteId: Joi.string().required(),

  /** Full statute name */
  statuteName: Joi.string().required(),

  /** 2-letter state code */
  state: Joi.string().valid(...US_STATE_CODES).required(),

  /** Number of sections evaluated within this statute */
  sectionCount: Joi.number().integer().min(0).required()
});

// ---------------------------------------------------------------------------
// Section: complianceSummary
// High-level overview of compliance analysis findings.
// ---------------------------------------------------------------------------
const complianceSummarySchema = Joi.object({
  /** Total number of violations found */
  totalViolations: Joi.number().integer().min(0).required(),

  /** Number of critical-severity violations */
  criticalViolations: Joi.number().integer().min(0).required(),

  /** Number of high-severity violations */
  highViolations: Joi.number().integer().min(0).required(),

  /** Statute ids that had violations */
  statutesViolated: Joi.array().items(Joi.string()).required(),

  /** Overall compliance risk level for this case */
  overallComplianceRisk: Joi.string().valid(...RISK_LEVELS).required(),

  /** Top findings from the analysis */
  keyFindings: Joi.array().items(Joi.string()).max(20).default([]),

  /** Suggested follow-up actions */
  recommendations: Joi.array().items(Joi.string()).max(20).default([])
}).required();

// ---------------------------------------------------------------------------
// Section: _metadata
// Optional metadata about the analysis run.
// ---------------------------------------------------------------------------
const metadataSchema = Joi.object({
  /** Duration of the analysis in milliseconds */
  durationMs: Joi.number().integer().min(0).optional(),

  /** Warnings generated during analysis */
  warnings: Joi.array().items(Joi.string()).default([]),

  /** Processing steps completed */
  steps: Joi.array().items(Joi.string()).default([])
}).optional();

// ---------------------------------------------------------------------------
// Top-level compliance report schema
// ---------------------------------------------------------------------------

/**
 * Joi validation schema for compliance reports.
 *
 * This is the contract between the federal lending law compliance engine and
 * all downstream consumers (API, frontend, reporting, dispute letter generation).
 *
 * Sections:
 *  - caseId:             case identifier
 *  - analyzedAt:         ISO-8601 timestamp of analysis
 *  - statutesEvaluated:  which statutes were checked
 *  - violations:         detected statutory violations with evidence
 *  - complianceSummary:  high-level findings and risk assessment
 *  - legalNarrative:     Claude-generated legal analysis text
 *  - _metadata:          optional analysis run metadata
 */
const complianceReportSchema = Joi.object({
  /** Case identifier */
  caseId: Joi.string().required(),

  /** ISO-8601 timestamp of when analysis was performed */
  analyzedAt: Joi.string().isoDate().required(),

  /** Statute ids that were evaluated in this analysis */
  statutesEvaluated: Joi.array().items(Joi.string()).min(1).required(),

  /** Statutory violations detected (federal) */
  violations: Joi.array().items(violationSchema).default([]),

  /** Jurisdiction information — optional, absent for federal-only reports */
  jurisdiction: jurisdictionSchema.optional(),

  /** State statutory violations detected — optional, absent for federal-only reports */
  stateViolations: Joi.array().items(stateViolationSchema).default([]),

  /** State statutes that were evaluated — optional, absent for federal-only reports */
  stateStatutesEvaluated: Joi.array().items(stateStatuteEvaluatedSchema).default([]),

  /** High-level compliance summary */
  complianceSummary: complianceSummarySchema,

  /** Claude-generated legal analysis narrative */
  legalNarrative: Joi.string().optional(),

  /** Analysis run metadata */
  _metadata: metadataSchema
});

/**
 * Validate a compliance report object against the schema.
 *
 * @param {Object} data - The compliance report object to validate
 * @returns {{ value: Object, error: import('joi').ValidationError|undefined }}
 *   Validated/coerced value and any validation error
 */
function validateComplianceReport(data) {
  return complianceReportSchema.validate(data, { abortEarly: false });
}

module.exports = {
  complianceReportSchema,
  validateComplianceReport,
  jurisdictionSchema,
  stateViolationSchema,
  stateStatuteEvaluatedSchema,
  EVIDENCE_SOURCE_TYPES,
  SEVERITY_LEVELS,
  RISK_LEVELS,
  US_STATE_CODES,
  JURISDICTION_DETERMINATION_METHODS
};
