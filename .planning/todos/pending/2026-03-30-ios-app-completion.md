---
created: 2026-03-30T01:45
title: Complete iOS app TODOs
area: general
files:
  - MortgageGuardian.xcworkspace
  - Mortgage-Guardian-2.0/
---

## Problem

The iOS app (Swift/SwiftUI) has 50+ TODO comments across its codebase. Key gaps include: Plaid bank connection flow completion, app state persistence, settings/scenarios views (stub implementations), bulk letter generation, issue resolution tracking, camera capture and file picker full integration, backup/restore functionality, and rate history view.

## Solution

Prioritize by user-facing impact:
1. Plaid connection flow (core feature)
2. App state persistence (data loss risk)
3. Camera/file picker integration (document capture UX)
4. Settings views (user configuration)
5. Bulk letter generation and export (power user feature)
Decision needed: is iOS or web the primary interface going forward? This affects priority relative to the web dashboard todo.
