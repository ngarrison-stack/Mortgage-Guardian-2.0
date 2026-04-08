const { createClient } = require('@supabase/supabase-js');
const jwksRsa = require('jwks-rsa');
const { createLogger } = require('../utils/logger');
const logger = createLogger('auth');

// Initialize Supabase client for JWT validation
// Uses anon key (not service key) — correct for auth.getUser() token validation
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

let supabase = null;
if (supabaseUrl && supabaseAnonKey) {
  supabase = createClient(supabaseUrl, supabaseAnonKey);
} else {
  logger.warn('Supabase not configured - auth middleware will reject all requests unless mocked');
}

// Initialize Clerk JWKS client for iOS/mobile token verification
const clerkIssuerUrl = process.env.CLERK_ISSUER_URL || 'https://fond-mako-71.clerk.accounts.dev';

const jwksClient = jwksRsa({
  jwksUri: `${clerkIssuerUrl}/.well-known/jwks.json`,
  cache: true,
  rateLimit: true,
  jwksRequestsPerMinute: 5,
  cacheMaxAge: 600000 // 10 minutes
});

/**
 * Decode a JWT without verification to read the header and payload.
 * @param {string} token - Raw JWT string
 * @returns {{ header: Object, payload: Object }} Decoded parts
 */
function decodeJwt(token) {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT structure');
  }
  const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString());
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  return { header, payload };
}

/**
 * Verify a JWT using the Clerk JWKS endpoint.
 * Checks RS256 signature, issuer, and expiration.
 *
 * @param {string} token - Raw JWT string
 * @returns {Promise<Object>} Decoded payload on success
 * @throws {Error} On verification failure
 */
async function verifyClerkToken(token) {
  const { header, payload } = decodeJwt(token);

  if (header.alg !== 'RS256') {
    throw new Error('Unsupported algorithm: ' + header.alg);
  }

  // Get the signing key from JWKS
  const key = await jwksClient.getSigningKey(header.kid);
  const publicKey = key.getPublicKey();

  // Verify signature using Node.js crypto
  const crypto = require('crypto');
  const [headerB64, payloadB64, signatureB64] = token.split('.');
  const data = `${headerB64}.${payloadB64}`;
  const signature = Buffer.from(signatureB64, 'base64url');

  const verifier = crypto.createVerify('RSA-SHA256');
  verifier.update(data);
  const isValid = verifier.verify(publicKey, signature);

  if (!isValid) {
    throw new Error('Invalid JWT signature');
  }

  // Verify issuer
  if (payload.iss !== clerkIssuerUrl) {
    throw new Error('Invalid issuer: ' + payload.iss);
  }

  // Verify expiration
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) {
    throw new Error('Token expired');
  }

  return payload;
}

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
 * Express middleware that enforces JWT authentication via dual-provider flow.
 *
 * Verification order:
 * 1. Try Clerk JWKS verification first (for iOS/mobile tokens)
 * 2. Fall back to Supabase auth.getUser() (for web frontend tokens)
 *
 * Returns 401 for:
 * - Missing Authorization header
 * - Malformed Authorization header (not 'Bearer <token>')
 * - Both Clerk and Supabase verification fail
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

    // --- Try Clerk JWKS verification first (iOS/mobile tokens) ---
    try {
      const decoded = await verifyClerkToken(token);
      req.user = {
        id: decoded.sub,
        email: decoded.email || null,
        provider: 'clerk'
      };
      return next();
    } catch (clerkError) {
      logger.debug('Clerk verification failed, trying Supabase fallback', {
        reason: clerkError.message
      });
    }

    // --- Fall back to Supabase validation (web frontend tokens) ---
    try {
      const { data, error } = await supabase.auth.getUser(token);

      if (error || !data || !data.user) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'Invalid or expired token'
        });
      }

      // Attach user to request for downstream handlers
      req.user = {
        ...data.user,
        provider: 'supabase'
      };
      return next();
    } catch (supabaseError) {
      logger.debug('Supabase verification also failed', {
        reason: supabaseError.message
      });
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
    }
  } catch (err) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Token validation failed'
    });
  }
}

module.exports = { requireAuth };
