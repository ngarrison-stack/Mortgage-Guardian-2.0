/**
 * Jest auto-mock for jwks-rsa
 *
 * Prevents ESM/jose import errors in test suites that load auth middleware.
 * By default, getSigningKey rejects so Clerk verification fails gracefully
 * and falls through to Supabase validation.
 *
 * Individual test files can override behavior via jest.mock('jwks-rsa', ...).
 */

const mockGetSigningKey = jest.fn().mockRejectedValue(new Error('Mock JWKS: no key'));

function jwksRsa(options) {
  return {
    getSigningKey: mockGetSigningKey
  };
}

// Expose the mock function for test assertions
jwksRsa._mockGetSigningKey = mockGetSigningKey;

module.exports = jwksRsa;
