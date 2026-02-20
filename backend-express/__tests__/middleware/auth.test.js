/**
 * Auth Middleware Unit Tests
 *
 * Tests the requireAuth middleware function in isolation.
 * Mocks @supabase/supabase-js to control auth.getUser() responses.
 *
 * Covers:
 *   - Valid authentication (token accepted, req.user set, next() called)
 *   - Missing authentication (no header, empty header)
 *   - Invalid authentication (non-Bearer scheme, Supabase error, null user, empty token)
 *   - Public path exclusion (POST /v1/plaid/webhook bypasses auth)
 */

const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');

// Create the mock client BEFORE mocking the module
const mockClient = createMockSupabaseClient();

// Mock @supabase/supabase-js so that when auth.js calls createClient(),
// it receives our mock client instead of a real Supabase client
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Set env vars so the middleware initializes the supabase client
process.env.SUPABASE_URL = 'https://mock.supabase.co';
process.env.SUPABASE_ANON_KEY = 'mock-anon-key';

// Now require the middleware AFTER mocking — this ensures createClient
// returns our mock client at module load time
const { requireAuth } = require('../../middleware/auth');

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
  });

  // ==================================================
  // Valid authentication
  // ==================================================
  describe('valid authentication', () => {
    test('passes request with valid Bearer token', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: { authorization: 'Bearer valid-test-token-123' }
      });

      // Mock Supabase to return a valid user
      mockClient.setResponse('auth', {
        data: { user: { id: 'user-123', email: 'test@example.com', role: 'authenticated' } },
        error: null
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith(); // called with no arguments (not an error)
      expect(res.status).not.toHaveBeenCalled();
      expect(res.json).not.toHaveBeenCalled();
    });

    test('sets req.user with authenticated user data', async () => {
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

      expect(req.user).toEqual(userData);
      expect(req.user.id).toBe('user-456');
      expect(req.user.email).toBe('admin@mortguardian.com');
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
  // Missing authentication
  // ==================================================
  describe('missing authentication', () => {
    test('returns 401 when Authorization header is missing', async () => {
      const { req, res, next } = createMockReqResNext({
        headers: {} // no authorization header
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
        headers: {} // no authorization header
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
        headers: {} // no authorization header
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
        headers: {} // no auth header
      });

      await requireAuth(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith(); // called with no arguments
      expect(res.status).not.toHaveBeenCalled();
      expect(res.json).not.toHaveBeenCalled();
    });

    test('does NOT skip auth for GET /v1/plaid/webhook', async () => {
      const { req, res, next } = createMockReqResNext({
        method: 'GET',
        originalUrl: '/v1/plaid/webhook',
        headers: {} // no auth header
      });

      await requireAuth(req, res, next);

      // Should be rejected because GET is not in PUBLIC_PATHS
      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    test('does NOT skip auth for POST /v1/plaid/link_token', async () => {
      const { req, res, next } = createMockReqResNext({
        method: 'POST',
        originalUrl: '/v1/plaid/link_token',
        headers: {} // no auth header
      });

      await requireAuth(req, res, next);

      // Should be rejected because /v1/plaid/link_token is not a public path
      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });
  });
});
