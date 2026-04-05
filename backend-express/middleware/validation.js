const Joi = require('joi');
const logger = require('../services/logger');

// ============================================
// COMMON VALIDATION SCHEMAS
// ============================================

/**
 * Common reusable schemas for validation
 */
const schemas = {
  // ID schemas
  userId: Joi.string().max(255).required().messages({
    'string.max': 'user_id must be 255 characters or less',
    'any.required': 'user_id is required',
    'string.empty': 'user_id cannot be empty'
  }),

  userIdOptional: Joi.string().max(255).messages({
    'string.max': 'user_id must be 255 characters or less'
  }),

  documentId: Joi.string().required().messages({
    'any.required': 'documentId is required',
    'string.empty': 'documentId cannot be empty'
  }),

  itemId: Joi.string().required().messages({
    'any.required': 'item_id is required',
    'string.empty': 'item_id cannot be empty'
  }),

  // Token schemas
  accessToken: Joi.string().pattern(/^access[-_]/).required().messages({
    'string.pattern.base': 'Invalid access token format',
    'any.required': 'access_token is required',
    'string.empty': 'access_token cannot be empty'
  }),

  publicToken: Joi.string().pattern(/^public-/).required().messages({
    'string.pattern.base': 'Invalid public token format',
    'any.required': 'public_token is required',
    'string.empty': 'public_token cannot be empty'
  }),

  // Date schemas
  dateYMD: Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).required().messages({
    'string.pattern.base': 'Date must be in YYYY-MM-DD format',
    'any.required': 'Date is required',
    'string.empty': 'Date cannot be empty'
  }),

  dateYMDOptional: Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).messages({
    'string.pattern.base': 'Date must be in YYYY-MM-DD format'
  }),

  // URL schemas
  webhookUrl: Joi.string().uri({ scheme: ['http', 'https'] }).required().messages({
    'string.uri': 'Invalid webhook URL format',
    'any.required': 'webhook is required',
    'string.empty': 'webhook cannot be empty'
  }),

  // Array schemas
  accountIds: Joi.array().items(Joi.string()).messages({
    'array.base': 'account_ids must be an array'
  }),

  products: Joi.array().items(Joi.string()).messages({
    'array.base': 'products must be an array'
  }),

  // Pagination schemas
  count: Joi.number().integer().min(1).max(500).default(100).messages({
    'number.min': 'count must be at least 1',
    'number.max': 'count must be at most 500',
    'number.base': 'count must be a number'
  }),

  offset: Joi.number().integer().min(0).default(0).messages({
    'number.min': 'offset must be non-negative',
    'number.base': 'offset must be a number'
  }),

  limit: Joi.number().integer().min(1).max(1000).default(50).messages({
    'number.min': 'limit must be at least 1',
    'number.max': 'limit must be at most 1000',
    'number.base': 'limit must be a number'
  }),

  // Text schemas
  prompt: Joi.string().max(100000).messages({
    'string.max': 'prompt must be 100000 characters or less'
  }),

  fileName: Joi.string().max(500).required().messages({
    'string.max': 'fileName must be 500 characters or less',
    'any.required': 'fileName is required'
  }),

  content: Joi.string().required().messages({
    'any.required': 'content is required',
    'string.empty': 'content cannot be empty'
  }),

  // Email schema
  email: Joi.string().email().max(255).messages({
    'string.email': 'Invalid email format',
    'string.max': 'email must be 255 characters or less'
  })
};

// ============================================
// PRE-BUILT VALIDATION SCHEMAS FOR ROUTES
// ============================================

/**
 * Pre-built schemas for common API endpoints
 */
const routeSchemas = {
  // Plaid routes
  plaidLinkToken: Joi.object({
    user_id: schemas.userId,
    client_name: Joi.string().max(255),
    redirect_uri: Joi.string().uri(),
    access_token: Joi.string(),
    products: schemas.products
  }),

  plaidExchangeToken: Joi.object({
    public_token: schemas.publicToken,
    user_id: schemas.userIdOptional,
    institution_id: Joi.string()
  }),

  plaidAccounts: Joi.object({
    access_token: schemas.accessToken,
    account_ids: schemas.accountIds
  }),

  plaidTransactions: Joi.object({
    access_token: schemas.accessToken,
    start_date: schemas.dateYMD,
    end_date: schemas.dateYMD,
    account_ids: schemas.accountIds,
    count: schemas.count,
    offset: schemas.offset
  }),

  plaidItem: Joi.object({
    access_token: schemas.accessToken
  }),

  plaidWebhookUpdate: Joi.object({
    access_token: schemas.accessToken,
    webhook: schemas.webhookUrl
  }),

  // Document routes
  documentUpload: Joi.object({
    documentId: schemas.documentId,
    userId: schemas.userId.messages({
      'any.required': 'userId is required',
      'string.empty': 'userId cannot be empty'
    }),
    fileName: schemas.fileName,
    documentType: Joi.string().max(100),
    content: schemas.content,
    analysisResults: Joi.object(),
    metadata: Joi.object()
  }),

  // Claude routes
  claudeAnalyze: Joi.object({
    prompt: schemas.prompt,
    model: Joi.string().max(100),
    maxTokens: Joi.number().integer().min(1).max(100000),
    temperature: Joi.number().min(0).max(2),
    documentText: Joi.string().max(500000),
    documentType: Joi.string().max(100)
  }).or('prompt', 'documentText').messages({
    'object.missing': 'Either prompt or documentText is required'
  })
};

// ============================================
// VALIDATION MIDDLEWARE FACTORY
// ============================================

/**
 * Create validation middleware for request body
 * @param {Joi.Schema} schema - Joi schema to validate against
 * @param {Object} options - Validation options
 * @param {boolean} options.stripUnknown - Remove unknown fields (default: true)
 * @param {boolean} options.allowUnknown - Allow unknown fields (default: false)
 * @param {boolean} options.abortEarly - Stop on first error (default: false)
 * @returns {Function} Express middleware function
 */
const validateBody = (schema, options = {}) => {
  const validationOptions = {
    stripUnknown: options.stripUnknown !== false,
    allowUnknown: options.allowUnknown || false,
    abortEarly: options.abortEarly || false,
    errors: {
      wrap: {
        label: false
      }
    }
  };

  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, validationOptions);

    if (error) {
      const errorDetails = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));

      logger.debug('Validation failed', {
        path: req.path,
        errors: errorDetails
      });

      return res.status(400).json({
        error: 'Bad Request',
        message: errorDetails.map(e => e.message).join('; '),
        details: errorDetails
      });
    }

    // Replace body with validated and sanitized values
    req.body = value;
    next();
  };
};

/**
 * Create validation middleware for query parameters
 * @param {Joi.Schema} schema - Joi schema to validate against
 * @param {Object} options - Validation options
 * @returns {Function} Express middleware function
 */
const validateQuery = (schema, options = {}) => {
  const validationOptions = {
    stripUnknown: options.stripUnknown !== false,
    allowUnknown: options.allowUnknown || false,
    abortEarly: options.abortEarly || false,
    errors: {
      wrap: {
        label: false
      }
    }
  };

  return (req, res, next) => {
    const { error, value } = schema.validate(req.query, validationOptions);

    if (error) {
      const errorDetails = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));

      logger.debug('Query validation failed', {
        path: req.path,
        errors: errorDetails
      });

      return res.status(400).json({
        error: 'Bad Request',
        message: errorDetails.map(e => e.message).join('; '),
        details: errorDetails
      });
    }

    // Replace query with validated and sanitized values
    req.query = value;
    next();
  };
};

/**
 * Create validation middleware for route parameters
 * @param {Joi.Schema} schema - Joi schema to validate against
 * @returns {Function} Express middleware function
 */
const validateParams = (schema) => {
  const validationOptions = {
    abortEarly: false,
    errors: {
      wrap: {
        label: false
      }
    }
  };

  return (req, res, next) => {
    const { error, value } = schema.validate(req.params, validationOptions);

    if (error) {
      const errorDetails = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));

      logger.debug('Params validation failed', {
        path: req.path,
        errors: errorDetails
      });

      return res.status(400).json({
        error: 'Bad Request',
        message: errorDetails.map(e => e.message).join('; '),
        details: errorDetails
      });
    }

    // Replace params with validated values
    req.params = value;
    next();
  };
};

// ============================================
// INPUT SANITIZATION
// ============================================

/**
 * Sanitize string input to prevent XSS and injection attacks
 * @param {string} str - String to sanitize
 * @returns {string} Sanitized string
 */
const sanitizeString = (str) => {
  if (typeof str !== 'string') return str;
  return str
    .trim()
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/javascript:/gi, '')
    .replace(/on\w+\s*=/gi, '');
};

/**
 * Recursively sanitize object values
 * @param {Object} obj - Object to sanitize
 * @returns {Object} Sanitized object
 */
const sanitizeObject = (obj) => {
  if (typeof obj === 'string') {
    return sanitizeString(obj);
  }
  if (Array.isArray(obj)) {
    return obj.map(item => sanitizeObject(item));
  }
  if (typeof obj === 'object' && obj !== null) {
    const sanitized = {};
    for (const key of Object.keys(obj)) {
      sanitized[key] = sanitizeObject(obj[key]);
    }
    return sanitized;
  }
  return obj;
};

/**
 * Middleware to sanitize request body
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const sanitizeBody = (req, res, next) => {
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeObject(req.body);
  }
  next();
};

// ============================================
// EXPORTS
// ============================================

module.exports = {
  // Middleware factories
  validateBody,
  validateQuery,
  validateParams,
  sanitizeBody,

  // Common schemas
  schemas,

  // Pre-built route schemas
  routeSchemas,

  // Sanitization utilities
  sanitizeString,
  sanitizeObject,

  // Re-export Joi for custom schema creation
  Joi
};
