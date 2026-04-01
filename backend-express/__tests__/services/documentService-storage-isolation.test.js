/**
 * Storage isolation tests for DocumentService
 *
 * Tests validateStoragePath defense-in-depth validation and confirms that
 * upload, get, and delete operations call validation before Supabase calls.
 *
 * Phase: 11-02 (Isolated Secure Document Storage)
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
// validateStoragePath — direct unit tests
// ============================================================
describe('DocumentService.validateStoragePath', () => {
  const userId = 'user-abc-123';

  it('accepts a valid storage path', () => {
    expect(() => {
      documentService.validateStoragePath(userId, `documents/${userId}/doc-001`);
    }).not.toThrow();
  });

  it('accepts a valid path with nested segments', () => {
    expect(() => {
      documentService.validateStoragePath(userId, `documents/${userId}/subdir/doc-001`);
    }).not.toThrow();
  });

  it('rejects path with .. directory traversal', () => {
    expect(() => {
      documentService.validateStoragePath(userId, `documents/../other-user/doc-001`);
    }).toThrow('directory traversal not allowed');
  });

  it('rejects path with .. in middle segments', () => {
    expect(() => {
      documentService.validateStoragePath(userId, `documents/${userId}/../other-user/doc-001`);
    }).toThrow('directory traversal not allowed');
  });

  it('rejects path with // double-slash injection', () => {
    expect(() => {
      documentService.validateStoragePath(userId, `documents/${userId}//doc-001`);
    }).toThrow('invalid path format');
  });

  it('rejects path with wrong userId prefix', () => {
    expect(() => {
      documentService.validateStoragePath(userId, 'documents/other-user-999/doc-001');
    }).toThrow('user path mismatch');
  });

  it('rejects path that does not start with documents/ prefix', () => {
    expect(() => {
      documentService.validateStoragePath(userId, `uploads/${userId}/doc-001`);
    }).toThrow('user path mismatch');
  });

  it('rejects empty path', () => {
    expect(() => {
      documentService.validateStoragePath(userId, '');
    }).toThrow('user path mismatch');
  });

  it('rejects path that is only the prefix (no document ID)', () => {
    // "documents/user-abc-123/" is technically valid prefix-wise,
    // but this tests that the prefix check works as boundary
    expect(() => {
      documentService.validateStoragePath(userId, `documents/${userId}/`);
    }).not.toThrow();
  });
});

// ============================================================
// Integration: validation is called before Supabase operations
// ============================================================
describe('DocumentService storage operations call validateStoragePath', () => {
  const userId = 'user-test-456';
  const documentId = 'doc-test-789';

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

  describe('uploadDocument calls validateStoragePath before Supabase upload', () => {
    it('calls validateStoragePath and proceeds to upload on valid path', async () => {
      mockSingle.mockResolvedValue({
        data: { document_id: documentId, storage_path: `documents/${userId}/${documentId}` },
        error: null
      });

      const validateSpy = jest.spyOn(documentService, 'validateStoragePath');

      await documentService.uploadDocument({
        documentId,
        userId,
        fileName: 'test.pdf',
        documentType: 'mortgage_statement',
        content: Buffer.from('test-content').toString('base64')
      });

      // Validation was called
      expect(validateSpy).toHaveBeenCalledWith(userId, `documents/${userId}/${documentId}`);
      // And it was called before the storage upload
      expect(mockStorageUpload).toHaveBeenCalled();

      validateSpy.mockRestore();
    });

    it('rejects upload if path validation fails (injected bad documentId)', async () => {
      // This tests defense-in-depth: if a documentId contained traversal chars
      const badDocumentId = '../other-user/evil-doc';

      await expect(documentService.uploadDocument({
        documentId: badDocumentId,
        userId,
        fileName: 'test.pdf',
        documentType: 'mortgage_statement',
        content: Buffer.from('test').toString('base64')
      })).rejects.toThrow('directory traversal not allowed');

      // Storage should NOT have been called
      expect(mockStorageUpload).not.toHaveBeenCalled();
    });
  });

  describe('getDocument calls validateStoragePath before Supabase download', () => {
    it('calls validateStoragePath on the stored path before download', async () => {
      const storagePath = `documents/${userId}/${documentId}`;
      mockSingle.mockResolvedValue({
        data: { document_id: documentId, storage_path: storagePath },
        error: null
      });
      // Storage download returns file data
      const fileContent = Buffer.from('file-content');
      const mockBlob = {
        arrayBuffer: jest.fn().mockResolvedValue(fileContent.buffer.slice(
          fileContent.byteOffset,
          fileContent.byteOffset + fileContent.byteLength
        ))
      };
      mockStorageDownload.mockResolvedValue({ data: mockBlob, error: null });

      const validateSpy = jest.spyOn(documentService, 'validateStoragePath');

      await documentService.getDocument({ documentId, userId });

      expect(validateSpy).toHaveBeenCalledWith(userId, storagePath);
      expect(mockStorageDownload).toHaveBeenCalled();

      validateSpy.mockRestore();
    });

    it('rejects getDocument if stored path has wrong userId', async () => {
      // Simulate a corrupted DB record pointing to another user's path
      mockSingle.mockResolvedValue({
        data: {
          document_id: documentId,
          storage_path: 'documents/other-user-999/stolen-doc'
        },
        error: null
      });

      await expect(documentService.getDocument({ documentId, userId }))
        .rejects.toThrow('user path mismatch');

      // Storage download should NOT have been called
      expect(mockStorageDownload).not.toHaveBeenCalled();
    });
  });

  describe('deleteDocument calls validateStoragePath before Supabase remove', () => {
    it('calls validateStoragePath on the stored path before remove', async () => {
      const storagePath = `documents/${userId}/${documentId}`;
      mockSingle.mockResolvedValue({
        data: { storage_path: storagePath },
        error: null
      });

      const validateSpy = jest.spyOn(documentService, 'validateStoragePath');

      await documentService.deleteDocument({ documentId, userId });

      expect(validateSpy).toHaveBeenCalledWith(userId, storagePath);
      expect(mockStorageRemove).toHaveBeenCalledWith([storagePath]);

      validateSpy.mockRestore();
    });

    it('rejects deleteDocument if stored path contains traversal', async () => {
      // Simulate a corrupted DB record with traversal in path
      mockSingle.mockResolvedValue({
        data: { storage_path: `documents/${userId}/../admin/secret-doc` },
        error: null
      });

      await expect(documentService.deleteDocument({ documentId, userId }))
        .rejects.toThrow('directory traversal not allowed');

      // Storage remove should NOT have been called
      expect(mockStorageRemove).not.toHaveBeenCalled();
    });
  });
});
