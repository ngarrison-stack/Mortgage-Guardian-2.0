# Coding Conventions

**Analysis Date:** 2026-01-12

## Naming Patterns

**Files:**
- camelCase.js for all backend JavaScript files (`server.js`, `claudeService.js`)
- camelCase.tsx for React components (`layout.tsx`, `page.tsx`)
- kebab-case.sh for shell scripts (`deploy-railway.sh`, `test-live-backend.sh`)
- UPPERCASE.md for important documentation (README.md, CLAUDE.md)
- Test files: `test-{feature}.js` (e.g., `test-claude.js`)

**Functions:**
- camelCase for all functions (`analyzeDocument`, `buildMortgageAnalysisPrompt`)
- No special prefix for async functions (async keyword used)
- Async/await pattern throughout (no .then() chains)

**Variables:**
- camelCase for variables (`documentText`, `analysisPrompt`, `maxTokens`)
- UPPER_SNAKE_CASE for constants and env vars (`PORT`, `ANTHROPIC_API_KEY`, `NODE_ENV`)
- No underscore prefix for private members (CommonJS modules, no classes)

**Types:**
- TypeScript enabled but minimal type annotations
- Implicit typing used in .js files
- tsconfig.json present in both `backend-express/` and `frontend/`

## Code Style

**Formatting:**
- No Prettier config detected (no .prettierrc file)
- 2-space indentation (observed in code samples)
- Single quotes for strings (backend)
- Double quotes for strings (frontend, per ESLint config)
- Semicolons required in backend, optional in frontend
- Line length: Not enforced (no config)

**Linting:**
- **Frontend**: ESLint with Next.js config
  - File: `frontend/eslint.config.mjs`
  - Extends: `next/core-web-vitals`, `next/typescript`
  - Ignores: node_modules, .next, out, build, next-env.d.ts
  - Run: `npm run lint` in frontend/
- **Backend**: No ESLint config detected
  - No .eslintrc or eslint.config.js file
  - Relies on editor defaults

## Import Organization

**Backend (CommonJS):**
1. Node.js built-ins (`const express = require('express')`)
2. External packages (`const cors = require('cors')`)
3. Local modules (`const claudeService = require('../services/claudeService')`)

**Frontend (ES Modules):**
1. External packages (`import { dirname } from "path"`)
2. Framework-specific (`@clerk/nextjs`, `next`)
3. Type imports (TypeScript `import type`)

**Grouping:**
- No blank lines between import groups currently
- No consistent sorting pattern

**Path Aliases:**
- None configured currently
- Relative imports used (../, ./)

## Error Handling

**Patterns:**
- Try/catch at route handler level
- Errors thrown from services bubble up
- Global Express error middleware: 4-parameter function in `backend-express/server.js`
- HTTP status codes: 400 (bad request), 401 (auth), 404 (not found), 500 (internal error)

**Error Types:**
- Standard Error objects with message property
- Custom statusCode property added: `error.status` or `error.statusCode`
- Error responses include: `error`, `message`, optionally `details` fields

**Async:**
- All async functions use try/catch
- No .catch() chains - await with try/catch preferred
- Next.js: async/await in Server Components

## Logging

**Framework:**
- Winston v3.11.0 for application logging (backend, configured but not heavily used)
- Morgan v1.10.0 for HTTP request logging
- console.log/console.error for development debugging

**Patterns:**
- Morgan logging:
  - Development: `morgan('dev')` - colored, minimal
  - Production: `morgan('combined')` - Apache combined log format
- Console logging throughout: `console.log(...)`, `console.error(...)`
- Format: Plain text messages, no structured logging currently
- When: Log request start/end (Morgan), errors (console.error), debugging (console.log)

## Comments

**When to Comment:**
- Section headers in server.js (e.g., `// ============================================`)
- API endpoint descriptions (route handlers)
- Complex logic explanation (rare currently)
- TODO comments for future work (not observed yet)

**JSDoc/TSDoc:**
- Not used currently
- No function documentation with @param, @returns tags
- Inline comments preferred

**TODO Comments:**
- Pattern: Not standardized (no TODOs found in sampled code)
- Expected: `// TODO: description` format

## Function Design

**Size:**
- Route handlers: 20-50 lines typically
- Service functions: 30-100 lines
- No strict limit enforced

**Parameters:**
- Object destructuring common: `const { prompt, model, maxTokens } = req.body`
- Options objects used for services: `claudeService.analyzeDocument({ prompt, model, maxTokens })`
- Max parameters: Typically 1-3 (often destructured from req)

**Return Values:**
- Explicit return statements
- Early returns for validation: `return res.status(400).json(...)`
- Async functions return Promises (implicitly via async/await)

## Module Design

**Exports:**
- **Backend**: CommonJS - `module.exports = { ... }` or `module.exports = router`
- **Frontend**: ES modules - `export default` for React components
- Named exports rare in current code

**Barrel Files:**
- Not used currently
- No index.js files for re-exporting
- Direct imports from specific files

**Module Pattern:**
- Backend: Express Router modules (`const router = express.Router()`)
- Services: Plain object exports with functions
- Frontend: React functional components

## Request/Response Patterns

**API Responses:**
- Success: `{ success: true, data: ..., timestamp: ... }`
- Error: `{ error: 'Error Type', message: '...', details?: ... }`
- Consistent JSON structure
- ISO 8601 timestamps

**Validation:**
- Manual validation in route handlers
- Joi v18.0.1 available but not heavily used
- Early return pattern: `if (!field) return res.status(400).json(...)`

## Environment Configuration

**Pattern:**
- dotenv package for .env file loading
- `require('dotenv').config()` at top of server.js
- Access via `process.env.VARIABLE_NAME`
- Type coercion: `parseInt(process.env.PORT)` for numbers
- Defaults: `process.env.VAR || defaultValue`

---

*Convention analysis: 2026-01-12*
*Update when patterns change*
