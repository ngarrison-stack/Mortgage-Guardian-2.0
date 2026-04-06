# Coding Conventions

**Analysis Date:** 2026-04-04

## Naming Patterns

**Files:**
- Backend services: camelCase (`caseFileService.js`, `documentAnalysisService.js`)
- Backend routes/middleware: camelCase (`cases.js`, `errorHandler.js`)
- Frontend components: kebab-case (`case-form.tsx`, `document-upload.tsx`, `confidence-gauge.tsx`)
- Frontend pages: `page.tsx` / `layout.tsx` (Next.js App Router convention)
- Frontend utilities: camelCase (`api.ts`, `hooks.ts`, `types.ts`)
- Tests: `*.test.js` alongside or in `__tests__/`

**Functions:**
- camelCase for all functions (`analyzeDocument`, `createCase`, `generateReport`)
- Async: no special prefix
- Private methods: underscore prefix (`_buildAnalysisPrompt`)
- React hooks: `use` prefix (`useCase`, `useCases`, `useCreateCase`)
- Event handlers: `handle` prefix (`handleChange`, `handleSubmit`)
- Callback props: `on` prefix (`onSubmit`, `onUploadComplete`)

**Variables:**
- camelCase for variables
- UPPER_SNAKE_CASE for constants (`DEFAULT_MODEL`, `DEFAULT_MAX_TOKENS`, `DEFAULT_TEMPERATURE`)
- No underscore prefix for private (except methods noted above)

**Types:**
- PascalCase for classes (`CaseFileService`, `AppError`, `ValidationError`)
- PascalCase for TypeScript interfaces/types (`CaseFormData`, `DocumentStatus`)
- No `I` prefix on interfaces

## Code Style

**Formatting:**
- No Prettier configured; formatting manually maintained
- 2 space indentation (consistent across backend and frontend)
- Single quotes for strings
- Semicolons required
- No strict line length enforced

**Linting:**
- Backend: ESLint 8.57.1 with `eslint:recommended` (`backend-express/.eslintrc.json`)
  - `no-unused-vars`: warn, `no-console`: off, `no-undef`: warn
  - Lints: `services/`, `routes/`, `middleware/`, `schemas/`, `utils/`, `server.js`
  - Run: `cd backend-express && npm run lint`
- Frontend: ESLint 9.39.1 with `eslint-config-next` (`frontend/eslint.config.mjs`)
  - Run: `cd frontend && npm run lint`

## Import Organization

**Backend (CommonJS):**
```javascript
// 1. External packages
const express = require('express');
const { createClient } = require('@supabase/supabase-js');

// 2. Internal services
const caseFileService = require('../services/caseFileService');
const { createLogger } = require('../utils/logger');

// 3. Middleware/schemas
const { validate } = require('../middleware/validate');
const { createCaseSchema } = require('../schemas/cases');

// 4. Initialize
const router = express.Router();
const logger = createLogger('case-routes');
```

**Frontend (ES Modules):**
```typescript
'use client'  // Client component directive (first line)

// 1. React/external packages
import { useState, useCallback } from 'react'
import { useDropzone } from 'react-dropzone'

// 2. Internal hooks/utilities (path alias @/)
import { useUploadDocument, useProcessDocument } from '@/lib/hooks'
import { cn, formatFileSize } from '@/lib/utils'

// 3. Components
import { DocumentStatus } from '@/components/document-status'
import { Button } from '@/components/ui/button'
```

**Path Aliases:**
- Frontend: `@/*` -> `./src/*` (configured in `frontend/tsconfig.json`)
- Backend: No aliases, relative paths with `../`

## Error Handling

**Backend Patterns:**
- Custom error hierarchy in `backend-express/middleware/errorHandler.js`:
  - `AppError` (base) with `statusCode`, `code`, `type`, `displayMessage`, `details`, `isOperational`
  - `ValidationError` (400), `NotFoundError` (404), `AuthenticationError` (401)
  - `AuthorizationError` (403), `ConflictError` (409), `RateLimitError` (429), `ExternalServiceError` (502)
- `asyncHandler` wrapper for automatic error catching in route handlers
- `formatErrorResponse()` for consistent JSON responses
- Services throw typed errors, middleware catches at boundary

**Frontend Patterns:**
- Custom `ApiError` class in `frontend/src/lib/api.ts` with `status` property
- `fetchWithAuth()` wrapper handles error parsing and re-throwing
- React Query handles error/loading states in components

## Logging

**Framework:**
- Winston logger (`backend-express/services/logger.js`)
- Factory: `createLogger(serviceName)` creates service-specific logger
- Production: JSON format (machine-parseable)
- Development: Colorized human-readable format
- Test: Silent mode
- Levels: debug (dev), info (prod minimum), warn, error

**Patterns:**
- Log at service boundaries: `logger.info('Processing document', { documentId, userId })`
- Log errors with context before throwing: `logger.error('Failed to create case', { error, userId })`
- Request correlation via `requestId` middleware
- No `console.log` convention enforced (ESLint `no-console: off`)

**Frontend:**
- No structured logging library
- Sentry integration for error tracking (`@sentry/nextjs`)
- Browser console for development

## Comments

**When to Comment:**
- JSDoc for all public service methods (backend)
- Section headers with ASCII separators: `// ============================================`
- Inline comments explain "why" not "what"

**JSDoc (Backend):**
```javascript
/**
 * Create a new case file
 * @param {Object} params - Parameters object
 * @param {string} params.userId - User ID
 * @param {string} params.caseName - Case name
 * @returns {Promise<Object>} Created case object
 */
async createCase({ userId, caseName }) { ... }
```

**TypeScript Types (Frontend):**
- Interfaces document component contracts (no separate JSDoc needed)
- Types in `frontend/src/lib/types.ts` serve as documentation

**TODO Comments:**
- Format: `// TODO: description` (no username)
- Some found in setup scripts and service files

## Function Design

**Size:**
- Most functions under 50 lines
- Large service files exist (600-800 LOC) but functions within are focused

**Parameters:**
- Object destructuring for multi-param functions:
  ```javascript
  async createCase({ userId, caseName, borrowerName, propertyAddress, loanNumber }) { ... }
  ```
- Joi schemas validate at API boundary before function receives clean data

**Return Values:**
- Explicit returns with async/await
- Services return result objects or throw typed errors
- No Result<T,E> pattern — throw on failure

## Module Design

**Backend Exports:**
- CommonJS: `module.exports = { functionA, functionB }`
- Service classes exported as singletons or with factory methods
- Routes export Express Router: `module.exports = router`

**Frontend Exports:**
- Named exports for components and hooks
- Default exports for Next.js pages (convention)
- Barrel re-exports not used (import from specific files)

**Module Pattern:**
- Backend: `'use strict'` at top of every file
- Services: class with methods or plain object with functions
- Routes: Express Router with middleware chain per endpoint

---

*Convention analysis: 2026-04-04*
*Update when patterns change*
