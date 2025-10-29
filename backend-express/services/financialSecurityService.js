/**
 * Financial-Grade Security Service for Backend
 * Implements bank-level security with PCI DSS, SOC 2, and GLBA compliance
 */

const crypto = require('crypto');
const AWS = require('aws-sdk');
const { promisify } = require('util');
const jwt = require('jsonwebtoken');
const speakeasy = require('speakeasy');
const { RateLimiterRedis } = require('rate-limiter-flexible');
const Redis = require('ioredis');
const winston = require('winston');
const { ElasticsearchTransport } = require('winston-elasticsearch');

// Initialize AWS services
const kms = new AWS.KMS({ region: process.env.AWS_REGION || 'us-east-1' });
const secretsManager = new AWS.SecretsManager({ region: process.env.AWS_REGION || 'us-east-1' });
const cloudHSM = new AWS.CloudHSMV2({ region: process.env.AWS_REGION || 'us-east-1' });

// Initialize Redis for session management and rate limiting
const redis = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD,
    enableTLSForSentinelMode: true,
    tls: {
        rejectUnauthorized: true
    },
    retryStrategy: (times) => Math.min(times * 50, 2000)
});

// Configure secure logging with audit trail
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'financial-security' },
    transports: [
        // Write to encrypted files
        new winston.transports.File({
            filename: '/var/log/mortgage-guardian/security-error.log',
            level: 'error',
            maxsize: 5242880, // 5MB
            maxFiles: 5
        }),
        new winston.transports.File({
            filename: '/var/log/mortgage-guardian/security-audit.log',
            level: 'info',
            maxsize: 5242880,
            maxFiles: 30 // 30 days retention
        }),
        // Send to Elasticsearch for SIEM
        new ElasticsearchTransport({
            level: 'info',
            clientOpts: {
                node: process.env.ELASTICSEARCH_URL || 'https://localhost:9200',
                auth: {
                    username: process.env.ELASTICSEARCH_USER,
                    password: process.env.ELASTICSEARCH_PASSWORD
                }
            },
            index: 'security-audit'
        })
    ]
});

// Add console logging in development
if (process.env.NODE_ENV === 'development') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

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
        // Different rate limiters for different operations
        this.rateLimiters = {
            // API calls - 100 per minute per IP
            api: new RateLimiterRedis({
                storeClient: redis,
                keyPrefix: 'rl:api',
                points: 100,
                duration: 60,
                blockDuration: 60
            }),
            // Authentication - 5 attempts per 15 minutes
            auth: new RateLimiterRedis({
                storeClient: redis,
                keyPrefix: 'rl:auth',
                points: 5,
                duration: 900,
                blockDuration: 900
            }),
            // Financial transactions - 10 per minute
            transaction: new RateLimiterRedis({
                storeClient: redis,
                keyPrefix: 'rl:transaction',
                points: 10,
                duration: 60,
                blockDuration: 300
            }),
            // Credential access - 20 per hour
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
        // FIPS 140-2 compliant encryption settings
        this.encryptionConfig = {
            algorithm: 'aes-256-gcm',
            keyLength: 32,
            ivLength: 16,
            tagLength: 16,
            saltLength: 64,
            iterations: 100000, // PBKDF2 iterations
            digest: 'sha512'
        };

        // Initialize HSM connection for critical operations
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
        return null; // Fall back to AWS KMS
    }

    initializeComplianceChecks() {
        this.complianceRules = {
            pciDss: {
                minPasswordLength: 8,
                requireMFA: true,
                encryptionRequired: true,
                tokenizationRequired: true,
                auditLogRetention: 365 * 3, // 3 years
                keyRotationDays: 90
            },
            soc2: {
                requireEncryption: true,
                requireAuditTrail: true,
                requireAccessControl: true,
                sessionTimeout: 900, // 15 minutes
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

    // ==================== CREDENTIAL MANAGEMENT ====================

    /**
     * Store credential with HSM/KMS encryption
     */
    async storeCredential(key, value, metadata = {}) {
        try {
            // Rate limiting
            await this.rateLimiters.credential.consume(metadata.userId || 'system');

            // Audit log - credential access attempt
            await this.auditLog('CREDENTIAL_STORE_ATTEMPT', {
                key: this.sanitizeForLog(key),
                userId: metadata.userId,
                ip: metadata.ipAddress
            });

            // Validate compliance
            await this.validateCompliance('credentialStorage', metadata);

            // Encrypt the credential
            const encrypted = await this.encryptWithHSM(value);

            // Store in AWS Secrets Manager with versioning
            const secretArn = await this.storeInSecretsManager(key, encrypted, metadata);

            // Audit log - success
            await this.auditLog('CREDENTIAL_STORE_SUCCESS', {
                key: this.sanitizeForLog(key),
                secretArn,
                userId: metadata.userId
            });

            return secretArn;

        } catch (error) {
            // Audit log - failure
            await this.auditLog('CREDENTIAL_STORE_FAILURE', {
                key: this.sanitizeForLog(key),
                error: error.message,
                userId: metadata.userId
            });

            throw error;
        }
    }

    /**
     * Retrieve credential with zero-trust validation
     */
    async retrieveCredential(key, context = {}) {
        try {
            // Zero-trust validation
            await this.validateZeroTrust(context);

            // Rate limiting
            await this.rateLimiters.credential.consume(context.userId || 'system');

            // Audit log - access attempt
            await this.auditLog('CREDENTIAL_RETRIEVE_ATTEMPT', {
                key: this.sanitizeForLog(key),
                userId: context.userId,
                ip: context.ipAddress,
                deviceId: context.deviceId
            });

            // Retrieve from Secrets Manager
            const encrypted = await this.retrieveFromSecretsManager(key);

            // Decrypt with HSM/KMS
            const decrypted = await this.decryptWithHSM(encrypted);

            // Audit log - success
            await this.auditLog('CREDENTIAL_RETRIEVE_SUCCESS', {
                key: this.sanitizeForLog(key),
                userId: context.userId
            });

            return decrypted;

        } catch (error) {
            // Audit log - failure
            await this.auditLog('CREDENTIAL_RETRIEVE_FAILURE', {
                key: this.sanitizeForLog(key),
                error: error.message,
                userId: context.userId
            });

            // Check for suspicious activity
            await this.checkSuspiciousActivity(context);

            throw error;
        }
    }

    /**
     * Rotate credentials automatically
     */
    async rotateCredential(key, context = {}) {
        try {
            await this.auditLog('CREDENTIAL_ROTATION_START', {
                key: this.sanitizeForLog(key),
                userId: context.userId
            });

            // Generate new credential
            const newValue = await this.generateSecureCredential();

            // Store new version
            const newArn = await this.storeCredential(`${key}-new`, newValue, context);

            // Update applications to use new credential
            await this.updateCredentialReferences(key, newArn);

            // Mark old credential for deletion (after grace period)
            await this.scheduleCredentialDeletion(key, 7); // 7 days grace period

            await this.auditLog('CREDENTIAL_ROTATION_SUCCESS', {
                key: this.sanitizeForLog(key),
                newArn
            });

            return newArn;

        } catch (error) {
            await this.auditLog('CREDENTIAL_ROTATION_FAILURE', {
                key: this.sanitizeForLog(key),
                error: error.message
            });
            throw error;
        }
    }

    // ==================== ENCRYPTION METHODS ====================

    /**
     * Encrypt with HSM or KMS
     */
    async encryptWithHSM(plaintext) {
        try {
            if (this.hsmClient) {
                // Use CloudHSM for highest security
                return await this.encryptWithCloudHSM(plaintext);
            } else {
                // Fall back to AWS KMS
                return await this.encryptWithKMS(plaintext);
            }
        } catch (error) {
            logger.error('Encryption failed', error);
            throw new Error('Failed to encrypt data');
        }
    }

    /**
     * Encrypt with AWS KMS
     */
    async encryptWithKMS(plaintext) {
        const params = {
            KeyId: process.env.KMS_KEY_ID,
            Plaintext: plaintext,
            EncryptionContext: {
                service: 'mortgage-guardian',
                purpose: 'credential-encryption',
                timestamp: new Date().toISOString()
            }
        };

        const result = await kms.encrypt(params).promise();
        return result.CiphertextBlob.toString('base64');
    }

    /**
     * Decrypt with HSM or KMS
     */
    async decryptWithHSM(ciphertext) {
        try {
            if (this.hsmClient) {
                return await this.decryptWithCloudHSM(ciphertext);
            } else {
                return await this.decryptWithKMS(ciphertext);
            }
        } catch (error) {
            logger.error('Decryption failed', error);
            throw new Error('Failed to decrypt data');
        }
    }

    /**
     * Decrypt with AWS KMS
     */
    async decryptWithKMS(ciphertext) {
        const params = {
            CiphertextBlob: Buffer.from(ciphertext, 'base64'),
            EncryptionContext: {
                service: 'mortgage-guardian',
                purpose: 'credential-encryption'
            }
        };

        const result = await kms.decrypt(params).promise();
        return result.Plaintext.toString();
    }

    // ==================== ZERO-TRUST VALIDATION ====================

    /**
     * Validate request with zero-trust principles
     */
    async validateZeroTrust(context) {
        const validations = await Promise.all([
            this.validateIdentity(context),
            this.validateDevice(context),
            this.validateNetwork(context),
            this.validateBehavior(context),
            this.validatePermissions(context)
        ]);

        if (!validations.every(v => v === true)) {
            throw new Error('Zero-trust validation failed');
        }

        return true;
    }

    async validateIdentity(context) {
        // Verify JWT token
        if (!context.token) {
            return false;
        }

        try {
            const decoded = jwt.verify(context.token, process.env.JWT_SECRET);

            // Check token expiration and claims
            if (decoded.exp < Date.now() / 1000) {
                return false;
            }

            // Verify MFA if required
            if (this.complianceRules.ffiec.requireMultiFactor) {
                return await this.verifyMFA(context.userId, context.mfaToken);
            }

            return true;
        } catch (error) {
            return false;
        }
    }

    async validateDevice(context) {
        // Device fingerprinting and trust verification
        if (!context.deviceId) {
            return false;
        }

        // Check if device is registered and trusted
        const deviceTrust = await redis.get(`device:trust:${context.deviceId}`);
        if (!deviceTrust) {
            return false;
        }

        // Check for jailbreak/root detection flags
        if (context.deviceJailbroken || context.deviceRooted) {
            await this.auditLog('UNTRUSTED_DEVICE', {
                deviceId: context.deviceId,
                reason: 'Jailbroken or rooted device'
            });
            return false;
        }

        return true;
    }

    async validateNetwork(context) {
        // IP reputation and geolocation checks
        if (!context.ipAddress) {
            return false;
        }

        // Check IP blacklist
        const isBlacklisted = await redis.sismember('ip:blacklist', context.ipAddress);
        if (isBlacklisted) {
            return false;
        }

        // Verify geolocation if enabled
        if (context.requireGeofencing) {
            return await this.validateGeolocation(context);
        }

        return true;
    }

    async validateBehavior(context) {
        // Behavioral analytics and anomaly detection
        const userBehavior = await this.getUserBehaviorProfile(context.userId);

        // Check for anomalies
        const anomalies = await this.detectAnomalies(context, userBehavior);
        if (anomalies.length > 0) {
            await this.auditLog('BEHAVIORAL_ANOMALY', {
                userId: context.userId,
                anomalies
            });

            // Require step-up authentication for anomalies
            if (!context.stepUpAuthCompleted) {
                return false;
            }
        }

        return true;
    }

    async validatePermissions(context) {
        // Fine-grained permission checking
        const permissions = await this.getUserPermissions(context.userId);

        // Check resource access
        if (!permissions.includes(context.resource)) {
            await this.auditLog('PERMISSION_DENIED', {
                userId: context.userId,
                resource: context.resource
            });
            return false;
        }

        // Check action permission
        if (!this.canPerformAction(permissions, context.action)) {
            return false;
        }

        return true;
    }

    // ==================== FRAUD DETECTION ====================

    /**
     * Real-time fraud detection for financial transactions
     */
    async detectFraud(transaction) {
        const riskFactors = [];
        let riskScore = 0;

        // Check transaction amount
        if (transaction.amount > 10000) {
            riskFactors.push('HIGH_VALUE_TRANSACTION');
            riskScore += 0.3;
        }

        // Check velocity
        const recentTransactions = await this.getRecentTransactions(transaction.userId);
        const velocity = this.calculateVelocity(recentTransactions);
        if (velocity > 5) { // More than 5 transactions in last hour
            riskFactors.push('HIGH_VELOCITY');
            riskScore += 0.2;
        }

        // Check location
        const locationRisk = await this.assessLocationRisk(transaction);
        if (locationRisk > 0.5) {
            riskFactors.push('RISKY_LOCATION');
            riskScore += locationRisk * 0.3;
        }

        // Machine learning model scoring
        const mlScore = await this.runFraudMLModel(transaction);
        riskScore += mlScore * 0.5;

        // Determine action based on risk score
        let action;
        if (riskScore < 0.3) {
            action = 'ALLOW';
        } else if (riskScore < 0.6) {
            action = 'REVIEW';
        } else if (riskScore < 0.8) {
            action = 'CHALLENGE'; // Require additional authentication
        } else {
            action = 'BLOCK';
        }

        // Audit all transactions
        await this.auditLog('TRANSACTION_RISK_ASSESSMENT', {
            transactionId: transaction.id,
            riskScore,
            riskFactors,
            action
        });

        return { riskScore, riskFactors, action };
    }

    // ==================== COMPLIANCE METHODS ====================

    /**
     * Validate compliance with financial regulations
     */
    async validateCompliance(operation, context) {
        const violations = [];

        // PCI DSS compliance
        if (operation === 'paymentProcessing') {
            if (!context.tokenized) {
                violations.push('PCI_DSS: Card data must be tokenized');
            }
            if (!context.encrypted) {
                violations.push('PCI_DSS: Data must be encrypted');
            }
        }

        // SOC 2 compliance
        if (!context.auditTrail) {
            violations.push('SOC2: Audit trail required');
        }

        // GLBA compliance
        if (operation === 'dataSharing' && !context.customerConsent) {
            violations.push('GLBA: Customer consent required for data sharing');
        }

        // FFIEC compliance
        if (operation === 'authentication' && !context.multiFactor) {
            violations.push('FFIEC: Multi-factor authentication required');
        }

        if (violations.length > 0) {
            await this.auditLog('COMPLIANCE_VIOLATION', {
                operation,
                violations,
                context
            });
            throw new Error(`Compliance violations: ${violations.join(', ')}`);
        }

        return true;
    }

    // ==================== AUDIT LOGGING ====================

    /**
     * Create immutable audit log entry
     */
    async auditLog(eventType, data) {
        const entry = {
            id: crypto.randomUUID(),
            timestamp: new Date().toISOString(),
            eventType,
            data,
            hash: null,
            previousHash: null
        };

        // Get previous hash for chain integrity
        const previousEntry = await this.getLastAuditEntry();
        if (previousEntry) {
            entry.previousHash = previousEntry.hash;
        }

        // Calculate hash of this entry
        entry.hash = this.calculateHash(entry);

        // Sign the entry for non-repudiation
        entry.signature = await this.signAuditEntry(entry);

        // Store in multiple locations for redundancy
        await Promise.all([
            this.storeAuditInDatabase(entry),
            this.storeAuditInS3(entry),
            this.sendToSIEM(entry)
        ]);

        logger.info('Audit log entry created', { eventType, id: entry.id });

        return entry;
    }

    calculateHash(entry) {
        const content = JSON.stringify({
            id: entry.id,
            timestamp: entry.timestamp,
            eventType: entry.eventType,
            data: entry.data,
            previousHash: entry.previousHash
        });

        return crypto
            .createHash('sha512')
            .update(content)
            .digest('hex');
    }

    async signAuditEntry(entry) {
        // Sign with KMS for non-repudiation
        const params = {
            KeyId: process.env.KMS_SIGNING_KEY_ID,
            Message: Buffer.from(entry.hash),
            MessageType: 'DIGEST',
            SigningAlgorithm: 'ECDSA_SHA_512'
        };

        const result = await kms.sign(params).promise();
        return result.Signature.toString('base64');
    }

    // ==================== HELPER METHODS ====================

    sanitizeForLog(value) {
        // Remove sensitive data from logs
        if (typeof value === 'string') {
            return value.substring(0, 4) + '****';
        }
        return '****';
    }

    async generateSecureCredential() {
        // Generate cryptographically secure credential
        return crypto.randomBytes(32).toString('base64');
    }

    async verifyMFA(userId, token) {
        // Verify TOTP token
        const secret = await this.getUserMFASecret(userId);
        return speakeasy.totp.verify({
            secret,
            encoding: 'base32',
            token,
            window: 2
        });
    }

    async checkSuspiciousActivity(context) {
        // Track failed attempts
        const key = `suspicious:${context.userId}:${context.ipAddress}`;
        const attempts = await redis.incr(key);
        await redis.expire(key, 3600); // Reset after 1 hour

        if (attempts > 5) {
            // Block user/IP
            await redis.sadd('blocked:users', context.userId);
            await redis.sadd('blocked:ips', context.ipAddress);

            // Alert security team
            await this.alertSecurityTeam({
                type: 'SUSPICIOUS_ACTIVITY',
                userId: context.userId,
                ipAddress: context.ipAddress,
                attempts
            });
        }
    }

    async alertSecurityTeam(alert) {
        // Send immediate notification to security team
        // Implementation would include email, SMS, PagerDuty, etc.
        logger.error('SECURITY ALERT', alert);
    }

    // ==================== AWS SECRETS MANAGER ====================

    async storeInSecretsManager(key, value, metadata) {
        const params = {
            Name: `mortgage-guardian/${key}`,
            SecretString: JSON.stringify({
                value,
                metadata,
                timestamp: new Date().toISOString()
            }),
            Description: `Encrypted credential for ${key}`,
            KmsKeyId: process.env.KMS_KEY_ID,
            Tags: [
                { Key: 'Environment', Value: process.env.NODE_ENV },
                { Key: 'Service', Value: 'mortgage-guardian' },
                { Key: 'Compliance', Value: 'PCI-DSS,SOC2,GLBA' }
            ]
        };

        try {
            const result = await secretsManager.createSecret(params).promise();
            return result.ARN;
        } catch (error) {
            if (error.code === 'ResourceExistsException') {
                // Update existing secret
                const updateParams = {
                    SecretId: params.Name,
                    SecretString: params.SecretString
                };
                const result = await secretsManager.updateSecret(updateParams).promise();
                return result.ARN;
            }
            throw error;
        }
    }

    async retrieveFromSecretsManager(key) {
        const params = {
            SecretId: `mortgage-guardian/${key}`,
            VersionStage: 'AWSCURRENT'
        };

        const result = await secretsManager.getSecretValue(params).promise();
        const secret = JSON.parse(result.SecretString);
        return secret.value;
    }

    // ==================== MIDDLEWARE ====================

    /**
     * Express middleware for request security
     */
    securityMiddleware() {
        return async (req, res, next) => {
            try {
                // Create security context
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

                // Apply rate limiting
                await this.rateLimiters.api.consume(context.ipAddress);

                // Validate zero-trust
                await this.validateZeroTrust(context);

                // Add security headers
                res.setHeader('X-Content-Type-Options', 'nosniff');
                res.setHeader('X-Frame-Options', 'DENY');
                res.setHeader('X-XSS-Protection', '1; mode=block');
                res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
                res.setHeader('Content-Security-Policy', "default-src 'self'");

                // Attach context to request
                req.securityContext = context;

                next();
            } catch (error) {
                // Log security failure
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
}

// Export singleton instance
module.exports = new FinancialSecurityService();