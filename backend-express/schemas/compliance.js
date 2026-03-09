const Joi = require('joi');
const { getStatuteIds } = require('../config/federalStatuteTaxonomy');

/**
 * Valid statute identifiers from the federal statute taxonomy.
 * Used for statuteFilter validation in compliance evaluation requests.
 */
const VALID_STATUTE_IDS = getStatuteIds();

/**
 * Schema for POST /v1/cases/:caseId/compliance (body)
 * Validates request body for triggering a compliance evaluation.
 * userId comes from req.user.id (JWT auth), not from the body.
 * Extended with state compliance options (15-08).
 */
const evaluateComplianceSchema = Joi.object({
  skipAiAnalysis: Joi.boolean().default(false),
  statuteFilter: Joi.array()
    .items(Joi.string().valid(...VALID_STATUTE_IDS))
    .optional(),
  plaidAccessToken: Joi.string().optional(),
  state: Joi.string().uppercase().length(2).optional(),
  skipStateAnalysis: Joi.boolean().default(false),
  stateStatuteFilter: Joi.array()
    .items(Joi.string().trim())
    .optional()
});

/**
 * Schema for GET /v1/cases/:caseId/compliance (params)
 * Validates route params for retrieving a stored compliance report.
 * userId comes from req.user.id (JWT auth), not from params.
 */
const getComplianceReportSchema = Joi.object({
  caseId: Joi.string().trim().required()
});

/**
 * Schema for GET /v1/compliance/statutes/:statuteId (params)
 * Validates route params for retrieving statute details.
 */
const getStatuteDetailsSchema = Joi.object({
  statuteId: Joi.string().trim().required()
});

/**
 * Schema for GET /v1/compliance/statutes (query)
 * Validates query parameters for listing federal statutes.
 */
const listStatutesSchema = Joi.object({
  category: Joi.string().trim().optional()
});

/**
 * Schema for GET /v1/compliance/states/:stateCode/statutes (query)
 * Validates query parameters for listing state statutes.
 */
const listStateStatutesSchema = Joi.object({
  category: Joi.string().trim().optional()
});

/**
 * Schema for GET /v1/compliance/states/:stateCode/statutes/:statuteId (params)
 * Validates route params for retrieving state statute details.
 */
const getStateStatuteDetailsSchema = Joi.object({
  stateCode: Joi.string().uppercase().length(2).required(),
  statuteId: Joi.string().trim().required()
});

/**
 * Schema for GET /v1/compliance/states (query)
 * Validates query params for listing supported states.
 */
const getSupportedStatesSchema = Joi.object({}).unknown(false);

/**
 * Schema for GET /v1/compliance/states/:stateCode/statutes (params)
 * Validates the stateCode param.
 */
const stateCodeParamsSchema = Joi.object({
  stateCode: Joi.string().uppercase().length(2).required()
});

module.exports = {
  evaluateComplianceSchema,
  getComplianceReportSchema,
  getStatuteDetailsSchema,
  listStatutesSchema,
  listStateStatutesSchema,
  getStateStatuteDetailsSchema,
  getSupportedStatesSchema,
  stateCodeParamsSchema
};
