const express = require('express');
const router = express.Router();
const documentService = require('../services/documentService');

// POST /v1/documents/upload
// Upload and store a mortgage document
router.post('/upload', async (req, res, next) => {
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

    // Validate required fields
    if (!documentId || !userId || !fileName || !content) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Missing required fields: documentId, userId, fileName, content'
      });
    }

    console.log(`Uploading document: ${fileName} for user ${userId}`);

    const result = await documentService.uploadDocument({
      documentId,
      userId,
      fileName,
      documentType: documentType || 'unknown',
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
router.get('/', async (req, res, next) => {
  try {
    const { userId, limit, offset } = req.query;

    if (!userId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'userId query parameter is required'
      });
    }

    const documents = await documentService.getDocumentsByUser({
      userId,
      limit: parseInt(limit) || 50,
      offset: parseInt(offset) || 0
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
router.get('/:documentId', async (req, res, next) => {
  try {
    const { documentId } = req.params;
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'userId query parameter is required'
      });
    }

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
router.delete('/:documentId', async (req, res, next) => {
  try {
    const { documentId } = req.params;
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'userId query parameter is required'
      });
    }

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
