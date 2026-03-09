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
 */
const evaluateComplianceSchema = Joi.object({
  skipAiAnalysis: Joi.boolean().default(false),
  statuteFilter: Joi.array()
    .items(Joi.string().valid(...VALID_STATUTE_IDS))
    .optional(),
  plaidAccessToken: Joi.string().optional()
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

module.exports = {
  evaluateComplianceSchema,
  getComplianceReportSchema,
  getStatuteDetailsSchema,
  listStatutesSchema
};
