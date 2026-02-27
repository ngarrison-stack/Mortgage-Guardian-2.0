const express = require('express');
const router = express.Router();
const documentService = require('../services/documentService');
const documentPipeline = require('../services/documentPipelineService');
const { createLogger } = require('../utils/logger');
const logger = createLogger('document-routes');
const { validate } = require('../middleware/validate');
const { validateFileContent, sanitizeFileName } = require('../utils/fileValidation');
const {
  uploadDocumentSchema,
  getDocumentsSchema,
  getDocumentSchema,
  deleteDocumentSchema,
  processDocumentSchema,
  retryDocumentSchema,
  completeDocumentSchema,
  getPipelineSchema
} = require('../schemas/documents');

// POST /v1/documents/upload
// Upload and store a mortgage document
router.post('/upload', validate(uploadDocumentSchema), async (req, res, next) => {
  try {
    const {
      documentId,
      userId,
      fileName,
      documentType,
      content,
      analysisResults,
      metadata
    } = req.body;

    // Decode base64 content and validate file
    const fileBuffer = Buffer.from(content, 'base64');
    const validationResult = await validateFileContent(fileBuffer, fileName);
    if (!validationResult.valid) {
      return res.status(400).json({
        error: 'Validation Error',
        message: validationResult.error
      });
    }

    // Sanitize the file name before any further use
    const safeFileName = sanitizeFileName(fileName);

    logger.info('Uploading document', { fileName: safeFileName, userId });

    const result = await documentService.uploadDocument({
      documentId,
      userId,
      fileName: safeFileName,
      documentType,
      content,
      analysisResults,
      metadata
    });

    res.status(201).json({
      success: true,
      documentId: result.documentId,
      storagePath: result.storagePath,
      message: 'Document uploaded successfully'
    });

  } catch (error) {
    logger.error('Document upload error', { error: error.message });
    next(error);
  }
});

// GET /v1/documents/pipeline
// List all documents in the pipeline for a user, optionally filtered by status
// NOTE: Must be defined before /:documentId to avoid "pipeline" matching as a param
router.get('/pipeline', validate(getPipelineSchema, 'query'), async (req, res) => {
  const { userId, status } = req.query;
  const documents = documentPipeline.getUserPipeline(userId, { status });

  res.json({
    documents,
    total: documents.length,
    userId
  });
});

// GET /v1/documents
// Get all documents for a user
router.get('/', validate(getDocumentsSchema, 'query'), async (req, res, next) => {
  try {
    const { userId, limit, offset } = req.query;

    const documents = await documentService.getDocumentsByUser({
      userId,
      limit,
      offset
    });

    res.json({
      documents,
      total: documents.length,
      userId
    });

  } catch (error) {
    logger.error('Get documents error', { error: error.message });
    next(error);
  }
});

// GET /v1/documents/:documentId
// Get a specific document
router.get('/:documentId', validate(getDocumentSchema, 'query'), async (req, res, next) => {
  try {
    const { documentId } = req.params;
    const { userId } = req.query;

    const document = await documentService.getDocument({
      documentId,
      userId
    });

    if (!document) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Document not found'
      });
    }

    res.json(document);

  } catch (error) {
    logger.error('Get document error', { error: error.message });
    next(error);
  }
});

// DELETE /v1/documents/:documentId
// Delete a document
router.delete('/:documentId', validate(deleteDocumentSchema, 'query'), async (req, res, next) => {
  try {
    const { documentId } = req.params;
    const { userId } = req.query;

    await documentService.deleteDocument({
      documentId,
      userId
    });

    res.json({
      success: true,
      message: 'Document deleted successfully'
    });

  } catch (error) {
    logger.error('Delete document error', { error: error.message });
    next(error);
  }
});

// ============================================
// PROCESSING PIPELINE ENDPOINTS
// ============================================

// POST /v1/documents/process
// Triggers the full processing pipeline: OCR → classify → analyze → review
router.post('/process', validate(processDocumentSchema), async (req, res, next) => {
  try {
    const { documentId, userId, documentText, fileBuffer, documentType } = req.body;

    logger.info('Starting document pipeline', { documentId, userId, documentType });

    // Run the pipeline (async — returns when all steps complete or one fails)
    const result = await documentPipeline.processDocument(documentId, userId, {
      documentText,
      fileBuffer,
      documentType
    });

    const statusCode = result.success ? 200 : 422;
    res.status(statusCode).json(result);

  } catch (error) {
    logger.error('Pipeline error', { error: error.message });
    next(error);
  }
});

// GET /v1/documents/:documentId/status
// Check where a document is in the processing pipeline
router.get('/:documentId/status', async (req, res) => {
  const { documentId } = req.params;
  const status = await documentPipeline.getStatus(documentId);

  if (!status) {
    return res.status(404).json({
      error: 'Not Found',
      message: 'No pipeline record found for this document'
    });
  }

  res.json(status);
});

// POST /v1/documents/:documentId/retry
// Retry a failed pipeline from the last successful step
router.post('/:documentId/retry', validate(retryDocumentSchema), async (req, res, next) => {
  try {
    const { documentId } = req.params;
    const { userId, documentText } = req.body;

    logger.info('Retrying document pipeline', { documentId, userId });

    const result = await documentPipeline.retryDocument(documentId, userId, { documentText });

    const statusCode = result.success ? 200 : 422;
    res.status(statusCode).json(result);

  } catch (error) {
    logger.error('Pipeline retry error', { error: error.message });

    if (error.message.includes('not in failed state') || error.message.includes('No pipeline found')) {
      return res.status(400).json({
        error: 'Bad Request',
        message: error.message
      });
    }

    next(error);
  }
});

// POST /v1/documents/:documentId/complete
// Mark document as complete after user review
router.post('/:documentId/complete', validate(completeDocumentSchema), async (req, res, next) => {
  try {
    const { documentId } = req.params;
    const { userId } = req.body;

    const result = documentPipeline.completeDocument(documentId, userId);
    res.json(result);

  } catch (error) {
    logger.error('Pipeline complete error', { error: error.message });

    if (error.message.includes('must be in review state') || error.message.includes('No pipeline found')) {
      return res.status(400).json({
        error: 'Bad Request',
        message: error.message
      });
    }

    next(error);
  }
});

module.exports = router;
