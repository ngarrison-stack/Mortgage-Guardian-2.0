const winston = require('winston');

// Environment configuration
const nodeEnv = process.env.NODE_ENV || 'development';
const logLevel = process.env.LOG_LEVEL || (nodeEnv === 'production' ? 'info' : 'debug');
const logFormat = process.env.LOG_FORMAT || (nodeEnv === 'production' ? 'json' : 'pretty');

// Define custom log levels with colors
const customLevels = {
  levels: {
    error: 0,
    warn: 1,
    info: 2,
    http: 3,
    debug: 4
  },
  colors: {
    error: 'red',
    warn: 'yellow',
    info: 'green',
    http: 'magenta',
    debug: 'blue'
  }
};

// Apply colors to Winston
winston.addColors(customLevels.colors);

/**
 * Sanitize sensitive data from log messages
 * Removes common sensitive field names to prevent accidental exposure
 * @param {Object} obj - Object to sanitize
 * @returns {Object} Sanitized object
 */
const sanitizeSensitiveData = (obj) => {
  if (!obj || typeof obj !== 'object') return obj;

  const sensitiveKeys = [
    'password', 'token', 'accessToken', 'access_token', 'refreshToken',
    'refresh_token', 'secret', 'apiKey', 'api_key', 'authorization',
    'plaid_secret', 'plaidSecret', 'jwt', 'cookie', 'session'
  ];

  const sanitized = { ...obj };

  for (const key of Object.keys(sanitized)) {
    const lowerKey = key.toLowerCase();
    if (sensitiveKeys.some(sensitive => lowerKey.includes(sensitive.toLowerCase()))) {
      sanitized[key] = '[REDACTED]';
    } else if (typeof sanitized[key] === 'object' && sanitized[key] !== null) {
      sanitized[key] = sanitizeSensitiveData(sanitized[key]);
    }
  }

  return sanitized;
};

/**
 * Custom format for development - colorful and human-readable
 */
const devFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
  winston.format.colorize({ all: true }),
  winston.format.printf(({ timestamp, level, message, requestId, service, ...meta }) => {
    const reqIdStr = requestId ? ` [${requestId}]` : '';
    const serviceStr = service ? ` [${service}]` : '';
    const metaStr = Object.keys(meta).length > 0
      ? `\n${JSON.stringify(sanitizeSensitiveData(meta), null, 2)}`
      : '';
    return `${timestamp}${serviceStr}${reqIdStr} ${level}: ${message}${metaStr}`;
  })
);

/**
 * Custom format for production - JSON for structured logging
 */
const prodFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DDTHH:mm:ss.SSSZ' }),
  winston.format.errors({ stack: true }),
  winston.format((info) => {
    // Sanitize metadata in production
    return sanitizeSensitiveData(info);
  })(),
  winston.format.json()
);

/**
 * Create the logger instance
 */
const logger = winston.createLogger({
  levels: customLevels.levels,
  level: logLevel,
  defaultMeta: {
    service: 'mortgage-guardian-backend',
    environment: nodeEnv
  },
  format: logFormat === 'json' ? prodFormat : devFormat,
  transports: [
    // Console transport - always enabled
    new winston.transports.Console({
      handleExceptions: true,
      handleRejections: true
    })
  ],
  // Prevent process exit on handled exceptions
  exitOnError: false
});

/**
 * Create a child logger with request context
 * Use this in route handlers to automatically include requestId
 * @param {Object} context - Context to include in all logs
 * @returns {Object} Child logger instance
 */
logger.child = function(context) {
  return {
    error: (message, meta = {}) => logger.error(message, { ...context, ...meta }),
    warn: (message, meta = {}) => logger.warn(message, { ...context, ...meta }),
    info: (message, meta = {}) => logger.info(message, { ...context, ...meta }),
    http: (message, meta = {}) => logger.http(message, { ...context, ...meta }),
    debug: (message, meta = {}) => logger.debug(message, { ...context, ...meta })
  };
};

/**
 * Log HTTP requests (for use with morgan or custom middleware)
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {number} responseTime - Response time in ms
 */
logger.logHttpRequest = function(req, res, responseTime) {
  const logData = {
    method: req.method,
    url: req.originalUrl || req.url,
    statusCode: res.statusCode,
    responseTime: `${responseTime}ms`,
    userAgent: req.get('User-Agent'),
    ip: req.ip || req.connection?.remoteAddress,
    requestId: req.id || req.headers['x-request-id']
  };

  // Log at appropriate level based on status code
  if (res.statusCode >= 500) {
    logger.error('HTTP Request Error', logData);
  } else if (res.statusCode >= 400) {
    logger.warn('HTTP Request Warning', logData);
  } else {
    logger.http('HTTP Request', logData);
  }
};

/**
 * Log errors with full stack traces and context
 * @param {string} message - Error message
 * @param {Error} error - Error object
 * @param {Object} context - Additional context
 */
logger.logError = function(message, error, context = {}) {
  const errorData = {
    ...context,
    errorName: error?.name,
    errorMessage: error?.message,
    errorStack: error?.stack,
    errorCode: error?.code || error?.statusCode
  };

  logger.error(message, errorData);
};

/**
 * Log API service calls (Plaid, Claude, etc.)
 * @param {string} service - Service name (e.g., 'plaid', 'claude')
 * @param {string} operation - Operation name
 * @param {Object} details - Operation details
 */
logger.logApiCall = function(service, operation, details = {}) {
  logger.info(`API Call: ${service}.${operation}`, {
    apiService: service,
    operation,
    ...sanitizeSensitiveData(details)
  });
};

/**
 * Log security-related events
 * @param {string} event - Security event type
 * @param {Object} details - Event details
 */
logger.logSecurityEvent = function(event, details = {}) {
  logger.warn(`Security Event: ${event}`, {
    securityEvent: event,
    ...sanitizeSensitiveData(details)
  });
};

// Log startup information
logger.info('Logger initialized', {
  level: logLevel,
  format: logFormat,
  environment: nodeEnv
});

module.exports = logger;
