# Testing Patterns

**Analysis Date:** 2026-01-12

## Test Framework

**Runner:**
- None configured currently
- `package.json` test script: `"test": "echo \"No tests yet\" && exit 0"`

**Assertion Library:**
- Not configured

**Run Commands:**
```bash
npm test                              # Placeholder (no tests)
```

## Test File Organization

**Location:**
- **Backend**: Test files at root of `backend-express/`
  - `test-claude.js` - Claude AI integration test
  - `test-live-backend.sh` - Backend API smoke test script
- **Root**: `test-plaid-corrected.js` - Plaid integration test
- No organized test directory structure

**Naming:**
- `test-{feature}.js` for integration tests
- `test-{feature}.sh` for shell-based smoke tests
- No unit test convention established

**Structure:**
```
backend-express/
  test-claude.js              # Claude AI test
  test-live-backend.sh        # API smoke tests
test-plaid-corrected.js       # Plaid test (root level)
```

## Test Structure

**Suite Organization:**
- No test suite structure currently
- Integration tests are standalone scripts
- Manual execution and verification

**Patterns:**
- Integration tests make real API calls
- Shell scripts test deployed endpoints
- No automated test runner

## Mocking

**Framework:**
- Mock service available: `backend-express/services/mockPlaidService.js`
- Manual mocking for Plaid integration testing
- No mocking framework configured

**Patterns:**
```javascript
// Mock Plaid service pattern (example from mockPlaidService.js)
const mockPlaidService = {
  createLinkToken: async () => ({ link_token: 'mock_token' }),
  exchangePublicToken: async () => ({ access_token: 'mock_access' }),
  // ... additional mock methods
};
```

**What to Mock:**
- External APIs: Plaid (mockPlaidService.js available)
- Anthropic Claude API (not mocked currently)
- Supabase database (not mocked currently)

**What NOT to Mock:**
- Currently all integration tests use real APIs
- No unit tests with isolated mocking

## Fixtures and Factories

**Test Data:**
- No formal fixture system
- Mock data embedded in `mockPlaidService.js`
- Test scripts generate data inline

**Location:**
- Mock services: `backend-express/services/mockPlaidService.js`
- No dedicated fixtures/ or factories/ directories

## Coverage

**Requirements:**
- No coverage targets set
- No coverage tooling configured
- Coverage not tracked

**Configuration:**
- None

**View Coverage:**
```bash
# Not available - no coverage collection
```

## Test Types

**Integration Tests:**
- Scope: Test full API endpoints with real external services
- Examples:
  - `backend-express/test-claude.js` - Tests Claude AI document analysis
  - `backend-express/test-live-backend.sh` - Tests deployed backend health and endpoints
  - Root `test-plaid-corrected.js` - Tests Plaid integration flow
- Mocking: Uses real APIs (sandbox/development environments)
- Setup: Requires valid API keys in environment

**Unit Tests:**
- Not implemented currently
- No isolated function testing

**E2E Tests:**
- Not implemented
- Shell scripts provide basic smoke testing for deployed services

## Common Patterns

**Integration Test Pattern:**
```javascript
// Example structure (from test-claude.js)
require('dotenv').config();
const { analyzeDocument } = require('./services/claudeService');

async function testAnalysis() {
  try {
    const result = await analyzeDocument({ /* params */ });
    console.log('Test passed:', result);
  } catch (error) {
    console.error('Test failed:', error);
  }
}

testAnalysis();
```

**Shell Test Pattern:**
```bash
# Example from test-live-backend.sh
#!/bin/bash
echo "Testing health endpoint..."
curl -X GET https://api-url/health
echo "Testing Claude endpoint..."
curl -X POST https://api-url/v1/ai/claude/analyze -H "Content-Type: application/json" -d '{"documentText":"..."}'
```

**Async Testing:**
- All async functions use async/await
- No Promise.then() chains in tests

**Error Testing:**
- Try/catch blocks capture errors
- Manual verification of error messages
- No assertion library for structured error validation

**Environment Configuration:**
- Tests use dotenv to load .env.local
- Requires valid API keys for real API testing
- Sandbox modes used where available (Plaid)

## Current Testing Gaps

**Missing Infrastructure:**
- No test framework (Jest, Vitest, Mocha)
- No assertion library (expect, chai)
- No test runner automation
- No continuous integration testing
- No code coverage tracking

**Missing Test Types:**
- Unit tests for services and utilities
- Automated integration test suite
- End-to-end user flow testing
- Performance/load testing
- Security testing

**Testing Best Practices Needed:**
- Test isolation (mocking external dependencies)
- Automated test execution
- CI/CD pipeline integration
- Test-driven development workflow
- Code coverage requirements

## Deployment Testing

**Manual Smoke Tests:**
- `backend-express/test-live-backend.sh` - Tests deployed backend endpoints
- Manual curl commands for API validation
- Health check monitoring

**Deployment Scripts:**
- `backend-express/deploy-railway.sh` - Railway deployment
- `backend-express/deploy-render.sh` - Render deployment
- Deployment scripts include basic verification

---

*Testing analysis: 2026-01-12*
*Update when test infrastructure is added*

**Recommendation:** Implement Jest or Vitest with proper unit and integration test structure. Add CI/CD pipeline with automated test execution.
