/**
 * Unit tests for CaseFileService (services/caseFileService.js)
 *
 * Tests all CRUD operations in both Supabase and mock modes.
 * Follows the same mock pattern as documentService.test.js.
 */

// --- Chainable DB mock ---
const mockInsert = jest.fn();
const mockSelect = jest.fn();
const mockUpdate = jest.fn();
const mockDelete = jest.fn();
const mockEq = jest.fn();
const mockOrder = jest.fn();
const mockRange = jest.fn();
const mockSingle = jest.fn();

const mockDbChain = {
  from: jest.fn(),
  insert: mockInsert,
  select: mockSelect,
  update: mockUpdate,
  delete: mockDelete,
  eq: mockEq,
  order: mockOrder,
  range: mockRange,
  single: mockSingle
};

const mockSupabase = { ...mockDbChain };

// Wire chain returns after object exists
mockSupabase.from.mockReturnValue(mockSupabase);
mockInsert.mockReturnValue(mockSupabase);
mockSelect.mockReturnValue(mockSupabase);
mockUpdate.mockReturnValue(mockSupabase);
mockDelete.mockReturnValue(mockSupabase);
mockEq.mockReturnValue(mockSupabase);
mockOrder.mockReturnValue(mockSupabase);
mockRange.mockReturnValue(mockSupabase);

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockSupabase)
}));

// Set env vars BEFORE requiring service
process.env.SUPABASE_URL = 'https://test.supabase.co';
process.env.SUPABASE_SERVICE_KEY = 'test-service-key';

const caseFileService = require('../../services/caseFileService');

// ============================================================
// Supabase mode tests
// ============================================================
describe('CaseFileService (Supabase mode)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset chain defaults
    mockSupabase.from.mockReturnValue(mockSupabase);
    mockInsert.mockReturnValue(mockSupabase);
    mockSelect.mockReturnValue(mockSupabase);
    mockUpdate.mockReturnValue(mockSupabase);
    mockDelete.mockReturnValue(mockSupabase);
    mockEq.mockReturnValue(mockSupabase);
    mockOrder.mockReturnValue(mockSupabase);
    mockRange.mockReturnValue(mockSupabase);
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
      mockSingle.mockResolvedValue({ data: mockCase, error: null });

      const result = await caseFileService.createCase(createArgs);

      expect(result.id).toBe('case-uuid-1');
      expect(result.case_name).toBe('Smith Mortgage Audit 2024');
      expect(mockSupabase.from).toHaveBeenCalledWith('case_files');
      expect(mockInsert).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-1',
          case_name: 'Smith Mortgage Audit 2024',
          borrower_name: 'John Smith',
          property_address: '123 Main St',
          loan_number: 'LN-001',
          servicer_name: 'BigBank Corp',
          notes: 'Initial audit case'
        })
      );
    });

    it('throws on database error', async () => {
      mockSingle.mockResolvedValue({
        data: null,
        error: { message: 'Insert failed' }
      });

      await expect(caseFileService.createCase(createArgs))
        .rejects.toThrow('Database error: Insert failed');
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
      mockRange.mockResolvedValue({ data: cases, error: null });

      const result = await caseFileService.getCasesByUser({ userId: 'user-1' });

      expect(result).toEqual(cases);
      expect(mockSupabase.from).toHaveBeenCalledWith('case_files');
      expect(mockEq).toHaveBeenCalledWith('user_id', 'user-1');
    });

    it('applies default limit and offset', async () => {
      mockRange.mockResolvedValue({ data: [], error: null });

      await caseFileService.getCasesByUser({ userId: 'user-1' });

      expect(mockRange).toHaveBeenCalledWith(0, 49);
      expect(mockOrder).toHaveBeenCalledWith('created_at', { ascending: false });
    });

    it('filters by status when provided', async () => {
      mockRange.mockResolvedValue({ data: [], error: null });

      await caseFileService.getCasesByUser({ userId: 'user-1', status: 'open' });

      // eq called twice: once for user_id, once for status
      expect(mockEq).toHaveBeenCalledWith('user_id', 'user-1');
      expect(mockEq).toHaveBeenCalledWith('status', 'open');
    });

    it('returns empty array when data is null', async () => {
      mockRange.mockResolvedValue({ data: null, error: null });

      const result = await caseFileService.getCasesByUser({ userId: 'user-1' });

      expect(result).toEqual([]);
    });

    it('throws on database error', async () => {
      mockRange.mockResolvedValue({ data: null, error: { message: 'Query timeout' } });

      await expect(caseFileService.getCasesByUser({ userId: 'user-1' }))
        .rejects.toThrow('Database error: Query timeout');
    });
  });

  // ----------------------------------------------------------
  // getCase
  // ----------------------------------------------------------
  describe('getCase', () => {
    it('returns case with documents array', async () => {
      const caseData = { id: 'case-1', case_name: 'Test Audit', user_id: 'user-1' };
      const docs = [{ document_id: 'doc-1', case_id: 'case-1' }];

      // First single() returns case, then order() returns docs
      let singleCallCount = 0;
      mockSingle.mockImplementation(() => {
        singleCallCount++;
        if (singleCallCount === 1) {
          return Promise.resolve({ data: caseData, error: null });
        }
        return Promise.resolve({ data: null, error: null });
      });
      mockOrder.mockResolvedValue({ data: docs, error: null });

      const result = await caseFileService.getCase({ caseId: 'case-1', userId: 'user-1' });

      expect(result.id).toBe('case-1');
      expect(result.documents).toEqual(docs);
    });

    it('returns null when case not found', async () => {
      mockSingle.mockResolvedValue({ data: null, error: null });

      const result = await caseFileService.getCase({ caseId: 'nonexistent', userId: 'user-1' });

      expect(result).toBeNull();
    });

    it('returns case with empty documents on doc fetch error', async () => {
      const caseData = { id: 'case-1', case_name: 'Test Audit' };
      mockSingle.mockResolvedValue({ data: caseData, error: null });
      mockOrder.mockResolvedValue({ data: null, error: { message: 'Doc query failed' } });

      const result = await caseFileService.getCase({ caseId: 'case-1', userId: 'user-1' });

      expect(result.id).toBe('case-1');
      expect(result.documents).toEqual([]);
    });

    it('throws on database error', async () => {
      mockSingle.mockResolvedValue({
        data: null,
        error: { message: 'Connection lost' }
      });

      await expect(caseFileService.getCase({ caseId: 'case-1', userId: 'user-1' }))
        .rejects.toThrow('Database error: Connection lost');
    });
  });

  // ----------------------------------------------------------
  // updateCase
  // ----------------------------------------------------------
  describe('updateCase', () => {
    it('only updates provided fields', async () => {
      const updated = { id: 'case-1', case_name: 'Updated Name', status: 'in_review' };
      mockSingle.mockResolvedValue({ data: updated, error: null });

      const result = await caseFileService.updateCase({
        caseId: 'case-1',
        userId: 'user-1',
        updates: { caseName: 'Updated Name', status: 'in_review' }
      });

      expect(result.case_name).toBe('Updated Name');
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({
          case_name: 'Updated Name',
          status: 'in_review'
        })
      );
      // Should NOT include fields that weren't provided
      const updateArg = mockUpdate.mock.calls[0][0];
      expect(updateArg).not.toHaveProperty('borrower_name');
      expect(updateArg).not.toHaveProperty('loan_number');
    });

    it('throws on database error', async () => {
      mockSingle.mockResolvedValue({
        data: null,
        error: { message: 'Update failed' }
      });

      await expect(caseFileService.updateCase({
        caseId: 'case-1',
        userId: 'user-1',
        updates: { caseName: 'New Name' }
      })).rejects.toThrow('Database error: Update failed');
    });
  });

  // ----------------------------------------------------------
  // deleteCase
  // ----------------------------------------------------------
  describe('deleteCase', () => {
    it('deletes case and returns success', async () => {
      mockSingle.mockResolvedValue({
        data: { id: 'case-1' },
        error: null
      });

      const result = await caseFileService.deleteCase({ caseId: 'case-1', userId: 'user-1' });

      expect(result).toEqual({ success: true });
      expect(mockSupabase.from).toHaveBeenCalledWith('case_files');
      expect(mockDelete).toHaveBeenCalled();
    });

    it('throws when case not found', async () => {
      mockSingle.mockResolvedValue({ data: null, error: null });

      await expect(caseFileService.deleteCase({ caseId: 'nonexistent', userId: 'user-1' }))
        .rejects.toThrow('Case not found');
    });

    it('throws on database error', async () => {
      mockSingle.mockResolvedValue({
        data: null,
        error: { message: 'FK constraint' }
      });

      await expect(caseFileService.deleteCase({ caseId: 'case-1', userId: 'user-1' }))
        .rejects.toThrow('Database error: FK constraint');
    });
  });

  // ----------------------------------------------------------
  // addDocumentToCase
  // ----------------------------------------------------------
  describe('addDocumentToCase', () => {
    it('updates document case_id', async () => {
      const updatedDoc = { document_id: 'doc-1', case_id: 'case-1' };
      mockSingle.mockResolvedValue({ data: updatedDoc, error: null });

      const result = await caseFileService.addDocumentToCase({
        caseId: 'case-1',
        documentId: 'doc-1',
        userId: 'user-1'
      });

      expect(result.case_id).toBe('case-1');
      expect(mockSupabase.from).toHaveBeenCalledWith('documents');
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({ case_id: 'case-1' })
      );
    });

    it('throws on database error', async () => {
      mockSingle.mockResolvedValue({
        data: null,
        error: { message: 'Document not found' }
      });

      await expect(caseFileService.addDocumentToCase({
        caseId: 'case-1',
        documentId: 'doc-1',
        userId: 'user-1'
      })).rejects.toThrow('Database error: Document not found');
    });
  });

  // ----------------------------------------------------------
  // removeDocumentFromCase
  // ----------------------------------------------------------
  describe('removeDocumentFromCase', () => {
    it('sets document case_id to null', async () => {
      const updatedDoc = { document_id: 'doc-1', case_id: null };
      mockSingle.mockResolvedValue({ data: updatedDoc, error: null });

      const result = await caseFileService.removeDocumentFromCase({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      expect(result.case_id).toBeNull();
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({ case_id: null })
      );
    });

    it('throws on database error', async () => {
      mockSingle.mockResolvedValue({
        data: null,
        error: { message: 'Update failed' }
      });

      await expect(caseFileService.removeDocumentFromCase({
        documentId: 'doc-1',
        userId: 'user-1'
      })).rejects.toThrow('Database error: Update failed');
    });
  });
});

// ============================================================
// Mock mode tests (no Supabase configured)
// ============================================================
describe('CaseFileService (mock mode)', () => {
  let mockCaseService;

  beforeEach(() => {
    jest.isolateModules(() => {
      delete process.env.SUPABASE_URL;
      delete process.env.SUPABASE_SERVICE_KEY;
      mockCaseService = require('../../services/caseFileService');
    });
    process.env.SUPABASE_URL = 'https://test.supabase.co';
    process.env.SUPABASE_SERVICE_KEY = 'test-service-key';
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

  it('mock methods work when Supabase not configured', async () => {
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
