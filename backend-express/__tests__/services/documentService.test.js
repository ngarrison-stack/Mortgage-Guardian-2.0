/**
 * Unit tests for DocumentService (services/documentService.js)
 *
 * Tests all CRUD operations in both Supabase and mock modes.
 * Supabase mock is hoisted because the module creates a client at load time.
 */

// --- Chainable DB mock ---
const mockInsert = jest.fn();
const mockSelect = jest.fn();
const mockDelete = jest.fn();
const mockEq = jest.fn();
const mockOrder = jest.fn();
const mockRange = jest.fn();
const mockSingle = jest.fn();

const mockDbChain = {
  from: jest.fn(),
  insert: mockInsert,
  select: mockSelect,
  delete: mockDelete,
  eq: mockEq,
  order: mockOrder,
  range: mockRange,
  single: mockSingle
};

// --- Storage mock ---
const mockStorageUpload = jest.fn();
const mockStorageDownload = jest.fn();
const mockStorageRemove = jest.fn();

const mockSupabase = {
  ...mockDbChain,
  storage: {
    from: jest.fn(() => ({
      upload: mockStorageUpload,
      download: mockStorageDownload,
      remove: mockStorageRemove
    }))
  }
};

// Wire chain returns after object exists
mockSupabase.from.mockReturnValue(mockSupabase);
mockInsert.mockReturnValue(mockSupabase);
mockSelect.mockReturnValue(mockSupabase);
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

const documentService = require('../../services/documentService');

// ============================================================
// Supabase mode tests
// ============================================================
describe('DocumentService (Supabase mode)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset chain defaults
    mockSupabase.from.mockReturnValue(mockSupabase);
    mockInsert.mockReturnValue(mockSupabase);
    mockSelect.mockReturnValue(mockSupabase);
    mockDelete.mockReturnValue(mockSupabase);
    mockEq.mockReturnValue(mockSupabase);
    mockOrder.mockReturnValue(mockSupabase);
    mockRange.mockReturnValue(mockSupabase);
    // Default storage success
    mockStorageUpload.mockResolvedValue({ data: {}, error: null });
    mockStorageDownload.mockResolvedValue({ data: null, error: null });
    mockStorageRemove.mockResolvedValue({ data: {}, error: null });
  });

  // ----------------------------------------------------------
  // uploadDocument
  // ----------------------------------------------------------
  describe('uploadDocument', () => {
    const uploadArgs = {
      documentId: 'doc-1',
      userId: 'user-1',
      fileName: 'statement.pdf',
      documentType: 'mortgage_statement',
      content: Buffer.from('mock-pdf-content').toString('base64'),
      analysisResults: { findings: [] },
      metadata: { source: 'upload' }
    };

    it('uploads file to storage and saves metadata', async () => {
      mockSingle.mockResolvedValue({
        data: { document_id: 'doc-1', storage_path: 'documents/user-1/doc-1' },
        error: null
      });

      const result = await documentService.uploadDocument(uploadArgs);

      expect(result.documentId).toBe('doc-1');
      expect(result.storagePath).toBe('documents/user-1/doc-1');
      expect(result.metadata).toBeDefined();
      // Verify storage upload
      expect(mockSupabase.storage.from).toHaveBeenCalledWith('documents');
      expect(mockStorageUpload).toHaveBeenCalledWith(
        'documents/user-1/doc-1',
        expect.any(Buffer),
        { contentType: 'application/pdf', upsert: true }
      );
      // Verify db insert
      expect(mockSupabase.from).toHaveBeenCalledWith('documents');
      expect(mockInsert).toHaveBeenCalledWith(
        expect.objectContaining({
          document_id: 'doc-1',
          user_id: 'user-1',
          file_name: 'statement.pdf',
          document_type: 'mortgage_statement',
          analysis_results: { findings: [] }
        })
      );
    });

    it('converts base64 content to Buffer for storage', async () => {
      mockSingle.mockResolvedValue({ data: { document_id: 'doc-1' }, error: null });

      await documentService.uploadDocument(uploadArgs);

      const uploadedBuffer = mockStorageUpload.mock.calls[0][1];
      expect(Buffer.isBuffer(uploadedBuffer)).toBe(true);
      expect(uploadedBuffer.toString()).toBe('mock-pdf-content');
    });

    it('throws on storage error', async () => {
      mockStorageUpload.mockResolvedValue({
        data: null,
        error: { message: 'Bucket full' }
      });

      await expect(documentService.uploadDocument(uploadArgs))
        .rejects.toThrow('Storage error: Bucket full');
    });

    it('throws on database error', async () => {
      mockSingle.mockResolvedValue({
        data: null,
        error: { message: 'Constraint violation' }
      });

      await expect(documentService.uploadDocument(uploadArgs))
        .rejects.toThrow('Database error: Constraint violation');
    });

    it('sets null analysisResults when not provided', async () => {
      mockSingle.mockResolvedValue({ data: { document_id: 'doc-2' }, error: null });

      await documentService.uploadDocument({
        ...uploadArgs,
        analysisResults: undefined,
        metadata: undefined
      });

      expect(mockInsert).toHaveBeenCalledWith(
        expect.objectContaining({
          analysis_results: null,
          metadata: {}
        })
      );
    });
  });

  // ----------------------------------------------------------
  // getDocumentsByUser
  // ----------------------------------------------------------
  describe('getDocumentsByUser', () => {
    it('returns documents filtered by userId', async () => {
      const docs = [{ document_id: 'doc-1' }, { document_id: 'doc-2' }];
      mockRange.mockResolvedValue({ data: docs, error: null });

      const result = await documentService.getDocumentsByUser({ userId: 'user-1' });

      expect(result).toEqual(docs);
      expect(mockSupabase.from).toHaveBeenCalledWith('documents');
      expect(mockEq).toHaveBeenCalledWith('user_id', 'user-1');
    });

    it('applies limit and offset defaults', async () => {
      mockRange.mockResolvedValue({ data: [], error: null });

      await documentService.getDocumentsByUser({ userId: 'user-1' });

      // Default: limit=50, offset=0 → range(0, 49)
      expect(mockRange).toHaveBeenCalledWith(0, 49);
      expect(mockOrder).toHaveBeenCalledWith('created_at', { ascending: false });
    });

    it('applies custom limit and offset', async () => {
      mockRange.mockResolvedValue({ data: [], error: null });

      await documentService.getDocumentsByUser({ userId: 'user-1', limit: 10, offset: 20 });

      expect(mockRange).toHaveBeenCalledWith(20, 29);
    });

    it('returns empty array when data is null', async () => {
      mockRange.mockResolvedValue({ data: null, error: null });

      const result = await documentService.getDocumentsByUser({ userId: 'user-1' });

      expect(result).toEqual([]);
    });

    it('throws on database error', async () => {
      mockRange.mockResolvedValue({ data: null, error: { message: 'Query timeout' } });

      await expect(documentService.getDocumentsByUser({ userId: 'user-1' }))
        .rejects.toThrow('Database error: Query timeout');
    });
  });

  // ----------------------------------------------------------
  // getDocument
  // ----------------------------------------------------------
  describe('getDocument', () => {
    it('returns metadata and base64 content', async () => {
      const metadata = {
        document_id: 'doc-1',
        storage_path: 'documents/user-1/doc-1',
        file_name: 'test.pdf'
      };
      // First single() call returns metadata
      mockSingle.mockResolvedValue({ data: metadata, error: null });

      // Storage download returns file data
      const fileContent = Buffer.from('file-content');
      const mockBlob = {
        arrayBuffer: jest.fn().mockResolvedValue(fileContent.buffer.slice(
          fileContent.byteOffset,
          fileContent.byteOffset + fileContent.byteLength
        ))
      };
      mockStorageDownload.mockResolvedValue({ data: mockBlob, error: null });

      const result = await documentService.getDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      expect(result.document_id).toBe('doc-1');
      expect(result.content).toBe(fileContent.toString('base64'));
      expect(mockEq).toHaveBeenCalledWith('document_id', 'doc-1');
      expect(mockEq).toHaveBeenCalledWith('user_id', 'user-1');
    });

    it('returns null when document not found', async () => {
      mockSingle.mockResolvedValue({ data: null, error: null });

      const result = await documentService.getDocument({
        documentId: 'nonexistent',
        userId: 'user-1'
      });

      expect(result).toBeNull();
    });

    it('returns metadata only when download fails', async () => {
      const metadata = {
        document_id: 'doc-1',
        storage_path: 'documents/user-1/doc-1'
      };
      mockSingle.mockResolvedValue({ data: metadata, error: null });
      mockStorageDownload.mockResolvedValue({
        data: null,
        error: { message: 'File not found in storage' }
      });

      const result = await documentService.getDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      // Returns metadata without content field
      expect(result).toEqual(metadata);
      expect(result.content).toBeUndefined();
    });

    it('throws on database error', async () => {
      mockSingle.mockResolvedValue({
        data: null,
        error: { message: 'Connection lost' }
      });

      await expect(documentService.getDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      })).rejects.toThrow('Database error: Connection lost');
    });
  });

  // ----------------------------------------------------------
  // deleteDocument
  // ----------------------------------------------------------
  describe('deleteDocument', () => {
    // Helper: set up the two-phase delete mock chain.
    // Phase 1 (SELECT): from → select → eq → eq → single → returns doc
    // Phase 2 (DELETE): from → delete → eq → eq → resolves with { error }
    // Since `await mockSupabase` resolves to mockSupabase itself (plain object),
    // and mockSupabase has no `error` property, dbError is undefined → happy path.
    function setupDeleteMocks({ docData, storageError = null, dbDeleteError = null }) {
      mockEq.mockReturnValue(mockSupabase);
      mockSingle.mockResolvedValue({ data: docData });
      mockStorageRemove.mockResolvedValue({
        data: storageError ? null : {},
        error: storageError
      });

      if (dbDeleteError) {
        // For DB delete error: last eq in delete chain must return { error }
        // Track from() calls to know when we're in the delete phase
        let fromCalls = 0;
        let eqCalls = 0;
        mockSupabase.from.mockImplementation(() => { fromCalls++; return mockSupabase; });
        mockEq.mockImplementation(() => {
          eqCalls++;
          // 4th eq call is the terminal eq in the delete chain (2 in select, 2 in delete)
          if (fromCalls >= 2 && eqCalls >= 4) {
            return Promise.resolve({ error: dbDeleteError });
          }
          return mockSupabase;
        });
      }
    }

    it('deletes from storage and database', async () => {
      setupDeleteMocks({ docData: { storage_path: 'documents/user-1/doc-1' } });

      const result = await documentService.deleteDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      expect(result).toEqual({ success: true });
      expect(mockStorageRemove).toHaveBeenCalledWith(['documents/user-1/doc-1']);
      expect(mockSupabase.from).toHaveBeenCalledWith('documents');
    });

    it('throws when document not found', async () => {
      setupDeleteMocks({ docData: null });

      await expect(documentService.deleteDocument({
        documentId: 'nonexistent',
        userId: 'user-1'
      })).rejects.toThrow('Document not found');
    });

    it('continues delete when storage deletion fails', async () => {
      setupDeleteMocks({
        docData: { storage_path: 'documents/user-1/doc-1' },
        storageError: { message: 'Storage unavailable' }
      });

      const result = await documentService.deleteDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      // Should succeed despite storage error (logged as warning)
      expect(result).toEqual({ success: true });
    });

    it('throws on database delete error', async () => {
      setupDeleteMocks({
        docData: { storage_path: 'documents/user-1/doc-1' },
        dbDeleteError: { message: 'FK constraint' }
      });

      await expect(documentService.deleteDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      })).rejects.toThrow('Database error: FK constraint');
    });
  });

  // ----------------------------------------------------------
  // getContentType
  // ----------------------------------------------------------
  describe('getContentType', () => {
    it('returns application/pdf for .pdf', () => {
      expect(documentService.getContentType('doc.pdf')).toBe('application/pdf');
    });

    it('returns image/jpeg for .jpg', () => {
      expect(documentService.getContentType('photo.jpg')).toBe('image/jpeg');
    });

    it('returns image/jpeg for .jpeg', () => {
      expect(documentService.getContentType('photo.jpeg')).toBe('image/jpeg');
    });

    it('returns image/png for .png', () => {
      expect(documentService.getContentType('screenshot.png')).toBe('image/png');
    });

    it('returns image/heic for .heic', () => {
      expect(documentService.getContentType('photo.heic')).toBe('image/heic');
    });

    it('returns text/plain for .txt', () => {
      expect(documentService.getContentType('notes.txt')).toBe('text/plain');
    });

    it('returns application/octet-stream for unknown extension', () => {
      expect(documentService.getContentType('file.xyz')).toBe('application/octet-stream');
    });
  });
});

// ============================================================
// Mock mode tests (no Supabase configured)
// ============================================================
describe('DocumentService (mock mode)', () => {
  let mockDocService;

  beforeEach(() => {
    jest.isolateModules(() => {
      delete process.env.SUPABASE_URL;
      delete process.env.SUPABASE_SERVICE_KEY;
      mockDocService = require('../../services/documentService');
    });
    process.env.SUPABASE_URL = 'https://test.supabase.co';
    process.env.SUPABASE_SERVICE_KEY = 'test-service-key';
  });

  it('mockUploadDocument stores in memory', async () => {
    const result = await mockDocService.uploadDocument({
      documentId: 'mock-doc-1',
      userId: 'user-1',
      fileName: 'test.pdf',
      documentType: 'mortgage_statement',
      content: 'base64data'
    });

    expect(result.documentId).toBe('mock-doc-1');
    expect(result.storagePath).toContain('mock://');
  });

  it('mockGetDocumentsByUser returns user documents', async () => {
    await mockDocService.uploadDocument({
      documentId: 'doc-a',
      userId: 'user-1',
      fileName: 'a.pdf',
      documentType: 'pdf',
      content: 'data'
    });
    await mockDocService.uploadDocument({
      documentId: 'doc-b',
      userId: 'user-2',
      fileName: 'b.pdf',
      documentType: 'pdf',
      content: 'data'
    });

    const docs = await mockDocService.getDocumentsByUser({ userId: 'user-1' });

    expect(docs).toHaveLength(1);
    expect(docs[0].document_id).toBe('doc-a');
  });

  it('mockGetDocument returns document by ID and userId', async () => {
    await mockDocService.uploadDocument({
      documentId: 'doc-get',
      userId: 'user-1',
      fileName: 'get.pdf',
      documentType: 'pdf',
      content: 'data'
    });

    const doc = await mockDocService.getDocument({
      documentId: 'doc-get',
      userId: 'user-1'
    });

    expect(doc.document_id).toBe('doc-get');
    expect(doc.file_name).toBe('get.pdf');
  });

  it('mockGetDocument returns null for wrong userId', async () => {
    await mockDocService.uploadDocument({
      documentId: 'doc-owned',
      userId: 'user-1',
      fileName: 'owned.pdf',
      documentType: 'pdf',
      content: 'data'
    });

    const doc = await mockDocService.getDocument({
      documentId: 'doc-owned',
      userId: 'user-other'
    });

    expect(doc).toBeNull();
  });

  it('mockDeleteDocument removes document', async () => {
    await mockDocService.uploadDocument({
      documentId: 'doc-del',
      userId: 'user-1',
      fileName: 'del.pdf',
      documentType: 'pdf',
      content: 'data'
    });

    const result = await mockDocService.deleteDocument({
      documentId: 'doc-del',
      userId: 'user-1'
    });
    expect(result).toEqual({ success: true });

    // Verify it's gone
    const doc = await mockDocService.getDocument({
      documentId: 'doc-del',
      userId: 'user-1'
    });
    expect(doc).toBeNull();
  });

  it('mockDeleteDocument throws for missing document', async () => {
    await expect(mockDocService.deleteDocument({
      documentId: 'nonexistent',
      userId: 'user-1'
    })).rejects.toThrow('Document not found');
  });
});
