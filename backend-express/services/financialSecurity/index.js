/**
 * Financial-Grade Security Service for Backend
 * Implements bank-level security with PCI DSS, SOC 2, and GLBA compliance.
 *
 * This module assembles the FinancialSecurityService class from focused
 * sub-modules: encryption, credentials, validation, audit, and helpers.
 */

const { RateLimiterRedis } = require('rate-limiter-flexible');
const { redis, cloudHSM, logger } = require('./config');
const encryptionMethods = require('./encryption');
const credentialMethods = require('./credentials');
const validationMethods = require('./validation');
const auditMethods = require('./audit');
const helperMethods = require('./helpers');

/**
 * Financial-Grade Security Manager
 */
class FinancialSecurityService {
    constructor() {
        this.initializeRateLimiters();
        this.initializeEncryption();
        this.initializeComplianceChecks();
    }

    // ==================== INITIALIZATION ====================

    initializeRateLimiters() {
        this.rateLimiters = {
            api: new RateLimiterRedis({
                storeClient: redis,
                keyPrefix: 'rl:api',
                points: 100,
                duration: 60,
                blockDuration: 60
            }),
            auth: new RateLimiterRedis({
                storeClient: redis,
                keyPrefix: 'rl:auth',
                points: 5,
                duration: 900,
                blockDuration: 900
            }),
            transaction: new RateLimiterRedis({
                storeClient: redis,
                keyPrefix: 'rl:transaction',
                points: 10,
                duration: 60,
                blockDuration: 300
            }),
            credential: new RateLimiterRedis({
                storeClient: redis,
                keyPrefix: 'rl:credential',
                points: 20,
                duration: 3600,
                blockDuration: 3600
            })
        };
    }

    initializeEncryption() {
        this.encryptionConfig = {
            algorithm: 'aes-256-gcm',
            keyLength: 32,
            ivLength: 16,
            tagLength: 16,
            saltLength: 64,
            iterations: 100000,
            digest: 'sha512'
        };

        this.hsmClient = this.initializeHSM();
    }

    async initializeHSM() {
        if (process.env.USE_CLOUD_HSM === 'true') {
            try {
                const clusters = await cloudHSM.describeClusters({}).promise();
                if (clusters.Clusters && clusters.Clusters.length > 0) {
                    logger.info('CloudHSM initialized successfully');
                    return cloudHSM;
                }
            } catch (error) {
                logger.error('Failed to initialize CloudHSM, falling back to KMS', error);
            }
        }
        return null;
    }

    initializeComplianceChecks() {
        this.complianceRules = {
            pciDss: {
                minPasswordLength: 8,
                requireMFA: true,
                encryptionRequired: true,
                tokenizationRequired: true,
                auditLogRetention: 365 * 3,
                keyRotationDays: 90
            },
            soc2: {
                requireEncryption: true,
                requireAuditTrail: true,
                requireAccessControl: true,
                sessionTimeout: 900,
                maxFailedAttempts: 5
            },
            glba: {
                requirePrivacyNotice: true,
                dataSharingRestrictions: true,
                customerOptOut: true
            },
            ffiec: {
                requireMultiFactor: true,
                riskBasedAuth: true,
                anomalyDetection: true
            }
        };
    }
}

// Assign methods from sub-modules to the prototype
Object.assign(FinancialSecurityService.prototype,
    encryptionMethods,
    credentialMethods,
    validationMethods,
    auditMethods,
    helperMethods
);

// Export singleton instance
module.exports = new FinancialSecurityService();
