# Coding Conventions

**Analysis Date:** 2026-02-26

## Naming Patterns

**Files:**
- camelCase for all source files: `claudeService.js`, `fileValidation.js`
- `*Service.js` suffix for service classes: `plaidService.js`, `documentService.js`
- `*.test.js` in `__tests__/` directory (not colocated)
- `index.js` for barrel exports in refactored module directories

**Functions:**
- camelCase for all functions: `analyzeDocument()`, `createLinkToken()`
- Descriptive names: `buildMortgageAnalysisPrompt()`, `verifyWebhookSignature()`
- No special prefix for async functions

**Variables:**
- camelCase for regular variables: `accessToken`, `documentId`
- UPPER_SNAKE_CASE for constants: `PUBLIC_PATHS`
- No underscore prefix for private members

**Classes:**
- PascalCase: `ClaudeService`, `PlaidService`, `FinancialSecurityService`
- PascalCase for provider/manager classes: `NativeEncryptionProvider`, `RedisSessionManager`

## Code Style

**Formatting:**
- No Prettier config (manual formatting)
- No ESLint config in backend (frontend uses `eslint-config-next`)
- 2 space indentation (consistent throughout)
- Single quotes for strings
- Semicolons required

**Linting:**
- Frontend only: ESLint with `eslint-config-next`
- Backend: No linter configured (relies on conventions)

## Import Organization

**Order:**
1. External packages: `const express = require('express');`
2. Local utilities: `const { createLogger } = require('../utils/logger');`
3. Logger instantiation: `const logger = createLogger('service-name');`
4. Local services/middleware: `const claudeService = require('../services/claudeService');`
5. Schemas (in routes): `const { analyzeSchema } = require('../schemas/claude');`

**Style:**
- CommonJS `require()` throughout backend (no ES modules)
- Destructuring for named exports: `const { createLogger } = require(...)`
- Direct require for singletons: `const claudeService = require(...)`

## Error Handling

**Patterns:**
- Try/catch in all async route handlers
- Known errors (401, 429) handled with specific status codes in routes
- Unknown errors passed to `next(error)` for centralized handler
- Services throw errors with context, caught by routes

**Error Response Format:**
```javascript
res.status(statusCode).json({
  error: 'ErrorType',
  message: 'Human-readable description'
});
```

**Service Error Pattern:**
```javascript
try {
  // ... business logic
} catch (error) {
  logger.error('Operation failed', { error: error.message, stack: error.stack });
  throw error;
}
```

## Logging

**Framework:**
- Winston with child logger pattern
- `const { createLogger } = require('../utils/logger');`
- `const logger = createLogger('service-name');`

**Patterns:**
- Structured logging with context objects:
  ```javascript
  logger.info('Token exchanged', { userId, itemId });
  logger.error('API error', { error: error.message, status: error.status });
  ```
- Log at service boundaries, not in utilities
- No `console.log` in committed code (replaced in Phase 8)
- Silent in test environment (`NODE_ENV=test`)

**Log Levels:**
- `info` - Successful operations, state changes
- `warn` - Missing optional config, fallback behavior
- `error` - Failed operations, exceptions
- `debug` - Detailed diagnostic info (dev only)

## Comments

**When to Comment:**
- JSDoc for public service methods (params, returns)
- Section dividers in large files: `// ============ SECTION ============`
- Business logic explanations: `// Users must verify email within 24 hours`
- Warnings: `// WARNING: In production, store access_token in database`

**JSDoc Pattern:**
```javascript
/**
 * Create Plaid Link token for bank connection flow
 * @param {string} userId - Unique user identifier
 * @param {string} clientName - Display name for Link UI
 * @returns {Promise<Object>} Link token and metadata
 */
```

**TODO Comments:**
- Not widely used; deferred issues tracked in `.planning/STATE.md` instead

## Function Design

**Size:**
- 30-100 lines typical for service methods
- Complex methods have clear try/catch structure
- Helper methods extracted to separate module files in refactored services

**Parameters:**
- Destructured objects for multiple params:
  ```javascript
  async getTransactions({ accessToken, startDate, endDate, accountIds = null, count = 100, offset = 0 })
  ```
- Default values for optional params
- Input validation at function start (token format checks, date validation)

**Return Values:**
- Formatted response objects with clear field names
- Consistent shape within a service

## Module Design

**Exports:**
- Singleton pattern (default): `module.exports = new ServiceClass();`
- Re-export facade: `module.exports = require('./submodule');`
- Named exports for schemas: `module.exports = { schema1, schema2 };`
- Named exports for utilities: `module.exports = { fn1, fn2 };`

**Prototype Mixin Pattern (refactored services):**
```javascript
// Sub-module exports methods as object
module.exports = {
  methodA() { /* uses `this` for shared state */ },
  methodB() { ... }
};

// index.js assembles class
Object.assign(ClassName.prototype, subModuleMethods);
module.exports = new ClassName();
```

**Try-Catch Optional Require (aspirational deps):**
```javascript
let Package;
try { Package = require('package-name'); } catch { Package = null; }
// Guard usage: if (!Package) throw new Error('Package not available');
```

---

*Convention analysis: 2026-02-26*
*Update when patterns change*
