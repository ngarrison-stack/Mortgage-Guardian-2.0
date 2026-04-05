const logger = require('../services/logger');

// ============================================
// CUSTOM ERROR CLASSES
// ============================================

/**
 * Base application error class
 * Extends Error with additional properties for API error responses
 */
class AppError extends Error {
  /**
   * Create an application error
   * @param {string} message - Error message
   * @param {number} statusCode - HTTP status code (default: 500)
   * @param {Object} options - Additional error options
   * @param {string} options.code - Error code for client handling
   * @param {string} options.type - Error type/category
   * @param {string} options.displayMessage - User-friendly message
   * @param {Object} options.details - Additional error details
   */
  constructor(message, statusCode = 500, options = {}) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.code = options.code || 'INTERNAL_ERROR';
    this.type = options.type || 'application_error';
    this.displayMessage = options.displayMessage || message;
    this.details = options.details || null;
    this.isOperational = true; // Distinguishes operational errors from programming errors

    Error.captureStackTrace(this, this.constructor);
  }

  /**
   * Convert error to JSON-serializable object
   * @param {boolean} includeStack - Whether to include stack trace
   * @returns {Object} Serializable error object
   */
  toJSON(includeStack = false) {
    return {
      error: this.name,
      code: this.code,
      type: this.type,
      message: this.message,
      displayMessage: this.displayMessage,
      details: this.details,
      ...(includeStack && { stack: this.stack })
    };
  }
}

/**
 * Validation error - for request validation failures
 */
class ValidationError extends AppError {
  constructor(message, details = null) {
    super(message, 400, {
      code: 'VALIDATION_ERROR',
      type: 'validation_error',
      displayMessage: message,
      details
    });
  }
}

/**
 * Not found error - for missing resources
 */
class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404, {
      code: 'NOT_FOUND',
      type: 'not_found_error',
      displayMessage: `The requested ${resource.toLowerCase()} could not be found`
    });
    this.resource = resource;
  }
}

/**
 * Authentication error - for auth failures
 */
class AuthenticationError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, {
      code: 'AUTHENTICATION_ERROR',
      type: 'authentication_error',
      displayMessage: message
    });
  }
}

/**
 * Authorization error - for permission failures
 */
class AuthorizationError extends AppError {
  constructor(message = 'Access denied') {
    super(message, 403, {
      code: 'AUTHORIZATION_ERROR',
      type: 'authorization_error',
      displayMessage: message
    });
  }
}

/**
 * Conflict error - for resource conflicts
 */
class ConflictError extends AppError {
  constructor(message = 'Resource conflict') {
    super(message, 409, {
      code: 'CONFLICT_ERROR',
      type: 'conflict_error',
      displayMessage: message
    });
  }
}

/**
 * Rate limit error - for throttling
 */
class RateLimitError extends AppError {
  constructor(message = 'Too many requests', retryAfter = null) {
    super(message, 429, {
      code: 'RATE_LIMIT_ERROR',
      type: 'rate_limit_error',
      displayMessage: 'Please slow down and try again later',
      details: retryAfter ? { retryAfter } : null
    });
    this.retryAfter = retryAfter;
  }
}

/**
 * External service error - for third-party API failures
 */
class ExternalServiceError extends AppError {
  constructor(serviceName, originalError = null) {
    const message = `External service error: ${serviceName}`;
    super(message, 502, {
      code: 'EXTERNAL_SERVICE_ERROR',
      type: 'external_service_error',
      displayMessage: 'An external service is temporarily unavailable',
      details: {
        service: serviceName,
        originalMessage: originalError?.message
      }
    });
    this.serviceName = serviceName;
    this.originalError = originalError;
  }
}

// ============================================
// ASYNC HANDLER WRAPPER
// ============================================

/**
 * Wrap async route handlers to automatically catch errors
 * Eliminates the need for try/catch blocks in every route
 *
 * @param {Function} fn - Async route handler function
 * @returns {Function} Wrapped middleware function
 *
 * @example
 * // Instead of:
 * router.get('/users', async (req, res, next) => {
 *   try {
 *     const users = await userService.getAll();
 *     res.json(users);
 *   } catch (error) {
 *     next(error);
 *   }
 * });
 *
 * // Use:
 * router.get('/users', asyncHandler(async (req, res) => {
 *   const users = await userService.getAll();
 *   res.json(users);
 * }));
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// ============================================
// ERROR RESPONSE FORMATTERS
// ============================================

/**
 * Format error for API response
 * @param {Error} error - Error to format
 * @param {boolean} isDevelopment - Whether to include debug info
 * @returns {Object} Formatted error response
 */
const formatErrorResponse = (error, isDevelopment = false) => {
  // Handle AppError instances
  if (error instanceof AppError) {
    return {
      ...error.toJSON(isDevelopment),
      ...(isDevelopment && { stack: error.stack })
    };
  }

  // Handle Plaid-specific errors (from plaidService.formatPlaidError)
  if (error.type && error.code) {
    return {
      error: 'Plaid API Error',
      type: error.type,
      code: error.code,
      message: error.message,
      displayMessage: error.displayMessage || error.message,
      ...(isDevelopment && { stack: error.stack })
    };
  }

  // Handle validation errors from Joi
  if (error.isJoi || error.details) {
    return {
      error: 'Validation Error',
      code: 'VALIDATION_ERROR',
      type: 'validation_error',
      message: error.message,
      details: error.details?.map(d => ({
        field: d.path?.join('.'),
        message: d.message
      })),
      ...(isDevelopment && { stack: error.stack })
    };
  }

  // Handle generic errors
  const statusCode = error.statusCode || 500;
  const isInternalError = statusCode >= 500;

  return {
    error: isInternalError ? 'Internal Server Error' : 'Error',
    code: error.code || (isInternalError ? 'INTERNAL_ERROR' : 'ERROR'),
    type: error.type || 'error',
    message: isDevelopment || !isInternalError
      ? error.message
      : 'An unexpected error occurred',
    ...(isDevelopment && { stack: error.stack })
  };
};

/**
 * Get HTTP status code from error
 * @param {Error} error - Error to analyze
 * @returns {number} HTTP status code
 */
const getStatusCode = (error) => {
  // Use explicit statusCode if available
  if (error.statusCode) {
    return error.statusCode;
  }

  // Plaid errors
  if (error.type && error.code) {
    return error.statusCode || 400;
  }

  // Joi validation errors
  if (error.isJoi || error.details) {
    return 400;
  }

  // Default to 500
  return 500;
};

// ============================================
// ERROR HANDLER MIDDLEWARE
// ============================================

/**
 * Global error handler middleware
 * Should be registered last in the middleware chain
 *
 * @param {Error} err - Error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Next middleware function
 */
const errorHandler = (err, req, res, next) => {
  const isDevelopment = process.env.NODE_ENV !== 'production';
  const statusCode = getStatusCode(err);

  // Log the error
  const logContext = {
    method: req.method,
    path: req.path,
    statusCode,
    requestId: req.id || req.headers['x-request-id'],
    userId: req.user?.userId || req.user?.sub
  };

  // Log at appropriate level based on status code
  if (statusCode >= 500) {
    logger.logError('Unhandled server error', err, logContext);
  } else if (statusCode >= 400) {
    logger.warn('Client error', {
      ...logContext,
      errorMessage: err.message,
      errorCode: err.code
    });
  }

  // Format and send response
  const errorResponse = formatErrorResponse(err, isDevelopment);

  // Add rate limit headers if applicable
  if (err instanceof RateLimitError && err.retryAfter) {
    res.set('Retry-After', String(err.retryAfter));
  }

  res.status(statusCode).json(errorResponse);
};

/**
 * Not found handler middleware
 * Use for undefined routes
 */
const notFoundHandler = (req, res, next) => {
  const error = new NotFoundError('Endpoint');
  error.message = `Cannot ${req.method} ${req.path}`;
  next(error);
};

// ============================================
// ERROR CREATION HELPERS
// ============================================

/**
 * Create an error from a status code
 * @param {number} statusCode - HTTP status code
 * @param {string} message - Error message
 * @param {Object} options - Additional options
 * @returns {AppError} Application error
 */
const createError = (statusCode, message, options = {}) => {
  return new AppError(message, statusCode, options);
};

/**
 * Wrap external service errors with additional context
 * @param {string} serviceName - Name of the external service
 * @param {Error} error - Original error
 * @returns {ExternalServiceError} Wrapped error
 */
const wrapExternalError = (serviceName, error) => {
  return new ExternalServiceError(serviceName, error);
};

// ============================================
// EXPORTS
// ============================================

module.exports = {
  // Error classes
  AppError,
  ValidationError,
  NotFoundError,
  AuthenticationError,
  AuthorizationError,
  ConflictError,
  RateLimitError,
  ExternalServiceError,

  // Middleware
  asyncHandler,
  errorHandler,
  notFoundHandler,

  // Utilities
  formatErrorResponse,
  getStatusCode,
  createError,
  wrapExternalError
};
