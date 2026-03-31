/**
 * RLS Policy Enforcement Verification Tests
 *
 * Validates that:
 * 1. Migration 004 SQL is structurally correct (RLS enabled, policies present)
 * 2. Application-layer services enforce user-scoping via WHERE user_id clauses
 *
 * Since the backend now uses pg (node-postgres) instead of Supabase,
 * Part 2 verifies that service methods include user_id in SQL queries.
 */

const fs = require('fs');
const path = require('path');

// ============================================================
// Part 1: Migration SQL Structure Tests
// ============================================================
describe('Migration 004 — RLS Policy Structure', () => {
  let migrationSql;
  let sqlWithoutComments;

  beforeAll(() => {
    const migrationPath = path.join(
      __dirname,
      '..', '..', 'migrations', '004_document_rls_policies.sql'
    );
    migrationSql = fs.readFileSync(migrationPath, 'utf-8');
    // Strip SQL single-line comments for accurate counting of active SQL tokens
    sqlWithoutComments = migrationSql
      .split('\n')
      .filter(line => !line.trimStart().startsWith('--'))
      .join('\n');
  });

  const rlsTables = ['documents', 'case_files', 'document_classifications', 'pipeline_state'];

  it('enables RLS on all 4 document-related tables', () => {
    for (const table of rlsTables) {
      const pattern = new RegExp(
        `ALTER\\s+TABLE\\s+${table}\\s+ENABLE\\s+ROW\\s+LEVEL\\s+SECURITY`,
        'i'
      );
      expect(migrationSql).toMatch(pattern);
    }
  });

  it('creates SELECT, INSERT, UPDATE, DELETE policies for documents table', () => {
    const operations = ['SELECT', 'INSERT', 'UPDATE', 'DELETE'];
    for (const op of operations) {
      const pattern = new RegExp(
        `CREATE\\s+POLICY\\s+.*documents.*\\s+ON\\s+documents\\s+FOR\\s+${op}`,
        'is'
      );
      expect(migrationSql).toMatch(pattern);
    }
  });

  it('creates SELECT, INSERT, UPDATE, DELETE policies for case_files table', () => {
    const operations = ['SELECT', 'INSERT', 'UPDATE', 'DELETE'];
    for (const op of operations) {
      const pattern = new RegExp(
        `CREATE\\s+POLICY\\s+.*case.files.*\\s+ON\\s+case_files\\s+FOR\\s+${op}`,
        'is'
      );
      expect(migrationSql).toMatch(pattern);
    }
  });

  it('creates SELECT, INSERT, UPDATE, DELETE policies for pipeline_state table', () => {
    const operations = ['SELECT', 'INSERT', 'UPDATE', 'DELETE'];
    for (const op of operations) {
      const pattern = new RegExp(
        `CREATE\\s+POLICY\\s+.*pipeline.state.*\\s+ON\\s+pipeline_state\\s+FOR\\s+${op}`,
        'is'
      );
      expect(migrationSql).toMatch(pattern);
    }
  });

  it('uses EXISTS join through documents table for document_classifications (no direct user_id)', () => {
    const existsPattern = /EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+documents\s+d\s+WHERE\s+d\.document_id\s*=\s*document_classifications\.document_id/i;
    expect(migrationSql).toMatch(existsPattern);

    const classificationBlocks = migrationSql.split(/ALTER\s+TABLE/i);
    const classBlock = classificationBlocks.find(block => /document_classifications\s+ENABLE/i.test(block));
    expect(classBlock).toBeDefined();
    expect(classBlock).not.toMatch(/document_classifications\.user_id/i);
  });

  it('references auth.uid()::text in all policies', () => {
    const authUidMatches = sqlWithoutComments.match(/auth\.uid\(\)::text/g);
    expect(authUidMatches).not.toBeNull();
    expect(authUidMatches.length).toBe(14);
  });

  it('uses idempotent DO $$ guards for all policies', () => {
    const doBlocks = sqlWithoutComments.match(/DO\s+\$\$/g);
    expect(doBlocks).not.toBeNull();
    expect(doBlocks.length).toBe(14);

    const pgPoliciesChecks = sqlWithoutComments.match(/pg_policies/g);
    expect(pgPoliciesChecks).not.toBeNull();
    expect(pgPoliciesChecks.length).toBe(14);
  });

  it('does NOT contain a service_role bypass policy', () => {
    expect(migrationSql).not.toMatch(/CREATE\s+POLICY.*service.role/i);
    expect(migrationSql).not.toMatch(/BYPASSRLS/i);
  });
});

// ============================================================
// Part 2: Service User-Scoping Audit Tests
// ============================================================
// These tests verify that application-layer services always filter
// queries by user_id, providing defense-in-depth alongside database RLS.
// Now that services use pg query() instead of Supabase chain builders,
// we verify user_id appears in the SQL queries.

const mockQuery = jest.fn();

jest.mock('../../services/db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}));

jest.mock('../../db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}), { virtual: true });

// Mock fs/promises for documentService
jest.mock('fs', () => ({
  ...jest.requireActual('fs'),
  promises: {
    writeFile: jest.fn().mockResolvedValue(undefined),
    readFile: jest.fn().mockResolvedValue(Buffer.from('test')),
    mkdir: jest.fn().mockResolvedValue(undefined),
    unlink: jest.fn().mockResolvedValue(undefined)
  }
}));

process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';

const documentService = require('../../services/documentService');
const caseFileService = require('../../services/caseFileService');

describe('Service user-scoping audit — DocumentService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('getDocumentsByUser filters by user_id', async () => {
    mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

    await documentService.getDocumentsByUser({ userId: 'user-abc' });

    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining('user_id'),
      expect.arrayContaining(['user-abc'])
    );
  });

  it('getDocument filters by both document_id and user_id', async () => {
    mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

    const result = await documentService.getDocument({ documentId: 'doc-1', userId: 'user-abc' });

    expect(result).toBeNull();
    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining('user_id'),
      expect.arrayContaining(['doc-1', 'user-abc'])
    );
  });

  it('deleteDocument filters by both document_id and user_id', async () => {
    mockQuery
      .mockResolvedValueOnce({ rows: [{ storage_path: 'documents/user-abc/doc-1' }], rowCount: 1 })
      .mockResolvedValueOnce({ rows: [], rowCount: 1 });

    await documentService.deleteDocument({ documentId: 'doc-1', userId: 'user-abc' });

    // Both queries should include user_id
    expect(mockQuery.mock.calls[0][0]).toContain('user_id');
    expect(mockQuery.mock.calls[0][1]).toContain('user-abc');
    expect(mockQuery.mock.calls[1][0]).toContain('user_id');
    expect(mockQuery.mock.calls[1][1]).toContain('user-abc');
  });
});

describe('Service user-scoping audit — CaseFileService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('getCasesByUser filters by user_id', async () => {
    mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

    await caseFileService.getCasesByUser({ userId: 'user-xyz' });

    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining('user_id'),
      expect.arrayContaining(['user-xyz'])
    );
  });

  it('getCase filters by user_id', async () => {
    mockQuery.mockResolvedValueOnce({ rows: [{ id: 'case-1' }], rowCount: 1 });
    mockQuery.mockResolvedValueOnce({ rows: [], rowCount: 0 });

    await caseFileService.getCase({ caseId: 'case-1', userId: 'user-xyz' });

    expect(mockQuery.mock.calls[0][0]).toContain('user_id');
    expect(mockQuery.mock.calls[0][1]).toContain('user-xyz');
  });

  it('updateCase filters by user_id', async () => {
    mockQuery.mockResolvedValue({ rows: [{ id: 'case-1' }], rowCount: 1 });

    await caseFileService.updateCase({
      caseId: 'case-1',
      userId: 'user-xyz',
      updates: { caseName: 'Updated' }
    });

    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining('user_id'),
      expect.arrayContaining(['user-xyz'])
    );
  });

  it('deleteCase filters by user_id', async () => {
    mockQuery.mockResolvedValue({ rows: [{ id: 'case-1' }], rowCount: 1 });

    await caseFileService.deleteCase({ caseId: 'case-1', userId: 'user-xyz' });

    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining('user_id'),
      expect.arrayContaining(['user-xyz'])
    );
  });
});
