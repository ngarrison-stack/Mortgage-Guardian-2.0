# Testing Patterns

**Analysis Date:** 2026-02-26

## Test Framework

**Runner:**
- Jest 29.7.0
- Config: `backend-express/jest.config.js`
- Preset: ts-jest (TypeScript support available)

**Assertion Library:**
- Jest built-in expect
- Common matchers: `toBe`, `toEqual`, `toHaveBeenCalledWith`, `toThrow`, `rejects.toThrow`

**Run Commands:**
```bash
npm test                              # Run all tests
npm run test:watch                    # Watch mode
npm run test:coverage                 # Coverage report
npm run test:verbose                  # Detailed output
npm test -- path/to/file.test.js     # Single file
```

## Test File Organization

**Location:**
- All tests in `__tests__/` directory (not colocated with source)
- Mirrors source structure: `__tests__/services/`, `__tests__/routes/`, etc.

**Naming:**
- Unit tests: `{sourceName}.test.js` (e.g., `claudeService.test.js`)
- Integration tests: `{feature}-integration.test.js` or `{feature}-routes.test.js`
- Security tests: `{feature}-upload-security.test.js`

**Structure:**
```
backend-express/
  __tests__/
    mocks/                        # Shared mock factories
      mockSupabaseClient.js
      mockClaudeService.js
      mockRedisClient.js
    fixtures/                     # Test data
      dbFixtures.js
    middleware/                   # Middleware tests
    routes/                      # Route integration tests
    services/                    # Service unit tests
    integration/                 # Cross-cutting integration tests
    utils/                       # Utility tests
    validation/                  # Schema tests
```

## Test Structure

**Suite Organization:**
```javascript
describe('ClaudeService', () => {
  describe('analyzeDocument', () => {
    const mockApiResponse = { /* test data at describe scope */ };

    beforeEach(() => {
      mockMessagesCreate.mockReset();
    });

    it('returns formatted response on success', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);
      const result = await claudeService.analyzeDocument({ prompt: 'test' });
      expect(result).toEqual({ /* expected */ });
    });

    it('throws on API error', async () => {
      mockMessagesCreate.mockRejectedValue(new Error('API error'));
      await expect(claudeService.analyzeDocument({ prompt: 'test' }))
        .rejects.toThrow('API error');
    });
  });
});
```

**Patterns:**
- `beforeEach()` resets mocks before each test
- Test data defined at `describe` block level (shared across tests)
- One logical assertion per test
- Async tests use `async/await` with `expect().rejects` for errors

## Mocking

**Framework:**
- Jest built-in mocking (`jest.fn()`, `jest.mock()`)

**Hoisted Module Mocking:**
```javascript
// Declare mock functions BEFORE jest.mock (hoisted)
const mockMessagesCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate }
  }));
});

// THEN require the module under test
const claudeService = require('../../services/claudeService');
```

**Virtual Mocks (for removed/optional packages):**
```javascript
jest.mock('rate-limiter-flexible', () => ({
  RateLimiterRedis: jest.fn(() => ({ /* mock methods */ }))
}), { virtual: true });  // virtual: true allows mocking uninstalled packages

jest.mock('speakeasy', () => ({
  totp: { verify: jest.fn() }
}), { virtual: true });
```

**Supabase Client Factory:**
```javascript
const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');
const mockClient = createMockSupabaseClient();

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Chainable query builder: mockClient.from('table').select().eq('col', 'val')
```

**What to Mock:**
- External SDKs: Anthropic, Plaid, Supabase
- Redis client
- Optional/aspirational packages (aws-sdk, speakeasy, rate-limiter-flexible)

**What NOT to Mock:**
- Pure utility functions
- Joi schemas (test real validation)
- Winston logger (silenced automatically via `NODE_ENV=test`)

## Fixtures and Factories

**Mock Factories (in `__tests__/mocks/`):**
- `mockSupabaseClient.js` - Chainable query builder with `setResponse`/`setError`
- `mockClaudeService.js` - Claude AI mock with preset responses
- `mockRedisClient.js` - Redis client mock

**Test Data (inline):**
```javascript
const mockApiResponse = {
  content: [{ text: 'Analysis result' }],
  model: 'claude-3-5-sonnet-20241022',
  usage: { input_tokens: 100, output_tokens: 50 },
  stop_reason: 'end_turn'
};
```

**Database Fixtures:**
- `__tests__/fixtures/dbFixtures.js` - Mock database records

## Coverage

**Requirements:**
- 90% minimum globally (statements, branches, functions, lines)
- Enforced by Jest config

**Configuration:**
```javascript
collectCoverageFrom: [
  'services/**/*.js',
  'routes/**/*.js',
  'middleware/**/*.js',
  'schemas/**/*.js',
  'utils/**/*.js',
  '!**/node_modules/**',
  '!**/__tests__/**'
]
```

**View Coverage:**
```bash
npm run test:coverage
open coverage/index.html
```

**Current Status:** 690 tests passing (as of Phase 11-05)

## Test Types

**Unit Tests:**
- Test single service method in isolation
- Mock all external dependencies
- Examples: `claudeService.test.js`, `plaidService.test.js`

**Integration Tests:**
- Test routes with middleware + services via supertest
- Mock external APIs but use real middleware chain
- Clear module cache and re-require app after mocking
- Examples: `documents-routes.test.js`, `auth-integration.test.js`

**Security Integration Tests:**
- Test cross-cutting security concerns (encryption, isolation, RLS)
- Exercise real crypto services, mock only storage boundaries
- Location: `__tests__/integration/`
- Examples: `document-security.test.js`, `user-isolation.test.js`

**Integration Test Pattern:**
```javascript
const request = require('supertest');
jest.mock('@supabase/supabase-js', () => ({ createClient: jest.fn(() => mockClient) }));

let app;
beforeAll(() => {
  delete require.cache[require.resolve('../../server')];
  app = require('../../server');
});

test('GET /v1/documents returns 200', async () => {
  const response = await request(app)
    .get('/v1/documents')
    .set('Authorization', 'Bearer valid-token')
    .query({ userId: 'user-123' });
  expect(response.status).toBe(200);
});
```

## Common Patterns

**Async Testing:**
```javascript
it('should handle async operation', async () => {
  const result = await service.method();
  expect(result).toEqual(expected);
});
```

**Error Testing:**
```javascript
it('should throw on invalid input', async () => {
  await expect(service.method(invalid))
    .rejects.toThrow('Expected error message');
});
```

**Silent Logger:**
- Winston logger auto-silences in test env (`silent: isTest` in logger.js)
- No need to mock logger — just works
- Tests verify logger behavior by checking `logger.info.mock.calls` when needed

**Module Cache Reset (Integration Tests):**
```javascript
beforeAll(() => {
  const serverPath = require.resolve('../../server');
  delete require.cache[serverPath];
  app = require('../../server');
});
```
This ensures mocks are applied before Express app initializes its middleware chain.

---

*Testing analysis: 2026-02-26*
*Update when test patterns change*
