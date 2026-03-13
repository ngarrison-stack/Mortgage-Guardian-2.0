const Joi = require('joi');

/**
 * Schema for POST /v1/cases/:caseId/report (params + body)
 * Triggers consolidated report generation for a case.
 * userId comes from req.user.id (JWT auth).
 */
const generateReportSchema = Joi.object({
  generateLetter: Joi.boolean().default(false),
  letterType: Joi.string()
    .valid('qualified_written_request', 'notice_of_error', 'request_for_information')
    .default('qualified_written_request'),
  skipPersistence: Joi.boolean().default(false)
});

/**
 * Schema for GET /v1/cases/:caseId/report (params)
 * Retrieves the latest consolidated report for a case.
 */
const getReportSchema = Joi.object({
  caseId: Joi.string().trim().required()
});

/**
 * Schema for POST /v1/cases/:caseId/report/letter (body)
 * Generates a dispute letter for an existing consolidated report.
 */
const generateLetterSchema = Joi.object({
  letterType: Joi.string()
    .valid('qualified_written_request', 'notice_of_error', 'request_for_information')
    .required()
});

module.exports = {
  generateReportSchema,
  getReportSchema,
  generateLetterSchema
};
