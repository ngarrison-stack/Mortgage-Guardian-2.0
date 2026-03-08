const Anthropic = require('@anthropic-ai/sdk');
const { createLogger } = require('../utils/logger');
const { DISCREPANCY_TYPES, SEVERITY_LEVELS } = require('../schemas/crossDocumentAnalysisSchema');

const logger = createLogger('cross-document-comparison');

// Initialize Anthropic client
const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

// Defaults consistent with documentAnalysisService
const DEFAULT_MODEL = 'claude-sonnet-4-5-20250514';
const DEFAULT_MAX_TOKENS = 4096;
const DEFAULT_TEMPERATURE = 0.1;

/**
 * System prompt shared across all comparison types.
 *
 * Establishes the forensic analyst persona — the user message then provides
 * pair-specific comparison instructions and document data.
 */
const SYSTEM_PROMPT = `You are a forensic mortgage document analyst at a major law firm. You are comparing two mortgage-related documents from the same loan file to identify discrepancies, contradictions, and potential regulatory violations.

Your analysis must be thorough, precise, and cite specific field values. When you identify a discrepancy, explain its significance for the borrower and whether it suggests a servicing error, regulatory violation, or potential fraud.

Respond ONLY with valid JSON matching the specified schema.`;

/**
 * Cross-Document Comparison Service
 *
 * Uses Claude AI to perform forensic analysis on document pairs — detecting
 * discrepancies, contradictions, timeline violations, and regulatory concerns
 * across related mortgage documents.
 *
 * While programmatic matching (in crossDocumentAggregationService) finds exact
 * mismatches, this service identifies contextual anomalies that require domain
 * expertise: inconsistent terms across the loan lifecycle, regulatory timing
 * violations, patterns suggesting misapplied payments or improper fee assessment.
 */
class CrossDocumentComparisonService {
  /**
   * Compare two documents using Claude AI forensic analysis.
   *
   * @param {Object} docA - First document
   * @param {string} docA.documentId - Unique document identifier
   * @param {string} docA.documentType - Classification type (e.g. "servicing")
   * @param {string} docA.documentSubtype - Classification subtype (e.g. "monthly_statement")
   * @param {Object} [docA.extractedData] - Extracted data from individual analysis
   * @param {Array} [docA.anomalies] - Anomalies from individual analysis
   * @param {Object} [docA.completeness] - Completeness from individual analysis
   * @param {Object} docB - Second document (same shape as docA)
   * @param {Object} comparisonConfig - Configuration from COMPARISON_PAIRS
   * @param {string} comparisonConfig.pairId - Pair identifier (e.g. "stmt-vs-stmt")
   * @param {Array<string>} comparisonConfig.comparisonFields - Field categories to compare
   * @param {Array<string>} comparisonConfig.discrepancyTypes - Applicable discrepancy types
   * @param {string} comparisonConfig.forensicSignificance - Significance level
   * @returns {Promise<Object>} Comparison result with discrepancies, timeline, summary
   */
  async compareDocumentPair(docA, docB, comparisonConfig) {
    // Validate inputs — return error objects, never throw
    if (!docA || !docB) {
      return {
        pairId: comparisonConfig ? comparisonConfig.pairId : 'unknown',
        documentA: this._buildDocRef(docA),
        documentB: this._buildDocRef(docB),
        discrepancies: [],
        timelineEvents: [],
        timelineViolations: [],
        comparisonSummary: '',
        error: true,
        errorMessage: 'Missing document data'
      };
    }

    if (!comparisonConfig || !comparisonConfig.pairId) {
      return {
        pairId: 'unknown',
        documentA: this._buildDocRef(docA),
        documentB: this._buildDocRef(docB),
        discrepancies: [],
        timelineEvents: [],
        timelineViolations: [],
        comparisonSummary: '',
        error: true,
        errorMessage: 'Missing comparison configuration'
      };
    }

    const pairId = comparisonConfig.pairId;
    const startTime = Date.now();

    logger.info('Starting cross-document comparison', {
      pairId,
      docA: { id: docA.documentId, type: docA.documentType, subtype: docA.documentSubtype },
      docB: { id: docB.documentId, type: docB.documentType, subtype: docB.documentSubtype }
    });

    // Check for empty extractedData on both documents
    const docAHasData = docA.extractedData && Object.keys(docA.extractedData).length > 0;
    const docBHasData = docB.extractedData && Object.keys(docB.extractedData).length > 0;

    if (!docAHasData && !docBHasData) {
      return {
        pairId,
        documentA: this._buildDocRef(docA),
        documentB: this._buildDocRef(docB),
        discrepancies: [],
        timelineEvents: [],
        timelineViolations: [],
        comparisonSummary: '',
        error: true,
        errorMessage: 'Both documents have empty extracted data'
      };
    }

    try {
      const userPrompt = this._buildComparisonPrompt(docA, docB, comparisonConfig);

      const response = await client.messages.create({
        model: DEFAULT_MODEL,
        max_tokens: DEFAULT_MAX_TOKENS,
        temperature: DEFAULT_TEMPERATURE,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: 'user',
            content: userPrompt
          }
        ]
      });

      const responseText = response.content[0].text;
      const usage = response.usage;

      const parsed = this._parseResponse(responseText);

      // If parse failed, return error with rawResponse
      if (parsed.parseError) {
        const duration = Date.now() - startTime;
        logger.warn('Comparison response parse failed', {
          pairId,
          parseError: parsed.parseError,
          duration,
          inputTokens: usage ? usage.input_tokens : null,
          outputTokens: usage ? usage.output_tokens : null
        });
        return {
          pairId,
          documentA: this._buildDocRef(docA),
          documentB: this._buildDocRef(docB),
          discrepancies: [],
          timelineEvents: [],
          timelineViolations: [],
          comparisonSummary: '',
          error: true,
          errorMessage: 'Failed to parse comparison response',
          rawResponse: parsed.rawResponse
        };
      }

      // Enrich and normalize the result
      const result = this._enrichResult(parsed, docA, docB, pairId);

      const duration = Date.now() - startTime;
      logger.info('Cross-document comparison completed', {
        pairId,
        discrepancyCount: result.discrepancies.length,
        timelineEventCount: result.timelineEvents.length,
        timelineViolationCount: result.timelineViolations.length,
        duration,
        inputTokens: usage ? usage.input_tokens : null,
        outputTokens: usage ? usage.output_tokens : null
      });

      return result;

    } catch (error) {
      const duration = Date.now() - startTime;
      logger.error('Cross-document comparison failed', {
        pairId,
        error: error.message,
        stack: error.stack,
        duration
      });

      return {
        pairId,
        documentA: this._buildDocRef(docA),
        documentB: this._buildDocRef(docB),
        discrepancies: [],
        timelineEvents: [],
        timelineViolations: [],
        comparisonSummary: '',
        error: true,
        errorMessage: error.message
      };
    }
  }

  // ---------------------------------------------------------------------------
  // Prompt Engineering
  // ---------------------------------------------------------------------------

  /**
   * Build the user prompt for a comparison, including both documents' data
   * and type-specific forensic instructions.
   *
   * @param {Object} docA - First document
   * @param {Object} docB - Second document
   * @param {Object} comparisonConfig - Comparison configuration
   * @returns {string} Complete user prompt
   */
  _buildComparisonPrompt(docA, docB, comparisonConfig) {
    const { pairId, comparisonFields, discrepancyTypes } = comparisonConfig;

    // Filter extractedData to only include comparison-relevant categories
    const docAFiltered = this._filterExtractedData(docA.extractedData, comparisonFields);
    const docBFiltered = this._filterExtractedData(docB.extractedData, comparisonFields);

    const instructions = this._getComparisonInstructions(pairId);

    return `Compare these two mortgage documents from the same loan file.

## Document A: ${docA.documentType}/${docA.documentSubtype} (ID: ${docA.documentId})

### Extracted Data:
${JSON.stringify(docAFiltered, null, 2)}

### Known Anomalies:
${JSON.stringify(docA.anomalies || [], null, 2)}

## Document B: ${docB.documentType}/${docB.documentSubtype} (ID: ${docB.documentId})

### Extracted Data:
${JSON.stringify(docBFiltered, null, 2)}

### Known Anomalies:
${JSON.stringify(docB.anomalies || [], null, 2)}

## Comparison Instructions

${instructions}

## Applicable Discrepancy Types
${discrepancyTypes.join(', ')}

## Required JSON Output

{
  "discrepancies": [
    {
      "id": "disc-001",
      "type": "one of: ${DISCREPANCY_TYPES.join(', ')}",
      "severity": "one of: ${SEVERITY_LEVELS.join(', ')}",
      "description": "detailed explanation of the discrepancy and its significance",
      "documentA": { "field": "fieldName", "value": "value from Document A" },
      "documentB": { "field": "fieldName", "value": "value from Document B" },
      "regulation": "applicable regulation if any (e.g. RESPA Section 6)",
      "forensicNote": "additional forensic analysis context"
    }
  ],
  "timelineEvents": [
    {
      "date": "ISO date string",
      "documentId": "which document this event comes from",
      "documentType": "document classification type",
      "event": "description of the event",
      "significance": "one of: routine, notable, concerning, critical"
    }
  ],
  "timelineViolations": [
    {
      "description": "explanation of the timeline violation",
      "severity": "one of: ${SEVERITY_LEVELS.join(', ')}",
      "relatedDocuments": ["documentId1", "documentId2"],
      "regulation": "applicable regulation if any"
    }
  ],
  "comparisonSummary": "2-3 sentence summary of the overall comparison findings"
}

If no discrepancies are found, return empty arrays. Do not invent findings.`;
  }

  /**
   * Return forensic comparison instructions specific to the pair type.
   *
   * @param {string} pairId - Comparison pair identifier
   * @returns {string} Pair-specific instructions
   */
  _getComparisonInstructions(pairId) {
    switch (pairId) {
      case 'stmt-vs-stmt':
        return `Focus on balance progression between sequential monthly statements:
- Does the principal balance decrease appropriately given the payment amount and interest rate?
- Are payment amounts consistent, or did they change without a modification notice?
- Are there unexplained fee changes between statements?
- Track escrow balance trajectory — does it follow expected disbursement patterns?
- Identify late charge patterns — are they applied consistently and per loan terms?

FLAG: Balance increases without explanation, fees appearing or disappearing between statements, interest rate changes without ARM adjustment notice.`;

      case 'stmt-vs-closing':
        return `Focus on consistency between current servicing terms and original closing disclosure:
- Does the interest rate on the statement match the closing disclosure rate? It should match exactly unless the loan is an ARM with a valid adjustment.
- Does the monthly payment match the original terms from closing?
- Does the current loan amount track correctly from the original amount considering amortization?

FLAG: Rate changes without ARM adjustment notice, payment amount changes without loan modification, principal balance that doesn't track with original amortization schedule.`;

      case 'stmt-vs-paymenthistory':
        return `Focus on payment application accuracy between statements and payment history:
- Do statement balances reflect the payments shown in the payment history?
- Are all payments in the history properly credited on subsequent statements?
- Is the principal/interest split in the payment history consistent with the statement rate and balance?

FLAG: Payments shown in history but not credited on statement, misapplied payments (incorrect interest vs principal allocation), phantom late fees charged for on-time payments per history records.`;

      case 'stmt-vs-escrow':
        return `Focus on escrow balance tracking between statement and escrow analysis:
- Does the statement's escrow balance match the escrow analysis projections?
- Is the monthly escrow amount on the statement consistent with the escrow analysis?
- Do escrow shortage/surplus amounts match between documents?

FLAG: Escrow shortage that doesn't match actual disbursements, excessive escrow cushion beyond RESPA's legal limit (1/6 of annual disbursements), monthly escrow amount changes without corresponding analysis.`;

      case 'stmt-vs-modification':
        return `Focus on whether loan modification terms are correctly applied in subsequent statements:
- Is the new payment amount from the modification reflected in the statement?
- Is the new interest rate from the modification applied on the statement?
- Does the modified principal balance match what the statement shows?
- Is the modification effective date consistent with when changes appear on statements?

FLAG: Old payment amount still being collected after modification effective date, modification terms not reflected in the first statement after the effective date, interest rate mismatch between modification and statement.`;

      case 'closing-vs-note':
        return `Focus on core loan terms consistency between closing disclosure and promissory note — these documents MUST match exactly:
- Loan amount must be identical between both documents
- Interest rate must be identical
- Loan term and maturity date must be consistent
- Monthly payment amount must match
- Late charge terms should be consistent

FLAG: ANY discrepancy between closing disclosure and promissory note is significant. These are the two foundational origination documents and must agree on all core terms.`;

      case 'stmt-vs-armadjust':
        return `Focus on ARM rate adjustment accuracy between the adjustment notice and subsequent statement:
- Does the new rate on the statement match the rate announced in the adjustment notice?
- Is the new payment amount on the statement consistent with the adjusted rate?
- Does the adjustment timing match — is the new rate applied on or after the effective date from the notice?

FLAG: Rate applied differently than announced in the notice, timing mismatch between effective date and when the rate appears on statements, payment amount that doesn't correspond to the adjusted rate.`;

      case 'correspondence-vs-stmt':
        return `General comparison between servicer correspondence and actual statement records:
- Do amounts mentioned in correspondence (balance, arrearage, fees) match statement records?
- Are dates in correspondence consistent with statement dates?
- Do any claims made in the correspondence contradict what the statements show?

FLAG: Disputed amounts in correspondence that don't match statement records, collection demands for amounts not supported by statements, misrepresented account status.`;

      case 'legal-vs-stmt':
        return `Focus on amounts claimed in legal proceedings versus actual servicing records:
- Does the default amount in legal filings match the actual arrearage on statements?
- Are fees claimed in legal filings documented in the servicing statements?
- Is the total amount claimed in legal proceedings supported by the servicing record?

FLAG: Inflated amounts in legal filings compared to statement records, fees in legal documents not found in servicing records, default amounts that don't reconcile with payment history.`;

      default:
        return `Perform a general forensic comparison of these two documents:
- Compare all shared fields for discrepancies in values, dates, or amounts
- Identify any contradictions between the documents
- Note any timeline inconsistencies
- Flag any regulatory concerns based on the document types involved

Report only findings supported by specific field values from both documents.`;
    }
  }

  // ---------------------------------------------------------------------------
  // Response Processing
  // ---------------------------------------------------------------------------

  /**
   * Parse Claude's comparison response.
   *
   * Follows the same graceful fallback as documentAnalysisService:
   * try direct parse → try markdown code fence extraction → return error.
   *
   * @param {string} responseText - Raw text response from Claude
   * @returns {Object} Parsed comparison data or { rawResponse, parseError }
   */
  _parseResponse(responseText) {
    try {
      return JSON.parse(responseText);
    } catch (directParseError) {
      // Try markdown code fence extraction
      const jsonMatch = responseText.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (jsonMatch) {
        try {
          return JSON.parse(jsonMatch[1].trim());
        } catch (fenceParseError) {
          // Fall through to fallback
        }
      }

      logger.warn('Failed to parse comparison response as JSON', {
        error: directParseError.message,
        responsePreview: responseText.substring(0, 200)
      });

      return {
        rawResponse: responseText,
        parseError: directParseError.message
      };
    }
  }

  /**
   * Enrich and normalize the parsed Claude response.
   *
   * - Ensures discrepancy IDs exist
   * - Validates discrepancy types and severities against allowed enums
   * - Ensures all required arrays exist
   * - Handles missing optional fields gracefully
   *
   * @param {Object} parsed - Parsed Claude response
   * @param {Object} docA - First document
   * @param {Object} docB - Second document
   * @param {string} pairId - Comparison pair ID
   * @returns {Object} Enriched comparison result
   */
  _enrichResult(parsed, docA, docB, pairId) {
    // Ensure arrays exist
    const rawDiscrepancies = Array.isArray(parsed.discrepancies) ? parsed.discrepancies : [];
    const rawTimelineEvents = Array.isArray(parsed.timelineEvents) ? parsed.timelineEvents : [];
    const rawTimelineViolations = Array.isArray(parsed.timelineViolations) ? parsed.timelineViolations : [];

    // Enrich discrepancies
    const discrepancies = rawDiscrepancies.map((disc, index) => {
      const enriched = { ...disc };

      // Assign ID if missing
      if (!enriched.id) {
        enriched.id = `disc-${String(index + 1).padStart(3, '0')}`;
      }

      // Validate type against allowed enum
      if (!enriched.type || !DISCREPANCY_TYPES.includes(enriched.type)) {
        enriched.type = 'amount_mismatch';
      }

      // Validate severity against allowed enum
      if (!enriched.severity || !SEVERITY_LEVELS.includes(enriched.severity)) {
        enriched.severity = 'medium';
      }

      // Ensure description
      if (!enriched.description) {
        enriched.description = 'Discrepancy detected between documents';
      }

      // Ensure documentA and documentB refs
      if (!enriched.documentA || typeof enriched.documentA !== 'object') {
        enriched.documentA = { field: 'unknown', value: null };
      }
      if (!enriched.documentB || typeof enriched.documentB !== 'object') {
        enriched.documentB = { field: 'unknown', value: null };
      }

      return enriched;
    });

    // Enrich timeline events
    const timelineEvents = rawTimelineEvents.map(event => {
      const enriched = { ...event };
      if (!enriched.date) enriched.date = 'unknown';
      if (!enriched.documentId) enriched.documentId = 'unknown';
      if (!enriched.documentType) enriched.documentType = 'unknown';
      if (!enriched.event) enriched.event = 'Undescribed event';
      if (!enriched.significance) enriched.significance = 'routine';
      return enriched;
    });

    // Enrich timeline violations
    const timelineViolations = rawTimelineViolations.map(violation => {
      const enriched = { ...violation };
      if (!enriched.description) enriched.description = 'Timeline violation detected';
      if (!enriched.severity || !SEVERITY_LEVELS.includes(enriched.severity)) {
        enriched.severity = 'high';
      }
      if (!Array.isArray(enriched.relatedDocuments) || enriched.relatedDocuments.length === 0) {
        enriched.relatedDocuments = [docA.documentId, docB.documentId];
      }
      return enriched;
    });

    return {
      pairId,
      documentA: this._buildDocRef(docA),
      documentB: this._buildDocRef(docB),
      discrepancies,
      timelineEvents,
      timelineViolations,
      comparisonSummary: parsed.comparisonSummary || ''
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /**
   * Build a document reference object for the result.
   *
   * @param {Object|null} doc - Document object
   * @returns {Object} Document reference { documentId, documentType, documentSubtype }
   */
  _buildDocRef(doc) {
    if (!doc) {
      return { documentId: 'unknown', documentType: 'unknown', documentSubtype: 'unknown' };
    }
    return {
      documentId: doc.documentId || 'unknown',
      documentType: doc.documentType || 'unknown',
      documentSubtype: doc.documentSubtype || 'unknown'
    };
  }

  /**
   * Filter extractedData to include only the field categories relevant
   * to this comparison (e.g. ['amounts', 'rates'] → only those sub-objects).
   *
   * @param {Object} extractedData - Full extracted data from document analysis
   * @param {Array<string>} comparisonFields - Field categories to include
   * @returns {Object} Filtered extracted data
   */
  _filterExtractedData(extractedData, comparisonFields) {
    if (!extractedData || !comparisonFields) {
      return extractedData || {};
    }

    const filtered = {};
    for (const field of comparisonFields) {
      if (extractedData[field] !== undefined) {
        filtered[field] = extractedData[field];
      }
    }

    // Always include identifiers for context
    if (extractedData.identifiers) {
      filtered.identifiers = extractedData.identifiers;
    }

    return filtered;
  }
}

module.exports = new CrossDocumentComparisonService();
