/**
 * Vendor-Neutral Security — Express Middleware
 * Security headers, rate limiting, and audit logging middleware.
 */

function createSecurityMiddleware(securityService) {
    return async (req, res, next) => {
        try {
            // Security headers
            res.setHeader('X-Content-Type-Options', 'nosniff');
            res.setHeader('X-Frame-Options', 'DENY');
            res.setHeader('X-XSS-Protection', '1; mode=block');
            res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
            res.setHeader('Content-Security-Policy', "default-src 'self'");
            res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
            res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');

            // Rate limiting
            const identifier = req.ip || req.connection.remoteAddress;
            await securityService.rateLimiter.api.consume(identifier);

            // Audit logging
            await securityService.auditLogger.info('Request', {
                method: req.method,
                path: req.path,
                ip: identifier,
                userAgent: req.headers['user-agent']
            });

            next();
        } catch (error) {
            if (error.name === 'RateLimiterError') {
                res.status(429).json({
                    error: 'Too many requests',
                    retryAfter: Math.round(error.msBeforeNext / 1000) || 60
                });
            } else {
                res.status(500).json({ error: 'Internal server error' });
            }
        }
    };
}

module.exports = { createSecurityMiddleware };
