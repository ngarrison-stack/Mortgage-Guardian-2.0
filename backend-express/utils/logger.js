/**
 * Shared Winston Logger — Structured Logging Utility
 *
 * Provides environment-aware structured logging for all backend modules.
 * Console transport only — serverless-friendly for Vercel/Railway (both capture stdout).
 *
 * Usage:
 *   const { createLogger } = require('../utils/logger');
 *   const logger = createLogger('plaid');
 *   logger.info('Token exchanged', { userId, itemId });
 */

const winston = require('winston');

const isProduction = process.env.NODE_ENV === 'production';
const isTest = process.env.NODE_ENV === 'test';

// JSON format for production (machine-parseable by log aggregators)
const productionFormat = winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
);

// Colorized human-readable format for development
const developmentFormat = winston.format.combine(
    winston.format.timestamp({ format: 'HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.colorize(),
    winston.format.printf(({ timestamp, level, message, service, ...meta }) => {
        const svc = service ? `[${service}]` : '';
        const metaStr = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
        return `${timestamp} ${level} ${svc} ${message}${metaStr}`;
    })
);

// Base logger — all child loggers inherit from this
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
    format: isProduction ? productionFormat : developmentFormat,
    defaultMeta: { service: 'mortgage-guardian' },
    silent: isTest,
    transports: [
        new winston.transports.Console()
    ]
});

/**
 * Create a child logger with a service-specific label.
 * @param {string} serviceName - Name of the service/module (e.g., 'plaid', 'claude', 'auth')
 * @returns {winston.Logger} Child logger instance
 */
function createLogger(serviceName) {
    return logger.child({ service: serviceName });
}

/**
 * Morgan stream adapter — pipes HTTP request logs through Winston at 'http' level.
 * Usage: app.use(morgan('combined', { stream: morganStream }))
 */
const morganStream = {
    write(message) {
        logger.log('http', message.trim());
    }
};

/**
 * Create a request-scoped child logger that includes requestId in every log entry.
 * @param {winston.Logger} baseLogger - Logger to create child from
 * @param {string} requestId - Request ID to include in all log entries
 * @returns {winston.Logger} Child logger with requestId metadata
 */
function createRequestLogger(baseLogger, requestId) {
    return baseLogger.child({ requestId });
}

module.exports = { logger, createLogger, createRequestLogger, morganStream };
