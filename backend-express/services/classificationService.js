const Anthropic = require('@anthropic-ai/sdk');
const { createLogger } = require('../utils/logger');
const logger = createLogger('classification');

// Initialize Anthropic client
const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

/**
 * Forensic Document Taxonomy
 *
 * Comprehensive mortgage document classification covering the full spectrum
 * of documents encountered in mortgage servicing audits, foreclosure defense,
 * and RESPA/TILA compliance litigation.
 *
 * 6 broad categories, 50+ specific subtypes.
 */
const DOCUMENT_TAXONOMY = {
  origination: {
    label: 'Origination Documents',
    subtypes: [
      'loan_application_1003',
      'good_faith_estimate',
      'loan_estimate',
      'truth_in_lending',
      'promissory_note',
      'deed_of_trust',
      'mortgage_deed',
      'hud1_settlement',
      'closing_disclosure',
      'appraisal_report',
      'title_insurance',
      'right_to_cancel'
    ]
  },
  servicing: {
    label: 'Servicing Documents',
    subtypes: [
      'monthly_statement',
      'escrow_analysis',
      'escrow_statement',
      'payment_history',
      'arm_adjustment_notice',
      'tax_payment_record',
      'insurance_payment_record',
      'payoff_statement',
      'annual_escrow_disclosure'
    ]
  },
  correspondence: {
    label: 'Correspondence',
    subtypes: [
      'loss_mitigation_application',
      'forbearance_agreement',
      'loan_modification',
      'qualified_written_request',
      'notice_of_error',
      'information_request',
      'collection_notice',
      'foreclosure_notice',
      'default_notice',
      'acceleration_letter',
      'general_correspondence'
    ]
  },
  legal: {
    label: 'Legal Documents',
    subtypes: [
      'assignment_of_mortgage',
      'substitution_of_trustee',
      'notice_of_default',
      'lis_pendens',
      'court_judgment',
      'court_order',
      'bankruptcy_filing',
      'proof_of_claim',
      'satisfaction_of_mortgage',
      'release_of_lien'
    ]
  },
  financial: {
    label: 'Financial Documents',
    subtypes: [
      'bank_statement',
      'tax_return',
      'income_verification',
      'credit_report',
      'profit_loss_statement',
      'asset_verification'
    ]
  },
  regulatory: {
    label: 'Regulatory Notices',
    subtypes: [
      'respa_disclosure',
      'tila_disclosure',
      'ecoa_notice',
      'fdcpa_notice',
      'scra_notice',
      'state_regulatory_notice'
    ]
  }
};

class ClassificationService {
  /**
   * Classify a document using Claude AI.
   *
   * Sends extracted document text to Claude with a forensic classification prompt.
   * Returns structured classification with type, subtype, confidence, and metadata.
   *
   * @param {string} documentText - Extracted text content of the document
   * @param {Object} [options={}] - Classification options
   * @param {string} [options.existingType] - User-provided document type hint
   * @returns {Promise<Object>} Classification result
   */
  async classifyDocument(documentText, { existingType } = {}) {
    try {
      const prompt = this._buildClassificationPrompt(documentText, existingType);

      const response = await client.messages.create({
        model: 'claude-sonnet-4-5-20250514',
        max_tokens: 2048,
        temperature: 0.1,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      });

      const responseText = response.content[0].text;
      const result = this._parseClassificationResponse(responseText);

      logger.info('Document classified', {
        classificationType: result.classificationType,
        classificationSubtype: result.classificationSubtype,
        confidence: result.confidence
      });

      return result;

    } catch (error) {
      logger.error('Classification error', { error: error.message, stack: error.stack });
      throw error;
    }
  }

  /**
   * Build the Claude classification prompt.
   *
   * Constructs a forensic-grade prompt that instructs Claude to:
   * 1. Classify into type/subtype from the taxonomy
   * 2. Extract key metadata (dates, amounts, parties, account numbers)
   * 3. Provide a confidence score
   * 4. Explain reasoning
   *
   * @param {string} documentText - Document text to classify
   * @param {string} [existingType] - Optional user-provided type hint
   * @returns {string} Complete classification prompt
   */
  _buildClassificationPrompt(documentText, existingType) {
    const taxonomyJson = JSON.stringify(DOCUMENT_TAXONOMY, null, 2);

    let existingTypeInstruction = '';
    if (existingType) {
      existingTypeInstruction = `\n\nNote: The user initially classified this document as "${existingType}". Consider this as context but classify independently based on the document content.`;
    }

    return `You are a forensic mortgage document classifier working in a litigation support role. Your task is to classify the following document into the correct category and subtype from the taxonomy below, extract key metadata, and provide a confidence score.

## Document Taxonomy

${taxonomyJson}

## Instructions

1. **Classify** the document into one of the taxonomy categories (classificationType) and a specific subtype (classificationSubtype).
2. **Extract key metadata** from the document including dates, monetary amounts, parties/entities, account numbers (masked), and property addresses.
3. **Provide a confidence score** between 0 and 1 indicating how certain you are of the classification.
4. **Explain your reasoning** briefly.

If the document doesn't fit any category, use classificationType: "unknown" with classificationSubtype: "unclassified".${existingTypeInstruction}

## Required JSON Response Format

Respond with ONLY valid JSON in this exact format (no markdown, no code fences):
{
  "classificationType": "category_name",
  "classificationSubtype": "specific_subtype",
  "confidence": 0.92,
  "extractedMetadata": {
    "dates": ["2024-01-15"],
    "amounts": ["$1,245.67"],
    "parties": ["Wells Fargo Home Mortgage"],
    "accountNumbers": ["****1234"],
    "propertyAddress": "123 Main St, Springfield, IL 62701"
  },
  "reasoning": "Brief explanation of why this classification was chosen."
}

## Document Text

${documentText}`;
  }

  /**
   * Parse Claude's classification response.
   *
   * Handles malformed JSON gracefully by wrapping in an error object.
   * Validates that classificationType exists in DOCUMENT_TAXONOMY (or is 'unknown').
   * Clamps confidence to 0-1 range.
   *
   * @param {string} responseText - Raw text response from Claude
   * @returns {Object} Parsed classification result
   */
  _parseClassificationResponse(responseText) {
    let parsed;

    try {
      parsed = JSON.parse(responseText);
    } catch (parseError) {
      logger.warn('Failed to parse classification response as JSON', {
        error: parseError.message,
        responsePreview: responseText.substring(0, 200)
      });
      return {
        rawResponse: responseText,
        parseError: parseError.message
      };
    }

    // Validate classificationType exists in taxonomy or is 'unknown'
    if (parsed.classificationType &&
        parsed.classificationType !== 'unknown' &&
        !DOCUMENT_TAXONOMY[parsed.classificationType]) {
      logger.warn('Invalid classificationType returned', {
        classificationType: parsed.classificationType
      });
      parsed.classificationType = 'unknown';
      parsed.classificationSubtype = 'unclassified';
    }

    // Clamp confidence to 0-1 range
    if (typeof parsed.confidence === 'number') {
      parsed.confidence = Math.max(0, Math.min(1, parsed.confidence));
    }

    return parsed;
  }

  /**
   * Get the full document taxonomy.
   *
   * @returns {Object} The DOCUMENT_TAXONOMY constant
   */
  getValidTypes() {
    return DOCUMENT_TAXONOMY;
  }

  /**
   * Get subtypes for a given classification type.
   *
   * @param {string} classificationType - The broad category name
   * @returns {string[]|null} Array of subtype strings, or null if type not found
   */
  getSubtypes(classificationType) {
    const category = DOCUMENT_TAXONOMY[classificationType];
    if (!category) {
      return null;
    }
    return category.subtypes;
  }
}

module.exports = new ClassificationService();
module.exports.DOCUMENT_TAXONOMY = DOCUMENT_TAXONOMY;
