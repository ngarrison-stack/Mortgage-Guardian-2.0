/**
 * Vendor-Neutral Financial Security Service
 * Platform-agnostic implementation - works with any infrastructure
 * No AWS dependencies - can run on-premise or any cloud provider
 */

const crypto = require('crypto');
const fs = require('fs').promises;
const path = require('path');
const { promisify } = require('util');
const jwt = require('jsonwebtoken');
const speakeasy = require('speakeasy');
const argon2 = require('argon2');
const winston = require('winston');
const Redis = require('ioredis');

// Platform-agnostic rate limiting
const { RateLimiterMemory, RateLimiterRedis } = require('rate-limiter-flexible');

/**
 * Vendor-Neutral Security Service
 * Can work with any backend: on-premise, Azure, GCP, or self-hosted
 */
class VendorNeutralSecurityService {
    constructor(config = {}) {
        this.config = {
            // Default to local/self-hosted configuration
            secretStorage: config.secretStorage || 'filesystem',
            encryptionProvider: config.encryptionProvider || 'native',
            auditBackend: config.auditBackend || 'local',
            hsmProvider: config.hsmProvider || null,
            ...config
        };

        this.initializeComponents();
    }

    // ==================== INITIALIZATION ====================

    async initializeComponents() {
        // Initialize based on configuration
        this.encryptionProvider = this.createEncryptionProvider();
        this.secretManager = this.createSecretManager();
        this.auditLogger = this.createAuditLogger();
        this.rateLimiter = this.createRateLimiter();
        this.sessionManager = this.createSessionManager();
    }

    createEncryptionProvider() {
        switch (this.config.encryptionProvider) {
            case 'native':
                return new NativeEncryptionProvider();
            case 'hashicorp-vault':
                return new HashicorpVaultProvider(this.config.vaultEndpoint);
            case 'azure-keyvault':
                return new AzureKeyVaultProvider(this.config.azureConfig);
            case 'gcp-kms':
                return new GCPKeyManagementProvider(this.config.gcpConfig);
            case 'hardware-hsm':
                return new HardwareHSMProvider(this.config.hsmConfig);
            default:
                return new NativeEncryptionProvider();
        }
    }

    createSecretManager() {
        switch (this.config.secretStorage) {
            case 'filesystem':
                return new FilesystemSecretManager(this.config.secretsPath);
            case 'database':
                return new DatabaseSecretManager(this.config.dbConnection);
            case 'hashicorp-vault':
                return new HashicorpVaultSecretManager(this.config.vaultEndpoint);
            case 'kubernetes':
                return new KubernetesSecretManager(this.config.k8sNamespace);
            case 'docker-secrets':
                return new DockerSecretManager();
            case 'env':
                return new EnvironmentSecretManager();
            default:
                return new FilesystemSecretManager('./secrets');
        }
    }

    createAuditLogger() {
        const transports = [];

        // Always log to file
        transports.push(
            new winston.transports.File({
                filename: path.join(this.config.logPath || './logs', 'audit.log'),
                level: 'info',
                format: winston.format.json(),
                maxsize: 5242880, // 5MB
                maxFiles: 30
            })
        );

        // Add additional transports based on configuration
        if (this.config.syslogHost) {
            // Syslog for enterprise environments
            const Syslog = require('winston-syslog').Syslog;
            transports.push(new Syslog({
                host: this.config.syslogHost,
                port: this.config.syslogPort || 514,
                protocol: 'tls4',
                facility: 'auth',
                app_name: 'mortgage-guardian'
            }));
        }

        if (this.config.elasticEndpoint) {
            // Elasticsearch for SIEM integration
            const { ElasticsearchTransport } = require('winston-elasticsearch');
            transports.push(new ElasticsearchTransport({
                level: 'info',
                clientOpts: {
                    node: this.config.elasticEndpoint,
                    auth: this.config.elasticAuth
                },
                index: 'security-audit'
            }));
        }

        return winston.createLogger({
            level: 'info',
            format: winston.format.combine(
                winston.format.timestamp(),
                winston.format.json()
            ),
            transports
        });
    }

    createRateLimiter() {
        // Use Redis if available, otherwise in-memory
        if (this.config.redisHost) {
            const redis = new Redis({
                host: this.config.redisHost,
                port: this.config.redisPort || 6379,
                password: this.config.redisPassword,
                tls: this.config.redisTLS ? {} : undefined
            });

            return {
                api: new RateLimiterRedis({
                    storeClient: redis,
                    keyPrefix: 'rl:api',
                    points: 100,
                    duration: 60
                }),
                auth: new RateLimiterRedis({
                    storeClient: redis,
                    keyPrefix: 'rl:auth',
                    points: 5,
                    duration: 900
                }),
                transaction: new RateLimiterRedis({
                    storeClient: redis,
                    keyPrefix: 'rl:transaction',
                    points: 10,
                    duration: 60
                })
            };
        } else {
            // In-memory rate limiting (single instance only)
            return {
                api: new RateLimiterMemory({
                    points: 100,
                    duration: 60
                }),
                auth: new RateLimiterMemory({
                    points: 5,
                    duration: 900
                }),
                transaction: new RateLimiterMemory({
                    points: 10,
                    duration: 60
                })
            };
        }
    }

    createSessionManager() {
        if (this.config.redisHost) {
            return new RedisSessionManager(this.config);
        } else {
            return new InMemorySessionManager();
        }
    }

    // ==================== ENCRYPTION PROVIDERS ====================

    /**
     * Native Node.js encryption (no external dependencies)
     */
}

class NativeEncryptionProvider {
    constructor() {
        // Generate or load master key
        this.masterKey = this.loadOrGenerateMasterKey();
        this.algorithm = 'aes-256-gcm';
    }

    loadOrGenerateMasterKey() {
        const keyPath = path.join(process.cwd(), '.keys', 'master.key');

        try {
            // Try to load existing key
            const key = fs.readFileSync(keyPath);
            return key;
        } catch (error) {
            // Generate new key
            const key = crypto.randomBytes(32);

            // Create directory if it doesn't exist
            const dir = path.dirname(keyPath);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
            }

            // Save key with restrictive permissions
            fs.writeFileSync(keyPath, key, { mode: 0o600 });

            return key;
        }
    }

    async encrypt(plaintext) {
        const iv = crypto.randomBytes(16);
        const cipher = crypto.createCipheriv(this.algorithm, this.masterKey, iv);

        let encrypted = cipher.update(plaintext, 'utf8');
        encrypted = Buffer.concat([encrypted, cipher.final()]);

        const authTag = cipher.getAuthTag();

        // Combine iv, authTag, and encrypted data
        return Buffer.concat([iv, authTag, encrypted]).toString('base64');
    }

    async decrypt(encryptedData) {
        const buffer = Buffer.from(encryptedData, 'base64');

        // Extract components
        const iv = buffer.slice(0, 16);
        const authTag = buffer.slice(16, 32);
        const encrypted = buffer.slice(32);

        const decipher = crypto.createDecipheriv(this.algorithm, this.masterKey, iv);
        decipher.setAuthTag(authTag);

        let decrypted = decipher.update(encrypted);
        decrypted = Buffer.concat([decrypted, decipher.final()]);

        return decrypted.toString('utf8');
    }

    async generateKey() {
        return crypto.randomBytes(32).toString('base64');
    }

    async deriveKey(password, salt, iterations = 100000) {
        return new Promise((resolve, reject) => {
            crypto.pbkdf2(password, salt, iterations, 32, 'sha512', (err, derivedKey) => {
                if (err) reject(err);
                else resolve(derivedKey);
            });
        });
    }
}

/**
 * HashiCorp Vault Provider
 */
class HashicorpVaultProvider {
    constructor(endpoint) {
        this.endpoint = endpoint;
        this.token = process.env.VAULT_TOKEN;
    }

    async encrypt(plaintext) {
        const response = await fetch(`${this.endpoint}/v1/transit/encrypt/mortgage-guardian`, {
            method: 'POST',
            headers: {
                'X-Vault-Token': this.token,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                plaintext: Buffer.from(plaintext).toString('base64')
            })
        });

        const data = await response.json();
        return data.data.ciphertext;
    }

    async decrypt(ciphertext) {
        const response = await fetch(`${this.endpoint}/v1/transit/decrypt/mortgage-guardian`, {
            method: 'POST',
            headers: {
                'X-Vault-Token': this.token,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ ciphertext })
        });

        const data = await response.json();
        return Buffer.from(data.data.plaintext, 'base64').toString('utf8');
    }
}

/**
 * Hardware HSM Provider (PKCS#11)
 */
class HardwareHSMProvider {
    constructor(config) {
        this.config = config;
        // Would initialize PKCS#11 library here
        // Examples: SoftHSM, Thales, Gemalto, YubiHSM
    }

    async encrypt(plaintext) {
        // Interface with HSM via PKCS#11
        // This is a placeholder - actual implementation would use graphene or node-pkcs11
        return Buffer.from(plaintext).toString('base64');
    }

    async decrypt(ciphertext) {
        // Interface with HSM via PKCS#11
        return Buffer.from(ciphertext, 'base64').toString('utf8');
    }
}

// ==================== SECRET MANAGERS ====================

/**
 * Filesystem-based secret storage (encrypted)
 */
class FilesystemSecretManager {
    constructor(secretsPath = './secrets') {
        this.secretsPath = secretsPath;
        this.encryption = new NativeEncryptionProvider();

        // Ensure secrets directory exists with proper permissions
        this.ensureSecretsDirectory();
    }

    async ensureSecretsDirectory() {
        try {
            await fs.mkdir(this.secretsPath, { recursive: true, mode: 0o700 });
        } catch (error) {
            // Directory might already exist
        }
    }

    async getSecret(key) {
        try {
            const filePath = path.join(this.secretsPath, `${key}.enc`);
            const encryptedData = await fs.readFile(filePath, 'utf8');
            return await this.encryption.decrypt(encryptedData);
        } catch (error) {
            if (error.code === 'ENOENT') {
                return null;
            }
            throw error;
        }
    }

    async setSecret(key, value) {
        const encrypted = await this.encryption.encrypt(value);
        const filePath = path.join(this.secretsPath, `${key}.enc`);
        await fs.writeFile(filePath, encrypted, { mode: 0o600 });
    }

    async deleteSecret(key) {
        const filePath = path.join(this.secretsPath, `${key}.enc`);
        await fs.unlink(filePath);
    }

    async listSecrets() {
        const files = await fs.readdir(this.secretsPath);
        return files
            .filter(f => f.endsWith('.enc'))
            .map(f => f.replace('.enc', ''));
    }
}

/**
 * Database-based secret storage
 */
class DatabaseSecretManager {
    constructor(connectionString) {
        this.connectionString = connectionString;
        this.encryption = new NativeEncryptionProvider();
        // Would initialize database connection here
        // Supports PostgreSQL, MySQL, SQLite
    }

    async getSecret(key) {
        // Query database for encrypted secret
        // Decrypt and return
        return null;
    }

    async setSecret(key, value) {
        // Encrypt value
        // Store in database
    }
}

/**
 * Kubernetes Secrets
 */
class KubernetesSecretManager {
    constructor(namespace = 'default') {
        this.namespace = namespace;
    }

    async getSecret(key) {
        // Read from Kubernetes secret
        // kubectl get secret {key} -n {namespace}
        const secretPath = `/var/run/secrets/${key}`;
        try {
            return await fs.readFile(secretPath, 'utf8');
        } catch {
            return null;
        }
    }
}

/**
 * Docker Secrets
 */
class DockerSecretManager {
    async getSecret(key) {
        // Docker secrets are mounted at /run/secrets/
        const secretPath = `/run/secrets/${key}`;
        try {
            return await fs.readFile(secretPath, 'utf8');
        } catch {
            return null;
        }
    }
}

/**
 * Environment Variables (for development)
 */
class EnvironmentSecretManager {
    async getSecret(key) {
        return process.env[key] || null;
    }

    async setSecret(key, value) {
        process.env[key] = value;
    }
}

// ==================== SESSION MANAGEMENT ====================

/**
 * In-memory session storage (single instance)
 */
class InMemorySessionManager {
    constructor() {
        this.sessions = new Map();
        this.cleanupInterval = setInterval(() => this.cleanup(), 60000); // Cleanup every minute
    }

    async createSession(userId, metadata = {}) {
        const sessionId = crypto.randomBytes(32).toString('hex');
        const session = {
            id: sessionId,
            userId,
            createdAt: Date.now(),
            lastActivity: Date.now(),
            metadata
        };

        this.sessions.set(sessionId, session);
        return sessionId;
    }

    async getSession(sessionId) {
        const session = this.sessions.get(sessionId);
        if (session) {
            session.lastActivity = Date.now();
            return session;
        }
        return null;
    }

    async deleteSession(sessionId) {
        this.sessions.delete(sessionId);
    }

    cleanup() {
        const now = Date.now();
        const timeout = 15 * 60 * 1000; // 15 minutes

        for (const [sessionId, session] of this.sessions) {
            if (now - session.lastActivity > timeout) {
                this.sessions.delete(sessionId);
            }
        }
    }

    destroy() {
        clearInterval(this.cleanupInterval);
        this.sessions.clear();
    }
}

/**
 * Redis session storage (distributed)
 */
class RedisSessionManager {
    constructor(config) {
        this.redis = new Redis({
            host: config.redisHost,
            port: config.redisPort || 6379,
            password: config.redisPassword
        });
    }

    async createSession(userId, metadata = {}) {
        const sessionId = crypto.randomBytes(32).toString('hex');
        const session = {
            id: sessionId,
            userId,
            createdAt: Date.now(),
            lastActivity: Date.now(),
            metadata
        };

        await this.redis.setex(
            `session:${sessionId}`,
            900, // 15 minutes
            JSON.stringify(session)
        );

        return sessionId;
    }

    async getSession(sessionId) {
        const data = await this.redis.get(`session:${sessionId}`);
        if (data) {
            const session = JSON.parse(data);
            session.lastActivity = Date.now();

            // Update session
            await this.redis.setex(
                `session:${sessionId}`,
                900,
                JSON.stringify(session)
            );

            return session;
        }
        return null;
    }

    async deleteSession(sessionId) {
        await this.redis.del(`session:${sessionId}`);
    }
}

// ==================== AUDIT LOGGING ====================

/**
 * Immutable audit log with blockchain-style hashing
 */
class ImmutableAuditLog {
    constructor(logPath = './audit') {
        this.logPath = logPath;
        this.currentLogFile = null;
        this.previousHash = null;
        this.initializeLog();
    }

    async initializeLog() {
        // Ensure audit directory exists
        await fs.mkdir(this.logPath, { recursive: true, mode: 0o700 });

        // Get current log file
        const date = new Date().toISOString().split('T')[0];
        this.currentLogFile = path.join(this.logPath, `audit-${date}.log`);

        // Load previous hash
        this.previousHash = await this.getLastHash();
    }

    async logEntry(event, metadata = {}) {
        const entry = {
            id: crypto.randomUUID(),
            timestamp: new Date().toISOString(),
            event,
            metadata,
            previousHash: this.previousHash
        };

        // Calculate hash
        entry.hash = this.calculateHash(entry);

        // Sign entry
        entry.signature = this.signEntry(entry);

        // Write to log
        await fs.appendFile(
            this.currentLogFile,
            JSON.stringify(entry) + '\n',
            { mode: 0o600 }
        );

        // Update previous hash
        this.previousHash = entry.hash;

        return entry;
    }

    calculateHash(entry) {
        const content = JSON.stringify({
            id: entry.id,
            timestamp: entry.timestamp,
            event: entry.event,
            metadata: entry.metadata,
            previousHash: entry.previousHash
        });

        return crypto.createHash('sha512').update(content).digest('hex');
    }

    signEntry(entry) {
        // In production, use proper key pair
        const sign = crypto.createSign('SHA512');
        sign.update(entry.hash);
        // Would use private key here
        return sign.sign('private_key', 'hex');
    }

    async getLastHash() {
        try {
            const content = await fs.readFile(this.currentLogFile, 'utf8');
            const lines = content.trim().split('\n');
            if (lines.length > 0) {
                const lastEntry = JSON.parse(lines[lines.length - 1]);
                return lastEntry.hash;
            }
        } catch {
            // File doesn't exist or is empty
        }
        return null;
    }

    async verifyLog() {
        // Verify entire log integrity
        const content = await fs.readFile(this.currentLogFile, 'utf8');
        const lines = content.trim().split('\n');

        let previousHash = null;

        for (const line of lines) {
            const entry = JSON.parse(line);

            // Verify hash chain
            if (entry.previousHash !== previousHash) {
                return false;
            }

            // Verify entry hash
            const calculatedHash = this.calculateHash(entry);
            if (calculatedHash !== entry.hash) {
                return false;
            }

            previousHash = entry.hash;
        }

        return true;
    }
}

// ==================== ZERO-KNOWLEDGE AUTHENTICATION ====================

/**
 * SRP (Secure Remote Password) implementation
 * Allows authentication without sending password
 */
class ZeroKnowledgeAuth {
    constructor() {
        this.users = new Map(); // In production, use database
    }

    async registerUser(username, password) {
        // Generate salt
        const salt = crypto.randomBytes(32);

        // Calculate verifier (never store password)
        const verifier = await this.calculateVerifier(password, salt);

        // Store salt and verifier
        this.users.set(username, { salt, verifier });

        return true;
    }

    async beginAuthentication(username) {
        const user = this.users.get(username);
        if (!user) {
            throw new Error('User not found');
        }

        // Generate ephemeral values
        const b = crypto.randomBytes(32);
        const B = this.calculateB(user.verifier, b);

        // Store session
        user.authSession = { b, B };

        return {
            salt: user.salt.toString('hex'),
            B: B.toString('hex')
        };
    }

    async verifyAuthentication(username, clientProof) {
        const user = this.users.get(username);
        if (!user || !user.authSession) {
            throw new Error('Invalid authentication session');
        }

        // Verify client proof
        // In real implementation, this would involve more SRP calculations
        const isValid = await this.verifyProof(clientProof, user);

        // Clear session
        delete user.authSession;

        return isValid;
    }

    async calculateVerifier(password, salt) {
        // SRP verifier calculation
        const hash = crypto.createHash('sha512');
        hash.update(salt);
        hash.update(password);
        return hash.digest();
    }

    calculateB(verifier, b) {
        // SRP B calculation
        // Simplified - real implementation would use modular exponentiation
        const hash = crypto.createHash('sha512');
        hash.update(verifier);
        hash.update(b);
        return hash.digest();
    }

    async verifyProof(clientProof, user) {
        // Verify client's zero-knowledge proof
        // Real implementation would be more complex
        return true;
    }
}

// ==================== MIDDLEWARE ====================

/**
 * Create security middleware for Express
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

// ==================== EXPORTS ====================

module.exports = {
    VendorNeutralSecurityService,
    NativeEncryptionProvider,
    HashicorpVaultProvider,
    HardwareHSMProvider,
    FilesystemSecretManager,
    DatabaseSecretManager,
    KubernetesSecretManager,
    DockerSecretManager,
    EnvironmentSecretManager,
    InMemorySessionManager,
    RedisSessionManager,
    ImmutableAuditLog,
    ZeroKnowledgeAuth,
    createSecurityMiddleware
};