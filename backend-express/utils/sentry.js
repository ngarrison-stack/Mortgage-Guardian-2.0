/**
 * Sentry Error Tracking Integration
 *
 * Provides optional Sentry error tracking for production environments.
 * Gracefully degrades when SENTRY_DSN is not configured — app runs fine without it.
 *
 * Does NOT capture PII — only requestId (UUID), userId (UUID), method, and path.
 * Disabled in test environment.
 */

const Sentry = require('@sentry/node');
const { createLogger } = require('./logger');

const logger = createLogger('sentry');

let initialized = false;

/**
 * Initialize Sentry with Express integration.
 * Call early — after Express app creation but before routes.
 *
 * @param {import('express').Application} app - Express application instance
 * @returns {object|undefined} Sentry instance if initialized, undefined otherwise
 */
function initSentry(app) {
  const dsn = process.env.SENTRY_DSN;

  if (!dsn) {
    logger.info('Sentry not configured (SENTRY_DSN not set)');
    return undefined;
  }

  if (process.env.NODE_ENV === 'test') {
    return undefined;
  }

  Sentry.init({
    dsn,
    environment: process.env.NODE_ENV,
    release: '2.0.0',
    tracesSampleRate: 0.1,
    integrations: [Sentry.expressIntegration()],
  });

  initialized = true;
  logger.info('Sentry initialized', { environment: process.env.NODE_ENV });

  return Sentry;
}

/**
 * Express error handler middleware for Sentry.
 * Returns Sentry's error handler if initialized, or a no-op passthrough otherwise.
 *
 * @returns {Function} Express error-handling middleware
 */
function sentryErrorHandler() {
  if (initialized) {
    return Sentry.expressErrorHandler();
  }

  // No-op middleware — pass error through to next handler
  return (err, req, res, next) => next(err);
}

/**
 * Add request context to Sentry scope.
 * Safe to call even if Sentry is not initialized — no-op in that case.
 *
 * Only captures non-PII identifiers: requestId, userId (UUID), method, path.
 *
 * @param {import('express').Request} req - Express request object
 */
function addSentryContext(req) {
  if (!initialized) {
    return;
  }

  Sentry.setContext('request', {
    requestId: req.requestId,
    userId: req.user?.id,
    method: req.method,
    path: req.path,
  });
}

module.exports = { initSentry, sentryErrorHandler, addSentryContext };
