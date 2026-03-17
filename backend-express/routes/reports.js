const express = require('express');
const router = express.Router();
const consolidatedReportService = require('../services/consolidatedReportService');
const disputeLetterService = require('../services/disputeLetterService');
const caseFileService = require('../services/caseFileService');
const { createLogger } = require('../utils/logger');
const logger = createLogger('report-routes');
const { validate } = require('../middleware/validate');
const {
  generateReportSchema,
  getReportSchema,
  generateLetterSchema
} = require('../schemas/reports');

// ============================================
// CONSOLIDATED REPORT ENDPOINTS
// Mounted at /v1/cases/:caseId/report
// ============================================

// POST /v1/cases/:caseId/report
// Generate consolidated report for a case
router.post('/cases/:caseId/report', validate(generateReportSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;
    const { generateLetter, letterType, skipPersistence } = req.body;

    logger.info('Generating consolidated report', { caseId, userId, generateLetter, letterType });

    const options = {};
    if (generateLetter != null) options.generateLetter = generateLetter;
    if (letterType) options.letterType = letterType;
    if (skipPersistence != null) options.skipPersistence = skipPersistence;

    const result = await consolidatedReportService.generateReport(caseId, userId, options);

    if (result.error) {
      logger.warn('Report generation returned error', { caseId, error: result.errorMessage });
      return res.status(422).json({
        error: 'ReportError',
        message: result.errorMessage || 'Report generation failed'
      });
    }

    logger.info('Consolidated report generated', { caseId, reportId: result.reportId });

    res.status(200).json({
      status: 'success',
      report: result
    });

  } catch (error) {
    logger.error('Report generation error', { error: error.message });
    next(error);
  }
});

// GET /v1/cases/:caseId/report
// Retrieve latest consolidated report for a case
router.get('/cases/:caseId/report', validate(getReportSchema, 'params'), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;

    logger.info('Retrieving consolidated report', { caseId, userId });

    const caseData = await caseFileService.getCase({ caseId, userId });

    if (!caseData) {
      return res.status(404).json({
        error: 'NotFound',
        message: 'Case not found'
      });
    }

    const report = caseData.consolidated_report || caseData.consolidatedReport || null;

    if (!report) {
      return res.status(404).json({
        error: 'NotFound',
        message: 'No consolidated report found for this case'
      });
    }

    logger.info('Consolidated report retrieved', { caseId });

    res.status(200).json({
      status: 'success',
      report
    });

  } catch (error) {
    logger.error('Retrieve consolidated report error', { error: error.message });
    next(error);
  }
});

// POST /v1/cases/:caseId/report/letter
// Generate dispute letter for an existing consolidated report
router.post('/cases/:caseId/report/letter', validate(generateLetterSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;
    const { letterType } = req.body;

    logger.info('Generating dispute letter', { caseId, userId, letterType });

    // Retrieve existing consolidated report
    const caseData = await caseFileService.getCase({ caseId, userId });

    if (!caseData) {
      return res.status(404).json({
        error: 'NotFound',
        message: 'Case not found'
      });
    }

    const report = caseData.consolidated_report || caseData.consolidatedReport || null;

    if (!report) {
      return res.status(404).json({
        error: 'NotFound',
        message: 'No consolidated report found. Generate a report first.'
      });
    }

    const letter = await disputeLetterService.generateDisputeLetter(letterType, report);

    if (letter.error) {
      logger.warn('Letter generation returned error', { caseId, error: letter.errorMessage });
      return res.status(422).json({
        error: 'LetterError',
        message: letter.errorMessage || 'Dispute letter generation failed'
      });
    }

    logger.info('Dispute letter generated', { caseId, letterType });

    res.status(200).json({
      status: 'success',
      letter
    });

  } catch (error) {
    logger.error('Letter generation error', { error: error.message });
    next(error);
  }
});

module.exports = router;
