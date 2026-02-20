/**
 * Test Utilities Module
 *
 * Reusable helpers for integration testing of the Express API.
 * Provides app setup with mock services, JWT generation, and response assertion helpers.
 *
 * Usage:
 *   const { setupTestApp, generateTestJWT, assertErrorResponse, assertSuccessResponse } = require('../utils/testUtils');
 *   const app = setupTestApp();
 *   const token = generateTestJWT({ userId: 'user-1', email: 'test@example.com' });
 */

const express = require('express');
const jwt = require('jsonwebtoken');

// Test JWT secret - used only in test environment
const TEST_JWT_SECRET = process.env.JWT_SECRET || 'test-secret-key';

/**
 * Set up a test Express app with all middleware and routes.
 *
 * Returns the actual Express app from server.js. Since server.js exports
 * the app directly via module.exports, and only starts listening when
 * NODE_ENV !== 'production' || !VERCEL, supertest can use it without
 * starting a server.
 *
 * Note: Routes use services that require() their dependencies at the module
 * level. For isolated testing, use jest.mock() to replace service modules
 * before requiring the app. This function is for convenience when mocking
 * is already configured via jest.config.js or test setup files.
 *
 * @returns {express.Application} The configured Express app
 */
function setupTestApp() {
  // Ensure test environment is set so server.js doesn't start listening
  // and morgan uses 'dev' format (less noisy in tests)
  const originalNodeEnv = process.env.NODE_ENV;
  process.env.NODE_ENV = 'test';

  // Clear the module cache for server.js and routes so they pick up
  // any jest.mock() overrides that were registered before this call
  const serverPath = require.resolve('../../server');
  const routePaths = [
    require.resolve('../../routes/claude'),
    require.resolve('../../routes/plaid'),
    require.resolve('../../routes/documents'),
    require.resolve('../../routes/health')
  ];

  // Delete cached modules to allow fresh require with mocks
  delete require.cache[serverPath];
  for (const routePath of routePaths) {
    delete require.cache[routePath];
  }

  const app = require('../../server');

  // Restore original NODE_ENV if it was set
  if (originalNodeEnv !== undefined) {
    process.env.NODE_ENV = originalNodeEnv;
  }

  return app;
}

/**
 * Generate a valid JWT token for testing authenticated endpoints.
 *
 * Uses jsonwebtoken to create a signed token with configurable claims.
 * The token uses the test secret 'test-secret-key' (or JWT_SECRET env var).
 *
 * @param {Object} [options={}] - Token payload options
 * @param {string} [options.userId='test-user-id'] - User ID claim
 * @param {string} [options.email='test@example.com'] - Email claim
 * @param {string} [options.role='authenticated'] - User role
 * @param {string} [options.expiresIn='1h'] - Token expiration (e.g. '1h', '30m')
 * @returns {string} Signed JWT token
 */
function generateTestJWT({
  userId = 'test-user-id',
  email = 'test@example.com',
  role = 'authenticated',
  expiresIn = '1h'
} = {}) {
  const payload = {
    sub: userId,
    email,
    role,
    aud: 'authenticated',
    iat: Math.floor(Date.now() / 1000)
  };

  return jwt.sign(payload, TEST_JWT_SECRET, { expiresIn });
}

/**
 * Assert that a response matches the standard error format.
 *
 * The API uses a consistent error format across all routes:
 *   { error: 'Error Type', message: 'Human-readable description' }
 *
 * @param {Object} response - Supertest response object
 * @param {number} statusCode - Expected HTTP status code
 * @param {string} [errorType] - Expected error type string (e.g. 'Bad Request', 'Not Found')
 * @throws {Error} If response doesn't match expected format
 */
function assertErrorResponse(response, statusCode, errorType) {
  expect(response.status).toBe(statusCode);
  expect(response.body).toHaveProperty('error');
  expect(response.body).toHaveProperty('message');
  expect(typeof response.body.error).toBe('string');
  expect(typeof response.body.message).toBe('string');

  if (errorType) {
    expect(response.body.error).toBe(errorType);
  }
}

/**
 * Assert that a response matches the standard success format.
 *
 * Many routes return: { success: true, ...data }
 * Some routes return data directly without the success wrapper.
 * This function validates the success flag and checks for expected fields.
 *
 * @param {Object} response - Supertest response object
 * @param {string[]} [expectedFields=[]] - Field names expected in response body
 * @throws {Error} If response doesn't match expected format
 */
function assertSuccessResponse(response, expectedFields = []) {
  expect(response.status).toBeGreaterThanOrEqual(200);
  expect(response.status).toBeLessThan(300);
  expect(response.body).toHaveProperty('success', true);

  for (const field of expectedFields) {
    expect(response.body).toHaveProperty(field);
  }
}

module.exports = {
  setupTestApp,
  generateTestJWT,
  assertErrorResponse,
  assertSuccessResponse,
  TEST_JWT_SECRET
};
