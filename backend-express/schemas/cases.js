const Joi = require('joi');

/**
 * Valid case statuses matching the CHECK constraint in migration 002.
 */
const VALID_STATUSES = ['open', 'in_review', 'complete', 'archived'];

/**
 * Schema for POST /v1/cases
 * Validates request body for creating a new case file.
 * userId comes from req.user.id (JWT auth), not from the body.
 */
const createCaseSchema = Joi.object({
  caseName: Joi.string().trim().min(1).max(200).required(),
  borrowerName: Joi.string().trim().max(200).optional(),
  propertyAddress: Joi.string().trim().max(500).optional(),
  loanNumber: Joi.string().trim().max(100).optional(),
  servicerName: Joi.string().trim().max(200).optional(),
  notes: Joi.string().trim().max(5000).optional()
});

/**
 * Schema for GET /v1/cases
 * Validates query parameters for listing user cases.
 * userId comes from req.user.id (JWT auth), not from query.
 */
const getCasesSchema = Joi.object({
  status: Joi.string().trim().valid(...VALID_STATUSES).optional(),
  limit: Joi.number().integer().min(1).max(500).default(50),
  offset: Joi.number().integer().min(0).default(0)
});

/**
 * Schema for GET /v1/cases/:caseId
 * No additional params needed — caseId from URL, userId from auth.
 */
const getCaseSchema = Joi.object({});

/**
 * Schema for PUT /v1/cases/:caseId
 * Validates request body for updating a case file.
 * At least one field must be provided.
 */
const updateCaseSchema = Joi.object({
  caseName: Joi.string().trim().min(1).max(200).optional(),
  borrowerName: Joi.string().trim().max(200).optional(),
  propertyAddress: Joi.string().trim().max(500).optional(),
  loanNumber: Joi.string().trim().max(100).optional(),
  servicerName: Joi.string().trim().max(200).optional(),
  status: Joi.string().trim().valid(...VALID_STATUSES).optional(),
  notes: Joi.string().trim().max(5000).optional()
}).min(1);

/**
 * Schema for POST /v1/cases/:caseId/documents
 * Validates request body for adding a document to a case.
 */
const addDocumentToCaseSchema = Joi.object({
  documentId: Joi.string().trim().required()
});

/**
 * Schema for DELETE /v1/cases/:caseId/documents/:documentId
 * No body needed — documentId from URL param, userId from auth.
 */
const removeDocumentFromCaseSchema = Joi.object({});

module.exports = {
  createCaseSchema,
  getCasesSchema,
  getCaseSchema,
  updateCaseSchema,
  addDocumentToCaseSchema,
  removeDocumentFromCaseSchema
};
