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
 * while mocking only external boundaries (Supabase).
 */

const crypto = require('crypto');

// Generate a test master key (32 bytes = 64 hex chars)
const TEST_MASTER_KEY = crypto.randomBytes(32).toString('hex');

// ============================================================
// MOCKS — set up before any module imports
// ============================================================

// Track buffers passed to Supabase storage for verification
let capturedUploadBuffer = null;
let capturedUploadPath = null;
let mockStorageDownloadResponse = null;

const mockStorageFrom = jest.fn(() => ({
  upload: jest.fn(async (path, buffer, options) => {
    capturedUploadPath = path;
    capturedUploadBuffer = Buffer.from(buffer);
    return { data: { path, id: 'mock-file-id' }, error: null };
  }),
  download: jest.fn(async (path) => {
    if (mockStorageDownloadResponse) {
      return mockStorageDownloadResponse;
    }
    // Return the captured upload buffer by default (simulate round-trip)
    const buf = capturedUploadBuffer || Buffer.from('mock content');
    return {
      data: {
        arrayBuffer: async () => buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength)
      },
      error: null
    };
  }),
  remove: jest.fn(async () => ({ data: [], error: null }))
}));

// Track database inserts to verify encrypted flag
let capturedDbInsert = null;
let mockDbSelectResponse = null;

const mockFromFn = jest.fn((table) => {
  const chainable = {
    insert: jest.fn((data) => {
      capturedDbInsert = data;
      return chainable;
    }),
    select: jest.fn(() => chainable),
    update: jest.fn(() => chainable),
    delete: jest.fn(() => chainable),
    eq: jest.fn(() => chainable),
    order: jest.fn(() => chainable),
    range: jest.fn(() => chainable),
    single: jest.fn(() => {
      if (mockDbSelectResponse) {
        return Promise.resolve(mockDbSelectResponse);
      }
      // Return the captured insert data as the "database row"
      return Promise.resolve({
        data: capturedDbInsert || { document_id: 'test', encrypted: true },
        error: null
      });
    }),
    then: (resolve) => {
      return resolve({ data: capturedDbInsert || [], error: null });
    }
  };
  return chainable;
});

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => ({
    from: mockFromFn,
    storage: { from: mockStorageFrom },
    auth: {
      getUser: jest.fn().mockResolvedValue({
        data: { user: { id: 'mock-user-id-12345' } },
        error: null
      })
    }
  }))
}));

// ============================================================
// TEST SETUP
// ============================================================

// We need fresh modules for each test group because documentService
// caches the encryption service singleton.
let documentService;
let DocumentEncryptionService;

beforeAll(() => {
  // Set encryption key before loading modules
  process.env.DOCUMENT_ENCRYPTION_KEY = TEST_MASTER_KEY;
  process.env.SUPABASE_URL = 'https://mock.supabase.co';
  process.env.SUPABASE_SERVICE_KEY = 'mock-service-key';

  // Clear module cache to get fresh instances with our mocks
  const modulesToClear = [
    '../../services/documentService',
    '../../services/documentEncryptionService'
  ];
  for (const mod of modulesToClear) {
    try {
      delete require.cache[require.resolve(mod)];
    } catch {
      // Not cached yet
    }
  }

  documentService = require('../../services/documentService');
  DocumentEncryptionService = require('../../services/documentEncryptionService');
});

beforeEach(() => {
  capturedUploadBuffer = null;
  capturedUploadPath = null;
  capturedDbInsert = null;
  mockDbSelectResponse = null;
  mockStorageDownloadResponse = null;
  jest.clearAllMocks();
});

afterAll(() => {
  delete process.env.DOCUMENT_ENCRYPTION_KEY;
  delete process.env.SUPABASE_URL;
  delete process.env.SUPABASE_SERVICE_KEY;
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
      documentId,
      userId,
      fileName: 'mortgage-statement.pdf',
      documentType: 'mortgage_statement',
      content: contentBase64,
      analysisResults: null,
      metadata: {}
    });

    // Verify the buffer sent to Supabase storage is NOT the original plaintext
    expect(capturedUploadBuffer).not.toBeNull();
    const originalBuffer = Buffer.from(originalContent);
    expect(capturedUploadBuffer.equals(originalBuffer)).toBe(false);

    // Verify the buffer starts with a 12-byte IV (not recognizable as original format)
    expect(capturedUploadBuffer.length).toBeGreaterThan(28); // iv(12) + authTag(16) + ciphertext

    // Verify the encrypted flag was set in the database
    expect(capturedDbInsert).toBeDefined();
    expect(capturedDbInsert.encrypted).toBe(true);

    // Now download the document — mock Supabase to return the encrypted buffer
    const encryptedBuf = capturedUploadBuffer;
    mockStorageDownloadResponse = {
      data: {
        arrayBuffer: async () => encryptedBuf.buffer.slice(
          encryptedBuf.byteOffset,
          encryptedBuf.byteOffset + encryptedBuf.byteLength
        )
      },
      error: null
    };

    // Mock the database metadata response for getDocument
    mockDbSelectResponse = {
      data: {
        document_id: documentId,
        user_id: userId,
        file_name: 'mortgage-statement.pdf',
        storage_path: `documents/${userId}/${documentId}`,
        encrypted: true
      },
      error: null
    };

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

    // Mock Supabase download to return raw plaintext (no encryption)
    mockStorageDownloadResponse = {
      data: {
        arrayBuffer: async () => plaintextBuffer.buffer.slice(
          plaintextBuffer.byteOffset,
          plaintextBuffer.byteOffset + plaintextBuffer.byteLength
        )
      },
      error: null
    };

    // Mock database metadata WITHOUT encrypted flag
    mockDbSelectResponse = {
      data: {
        document_id: documentId,
        user_id: userId,
        file_name: 'old-doc.pdf',
        storage_path: `documents/${userId}/${documentId}`,
        encrypted: false  // Not encrypted
      },
      error: null
    };

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
      freshDocService = require('../../services/documentService');
    });

    const userId = 'user-nokey-789';
    const documentId = 'doc-nokey-001';
    const originalContent = 'Document without encryption key';
    const contentBase64 = Buffer.from(originalContent).toString('base64');

    // Upload should succeed without crash
    await freshDocService.uploadDocument({
      documentId,
      userId,
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
      documentId,
      userId,
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
    expect(capturedDbInsert.analysis_results.summary).toBe('No issues found');

    // Verify the encrypted buffer can be decrypted back
    const decrypted = DocumentEncryptionService.decrypt(userId, capturedUploadBuffer);
    expect(decrypted.equals(originalBuffer)).toBe(true);
  });
});
