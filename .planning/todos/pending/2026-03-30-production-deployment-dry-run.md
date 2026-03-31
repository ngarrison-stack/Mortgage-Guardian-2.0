---
created: 2026-03-30T01:45
title: Production deployment dry run
area: tooling
files:
  - backend-express/vercel.json
  - backend-express/railway.json
  - backend-express/Dockerfile
  - .github/workflows/complete-ci-cd.yml
---

## Problem

CI/CD configs exist (Vercel, Railway, Docker, GitHub Actions) but haven't been tested with real infrastructure. Enterprise CI/CD pipeline includes security scanning (Trivy, Snyk), performance testing (k6), and compliance checks — none verified against actual services. Config issues will surface at the worst time if not caught in a dry run.

## Solution

Deploy to staging environment:
- Backend to Railway with real Supabase instance + Plaid sandbox
- Frontend to Vercel with Clerk production keys
- Run the GitHub Actions CI/CD pipeline end-to-end
- Verify health checks, env var config, CORS settings
- Test document upload → analysis → report flow with real API keys
- Document any config fixes needed
