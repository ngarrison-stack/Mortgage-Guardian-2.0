/**
 * RLS Policy Enforcement Verification Tests
 *
 * Validates that:
 * 1. Migration 004 SQL is structurally correct (RLS enabled, policies present)
 * 2. Application-layer services enforce user-scoping (defense-in-depth)
 *
 * Note: Actual RLS enforcement testing requires a live Supabase instance.
 * These tests verify the migration structure and that the application layer
 * ALSO enforces user isolation via .eq('user_id', ...) filters.
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
    // document_classifications policies must use EXISTS subquery joining to documents
    const existsPattern = /EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+documents\s+d\s+WHERE\s+d\.document_id\s*=\s*document_classifications\.document_id/i;
    expect(migrationSql).toMatch(existsPattern);

    // Verify document_classifications policies do NOT use direct user_id comparison
    // (they should only reference user_id inside the EXISTS subquery via documents table)
    const classificationBlocks = migrationSql.split(/ALTER\s+TABLE/i);
    const classBlock = classificationBlocks.find(block => /document_classifications\s+ENABLE/i.test(block));
    expect(classBlock).toBeDefined();

    // Within the classification section, user_id should only appear inside EXISTS (d.user_id)
    // and never as a direct column reference like: document_classifications.user_id
    expect(classBlock).not.toMatch(/document_classifications\.user_id/i);
  });

  it('references auth.uid()::text in all policies', () => {
    // Count occurrences of auth.uid()::text in active SQL (excluding comments)
    const authUidMatches = sqlWithoutComments.match(/auth\.uid\(\)::text/g);
    expect(authUidMatches).not.toBeNull();
    // 4 policies for documents + 4 for case_files + 2 for document_classifications + 4 for pipeline_state = 14
    expect(authUidMatches.length).toBe(14);
  });

  it('uses idempotent DO $$ guards for all policies', () => {
    const doBlocks = sqlWithoutComments.match(/DO\s+\$\$/g);
    expect(doBlocks).not.toBeNull();
    // One DO $$ block per policy: 4 + 4 + 2 + 4 = 14
    expect(doBlocks.length).toBe(14);

    // Each guard checks pg_policies
    const pgPoliciesChecks = sqlWithoutComments.match(/pg_policies/g);
    expect(pgPoliciesChecks).not.toBeNull();
    expect(pgPoliciesChecks.length).toBe(14);
  });

  it('does NOT contain a service_role bypass policy', () => {
    // Verify no CREATE POLICY references service_role — comments mentioning it are fine
    expect(migrationSql).not.toMatch(/CREATE\s+POLICY.*service.role/i);
    expect(migrationSql).not.toMatch(/BYPASSRLS/i);
  });
});

// ============================================================
// Part 2: Service User-Scoping Audit Tests
// ============================================================
// These tests verify that application-layer services always filter
// queries by user_id, providing defense-in-depth alongside database RLS.

// --- Top-level chainable DB mock (shared by both service imports) ---
const mockEq = jest.fn();
const mockSingle = jest.fn();
const mockOrder = jest.fn();
const mockRange = jest.fn();
const mockSelect = jest.fn();
const mockInsert = jest.fn();
const mockUpdate = jest.fn();
const mockDelete = jest.fn();

const mockStorageUpload = jest.fn();
const mockStorageDownload = jest.fn();
const mockStorageRemove = jest.fn();

const mockSupabase = {
  from: jest.fn(),
  insert: mockInsert,
  select: mockSelect,
  update: mockUpdate,
  delete: mockDelete,
  eq: mockEq,
  order: mockOrder,
  range: mockRange,
  single: mockSingle,
  storage: {
    from: jest.fn(() => ({
      upload: mockStorageUpload,
      download: mockStorageDownload,
      remove: mockStorageRemove
    }))
  }
};

// Wire chain — every chainable method returns the mock itself
mockSupabase.from.mockReturnValue(mockSupabase);
mockInsert.mockReturnValue(mockSupabase);
mockSelect.mockReturnValue(mockSupabase);
mockUpdate.mockReturnValue(mockSupabase);
mockDelete.mockReturnValue(mockSupabase);
mockEq.mockReturnValue(mockSupabase);
mockOrder.mockReturnValue(mockSupabase);
mockRange.mockReturnValue(mockSupabase);

// Hoist mock before any require()
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockSupabase)
}));

// Set env vars BEFORE requiring services
process.env.SUPABASE_URL = 'https://test.supabase.co';
process.env.SUPABASE_SERVICE_KEY = 'test-service-key';

const documentService = require('../../services/documentService');
const caseFileService = require('../../services/caseFileService');

function resetChain() {
  mockSupabase.from.mockReturnValue(mockSupabase);
  mockInsert.mockReturnValue(mockSupabase);
  mockSelect.mockReturnValue(mockSupabase);
  mockUpdate.mockReturnValue(mockSupabase);
  mockDelete.mockReturnValue(mockSupabase);
  mockEq.mockReturnValue(mockSupabase);
  mockOrder.mockReturnValue(mockSupabase);
  mockRange.mockReturnValue(mockSupabase);
  mockStorageUpload.mockResolvedValue({ data: {}, error: null });
  mockStorageDownload.mockResolvedValue({ data: null, error: null });
  mockStorageRemove.mockResolvedValue({ data: {}, error: null });
}

describe('Service user-scoping audit — DocumentService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    resetChain();
  });

  it('getDocumentsByUser filters by user_id', async () => {
    mockRange.mockResolvedValue({ data: [], error: null });

    await documentService.getDocumentsByUser({ userId: 'user-abc' });

    expect(mockEq).toHaveBeenCalledWith('user_id', 'user-abc');
  });

  it('getDocument filters by both document_id and user_id', async () => {
    mockSingle.mockResolvedValue({ data: null, error: { message: 'Not found' } });

    try {
      await documentService.getDocument({ documentId: 'doc-1', userId: 'user-abc' });
    } catch {
      // Expected — we just need to verify the filter calls
    }

    expect(mockEq).toHaveBeenCalledWith('document_id', 'doc-1');
    expect(mockEq).toHaveBeenCalledWith('user_id', 'user-abc');
  });

  it('deleteDocument filters by both document_id and user_id', async () => {
    // The delete flow calls:
    //   1. select → eq(doc_id) → eq(user_id) → single()  (fetch storage_path)
    //   2. storage.remove()
    //   3. delete → eq(doc_id) → eq(user_id)              (delete from DB)
    // single() resolves the first chain; the second delete chain resolves via .eq() thenable
    mockSingle.mockResolvedValueOnce({
      data: { storage_path: 'documents/user-abc/doc-1' },
      error: null
    });
    // The final eq in the delete chain is awaited directly (no .single()),
    // so we need the last eq call to resolve as a thenable
    const callCount = { n: 0 };
    mockEq.mockImplementation(() => {
      callCount.n++;
      // The delete chain: from().delete().eq(doc).eq(user) — 6th and 7th eq calls
      // (first 4 are from the select chain + second query has eq calls from delete chain)
      // Return mockSupabase for chaining, but add thenable behavior
      return Object.assign({}, mockSupabase, {
        then: (resolve) => resolve({ data: [], error: null })
      });
    });

    await documentService.deleteDocument({ documentId: 'doc-1', userId: 'user-abc' });

    expect(mockEq).toHaveBeenCalledWith('document_id', 'doc-1');
    expect(mockEq).toHaveBeenCalledWith('user_id', 'user-abc');
  });
});

describe('Service user-scoping audit — CaseFileService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    resetChain();
  });

  it('getCasesByUser filters by user_id', async () => {
    mockRange.mockResolvedValue({ data: [], error: null });

    await caseFileService.getCasesByUser({ userId: 'user-xyz' });

    expect(mockEq).toHaveBeenCalledWith('user_id', 'user-xyz');
  });

  it('getCase filters by user_id', async () => {
    // First query: case_files → eq(id) → eq(user_id) → single()
    mockSingle.mockResolvedValueOnce({ data: { id: 'case-1' }, error: null });
    // Second query: documents → eq(case_id) → eq(user_id) → order()
    mockOrder.mockResolvedValueOnce({ data: [], error: null });

    await caseFileService.getCase({ caseId: 'case-1', userId: 'user-xyz' });

    expect(mockEq).toHaveBeenCalledWith('user_id', 'user-xyz');
  });

  it('updateCase filters by user_id', async () => {
    mockSingle.mockResolvedValue({ data: { id: 'case-1' }, error: null });

    await caseFileService.updateCase({
      caseId: 'case-1',
      userId: 'user-xyz',
      updates: { caseName: 'Updated' }
    });

    expect(mockEq).toHaveBeenCalledWith('user_id', 'user-xyz');
  });

  it('deleteCase filters by user_id', async () => {
    mockSingle.mockResolvedValue({ data: { id: 'case-1' }, error: null });

    await caseFileService.deleteCase({ caseId: 'case-1', userId: 'user-xyz' });

    expect(mockEq).toHaveBeenCalledWith('user_id', 'user-xyz');
  });
});
