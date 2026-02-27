/**
 * OCR Service — Hybrid Text Extraction
 *
 * Extracts text from uploaded documents using a two-strategy approach:
 *   1. pdf-parse for text-based PDFs (fast, no API cost)
 *   2. Claude Vision for scanned PDFs and images (AI-powered OCR)
 *
 * This removes the dependency on iOS client-side OCR and makes the
 * platform client-agnostic — web uploads work without pre-extracted text.
 *
 * Phase 10-02: Document Intake & Classification Pipeline
 */

const pdfParse = require('pdf-parse');
const Anthropic = require('@anthropic-ai/sdk');
const { createLogger } = require('../utils/logger');
const logger = createLogger('ocr');

// Minimum characters of extracted text to consider a PDF "text-based"
// rather than scanned. Avoids treating scanned PDFs with embedded
// metadata-only text as text PDFs.
const MEANINGFUL_TEXT_THRESHOLD = 50;

// Supported image extensions and their MIME types
const IMAGE_TYPES = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  heic: 'image/heic',
  tiff: 'image/tiff'
};

// Claude Vision prompt for OCR extraction
const VISION_OCR_PROMPT =
  'Extract ALL text from this document image. Preserve the original formatting, ' +
  'layout, and structure as closely as possible. Include all numbers, dates, names, ' +
  'addresses, and financial figures exactly as they appear. Return only the extracted ' +
  'text, no commentary.';

class OcrService {
  constructor() {
    this._client = null;
  }

  /**
   * Lazily initialize the Anthropic client.
   * Deferred so missing API key only errors when Vision is actually needed.
   */
  _getClient() {
    if (!this._client) {
      if (!process.env.ANTHROPIC_API_KEY) {
        throw new Error('OCR requires ANTHROPIC_API_KEY for image processing');
      }
      this._client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    }
    return this._client;
  }

  /**
   * Main entry point — extract text from a file buffer.
   *
   * Routes to the appropriate extractor based on file type:
   *   - PDF  -> _extractFromPdf (with fallback to Vision for scanned PDFs)
   *   - Image -> _extractFromImage (Claude Vision)
   *
   * @param {Buffer} fileBuffer - Raw file content
   * @param {string} fileName - Original file name (used for type detection)
   * @returns {Promise<{text: string, method: string, pageCount: number|null, confidence: number}>}
   */
  async extractText(fileBuffer, fileName) {
    const startTime = Date.now();

    if (!fileBuffer || !Buffer.isBuffer(fileBuffer) || fileBuffer.length === 0) {
      throw new Error('File buffer is required and must be non-empty');
    }

    if (!fileName || typeof fileName !== 'string') {
      throw new Error('File name is required');
    }

    const { isPdf, isImage, mimeType } = this._detectFileType(fileName);

    if (!isPdf && !isImage) {
      const ext = fileName.split('.').pop().toLowerCase();
      throw new Error(`Unsupported file type: .${ext}. Supported types: pdf, jpg, jpeg, png, heic, tiff`);
    }

    let result;

    if (isPdf) {
      result = await this._extractFromPdf(fileBuffer);
    } else {
      result = await this._extractFromImage(fileBuffer, mimeType);
    }

    const elapsed = Date.now() - startTime;
    logger.info('Text extraction complete', {
      fileName,
      method: result.method,
      textLength: result.text.length,
      pageCount: result.pageCount,
      elapsedMs: elapsed
    });

    return result;
  }

  /**
   * Extract text from a PDF buffer.
   *
   * Attempts pdf-parse first. If the extracted text is meaningful (>50 chars
   * after trimming), returns it directly. Otherwise falls back to Claude Vision
   * for scanned/image-based PDFs.
   *
   * @param {Buffer} fileBuffer - PDF file content
   * @returns {Promise<{text: string, method: string, pageCount: number|null, confidence: number}>}
   */
  async _extractFromPdf(fileBuffer) {
    try {
      const pdfData = await pdfParse(fileBuffer);
      const extractedText = (pdfData.text || '').trim();

      if (extractedText.length >= MEANINGFUL_TEXT_THRESHOLD) {
        logger.info('PDF text extraction via pdf-parse succeeded', {
          textLength: extractedText.length,
          pageCount: pdfData.numpages
        });

        return {
          text: extractedText,
          method: 'pdf-parse',
          pageCount: pdfData.numpages || null,
          confidence: 0.95
        };
      }

      // Scanned PDF — text too short to be meaningful
      logger.info('PDF text insufficient, falling back to Claude Vision', {
        extractedLength: extractedText.length,
        threshold: MEANINGFUL_TEXT_THRESHOLD
      });

      return await this._extractFromImage(fileBuffer, 'application/pdf');

    } catch (error) {
      // pdf-parse failed — try Vision as fallback
      logger.warn('pdf-parse failed, falling back to Claude Vision', {
        error: error.message
      });

      return await this._extractFromImage(fileBuffer, 'application/pdf');
    }
  }

  /**
   * Extract text from an image or scanned PDF using Claude Vision.
   *
   * Sends the file as a base64-encoded image to Claude's Vision API
   * with an OCR-focused prompt.
   *
   * @param {Buffer} fileBuffer - Image or PDF file content
   * @param {string} mimeType - MIME type of the file
   * @returns {Promise<{text: string, method: string, pageCount: number|null, confidence: number}>}
   */
  async _extractFromImage(fileBuffer, mimeType) {
    const client = this._getClient();

    try {
      const base64Data = fileBuffer.toString('base64');

      const response = await client.messages.create({
        model: 'claude-sonnet-4-5-20250514',
        max_tokens: 8192,
        messages: [{
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: mimeType,
                data: base64Data
              }
            },
            {
              type: 'text',
              text: VISION_OCR_PROMPT
            }
          ]
        }]
      });

      const extractedText = response.content[0].text || '';

      logger.info('Claude Vision extraction complete', {
        textLength: extractedText.length,
        model: response.model,
        tokensUsed: (response.usage?.input_tokens || 0) + (response.usage?.output_tokens || 0)
      });

      return {
        text: extractedText,
        method: 'claude-vision',
        pageCount: null,
        confidence: 0.85
      };

    } catch (error) {
      logger.error('Claude Vision extraction failed', {
        error: error.message,
        mimeType
      });
      throw new Error(`Vision OCR failed: ${error.message}`);
    }
  }

  /**
   * Detect file type from extension.
   *
   * Uses extension-based detection matching the pattern established
   * in documentService.getContentType().
   *
   * @param {string} fileName - File name with extension
   * @returns {{isPdf: boolean, isImage: boolean, mimeType: string|null}}
   */
  _detectFileType(fileName) {
    const ext = (fileName.split('.').pop() || '').toLowerCase();

    if (ext === 'pdf') {
      return { isPdf: true, isImage: false, mimeType: 'application/pdf' };
    }

    if (IMAGE_TYPES[ext]) {
      return { isPdf: false, isImage: true, mimeType: IMAGE_TYPES[ext] };
    }

    return { isPdf: false, isImage: false, mimeType: null };
  }
}

module.exports = new OcrService();
