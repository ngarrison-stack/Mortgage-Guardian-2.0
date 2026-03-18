const { createClient } = require('@supabase/supabase-js');
const { createLogger } = require('../utils/logger');
const documentService = require('./documentService');
const claudeService = require('./claudeService');
const ocrService = require('./ocrService');
const classificationService = require('./classificationService');
const caseFileService = require('./caseFileService');
const documentAnalysisService = require('./documentAnalysisService');
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
 *
 * Persistence:
 *   - In-memory Map is the primary store for active pipelines (fast).
 *   - Supabase pipeline_state table is the recovery mechanism for server restarts.
 *   - DB persistence is best-effort — pipeline never blocks on DB failures.
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

// Initialize Supabase client for pipeline state persistence
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

let supabase = null;
if (supabaseUrl && supabaseServiceKey) {
  supabase = createClient(supabaseUrl, supabaseServiceKey);
  logger.info('Supabase client initialized for pipeline state persistence');
} else {
  logger.warn('Supabase not configured - pipeline state will be in-memory only');
}

class DocumentPipelineService {
  constructor() {
    // In-memory tracking — primary store for active pipelines
    this.pipelineState = new Map();
    // Track scheduled cleanup timers so they can be cancelled if needed
    this._cleanupTimers = new Map();
  }

  /**
   * Get the current size of the in-memory pipeline state Map.
   * Useful for monitoring and alerting on memory growth.
   *
   * @returns {number} Number of entries in the pipeline state Map
   */
  getMapSize() {
    return this.pipelineState.size;
  }

  /**
   * Safety valve: if the pipeline state Map exceeds 1000 entries,
   * log a warning and evict the oldest 100 entries (by Map insertion order).
   * Called before adding new entries to prevent unbounded growth.
   */
  _enforceMapSizeLimit() {
    if (this.pipelineState.size > 1000) {
      logger.warn('Pipeline state Map exceeded 1000 entries, evicting oldest 100', {
        currentSize: this.pipelineState.size
      });
      const keys = [...this.pipelineState.keys()].slice(0, 100);
      for (const key of keys) {
        this.pipelineState.delete(key);
        // Cancel any pending cleanup timer for evicted entries
        const timer = this._cleanupTimers.get(key);
        if (timer) {
          clearTimeout(timer);
          this._cleanupTimers.delete(key);
        }
      }
    }
  }

  /**
   * Schedule cleanup of a pipeline entry after a grace period.
   * Clients may still poll for final status, so we delay removal
   * by 5 minutes after reaching a terminal state.
   *
   * @param {string} documentId - Document identifier to clean up
   */
  _scheduleCleanup(documentId) {
    // Cancel any existing timer for this document
    const existing = this._cleanupTimers.get(documentId);
    if (existing) {
      clearTimeout(existing);
    }

    const timer = setTimeout(() => {
      this.pipelineState.delete(documentId);
      this._cleanupTimers.delete(documentId);
      logger.info('Pipeline state cleaned up after grace period', { documentId });
    }, 5 * 60 * 1000);

    // Ensure the timer doesn't prevent Node.js from exiting
    if (timer.unref) {
      timer.unref();
    }

    this._cleanupTimers.set(documentId, timer);
  }

  // ============================================
  // DATABASE PERSISTENCE (best-effort)
  // ============================================

  /**
   * Persist pipeline state to the database.
   * Best-effort: logs warning on failure but never throws.
   * Uses document_id as the natural key for upsert.
   *
   * @param {Object} pipeline - Pipeline state object
   */
  async _persistPipeline(pipeline) {
    if (!supabase) return;

    try {
      const row = {
        document_id: pipeline.documentId,
        user_id: pipeline.userId,
        document_type: pipeline.documentType,
        file_name: pipeline.fileName || null,
        status: pipeline.status,
        steps: pipeline.steps,
        extracted_text: pipeline.extractedText,
        classification_results: pipeline.classificationResults,
        analysis_results: pipeline.analysisResults,
        case_id: pipeline.caseId,
        error: pipeline.error,
        retry_count: pipeline.retryCount,
        created_at: pipeline.createdAt,
        updated_at: pipeline.updatedAt
      };

      const { error } = await supabase
        .from('pipeline_state')
        .upsert(row, { onConflict: 'document_id' });

      if (error) {
        logger.warn('Failed to persist pipeline state', {
          documentId: pipeline.documentId,
          error: error.message
        });
      }
    } catch (err) {
      logger.warn('Pipeline state persistence error', {
        documentId: pipeline.documentId,
        error: err.message
      });
    }
  }

  /**
   * Load pipeline state from the database.
   * Falls back to in-memory Map if DB is unavailable.
   * When loaded from DB, populates the in-memory Map for fast access.
   *
   * @param {string} documentId - Document identifier
   * @returns {Object|null} Pipeline state or null if not found
   */
  async _loadPipeline(documentId) {
    // Check in-memory first (fast path)
    const cached = this.pipelineState.get(documentId);
    if (cached) return cached;

    // Try database fallback
    if (!supabase) return null;

    try {
      const { data, error } = await supabase
        .from('pipeline_state')
        .select('*')
        .eq('document_id', documentId)
        .single();

      if (error || !data) return null;

      // Convert DB row to pipeline object
      const pipeline = {
        documentId: data.document_id,
        userId: data.user_id,
        documentType: data.document_type,
        fileName: data.file_name,
        status: data.status,
        steps: data.steps || {},
        extractedText: data.extracted_text,
        classificationResults: data.classification_results,
        analysisResults: data.analysis_results,
        caseId: data.case_id,
        error: data.error,
        retryCount: data.retry_count || 0,
        createdAt: data.created_at,
        updatedAt: data.updated_at
      };

      // Populate in-memory Map for subsequent fast access
      this.pipelineState.set(documentId, pipeline);

      logger.info('Pipeline state recovered from database', {
        documentId,
        status: pipeline.status
      });

      return pipeline;
    } catch (err) {
      logger.warn('Failed to load pipeline from database', {
        documentId,
        error: err.message
      });
      return null;
    }
  }

  // ============================================
  // CASE FILE AUTO-ASSOCIATION
  // ============================================

  /**
   * Auto-associate document with an open case file after classification.
   *
   * Rules:
   * - If exactly one open case exists for the user, auto-associate.
   * - If no open cases, skip (user can manually associate later).
   * - If multiple open cases, skip (ambiguous — user decides).
   *
   * Best-effort: never blocks pipeline on association failure.
   *
   * @param {Object} pipeline - Pipeline state object
   */
  async _associateWithCase(pipeline) {
    try {
      const openCases = await caseFileService.getCasesByUser({
        userId: pipeline.userId,
        status: 'open'
      });

      if (openCases.length === 1) {
        const caseId = openCases[0].id;

        await caseFileService.addDocumentToCase({
          caseId,
          documentId: pipeline.documentId,
          userId: pipeline.userId
        });

        pipeline.caseId = caseId;
        this.pipelineState.set(pipeline.documentId, pipeline);

        logger.info('Document auto-associated with case', {
          documentId: pipeline.documentId,
          caseId,
          caseName: openCases[0].case_name
        });
      } else if (openCases.length === 0) {
        logger.info('No open cases for auto-association', {
          documentId: pipeline.documentId,
          userId: pipeline.userId
        });
      } else {
        logger.info('Multiple open cases — skipping auto-association', {
          documentId: pipeline.documentId,
          userId: pipeline.userId,
          openCaseCount: openCases.length
        });
      }
    } catch (err) {
      // Best-effort — don't block pipeline on association failure
      logger.warn('Case auto-association failed', {
        documentId: pipeline.documentId,
        error: err.message
      });
    }
  }

  // ============================================
  // PIPELINE LIFECYCLE
  // ============================================

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

    this._enforceMapSizeLimit();
    this.pipelineState.set(documentId, pipeline);
    // Best-effort DB persistence (fire and forget)
    this._persistPipeline(pipeline).catch(() => {});
    logger.info('Pipeline initialized', { documentId, userId, documentType });
    return pipeline;
  }

  /**
   * Get the current pipeline status for a document.
   * Tries in-memory Map first, falls back to database.
   */
  async getStatus(documentId) {
    // Try loading from DB if not in memory
    const pipeline = await this._loadPipeline(documentId);
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
   * Synchronous version for cases where async is not feasible.
   * Only checks in-memory Map (no DB fallback).
   */
  getStatusSync(documentId) {
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
    // Try loading from DB before checking in-memory
    let pipeline = await this._loadPipeline(documentId);

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
        // Auto-associate with case file after classification
        await this._associateWithCase(pipeline);
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
      // Persist failure state
      this._persistPipeline(pipeline).catch(() => {});
      // Schedule cleanup after grace period
      this._scheduleCleanup(documentId);

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
    // Try loading from DB if not in memory
    const pipeline = await this._loadPipeline(documentId);

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
      results.push(this.getStatusSync(pipeline.documentId));
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
    // Persist after OCR completion
    this._persistPipeline(pipeline).catch(() => {});
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
    // Persist after classification completion
    this._persistPipeline(pipeline).catch(() => {});

    logger.info('Classification complete', {
      documentId: pipeline.documentId,
      classificationType: result.classificationType,
      classificationSubtype: result.classificationSubtype,
      confidence: result.confidence
    });
  }

  /**
   * Step 3: Deep document analysis using documentAnalysisService.
   *
   * Passes classification results (from _runClassification step) to enable
   * type-specific analysis prompts, completeness scoring, and anomaly detection.
   */
  async _runAnalysis(pipeline) {
    this._advanceState(pipeline, PIPELINE_STATES.ANALYZING);

    // Use classification results from pipeline (set during _runClassification step)
    const classification = {
      classificationType: pipeline.classificationResults?.classificationType || pipeline.documentType || 'unknown',
      classificationSubtype: pipeline.classificationResults?.classificationSubtype || 'unknown',
      confidence: pipeline.classificationResults?.confidence || 0,
      extractedMetadata: pipeline.classificationResults?.extractedMetadata || {}
    };

    const analysisResult = await documentAnalysisService.analyzeDocument(
      pipeline.extractedText,
      classification,
      { userId: pipeline.userId }
    );

    pipeline.analysisResults = analysisResult;

    pipeline.steps.analyzing = {
      completedAt: new Date().toISOString(),
      classificationType: classification.classificationType,
      classificationSubtype: classification.classificationSubtype
    };
    pipeline.updatedAt = new Date().toISOString();
    this.pipelineState.set(pipeline.documentId, pipeline);
    // Persist after analysis completion
    this._persistPipeline(pipeline).catch(() => {});

    // Log analysis completion with key metrics
    logger.info('Document analysis complete', {
      documentId: pipeline.documentId,
      riskLevel: analysisResult?.summary?.riskLevel || 'unknown',
      completenessScore: analysisResult?.completeness?.score || null,
      anomalyCount: analysisResult?.anomalies?.length || 0
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
    // Best-effort persistence on every state transition
    this._persistPipeline(pipeline).catch(() => {});

    logger.info('Pipeline state transition', {
      documentId: pipeline.documentId,
      from: previousState,
      to: newState
    });

    // Schedule cleanup when pipeline reaches a terminal state
    if ([PIPELINE_STATES.COMPLETE, PIPELINE_STATES.FAILED].includes(newState)) {
      this._scheduleCleanup(pipeline.documentId);
    }
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
