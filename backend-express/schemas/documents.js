const Joi = require('joi');

/**
 * Schema for POST /v1/documents/upload
 * Validates document upload request body.
 */
const uploadDocumentSchema = Joi.object({
  documentId: Joi.string().trim().required(),
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
  limit: Joi.number().integer().min(1).max(500).default(50),
  offset: Joi.number().integer().min(0).default(0)
});

/**
 * Schema for GET /v1/documents/:documentId
 * Validates query parameters for retrieving a specific document.
 */
const getDocumentSchema = Joi.object({});

/**
 * Schema for DELETE /v1/documents/:documentId
 * Validates query parameters for deleting a document.
 */
const deleteDocumentSchema = Joi.object({});

/**
 * Schema for POST /v1/documents/process
 * Triggers the full processing pipeline for an uploaded document.
 *
 * documentText is optional — server-side OCR handles text extraction
 * when fileBuffer is provided instead.
 */
const processDocumentSchema = Joi.object({
  documentId: Joi.string().trim().required(),
  documentText: Joi.string().optional(),
  fileBuffer: Joi.string().optional(),   // base64-encoded file content
  documentType: Joi.string().trim().valid(
    // Broad taxonomy categories
    'origination', 'servicing', 'correspondence', 'legal', 'financial', 'regulatory',
    // Legacy types for backward compatibility
    'mortgage_statement', 'escrow_statement', 'payment_history',
    'bank_statement', 'tax_document', 'legal_document',
    'unknown'
  ).default('unknown')
}).or('documentText', 'fileBuffer');  // At least one must be provided

/**
 * Schema for POST /v1/documents/:documentId/retry
 * Retries a failed pipeline from the last successful step.
 */
const retryDocumentSchema = Joi.object({
  documentText: Joi.string(),
  fileBuffer: Joi.string()   // base64-encoded file content
});

/**
 * Schema for POST /v1/documents/:documentId/complete
 * Marks a document as complete after user review.
 */
const completeDocumentSchema = Joi.object({});

/**
 * Schema for GET /v1/documents/pipeline
 * Lists documents in the processing pipeline for a user.
 */
const getPipelineSchema = Joi.object({
  status: Joi.string().trim().valid(
    'uploaded', 'ocr', 'classifying', 'analyzing', 'analyzed',
    'review', 'complete', 'failed'
  )
});

/**
 * Schema for GET /v1/documents/:documentId/analysis
 * Validates route params for retrieving a document's analysis report.
 */
const analysisParamsSchema = Joi.object({
  documentId: Joi.string().required().trim()
});

module.exports = {
  uploadDocumentSchema,
  getDocumentsSchema,
  getDocumentSchema,
  deleteDocumentSchema,
  processDocumentSchema,
  retryDocumentSchema,
  completeDocumentSchema,
  getPipelineSchema,
  analysisParamsSchema
};
