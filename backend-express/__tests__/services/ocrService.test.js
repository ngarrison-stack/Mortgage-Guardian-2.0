/**
 * Unit tests for OcrService (services/ocrService.js)
 *
 * Tests hybrid text extraction: pdf-parse for text PDFs, Claude Vision
 * for scanned PDFs and images. All external dependencies are mocked.
 *
 * Phase 10-02: Document Intake & Classification Pipeline
 */

// -------------------------------------------------------------------
// Mocks — hoisted above require() calls
// -------------------------------------------------------------------

const mockMessagesCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate }
  }));
});

const mockPdfParse = jest.fn();
jest.mock('pdf-parse', () => mockPdfParse);

// -------------------------------------------------------------------
// Setup
// -------------------------------------------------------------------

const ORIGINAL_ENV = process.env;

beforeEach(() => {
  jest.resetModules();
  mockMessagesCreate.mockReset();
  mockPdfParse.mockReset();
  process.env = { ...ORIGINAL_ENV, ANTHROPIC_API_KEY: 'test-key-12345' };
});

afterEach(() => {
  process.env = ORIGINAL_ENV;
});

/**
 * Helper: require a fresh ocrService instance.
 * Must be called AFTER mocks are in place and env is set.
 */
function getOcrService() {
  // Clear cached module to get fresh singleton with current env
  delete require.cache[require.resolve('../../services/ocrService')];
  return require('../../services/ocrService');
}

// -------------------------------------------------------------------
// Fixtures
// -------------------------------------------------------------------

const MEANINGFUL_TEXT = 'This is a mortgage statement with detailed payment information for the account holder. ' +
  'Principal balance: $250,000.00. Interest rate: 6.5%. Monthly payment: $1,580.17. ' +
  'Escrow balance: $4,200.00. Payment due date: March 1, 2026. ' +
  'Loan origination date: January 15, 2020. Servicer: National Mortgage Corp. ' +
  'Property address: 123 Main Street, Springfield, IL 62704.';

const SHORT_TEXT = 'PDF metadata only';

const VISION_RESPONSE = {
  content: [{ text: 'Extracted text from scanned document via Vision API' }],
  model: 'claude-sonnet-4-5-20250514',
  usage: { input_tokens: 500, output_tokens: 100 }
};

const PDF_BUFFER = Buffer.from('fake-pdf-content');
const IMAGE_BUFFER = Buffer.from('fake-image-content');

// ===================================================================
// Tests
// ===================================================================

describe('OcrService', () => {

  // -----------------------------------------------------------------
  // 1. Text PDF extraction via pdf-parse
  // -----------------------------------------------------------------
  describe('Text PDF extraction', () => {
    it('extracts text from text-based PDF using pdf-parse', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({
        text: MEANINGFUL_TEXT,
        numpages: 3
      });

      const result = await ocrService.extractText(PDF_BUFFER, 'statement.pdf');

      expect(result.text).toBe(MEANINGFUL_TEXT);
      expect(result.method).toBe('pdf-parse');
      expect(result.pageCount).toBe(3);
      expect(result.confidence).toBeGreaterThan(0);
      expect(result.confidence).toBeLessThanOrEqual(0.90);
      expect(result.qualityMetrics).toBeDefined();
      expect(result.qualityMetrics.qualityScore).toBeGreaterThanOrEqual(0);
      expect(result.qualityMetrics.qualityScore).toBeLessThanOrEqual(1);
    });

    it('does NOT call Claude Vision when pdf-parse returns meaningful text', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({
        text: MEANINGFUL_TEXT,
        numpages: 1
      });

      await ocrService.extractText(PDF_BUFFER, 'document.pdf');

      expect(mockPdfParse).toHaveBeenCalledWith(PDF_BUFFER);
      expect(mockMessagesCreate).not.toHaveBeenCalled();
    });
  });

  // -----------------------------------------------------------------
  // 2. Scanned PDF fallback to Claude Vision
  // -----------------------------------------------------------------
  describe('Scanned PDF fallback to Vision', () => {
    it('falls back to Claude Vision when pdf-parse returns short text', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({
        text: SHORT_TEXT,
        numpages: 1
      });

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      const result = await ocrService.extractText(PDF_BUFFER, 'scanned.pdf');

      expect(result.text).toBe('Extracted text from scanned document via Vision API');
      expect(result.method).toBe('claude-vision');
      expect(result.pageCount).toBeNull();
      expect(result.confidence).toBeGreaterThan(0);
      expect(result.confidence).toBeLessThanOrEqual(0.80);
      expect(result.qualityMetrics).toBeDefined();
    });

    it('falls back to Claude Vision when pdf-parse returns empty text', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({
        text: '',
        numpages: 2
      });

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      const result = await ocrService.extractText(PDF_BUFFER, 'blank-text.pdf');

      expect(result.method).toBe('claude-vision');
      expect(mockMessagesCreate).toHaveBeenCalled();
    });

    it('sends PDF to Vision with application/pdf MIME type', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({ text: '', numpages: 1 });
      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      await ocrService.extractText(PDF_BUFFER, 'scanned.pdf');

      const callArgs = mockMessagesCreate.mock.calls[0][0];
      const imageContent = callArgs.messages[0].content[0];
      expect(imageContent.source.media_type).toBe('application/pdf');
      expect(imageContent.source.type).toBe('base64');
      expect(imageContent.source.data).toBe(PDF_BUFFER.toString('base64'));
    });
  });

  // -----------------------------------------------------------------
  // 3. Image extraction via Claude Vision
  // -----------------------------------------------------------------
  describe('Image extraction', () => {
    it('routes .jpg files directly to Claude Vision', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      const result = await ocrService.extractText(IMAGE_BUFFER, 'photo.jpg');

      expect(result.text).toBe('Extracted text from scanned document via Vision API');
      expect(result.method).toBe('claude-vision');
      expect(mockPdfParse).not.toHaveBeenCalled();
    });

    it('routes .png files directly to Claude Vision', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      const result = await ocrService.extractText(IMAGE_BUFFER, 'screenshot.png');

      expect(result.method).toBe('claude-vision');
      expect(mockPdfParse).not.toHaveBeenCalled();
    });

    it('routes .jpeg files directly to Claude Vision', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      await ocrService.extractText(IMAGE_BUFFER, 'scan.jpeg');

      const callArgs = mockMessagesCreate.mock.calls[0][0];
      expect(callArgs.messages[0].content[0].source.media_type).toBe('image/jpeg');
    });

    it('routes .heic files directly to Claude Vision', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      await ocrService.extractText(IMAGE_BUFFER, 'iphone-photo.heic');

      const callArgs = mockMessagesCreate.mock.calls[0][0];
      expect(callArgs.messages[0].content[0].source.media_type).toBe('image/heic');
    });

    it('routes .tiff files directly to Claude Vision', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      await ocrService.extractText(IMAGE_BUFFER, 'document.tiff');

      const callArgs = mockMessagesCreate.mock.calls[0][0];
      expect(callArgs.messages[0].content[0].source.media_type).toBe('image/tiff');
    });

    it('uses claude-sonnet-4-5-20250514 model for Vision', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      await ocrService.extractText(IMAGE_BUFFER, 'photo.jpg');

      const callArgs = mockMessagesCreate.mock.calls[0][0];
      expect(callArgs.model).toBe('claude-sonnet-4-5-20250514');
      expect(callArgs.max_tokens).toBe(8192);
    });
  });

  // -----------------------------------------------------------------
  // 4. Unsupported file types
  // -----------------------------------------------------------------
  describe('Unsupported file types', () => {
    it('throws error for .docx files', async () => {
      const ocrService = getOcrService();

      await expect(
        ocrService.extractText(Buffer.from('content'), 'document.docx')
      ).rejects.toThrow('Unsupported file type: .docx');
    });

    it('throws error for .zip files', async () => {
      const ocrService = getOcrService();

      await expect(
        ocrService.extractText(Buffer.from('content'), 'archive.zip')
      ).rejects.toThrow('Unsupported file type: .zip');
    });

    it('throws error for .xlsx files', async () => {
      const ocrService = getOcrService();

      await expect(
        ocrService.extractText(Buffer.from('content'), 'spreadsheet.xlsx')
      ).rejects.toThrow('Unsupported file type: .xlsx');
    });

    it('includes supported types in error message', async () => {
      const ocrService = getOcrService();

      await expect(
        ocrService.extractText(Buffer.from('content'), 'file.docx')
      ).rejects.toThrow(/Supported types: pdf, jpg, jpeg, png, heic, tiff/);
    });
  });

  // -----------------------------------------------------------------
  // 5. pdf-parse failure fallback
  // -----------------------------------------------------------------
  describe('pdf-parse failure fallback', () => {
    it('falls back to Claude Vision when pdf-parse throws an error', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockRejectedValue(new Error('Invalid PDF structure'));
      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      const result = await ocrService.extractText(PDF_BUFFER, 'corrupted.pdf');

      expect(result.method).toBe('claude-vision');
      expect(result.text).toBe('Extracted text from scanned document via Vision API');
    });
  });

  // -----------------------------------------------------------------
  // 6. Claude Vision failure
  // -----------------------------------------------------------------
  describe('Claude Vision failure', () => {
    it('throws with context when Anthropic API returns error for image', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockRejectedValue(new Error('API rate limit exceeded'));

      await expect(
        ocrService.extractText(IMAGE_BUFFER, 'photo.jpg')
      ).rejects.toThrow('Vision OCR failed: API rate limit exceeded');
    });

    it('throws with context when Anthropic API fails for scanned PDF fallback', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({ text: '', numpages: 1 });
      mockMessagesCreate.mockRejectedValue(new Error('Service unavailable'));

      await expect(
        ocrService.extractText(PDF_BUFFER, 'scanned.pdf')
      ).rejects.toThrow('Vision OCR failed: Service unavailable');
    });
  });

  // -----------------------------------------------------------------
  // 7. Missing API key
  // -----------------------------------------------------------------
  describe('Missing ANTHROPIC_API_KEY', () => {
    it('throws clear error when API key is not set and image extraction is needed', async () => {
      delete process.env.ANTHROPIC_API_KEY;
      const ocrService = getOcrService();

      await expect(
        ocrService.extractText(IMAGE_BUFFER, 'photo.jpg')
      ).rejects.toThrow('OCR requires ANTHROPIC_API_KEY for image processing');
    });

    it('throws clear error when API key is not set and scanned PDF falls back to Vision', async () => {
      delete process.env.ANTHROPIC_API_KEY;
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({ text: '', numpages: 1 });

      await expect(
        ocrService.extractText(PDF_BUFFER, 'scanned.pdf')
      ).rejects.toThrow('OCR requires ANTHROPIC_API_KEY for image processing');
    });
  });

  // -----------------------------------------------------------------
  // Input validation
  // -----------------------------------------------------------------
  describe('Input validation', () => {
    it('throws when fileBuffer is null', async () => {
      const ocrService = getOcrService();

      await expect(
        ocrService.extractText(null, 'file.pdf')
      ).rejects.toThrow('File buffer is required');
    });

    it('throws when fileBuffer is empty', async () => {
      const ocrService = getOcrService();

      await expect(
        ocrService.extractText(Buffer.alloc(0), 'file.pdf')
      ).rejects.toThrow('File buffer is required');
    });

    it('throws when fileName is missing', async () => {
      const ocrService = getOcrService();

      await expect(
        ocrService.extractText(PDF_BUFFER, '')
      ).rejects.toThrow('File name is required');
    });
  });

  // -----------------------------------------------------------------
  // _assessTextQuality
  // -----------------------------------------------------------------
  describe('_assessTextQuality', () => {
    it('returns high quality score for proper sentences', () => {
      const ocrService = getOcrService();

      const result = ocrService._assessTextQuality(MEANINGFUL_TEXT);

      expect(result.qualityScore).toBeGreaterThanOrEqual(0.8);
      expect(result.wordCount).toBeGreaterThan(20);
      expect(result.avgWordLength).toBeGreaterThanOrEqual(3);
      expect(result.avgWordLength).toBeLessThanOrEqual(15);
      expect(result.alphaRatio).toBeGreaterThanOrEqual(0.5);
      expect(result.lineCount).toBeGreaterThanOrEqual(1);
    });

    it('returns low quality score for gibberish text', () => {
      const ocrService = getOcrService();

      const gibberish = '# $ @ ! % ^ & * ( ) + = - ~ ` |';
      const result = ocrService._assessTextQuality(gibberish);

      // Single-char symbols: low alpha ratio, bad avg word length
      expect(result.qualityScore).toBeLessThanOrEqual(0.4);
      expect(result.alphaRatio).toBeLessThan(0.5);
    });

    it('reduces quality score for short text with fewer than 20 words', () => {
      const ocrService = getOcrService();

      const shortText = 'Only a few words here in this text.';
      const result = ocrService._assessTextQuality(shortText);

      expect(result.wordCount).toBeLessThan(20);
      expect(result.qualityScore).toBeLessThan(1.0);
    });

    it('clamps quality score to [0.0, 1.0] range', () => {
      const ocrService = getOcrService();

      // Even the worst text should not go below 0
      const terrible = '!! @@ ## $$ %%';
      const result = ocrService._assessTextQuality(terrible);

      expect(result.qualityScore).toBeGreaterThanOrEqual(0.0);
      expect(result.qualityScore).toBeLessThanOrEqual(1.0);
    });
  });

  // -----------------------------------------------------------------
  // Dynamic confidence scoring
  // -----------------------------------------------------------------
  describe('Dynamic confidence scoring', () => {
    it('pdf-parse confidence is dynamic based on quality (not hardcoded 0.95)', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({
        text: MEANINGFUL_TEXT,
        numpages: 2
      });

      const result = await ocrService.extractText(PDF_BUFFER, 'statement.pdf');

      // Dynamic: 0.90 * qualityScore, so never exactly 0.95
      expect(result.confidence).not.toBe(0.95);
      expect(result.confidence).toBeGreaterThan(0);
      expect(result.confidence).toBeLessThanOrEqual(0.90);
    });

    it('Vision confidence is dynamic based on quality (not hardcoded 0.85)', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      const result = await ocrService.extractText(IMAGE_BUFFER, 'photo.jpg');

      // Dynamic: 0.80 * qualityScore, so never exactly 0.85
      expect(result.confidence).not.toBe(0.85);
      expect(result.confidence).toBeGreaterThan(0);
      expect(result.confidence).toBeLessThanOrEqual(0.80);
    });

    it('includes qualityMetrics in pdf-parse extraction results', async () => {
      const ocrService = getOcrService();

      mockPdfParse.mockResolvedValue({
        text: MEANINGFUL_TEXT,
        numpages: 1
      });

      const result = await ocrService.extractText(PDF_BUFFER, 'doc.pdf');

      expect(result.qualityMetrics).toBeDefined();
      expect(result.qualityMetrics).toHaveProperty('wordCount');
      expect(result.qualityMetrics).toHaveProperty('avgWordLength');
      expect(result.qualityMetrics).toHaveProperty('alphaRatio');
      expect(result.qualityMetrics).toHaveProperty('lineCount');
      expect(result.qualityMetrics).toHaveProperty('qualityScore');
    });

    it('includes qualityMetrics in Vision extraction results', async () => {
      const ocrService = getOcrService();

      mockMessagesCreate.mockResolvedValue(VISION_RESPONSE);

      const result = await ocrService.extractText(IMAGE_BUFFER, 'photo.jpg');

      expect(result.qualityMetrics).toBeDefined();
      expect(result.qualityMetrics).toHaveProperty('wordCount');
      expect(result.qualityMetrics).toHaveProperty('qualityScore');
    });
  });

  // -----------------------------------------------------------------
  // _detectFileType
  // -----------------------------------------------------------------
  describe('_detectFileType', () => {
    it('detects PDF files', () => {
      const ocrService = getOcrService();

      const result = ocrService._detectFileType('document.pdf');

      expect(result).toEqual({ isPdf: true, isImage: false, mimeType: 'application/pdf' });
    });

    it('detects JPG images', () => {
      const ocrService = getOcrService();

      const result = ocrService._detectFileType('photo.jpg');

      expect(result).toEqual({ isPdf: false, isImage: true, mimeType: 'image/jpeg' });
    });

    it('detects PNG images', () => {
      const ocrService = getOcrService();

      const result = ocrService._detectFileType('screenshot.png');

      expect(result).toEqual({ isPdf: false, isImage: true, mimeType: 'image/png' });
    });

    it('returns unsupported for unknown extensions', () => {
      const ocrService = getOcrService();

      const result = ocrService._detectFileType('file.docx');

      expect(result).toEqual({ isPdf: false, isImage: false, mimeType: null });
    });

    it('handles case-insensitive extensions', () => {
      const ocrService = getOcrService();

      const result = ocrService._detectFileType('DOCUMENT.PDF');

      expect(result).toEqual({ isPdf: true, isImage: false, mimeType: 'application/pdf' });
    });
  });
});
