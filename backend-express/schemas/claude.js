const Joi = require('joi');

/**
 * Schema for POST /v1/ai/claude/analyze
 * Validates Claude AI document analysis request body.
 * At least one of prompt or documentText must be present.
 */
const analyzeSchema = Joi.object({
  prompt: Joi.string().trim().optional(),
  documentText: Joi.string().trim().optional(),
  model: Joi.string().trim().default('claude-3-5-sonnet-20241022').optional(),
  maxTokens: Joi.number().integer().min(1).max(100000).default(4096).optional(),
  temperature: Joi.number().min(0).max(1).default(0.1).optional(),
  documentType: Joi.string().trim().optional()
}).or('prompt', 'documentText');

module.exports = {
  analyzeSchema
};
