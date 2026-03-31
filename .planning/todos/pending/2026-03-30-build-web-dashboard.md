---
created: 2026-03-30T01:45
title: Build web dashboard frontend
area: ui
files:
  - frontend/src/app/page.tsx
  - frontend/src/app/layout.tsx
---

## Problem

The backend has a complete API (document upload, case management, AI analysis, consolidated reports, dispute letters) but the Next.js frontend is just a login shell with Clerk auth. No pages exist for document upload, case management, report viewing, or dispute letter generation. This is the biggest gap between system capability and user access.

## Solution

Build a v5.0 milestone with dashboard pages:
- Case list / create / detail views
- Document upload with drag-and-drop and progress tracking
- Report viewer with risk level visualization (Chart.js/Recharts)
- Dispute letter generation and download (QWR, Notice of Error, RFI)
- Plaid bank connection flow
- Leverage existing Clerk auth, Tailwind CSS v4, Next.js 15 App Router
- Should be informed by OpenAPI spec (generate that first)
