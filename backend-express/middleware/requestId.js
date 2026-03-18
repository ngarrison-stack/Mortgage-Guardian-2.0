const crypto = require('crypto');
const { createLogger, createRequestLogger } = require('../utils/logger');

const baseLogger = createLogger('request');

/**
 * Request ID middleware — assigns a unique ID to every request for log correlation.
 *
 * Uses client-provided X-Request-ID if present (for distributed tracing continuity),
 * otherwise generates a new UUID via crypto.randomUUID().
 *
 * Attaches to req.requestId and echoes back in the X-Request-ID response header.
 * Also attaches req.logger — a request-scoped Winston child logger that includes
 * requestId in every log entry for correlated tracing.
 */
function requestId(req, res, next) {
  const id = req.headers['x-request-id'] || crypto.randomUUID();
  req.requestId = id;
  res.setHeader('X-Request-ID', id);
  req.logger = createRequestLogger(baseLogger, id);
  next();
}

module.exports = requestId;
