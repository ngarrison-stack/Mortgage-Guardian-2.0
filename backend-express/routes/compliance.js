const express = require('express');
const router = express.Router();
const complianceService = require('../services/complianceService');
const caseFileService = require('../services/caseFileService');
const { FEDERAL_STATUTES, getStatuteById } = require('../config/federalStatuteTaxonomy');
const {
  STATE_STATUTES,
  getSupportedStates,
  getStateStatuteById
} = require('../config/stateStatuteTaxonomy');
const { createLogger } = require('../utils/logger');
const logger = createLogger('compliance-routes');
const { validate } = require('../middleware/validate');
const {
  evaluateComplianceSchema,
  getComplianceReportSchema,
  getStatuteDetailsSchema,
  listStatutesSchema,
  getSupportedStatesSchema,
  stateCodeParamsSchema,
  getStateStatuteDetailsSchema
} = require('../schemas/compliance');

// ============================================
// STATUTE REFERENCE ENDPOINTS
// These are mounted at /v1/compliance/...
// ============================================

// GET /v1/compliance/statutes
// List all federal statutes in the taxonomy
router.get('/compliance/statutes', validate(listStatutesSchema, 'query'), async (req, res, next) => {
  try {
    const { category } = req.query;

    let statutes = Object.values(FEDERAL_STATUTES).map(s => ({
      id: s.id,
      name: s.name,
      citation: s.citation,
      regulatoryBody: s.regulatoryBody,
      sectionCount: s.sections.length
    }));

    // Filter by regulatory body if category is provided
    if (category) {
      statutes = statutes.filter(s =>
        s.regulatoryBody.toLowerCase().includes(category.toLowerCase())
      );
    }

    res.status(200).json({ statutes });
  } catch (error) {
    logger.error('List statutes error', { error: error.message });
    next(error);
  }
});

// GET /v1/compliance/statutes/:statuteId
// Get detailed information about a specific federal statute
router.get('/compliance/statutes/:statuteId', validate(getStatuteDetailsSchema, 'params'), async (req, res, next) => {
  try {
    const { statuteId } = req.params;
    const statute = getStatuteById(statuteId);

    if (!statute) {
      return res.status(404).json({
        error: 'NotFound',
        message: `Statute '${statuteId}' not found`
      });
    }

    res.status(200).json(statute);
  } catch (error) {
    logger.error('Get statute details error', { error: error.message });
    next(error);
  }
});

// ============================================
// STATE STATUTE REFERENCE ENDPOINTS
// These are mounted at /v1/compliance/states/...
// ============================================

// GET /v1/compliance/states
// List all supported states with statute counts
router.get('/compliance/states', validate(getSupportedStatesSchema, 'query'), async (req, res, next) => {
  try {
    const stateCodes = getSupportedStates();

    const states = stateCodes.map(code => {
      const entry = STATE_STATUTES[code];
      const statutes = Object.values(entry.statutes);
      const sectionCount = statutes.reduce((sum, s) => sum + s.sections.length, 0);
      return {
        stateCode: entry.stateCode,
        stateName: entry.stateName,
        statuteCount: statutes.length,
        sectionCount
      };
    });

    res.status(200).json({ states });
  } catch (error) {
    logger.error('List supported states error', { error: error.message });
    next(error);
  }
});

// GET /v1/compliance/states/:stateCode/statutes
// List statutes for a specific state
router.get('/compliance/states/:stateCode/statutes', validate(stateCodeParamsSchema, 'params'), async (req, res, next) => {
  try {
    const { stateCode } = req.params;
    const entry = STATE_STATUTES[stateCode.toUpperCase()];

    if (!entry) {
      return res.status(404).json({
        error: 'NotFound',
        message: `State '${stateCode}' is not supported`
      });
    }

    const statutes = Object.values(entry.statutes).map(s => ({
      id: s.id,
      name: s.name,
      citation: s.citation,
      enforcementBody: s.enforcementBody,
      sectionCount: s.sections.length
    }));

    res.status(200).json({
      stateCode: entry.stateCode,
      stateName: entry.stateName,
      statutes
    });
  } catch (error) {
    logger.error('List state statutes error', { error: error.message });
    next(error);
  }
});

// GET /v1/compliance/states/:stateCode/statutes/:statuteId
// Get detailed state statute with sections, requirements, violation patterns, penalties
router.get('/compliance/states/:stateCode/statutes/:statuteId', validate(getStateStatuteDetailsSchema, 'params'), async (req, res, next) => {
  try {
    const { stateCode, statuteId } = req.params;
    const entry = STATE_STATUTES[stateCode.toUpperCase()];

    if (!entry) {
      return res.status(404).json({
        error: 'NotFound',
        message: `State '${stateCode}' is not supported`
      });
    }

    const statute = getStateStatuteById(stateCode.toUpperCase(), statuteId);

    if (!statute) {
      return res.status(404).json({
        error: 'NotFound',
        message: `Statute '${statuteId}' not found in state '${stateCode}'`
      });
    }

    res.status(200).json(statute);
  } catch (error) {
    logger.error('Get state statute details error', { error: error.message });
    next(error);
  }
});

// ============================================
// CASE COMPLIANCE ENDPOINTS
// These are mounted at /v1/cases/:caseId/compliance
// but registered via the compliance router
// ============================================

// POST /v1/cases/:caseId/compliance
// Run compliance evaluation for a case
router.post('/cases/:caseId/compliance', validate(evaluateComplianceSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;
    const { skipAiAnalysis, statuteFilter, plaidAccessToken, state, skipStateAnalysis, stateStatuteFilter } = req.body;

    logger.info('Running compliance evaluation', { caseId, userId, skipAiAnalysis, state });

    const options = {};
    if (skipAiAnalysis != null) options.skipAiAnalysis = skipAiAnalysis;
    if (statuteFilter) options.statuteFilter = statuteFilter;
    if (plaidAccessToken) options.plaidAccessToken = plaidAccessToken;
    if (state) options.state = state;
    if (skipStateAnalysis != null) options.skipStateAnalysis = skipStateAnalysis;
    if (stateStatuteFilter) options.stateStatuteFilter = stateStatuteFilter;

    const result = await complianceService.evaluateCompliance(caseId, userId, options);

    if (result.error) {
      logger.warn('Compliance evaluation returned error', { caseId, error: result.errorMessage });
      return res.status(200).json({
        caseId,
        status: 'error',
        message: result.errorMessage
      });
    }

    logger.info('Compliance evaluation completed', {
      caseId,
      violations: result.violations ? result.violations.length : 0
    });

    res.status(200).json({
      caseId,
      status: 'completed',
      complianceReport: result
    });

  } catch (error) {
    logger.error('Compliance evaluation error', { error: error.message });
    next(error);
  }
});

// GET /v1/cases/:caseId/compliance
// Retrieve stored compliance report for a case
router.get('/cases/:caseId/compliance', validate(getComplianceReportSchema, 'params'), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { caseId } = req.params;

    logger.info('Retrieving compliance report', { caseId, userId });

    const caseData = await caseFileService.getCase({ caseId, userId });

    if (!caseData) {
      return res.status(404).json({
        error: 'NotFound',
        message: 'Case not found'
      });
    }

    const complianceReport = caseData.compliance_report || caseData.complianceReport || null;

    if (!complianceReport) {
      return res.status(404).json({
        error: 'NotFound',
        message: 'No compliance report found for this case'
      });
    }

    logger.info('Compliance report retrieved', { caseId });

    res.status(200).json({
      caseId,
      status: 'completed',
      complianceReport
    });

  } catch (error) {
    logger.error('Retrieve compliance report error', { error: error.message });
    next(error);
  }
});

module.exports = router;
