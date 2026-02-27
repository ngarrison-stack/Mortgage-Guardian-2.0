---
phase: 11-isolated-secure-storage
plan: 03
subsystem: security
tags: [aes-256-gcm, hkdf, encryption, tdd, crypto, node-crypto]

requires:
  - phase: 11-isolated-secure-storage
    provides: "RLS policies and storage path validation from 11-01 and 11-02"
provides:
  - "Per-user document encryption with AES-256-GCM"
  - "HKDF key derivation from master key + userId"
  - "Packed buffer format: iv(12) + authTag(16) + ciphertext"
affects: [11-04-encrypted-document-upload, 11-05-secure-retrieval]

tech-stack:
  added: []
  patterns: ["TDD for crypto code", "HKDF per-user key derivation", "AES-256-GCM authenticated encryption"]

key-files:
  created:
    - backend-express/services/documentEncryptionService.js
    - backend-express/__tests__/services/documentEncryptionService.test.js
  modified: []

key-decisions:
  - "Pack format iv+authTag+ciphertext in single buffer for storage simplicity"
  - "HKDF with app-specific info string 'mortgage-guardian-doc-v1' for domain separation"

patterns-established:
  - "TDD RED-GREEN-REFACTOR for cryptographic services"
  - "Per-user key derivation pattern for tenant isolation"

issues-created: []

duration: 3min
completed: 2026-02-27
---

# Phase 11 Plan 03: Document Encryption Service Summary

**Per-user AES-256-GCM encryption service with HKDF key derivation, built test-first with 11 passing crypto tests covering round-trip, tamper detection, and edge cases**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-27T10:35:36Z
- **Completed:** 2026-02-27T10:39:05Z
- **Tasks:** 2 (RED, GREEN)
- **Files modified:** 2

## TDD Cycle

### RED Phase
Wrote 11 test cases before any implementation existed. All tests failed with "Cannot find module" since the service did not exist yet. Tests cover:
1. Round-trip encrypt/decrypt correctness
2. Different users get different derived keys
3. Same user gets deterministic key
4. Tampered ciphertext throws (GCM authentication)
5. Tampered authTag throws (GCM authentication)
6. Wrong userId throws (key mismatch)
7. Missing env var throws descriptive error
8. Empty buffer (0-byte) encrypt/decrypt
9. Large buffer (1MB) encrypt/decrypt
10. Encrypted output differs from plaintext
11. Pack format length = 12 + 16 + plaintext.length

### GREEN Phase
Implemented `DocumentEncryptionService` class with three methods:
- `deriveKey(userId)` — HKDF-SHA256 from master key + userId salt + app-specific info string
- `encrypt(userId, buffer)` — AES-256-GCM with random 12-byte IV, returns packed iv+authTag+ciphertext
- `decrypt(userId, packed)` — unpacks at fixed offsets, authenticates via GCM, returns plaintext

Constructor validates DOCUMENT_ENCRYPTION_KEY env var (must be 64 hex chars / 32 bytes).
Singleton pattern matches existing service conventions. All 11 tests passed.

### REFACTOR Phase
No refactoring needed — implementation is clean, constants well-named, JSDoc complete, logging never exposes sensitive data.

## Accomplishments
- Per-user document encryption with cryptographic tenant isolation
- Zero external dependencies (Node.js crypto module only)
- Tamper detection via GCM authenticated encryption
- HKDF domain separation with app-specific info string
- Full test suite at 667 tests, zero regressions

## Task Commits

1. **RED: Failing tests** - `c7a6d16` (test)
2. **GREEN: Implementation** - `9d8a0f6` (feat)

## Files Created/Modified
- `backend-express/services/documentEncryptionService.js` — AES-256-GCM encryption service with HKDF per-user key derivation, singleton pattern (120 lines)
- `backend-express/__tests__/services/documentEncryptionService.test.js` — 11 test cases covering round-trip, tamper detection, key derivation, edge cases (183 lines)

## Decisions Made
- **Pack format iv+authTag+ciphertext in single buffer** — simplifies storage (one blob per document) and unpacking (fixed offsets: 0-12, 12-28, 28+)
- **HKDF info string 'mortgage-guardian-doc-v1'** — domain separation ensures keys derived for this app cannot be reused in other contexts; version suffix enables future key rotation
- **jest.isolateModules for missing-env test** — ensures fresh module load without cache interference from singleton pattern

## Deviations from Plan
- Test 7 (missing env var) required `jest.isolateModules` instead of manual `require.cache` manipulation. The singleton pattern causes the module to be cached after first successful load; `jest.isolateModules` provides a clean module registry for testing constructor failure. This is a test implementation detail, not a change to the planned behavior.

## Issues Encountered
None beyond the minor test technique adjustment noted above.

## Next Phase Readiness
- Encryption service ready for integration into document upload/download flow (11-04)
- `encrypt(userId, buffer)` and `decrypt(userId, buffer)` API matches what 11-04 needs to wrap around storage operations
- Pack format (single buffer) means encrypted data can be stored directly in Supabase Storage as a blob
- 3 security layers now complete: RLS (11-01), Storage policies + path validation (11-02), Per-user encryption (this plan)

---
*Phase: 11-isolated-secure-storage*
*Completed: 2026-02-27*
