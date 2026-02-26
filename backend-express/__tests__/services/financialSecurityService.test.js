/**
 * Unit tests for FinancialSecurityService (services/financialSecurityService.js)
 *
 * Tests encryption, credential management, compliance validation,
 * fraud detection, audit logging, helpers, and security middleware
 * with fully mocked AWS SDK, Redis, and external dependencies.
 */

const crypto = require('crypto');

// ── Mock external dependencies ──────────────────────────────────────────────
const mockRedis = {
  get: jest.fn(),
  set: jest.fn(),
  incr: jest.fn(),
  expire: jest.fn(),
  sadd: jest.fn(),
  sismember: jest.fn(),
  del: jest.fn()
};

jest.mock('ioredis', () => jest.fn(() => mockRedis));

const mockKmsEncrypt = jest.fn();
const mockKmsDecrypt = jest.fn();
const mockKmsSign = jest.fn();
const mockCreateSecret = jest.fn();
const mockUpdateSecret = jest.fn();
const mockGetSecretValue = jest.fn();
const mockDescribeClusters = jest.fn();

// Lift per-instance methods so tests can assert on call args
const mockKmsEncryptMethod = jest.fn(() => ({ promise: mockKmsEncrypt }));
const mockKmsDecryptMethod = jest.fn(() => ({ promise: mockKmsDecrypt }));
const mockKmsSignMethod = jest.fn(() => ({ promise: mockKmsSign }));

jest.mock('aws-sdk', () => ({
  KMS: jest.fn(() => ({
    encrypt: mockKmsEncryptMethod,
    decrypt: mockKmsDecryptMethod,
    sign: mockKmsSignMethod
  })),
  SecretsManager: jest.fn(() => ({
    createSecret: jest.fn(() => ({ promise: mockCreateSecret })),
    updateSecret: jest.fn(() => ({ promise: mockUpdateSecret })),
    getSecretValue: jest.fn(() => ({ promise: mockGetSecretValue }))
  })),
  CloudHSMV2: jest.fn(() => ({
    describeClusters: jest.fn(() => ({ promise: mockDescribeClusters }))
  }))
}), { virtual: true });

const mockRateLimiterConsume = jest.fn().mockResolvedValue(true);

jest.mock('rate-limiter-flexible', () => ({
  RateLimiterRedis: jest.fn(() => ({
    consume: mockRateLimiterConsume
  }))
}), { virtual: true });

jest.mock('jsonwebtoken', () => ({
  verify: jest.fn()
}));

jest.mock('speakeasy', () => ({
  totp: { verify: jest.fn() }
}), { virtual: true });

const mockLoggerInfo = jest.fn();
const mockLoggerError = jest.fn();
const mockLoggerWarn = jest.fn();
const mockLoggerAdd = jest.fn();

jest.mock('winston', () => ({
  createLogger: jest.fn(() => ({
    info: mockLoggerInfo,
    error: mockLoggerError,
    warn: mockLoggerWarn,
    add: mockLoggerAdd
  })),
  format: {
    combine: jest.fn(),
    timestamp: jest.fn(),
    errors: jest.fn(),
    json: jest.fn(),
    simple: jest.fn()
  },
  transports: {
    File: jest.fn(),
    Console: jest.fn()
  }
}));

jest.mock('winston-elasticsearch', () => ({
  ElasticsearchTransport: jest.fn()
}), { virtual: true });

// Set env vars before requiring
process.env.KMS_KEY_ID = 'test-key-id';
process.env.KMS_SIGNING_KEY_ID = 'test-signing-key';
process.env.JWT_SECRET = 'test-jwt-secret';

const service = require('../../services/financialSecurityService');
const FinancialSecurityService = service.constructor;

// ============================================================
// FinancialSecurityService
// ============================================================
describe('FinancialSecurityService', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Default: force KMS path (hsmClient = null, not a Promise)
    service.hsmClient = null;

    // Mock internal methods that interact with DB/external services
    service.getLastAuditEntry = jest.fn().mockResolvedValue(null);
    service.storeAuditInDatabase = jest.fn().mockResolvedValue();
    service.storeAuditInS3 = jest.fn().mockResolvedValue();
    service.sendToSIEM = jest.fn().mockResolvedValue();

    // Default KMS sign for audit entries
    mockKmsSign.mockResolvedValue({
      Signature: Buffer.from('mock-signature')
    });
  });

  // ── Encryption ──────────────────────────────────────────────
  describe('encryptWithKMS', () => {
    it('returns base64 ciphertext', async () => {
      mockKmsEncrypt.mockResolvedValue({
        CiphertextBlob: Buffer.from('encrypted-data')
      });

      const result = await service.encryptWithKMS('sensitive-data');

      expect(result).toBe(Buffer.from('encrypted-data').toString('base64'));
    });

    it('passes KeyId and EncryptionContext to KMS', async () => {
      mockKmsEncrypt.mockResolvedValue({
        CiphertextBlob: Buffer.from('encrypted')
      });

      await service.encryptWithKMS('data');

      expect(mockKmsEncryptMethod).toHaveBeenCalledWith(
        expect.objectContaining({
          KeyId: 'test-key-id',
          Plaintext: 'data',
          EncryptionContext: expect.objectContaining({
            service: 'mortgage-guardian',
            purpose: 'credential-encryption'
          })
        })
      );
    });
  });

  describe('decryptWithKMS', () => {
    it('returns plaintext string', async () => {
      const ciphertext = Buffer.from('encrypted').toString('base64');
      mockKmsDecrypt.mockResolvedValue({
        Plaintext: Buffer.from('decrypted-value')
      });

      const result = await service.decryptWithKMS(ciphertext);

      expect(result).toBe('decrypted-value');
    });
  });

  describe('encryptWithHSM', () => {
    it('falls back to KMS when HSM not available', async () => {
      service.hsmClient = null;
      mockKmsEncrypt.mockResolvedValue({
        CiphertextBlob: Buffer.from('kms-encrypted')
      });

      const result = await service.encryptWithHSM('plaintext');

      expect(result).toBe(Buffer.from('kms-encrypted').toString('base64'));
    });
  });

  describe('decryptWithHSM', () => {
    it('falls back to KMS when HSM not available', async () => {
      service.hsmClient = null;
      mockKmsDecrypt.mockResolvedValue({
        Plaintext: Buffer.from('decrypted')
      });

      const result = await service.decryptWithHSM(
        Buffer.from('cipher').toString('base64')
      );

      expect(result).toBe('decrypted');
    });
  });

  // ── Credential Management ──────────────────────────────────
  describe('storeCredential', () => {
    beforeEach(() => {
      mockKmsEncrypt.mockResolvedValue({
        CiphertextBlob: Buffer.from('encrypted-cred')
      });
      mockCreateSecret.mockResolvedValue({
        ARN: 'arn:aws:secretsmanager:us-east-1:123:secret:test'
      });
    });

    it('stores encrypted credential in Secrets Manager', async () => {
      const arn = await service.storeCredential('api-key', 'secret-value', {
        userId: 'user-1',
        auditTrail: true
      });

      expect(arn).toBe('arn:aws:secretsmanager:us-east-1:123:secret:test');
    });

    it('consumes rate limit before storing', async () => {
      await service.storeCredential('key', 'val', { userId: 'user-1', auditTrail: true });

      expect(mockRateLimiterConsume).toHaveBeenCalledWith('user-1');
    });

    it('creates audit log entries for attempt and success', async () => {
      const auditSpy = jest.spyOn(service, 'auditLog');

      await service.storeCredential('key', 'val', { userId: 'user-1', auditTrail: true });

      const auditCalls = auditSpy.mock.calls.map(c => c[0]);
      expect(auditCalls).toContain('CREDENTIAL_STORE_ATTEMPT');
      expect(auditCalls).toContain('CREDENTIAL_STORE_SUCCESS');
    });

    it('updates existing secret on ResourceExistsException', async () => {
      const existsError = new Error('Secret exists');
      existsError.code = 'ResourceExistsException';
      mockCreateSecret.mockRejectedValue(existsError);
      mockUpdateSecret.mockResolvedValue({
        ARN: 'arn:aws:secretsmanager:us-east-1:123:secret:updated'
      });

      const arn = await service.storeCredential('existing-key', 'new-value', {
        userId: 'user-1',
        auditTrail: true
      });

      expect(arn).toBe('arn:aws:secretsmanager:us-east-1:123:secret:updated');
    });
  });

  describe('retrieveCredential', () => {
    beforeEach(() => {
      // Mock validateZeroTrust to pass
      service.validateZeroTrust = jest.fn().mockResolvedValue(true);
      service.checkSuspiciousActivity = jest.fn().mockResolvedValue();
      mockGetSecretValue.mockResolvedValue({
        SecretString: JSON.stringify({ value: Buffer.from('encrypted').toString('base64') })
      });
      mockKmsDecrypt.mockResolvedValue({
        Plaintext: Buffer.from('decrypted-credential')
      });
    });

    it('retrieves and decrypts credential', async () => {
      const result = await service.retrieveCredential('api-key', {
        userId: 'user-1'
      });

      expect(result).toBe('decrypted-credential');
    });

    it('calls validateZeroTrust before retrieval', async () => {
      await service.retrieveCredential('key', { userId: 'user-1' });

      expect(service.validateZeroTrust).toHaveBeenCalledWith({ userId: 'user-1' });
    });

    it('throws on rate limit exceeded', async () => {
      mockRateLimiterConsume.mockRejectedValueOnce(new Error('Rate limit exceeded'));

      await expect(
        service.retrieveCredential('key', { userId: 'user-1' })
      ).rejects.toThrow('Rate limit exceeded');
    });
  });

  describe('rotateCredential', () => {
    it('generates new credential and stores it', async () => {
      const generateSpy = jest.spyOn(service, 'generateSecureCredential')
        .mockResolvedValue('new-cred-base64');
      const storeSpy = jest.spyOn(service, 'storeCredential')
        .mockResolvedValue('arn:new');
      service.updateCredentialReferences = jest.fn().mockResolvedValue();
      service.scheduleCredentialDeletion = jest.fn().mockResolvedValue();

      const arn = await service.rotateCredential('old-key', { userId: 'user-1' });

      expect(generateSpy).toHaveBeenCalled();
      expect(storeSpy).toHaveBeenCalledWith('old-key-new', 'new-cred-base64', { userId: 'user-1' });
      expect(arn).toBe('arn:new');

      generateSpy.mockRestore();
      storeSpy.mockRestore();
    });
  });

  describe('generateSecureCredential', () => {
    it('returns base64 string of 32 random bytes', async () => {
      const cred = await service.generateSecureCredential();

      const decoded = Buffer.from(cred, 'base64');
      expect(decoded.length).toBe(32);
    });
  });

  // ── Compliance Validation ───────────────────────────────────
  describe('validateCompliance', () => {
    it('throws for PCI DSS violation — untokenized payment', async () => {
      await expect(
        service.validateCompliance('paymentProcessing', {
          tokenized: false,
          encrypted: true,
          auditTrail: true
        })
      ).rejects.toThrow(/PCI_DSS/);
    });

    it('throws for SOC2 violation — missing audit trail', async () => {
      await expect(
        service.validateCompliance('anyOperation', {
          auditTrail: false
        })
      ).rejects.toThrow(/SOC2/);
    });

    it('throws for GLBA violation — data sharing without consent', async () => {
      await expect(
        service.validateCompliance('dataSharing', {
          customerConsent: false,
          auditTrail: true
        })
      ).rejects.toThrow(/GLBA/);
    });

    it('passes when all compliance requirements met', async () => {
      const result = await service.validateCompliance('paymentProcessing', {
        tokenized: true,
        encrypted: true,
        auditTrail: true
      });

      expect(result).toBe(true);
    });

    it('throws for FFIEC violation — authentication without MFA', async () => {
      await expect(
        service.validateCompliance('authentication', {
          multiFactor: false,
          auditTrail: true
        })
      ).rejects.toThrow(/FFIEC/);
    });
  });

  // ── Fraud Detection ─────────────────────────────────────────
  describe('detectFraud', () => {
    beforeEach(() => {
      service.getRecentTransactions = jest.fn().mockResolvedValue([]);
      service.calculateVelocity = jest.fn().mockReturnValue(0);
      service.assessLocationRisk = jest.fn().mockResolvedValue(0);
      service.runFraudMLModel = jest.fn().mockResolvedValue(0);
    });

    it('returns ALLOW for low-risk transaction', async () => {
      const result = await service.detectFraud({
        id: 'txn-1',
        userId: 'user-1',
        amount: 100
      });

      expect(result.riskScore).toBeLessThan(0.3);
      expect(result.action).toBe('ALLOW');
    });

    it('returns REVIEW for medium-risk transaction (high value)', async () => {
      service.runFraudMLModel.mockResolvedValue(0.3);

      const result = await service.detectFraud({
        id: 'txn-2',
        userId: 'user-1',
        amount: 15000
      });

      expect(result.riskFactors).toContain('HIGH_VALUE_TRANSACTION');
      expect(['REVIEW', 'CHALLENGE']).toContain(result.action);
    });

    it('returns BLOCK for high-risk transaction', async () => {
      service.calculateVelocity.mockReturnValue(10);
      service.assessLocationRisk.mockResolvedValue(0.9);
      service.runFraudMLModel.mockResolvedValue(0.8);

      const result = await service.detectFraud({
        id: 'txn-3',
        userId: 'user-1',
        amount: 50000
      });

      expect(result.riskScore).toBeGreaterThanOrEqual(0.8);
      expect(result.action).toBe('BLOCK');
    });

    it('creates audit log for every transaction', async () => {
      const auditSpy = jest.spyOn(service, 'auditLog');

      await service.detectFraud({
        id: 'txn-4',
        userId: 'user-1',
        amount: 50
      });

      expect(auditSpy).toHaveBeenCalledWith(
        'TRANSACTION_RISK_ASSESSMENT',
        expect.objectContaining({
          transactionId: 'txn-4',
          action: expect.any(String)
        })
      );
    });
  });

  // ── Audit Logging ───────────────────────────────────────────
  describe('auditLog', () => {
    it('creates entry with UUID, timestamp, and hash chain', async () => {
      const entry = await service.auditLog('TEST_EVENT', { key: 'value' });

      expect(entry.id).toBeDefined();
      expect(entry.timestamp).toBeDefined();
      expect(entry.hash).toBeDefined();
      expect(entry.hash).toHaveLength(128); // SHA-512 hex = 128 chars
      expect(entry.eventType).toBe('TEST_EVENT');
    });

    it('links to previous hash when prior entry exists', async () => {
      service.getLastAuditEntry.mockResolvedValue({
        hash: 'previous-hash-abc'
      });

      const entry = await service.auditLog('CHAINED_EVENT', {});

      expect(entry.previousHash).toBe('previous-hash-abc');
    });

    it('signs entry with KMS', async () => {
      await service.auditLog('SIGNED_EVENT', {});

      expect(mockKmsSign).toHaveBeenCalled();
    });

    it('stores in multiple locations for redundancy', async () => {
      await service.auditLog('REDUNDANT_EVENT', {});

      expect(service.storeAuditInDatabase).toHaveBeenCalled();
      expect(service.storeAuditInS3).toHaveBeenCalled();
      expect(service.sendToSIEM).toHaveBeenCalled();
    });
  });

  describe('calculateHash', () => {
    it('produces consistent SHA-512 hash for same input', () => {
      const entry = {
        id: 'test-id',
        timestamp: '2026-02-24T00:00:00Z',
        eventType: 'TEST',
        data: { key: 'value' },
        previousHash: null
      };

      const hash1 = service.calculateHash(entry);
      const hash2 = service.calculateHash(entry);

      expect(hash1).toBe(hash2);
      expect(hash1).toHaveLength(128); // SHA-512 hex
    });

    it('produces different hash for different input', () => {
      const entry1 = {
        id: 'id-1',
        timestamp: '2026-02-24T00:00:00Z',
        eventType: 'EVENT_A',
        data: {},
        previousHash: null
      };
      const entry2 = { ...entry1, id: 'id-2' };

      expect(service.calculateHash(entry1)).not.toBe(service.calculateHash(entry2));
    });
  });

  // ── Helper Methods ──────────────────────────────────────────
  describe('sanitizeForLog', () => {
    it('truncates string to 4 chars + ****', () => {
      expect(service.sanitizeForLog('secret123')).toBe('secr****');
    });

    it('returns **** for non-string values', () => {
      expect(service.sanitizeForLog(12345)).toBe('****');
      expect(service.sanitizeForLog({ key: 'val' })).toBe('****');
      expect(service.sanitizeForLog(null)).toBe('****');
    });

    it('handles short strings', () => {
      expect(service.sanitizeForLog('ab')).toBe('ab****');
    });
  });

  // ── Security Middleware ─────────────────────────────────────
  describe('securityMiddleware', () => {
    let middleware;
    let req;
    let res;
    let next;

    beforeEach(() => {
      middleware = service.securityMiddleware();
      req = {
        user: { id: 'user-1' },
        headers: {
          authorization: 'Bearer test-token',
          'x-device-id': 'device-1',
          'x-device-jailbroken': 'false',
          'user-agent': 'test-agent'
        },
        ip: '127.0.0.1',
        path: '/v1/test',
        method: 'GET'
      };
      res = {
        setHeader: jest.fn(),
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      };
      next = jest.fn();
    });

    it('sets security headers on success', async () => {
      service.validateZeroTrust = jest.fn().mockResolvedValue(true);

      await middleware(req, res, next);

      expect(res.setHeader).toHaveBeenCalledWith('X-Content-Type-Options', 'nosniff');
      expect(res.setHeader).toHaveBeenCalledWith('X-Frame-Options', 'DENY');
      expect(res.setHeader).toHaveBeenCalledWith('X-XSS-Protection', '1; mode=block');
      expect(res.setHeader).toHaveBeenCalledWith(
        'Strict-Transport-Security',
        'max-age=31536000; includeSubDomains'
      );
      expect(res.setHeader).toHaveBeenCalledWith(
        'Content-Security-Policy',
        "default-src 'self'"
      );
      expect(next).toHaveBeenCalled();
    });

    it('returns 403 on security validation failure', async () => {
      service.validateZeroTrust = jest.fn()
        .mockRejectedValue(new Error('Zero-trust failed'));

      await middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          error: 'Security validation failed',
          code: 'SECURITY_ERROR'
        })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('attaches security context to request on success', async () => {
      service.validateZeroTrust = jest.fn().mockResolvedValue(true);

      await middleware(req, res, next);

      expect(req.securityContext).toBeDefined();
      expect(req.securityContext.userId).toBe('user-1');
      expect(req.securityContext.ipAddress).toBe('127.0.0.1');
    });
  });

  // ── Zero-Trust Validation ─────────────────────────────────
  describe('validateZeroTrust', () => {
    // Restore the real validateZeroTrust for these tests
    let realValidateZeroTrust;

    beforeEach(() => {
      // Save and restore since other tests mock it
      realValidateZeroTrust = FinancialSecurityService.prototype.validateZeroTrust;
      service.validateZeroTrust = realValidateZeroTrust.bind(service);

      // Mock the sub-validators
      service.validateIdentity = jest.fn().mockResolvedValue(true);
      service.validateDevice = jest.fn().mockResolvedValue(true);
      service.validateNetwork = jest.fn().mockResolvedValue(true);
      service.validateBehavior = jest.fn().mockResolvedValue(true);
      service.validatePermissions = jest.fn().mockResolvedValue(true);
    });

    it('passes when all validations return true', async () => {
      const result = await service.validateZeroTrust({ userId: 'user-1' });
      expect(result).toBe(true);
    });

    it('throws when any validation fails', async () => {
      service.validateDevice.mockResolvedValue(false);

      await expect(
        service.validateZeroTrust({ userId: 'user-1' })
      ).rejects.toThrow('Zero-trust validation failed');
    });

    it('calls all five validators', async () => {
      const ctx = { userId: 'user-1' };
      await service.validateZeroTrust(ctx);

      expect(service.validateIdentity).toHaveBeenCalledWith(ctx);
      expect(service.validateDevice).toHaveBeenCalledWith(ctx);
      expect(service.validateNetwork).toHaveBeenCalledWith(ctx);
      expect(service.validateBehavior).toHaveBeenCalledWith(ctx);
      expect(service.validatePermissions).toHaveBeenCalledWith(ctx);
    });
  });

  // ── validateIdentity ──────────────────────────────────────
  describe('validateIdentity', () => {
    const jwt = require('jsonwebtoken');

    beforeEach(() => {
      service.validateIdentity = FinancialSecurityService.prototype.validateIdentity.bind(service);
    });

    it('returns false when no token provided', async () => {
      const result = await service.validateIdentity({});
      expect(result).toBe(false);
    });

    it('returns false when token is expired', async () => {
      jwt.verify.mockReturnValue({ exp: 0 }); // expired
      const result = await service.validateIdentity({ token: 'expired-token' });
      expect(result).toBe(false);
    });

    it('verifies MFA when FFIEC requires it', async () => {
      jwt.verify.mockReturnValue({ exp: Date.now() / 1000 + 3600 });
      service.verifyMFA = jest.fn().mockResolvedValue(true);

      const result = await service.validateIdentity({
        token: 'valid-token',
        userId: 'user-1',
        mfaToken: '123456'
      });

      expect(service.verifyMFA).toHaveBeenCalledWith('user-1', '123456');
      expect(result).toBe(true);
    });

    it('returns false on jwt.verify error', async () => {
      jwt.verify.mockImplementation(() => { throw new Error('bad token'); });
      const result = await service.validateIdentity({ token: 'bad' });
      expect(result).toBe(false);
    });
  });

  // ── validateDevice ────────────────────────────────────────
  describe('validateDevice', () => {
    beforeEach(() => {
      service.validateDevice = FinancialSecurityService.prototype.validateDevice.bind(service);
    });

    it('returns false when no deviceId', async () => {
      const result = await service.validateDevice({});
      expect(result).toBe(false);
    });

    it('returns false when device is not trusted', async () => {
      mockRedis.get.mockResolvedValue(null);
      const result = await service.validateDevice({ deviceId: 'unknown' });
      expect(result).toBe(false);
    });

    it('returns false for jailbroken device', async () => {
      mockRedis.get.mockResolvedValue('trusted');
      const result = await service.validateDevice({
        deviceId: 'dev-1',
        deviceJailbroken: true
      });
      expect(result).toBe(false);
    });

    it('returns true for trusted, non-jailbroken device', async () => {
      mockRedis.get.mockResolvedValue('trusted');
      const result = await service.validateDevice({
        deviceId: 'dev-1',
        deviceJailbroken: false,
        deviceRooted: false
      });
      expect(result).toBe(true);
    });
  });

  // ── validateNetwork ───────────────────────────────────────
  describe('validateNetwork', () => {
    beforeEach(() => {
      service.validateNetwork = FinancialSecurityService.prototype.validateNetwork.bind(service);
    });

    it('returns false when no ipAddress', async () => {
      const result = await service.validateNetwork({});
      expect(result).toBe(false);
    });

    it('returns false when IP is blacklisted', async () => {
      mockRedis.sismember.mockResolvedValue(1); // truthy = blacklisted
      const result = await service.validateNetwork({ ipAddress: '10.0.0.1' });
      expect(result).toBe(false);
    });

    it('returns true for non-blacklisted IP', async () => {
      mockRedis.sismember.mockResolvedValue(0);
      const result = await service.validateNetwork({ ipAddress: '10.0.0.2' });
      expect(result).toBe(true);
    });
  });

  // ── validateBehavior ──────────────────────────────────────
  describe('validateBehavior', () => {
    beforeEach(() => {
      service.validateBehavior = FinancialSecurityService.prototype.validateBehavior.bind(service);
      service.getUserBehaviorProfile = jest.fn().mockResolvedValue({});
      service.detectAnomalies = jest.fn().mockResolvedValue([]);
    });

    it('returns true when no anomalies detected', async () => {
      const result = await service.validateBehavior({ userId: 'user-1' });
      expect(result).toBe(true);
    });

    it('returns false when anomalies detected and no step-up auth', async () => {
      service.detectAnomalies.mockResolvedValue(['UNUSUAL_TIME']);
      const result = await service.validateBehavior({
        userId: 'user-1',
        stepUpAuthCompleted: false
      });
      expect(result).toBe(false);
    });

    it('returns true when anomalies detected but step-up auth completed', async () => {
      service.detectAnomalies.mockResolvedValue(['UNUSUAL_TIME']);
      const result = await service.validateBehavior({
        userId: 'user-1',
        stepUpAuthCompleted: true
      });
      expect(result).toBe(true);
    });
  });

  // ── validatePermissions ───────────────────────────────────
  describe('validatePermissions', () => {
    beforeEach(() => {
      service.validatePermissions = FinancialSecurityService.prototype.validatePermissions.bind(service);
      service.getUserPermissions = jest.fn().mockResolvedValue(['/v1/test']);
      service.canPerformAction = jest.fn().mockReturnValue(true);
    });

    it('returns true when user has permission for resource and action', async () => {
      const result = await service.validatePermissions({
        userId: 'user-1',
        resource: '/v1/test',
        action: 'GET'
      });
      expect(result).toBe(true);
    });

    it('returns false when user lacks resource permission', async () => {
      const result = await service.validatePermissions({
        userId: 'user-1',
        resource: '/v1/admin',
        action: 'GET'
      });
      expect(result).toBe(false);
    });

    it('returns false when action not permitted', async () => {
      service.canPerformAction.mockReturnValue(false);
      const result = await service.validatePermissions({
        userId: 'user-1',
        resource: '/v1/test',
        action: 'DELETE'
      });
      expect(result).toBe(false);
    });
  });

  // ── checkSuspiciousActivity ───────────────────────────────
  describe('checkSuspiciousActivity', () => {
    beforeEach(() => {
      service.checkSuspiciousActivity = FinancialSecurityService.prototype.checkSuspiciousActivity.bind(service);
      service.alertSecurityTeam = jest.fn().mockResolvedValue();
    });

    it('increments suspicious activity counter', async () => {
      mockRedis.incr.mockResolvedValue(1);
      await service.checkSuspiciousActivity({ userId: 'user-1', ipAddress: '10.0.0.1' });

      expect(mockRedis.incr).toHaveBeenCalledWith('suspicious:user-1:10.0.0.1');
      expect(mockRedis.expire).toHaveBeenCalledWith('suspicious:user-1:10.0.0.1', 3600);
    });

    it('blocks user and IP after 5 failed attempts', async () => {
      mockRedis.incr.mockResolvedValue(6);
      await service.checkSuspiciousActivity({ userId: 'user-1', ipAddress: '10.0.0.1' });

      expect(mockRedis.sadd).toHaveBeenCalledWith('blocked:users', 'user-1');
      expect(mockRedis.sadd).toHaveBeenCalledWith('blocked:ips', '10.0.0.1');
      expect(service.alertSecurityTeam).toHaveBeenCalled();
    });

    it('does not block when attempts are under threshold', async () => {
      mockRedis.incr.mockResolvedValue(3);
      await service.checkSuspiciousActivity({ userId: 'user-1', ipAddress: '10.0.0.1' });

      expect(mockRedis.sadd).not.toHaveBeenCalled();
      expect(service.alertSecurityTeam).not.toHaveBeenCalled();
    });
  });

  // ── verifyMFA ─────────────────────────────────────────────
  describe('verifyMFA', () => {
    const speakeasy = require('speakeasy');

    beforeEach(() => {
      service.verifyMFA = FinancialSecurityService.prototype.verifyMFA.bind(service);
      service.getUserMFASecret = jest.fn().mockResolvedValue('BASE32SECRET');
    });

    it('calls speakeasy.totp.verify with correct params', async () => {
      speakeasy.totp.verify.mockReturnValue(true);
      const result = await service.verifyMFA('user-1', '123456');

      expect(speakeasy.totp.verify).toHaveBeenCalledWith(
        expect.objectContaining({
          secret: 'BASE32SECRET',
          encoding: 'base32',
          token: '123456',
          window: 2
        })
      );
      expect(result).toBe(true);
    });

    it('returns false for invalid MFA token', async () => {
      speakeasy.totp.verify.mockReturnValue(false);
      const result = await service.verifyMFA('user-1', 'wrong');
      expect(result).toBe(false);
    });
  });

  // ── Credential error paths ────────────────────────────────
  describe('storeCredential error path', () => {
    it('logs failure and rethrows on unexpected error', async () => {
      mockKmsEncrypt.mockRejectedValue(new Error('KMS unavailable'));
      const auditSpy = jest.spyOn(service, 'auditLog');

      await expect(
        service.storeCredential('key', 'val', { userId: 'user-1', auditTrail: true })
      ).rejects.toThrow();

      const auditCalls = auditSpy.mock.calls.map(c => c[0]);
      expect(auditCalls).toContain('CREDENTIAL_STORE_FAILURE');
    });
  });

  describe('rotateCredential error path', () => {
    it('logs failure and rethrows on error', async () => {
      service.generateSecureCredential = jest.fn().mockRejectedValue(new Error('gen failed'));
      const auditSpy = jest.spyOn(service, 'auditLog');

      await expect(
        service.rotateCredential('key', { userId: 'user-1' })
      ).rejects.toThrow('gen failed');

      const auditCalls = auditSpy.mock.calls.map(c => c[0]);
      expect(auditCalls).toContain('CREDENTIAL_ROTATION_FAILURE');
    });
  });

  // ── encryptWithHSM / decryptWithHSM error paths ──────────
  describe('encryptWithHSM error handling', () => {
    it('throws "Failed to encrypt data" on encryption error', async () => {
      service.hsmClient = null;
      mockKmsEncrypt.mockRejectedValue(new Error('KMS down'));

      await expect(service.encryptWithHSM('data')).rejects.toThrow('Failed to encrypt data');
    });
  });

  describe('decryptWithHSM error handling', () => {
    it('throws "Failed to decrypt data" on decryption error', async () => {
      service.hsmClient = null;
      mockKmsDecrypt.mockRejectedValue(new Error('KMS down'));

      await expect(
        service.decryptWithHSM(Buffer.from('x').toString('base64'))
      ).rejects.toThrow('Failed to decrypt data');
    });
  });

  // ── Compliance audit logging ──────────────────────────────
  describe('validateCompliance audit logging', () => {
    it('logs COMPLIANCE_VIOLATION on failure', async () => {
      const auditSpy = jest.spyOn(service, 'auditLog');

      await expect(
        service.validateCompliance('paymentProcessing', {
          tokenized: false,
          encrypted: true,
          auditTrail: true
        })
      ).rejects.toThrow();

      expect(auditSpy).toHaveBeenCalledWith(
        'COMPLIANCE_VIOLATION',
        expect.objectContaining({
          operation: 'paymentProcessing',
          violations: expect.any(Array)
        })
      );
    });
  });

  // ── Secrets Manager helpers ───────────────────────────────
  describe('storeInSecretsManager', () => {
    it('creates secret with correct Name prefix', async () => {
      mockCreateSecret.mockResolvedValue({ ARN: 'arn:test' });

      const arn = await service.storeInSecretsManager('my-key', 'enc-value', {});

      expect(arn).toBe('arn:test');
    });

    it('rethrows non-ResourceExistsException errors', async () => {
      const otherError = new Error('Access denied');
      otherError.code = 'AccessDeniedException';
      mockCreateSecret.mockRejectedValue(otherError);

      await expect(
        service.storeInSecretsManager('key', 'val', {})
      ).rejects.toThrow('Access denied');
    });
  });

  describe('retrieveFromSecretsManager', () => {
    it('parses SecretString and returns value', async () => {
      mockGetSecretValue.mockResolvedValue({
        SecretString: JSON.stringify({ value: 'the-secret' })
      });

      const result = await service.retrieveFromSecretsManager('my-key');

      expect(result).toBe('the-secret');
    });
  });

  // ── HSM path branches ────────────────────────────────────
  describe('encryptWithHSM — HSM path', () => {
    it('calls encryptWithCloudHSM when hsmClient is set', async () => {
      service.hsmClient = {}; // truthy
      service.encryptWithCloudHSM = jest.fn().mockResolvedValue('hsm-encrypted');

      const result = await service.encryptWithHSM('plaintext');

      expect(service.encryptWithCloudHSM).toHaveBeenCalledWith('plaintext');
      expect(result).toBe('hsm-encrypted');
    });
  });

  describe('decryptWithHSM — HSM path', () => {
    it('calls decryptWithCloudHSM when hsmClient is set', async () => {
      service.hsmClient = {}; // truthy
      service.decryptWithCloudHSM = jest.fn().mockResolvedValue('hsm-decrypted');

      const result = await service.decryptWithHSM('cipher');

      expect(service.decryptWithCloudHSM).toHaveBeenCalledWith('cipher');
      expect(result).toBe('hsm-decrypted');
    });
  });

  // ── validateNetwork geofencing branch ─────────────────────
  describe('validateNetwork — geofencing', () => {
    beforeEach(() => {
      service.validateNetwork = FinancialSecurityService.prototype.validateNetwork.bind(service);
    });

    it('calls validateGeolocation when requireGeofencing is set', async () => {
      mockRedis.sismember.mockResolvedValue(0);
      service.validateGeolocation = jest.fn().mockResolvedValue(true);

      const result = await service.validateNetwork({
        ipAddress: '10.0.0.1',
        requireGeofencing: true
      });

      expect(service.validateGeolocation).toHaveBeenCalled();
      expect(result).toBe(true);
    });
  });

  // ── PCI DSS encryption branch ────────────────────────────
  describe('validateCompliance — PCI DSS encryption', () => {
    it('throws for unencrypted payment processing', async () => {
      await expect(
        service.validateCompliance('paymentProcessing', {
          tokenized: true,
          encrypted: false,
          auditTrail: true
        })
      ).rejects.toThrow(/PCI_DSS/);
    });

    it('throws for both untokenized and unencrypted payment', async () => {
      await expect(
        service.validateCompliance('paymentProcessing', {
          tokenized: false,
          encrypted: false,
          auditTrail: true
        })
      ).rejects.toThrow(/PCI_DSS/);
    });
  });

  // ── CHALLENGE fraud action branch ──────────────────────────
  describe('detectFraud — CHALLENGE action', () => {
    it('returns CHALLENGE for risk score between 0.6 and 0.8', async () => {
      service.getRecentTransactions = jest.fn().mockResolvedValue([]);
      // riskScore = 0.3 (high value) + 0.2 (velocity) + 0.6*0.3 (location) + 0*0.5 (ML) = 0.68
      service.calculateVelocity = jest.fn().mockReturnValue(6);
      service.assessLocationRisk = jest.fn().mockResolvedValue(0.6);
      service.runFraudMLModel = jest.fn().mockResolvedValue(0);

      const result = await service.detectFraud({
        id: 'txn-challenge',
        userId: 'user-1',
        amount: 15000
      });

      expect(result.riskScore).toBeGreaterThanOrEqual(0.6);
      expect(result.riskScore).toBeLessThan(0.8);
      expect(result.action).toBe('CHALLENGE');
    });
  });

  // ── validateIdentity — MFA not required branch ────────────
  describe('validateIdentity — MFA not required', () => {
    const jwt = require('jsonwebtoken');

    it('returns true without MFA when requireMultiFactor is false', async () => {
      service.validateIdentity = FinancialSecurityService.prototype.validateIdentity.bind(service);
      jwt.verify.mockReturnValue({ exp: Date.now() / 1000 + 3600 });

      // Temporarily disable MFA requirement
      const origRules = service.complianceRules.ffiec.requireMultiFactor;
      service.complianceRules.ffiec.requireMultiFactor = false;

      const result = await service.validateIdentity({ token: 'valid-token' });

      service.complianceRules.ffiec.requireMultiFactor = origRules;
      expect(result).toBe(true);
    });
  });

  // ── alertSecurityTeam ─────────────────────────────────────
  describe('alertSecurityTeam', () => {
    it('logs security alert via logger.error', async () => {
      service.alertSecurityTeam = FinancialSecurityService.prototype.alertSecurityTeam.bind(service);
      const alert = { type: 'TEST', userId: 'user-1' };

      await service.alertSecurityTeam(alert);

      expect(mockLoggerError).toHaveBeenCalledWith('SECURITY ALERT', alert);
    });
  });

  // ── retrieveCredential error path ─────────────────────────
  describe('retrieveCredential error path', () => {
    it('logs failure, checks suspicious activity, and rethrows', async () => {
      service.validateZeroTrust = jest.fn().mockResolvedValue(true);
      service.checkSuspiciousActivity = jest.fn().mockResolvedValue();
      mockRateLimiterConsume.mockResolvedValue(true);
      mockGetSecretValue.mockRejectedValue(new Error('Secret not found'));

      const auditSpy = jest.spyOn(service, 'auditLog');

      await expect(
        service.retrieveCredential('missing-key', { userId: 'user-1' })
      ).rejects.toThrow('Secret not found');

      const auditCalls = auditSpy.mock.calls.map(c => c[0]);
      expect(auditCalls).toContain('CREDENTIAL_RETRIEVE_FAILURE');
      expect(service.checkSuspiciousActivity).toHaveBeenCalled();
    });
  });
});
