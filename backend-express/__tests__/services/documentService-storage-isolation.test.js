/**
 * Storage isolation tests for DocumentService
 *
 * Tests validateStoragePath defense-in-depth validation.
 * Since documentService now uses local filesystem + pg,
 * these tests focus on the path validation logic.
 *
 * Phase: 11-02 (Isolated Secure Document Storage)
 */

// Shared mock for query function
const sharedMockQuery = jest.fn();

// Mock db and fs so the service can load
jest.mock('../../services/db', () => ({ query: sharedMockQuery, pool: { connect: jest.fn() } }));
jest.mock('../../db', () => ({ query: sharedMockQuery, pool: { connect: jest.fn() } }), { virtual: true });
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

// ============================================================
// validateStoragePath — direct unit tests
// ============================================================
describe('DocumentService.validateStoragePath', () => {
  const userId = 'user-abc-123';

  it('accepts a valid storage path', () => {
    expect(() => { documentService.validateStoragePath(userId, `documents/${userId}/doc-001`); }).not.toThrow();
  });

  it('accepts a valid path with nested segments', () => {
    expect(() => { documentService.validateStoragePath(userId, `documents/${userId}/subdir/doc-001`); }).not.toThrow();
  });

  it('rejects path with .. directory traversal', () => {
    expect(() => { documentService.validateStoragePath(userId, `documents/../other-user/doc-001`); }).toThrow('directory traversal not allowed');
  });

  it('rejects path with .. in middle segments', () => {
    expect(() => { documentService.validateStoragePath(userId, `documents/${userId}/../other-user/doc-001`); }).toThrow('directory traversal not allowed');
  });

  it('rejects path with // double-slash injection', () => {
    expect(() => { documentService.validateStoragePath(userId, `documents/${userId}//doc-001`); }).toThrow('invalid path format');
  });

  it('rejects path with wrong userId prefix', () => {
    expect(() => { documentService.validateStoragePath(userId, 'documents/other-user-999/doc-001'); }).toThrow('user path mismatch');
  });

  it('rejects path that does not start with documents/ prefix', () => {
    expect(() => { documentService.validateStoragePath(userId, `uploads/${userId}/doc-001`); }).toThrow('user path mismatch');
  });

  it('rejects empty path', () => {
    expect(() => { documentService.validateStoragePath(userId, ''); }).toThrow('user path mismatch');
  });

  it('rejects path that is only the prefix (no document ID)', () => {
    expect(() => { documentService.validateStoragePath(userId, `documents/${userId}/`); }).not.toThrow();
  });
});

// ============================================================
// Integration: validation is called before storage operations
// ============================================================
describe('DocumentService storage operations call validateStoragePath', () => {
  const userId = 'user-test-456';
  const documentId = 'doc-test-789';
  const mockQuery = sharedMockQuery;
  const mockFs = require('fs').promises;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('uploadDocument calls validateStoragePath before filesystem write', () => {
    it('calls validateStoragePath and proceeds to upload on valid path', async () => {
      mockQuery.mockResolvedValue({
        rows: [{ document_id: documentId, storage_path: `documents/${userId}/${documentId}` }],
        rowCount: 1
      });

      const validateSpy = jest.spyOn(documentService, 'validateStoragePath');

      await documentService.uploadDocument({
        documentId,
        userId,
        fileName: 'test.pdf',
        documentType: 'mortgage_statement',
        content: Buffer.from('test-content').toString('base64')
      });

      expect(validateSpy).toHaveBeenCalledWith(userId, `documents/${userId}/${documentId}`);
      expect(mockFs.writeFile).toHaveBeenCalled();

      validateSpy.mockRestore();
    });

    it('rejects upload if path validation fails (injected bad documentId)', async () => {
      const badDocumentId = '../other-user/evil-doc';

      await expect(documentService.uploadDocument({
        documentId: badDocumentId,
        userId,
        fileName: 'test.pdf',
        documentType: 'mortgage_statement',
        content: Buffer.from('test').toString('base64')
      })).rejects.toThrow('directory traversal not allowed');

      expect(mockFs.writeFile).not.toHaveBeenCalled();
    });
  });

  describe('getDocument calls validateStoragePath before filesystem read', () => {
    it('calls validateStoragePath on the stored path before read', async () => {
      const storagePath = `documents/${userId}/${documentId}`;
      mockQuery.mockResolvedValue({
        rows: [{ document_id: documentId, storage_path: storagePath }],
        rowCount: 1
      });
      mockFs.readFile.mockResolvedValue(Buffer.from('file-content'));

      const validateSpy = jest.spyOn(documentService, 'validateStoragePath');

      await documentService.getDocument({ documentId, userId });

      expect(validateSpy).toHaveBeenCalledWith(userId, storagePath);
      expect(mockFs.readFile).toHaveBeenCalled();

      validateSpy.mockRestore();
    });

    it('rejects getDocument if stored path has wrong userId', async () => {
      mockQuery.mockResolvedValue({
        rows: [{ document_id: documentId, storage_path: 'documents/other-user-999/stolen-doc' }],
        rowCount: 1
      });

      await expect(documentService.getDocument({ documentId, userId }))
        .rejects.toThrow('user path mismatch');

      expect(mockFs.readFile).not.toHaveBeenCalled();
    });
  });

  describe('deleteDocument calls validateStoragePath before filesystem remove', () => {
    it('calls validateStoragePath on the stored path before remove', async () => {
      const storagePath = `documents/${userId}/${documentId}`;
      mockQuery
        .mockResolvedValueOnce({ rows: [{ storage_path: storagePath }], rowCount: 1 })
        .mockResolvedValueOnce({ rows: [], rowCount: 1 });

      const validateSpy = jest.spyOn(documentService, 'validateStoragePath');

      await documentService.deleteDocument({ documentId, userId });

      expect(validateSpy).toHaveBeenCalledWith(userId, storagePath);
      expect(mockFs.unlink).toHaveBeenCalled();

      validateSpy.mockRestore();
    });

    it('rejects deleteDocument if stored path contains traversal', async () => {
      mockQuery.mockResolvedValue({
        rows: [{ storage_path: `documents/${userId}/../admin/secret-doc` }],
        rowCount: 1
      });

      await expect(documentService.deleteDocument({ documentId, userId }))
        .rejects.toThrow('directory traversal not allowed');

      expect(mockFs.unlink).not.toHaveBeenCalled();
    });
  });
});
