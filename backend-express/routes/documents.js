const express = require('express');
const router = express.Router();
const documentService = require('../services/documentService');
const { validate } = require('../middleware/validate');
const {
  uploadDocumentSchema,
  getDocumentsSchema,
  getDocumentSchema,
  deleteDocumentSchema
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

    console.log(`Uploading document: ${fileName} for user ${userId}`);

    const result = await documentService.uploadDocument({
      documentId,
      userId,
      fileName,
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
    console.error('Document upload error:', error);
    next(error);
  }
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
    console.error('Get documents error:', error);
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
    console.error('Get document error:', error);
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
    console.error('Delete document error:', error);
    next(error);
  }
});

module.exports = router;
