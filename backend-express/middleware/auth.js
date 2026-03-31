const { verifyToken } = require('@clerk/backend');
const { createLogger } = require('../utils/logger');
const logger = createLogger('auth');

/**
 * Paths that bypass JWT authentication.
 * Each entry specifies a method and path that should skip auth validation.
 * These endpoints use their own verification mechanisms.
 */
const PUBLIC_PATHS = [
  { method: 'POST', path: '/v1/plaid/webhook' }
];

/**
 * Check if a request matches a public path that bypasses auth.
 *
 * @param {string} method - HTTP method (e.g. 'GET', 'POST')
 * @param {string} url - Request originalUrl
 * @returns {boolean} True if the request should bypass auth
 */
function isPublicPath(method, url) {
  return PUBLIC_PATHS.some(
    (route) => route.method === method && url.startsWith(route.path)
  );
}

/**
 * Express middleware that enforces JWT authentication via Clerk.
 *
 * Extracts the Bearer token from the Authorization header, validates it
 * using Clerk's verifyToken(), and attaches the authenticated user to req.user.
 *
 * Returns 401 for:
 * - Missing Authorization header
 * - Malformed Authorization header (not 'Bearer <token>')
 * - Invalid or expired token
 * - Unexpected validation errors
 *
 * Public paths (defined in PUBLIC_PATHS) bypass authentication entirely.
 *
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 * @param {import('express').NextFunction} next
 */
async function requireAuth(req, res, next) {
  // Skip auth for public paths
  if (isPublicPath(req.method, req.originalUrl)) {
    return next();
  }

  try {
    // Extract Authorization header
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Missing or invalid Authorization header'
      });
    }

    // Extract token after 'Bearer '
    const token = authHeader.slice(7);

    if (!token) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Missing or invalid Authorization header'
      });
    }

    // Validate token via Clerk
    const payload = await verifyToken(token, {
      secretKey: process.env.CLERK_SECRET_KEY,
    });

    // Attach user to request for downstream handlers
    // payload.sub is the Clerk user ID
    req.user = { id: payload.sub };
    next();
  } catch (err) {
    logger.warn('Token validation failed', { error: err.message });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid or expired token'
    });
  }
}

module.exports = { requireAuth };
