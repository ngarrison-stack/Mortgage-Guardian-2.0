const crypto = require('crypto');

/**
 * Request ID middleware — assigns a unique ID to every request for log correlation.
 *
 * Uses client-provided X-Request-ID if present (for distributed tracing continuity),
 * otherwise generates a new UUID via crypto.randomUUID().
 *
 * Attaches to req.requestId and echoes back in the X-Request-ID response header.
 */
function requestId(req, res, next) {
  const id = req.headers['x-request-id'] || crypto.randomUUID();
  req.requestId = id;
  res.setHeader('X-Request-ID', id);
  next();
}

module.exports = requestId;
