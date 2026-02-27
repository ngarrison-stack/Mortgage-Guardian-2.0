const express = require('express');
const router = express.Router();
const caseFileService = require('../services/caseFileService');
const { createLogger } = require('../utils/logger');
const logger = createLogger('case-routes');
const { validate } = require('../middleware/validate');
const {
  createCaseSchema,
  getCasesSchema,
  getCaseSchema,
  updateCaseSchema,
  addDocumentToCaseSchema,
  removeDocumentFromCaseSchema
} = require('../schemas/cases');

// POST /v1/cases
// Create a new case file
router.post('/', validate(createCaseSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseName, borrowerName, propertyAddress, loanNumber, servicerName, notes } = req.body;

    logger.info('Creating case', { userId, caseName });

    const result = await caseFileService.createCase({
      userId,
      caseName,
      borrowerName,
      propertyAddress,
      loanNumber,
      servicerName,
      notes
    });

    res.status(201).json(result);

  } catch (error) {
    logger.error('Create case error', { error: error.message });
    next(error);
  }
});

// GET /v1/cases
// List user's cases with optional status filter
router.get('/', validate(getCasesSchema, 'query'), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { status, limit, offset } = req.query;

    const cases = await caseFileService.getCasesByUser({
      userId,
      status,
      limit,
      offset
    });

    res.json({
      cases,
      total: cases.length,
      userId
    });

  } catch (error) {
    logger.error('List cases error', { error: error.message });
    next(error);
  }
});

// GET /v1/cases/:caseId
// Get a single case with its documents
router.get('/:caseId', validate(getCaseSchema, 'query'), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;

    const caseData = await caseFileService.getCase({ caseId, userId });

    if (!caseData) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Case not found'
      });
    }

    res.json(caseData);

  } catch (error) {
    logger.error('Get case error', { error: error.message });
    next(error);
  }
});

// PUT /v1/cases/:caseId
// Update case fields
router.put('/:caseId', validate(updateCaseSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;
    const updates = req.body;

    const result = await caseFileService.updateCase({ caseId, userId, updates });

    if (!result) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Case not found'
      });
    }

    res.json(result);

  } catch (error) {
    logger.error('Update case error', { error: error.message });
    next(error);
  }
});

// DELETE /v1/cases/:caseId
// Delete a case
router.delete('/:caseId', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;

    const result = await caseFileService.deleteCase({ caseId, userId });

    res.json(result);

  } catch (error) {
    logger.error('Delete case error', { error: error.message });
    next(error);
  }
});

// POST /v1/cases/:caseId/documents
// Add a document to a case
router.post('/:caseId/documents', validate(addDocumentToCaseSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;
    const { documentId } = req.body;

    const result = await caseFileService.addDocumentToCase({ caseId, documentId, userId });

    res.json(result);

  } catch (error) {
    logger.error('Add document to case error', { error: error.message });
    next(error);
  }
});

// DELETE /v1/cases/:caseId/documents/:documentId
// Remove a document from a case
router.delete('/:caseId/documents/:documentId', validate(removeDocumentFromCaseSchema, 'query'), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { documentId } = req.params;

    const result = await caseFileService.removeDocumentFromCase({ documentId, userId });

    res.json(result);

  } catch (error) {
    logger.error('Remove document from case error', { error: error.message });
    next(error);
  }
});

module.exports = router;
