/**
 * Encrypted Document Lifecycle Integration Tests
 *
 * Verifies the complete encrypted document lifecycle including:
 * - Encrypt/decrypt round-trip through documentService
 * - Backward compatibility with unencrypted documents
 * - Graceful handling when encryption key is missing
 * - Per-user key isolation (different outputs for same content)
 * - Cross-user decryption failure (user-A cannot decrypt user-B's data)
 * - Pipeline encryption integration (stored documents are encrypted)
 *
 * These tests exercise the real documentEncryptionService (not mocked)
 * while mocking only external boundaries (filesystem, database).
 */

const crypto = require('crypto');

// Generate a test master key (32 bytes = 64 hex chars)
const TEST_MASTER_KEY = crypto.randomBytes(32).toString('hex');

// ============================================================
// MOCKS — set up before any module imports
// ============================================================

// Track buffers passed to filesystem for verification
let capturedUploadBuffer = null;
let capturedUploadPath = null;

const mockQuery = jest.fn();

// Mock the db module
jest.mock('../../services/db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}));

jest.mock('../../db', () => ({
  query: mockQuery,
  pool: { connect: jest.fn() }
}), { virtual: true });

// Mock fs/promises
const mockWriteFile = jest.fn(async (filePath, buffer) => {
  capturedUploadPath = filePath;
  capturedUploadBuffer = Buffer.from(buffer);
});
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

// ============================================================
// TEST SETUP
// ============================================================

let documentService;
let DocumentEncryptionService;

// Track database inserts to verify encrypted flag
let capturedDbInsert = null;

beforeAll(() => {
  // Set encryption key before loading modules
  process.env.DOCUMENT_ENCRYPTION_KEY = TEST_MASTER_KEY;
  process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';

  // Clear module cache to get fresh instances with our mocks
  const modulesToClear = [
    '../../services/documentService',
    '../../services/documentEncryptionService'
  ];
  for (const mod of modulesToClear) {
    try { delete require.cache[require.resolve(mod)]; } catch { /* Not cached yet */ }
  }

  documentService = require('../../services/documentService');
  DocumentEncryptionService = require('../../services/documentEncryptionService');
});

beforeEach(() => {
  capturedUploadBuffer = null;
  capturedUploadPath = null;
  capturedDbInsert = null;
  mockQuery.mockReset();
  mockWriteFile.mockClear();
  mockReadFile.mockReset();
  mockMkdir.mockClear();
  mockUnlink.mockClear();

  // Default mock for db.query on INSERT: capture data and return it
  mockQuery.mockImplementation(async (sql, params) => {
    if (sql.includes('INSERT INTO documents')) {
      capturedDbInsert = {
        document_id: params[0],
        user_id: params[1],
        file_name: params[2],
        document_type: params[3],
        analysis_results: params[4],
        metadata: params[5],
        storage_path: params[6],
        encrypted: params[7]
      };
      return { rows: [capturedDbInsert], rowCount: 1 };
    }
    if (sql.includes('SELECT') && sql.includes('documents')) {
      return { rows: [], rowCount: 0 };
    }
    return { rows: [], rowCount: 0 };
  });

  // Default mock for writeFile: capture buffer
  mockWriteFile.mockImplementation(async (filePath, buffer) => {
    capturedUploadPath = filePath;
    capturedUploadBuffer = Buffer.from(buffer);
  });
});

afterAll(() => {
  delete process.env.DOCUMENT_ENCRYPTION_KEY;
  delete process.env.DATABASE_URL;
});

// ============================================================
// ENCRYPTED DOCUMENT LIFECYCLE
// ============================================================
describe('Encrypted Document Lifecycle', () => {

  test('encrypts document on upload and decrypts on download (round-trip)', async () => {
    const userId = 'user-roundtrip-123';
    const documentId = 'doc-roundtrip-001';
    const originalContent = 'This is a sensitive mortgage document with PII data.';
    const contentBase64 = Buffer.from(originalContent).toString('base64');

    // Upload document
    await documentService.uploadDocument({
      documentId, userId,
      fileName: 'mortgage-statement.pdf',
      documentType: 'mortgage_statement',
      content: contentBase64,
      analysisResults: null,
      metadata: {}
    });

    // Verify the buffer written to filesystem is NOT the original plaintext
    expect(capturedUploadBuffer).not.toBeNull();
    const originalBuffer = Buffer.from(originalContent);
    expect(capturedUploadBuffer.equals(originalBuffer)).toBe(false);

    // Verify the buffer starts with a 12-byte IV (not recognizable as original format)
    expect(capturedUploadBuffer.length).toBeGreaterThan(28); // iv(12) + authTag(16) + ciphertext

    // Verify the encrypted flag was set in the database
    expect(capturedDbInsert).toBeDefined();
    expect(capturedDbInsert.encrypted).toBe(true);

    // Now download the document — mock filesystem to return the encrypted buffer
    const encryptedBuf = capturedUploadBuffer;
    mockReadFile.mockResolvedValue(encryptedBuf);

    // Mock the database metadata response for getDocument
    mockQuery.mockResolvedValueOnce({
      rows: [{
        document_id: documentId,
        user_id: userId,
        file_name: 'mortgage-statement.pdf',
        storage_path: `documents/${userId}/${documentId}`,
        encrypted: true
      }],
      rowCount: 1
    });

    const retrieved = await documentService.getDocument({ documentId, userId });
    expect(retrieved).toBeDefined();
    expect(retrieved.content).toBeDefined();

    // Verify round-trip: decrypted content matches original
    const decryptedContent = Buffer.from(retrieved.content, 'base64').toString('utf-8');
    expect(decryptedContent).toBe(originalContent);
  });

  test('backward-compatible with unencrypted documents', async () => {
    const userId = 'user-legacy-456';
    const documentId = 'doc-legacy-001';
    const plaintextContent = 'Legacy unencrypted document content';
    const plaintextBuffer = Buffer.from(plaintextContent);

    // Mock filesystem to return raw plaintext (no encryption)
    mockReadFile.mockResolvedValue(plaintextBuffer);

    // Mock database metadata WITHOUT encrypted flag
    mockQuery.mockResolvedValueOnce({
      rows: [{
        document_id: documentId,
        user_id: userId,
        file_name: 'old-doc.pdf',
        storage_path: `documents/${userId}/${documentId}`,
        encrypted: false
      }],
      rowCount: 1
    });

    const retrieved = await documentService.getDocument({ documentId, userId });
    expect(retrieved).toBeDefined();

    // Verify content is returned as-is (no decryption attempted)
    const returnedContent = Buffer.from(retrieved.content, 'base64').toString('utf-8');
    expect(returnedContent).toBe(plaintextContent);
  });

  test('gracefully handles missing encryption key', async () => {
    // Save and remove the encryption key
    const savedKey = process.env.DOCUMENT_ENCRYPTION_KEY;
    delete process.env.DOCUMENT_ENCRYPTION_KEY;

    // We need a fresh documentService instance without encryption
    let freshDocService;
    jest.isolateModules(() => {
      delete process.env.DOCUMENT_ENCRYPTION_KEY;
      freshDocService = require('../../services/documentService');
    });

    const userId = 'user-nokey-789';
    const documentId = 'doc-nokey-001';
    const originalContent = 'Document without encryption key';
    const contentBase64 = Buffer.from(originalContent).toString('base64');

    // Reset capturedUploadBuffer
    capturedUploadBuffer = null;

    // Upload should succeed without crash
    await freshDocService.uploadDocument({
      documentId, userId,
      fileName: 'test.pdf',
      documentType: 'mortgage_statement',
      content: contentBase64,
      analysisResults: null,
      metadata: {}
    });

    // Verify the buffer was stored as plaintext (not encrypted)
    expect(capturedUploadBuffer).not.toBeNull();
    const originalBuffer = Buffer.from(originalContent);
    expect(capturedUploadBuffer.equals(originalBuffer)).toBe(true);

    // Verify encrypted flag was NOT set
    expect(capturedDbInsert.encrypted).toBe(false);

    // Restore key
    process.env.DOCUMENT_ENCRYPTION_KEY = savedKey;
  });

  test('different users produce different encrypted outputs for same content', () => {
    const userA = 'user-alpha-001';
    const userB = 'user-beta-002';
    const sameContent = Buffer.from('Identical mortgage document content for both users');

    const encryptedA = DocumentEncryptionService.encrypt(userA, sameContent);
    const encryptedB = DocumentEncryptionService.encrypt(userB, sameContent);

    // Both should be Buffers
    expect(Buffer.isBuffer(encryptedA)).toBe(true);
    expect(Buffer.isBuffer(encryptedB)).toBe(true);

    // Encrypted outputs must differ (different per-user derived keys + random IVs)
    expect(encryptedA.equals(encryptedB)).toBe(false);

    // Even the ciphertext portions (after iv+authTag) must differ
    const ciphertextA = encryptedA.subarray(28);
    const ciphertextB = encryptedB.subarray(28);
    expect(ciphertextA.equals(ciphertextB)).toBe(false);
  });

  test('user-A cannot decrypt user-B document (cross-user decryption fails)', () => {
    const userA = 'user-alpha-001';
    const userB = 'user-beta-002';
    const sensitiveContent = Buffer.from('User-A private mortgage data - loan details and SSN');

    // Encrypt as user-A
    const encryptedByA = DocumentEncryptionService.encrypt(userA, sensitiveContent);

    // Attempt to decrypt as user-B — should throw (GCM auth tag mismatch)
    expect(() => {
      DocumentEncryptionService.decrypt(userB, encryptedByA);
    }).toThrow();

    // Verify user-A can still decrypt their own document
    const decrypted = DocumentEncryptionService.decrypt(userA, encryptedByA);
    expect(decrypted.equals(sensitiveContent)).toBe(true);
  });

  test('encrypted document survives full pipeline flow', async () => {
    const userId = 'user-pipeline-001';
    const documentId = 'doc-pipeline-001';
    const documentContent = 'Mortgage statement processed through full pipeline';
    const contentBase64 = Buffer.from(documentContent).toString('base64');

    // Upload document through documentService (triggers encryption)
    const uploadResult = await documentService.uploadDocument({
      documentId, userId,
      fileName: 'pipeline-doc.pdf',
      documentType: 'mortgage_statement',
      content: contentBase64,
      analysisResults: { issues: [], summary: 'No issues found' },
      metadata: { pipelineStatus: 'review' }
    });

    expect(uploadResult.documentId).toBe(documentId);

    // Verify the stored document is encrypted
    expect(capturedUploadBuffer).not.toBeNull();
    const originalBuffer = Buffer.from(documentContent);
    expect(capturedUploadBuffer.equals(originalBuffer)).toBe(false);
    expect(capturedDbInsert.encrypted).toBe(true);

    // Verify analysis results were stored alongside the encrypted document
    expect(capturedDbInsert.analysis_results).toBeDefined();

    // Verify the encrypted buffer can be decrypted back
    const decrypted = DocumentEncryptionService.decrypt(userId, capturedUploadBuffer);
    expect(decrypted.equals(originalBuffer)).toBe(true);
  });
});
