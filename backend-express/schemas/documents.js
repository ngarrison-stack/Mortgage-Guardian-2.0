const Joi = require('joi');

/**
 * Schema for POST /v1/documents/upload
 * Validates document upload request body.
 */
const uploadDocumentSchema = Joi.object({
  documentId: Joi.string().trim().required(),
  userId: Joi.string().trim().required(),
  fileName: Joi.string().trim().max(255).pattern(/^[a-zA-Z0-9._\s()-]+$/, 'safe characters').required(),
  content: Joi.string().max(28000000).required(),
  documentType: Joi.string().trim().valid('mortgage_statement', 'bank_statement', 'tax_document', 'correspondence', 'legal_document', 'unknown').default('unknown'),
  analysisResults: Joi.object(),
  metadata: Joi.object()
});

/**
 * Schema for GET /v1/documents
 * Validates query parameters for listing user documents.
 */
const getDocumentsSchema = Joi.object({
  userId: Joi.string().trim().required(),
  limit: Joi.number().integer().min(1).max(500).default(50),
  offset: Joi.number().integer().min(0).default(0)
});

/**
 * Schema for GET /v1/documents/:documentId
 * Validates query parameters for retrieving a specific document.
 */
const getDocumentSchema = Joi.object({
  userId: Joi.string().trim().required()
});

/**
 * Schema for DELETE /v1/documents/:documentId
 * Validates query parameters for deleting a document.
 */
const deleteDocumentSchema = Joi.object({
  userId: Joi.string().trim().required()
});

module.exports = {
  uploadDocumentSchema,
  getDocumentsSchema,
  getDocumentSchema,
  deleteDocumentSchema
};
