const { createLogger } = require('../utils/logger');
const documentService = require('./documentService');
const claudeService = require('./claudeService');
const ocrService = require('./ocrService');
const classificationService = require('./classificationService');
const logger = createLogger('document-pipeline');

/**
 * Document Processing Pipeline
 *
 * Manages the lifecycle of a document from upload through analysis.
 * Each document progresses through defined states, with each transition
 * recorded so failed steps can be retried without re-running completed ones.
 *
 * States:
 *   uploaded -> ocr -> classifying -> analyzing -> analyzed -> review -> complete
 *                                       |
 *                                     failed (at any step, with retry)
 */

const PIPELINE_STATES = {
  UPLOADED: 'uploaded',
  OCR: 'ocr',                    // Server-side text extraction (or client pre-extracted)
  CLASSIFYING: 'classifying',    // AI document classification
  ANALYZING: 'analyzing',
  ANALYZED: 'analyzed',
  REVIEW: 'review',
  COMPLETE: 'complete',
  FAILED: 'failed'
};

// Which state follows which
const STATE_TRANSITIONS = {
  [PIPELINE_STATES.UPLOADED]: PIPELINE_STATES.OCR,
  [PIPELINE_STATES.OCR]: PIPELINE_STATES.CLASSIFYING,
  [PIPELINE_STATES.CLASSIFYING]: PIPELINE_STATES.ANALYZING,
  [PIPELINE_STATES.ANALYZING]: PIPELINE_STATES.ANALYZED,
  [PIPELINE_STATES.ANALYZED]: PIPELINE_STATES.REVIEW,
  [PIPELINE_STATES.REVIEW]: PIPELINE_STATES.COMPLETE
};

class DocumentPipelineService {
  constructor() {
    // In-memory tracking (will be replaced by DB table in production)
    this.pipelineState = new Map();
  }

  /**
   * Initialize pipeline tracking for a newly uploaded document.
   */
  initPipeline(documentId, userId, documentType) {
    const pipeline = {
      documentId,
      userId,
      documentType,
      status: PIPELINE_STATES.UPLOADED,
      steps: {
        uploaded: { completedAt: new Date().toISOString() },
        ocr: null,
        classifying: null,
        analyzing: null,
        analyzed: null,
        review: null,
        complete: null
      },
      extractedText: null,
      classificationResults: null,
      analysisResults: null,
      caseId: null,
      error: null,
      retryCount: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    this.pipelineState.set(documentId, pipeline);
    logger.info('Pipeline initialized', { documentId, userId, documentType });
    return pipeline;
  }

  /**
   * Get the current pipeline status for a document.
   */
  getStatus(documentId) {
    const pipeline = this.pipelineState.get(documentId);
    if (!pipeline) {
      return null;
    }

    return {
      documentId: pipeline.documentId,
      status: pipeline.status,
      steps: pipeline.steps,
      error: pipeline.error,
      retryCount: pipeline.retryCount,
      hasAnalysis: !!pipeline.analysisResults,
      hasClassification: !!pipeline.classificationResults,
      caseId: pipeline.caseId,
      createdAt: pipeline.createdAt,
      updatedAt: pipeline.updatedAt
    };
  }

  /**
   * Run the full processing pipeline for a document.
   * Picks up from the last completed step so retries skip finished work.
   */
  async processDocument(documentId, userId, { documentText, fileBuffer, documentType }) {
    let pipeline = this.pipelineState.get(documentId);

    if (!pipeline) {
      pipeline = this.initPipeline(documentId, userId, documentType);
    }

    try {
      // Step 1: OCR — extract text from document
      if (this._shouldRunStep(pipeline, PIPELINE_STATES.OCR)) {
        await this._runOcr(pipeline, { fileBuffer, documentText });
      }

      // Step 2: Classification — identify document type
      if (this._shouldRunStep(pipeline, PIPELINE_STATES.CLASSIFYING)) {
        await this._runClassification(pipeline);
      }

      // Step 3: AI Analysis
      if (this._shouldRunStep(pipeline, PIPELINE_STATES.ANALYZING)) {
        await this._runAnalysis(pipeline);
      }

      // Step 4: Mark as analyzed and ready for review
      if (this._shouldRunStep(pipeline, PIPELINE_STATES.ANALYZED)) {
        this._advanceState(pipeline, PIPELINE_STATES.ANALYZED);
      }

      // Step 5: Ready for user review (cross-reference with Plaid happens here)
      if (this._shouldRunStep(pipeline, PIPELINE_STATES.REVIEW)) {
        this._advanceState(pipeline, PIPELINE_STATES.REVIEW);
        logger.info('Document ready for review', { documentId });
      }

      return {
        success: true,
        documentId,
        status: pipeline.status,
        classificationResults: pipeline.classificationResults,
        analysisResults: pipeline.analysisResults,
        caseId: pipeline.caseId,
        steps: pipeline.steps
      };

    } catch (error) {
      pipeline.status = PIPELINE_STATES.FAILED;
      pipeline.error = {
        message: error.message,
        failedAt: pipeline.status,
        timestamp: new Date().toISOString()
      };
      pipeline.updatedAt = new Date().toISOString();
      this.pipelineState.set(documentId, pipeline);

      logger.error('Pipeline failed', {
        documentId,
        failedAt: pipeline.error.failedAt,
        error: error.message
      });

      return {
        success: false,
        documentId,
        status: PIPELINE_STATES.FAILED,
        error: pipeline.error,
        steps: pipeline.steps
      };
    }
  }

  /**
   * Retry a failed document from the step it failed at.
   */
  async retryDocument(documentId, userId, { documentText, fileBuffer } = {}) {
    const pipeline = this.pipelineState.get(documentId);

    if (!pipeline) {
      throw new Error(`No pipeline found for document ${documentId}`);
    }

    if (pipeline.userId !== userId) {
      throw new Error('Unauthorized');
    }

    if (pipeline.status !== PIPELINE_STATES.FAILED) {
      throw new Error(`Document is not in failed state (current: ${pipeline.status})`);
    }

    // Reset from failure: revert to the step before the failed one
    const failedStep = pipeline.error?.failedAt;
    pipeline.status = this._getPreviousState(failedStep) || PIPELINE_STATES.UPLOADED;
    pipeline.error = null;
    pipeline.retryCount += 1;
    pipeline.updatedAt = new Date().toISOString();

    logger.info('Retrying pipeline', {
      documentId,
      fromState: pipeline.status,
      retryCount: pipeline.retryCount
    });

    // Use stored text if no new text provided
    const text = documentText || pipeline.extractedText;

    return this.processDocument(documentId, userId, {
      documentText: text,
      fileBuffer: fileBuffer || undefined,
      documentType: pipeline.documentType
    });
  }

  /**
   * Mark a document as complete after user review / cross-reference.
   * Called by the client after the user confirms findings.
   */
  completeDocument(documentId, userId) {
    const pipeline = this.pipelineState.get(documentId);

    if (!pipeline) {
      throw new Error(`No pipeline found for document ${documentId}`);
    }

    if (pipeline.userId !== userId) {
      throw new Error('Unauthorized');
    }

    if (pipeline.status !== PIPELINE_STATES.REVIEW) {
      throw new Error(`Document must be in review state to complete (current: ${pipeline.status})`);
    }

    this._advanceState(pipeline, PIPELINE_STATES.COMPLETE);
    logger.info('Document processing complete', { documentId });

    return {
      success: true,
      documentId,
      status: pipeline.status,
      steps: pipeline.steps
    };
  }

  /**
   * Get all documents in the pipeline for a user, optionally filtered by status.
   */
  getUserPipeline(userId, { status } = {}) {
    const results = [];
    for (const pipeline of this.pipelineState.values()) {
      if (pipeline.userId !== userId) continue;
      if (status && pipeline.status !== status) continue;
      results.push(this.getStatus(pipeline.documentId));
    }
    return results.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
  }

  // ============================================
  // PIPELINE STEP IMPLEMENTATIONS
  // ============================================

  /**
   * Step 1: OCR — Extract text from the document.
   *
   * Accepts either a fileBuffer (server-side OCR) or pre-extracted documentText
   * (backward compatibility with iOS Vision OCR). If both are provided,
   * fileBuffer takes precedence for server-side extraction.
   *
   * @param {Object} pipeline - Pipeline state object
   * @param {Object} options - OCR options
   * @param {Buffer|string} [options.fileBuffer] - Raw file content (Buffer or base64 string)
   * @param {string} [options.documentText] - Pre-extracted text from client
   */
  async _runOcr(pipeline, { fileBuffer, documentText }) {
    this._advanceState(pipeline, PIPELINE_STATES.OCR);

    let extractedText;
    let method;

    if (fileBuffer) {
      // Server-side OCR via ocrService
      const buffer = Buffer.isBuffer(fileBuffer)
        ? fileBuffer
        : Buffer.from(fileBuffer, 'base64');

      const ocrResult = await ocrService.extractText(buffer, pipeline.fileName || 'document.pdf');
      extractedText = ocrResult.text;
      method = ocrResult.method; // 'pdf-parse' or 'claude-vision'

      logger.info('OCR complete (server-side)', {
        documentId: pipeline.documentId,
        method,
        textLength: extractedText.length,
        pageCount: ocrResult.pageCount
      });
    } else if (documentText) {
      // Client pre-extracted text (iOS Vision OCR backward compatibility)
      extractedText = documentText;
      method = 'client-provided';

      logger.info('OCR complete (client-provided)', {
        documentId: pipeline.documentId,
        method,
        textLength: extractedText.length
      });
    } else {
      throw new Error('No document content provided. Supply fileBuffer or pre-extracted documentText.');
    }

    // Store extracted text so retries don't need it re-sent
    pipeline.extractedText = extractedText;
    pipeline.steps.ocr = {
      completedAt: new Date().toISOString(),
      method,
      textLength: extractedText.length
    };
    pipeline.updatedAt = new Date().toISOString();
    this.pipelineState.set(pipeline.documentId, pipeline);
  }

  /**
   * Step 2: Classification — Identify document type using AI.
   *
   * Calls classificationService to classify the extracted text into the
   * forensic document taxonomy. Updates pipeline.documentType with the
   * more specific classification result.
   *
   * @param {Object} pipeline - Pipeline state object
   */
  async _runClassification(pipeline) {
    this._advanceState(pipeline, PIPELINE_STATES.CLASSIFYING);

    const result = await classificationService.classifyDocument(
      pipeline.extractedText,
      { existingType: pipeline.documentType }
    );

    // Store classification results
    pipeline.classificationResults = result;

    // Update document type with more specific classification
    if (result.classificationType && result.classificationType !== 'unknown') {
      pipeline.documentType = result.classificationSubtype || result.classificationType;
    }

    pipeline.steps.classifying = {
      completedAt: new Date().toISOString(),
      classificationType: result.classificationType,
      classificationSubtype: result.classificationSubtype,
      confidence: result.confidence
    };
    pipeline.updatedAt = new Date().toISOString();
    this.pipelineState.set(pipeline.documentId, pipeline);

    logger.info('Classification complete', {
      documentId: pipeline.documentId,
      classificationType: result.classificationType,
      classificationSubtype: result.classificationSubtype,
      confidence: result.confidence
    });
  }

  /**
   * Step 3: Send extracted text to Claude for AI analysis.
   */
  async _runAnalysis(pipeline) {
    this._advanceState(pipeline, PIPELINE_STATES.ANALYZING);

    const prompt = claudeService.buildMortgageAnalysisPrompt(
      pipeline.extractedText,
      pipeline.documentType
    );

    const result = await claudeService.analyzeDocument({
      prompt,
      maxTokens: 4096,
      temperature: 0.1
    });

    // Parse Claude's response into structured data
    let parsedAnalysis;
    try {
      parsedAnalysis = JSON.parse(result.content);
    } catch {
      // If Claude didn't return valid JSON, wrap the raw response
      parsedAnalysis = {
        rawAnalysis: result.content,
        parseWarning: 'AI response was not structured JSON'
      };
    }

    pipeline.analysisResults = {
      analysis: parsedAnalysis,
      model: result.model,
      usage: result.usage,
      analyzedAt: new Date().toISOString()
    };

    pipeline.steps.analyzing = {
      completedAt: new Date().toISOString(),
      model: result.model,
      tokensUsed: result.usage.inputTokens + result.usage.outputTokens
    };
    pipeline.updatedAt = new Date().toISOString();
    this.pipelineState.set(pipeline.documentId, pipeline);

    logger.info('AI analysis complete', {
      documentId: pipeline.documentId,
      model: result.model,
      issuesFound: parsedAnalysis.issues?.length || 0
    });
  }

  // ============================================
  // STATE MACHINE HELPERS
  // ============================================

  /**
   * Check if a step needs to run based on current pipeline state.
   */
  _shouldRunStep(pipeline, targetState) {
    const stateOrder = Object.values(PIPELINE_STATES).filter(s => s !== 'failed');
    const currentIdx = stateOrder.indexOf(pipeline.status);
    const targetIdx = stateOrder.indexOf(targetState);

    // Run the step if we haven't reached it yet
    return currentIdx < targetIdx;
  }

  /**
   * Advance the pipeline to the next state.
   */
  _advanceState(pipeline, newState) {
    const previousState = pipeline.status;
    pipeline.status = newState;
    pipeline.steps[newState] = pipeline.steps[newState] || {
      completedAt: new Date().toISOString()
    };
    pipeline.updatedAt = new Date().toISOString();
    this.pipelineState.set(pipeline.documentId, pipeline);

    logger.info('Pipeline state transition', {
      documentId: pipeline.documentId,
      from: previousState,
      to: newState
    });
  }

  /**
   * Get the state before a given state (for retry rollback).
   */
  _getPreviousState(state) {
    const entries = Object.entries(STATE_TRANSITIONS);
    for (const [from, to] of entries) {
      if (to === state) return from;
    }
    return null;
  }
}

module.exports = new DocumentPipelineService();
module.exports.PIPELINE_STATES = PIPELINE_STATES;
