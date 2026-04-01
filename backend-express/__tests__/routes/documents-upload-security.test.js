/**
 * Document Upload Security Integration Tests
 *
 * Tests the full POST /v1/documents/upload flow through the Express middleware chain:
 *   auth -> rate limit -> Joi validation -> file content validation -> filename sanitization -> storage
 *
 * Verifies:
 *   1. Valid uploads accepted (PDF, JPEG, PNG with real magic bytes)
 *   2. Invalid file types rejected (disguised EXE, ZIP)
 *   3. Size limit enforcement
 *   4. Filename security (path traversal, null bytes, special characters)
 *
 * Mock strategy:
 *   - @supabase/supabase-js mocked to control auth.getUser() responses
 *   - documentService mocked to prevent real storage calls (we test security layers, not storage)
 *   - Service modules mocked to prevent real API calls
 *   - Pattern follows auth-integration.test.js exactly
 *
 * Phase 04-04: Document Upload Security Integration Tests
 */

const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');
const mockClaudeService = require('../mocks/mockClaudeService');
const request = require('supertest');

// Create mock Supabase client
const mockClient = createMockSupabaseClient();

// Mock @supabase/supabase-js before any module loads it
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Mock service modules to prevent real API calls
jest.mock('../../services/claudeService', () => mockClaudeService);

jest.mock('../../services/plaidService', () => ({
  createLinkToken: jest.fn().mockResolvedValue({ link_token: 'mock-link-token', expiration: '2025-01-01T00:00:00Z', request_id: 'mock-req-id' }),
  exchangePublicToken: jest.fn().mockResolvedValue({ accessToken: 'mock-access-token', itemId: 'mock-item-id', requestId: 'mock-req-id' }),
  getAccounts: jest.fn().mockResolvedValue({ accounts: [], item: {}, request_id: 'mock-req-id' }),
  getTransactions: jest.fn().mockResolvedValue({ transactions: [], total_transactions: 0, accounts: [], request_id: 'mock-req-id' }),
  getItem: jest.fn().mockResolvedValue({ itemId: 'mock-item-id', institutionId: 'mock-inst-id' }),
  removeItem: jest.fn().mockResolvedValue({ removed: true, request_id: 'mock-req-id' }),
  updateWebhook: jest.fn().mockResolvedValue({ itemId: 'mock-item-id', webhook: 'https://mock.webhook.url' }),
  createSandboxPublicToken: jest.fn().mockResolvedValue('public-sandbox-mock'),
  testConnection: jest.fn().mockResolvedValue({ success: true }),
  verifyWebhookSignature: jest.fn().mockReturnValue(true)
}));

jest.mock('../../services/plaidDataService', () => ({
  upsertPlaidItem: jest.fn().mockResolvedValue({ success: true }),
  getItem: jest.fn().mockResolvedValue({ success: true, data: { access_token: 'mock', user_id: 'mock' } }),
  storeTransactions: jest.fn().mockResolvedValue({ success: true }),
  upsertAccounts: jest.fn().mockResolvedValue({ success: true }),
  createNotification: jest.fn().mockResolvedValue({ success: true }),
  removeTransactions: jest.fn().mockResolvedValue({ success: true }),
  updateItemStatus: jest.fn().mockResolvedValue({ success: true })
}));

// Mock documentService — we test security layers, not storage
const mockUploadDocument = jest.fn().mockResolvedValue({
  documentId: 'mock-doc-id',
  storagePath: 'documents/test-user-id/mock-doc-id'
});

jest.mock('../../services/documentService', () => ({
  uploadDocument: mockUploadDocument,
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true })
}));

// Set env vars so modules initialize properly
process.env.SUPABASE_URL = 'https://mock.supabase.co';
process.env.SUPABASE_ANON_KEY = 'mock-anon-key';

// Prevent server.js from calling app.listen() during tests
process.env.NODE_ENV = 'production';
process.env.VERCEL = '1';

// ---------------------------------------------------------------------------
// Test binary buffers with real magic bytes
// ---------------------------------------------------------------------------

/** Valid PDF content with real magic bytes */
const VALID_PDF_BUFFER = Buffer.from('%PDF-1.4 test content for upload security testing');
const VALID_PDF_BASE64 = VALID_PDF_BUFFER.toString('base64');

/** Valid JPEG content with real magic bytes (FF D8 FF E0 header) */
const VALID_JPEG_BUFFER = Buffer.alloc(256);
VALID_JPEG_BUFFER[0] = 0xFF;
VALID_JPEG_BUFFER[1] = 0xD8;
VALID_JPEG_BUFFER[2] = 0xFF;
VALID_JPEG_BUFFER[3] = 0xE0;
// JFIF APP0 marker segment
VALID_JPEG_BUFFER[4] = 0x00;
VALID_JPEG_BUFFER[5] = 0x10;
VALID_JPEG_BUFFER[6] = 0x4A; // J
VALID_JPEG_BUFFER[7] = 0x46; // F
VALID_JPEG_BUFFER[8] = 0x49; // I
VALID_JPEG_BUFFER[9] = 0x46; // F
VALID_JPEG_BUFFER[10] = 0x00;
const VALID_JPEG_BASE64 = VALID_JPEG_BUFFER.toString('base64');

/** Valid PNG content with real magic bytes (89 50 4E 47 0D 0A 1A 0A header) */
const VALID_PNG_BUFFER = Buffer.alloc(256);
VALID_PNG_BUFFER[0] = 0x89;
VALID_PNG_BUFFER[1] = 0x50; // P
VALID_PNG_BUFFER[2] = 0x4E; // N
VALID_PNG_BUFFER[3] = 0x47; // G
VALID_PNG_BUFFER[4] = 0x0D;
VALID_PNG_BUFFER[5] = 0x0A;
VALID_PNG_BUFFER[6] = 0x1A;
VALID_PNG_BUFFER[7] = 0x0A;
// IHDR chunk (minimal valid PNG structure)
VALID_PNG_BUFFER[8] = 0x00;
VALID_PNG_BUFFER[9] = 0x00;
VALID_PNG_BUFFER[10] = 0x00;
VALID_PNG_BUFFER[11] = 0x0D; // chunk length = 13
VALID_PNG_BUFFER[12] = 0x49; // I
VALID_PNG_BUFFER[13] = 0x48; // H
VALID_PNG_BUFFER[14] = 0x44; // D
VALID_PNG_BUFFER[15] = 0x52; // R
const VALID_PNG_BASE64 = VALID_PNG_BUFFER.toString('base64');

/** EXE content with MZ header (disguised as PDF) */
const EXE_BUFFER = Buffer.alloc(256);
EXE_BUFFER[0] = 0x4D; // M
EXE_BUFFER[1] = 0x5A; // Z
const EXE_AS_PDF_BASE64 = EXE_BUFFER.toString('base64');

/** ZIP content with PK header (disguised as PDF) */
const ZIP_BUFFER = Buffer.alloc(256);
ZIP_BUFFER[0] = 0x50; // P
ZIP_BUFFER[1] = 0x4B; // K
ZIP_BUFFER[2] = 0x03;
ZIP_BUFFER[3] = 0x04;
const ZIP_AS_PDF_BASE64 = ZIP_BUFFER.toString('base64');

// ---------------------------------------------------------------------------
// Test setup
// ---------------------------------------------------------------------------

let app;
const AUTH_TOKEN = 'Bearer valid-test-token';

beforeAll(() => {
  // Clear cached server and route modules so our jest.mock() calls take effect
  const serverPath = require.resolve('../../server');
  const routePaths = [
    require.resolve('../../routes/claude'),
    require.resolve('../../routes/plaid'),
    require.resolve('../../routes/documents'),
    require.resolve('../../routes/health')
  ];
  delete require.cache[serverPath];
  for (const routePath of routePaths) {
    delete require.cache[routePath];
  }

  // Also clear the middleware module cache so it picks up the mock
  const authPath = require.resolve('../../middleware/auth');
  delete require.cache[authPath];

  // Clear fileValidation module cache for clean require
  const fileValidationPath = require.resolve('../../utils/fileValidation');
  delete require.cache[fileValidationPath];

  app = require('../../server');

  // Restore NODE_ENV to test for proper behavior in tests
  process.env.NODE_ENV = 'test';
});

afterAll(() => {
  delete process.env.VERCEL;
});

beforeEach(() => {
  mockClient.reset();
  mockClaudeService.reset();
  mockUploadDocument.mockClear();

  // Configure mock Supabase to accept the auth token
  mockClient.setResponse('auth', {
    data: {
      user: {
        id: 'test-user-id',
        email: 'test@example.com',
        role: 'authenticated'
      }
    },
    error: null
  });
});

/**
 * Helper to build a valid upload request body.
 * Override any field by passing it in the overrides object.
 */
function buildUploadBody(overrides = {}) {
  return {
    documentId: 'doc-test-001',
    fileName: 'test-document.pdf',
    documentType: 'mortgage_statement',
    content: VALID_PDF_BASE64,
    ...overrides
  };
}

// ===========================================================================
// TESTS
// ===========================================================================

describe('Document upload security integration', () => {

  // =========================================================================
  // 1. Valid uploads accepted
  // =========================================================================
  describe('valid uploads accepted', () => {

    test('valid PDF with real magic bytes returns 201', async () => {
      const body = buildUploadBody({
        fileName: 'mortgage-statement.pdf',
        content: VALID_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('documentId');
      expect(response.body).toHaveProperty('storagePath');
      expect(response.body).toHaveProperty('message', 'Document uploaded successfully');
    });

    test('valid JPEG with real magic bytes returns 201', async () => {
      const body = buildUploadBody({
        fileName: 'scan-photo.jpg',
        content: VALID_JPEG_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('success', true);
    });

    test('valid PNG with real magic bytes returns 201', async () => {
      const body = buildUploadBody({
        fileName: 'screenshot.png',
        content: VALID_PNG_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('success', true);
    });

  });

  // =========================================================================
  // 2. Invalid file types rejected
  // =========================================================================
  describe('invalid file types rejected', () => {

    test('EXE disguised as .pdf is rejected with 400', async () => {
      const body = buildUploadBody({
        fileName: 'malware.pdf',
        content: EXE_AS_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body).toHaveProperty('message');
      // The validation error should indicate content/type mismatch
      expect(response.body.message).toMatch(/does not match|not allowed/i);
    });

    test('ZIP file disguised as .pdf is rejected with 400', async () => {
      const body = buildUploadBody({
        fileName: 'archive.pdf',
        content: ZIP_AS_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.message).toMatch(/does not match|not allowed/i);
    });

    test('disallowed content type extension is rejected by Joi', async () => {
      const body = buildUploadBody({
        fileName: 'script.exe'
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // Joi pattern validation rejects .exe extension (not in safe characters pattern, or schema rejects)
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

  });

  // =========================================================================
  // 3. Size limit enforcement
  // =========================================================================
  describe('size limit enforcement', () => {

    test('content within size limit returns 201', async () => {
      // Small valid PDF content — well within 20MB limit
      const body = buildUploadBody({
        fileName: 'small-doc.pdf',
        content: VALID_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('success', true);
    });

    test('content exceeding body parser limit (25MB) is rejected with 413', async () => {
      // Create content that exceeds the 25MB body parser limit
      // The body parser fires before Joi, so we get 413 PayloadTooLarge
      const oversizedContent = 'A'.repeat(26 * 1024 * 1024);
      const body = buildUploadBody({
        fileName: 'huge-doc.pdf',
        content: oversizedContent
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // Body parser rejects before Joi or file validation can process
      expect([400, 413]).toContain(response.status);
    });

  });

  // =========================================================================
  // 4. Filename security
  // =========================================================================
  describe('filename security', () => {

    test('normal filename is accepted and passed to storage', async () => {
      const body = buildUploadBody({
        fileName: 'mortgage-statement-2024.pdf',
        content: VALID_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(201);

      // Verify documentService.uploadDocument was called with the sanitized filename
      expect(mockUploadDocument).toHaveBeenCalledWith(
        expect.objectContaining({
          fileName: 'mortgage-statement-2024.pdf'
        })
      );
    });

    test('path traversal in filename is rejected by Joi pattern', async () => {
      const body = buildUploadBody({
        fileName: '../../../etc/passwd',
        content: VALID_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // Joi fileName pattern /^[a-zA-Z0-9._\s()-]+$/ rejects path separators
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

    test('filename with null bytes is rejected by Joi pattern', async () => {
      const body = buildUploadBody({
        fileName: 'test\x00.pdf',
        content: VALID_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // Joi pattern rejects null bytes (not in safe characters set)
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

    test('filename with special characters is sanitized before storage', async () => {
      // Characters that pass Joi pattern but get sanitized by sanitizeFileName
      const body = buildUploadBody({
        fileName: 'my document (1).pdf',
        content: VALID_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(201);

      // sanitizeFileName replaces spaces and parens with underscores
      // "my document (1).pdf" → "my_document_1_.pdf" (trailing underscore from closing paren)
      expect(mockUploadDocument).toHaveBeenCalledWith(
        expect.objectContaining({
          fileName: expect.stringMatching(/^my_document_1_\.pdf$/)
        })
      );
    });

  });

  // =========================================================================
  // 5. Auth required
  // =========================================================================
  describe('authentication required', () => {

    test('upload without auth token returns 401', async () => {
      const body = buildUploadBody();

      const response = await request(app)
        .post('/v1/documents/upload')
        .send(body);

      expect(response.status).toBe(401);
      expect(response.body).toEqual({
        error: 'Unauthorized',
        message: expect.any(String)
      });
    });

  });

  // =========================================================================
  // 6. Edge cases
  // =========================================================================
  describe('edge cases', () => {

    test('empty content string (decodes to empty buffer) is rejected', async () => {
      // Empty base64 string decodes to empty Buffer
      const body = buildUploadBody({
        fileName: 'empty.pdf',
        content: ''
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // Joi requires content (non-empty string), so this is caught at schema level
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

    test('missing content field is rejected by Joi', async () => {
      const body = {
        documentId: 'doc-test-002',
        fileName: 'test.pdf',
        documentType: 'mortgage_statement'
        // no content field
      };

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error', 'Bad Request');
      expect(response.body.message).toMatch(/content/i);
    });

    test('very long filename (255+ chars) is rejected by Joi max', async () => {
      const longName = 'a'.repeat(300) + '.pdf';
      const body = buildUploadBody({
        fileName: longName,
        content: VALID_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // Joi .max(255) on fileName rejects this
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

    test('double extension file (file.pdf.exe) is rejected by Joi pattern', async () => {
      // The Joi pattern /^[a-zA-Z0-9._\s()-]+$/ allows dots, but .exe extension
      // means file-type detection will fail if content doesn't match claimed type
      const body = buildUploadBody({
        fileName: 'document.pdf.exe',
        content: VALID_PDF_BASE64
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // File content validation: PDF magic bytes with .exe extension → mismatch
      // The file has PDF content but claims to be .exe — file validation rejects it
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

    test('unicode characters in filename are rejected by Joi pattern', async () => {
      const body = buildUploadBody({
        fileName: 'dokument-ubersicht.pdf',
        content: VALID_PDF_BASE64
      });

      // ASCII-only filename passes Joi pattern
      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // ASCII-safe name passes; test with actual unicode
      expect(response.status).toBe(201);

      // Now test actual unicode
      const unicodeBody = buildUploadBody({
        fileName: '\u00FCbersicht-dokument.pdf',
        content: VALID_PDF_BASE64
      });

      const unicodeResponse = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(unicodeBody);

      // Joi pattern /^[a-zA-Z0-9._\s()-]+$/ rejects unicode characters
      expect(unicodeResponse.status).toBe(400);
      expect(unicodeResponse.body).toHaveProperty('error');
    });

    test('content that is not valid base64 but passes Joi still works (Buffer.from tolerates it)', async () => {
      // Buffer.from(string, 'base64') is lenient and doesn't throw on invalid base64
      // It will produce a buffer, which then gets validated by file content checks
      const body = buildUploadBody({
        fileName: 'test.txt',
        content: 'not-really-base64!@#$%'
      });

      const response = await request(app)
        .post('/v1/documents/upload')
        .set('Authorization', AUTH_TOKEN)
        .send(body);

      // Buffer.from('not-really-base64!@#$%', 'base64') produces a small buffer
      // file-type can't detect it, but .txt extension is in allowed list
      // So it passes with a warning (unverifiable type)
      expect(response.status).toBe(201);
    });

  });

});
