/**
 * Unit tests for CaseFileService (services/caseFileService.js)
 *
 * Tests all CRUD operations in both PostgreSQL and mock modes.
 * Uses jest.mock for ../../services/db to control query() responses.
 */

const mockQuery = jest.fn();

jest.mock('../../services/db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}));

// Set env vars BEFORE requiring service so it initializes the DB path
process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';

const caseFileService = require('../../services/caseFileService');

// ============================================================
// PostgreSQL mode tests
// ============================================================
describe('CaseFileService (PostgreSQL mode)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ----------------------------------------------------------
  // createCase
  // ----------------------------------------------------------
  describe('createCase', () => {
    const createArgs = {
      userId: 'user-1',
      caseName: 'Smith Mortgage Audit 2024',
      borrowerName: 'John Smith',
      propertyAddress: '123 Main St',
      loanNumber: 'LN-001',
      servicerName: 'BigBank Corp',
      notes: 'Initial audit case'
    };

    it('creates a case and returns the created record', async () => {
      const mockCase = {
        id: 'case-uuid-1',
        user_id: 'user-1',
        case_name: 'Smith Mortgage Audit 2024',
        borrower_name: 'John Smith',
        status: 'open'
      };
      mockQuery.mockResolvedValue({ rows: [mockCase], rowCount: 1 });

      const result = await caseFileService.createCase(createArgs);

      expect(result.id).toBe('case-uuid-1');
      expect(result.case_name).toBe('Smith Mortgage Audit 2024');
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO case_files'),
        expect.arrayContaining(['user-1', 'Smith Mortgage Audit 2024', 'John Smith', '123 Main St', 'LN-001', 'BigBank Corp', 'Initial audit case'])
      );
    });

    it('throws on database error', async () => {
      mockQuery.mockRejectedValue(new Error('Insert failed'));

      await expect(caseFileService.createCase(createArgs))
        .rejects.toThrow('Insert failed');
    });
  });

  // ----------------------------------------------------------
  // getCasesByUser
  // ----------------------------------------------------------
  describe('getCasesByUser', () => {
    it('returns cases filtered by userId', async () => {
      const cases = [
        { id: 'case-1', case_name: 'Audit A' },
        { id: 'case-2', case_name: 'Audit B' }
      ];
      mockQuery.mockResolvedValue({ rows: cases, rowCount: 2 });

      const result = await caseFileService.getCasesByUser({ userId: 'user-1' });

      expect(result).toEqual(cases);
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('WHERE user_id = $1'),
        expect.arrayContaining(['user-1'])
      );
    });

    it('applies default limit and offset', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      await caseFileService.getCasesByUser({ userId: 'user-1' });

      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('LIMIT'),
        expect.arrayContaining(['user-1', 50, 0])
      );
    });

    it('filters by status when provided', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      await caseFileService.getCasesByUser({ userId: 'user-1', status: 'open' });

      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('AND status ='),
        expect.arrayContaining(['user-1', 'open'])
      );
    });

    it('returns empty array when no results', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      const result = await caseFileService.getCasesByUser({ userId: 'user-1' });

      expect(result).toEqual([]);
    });

    it('throws on database error', async () => {
      mockQuery.mockRejectedValue(new Error('Query timeout'));

      await expect(caseFileService.getCasesByUser({ userId: 'user-1' }))
        .rejects.toThrow('Query timeout');
    });
  });

  // ----------------------------------------------------------
  // getCase
  // ----------------------------------------------------------
  describe('getCase', () => {
    it('returns case with documents array', async () => {
      const caseData = { id: 'case-1', case_name: 'Test Audit', user_id: 'user-1' };
      const docs = [{ document_id: 'doc-1', case_id: 'case-1' }];

      // First query returns case, second returns docs
      mockQuery
        .mockResolvedValueOnce({ rows: [caseData], rowCount: 1 })
        .mockResolvedValueOnce({ rows: docs, rowCount: 1 });

      const result = await caseFileService.getCase({ caseId: 'case-1', userId: 'user-1' });

      expect(result.id).toBe('case-1');
      expect(result.documents).toEqual(docs);
    });

    it('returns null when case not found', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      const result = await caseFileService.getCase({ caseId: 'nonexistent', userId: 'user-1' });

      expect(result).toBeNull();
    });

    it('returns case with empty documents on doc fetch error', async () => {
      const caseData = { id: 'case-1', case_name: 'Test Audit' };
      mockQuery
        .mockResolvedValueOnce({ rows: [caseData], rowCount: 1 })
        .mockRejectedValueOnce(new Error('Doc query failed'));

      const result = await caseFileService.getCase({ caseId: 'case-1', userId: 'user-1' });

      expect(result.id).toBe('case-1');
      expect(result.documents).toEqual([]);
    });

    it('throws on database error for case query', async () => {
      mockQuery.mockRejectedValue(new Error('Connection lost'));

      await expect(caseFileService.getCase({ caseId: 'case-1', userId: 'user-1' }))
        .rejects.toThrow('Connection lost');
    });
  });

  // ----------------------------------------------------------
  // updateCase
  // ----------------------------------------------------------
  describe('updateCase', () => {
    it('only updates provided fields', async () => {
      const updated = { id: 'case-1', case_name: 'Updated Name', status: 'in_review' };
      mockQuery.mockResolvedValue({ rows: [updated], rowCount: 1 });

      const result = await caseFileService.updateCase({
        caseId: 'case-1',
        userId: 'user-1',
        updates: { caseName: 'Updated Name', status: 'in_review' }
      });

      expect(result.case_name).toBe('Updated Name');
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('UPDATE case_files SET'),
        expect.arrayContaining(['Updated Name', 'in_review', 'case-1', 'user-1'])
      );
    });

    it('throws on database error', async () => {
      mockQuery.mockRejectedValue(new Error('Update failed'));

      await expect(caseFileService.updateCase({
        caseId: 'case-1',
        userId: 'user-1',
        updates: { caseName: 'New Name' }
      })).rejects.toThrow('Update failed');
    });
  });

  // ----------------------------------------------------------
  // deleteCase
  // ----------------------------------------------------------
  describe('deleteCase', () => {
    it('deletes case and returns success', async () => {
      mockQuery.mockResolvedValue({ rows: [{ id: 'case-1' }], rowCount: 1 });

      const result = await caseFileService.deleteCase({ caseId: 'case-1', userId: 'user-1' });

      expect(result).toEqual({ success: true });
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('DELETE FROM case_files'),
        ['case-1', 'user-1']
      );
    });

    it('throws when case not found', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      await expect(caseFileService.deleteCase({ caseId: 'nonexistent', userId: 'user-1' }))
        .rejects.toThrow('Case not found');
    });

    it('throws on database error', async () => {
      mockQuery.mockRejectedValue(new Error('FK constraint'));

      await expect(caseFileService.deleteCase({ caseId: 'case-1', userId: 'user-1' }))
        .rejects.toThrow('FK constraint');
    });
  });

  // ----------------------------------------------------------
  // addDocumentToCase
  // ----------------------------------------------------------
  describe('addDocumentToCase', () => {
    it('updates document case_id', async () => {
      const updatedDoc = { document_id: 'doc-1', case_id: 'case-1' };
      mockQuery.mockResolvedValue({ rows: [updatedDoc], rowCount: 1 });

      const result = await caseFileService.addDocumentToCase({
        caseId: 'case-1',
        documentId: 'doc-1',
        userId: 'user-1'
      });

      expect(result.case_id).toBe('case-1');
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('UPDATE documents SET case_id'),
        ['case-1', 'doc-1', 'user-1']
      );
    });

    it('throws on database error', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      await expect(caseFileService.addDocumentToCase({
        caseId: 'case-1',
        documentId: 'doc-1',
        userId: 'user-1'
      })).rejects.toThrow('Document not found');
    });
  });

  // ----------------------------------------------------------
  // removeDocumentFromCase
  // ----------------------------------------------------------
  describe('removeDocumentFromCase', () => {
    it('sets document case_id to null', async () => {
      const updatedDoc = { document_id: 'doc-1', case_id: null };
      mockQuery.mockResolvedValue({ rows: [updatedDoc], rowCount: 1 });

      const result = await caseFileService.removeDocumentFromCase({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      expect(result.case_id).toBeNull();
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('SET case_id = NULL'),
        ['doc-1', 'user-1']
      );
    });

    it('throws on database error', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      await expect(caseFileService.removeDocumentFromCase({
        documentId: 'doc-1',
        userId: 'user-1'
      })).rejects.toThrow('Document not found');
    });
  });
});

// ============================================================
// Mock mode tests (no DATABASE_URL configured)
// ============================================================
describe('CaseFileService (mock mode)', () => {
  let mockCaseService;

  beforeEach(() => {
    delete process.env.DATABASE_URL;
    jest.isolateModules(() => {
      mockCaseService = require('../../services/caseFileService');
    });
  });

  afterEach(() => {
    process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';
  });

  it('mockCreateCase stores in memory and returns case', async () => {
    const result = await mockCaseService.createCase({
      userId: 'user-1',
      caseName: 'Mock Audit Case',
      borrowerName: 'Jane Doe'
    });

    expect(result.id).toBeDefined();
    expect(result.case_name).toBe('Mock Audit Case');
    expect(result.borrower_name).toBe('Jane Doe');
    expect(result.status).toBe('open');
  });

  it('mockGetCasesByUser returns cases filtered by userId', async () => {
    await mockCaseService.createCase({ userId: 'user-1', caseName: 'Case A' });
    await mockCaseService.createCase({ userId: 'user-2', caseName: 'Case B' });
    await mockCaseService.createCase({ userId: 'user-1', caseName: 'Case C' });

    const cases = await mockCaseService.getCasesByUser({ userId: 'user-1' });

    expect(cases).toHaveLength(2);
    expect(cases.every(c => c.user_id === 'user-1')).toBe(true);
  });

  it('mockGetCasesByUser filters by status', async () => {
    const case1 = await mockCaseService.createCase({ userId: 'user-1', caseName: 'Open Case' });
    await mockCaseService.updateCase({ caseId: case1.id, userId: 'user-1', updates: { status: 'complete' } });
    await mockCaseService.createCase({ userId: 'user-1', caseName: 'Still Open' });

    const openCases = await mockCaseService.getCasesByUser({ userId: 'user-1', status: 'open' });

    expect(openCases).toHaveLength(1);
    expect(openCases[0].case_name).toBe('Still Open');
  });

  it('mockGetCase returns case with documents array', async () => {
    const created = await mockCaseService.createCase({ userId: 'user-1', caseName: 'Test Case' });
    await mockCaseService.addDocumentToCase({ caseId: created.id, documentId: 'doc-1', userId: 'user-1' });

    const result = await mockCaseService.getCase({ caseId: created.id, userId: 'user-1' });

    expect(result.id).toBe(created.id);
    expect(result.documents).toHaveLength(1);
    expect(result.documents[0].document_id).toBe('doc-1');
  });

  it('mockGetCase returns null for wrong userId', async () => {
    const created = await mockCaseService.createCase({ userId: 'user-1', caseName: 'Private Case' });

    const result = await mockCaseService.getCase({ caseId: created.id, userId: 'user-other' });

    expect(result).toBeNull();
  });

  it('mockUpdateCase only updates provided fields', async () => {
    const created = await mockCaseService.createCase({
      userId: 'user-1',
      caseName: 'Original Name',
      borrowerName: 'Original Borrower'
    });

    const updated = await mockCaseService.updateCase({
      caseId: created.id,
      userId: 'user-1',
      updates: { caseName: 'Updated Name' }
    });

    expect(updated.case_name).toBe('Updated Name');
    expect(updated.borrower_name).toBe('Original Borrower'); // unchanged
  });

  it('mockDeleteCase removes case and unlinks documents', async () => {
    const created = await mockCaseService.createCase({ userId: 'user-1', caseName: 'To Delete' });
    await mockCaseService.addDocumentToCase({ caseId: created.id, documentId: 'doc-1', userId: 'user-1' });

    const result = await mockCaseService.deleteCase({ caseId: created.id, userId: 'user-1' });
    expect(result).toEqual({ success: true });

    const fetched = await mockCaseService.getCase({ caseId: created.id, userId: 'user-1' });
    expect(fetched).toBeNull();
  });

  it('mockDeleteCase throws for missing case', async () => {
    await expect(mockCaseService.deleteCase({ caseId: 'nonexistent', userId: 'user-1' }))
      .rejects.toThrow('Case not found');
  });

  it('mockAddDocumentToCase links document to case', async () => {
    const created = await mockCaseService.createCase({ userId: 'user-1', caseName: 'Link Test' });

    const result = await mockCaseService.addDocumentToCase({
      caseId: created.id,
      documentId: 'doc-link-1',
      userId: 'user-1'
    });

    expect(result.document_id).toBe('doc-link-1');
    expect(result.case_id).toBe(created.id);
  });

  it('mockRemoveDocumentFromCase sets case_id to null', async () => {
    const created = await mockCaseService.createCase({ userId: 'user-1', caseName: 'Unlink Test' });
    await mockCaseService.addDocumentToCase({ caseId: created.id, documentId: 'doc-unlink-1', userId: 'user-1' });

    const result = await mockCaseService.removeDocumentFromCase({
      documentId: 'doc-unlink-1',
      userId: 'user-1'
    });

    expect(result.case_id).toBeNull();

    // Verify document no longer in case
    const caseData = await mockCaseService.getCase({ caseId: created.id, userId: 'user-1' });
    expect(caseData.documents).toHaveLength(0);
  });

  it('mock methods work when DATABASE_URL not configured', async () => {
    // This is a comprehensive check that the mock fallback works end-to-end
    const created = await mockCaseService.createCase({
      userId: 'user-1',
      caseName: 'Full Lifecycle'
    });
    expect(created.id).toBeDefined();

    const cases = await mockCaseService.getCasesByUser({ userId: 'user-1' });
    expect(cases.length).toBeGreaterThan(0);

    const fetched = await mockCaseService.getCase({ caseId: created.id, userId: 'user-1' });
    expect(fetched).not.toBeNull();

    const updated = await mockCaseService.updateCase({
      caseId: created.id,
      userId: 'user-1',
      updates: { status: 'in_review' }
    });
    expect(updated.status).toBe('in_review');

    const deleted = await mockCaseService.deleteCase({ caseId: created.id, userId: 'user-1' });
    expect(deleted.success).toBe(true);
  });
});
