/**
 * Cross-Document Data Aggregation Service
 *
 * Collects analysis reports for all documents in a case, normalizes extracted
 * data for comparison, and builds typed comparison pairs based on the
 * cross-document comparison configuration.
 *
 * This is the data preparation layer — it bridges individual document analyses
 * (Phase 12) and cross-document comparison (Phase 13 Plan 03).
 *
 * Input: caseId, userId
 * Output: Aggregated documents with analysis data + typed comparison pairs
 *
 * Data sources (in priority order):
 *  1. Document's analysis_results from Supabase (via caseFileService.getCase)
 *  2. Pipeline in-memory state (via documentPipelineService.pipelineState)
 */

const { createLogger } = require('../utils/logger');
const caseFileService = require('./caseFileService');
const documentPipelineService = require('./documentPipelineService');
const { getComparisonPairsForDocTypes } = require('../config/crossDocumentComparisons');

const logger = createLogger('cross-document-aggregation');

class CrossDocumentAggregationService {

  /**
   * Aggregate all analyzed documents in a case and build comparison pairs.
   *
   * @param {string} caseId - The case file ID
   * @param {string} userId - The user ID (for authorization scoping)
   * @returns {Promise<Object>} Aggregated documents and comparison pairs
   * @throws {Error} "Case not found" if case does not exist
   * @throws {Error} "No documents found in case" if case has no documents
   */
  async aggregateForCase(caseId, userId) {
    logger.info('Aggregating documents for cross-document analysis', { caseId, userId });

    // 1. Get case with documents
    const caseData = await this._getCase(caseId, userId);

    // 2. Build normalized document records
    const documents = [];
    const documentsWithoutAnalysis = [];

    for (const doc of caseData.documents) {
      const normalized = this._normalizeDocument(doc);
      documents.push(normalized);

      if (!normalized.analysisReport) {
        documentsWithoutAnalysis.push(normalized.documentId);
      }
    }

    const analyzedDocuments = documents.filter(d => d.analysisReport !== null);

    // 3. Build comparison pairs from analyzed documents
    const comparisonPairs = this._buildComparisonPairs(analyzedDocuments);

    logger.info('Aggregation complete', {
      caseId,
      totalDocuments: documents.length,
      analyzedDocuments: analyzedDocuments.length,
      comparisonPairs: comparisonPairs.length,
      documentsWithoutAnalysis: documentsWithoutAnalysis.length
    });

    return {
      caseId,
      documents,
      comparisonPairs,
      documentsWithoutAnalysis,
      totalDocuments: documents.length,
      analyzedDocuments: analyzedDocuments.length
    };
  }

  /**
   * Get case with documents, throwing descriptive errors for missing cases.
   *
   * @param {string} caseId
   * @param {string} userId
   * @returns {Promise<Object>} Case data with documents array
   * @private
   */
  async _getCase(caseId, userId) {
    let caseData;

    try {
      caseData = await caseFileService.getCase({ caseId, userId });
    } catch (error) {
      logger.error('Failed to retrieve case', { caseId, userId, error: error.message });
      throw error;
    }

    if (!caseData) {
      throw new Error('Case not found');
    }

    if (!caseData.documents || caseData.documents.length === 0) {
      throw new Error('No documents found in case');
    }

    return caseData;
  }

  /**
   * Normalize a document record into the aggregation output format.
   *
   * Checks for analysis data in this priority:
   *  1. analysis_results from the Supabase document record
   *  2. Pipeline in-memory state (documentPipelineService.pipelineState)
   *
   * @param {Object} doc - Raw document record from caseFileService.getCase()
   * @returns {Object} Normalized document record
   * @private
   */
  _normalizeDocument(doc) {
    const documentId = doc.document_id;

    // Try to get analysis from the document record (Supabase)
    let analysisReport = doc.analysis_results || null;
    let classificationData = null;

    // If no analysis in Supabase, check pipeline in-memory state
    if (!analysisReport) {
      const pipelineData = documentPipelineService.pipelineState.get(documentId);
      if (pipelineData && pipelineData.analysisResults) {
        analysisReport = pipelineData.analysisResults;
        classificationData = pipelineData.classificationResults || null;
      }
    }

    // Extract classification type/subtype from analysis report or pipeline
    let documentType = null;
    let documentSubtype = null;

    if (analysisReport && analysisReport.documentInfo) {
      documentType = analysisReport.documentInfo.documentType;
      documentSubtype = analysisReport.documentInfo.documentSubtype;
    } else if (classificationData) {
      documentType = classificationData.classificationType;
      documentSubtype = classificationData.classificationSubtype;
    }

    return {
      documentId,
      documentType,
      documentSubtype,
      analysisReport,
      extractedData: analysisReport?.extractedData || {},
      anomalies: analysisReport?.anomalies || [],
      completeness: analysisReport?.completeness || null,
      analyzedAt: analysisReport?.documentInfo?.analyzedAt || null
    };
  }

  /**
   * Build all comparison pairs for analyzed documents.
   *
   * For each unique pair of analyzed documents (i, j) where i < j,
   * check if their document types match any comparison pair configuration.
   * If so, create a comparison pair record.
   *
   * @param {Array} analyzedDocuments - Documents with analysis data
   * @returns {Array} Comparison pair records
   * @private
   */
  _buildComparisonPairs(analyzedDocuments) {
    const pairs = [];

    // Need at least 2 analyzed documents to form pairs
    if (analyzedDocuments.length < 2) {
      return pairs;
    }

    // Generate all unique combinations (N choose 2)
    for (let i = 0; i < analyzedDocuments.length; i++) {
      for (let j = i + 1; j < analyzedDocuments.length; j++) {
        const docA = analyzedDocuments[i];
        const docB = analyzedDocuments[j];

        // Skip if either document lacks classification
        if (!docA.documentType || !docB.documentType) {
          continue;
        }

        // Find matching comparison pair configurations
        const matchingPairs = getComparisonPairsForDocTypes(
          docA.documentType, docA.documentSubtype,
          docB.documentType, docB.documentSubtype
        );

        // Create a comparison pair record for each matching configuration
        for (const config of matchingPairs) {
          pairs.push({
            pairId: config.id,
            docA: {
              documentId: docA.documentId,
              documentType: docA.documentType,
              documentSubtype: docA.documentSubtype
            },
            docB: {
              documentId: docB.documentId,
              documentType: docB.documentType,
              documentSubtype: docB.documentSubtype
            },
            comparisonFields: config.comparisonFields,
            discrepancyTypes: config.discrepancyTypes,
            forensicSignificance: config.forensicSignificance
          });
        }
      }
    }

    return pairs;
  }
}

module.exports = new CrossDocumentAggregationService();
