---
created: 2026-03-30T01:45
title: Generate OpenAPI spec from existing routes
area: docs
files:
  - backend-express/routes/*.js
  - backend-express/middleware/validate.js
  - backend-express/schemas/*.js
---

## Problem

13 backend API endpoints exist with full Joi validation schemas but no formal API documentation. No Swagger/OpenAPI spec, no Redoc or SwaggerUI. This blocks contract-first frontend development and makes third-party/iOS integration harder. The Joi schemas already define request/response shapes — they just need to be expressed as OpenAPI.

## Solution

Generate OpenAPI 3.0 spec from existing route definitions and Joi schemas. Options:
- `joi-to-swagger` to auto-convert Joi schemas to OpenAPI components
- Or manual spec with route comments as source of truth
- Serve with SwaggerUI at `/api-docs` endpoint
- Unblocks frontend dashboard development with typed API contracts
