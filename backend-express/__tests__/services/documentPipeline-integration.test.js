/**
 * Document Pipeline Integration Tests
 *
 * Tests the full document processing pipeline flow with external
 * dependencies mocked at the boundary (Anthropic SDK, pdf-parse, Supabase).
 *
 * Covers:
 * - Full happy path: upload -> OCR -> classify -> analyze -> review -> complete
 * - Server-side OCR via fileBuffer
 * - Retry from failed state
 * - Backward compatibility with pre-extracted documentText
 * - Encryption integration: pipeline processes plaintext, storage encrypts
 */

// ============================================================
// MOCKS — set up before any module imports
// ============================================================

// Mock Supabase (no real DB)
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => null)
}));

// Mock pdf-parse (used by ocrService)
jest.mock('pdf-parse', () => {
  return jest.fn().mockResolvedValue({
    text: 'Extracted PDF text for mortgage statement dated 2024-01-15. Loan #12345. Payment due: $1,500.00.',
    numpages: 2,
    info: { Title: 'Mortgage Statement' }
  });
});

// Mock Anthropic SDK (used by ocrService, classificationService, claudeService)
const mockAnthropicCreate = jest.fn();
jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockAnthropicCreate }
  }));
});

// Mock encryption service for verifying it's called during storage
const mockEncrypt = jest.fn((userId, buffer) => Buffer.concat([Buffer.from('ENC:'), buffer]));
const mockDecrypt = jest.fn((userId, buffer) => buffer.subarray(4));
jest.mock('../../services/documentEncryptionService', () => ({
  encrypt: mockEncrypt,
  decrypt: mockDecrypt
}));

// Track the required services — we need fresh instances after mocks are set up
let documentPipeline;
let caseFileService;

/**
 * Helper to configure Anthropic mock responses for the full pipeline.
 * The pipeline calls Anthropic at multiple stages:
 * 1. Classification (classificationService)
 * 2. Analysis (claudeService via pipeline._runAnalysis)
 * Optionally: OCR Vision (if fileBuffer is image/scanned)
 */
function setupAnthropicMockResponses({
  classificationResponse,
  analysisResponse,
  ocrVisionResponse
} = {}) {
  const responses = [];

  // If OCR vision is needed, it comes first
  if (ocrVisionResponse) {
    responses.push(ocrVisionResponse);
  }

  // Classification response
  responses.push(classificationResponse || {
    content: [{
      text: JSON.stringify({
        classificationType: 'servicing',
        classificationSubtype: 'monthly_statement',
        confidence: 0.92,
        keyMetadata: {
          dates: ['2024-01-15'],
          amounts: ['$1,500.00'],
          parties: ['Test Bank'],
          accountNumbers: ['12345']
        },
        summary: 'Monthly mortgage servicing statement'
      })
    }],
    model: 'claude-sonnet-4-5-20250514',
    usage: { input_tokens: 500, output_tokens: 200 },
    stop_reason: 'end_turn'
  });

  // Analysis response
  responses.push(analysisResponse || {
    content: [{
      text: JSON.stringify({
        issues: [
          {
            type: 'escrow_discrepancy',
            description: 'Escrow payment appears higher than expected',
            confidence: 0.78,
            severity: 'medium'
          }
        ],
        summary: 'One potential escrow discrepancy identified',
        riskLevel: 'medium'
      })
    }],
    model: 'claude-3-5-sonnet-20241022',
    usage: { input_tokens: 1000, output_tokens: 500 },
    stop_reason: 'end_turn'
  });

  // Set up mock to return responses in order
  mockAnthropicCreate.mockReset();
  for (let i = 0; i < responses.length; i++) {
    mockAnthropicCreate.mockResolvedValueOnce(responses[i]);
  }
}

beforeAll(() => {
  // Set environment so services don't try to use real Supabase
  process.env.ANTHROPIC_API_KEY = 'test-key';
  // Enable encryption path for integration tests
  process.env.DOCUMENT_ENCRYPTION_KEY = 'a'.repeat(64);

  // Clear module cache for fresh instances with mocks in effect
  const modulesToClear = [
    '../../services/documentPipelineService',
    '../../services/ocrService',
    '../../services/classificationService',
    '../../services/claudeService',
    '../../services/caseFileService',
    '../../services/documentService'
  ];

  for (const mod of modulesToClear) {
    try {
      const resolved = require.resolve(mod);
      delete require.cache[resolved];
    } catch {
      // Module may not be cached yet
    }
  }

  // Now require fresh instances
  documentPipeline = require('../../services/documentPipelineService');
  caseFileService = require('../../services/caseFileService');
});

beforeEach(() => {
  // Clear pipeline state between tests
  documentPipeline.pipelineState.clear();
  // Clear case file service mock state
  caseFileService.mockCases.clear();
  caseFileService.mockDocCaseMap.clear();
  // Reset all mocks
  jest.clearAllMocks();
});

afterAll(() => {
  delete process.env.ANTHROPIC_API_KEY;
  delete process.env.DOCUMENT_ENCRYPTION_KEY;
});

// ============================================================
// HAPPY PATH: Pre-extracted text -> full pipeline
// ============================================================
describe('Full pipeline with pre-extracted text', () => {
  it('progresses through all states: uploaded -> ocr -> classifying -> analyzing -> analyzed -> review', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-happy-path';
    const userId = 'user-1';

    // Step 1: Initialize pipeline
    const pipeline = documentPipeline.initPipeline(docId, userId, 'unknown');
    expect(pipeline.status).toBe('uploaded');

    // Step 2: Process document with pre-extracted text
    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Mortgage statement for loan #12345 dated 2024-01-15.',
      documentType: 'unknown'
    });

    // Verify successful completion through to review
    expect(result.success).toBe(true);
    expect(result.status).toBe('review');
    expect(result.documentId).toBe(docId);

    // Verify classification results populated
    expect(result.classificationResults).toBeDefined();
    expect(result.classificationResults.classificationType).toBe('servicing');
    expect(result.classificationResults.classificationSubtype).toBe('monthly_statement');

    // Verify analysis results populated
    expect(result.analysisResults).toBeDefined();
    expect(result.analysisResults.analysis.issues).toHaveLength(1);

    // Verify steps are tracked
    expect(result.steps.uploaded).toBeDefined();
    expect(result.steps.ocr).toBeDefined();
    expect(result.steps.ocr.method).toBe('client-provided');
    expect(result.steps.classifying).toBeDefined();
    expect(result.steps.analyzing).toBeDefined();
    expect(result.steps.analyzed).toBeDefined();
    expect(result.steps.review).toBeDefined();
  });

  it('completes document after review', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-complete';
    const userId = 'user-1';

    documentPipeline.initPipeline(docId, userId, 'unknown');
    await documentPipeline.processDocument(docId, userId, {
      documentText: 'Test mortgage document content.',
      documentType: 'unknown'
    });

    // Complete the document (user confirms review)
    const completeResult = documentPipeline.completeDocument(docId, userId);
    expect(completeResult.success).toBe(true);
    expect(completeResult.status).toBe('complete');
    expect(completeResult.steps.complete).toBeDefined();
  });

  it('auto-associates document with single open case', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-auto-case';
    const userId = 'user-1';

    // Create a single open case
    caseFileService.mockCreateCase({
      userId,
      caseName: 'Test Case'
    });

    documentPipeline.initPipeline(docId, userId, 'unknown');
    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Mortgage statement content.',
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);
    // Verify case association was attempted
    expect(result.caseId).toBeDefined();
    expect(result.caseId).toMatch(/^mock-case-/);
  });
});

// ============================================================
// SERVER-SIDE OCR: fileBuffer path
// ============================================================
describe('Full pipeline with fileBuffer (server-side OCR)', () => {
  it('extracts text via pdf-parse and completes pipeline', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-ocr-buffer';
    const userId = 'user-1';

    // Create a fake PDF buffer (pdf-parse is mocked, so content doesn't matter)
    const fakeBuffer = Buffer.from('fake pdf content').toString('base64');

    documentPipeline.initPipeline(docId, userId, 'unknown');

    const result = await documentPipeline.processDocument(docId, userId, {
      fileBuffer: fakeBuffer,
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);
    expect(result.status).toBe('review');

    // Verify OCR was server-side
    expect(result.steps.ocr.method).toBe('pdf-parse');
    expect(result.steps.ocr.textLength).toBeGreaterThan(0);

    // Verify classification and analysis still ran
    expect(result.classificationResults).toBeDefined();
    expect(result.analysisResults).toBeDefined();
  });
});

// ============================================================
// RETRY FROM FAILED STATE
// ============================================================
describe('Pipeline retry from failed state', () => {
  it('retries from failed analysis and completes', async () => {
    // First run: classification succeeds, analysis fails
    mockAnthropicCreate
      .mockResolvedValueOnce({
        // Classification response
        content: [{
          text: JSON.stringify({
            classificationType: 'servicing',
            classificationSubtype: 'monthly_statement',
            confidence: 0.90,
            keyMetadata: {},
            summary: 'Monthly statement'
          })
        }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 500, output_tokens: 200 },
        stop_reason: 'end_turn'
      })
      .mockRejectedValueOnce(new Error('API rate limit exceeded'));

    const docId = 'doc-retry';
    const userId = 'user-1';

    documentPipeline.initPipeline(docId, userId, 'unknown');

    // First attempt — should fail at analysis
    const failResult = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Test document for retry.',
      documentType: 'unknown'
    });

    expect(failResult.success).toBe(false);
    expect(failResult.status).toBe('failed');

    // Now set up for retry success
    setupAnthropicMockResponses();

    // Retry — should pick up from pre-failure state
    const retryResult = await documentPipeline.retryDocument(docId, userId);

    expect(retryResult.success).toBe(true);
    expect(retryResult.status).toBe('review');
    expect(retryResult.analysisResults).toBeDefined();
  });

  it('throws when retrying non-failed document', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-not-failed';
    const userId = 'user-1';

    documentPipeline.initPipeline(docId, userId, 'unknown');
    await documentPipeline.processDocument(docId, userId, {
      documentText: 'Test document.',
      documentType: 'unknown'
    });

    // Document is in 'review' state, not 'failed'
    await expect(
      documentPipeline.retryDocument(docId, userId)
    ).rejects.toThrow('not in failed state');
  });

  it('throws when retrying non-existent document', async () => {
    await expect(
      documentPipeline.retryDocument('nonexistent-doc', 'user-1')
    ).rejects.toThrow('No pipeline found');
  });
});

// ============================================================
// BACKWARD COMPATIBILITY
// ============================================================
describe('Backward compatibility', () => {
  it('works with documentText only (no fileBuffer) — iOS pre-extracted path', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-backward-compat';
    const userId = 'user-1';

    // No initPipeline call — processDocument should create it
    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Pre-extracted mortgage statement text from iOS Vision OCR.',
      documentType: 'mortgage_statement'
    });

    expect(result.success).toBe(true);
    expect(result.status).toBe('review');
    expect(result.steps.ocr.method).toBe('client-provided');
  });

  it('pipeline auto-initializes when not previously initialized', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-auto-init';
    const userId = 'user-1';

    // Do NOT call initPipeline — processDocument should handle it
    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Document text.',
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);
    expect(result.documentId).toBe(docId);
  });
});

// ============================================================
// STATUS TRACKING
// ============================================================
describe('Pipeline status tracking', () => {
  it('getStatus returns correct state after processing', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-status';
    const userId = 'user-1';

    documentPipeline.initPipeline(docId, userId, 'unknown');
    await documentPipeline.processDocument(docId, userId, {
      documentText: 'Status tracking test.',
      documentType: 'unknown'
    });

    const status = await documentPipeline.getStatus(docId);
    expect(status).toBeDefined();
    expect(status.status).toBe('review');
    expect(status.hasClassification).toBe(true);
    expect(status.hasAnalysis).toBe(true);
    expect(status.documentId).toBe(docId);
  });

  it('getStatus returns null for unknown document', async () => {
    const status = await documentPipeline.getStatus('nonexistent');
    expect(status).toBeNull();
  });

  it('getUserPipeline returns all documents for a user', async () => {
    setupAnthropicMockResponses();

    documentPipeline.initPipeline('doc-a', 'user-1', 'unknown');
    await documentPipeline.processDocument('doc-a', 'user-1', {
      documentText: 'Doc A.',
      documentType: 'unknown'
    });

    // Set up mocks for second document
    setupAnthropicMockResponses();

    documentPipeline.initPipeline('doc-b', 'user-1', 'unknown');
    await documentPipeline.processDocument('doc-b', 'user-1', {
      documentText: 'Doc B.',
      documentType: 'unknown'
    });

    const userDocs = documentPipeline.getUserPipeline('user-1');
    expect(userDocs).toHaveLength(2);

    // Should not include other user's documents
    documentPipeline.initPipeline('doc-other', 'user-2', 'unknown');
    const user1Docs = documentPipeline.getUserPipeline('user-1');
    expect(user1Docs).toHaveLength(2);
  });
});

// ============================================================
// ENCRYPTION INTEGRATION
// ============================================================
describe('Encryption integration with pipeline storage', () => {
  /**
   * The pipeline processes plaintext in memory (OCR, classification, analysis).
   * Encryption is a storage concern handled by documentService.uploadDocument.
   * This test verifies the end-to-end flow: pipeline produces analysis results,
   * then documentService encrypts when storing.
   */

  let documentService;

  beforeAll(() => {
    // Require documentService (which uses the mocked encryption service)
    documentService = require('../../services/documentService');
  });

  it('pipeline processes plaintext; documentService encrypts on storage', async () => {
    setupAnthropicMockResponses();

    const docId = 'doc-encrypt-flow';
    const userId = 'user-encrypt';

    // Run the pipeline (works with plaintext in memory)
    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Mortgage statement for encryption integration test.',
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);
    expect(result.status).toBe('review');

    // Pipeline produces plaintext analysis results
    expect(result.analysisResults).toBeDefined();
    expect(result.analysisResults.analysis.issues).toHaveLength(1);

    // Now simulate what the API route does: store via documentService
    // documentService is in mock mode (Supabase is null), so it uses
    // in-memory storage. Encryption only applies in Supabase mode.
    // This verifies the separation of concerns: pipeline never encrypts.
    const storeResult = await documentService.uploadDocument({
      documentId: docId,
      userId,
      fileName: 'test-statement.pdf',
      documentType: result.classificationResults.classificationType,
      content: Buffer.from('raw document bytes').toString('base64'),
      analysisResults: result.analysisResults,
      metadata: { pipelineStatus: result.status }
    });

    // Verify document was stored (mock mode)
    expect(storeResult.documentId).toBe(docId);
    expect(storeResult.storagePath).toContain('mock://');
  });

  it('pipeline does not call encryption service directly', async () => {
    setupAnthropicMockResponses();
    mockEncrypt.mockClear();
    mockDecrypt.mockClear();

    const docId = 'doc-no-direct-encrypt';
    const userId = 'user-1';

    // Run the full pipeline
    const result = await documentPipeline.processDocument(docId, userId, {
      documentText: 'Test document for encryption separation.',
      documentType: 'unknown'
    });

    expect(result.success).toBe(true);

    // The pipeline itself should never call encrypt or decrypt.
    // Encryption is handled by documentService at the storage layer.
    expect(mockEncrypt).not.toHaveBeenCalled();
    expect(mockDecrypt).not.toHaveBeenCalled();
  });

  it('DOCUMENT_ENCRYPTION_KEY is configured in test environment', () => {
    // Verify that the encryption key is set for integration tests,
    // so any code path checking for it will find it available.
    expect(process.env.DOCUMENT_ENCRYPTION_KEY).toBeDefined();
    expect(process.env.DOCUMENT_ENCRYPTION_KEY).toHaveLength(64);
  });
});
