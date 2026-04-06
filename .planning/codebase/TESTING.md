# Testing Patterns

**Analysis Date:** 2026-04-04

## Test Framework

**Runner:**
- Jest 29.7.0 (backend only)
- Config: `backend-express/jest.config.js` with ts-jest preset
- Node.js test environment (not jsdom)

**Assertion Library:**
- Jest built-in expect
- Matchers: `toBe`, `toEqual`, `toThrow`, `toBeInstanceOf`, `toMatchObject`, `toHaveBeenCalledWith`

**HTTP Testing:**
- Supertest 7.2.2 for API route testing

**Load Testing:**
- autocannon 8.0.0 (`backend-express/loadtest/`)
- Suites: health, api, stress, memory, all
- Runner: `backend-express/loadtest/runner.js`

**Run Commands:**
```bash
cd backend-express
npm test                    # Run all tests
npm run test:watch          # Watch mode
npm run test:coverage       # Coverage report
npm run test:verbose        # Detailed output
npm run loadtest            # All load test suites
npm run loadtest:health     # Health endpoint load tests
npm run loadtest:api        # API route load tests
npm run loadtest:stress     # Stress tests (ramp-up stages)
npm run loadtest:memory     # Memory profiling under load
```

**Frontend:**
- No test framework configured
- Linting only: `cd frontend && npm run lint`

## Test File Organization

**Location:**
- All tests in `backend-express/__tests__/` directory (not co-located)
- Test discovery: `**/__tests__/**/*.test.js`, `**/__tests__/**/*.test.ts`

**Naming:**
- Unit tests: `{module}.test.js` (e.g., `complianceService.test.js`)
- Integration tests: `{feature}.test.js` in `integration/` (e.g., `user-isolation.test.js`)
- Route tests: `{route}-routes.test.js` (e.g., `plaid-routes.test.js`)
- Middleware tests: `{middleware}.test.js` in `middleware/`

**Structure:**
```
backend-express/__tests__/
├── mocks/                              # Shared mock implementations
│   ├── mockClaudeService.js
│   ├── mockSupabaseClient.js
│   ├── mockPipelineServices.js
│   └── mockRedisClient.js
├── middleware/                          # Middleware tests
│   ├── auth.test.js
│   └── validate.test.js
├── integration/                         # Feature integration tests
│   ├── user-isolation.test.js
│   ├── document-security.test.js
│   ├── pipeline-performance.test.js
│   ├── forensic-analysis.test.js
│   └── consolidated-report.test.js
├── routes/                              # Route handler tests
│   └── plaid-routes.test.js
├── services/                            # Service unit tests
│   ├── complianceService.test.js
│   ├── complianceRuleEngine.test.js
│   ├── documentPipeline-integration.test.js
│   └── plaidCrossReferenceService.test.js
└── migrations/                          # Schema/policy tests
    └── rls-policies.test.js
```

## Test Structure

**Suite Organization:**
```javascript
describe('CaseFileService', () => {
  beforeEach(() => {
    mockClient.reset();  // Clear state between tests
  });

  describe('createCase', () => {
    it('should create a case with valid parameters', async () => {
      // arrange
      const params = { userId: 'user-1', caseName: 'Test Case' };

      // act
      const result = await service.createCase(params);

      // assert
      expect(result).toMatchObject({ caseName: 'Test Case' });
    });

    it('should throw ValidationError on missing userId', async () => {
      await expect(service.createCase({}))
        .rejects.toBeInstanceOf(ValidationError);
    });
  });
});
```

**Patterns:**
- `beforeEach` for per-test setup (mock reset, state cleanup)
- `afterEach` or `afterAll` for teardown when needed
- Arrange/Act/Assert structure (sometimes implicit)
- One assertion focus per test (multiple expects OK if related)

## Mocking

**Framework:**
- Jest built-in mocking (`jest.mock()`, `jest.fn()`)
- Module mocking hoisted before imports

**Patterns:**

Module mocking:
```javascript
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

jest.mock('../services/caseFileService', () => ({
  getCase: jest.fn(),
  updateCase: jest.fn()
}));
```

Custom service mocks (in `__tests__/mocks/`):
```javascript
const mockClaudeService = {
  analyzeDocument: jest.fn(),
  buildMortgageAnalysisPrompt: jest.fn(),
  testConnection: jest.fn(),
  setResponse: jest.fn(),    // Configure response for test
  setError: jest.fn(),       // Force error scenario
  reset: jest.fn()           // Clear state
};
```

In-memory stores for integration tests:
```javascript
const mockCaseStore = new Map();
const mockDocumentStore = new Map();
// Simulate CRUD with user isolation checks
```

**What to Mock:**
- External services: Supabase, Claude AI, Plaid, Redis
- Database operations (Supabase client)
- Third-party API calls

**What NOT to Mock:**
- Business logic within services under test
- Joi validation schemas (test real validation)
- Express middleware chains in integration tests

## Fixtures and Factories

**Test Data:**
```javascript
// Factory functions with sensible defaults and overrides
function makeForensicReport(overrides = {}) {
  return {
    caseId: 'case-001',
    analyzedAt: '2026-03-09T12:00:00.000Z',
    discrepancies: [...],
    timeline: { events: [], violations: [] },
    summary: { ... },
    ...overrides
  };
}

// Mock Express req/res/next
function createMockReqResNext() {
  const req = { body: {}, params: {}, query: {}, headers: {} };
  const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
  const next = jest.fn();
  return { req, res, next };
}
```

**Location:**
- Factory functions: defined in test file near usage
- Shared mocks: `backend-express/__tests__/mocks/`
- No separate fixtures directory (inline data or factories)

## Coverage

**Requirements:**
- Enforced thresholds in `backend-express/jest.config.js`:
  - Statements: 85%
  - Branches: 70%
  - Functions: 85%
  - Lines: 85%

**Current Coverage (as of Phase 24-05):**
- Statements: 97.07%
- Branches: 85.70%
- Functions: 96.88%
- Lines: 97.64%
- Total tests passing: 1610+

**Configuration:**
- Coverage collected from: `services/`, `routes/`, `middleware/`, `schemas/`, `utils/`
- Reports: text (console), lcov (CI), html (browsable)
- Output directory: `backend-express/coverage/`

**View Coverage:**
```bash
cd backend-express
npm run test:coverage
open coverage/index.html
```

## Test Types

**Unit Tests:**
- Scope: Single service or module in isolation
- Mocking: All external dependencies mocked
- Speed: Fast (<100ms per test)
- Examples: `complianceService.test.js`, `complianceRuleEngine.test.js`

**Integration Tests:**
- Scope: Multiple services working together
- Mocking: External boundaries only (Supabase, Claude, Plaid)
- Setup: Mock stores simulate database behavior
- Examples: `user-isolation.test.js`, `document-security.test.js`, `pipeline-performance.test.js`

**Route Tests:**
- Scope: HTTP endpoint handlers via Supertest
- Mocking: Services mocked, Express middleware real
- Examples: `plaid-routes.test.js`

**Middleware Tests:**
- Scope: Individual middleware functions
- Mocking: req/res/next objects
- Examples: `auth.test.js`, `validate.test.js`

**Load Tests:**
- Scope: Performance under concurrent connections
- Tool: autocannon via `backend-express/loadtest/`
- Suites: health, api, stress (ramp-up), memory profiling
- Thresholds: p99 < 1000ms, error rate < 1%, RSS < 100MB

**E2E Tests:**
- Not currently implemented (frontend has no tests)

## Common Patterns

**Async Testing:**
```javascript
it('should process document successfully', async () => {
  const result = await service.processDocument(mockDoc);
  expect(result.status).toBe('completed');
});
```

**Error Testing:**
```javascript
it('should throw ValidationError on invalid input', async () => {
  await expect(service.method(invalidInput))
    .rejects.toBeInstanceOf(ValidationError);
});

// Or with try/catch for detailed assertions
it('should include error details', async () => {
  try {
    await service.method(invalidInput);
    fail('Should have thrown');
  } catch (error) {
    expect(error).toBeInstanceOf(ValidationError);
    expect(error.statusCode).toBe(400);
    expect(error.details).toBeDefined();
  }
});
```

**Supertest for Routes:**
```javascript
const request = require('supertest');
it('should create a case', async () => {
  const res = await request(app)
    .post('/v1/cases')
    .set('Authorization', `Bearer ${token}`)
    .send({ caseName: 'Test Case' });
  expect(res.status).toBe(201);
});
```

**Performance Benchmarking:**
```javascript
it('should complete under 500ms', async () => {
  const start = Date.now();
  await service.processDocument(mockDoc);
  const duration = Date.now() - start;
  expect(duration).toBeLessThan(500);
});
```

**Snapshot Testing:**
- Not used in this codebase

---

*Testing analysis: 2026-04-04*
*Update when test patterns change*
