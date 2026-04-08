/**
 * Auth Middleware Unit Tests
 *
 * Tests the requireAuth middleware function in isolation.
 * Mocks @supabase/supabase-js to control auth.getUser() responses.
 * Mocks jwks-rsa to control Clerk JWKS verification.
 *
 * Covers:
 *   - Valid Supabase authentication (token accepted, req.user set with provider: 'supabase')
 *   - Valid Clerk authentication (RS256 JWT verified, req.user set with provider: 'clerk')
 *   - Clerk-to-Supabase fallback (Clerk fails, Supabase succeeds)
 *   - Both providers fail → 401
 *   - Missing authentication (no header, empty header)
 *   - Invalid authentication (non-Bearer scheme, errors, null user, empty token)
 *   - Expired Clerk token → falls back to Supabase
 *   - Clerk JWKS unavailable → falls back to Supabase
 *   - Public path exclusion (POST /v1/plaid/webhook bypasses auth)
 */

const crypto = require('crypto');
const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');

// Generate an RSA key pair for test JWT signing/verification
const { publicKey: testPublicKey, privateKey: testPrivateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
});

// Create the mock client BEFORE mocking the module
const mockClient = createMockSupabaseClient();

// Mock jwks-rsa to avoid ESM/jose import issues and control Clerk verification
const mockGetSigningKey = jest.fn();
jest.mock('jwks-rsa', () => {
  return jest.fn(() => ({
    getSigningKey: mockGetSigningKey
  }));
});

// Mock @supabase/supabase-js so that when auth.js calls createClient(),
// it receives our mock client instead of a real Supabase client
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Set env vars so the middleware initializes the supabase client
process.env.SUPABASE_URL = 'https://mock.supabase.co';
process.env.SUPABASE_ANON_KEY = 'mock-anon-key';
process.env.CLERK_ISSUER_URL = 'https://test-clerk.clerk.accounts.dev';

// Now require the middleware AFTER mocking — this ensures createClient
// returns our mock client at module load time
const { requireAuth } = require('../../middleware/auth');

/**
 * Create a signed RS256 JWT for testing Clerk verification.
 *
 * @param {Object} payloadOverrides - Claims to merge into the JWT payload
 * @param {Object} headerOverrides - Fields to merge into the JWT header
 * @returns {string} Signed JWT string
 */
function createTestJwt(payloadOverrides = {}, headerOverrides = {}) {
  const header = {
    alg: 'RS256',
    typ: 'JWT',
    kid: 'test-key-id',
    ...headerOverrides
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: 'clerk-user-123',
    email: 'ios@example.com',
    iss: 'https://test-clerk.clerk.accounts.dev',
    iat: now - 60,
    exp: now + 3600,
    ...payloadOverrides
  };

  const headerB64 = Buffer.from(JSON.stringify(header)).toString('base64url');
  const payloadB64 = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const data = `${headerB64}.${payloadB64}`;

  const signer = crypto.createSign('RSA-SHA256');
  signer.update(data);
  const signature = signer.sign(testPrivateKey);
  const signatureB64 = signature.toString('base64url');

  return `${headerB64}.${payloadB64}.${signatureB64}`;
}

/**
 * Configure mockGetSigningKey to return the test public key (Clerk success).
 */
function setupClerkSuccess() {
  mockGetSigningKey.mockResolvedValue({
    getPublicKey: () => testPublicKey
  });
}

/**
 * Configure mockGetSigningKey to reject (Clerk JWKS unavailable).
 */
function setupClerkFailure(message = 'JWKS endpoint unreachable') {
  mockGetSigningKey.mockRejectedValue(new Error(message));
}

/**
 * Create mock Express req/res/next objects for middleware testing
 */
function createMockReqResNext(overrides = {}) {
  const req = {
    headers: {},
    originalUrl: '/v1/test',
    method: 'GET',
    ...overrides
  };

  const res = {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis()
  };

  const next = jest.fn();

  return { req, res, next };
}

describe('requireAuth middleware', () => {
  beforeEach(() => {
    mockClient.reset();
    mockGetSigningKey.mockReset();
    // Default: Clerk fails, so existing Supabase tests work as before
    setupClerkFailure();
  });

  // ==================================================
  // Valid Supabase authentication
  // ==================================================
  describe('valid Supabase authentication', () => {
    test('passes request with valid Bearer token via Supabase', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer valid-test-token-123' }
      });

      mockClient.setResponse('auth', {
        data: { user: { id: 'user-123', email: 'test@example.com', role: 'authenticated' } },
        error: null
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith();
      expect(res.status).not.toHaveBeenCalled();
      expect(res.json).not.toHaveBeenCalled();
    });

    test('sets req.user with Supabase user data and provider: supabase', async () => {
      const userData = {
        id: 'user-456',
        email: 'admin@mortguardian.com',
        role: 'authenticated',
        app_metadata: { provider: 'email' }
      };

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer some-valid-token' }
      });

      mockClient.setResponse('auth', {
        data: { user: userData },
        error: null
      });

      await requireAuth(req, res, next);

      expect(req.user).toEqual({ ...userData, provider: 'supabase' });
      expect(req.user.id).toBe('user-456');
      expect(req.user.email).toBe('admin@mortguardian.com');
      expect(req.user.provider).toBe('supabase');
    });

    test('calls next() exactly once', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer another-valid-token' }
      });

      mockClient.setResponse('auth', {
        data: { user: { id: 'user-789', email: 'user@test.com', role: 'authenticated' } },
        error: null
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
    });
  });

  // ==================================================
  // Valid Clerk authentication
  // ==================================================
  describe('valid Clerk authentication', () => {
    test('accepts a valid Clerk RS256 JWT and sets provider: clerk', async () => {
      setupClerkSuccess();
      const token = createTestJwt();

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: `Bearer ${token}` }
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith();
      expect(req.user).toEqual({
        id: 'clerk-user-123',
        email: 'ios@example.com',
        provider: 'clerk'
      });
      expect(res.status).not.toHaveBeenCalled();
    });

    test('sets req.user.id from JWT sub claim', async () => {
      setupClerkSuccess();
      const token = createTestJwt({ sub: 'user_abc_xyz' });

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: `Bearer ${token}` }
      });

      await requireAuth(req, res, next);

      expect(req.user.id).toBe('user_abc_xyz');
      expect(req.user.provider).toBe('clerk');
    });

    test('handles Clerk JWT with no email claim', async () => {
      setupClerkSuccess();
      const token = createTestJwt({ email: undefined });

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: `Bearer ${token}` }
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.user).toEqual({
        id: 'clerk-user-123',
        email: null,
        provider: 'clerk'
      });
    });

    test('Clerk path is tried before Supabase', async () => {
      setupClerkSuccess();
      const token = createTestJwt();

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: `Bearer ${token}` }
      });

      // Even if Supabase would also succeed, Clerk should be used first
      mockClient.setResponse('auth', {
        data: { user: { id: 'supabase-user', email: 'sup@test.com' } },
        error: null
      });

      await requireAuth(req, res, next);

      // Should have Clerk provider, not Supabase
      expect(req.user.provider).toBe('clerk');
      expect(req.user.id).toBe('clerk-user-123');
    });
  });

  // ==================================================
  // Clerk-to-Supabase fallback
  // ==================================================
  describe('Clerk-to-Supabase fallback', () => {
    test('falls back to Supabase when Clerk JWKS is unavailable', async () => {
      setupClerkFailure('JWKS endpoint unreachable');

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer supabase-token-abc' }
      });

      mockClient.setResponse('auth', {
        data: { user: { id: 'sb-user-1', email: 'web@test.com', role: 'authenticated' } },
        error: null
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.user.provider).toBe('supabase');
      expect(req.user.id).toBe('sb-user-1');
    });

    test('falls back to Supabase when Clerk token is expired', async () => {
      setupClerkSuccess();
      // Create an expired token (exp in the past)
      const expiredToken = createTestJwt({ exp: Math.floor(Date.now() / 1000) - 3600 });

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: `Bearer ${expiredToken}` }
      });

      mockClient.setResponse('auth', {
        data: { user: { id: 'sb-user-2', email: 'fallback@test.com', role: 'authenticated' } },
        error: null
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.user.provider).toBe('supabase');
      expect(req.user.id).toBe('sb-user-2');
    });

    test('falls back to Supabase when Clerk issuer does not match', async () => {
      setupClerkSuccess();
      const token = createTestJwt({ iss: 'https://wrong-issuer.clerk.accounts.dev' });

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: `Bearer ${token}` }
      });

      mockClient.setResponse('auth', {
        data: { user: { id: 'sb-user-3', email: 'iss@test.com', role: 'authenticated' } },
        error: null
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.user.provider).toBe('supabase');
    });

    test('falls back to Supabase when Clerk JWT has wrong algorithm', async () => {
      setupClerkSuccess();
      // Create a token with HS256 header (unsupported for Clerk)
      const token = createTestJwt({}, { alg: 'HS256' });

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: `Bearer ${token}` }
      });

      mockClient.setResponse('auth', {
        data: { user: { id: 'sb-user-4', email: 'alg@test.com', role: 'authenticated' } },
        error: null
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.user.provider).toBe('supabase');
    });
  });

  // ==================================================
  // Both providers fail
  // ==================================================
  describe('both providers fail', () => {
    test('returns 401 when both Clerk and Supabase reject the token', async () => {
      setupClerkFailure();

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer bad-token-xyz' }
      });

      mockClient.setError('auth', { message: 'Invalid token', code: 'INVALID_TOKEN' });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
      expect(next).not.toHaveBeenCalled();
    });

    test('returns 401 when Clerk fails and Supabase returns null user', async () => {
      setupClerkFailure();

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer orphan-token' }
      });

      mockClient.setResponse('auth', {
        data: { user: null },
        error: null
      });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
      expect(next).not.toHaveBeenCalled();
    });

    test('returns 401 when Clerk fails and Supabase throws', async () => {
      setupClerkFailure();

      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer crash-token' }
      });

      const originalGetUser = mockClient.auth.getUser;
      mockClient.auth.getUser = jest.fn().mockRejectedValue(new Error('Network failure'));

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
      expect(next).not.toHaveBeenCalled();

      mockClient.auth.getUser = originalGetUser;
    });
  });

  // ==================================================
  // Missing authentication
  // ==================================================
  describe('missing authentication', () => {
    test('returns 401 when Authorization header is missing', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: {}
      });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Missing or invalid Authorization header'
      });
    });

    test('returns 401 when Authorization header is empty', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: '' }
      });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Missing or invalid Authorization header'
      });
    });

    test('returns error format: { error: "Unauthorized", message: "..." }', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: {}
      });

      await requireAuth(req, res, next);

      expect(res.json).toHaveBeenCalledTimes(1);
      const responseBody = res.json.mock.calls[0][0];
      expect(responseBody).toHaveProperty('error', 'Unauthorized');
      expect(responseBody).toHaveProperty('message');
      expect(typeof responseBody.message).toBe('string');
    });

    test('does not call next()', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: {}
      });

      await requireAuth(req, res, next);

      expect(next).not.toHaveBeenCalled();
    });
  });

  // ==================================================
  // Invalid authentication
  // ==================================================
  describe('invalid authentication', () => {
    test('returns 401 for non-Bearer scheme (e.g., "Basic")', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Basic dXNlcjpwYXNz' }
      });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Missing or invalid Authorization header'
      });
      expect(next).not.toHaveBeenCalled();
    });

    test('returns 401 when Supabase returns error', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer expired-token-123' }
      });

      mockClient.setError('auth', { message: 'Invalid token', code: 'INVALID_TOKEN' });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
      expect(next).not.toHaveBeenCalled();
    });

    test('returns 401 when Supabase returns null user', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer null-user-token' }
      });

      mockClient.setResponse('auth', {
        data: { user: null },
        error: null
      });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
      expect(next).not.toHaveBeenCalled();
    });

    test('returns 401 when Supabase auth.getUser() throws an exception', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer crash-token' }
      });

      const originalGetUser = mockClient.auth.getUser;
      mockClient.auth.getUser = jest.fn().mockRejectedValue(new Error('Network failure'));

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
      expect(next).not.toHaveBeenCalled();

      mockClient.auth.getUser = originalGetUser;
    });

    test('returns 401 for malformed token (Bearer with empty string)', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer ' }
      });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unauthorized',
        message: 'Missing or invalid Authorization header'
      });
      expect(next).not.toHaveBeenCalled();
    });
  });

  // ==================================================
  // Public path exclusion
  // ==================================================
  describe('public path exclusion', () => {
    test('skips auth for POST /v1/plaid/webhook', async () => {
      const { req, res, next } = createMockReqResNext({
        method: 'POST',
        originalUrl: '/v1/plaid/webhook',
        headers: {}
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith();
      expect(res.status).not.toHaveBeenCalled();
      expect(res.json).not.toHaveBeenCalled();
    });

    test('does NOT skip auth for GET /v1/plaid/webhook', async () => {
      const { req, res, next } = createMockReqResNext({
        method: 'GET',
        originalUrl: '/v1/plaid/webhook',
        headers: {}
      });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    test('does NOT skip auth for POST /v1/plaid/link_token', async () => {
      const { req, res, next } = createMockReqResNext({
        method: 'POST',
        originalUrl: '/v1/plaid/link_token',
        headers: {}
      });

      await requireAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });
  });
});
