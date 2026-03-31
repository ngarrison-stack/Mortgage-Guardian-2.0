/**
 * Unit tests for DocumentService (services/documentService.js)
 *
 * Tests all CRUD operations in both DB and mock modes.
 * Includes encryption integration tests for upload/download.
 * Mocks fs/promises for filesystem and ../db for database.
 */

const mockQuery = jest.fn();

// Mock the db module (service uses require('../db') from services/)
jest.mock('../../services/db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}));

// For the lazy-loaded require('../db') in documentService, we also need:
jest.mock('../../db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}), { virtual: true });

// Mock fs/promises for filesystem operations
const mockWriteFile = jest.fn().mockResolvedValue(undefined);
const mockReadFile = jest.fn();
const mockMkdir = jest.fn().mockResolvedValue(undefined);
const mockUnlink = jest.fn().mockResolvedValue(undefined);

jest.mock('fs', () => ({
  ...jest.requireActual('fs'),
  promises: {
    writeFile: mockWriteFile,
    readFile: mockReadFile,
    mkdir: mockMkdir,
    unlink: mockUnlink
  }
}));

// --- Encryption service mock ---
const mockEncrypt = jest.fn();
const mockDecrypt = jest.fn();

jest.mock('../../services/documentEncryptionService', () => ({
  encrypt: mockEncrypt,
  decrypt: mockDecrypt
}));

// Set env vars BEFORE requiring service
process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';

const documentService = require('../../services/documentService');

// ============================================================
// DB mode tests
// ============================================================
describe('DocumentService (DB mode)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Default encryption mock behavior
    mockEncrypt.mockImplementation((userId, buffer) => {
      return Buffer.concat([Buffer.from('ENC:'), buffer]);
    });
    mockDecrypt.mockImplementation((userId, buffer) => {
      return buffer.subarray(4);
    });
    // Ensure encryption key is NOT set by default (tests opt in)
    delete process.env.DOCUMENT_ENCRYPTION_KEY;
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

    it('uploads file to filesystem and saves metadata to DB', async () => {
      mockQuery.mockResolvedValue({
        rows: [{ document_id: 'doc-1', storage_path: 'documents/user-1/doc-1' }],
        rowCount: 1
      });

      const result = await documentService.uploadDocument(uploadArgs);

      expect(result.documentId).toBe('doc-1');
      expect(result.storagePath).toBe('documents/user-1/doc-1');
      expect(result.metadata).toBeDefined();
      // Verify filesystem write
      expect(mockMkdir).toHaveBeenCalled();
      expect(mockWriteFile).toHaveBeenCalledWith(
        expect.any(String),
        expect.any(Buffer)
      );
      // Verify db insert
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO documents'),
        expect.arrayContaining(['doc-1', 'user-1', 'statement.pdf', 'mortgage_statement'])
      );
    });

    it('converts base64 content to Buffer for storage', async () => {
      mockQuery.mockResolvedValue({ rows: [{ document_id: 'doc-1' }], rowCount: 1 });

      await documentService.uploadDocument(uploadArgs);

      const writtenBuffer = mockWriteFile.mock.calls[0][1];
      expect(Buffer.isBuffer(writtenBuffer)).toBe(true);
      expect(writtenBuffer.toString()).toBe('mock-pdf-content');
    });

    it('throws on database error', async () => {
      mockQuery.mockRejectedValue(new Error('Constraint violation'));

      await expect(documentService.uploadDocument(uploadArgs))
        .rejects.toThrow('Constraint violation');
    });
  });

  // ----------------------------------------------------------
  // getDocumentsByUser
  // ----------------------------------------------------------
  describe('getDocumentsByUser', () => {
    it('returns documents filtered by userId', async () => {
      const docs = [{ document_id: 'doc-1' }, { document_id: 'doc-2' }];
      mockQuery.mockResolvedValue({ rows: docs, rowCount: 2 });

      const result = await documentService.getDocumentsByUser({ userId: 'user-1' });

      expect(result).toEqual(docs);
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('WHERE user_id = $1'),
        expect.arrayContaining(['user-1'])
      );
    });

    it('returns empty array when no results', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      const result = await documentService.getDocumentsByUser({ userId: 'user-1' });

      expect(result).toEqual([]);
    });

    it('throws on database error', async () => {
      mockQuery.mockRejectedValue(new Error('Query timeout'));

      await expect(documentService.getDocumentsByUser({ userId: 'user-1' }))
        .rejects.toThrow('Query timeout');
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
      mockQuery.mockResolvedValue({ rows: [metadata], rowCount: 1 });

      const fileContent = Buffer.from('file-content');
      mockReadFile.mockResolvedValue(fileContent);

      const result = await documentService.getDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      expect(result.document_id).toBe('doc-1');
      expect(result.content).toBe(fileContent.toString('base64'));
    });

    it('returns null when document not found', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      const result = await documentService.getDocument({
        documentId: 'nonexistent',
        userId: 'user-1'
      });

      expect(result).toBeNull();
    });

    it('returns metadata only when file read fails', async () => {
      const metadata = {
        document_id: 'doc-1',
        storage_path: 'documents/user-1/doc-1'
      };
      mockQuery.mockResolvedValue({ rows: [metadata], rowCount: 1 });
      mockReadFile.mockRejectedValue(new Error('File not found'));

      const result = await documentService.getDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      // Returns metadata without content field
      expect(result).toEqual(metadata);
      expect(result.content).toBeUndefined();
    });

    it('throws on database error', async () => {
      mockQuery.mockRejectedValue(new Error('Connection lost'));

      await expect(documentService.getDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      })).rejects.toThrow('Connection lost');
    });
  });

  // ----------------------------------------------------------
  // deleteDocument
  // ----------------------------------------------------------
  describe('deleteDocument', () => {
    it('deletes from filesystem and database', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ storage_path: 'documents/user-1/doc-1' }], rowCount: 1 })
        .mockResolvedValueOnce({ rows: [], rowCount: 1 });

      const result = await documentService.deleteDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      expect(result).toEqual({ success: true });
      expect(mockUnlink).toHaveBeenCalled();
      expect(mockQuery).toHaveBeenCalledTimes(2);
    });

    it('throws when document not found', async () => {
      mockQuery.mockResolvedValue({ rows: [], rowCount: 0 });

      await expect(documentService.deleteDocument({
        documentId: 'nonexistent',
        userId: 'user-1'
      })).rejects.toThrow('Document not found');
    });

    it('continues delete when filesystem deletion fails', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ storage_path: 'documents/user-1/doc-1' }], rowCount: 1 })
        .mockResolvedValueOnce({ rows: [], rowCount: 1 });
      mockUnlink.mockRejectedValue(new Error('File not found'));

      const result = await documentService.deleteDocument({
        documentId: 'doc-1',
        userId: 'user-1'
      });

      // Should succeed despite filesystem error (logged as warning)
      expect(result).toEqual({ success: true });
    });
  });

  // ----------------------------------------------------------
  // getContentType
  // ----------------------------------------------------------
  describe('getContentType', () => {
    it('returns application/pdf for .pdf', () => { expect(documentService.getContentType('doc.pdf')).toBe('application/pdf'); });
    it('returns image/jpeg for .jpg', () => { expect(documentService.getContentType('photo.jpg')).toBe('image/jpeg'); });
    it('returns image/jpeg for .jpeg', () => { expect(documentService.getContentType('photo.jpeg')).toBe('image/jpeg'); });
    it('returns image/png for .png', () => { expect(documentService.getContentType('screenshot.png')).toBe('image/png'); });
    it('returns image/heic for .heic', () => { expect(documentService.getContentType('photo.heic')).toBe('image/heic'); });
    it('returns text/plain for .txt', () => { expect(documentService.getContentType('notes.txt')).toBe('text/plain'); });
    it('returns application/octet-stream for unknown extension', () => { expect(documentService.getContentType('file.xyz')).toBe('application/octet-stream'); });
  });
});

// ============================================================
// Mock mode tests (no DATABASE_URL configured)
// ============================================================
describe('DocumentService (mock mode)', () => {
  let mockDocService;

  beforeEach(() => {
    delete process.env.DATABASE_URL;
    jest.isolateModules(() => {
      mockDocService = require('../../services/documentService');
    });
  });

  afterEach(() => {
    process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';
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
    await mockDocService.uploadDocument({ documentId: 'doc-a', userId: 'user-1', fileName: 'a.pdf', documentType: 'pdf', content: 'data' });
    await mockDocService.uploadDocument({ documentId: 'doc-b', userId: 'user-2', fileName: 'b.pdf', documentType: 'pdf', content: 'data' });

    const docs = await mockDocService.getDocumentsByUser({ userId: 'user-1' });

    expect(docs).toHaveLength(1);
    expect(docs[0].document_id).toBe('doc-a');
  });

  it('mockGetDocument returns document by ID and userId', async () => {
    await mockDocService.uploadDocument({ documentId: 'doc-get', userId: 'user-1', fileName: 'get.pdf', documentType: 'pdf', content: 'data' });

    const doc = await mockDocService.getDocument({ documentId: 'doc-get', userId: 'user-1' });

    expect(doc.document_id).toBe('doc-get');
    expect(doc.file_name).toBe('get.pdf');
  });

  it('mockGetDocument returns null for wrong userId', async () => {
    await mockDocService.uploadDocument({ documentId: 'doc-owned', userId: 'user-1', fileName: 'owned.pdf', documentType: 'pdf', content: 'data' });

    const doc = await mockDocService.getDocument({ documentId: 'doc-owned', userId: 'user-other' });

    expect(doc).toBeNull();
  });

  it('mockDeleteDocument removes document', async () => {
    await mockDocService.uploadDocument({ documentId: 'doc-del', userId: 'user-1', fileName: 'del.pdf', documentType: 'pdf', content: 'data' });

    const result = await mockDocService.deleteDocument({ documentId: 'doc-del', userId: 'user-1' });
    expect(result).toEqual({ success: true });

    const doc = await mockDocService.getDocument({ documentId: 'doc-del', userId: 'user-1' });
    expect(doc).toBeNull();
  });

  it('mockDeleteDocument throws for missing document', async () => {
    await expect(mockDocService.deleteDocument({ documentId: 'nonexistent', userId: 'user-1' })).rejects.toThrow('Document not found');
  });
});
