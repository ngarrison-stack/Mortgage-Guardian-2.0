/**
 * Financial Security Service — Helper Methods
 * Utility methods, MFA verification, suspicious activity tracking,
 * security alerts, and Express middleware.
 */

const crypto = require('crypto');
const { redis, logger } = require('./config');

// Optional: speakeasy for MFA/TOTP (future deployment)
let speakeasy;
try { speakeasy = require('speakeasy'); } catch { speakeasy = null; }

module.exports = {
    sanitizeForLog(value) {
        if (typeof value === 'string') {
            return value.substring(0, 4) + '****';
        }
        return '****';
    },

    async generateSecureCredential() {
        return crypto.randomBytes(32).toString('base64');
    },

    async verifyMFA(userId, token) {
        if (!speakeasy) {
            throw new Error('MFA not available: speakeasy package not installed');
        }
        const secret = await this.getUserMFASecret(userId);
        return speakeasy.totp.verify({
            secret,
            encoding: 'base32',
            token,
            window: 2
        });
    },

    async checkSuspiciousActivity(context) {
        const key = `suspicious:${context.userId}:${context.ipAddress}`;
        const attempts = await redis.incr(key);
        await redis.expire(key, 3600);

        if (attempts > 5) {
            await redis.sadd('blocked:users', context.userId);
            await redis.sadd('blocked:ips', context.ipAddress);

            await this.alertSecurityTeam({
                type: 'SUSPICIOUS_ACTIVITY',
                userId: context.userId,
                ipAddress: context.ipAddress,
                attempts
            });
        }
    },

    async alertSecurityTeam(alert) {
        logger.error('SECURITY ALERT', alert);
    },

    /**
     * Express middleware for request security
     */
    securityMiddleware() {
        return async (req, res, next) => {
            try {
                const context = {
                    userId: req.user?.id,
                    token: req.headers.authorization?.replace('Bearer ', ''),
                    ipAddress: req.ip,
                    deviceId: req.headers['x-device-id'],
                    deviceJailbroken: req.headers['x-device-jailbroken'] === 'true',
                    userAgent: req.headers['user-agent'],
                    resource: req.path,
                    action: req.method,
                    timestamp: new Date()
                };

                await this.rateLimiters.api.consume(context.ipAddress);

                await this.validateZeroTrust(context);

                res.setHeader('X-Content-Type-Options', 'nosniff');
                res.setHeader('X-Frame-Options', 'DENY');
                res.setHeader('X-XSS-Protection', '1; mode=block');
                res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
                res.setHeader('Content-Security-Policy', "default-src 'self'");

                req.securityContext = context;

                next();
            } catch (error) {
                await this.auditLog('SECURITY_MIDDLEWARE_FAILURE', {
                    error: error.message,
                    ip: req.ip,
                    path: req.path
                });

                res.status(403).json({
                    error: 'Security validation failed',
                    code: 'SECURITY_ERROR'
                });
            }
        };
    }
};
