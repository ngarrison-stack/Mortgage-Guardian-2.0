const Anthropic = require('@anthropic-ai/sdk');
const { createLogger } = require('../utils/logger');
const { validateAnalysisReport } = require('../schemas/analysisReportSchema');
const {
  getFieldDefinition,
  getExpectedFieldCount,
  categorizeField
} = require('../config/documentFieldDefinitions');

const logger = createLogger('document-analysis');

// Initialize Anthropic client
const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

// Defaults consistent with classification service
const DEFAULT_MODEL = 'claude-sonnet-4-5-20250514';
const DEFAULT_MAX_TOKENS = 8192;
const DEFAULT_TEMPERATURE = 0.1;

/**
 * Document Analysis Service
 *
 * Performs deep, structured analysis of individual mortgage documents using
 * Claude AI. Extracts key data points, detects anomalies, scores completeness,
 * and generates forensic-grade analysis reports.
 *
 * This replaces the basic claudeService.buildMortgageAnalysisPrompt() with
 * type-specific analysis leveraging the 54-subtype document taxonomy.
 */
class DocumentAnalysisService {
  /**
   * Analyze a mortgage document using Claude AI.
   *
   * @param {string} documentText - Extracted text content of the document
   * @param {Object} classification - Classification result from classificationService
   * @param {string} classification.classificationType - Broad category (e.g. "servicing")
   * @param {string} classification.classificationSubtype - Specific subtype (e.g. "monthly_statement")
   * @param {number} [classification.confidence] - Classification confidence score
   * @param {Object} [classification.extractedMetadata] - Metadata from classification
   * @param {Object} [options={}] - Analysis options
   * @param {string} [options.model] - Claude model to use
   * @param {number} [options.maxTokens] - Max tokens for Claude response
   * @param {number} [options.temperature] - Temperature for Claude response
   * @param {string} [options.userId] - User ID for audit logging
   * @returns {Promise<Object>} Validated analysis report matching analysisReportSchema
   */
  async analyzeDocument(documentText, classification, options = {}) {
    if (!documentText || typeof documentText !== 'string' || documentText.trim().length === 0) {
      throw new Error('Document text is required and must be a non-empty string');
    }

    if (!classification || typeof classification !== 'object') {
      throw new Error('Classification object is required');
    }

    if (!classification.classificationType || !classification.classificationSubtype) {
      throw new Error('Classification must include classificationType and classificationSubtype');
    }

    const model = options.model || DEFAULT_MODEL;
    const maxTokens = options.maxTokens || DEFAULT_MAX_TOKENS;
    const temperature = options.temperature !== undefined ? options.temperature : DEFAULT_TEMPERATURE;
    const startTime = Date.now();

    logger.info('Starting document analysis', {
      classificationType: classification.classificationType,
      classificationSubtype: classification.classificationSubtype,
      model,
      userId: options.userId
    });

    try {
      const prompt = this._buildAnalysisPrompt(documentText, classification);

      const response = await client.messages.create({
        model,
        max_tokens: maxTokens,
        temperature,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      });

      const responseText = response.content[0].text;
      const usage = response.usage;

      const parsed = this._parseAnalysisResponse(responseText);

      // If parse failed, return error result
      if (parsed.parseError) {
        const duration = Date.now() - startTime;
        logger.warn('Analysis response parse failed', {
          parseError: parsed.parseError,
          duration,
          inputTokens: usage ? usage.input_tokens : null,
          outputTokens: usage ? usage.output_tokens : null
        });
        return {
          error: false,
          parseError: parsed.parseError,
          rawResponse: parsed.rawResponse,
          documentInfo: {
            documentType: classification.classificationType,
            documentSubtype: classification.classificationSubtype,
            analyzedAt: new Date().toISOString(),
            modelUsed: model,
            confidence: classification.confidence || 0
          }
        };
      }

      // Validate and enrich
      const result = this._validateAndEnrich(parsed, classification, model);

      const duration = Date.now() - startTime;
      logger.info('Document analysis completed', {
        classificationType: classification.classificationType,
        classificationSubtype: classification.classificationSubtype,
        anomalyCount: result.anomalies ? result.anomalies.length : 0,
        riskLevel: result.summary ? result.summary.riskLevel : 'unknown',
        completenessScore: result.completeness ? result.completeness.score : null,
        duration,
        inputTokens: usage ? usage.input_tokens : null,
        outputTokens: usage ? usage.output_tokens : null
      });

      return result;

    } catch (error) {
      const duration = Date.now() - startTime;
      logger.error('Document analysis failed', {
        error: error.message,
        stack: error.stack,
        classificationType: classification.classificationType,
        classificationSubtype: classification.classificationSubtype,
        duration
      });

      return {
        error: true,
        errorMessage: error.message,
        rawResponse: null,
        documentInfo: {
          documentType: classification.classificationType,
          documentSubtype: classification.classificationSubtype,
          analyzedAt: new Date().toISOString(),
          modelUsed: model,
          confidence: 0
        }
      };
    }
  }

  // ---------------------------------------------------------------------------
  // Prompt Engineering
  // ---------------------------------------------------------------------------

  /**
   * Build the analysis prompt, routing to a type-specific builder.
   *
   * @param {string} documentText - Document text
   * @param {Object} classification - Classification result
   * @returns {string} Complete analysis prompt
   */
  _buildAnalysisPrompt(documentText, classification) {
    const { classificationType, classificationSubtype } = classification;

    switch (classificationType) {
      case 'servicing':
        return this._buildServicingPrompt(documentText, classificationSubtype);
      case 'origination':
        return this._buildOriginationPrompt(documentText, classificationSubtype);
      case 'correspondence':
        return this._buildCorrespondencePrompt(documentText, classificationSubtype);
      case 'legal':
        return this._buildLegalPrompt(documentText, classificationSubtype);
      case 'financial':
        return this._buildFinancialPrompt(documentText, classificationSubtype);
      case 'regulatory':
        return this._buildRegulatoryPrompt(documentText, classificationSubtype);
      default:
        return this._buildGenericPrompt(documentText, classification);
    }
  }

  /**
   * Build the common extraction template shared by all prompts.
   *
   * @param {string} classificationType - Broad category
   * @param {string} classificationSubtype - Specific subtype
   * @returns {string} JSON extraction template based on field definitions
   */
  _buildExtractionTemplate(classificationType, classificationSubtype) {
    const fieldDef = getFieldDefinition(classificationType, classificationSubtype);
    const allFields = [...fieldDef.critical, ...fieldDef.expected, ...fieldDef.optional];

    // Group fields by likely category for the extraction template
    const dateFields = allFields.filter(f => /date|period|year/i.test(f));
    const amountFields = allFields.filter(f => /amount|balance|payment|cost|charge|fee|income|expense|revenue|profit|debt|value|rate(?!.*[dD])/i.test(f) && !/rate/i.test(f));
    const rateFields = allFields.filter(f => /rate|apr|percentage/i.test(f));
    const partyFields = allFields.filter(f => /borrower|lender|servicer|party|parties|name|holder|employer|trustee|plaintiff|defendant|creditor|debtor|appraiser|insurer|assignor|assignee|judge|attorney|agency|collector|applicant|member|seller|buyer|recipient|sender/i.test(f));
    const idFields = allFields.filter(f => /number|address|identifier|parcel/i.test(f));

    return `{
  "extractedData": {
    "dates": { ${dateFields.map(f => `"${f}": "value or null"`).join(', ') || '/* named dates found in document */'} },
    "amounts": { ${amountFields.map(f => `"${f}": "value or null"`).join(', ') || '/* named dollar amounts */'} },
    "rates": { ${rateFields.map(f => `"${f}": "value or null"`).join(', ') || '/* named percentage rates */'} },
    "parties": { ${partyFields.map(f => `"${f}": "value or null"`).join(', ') || '/* named parties */'} },
    "identifiers": { ${idFields.map(f => `"${f}": "value or null"`).join(', ') || '/* account/loan numbers, addresses */'} },
    "terms": { /* loan/document terms */ },
    "custom": { /* any type-specific fields not fitting above categories */ }
  },
  "anomalies": [
    {
      "field": "fieldName",
      "type": "unusual_value|inconsistency|missing_required|calculation_error|regulatory_concern",
      "severity": "critical|high|medium|low|info",
      "description": "explanation of the anomaly",
      "expectedValue": "if applicable",
      "actualValue": "if applicable"
    }
  ],
  "summary": {
    "overview": "2-3 sentence summary of the document analysis",
    "keyFindings": ["finding1", "finding2"],
    "riskLevel": "low|medium|high|critical",
    "recommendations": ["action1", "action2"]
  }
}`;
  }

  /**
   * Build servicing-specific analysis prompt.
   */
  _buildServicingPrompt(documentText, subtype) {
    const fieldDef = getFieldDefinition('servicing', subtype);
    const template = this._buildExtractionTemplate('servicing', subtype);

    const subtypeChecks = {
      monthly_statement: `For a monthly_statement specifically, check:
- Payment amount matches principal + interest + escrow
- Interest calculation matches rate x balance / 12
- Escrow disbursements match expected taxes/insurance
- Late fees comply with RESPA limits (typically 4-5% of P&I)
- Fees are itemized and reasonable
- Statement date and due date are consistent`,
      escrow_analysis: `For an escrow_analysis specifically, check:
- Projected disbursements match actual tax/insurance amounts
- Shortage/surplus calculations are mathematically correct
- Monthly escrow payment change is justified
- Cushion does not exceed RESPA maximum (1/6 of annual disbursements)`,
      escrow_statement: `For an escrow_statement specifically, check:
- Beginning and ending balance reconcile with activity
- All disbursements have corresponding expected obligations
- Statement period is complete and continuous`,
      payment_history: `For a payment_history specifically, check:
- All payments are accounted for chronologically
- Principal/interest split matches amortization schedule
- Late fees are applied consistently per terms
- No unexplained balance adjustments`,
      arm_adjustment_notice: `For an arm_adjustment_notice specifically, check:
- New rate equals index + margin
- Rate caps are respected (periodic and lifetime)
- Notice timing meets regulatory requirements (typically 7-8 months advance)
- Payment change calculation is correct`,
      payoff_statement: `For a payoff_statement specifically, check:
- Per diem interest calculation is correct (rate x balance / 365)
- All fees are itemized and reasonable
- Good-through date is clearly stated
- Payoff amount reconciles with balance + interest + fees`
    };

    const specificChecks = subtypeChecks[subtype] || `For this servicing document, check:
- All monetary amounts are consistent and reasonable
- Dates are logical and consistent
- Required regulatory disclosures are present`;

    return `You are a forensic mortgage analyst reviewing a ${subtype} document from the servicing category.

Your task is to perform a thorough forensic analysis, extracting ALL data points and identifying any anomalies, errors, or regulatory concerns.

Critical fields that MUST be extracted if present: ${fieldDef.critical.join(', ')}
Expected fields: ${fieldDef.expected.join(', ')}
Optional fields to look for: ${fieldDef.optional.join(', ')}

Extract ALL data points from this document into the following JSON structure:
${template}

${specificChecks}

Document text:
---
${documentText}
---

Respond ONLY with valid JSON. No markdown, no explanation outside the JSON.`;
  }

  /**
   * Build origination-specific analysis prompt.
   */
  _buildOriginationPrompt(documentText, subtype) {
    const fieldDef = getFieldDefinition('origination', subtype);
    const template = this._buildExtractionTemplate('origination', subtype);

    const subtypeChecks = {
      closing_disclosure: `For a closing_disclosure specifically, check:
- Loan terms match between page 1 summary and detailed sections
- Closing costs are properly itemized per TRID requirements
- Cash to close calculation is correct
- APR calculation is accurate
- Comparison with Loan Estimate for tolerance violations`,
      truth_in_lending: `For a truth_in_lending specifically, check:
- APR is correctly calculated based on loan terms
- Finance charge includes all required items
- Amount financed equals loan amount minus prepaid charges
- Total of payments is mathematically correct
- Required TILA disclosures are present`,
      promissory_note: `For a promissory_note specifically, check:
- Principal, rate, and payment terms are internally consistent
- Monthly payment matches amortization calculation
- Late charge terms comply with applicable law
- Maturity date is consistent with loan term
- Prepayment terms are clearly stated`,
      hud1_settlement: `For a hud1_settlement specifically, check:
- All line items are correctly totaled
- Buyer and seller columns balance
- Real estate commissions are reasonable
- Title charges are itemized
- Pro-rations are calculated correctly`
    };

    const specificChecks = subtypeChecks[subtype] || `For this origination document, check:
- Loan terms are internally consistent
- All required disclosures are present
- Monetary amounts reconcile correctly
- Dates are logical and complete`;

    return `You are a forensic mortgage analyst reviewing a ${subtype} document from the origination category.

Your task is to perform a thorough forensic analysis of this loan origination document, extracting ALL data points and identifying any anomalies, errors, or regulatory concerns.

Critical fields that MUST be extracted if present: ${fieldDef.critical.join(', ')}
Expected fields: ${fieldDef.expected.join(', ')}
Optional fields to look for: ${fieldDef.optional.join(', ')}

Extract ALL data points from this document into the following JSON structure:
${template}

${specificChecks}

Document text:
---
${documentText}
---

Respond ONLY with valid JSON. No markdown, no explanation outside the JSON.`;
  }

  /**
   * Build correspondence-specific analysis prompt.
   */
  _buildCorrespondencePrompt(documentText, subtype) {
    const fieldDef = getFieldDefinition('correspondence', subtype);
    const template = this._buildExtractionTemplate('correspondence', subtype);

    const subtypeChecks = {
      foreclosure_notice: `For a foreclosure_notice specifically, check:
- Notice timing meets state and federal requirements
- Default amount is itemized and reconcilable
- Cure deadline allows legally required time
- Required borrower rights disclosures are present
- Military service / SCRA notice is included
- Housing counselor information is provided
- Right to cure is clearly stated`,
      qualified_written_request: `For a qualified_written_request specifically, check:
- Request is specific and actionable under RESPA Section 6
- Response deadline is calculated correctly (30 business days acknowledgment, 30 business days response)
- Borrower identification is sufficient`,
      notice_of_error: `For a notice_of_error specifically, check:
- Error is clearly described with specific account impact
- Response deadline meets RESPA requirements (30 business days)
- Correction requested is specific and measurable`,
      loan_modification: `For a loan_modification specifically, check:
- New terms are clearly stated and internally consistent
- Modified payment matches new rate and principal
- Effective date is clearly stated
- Trial period requirements (if any) are clear
- Deferred balance terms are explicit`
    };

    const specificChecks = subtypeChecks[subtype] || `For this correspondence document, check:
- Deadline calculations are correct
- Required notices and disclosures are present
- Borrower rights are properly communicated
- Response requirements are clearly stated`;

    return `You are a forensic mortgage analyst reviewing a ${subtype} document from the correspondence category.

Your task is to perform a thorough forensic analysis of this mortgage correspondence, extracting ALL data points and identifying any anomalies, errors, or regulatory concerns, especially regarding borrower rights and deadlines.

Critical fields that MUST be extracted if present: ${fieldDef.critical.join(', ')}
Expected fields: ${fieldDef.expected.join(', ')}
Optional fields to look for: ${fieldDef.optional.join(', ')}

Extract ALL data points from this document into the following JSON structure:
${template}

${specificChecks}

Document text:
---
${documentText}
---

Respond ONLY with valid JSON. No markdown, no explanation outside the JSON.`;
  }

  /**
   * Build legal-specific analysis prompt.
   */
  _buildLegalPrompt(documentText, subtype) {
    const fieldDef = getFieldDefinition('legal', subtype);
    const template = this._buildExtractionTemplate('legal', subtype);

    const subtypeChecks = {
      assignment_of_mortgage: `For an assignment_of_mortgage specifically, check:
- Chain of title is clear (assignor to assignee)
- Recording information is complete
- Legal description matches property address
- Notarization is proper
- MERS involvement is noted if present`,
      notice_of_default: `For a notice_of_default specifically, check:
- Default amount is itemized
- Cure period meets state requirements
- Recording information is complete
- Contact information for borrower assistance is provided`,
      bankruptcy_filing: `For a bankruptcy_filing specifically, check:
- Chapter is clearly identified
- Automatic stay date is clear
- Mortgage debt is properly scheduled
- Plan payment (if Chapter 13) addresses mortgage arrears`
    };

    const specificChecks = subtypeChecks[subtype] || `For this legal document, check:
- All parties are properly identified
- Recording information is complete
- Legal description is present and consistent
- Dates are logical and complete
- Notarization requirements are met`;

    return `You are a forensic mortgage analyst reviewing a ${subtype} document from the legal category.

Your task is to perform a thorough forensic analysis of this legal document, extracting ALL data points and identifying any anomalies, errors, or concerns regarding proper execution and recording.

Critical fields that MUST be extracted if present: ${fieldDef.critical.join(', ')}
Expected fields: ${fieldDef.expected.join(', ')}
Optional fields to look for: ${fieldDef.optional.join(', ')}

Extract ALL data points from this document into the following JSON structure:
${template}

${specificChecks}

Document text:
---
${documentText}
---

Respond ONLY with valid JSON. No markdown, no explanation outside the JSON.`;
  }

  /**
   * Build financial-specific analysis prompt.
   */
  _buildFinancialPrompt(documentText, subtype) {
    const fieldDef = getFieldDefinition('financial', subtype);
    const template = this._buildExtractionTemplate('financial', subtype);

    const subtypeChecks = {
      bank_statement: `For a bank_statement specifically, check:
- Beginning balance + deposits - withdrawals = ending balance
- Large or unusual deposits are flagged
- Regular income deposits are consistent
- NSF/overdraft activity is noted`,
      tax_return: `For a tax_return specifically, check:
- Income sources are consistent with employment
- Deductions are reasonable for filing status
- Self-employment income is properly documented
- Taxable income calculation is correct`,
      income_verification: `For an income_verification specifically, check:
- YTD earnings are consistent with stated annual income
- Employment start date suggests stable employment
- Pay frequency and base rate reconcile with annual amount`
    };

    const specificChecks = subtypeChecks[subtype] || `For this financial document, check:
- All totals and calculations are correct
- Income/asset figures are internally consistent
- Dates and periods are logical
- Source documentation appears authentic`;

    return `You are a forensic mortgage analyst reviewing a ${subtype} document from the financial category.

Your task is to perform a thorough forensic analysis of this financial document, extracting ALL data points and identifying any anomalies, inconsistencies, or calculation errors.

Critical fields that MUST be extracted if present: ${fieldDef.critical.join(', ')}
Expected fields: ${fieldDef.expected.join(', ')}
Optional fields to look for: ${fieldDef.optional.join(', ')}

Extract ALL data points from this document into the following JSON structure:
${template}

${specificChecks}

Document text:
---
${documentText}
---

Respond ONLY with valid JSON. No markdown, no explanation outside the JSON.`;
  }

  /**
   * Build regulatory-specific analysis prompt.
   */
  _buildRegulatoryPrompt(documentText, subtype) {
    const fieldDef = getFieldDefinition('regulatory', subtype);
    const template = this._buildExtractionTemplate('regulatory', subtype);

    const subtypeChecks = {
      respa_disclosure: `For a respa_disclosure specifically, check:
- All required RESPA language is present
- Transfer notice timing meets 15-day requirement
- New servicer contact information is complete
- Dispute rights are clearly communicated`,
      tila_disclosure: `For a tila_disclosure specifically, check:
- APR is correctly calculated
- Finance charge includes all required items
- Amount financed and total of payments are correct
- Required disclosures (demand feature, variable rate, etc.) are present`,
      fdcpa_notice: `For an fdcpa_notice specifically, check:
- Mini-Miranda warning is present
- Validation rights are clearly stated
- 30-day dispute period is disclosed
- Debt collector is properly identified
- Original creditor is disclosed if different`
    };

    const specificChecks = subtypeChecks[subtype] || `For this regulatory notice, check:
- All required disclosures are present
- Timing requirements are met
- Required regulatory language is included
- Borrower rights are clearly stated`;

    return `You are a forensic mortgage analyst reviewing a ${subtype} document from the regulatory category.

Your task is to perform a thorough forensic analysis of this regulatory notice, extracting ALL data points and identifying any missing disclosures, timing violations, or regulatory non-compliance.

Critical fields that MUST be extracted if present: ${fieldDef.critical.join(', ')}
Expected fields: ${fieldDef.expected.join(', ')}
Optional fields to look for: ${fieldDef.optional.join(', ')}

Extract ALL data points from this document into the following JSON structure:
${template}

${specificChecks}

Document text:
---
${documentText}
---

Respond ONLY with valid JSON. No markdown, no explanation outside the JSON.`;
  }

  /**
   * Build generic analysis prompt for unknown/unrecognized document types.
   */
  _buildGenericPrompt(documentText, classification) {
    const { classificationType, classificationSubtype } = classification;
    const fieldDef = getFieldDefinition(classificationType, classificationSubtype);
    const template = this._buildExtractionTemplate(classificationType, classificationSubtype);

    return `You are a forensic mortgage analyst reviewing a document classified as ${classificationType}/${classificationSubtype}.

Your task is to extract ALL available data points and identify any anomalies or concerns.

Fields to look for: ${[...fieldDef.critical, ...fieldDef.expected, ...fieldDef.optional].join(', ')}

Extract ALL data points from this document into the following JSON structure:
${template}

Check for:
- Internal consistency of all data points
- Missing information that would normally be present
- Any unusual values or calculation errors
- Regulatory compliance concerns

Document text:
---
${documentText}
---

Respond ONLY with valid JSON. No markdown, no explanation outside the JSON.`;
  }

  // ---------------------------------------------------------------------------
  // Response Processing
  // ---------------------------------------------------------------------------

  /**
   * Parse Claude's analysis response.
   *
   * Graceful fallback: if JSON parse fails, returns { rawResponse, parseError }
   * instead of throwing.
   *
   * @param {string} responseText - Raw text response from Claude
   * @returns {Object} Parsed analysis data or error fallback
   */
  _parseAnalysisResponse(responseText) {
    try {
      // Try direct parse first
      return JSON.parse(responseText);
    } catch (directParseError) {
      // Try to extract JSON from markdown code fences
      const jsonMatch = responseText.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (jsonMatch) {
        try {
          return JSON.parse(jsonMatch[1].trim());
        } catch (fenceParseError) {
          // Fall through to fallback
        }
      }

      logger.warn('Failed to parse analysis response as JSON', {
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
   * Validate parsed data against schema and enrich with completeness scoring.
   *
   * @param {Object} parsedData - Parsed Claude response
   * @param {Object} classification - Document classification
   * @param {string} model - Claude model used
   * @returns {Object} Enriched analysis report
   */
  _validateAndEnrich(parsedData, classification, model) {
    const { classificationType, classificationSubtype } = classification;

    // Build the documentInfo section
    const documentInfo = {
      documentType: classificationType,
      documentSubtype: classificationSubtype,
      analyzedAt: new Date().toISOString(),
      modelUsed: model,
      confidence: classification.confidence || 0
    };

    // Ensure extractedData has all required sub-objects with defaults
    const extractedData = {
      dates: {},
      amounts: {},
      rates: {},
      parties: {},
      identifiers: {},
      terms: {},
      custom: {},
      ...(parsedData.extractedData || {})
    };

    // Ensure anomalies is an array
    const rawAnomalies = Array.isArray(parsedData.anomalies) ? parsedData.anomalies : [];

    // Categorize and enrich anomalies
    const anomalies = this._categorizeAnomalies(rawAnomalies, classificationType, classificationSubtype);

    // Calculate completeness
    const completeness = this._calculateCompleteness(extractedData, classificationType, classificationSubtype);

    // Ensure summary has required fields with defaults
    const summary = {
      overview: '',
      keyFindings: [],
      riskLevel: 'low',
      recommendations: [],
      ...(parsedData.summary || {})
    };

    // Build the full report
    const report = {
      documentInfo,
      extractedData,
      anomalies,
      completeness,
      summary
    };

    // Validate against schema
    const { error: validationError } = validateAnalysisReport(report);

    if (validationError) {
      logger.warn('Analysis report has validation warnings', {
        validationErrors: validationError.details.map(d => d.message),
        classificationType,
        classificationSubtype
      });
      report.validationWarnings = validationError.details.map(d => d.message);
    }

    return report;
  }

  /**
   * Calculate completeness score from extracted data against field definitions.
   *
   * @param {Object} extractedData - Extracted data with sub-objects
   * @param {string} classificationType - Broad category
   * @param {string} classificationSubtype - Specific subtype
   * @returns {Object} Completeness metrics
   */
  _calculateCompleteness(extractedData, classificationType, classificationSubtype) {
    const fieldDef = getFieldDefinition(classificationType, classificationSubtype);
    const expectedFields = [...fieldDef.critical, ...fieldDef.expected];
    const totalExpectedFields = expectedFields.length;

    // Collect all field names from all extractedData sub-objects
    const allExtractedFieldNames = new Set();
    for (const section of Object.values(extractedData)) {
      if (section && typeof section === 'object' && !Array.isArray(section)) {
        for (const [key, value] of Object.entries(section)) {
          // Only count fields that have non-null, non-empty values
          if (value !== null && value !== undefined && value !== '' && value !== 'null' && value !== 'value or null') {
            allExtractedFieldNames.add(key);
          }
        }
      }
    }

    const presentFields = expectedFields.filter(f => allExtractedFieldNames.has(f));
    const missingFields = expectedFields.filter(f => !allExtractedFieldNames.has(f));
    const missingCritical = fieldDef.critical.filter(f => !allExtractedFieldNames.has(f));

    const score = totalExpectedFields > 0
      ? Math.round((presentFields.length / totalExpectedFields) * 100)
      : 0;

    return {
      score,
      totalExpectedFields,
      presentFields,
      missingFields,
      missingCritical
    };
  }

  /**
   * Enrich Claude-detected anomalies with severity based on field criticality.
   *
   * Missing critical fields get severity elevated to 'high'.
   *
   * @param {Array} anomalies - Raw anomalies from Claude
   * @param {string} classificationType - Broad category
   * @param {string} classificationSubtype - Specific subtype
   * @returns {Array} Enriched anomalies
   */
  _categorizeAnomalies(anomalies, classificationType, classificationSubtype) {
    return anomalies.map(anomaly => {
      const enriched = { ...anomaly };

      // Ensure required fields exist
      if (!enriched.field) enriched.field = 'unknown';
      if (!enriched.type) enriched.type = 'unusual_value';
      if (!enriched.severity) enriched.severity = 'medium';
      if (!enriched.description) enriched.description = 'No description provided';

      // Elevate severity for critical field anomalies
      const fieldCategory = categorizeField(enriched.field, classificationType, classificationSubtype);

      if (fieldCategory === 'critical' && (enriched.severity === 'low' || enriched.severity === 'info' || enriched.severity === 'medium')) {
        enriched.severity = 'high';
      }

      return enriched;
    });
  }
}

module.exports = new DocumentAnalysisService();
