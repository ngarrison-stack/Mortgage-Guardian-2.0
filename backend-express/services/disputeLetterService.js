/**
 * RESPA Dispute Letter Generation Service
 *
 * Uses Claude AI to generate litigation-grade RESPA-compliant dispute letters
 * based on consolidated audit findings. Supports three letter types:
 * - Qualified Written Request (RESPA Section 6)
 * - Notice of Error (12 CFR 1024.35)
 * - Request for Information (12 CFR 1024.36)
 *
 * Input:  letterType, consolidatedReport, options
 * Output: { letterType, generatedAt, content, recipientInfo } or { error, errorMessage, letterType }
 */

const Anthropic = require('@anthropic-ai/sdk');
const { createLogger } = require('../utils/logger');
const { LETTER_TYPES, LETTER_SECTIONS } = require('../config/consolidatedReportConfig');

const logger = createLogger('dispute-letter');

const DEFAULT_MODEL = 'claude-sonnet-4-5-20250514';
const DEFAULT_TEMPERATURE = 0.1;
const LETTER_MAX_TOKENS = 4096;

class DisputeLetterService {
  constructor() {
    this._client = null;
  }

  /**
   * Lazily initialize the Anthropic client.
   * Deferred so missing API key only errors when generation is actually needed.
   */
  _getClient() {
    if (!this._client) {
      if (!process.env.ANTHROPIC_API_KEY) {
        throw new Error('Dispute letter generation requires ANTHROPIC_API_KEY');
      }
      this._client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    }
    return this._client;
  }

  /**
   * Generate a RESPA-compliant dispute letter using Claude AI.
   *
   * @param {string} letterType - One of LETTER_TYPES: 'qualified_written_request' | 'notice_of_error' | 'request_for_information'
   * @param {Object} consolidatedReport - Full consolidated audit report
   * @param {Object} [options={}] - Optional overrides (e.g., borrowerName, loanNumber)
   * @returns {Promise<Object>} Letter result or error object — never throws
   */
  async generateDisputeLetter(letterType, consolidatedReport, options = {}) {
    // Validate letter type
    if (!letterType || !LETTER_TYPES.includes(letterType)) {
      logger.warn('Invalid letter type requested', { letterType });
      return {
        error: true,
        errorMessage: `Invalid letter type: ${letterType}. Must be one of: ${LETTER_TYPES.join(', ')}`,
        letterType: letterType || 'unknown'
      };
    }

    // Validate consolidated report
    if (!consolidatedReport || typeof consolidatedReport !== 'object') {
      logger.warn('Missing or invalid consolidated report', { letterType });
      return {
        error: true,
        errorMessage: 'Consolidated report is required for letter generation',
        letterType
      };
    }

    try {
      const recipientInfo = this._extractRecipientInfo(consolidatedReport);
      const prompt = this._buildLetterPrompt(letterType, consolidatedReport, options);

      const client = this._getClient();
      const response = await client.messages.create({
        model: DEFAULT_MODEL,
        max_tokens: LETTER_MAX_TOKENS,
        temperature: DEFAULT_TEMPERATURE,
        messages: [{ role: 'user', content: prompt }]
      });

      const responseText = response.content[0].text;
      const parsed = this._parseClaudeResponse(responseText);

      if (parsed.parseError) {
        logger.warn('Failed to parse Claude dispute letter response', {
          letterType,
          parseError: parsed.parseError
        });
        return {
          error: true,
          errorMessage: `Failed to parse generated letter: ${parsed.parseError}`,
          letterType
        };
      }

      logger.info('Dispute letter generated successfully', {
        letterType,
        inputTokens: response.usage?.input_tokens,
        outputTokens: response.usage?.output_tokens
      });

      return {
        letterType,
        generatedAt: new Date().toISOString(),
        content: {
          subject: parsed.subject || '',
          salutation: parsed.salutation || '',
          body: parsed.body || '',
          demands: Array.isArray(parsed.demands) ? parsed.demands : [],
          legalCitations: Array.isArray(parsed.legalCitations) ? parsed.legalCitations : [],
          responseDeadline: parsed.responseDeadline || '',
          closingStatement: parsed.closingStatement || ''
        },
        recipientInfo
      };
    } catch (error) {
      logger.error('Dispute letter generation failed', {
        error: error.message,
        letterType
      });
      return {
        error: true,
        errorMessage: error.message,
        letterType
      };
    }
  }

  /**
   * Build the Claude prompt for a specific letter type.
   *
   * @param {string} letterType - The RESPA letter type
   * @param {Object} report - Consolidated audit report
   * @param {Object} [options={}] - Optional overrides
   * @returns {string} Prompt string
   */
  _buildLetterPrompt(letterType, report, options = {}) {
    const caseSummary = report.caseSummary || {};
    const violations = this._extractViolations(report);
    const findings = this._extractFindings(report);
    const letterTypeName = this._formatLetterTypeName(letterType);
    const sections = LETTER_SECTIONS[letterType] || [];

    const borrowerName = options.borrowerName || caseSummary.borrowerName || '[BORROWER NAME]';
    const loanNumber = options.loanNumber || caseSummary.loanNumber || '[LOAN NUMBER]';
    const servicerName = caseSummary.servicerName || '[SERVICER NAME]';
    const servicerAddress = caseSummary.servicerAddress || '[SERVICER ADDRESS]';
    const propertyAddress = caseSummary.propertyAddress || '[PROPERTY ADDRESS]';

    let typeSpecificInstructions = '';

    if (letterType === 'qualified_written_request') {
      typeSpecificInstructions = `This is a Qualified Written Request (QWR) under RESPA Section 6 (12 U.S.C. § 2605(e)).

Key requirements:
- Explicitly declare this as a Qualified Written Request under RESPA Section 6
- The servicer must acknowledge receipt within 5 business days
- The servicer must respond substantively within 30 business days (extendable to 60)
- Include specific account errors and requested corrections
- Reference RESPA Section 6(e) obligations
- Note that failure to respond may result in actual damages, statutory damages up to $2,000, costs, and attorney fees`;
    } else if (letterType === 'notice_of_error') {
      typeSpecificInstructions = `This is a Notice of Error under 12 CFR 1024.35 (Regulation X).

Key requirements:
- Explicitly declare this as a Notice of Error under 12 CFR 1024.35
- Identify the specific error category under 12 CFR 1024.35(b):
  (1) Failure to accept payment
  (2) Failure to apply payment correctly
  (3) Failure to credit payment as of date received
  (4) Failure to pay taxes/insurance from escrow
  (5) Imposition of unreasonable fees
  (6) Failure to provide accurate payoff statement
  (7) Failure to provide required notices
  (8) Failure to transfer escrow at servicing transfer
  (9) Making the first notice/filing for foreclosure in violation
  (10) Moving for judgment/sale in violation
  (11) Any other error
- The servicer must respond within 30 business days (extendable to 15 more)
- Servicer must correct the error or provide a written explanation
- Reference Regulation X enforcement provisions`;
    } else if (letterType === 'request_for_information') {
      typeSpecificInstructions = `This is a Request for Information (RFI) under 12 CFR 1024.36 (Regulation X).

Key requirements:
- Explicitly declare this as a Request for Information under 12 CFR 1024.36
- Specify exact information being requested with sufficient detail
- The servicer must respond within 30 business days (extendable to 15 more)
- Servicer must provide the requested information or explain why it cannot
- Reference the borrower's right to request information under Regulation X
- Note that the servicer may not charge a fee for responding to the RFI`;
    }

    return `You are a mortgage servicing law expert specializing in RESPA compliance. Generate a formal ${letterTypeName} that is litigation-grade and ready for immediate use.

## Letter Type
${typeSpecificInstructions}

## Required Sections
${sections.map(s => `- **${s.title}**: ${s.description}`).join('\n')}

## Borrower & Loan Information
- Borrower Name: ${borrowerName}
- Loan Number: ${loanNumber}
- Property Address: ${propertyAddress}
- Servicer: ${servicerName}
- Servicer Address: ${servicerAddress}

## Violations & Findings from Audit

### Compliance Violations:
${violations.length > 0 ? JSON.stringify(violations, null, 2) : 'No specific compliance violations identified.'}

### Audit Findings:
${findings.length > 0 ? JSON.stringify(findings, null, 2) : 'No specific audit findings available.'}

## Instructions

Generate the dispute letter content. Respond with valid JSON in this exact format:

\`\`\`json
{
  "subject": "Subject line for the letter",
  "salutation": "Dear [appropriate recipient]:",
  "body": "Full letter body in markdown format, including all required sections",
  "demands": ["Specific demand 1", "Specific demand 2"],
  "legalCitations": ["12 U.S.C. § 2605(e)", "12 CFR 1024.35"],
  "responseDeadline": "30 business days from receipt of this letter",
  "closingStatement": "Professional closing statement with signature block"
}
\`\`\`

Requirements:
- Use formal legal language appropriate for regulatory correspondence
- Cite specific statutes, regulations, and CFR sections
- Include all violations and findings as supporting evidence in the body
- Make demands specific and actionable
- Include appropriate response deadlines per the applicable regulation
- The body should be comprehensive and ready to send without modification

Respond ONLY with valid JSON. No explanation outside the JSON.`;
  }

  /**
   * Extract recipient/servicer information from the consolidated report.
   *
   * @param {Object} report - Consolidated audit report
   * @returns {Object} { servicerName, servicerAddress }
   */
  _extractRecipientInfo(report) {
    const caseSummary = report.caseSummary || {};
    return {
      servicerName: caseSummary.servicerName || 'Unknown Servicer',
      servicerAddress: caseSummary.servicerAddress || 'Address Not Available'
    };
  }

  /**
   * Extract violations from the consolidated report for use in prompts.
   *
   * @param {Object} report - Consolidated audit report
   * @returns {Array} Simplified violation objects
   */
  _extractViolations(report) {
    const violations = [];

    // Support both consolidated report and raw aggregated data
    const complianceData = report.complianceFindings || report.complianceReport || {};
    const federalViolations = complianceData.federalViolations || complianceData.violations || [];
    const stateViolations = complianceData.stateViolations || [];

    // Federal violations
    if (Array.isArray(federalViolations)) {
      for (const v of federalViolations) {
        violations.push({
          type: 'federal',
          statuteName: v.statuteName || 'Unknown Statute',
          citation: v.citation || '',
          severity: v.severity || 'medium',
          description: v.description || '',
          legalBasis: v.legalBasis || ''
        });
      }
    }

    // State violations
    if (Array.isArray(stateViolations)) {
      for (const v of stateViolations) {
        violations.push({
          type: 'state',
          jurisdiction: v.jurisdiction || '',
          statuteName: v.statuteName || 'Unknown Statute',
          citation: v.citation || '',
          severity: v.severity || 'medium',
          description: v.description || ''
        });
      }
    }

    return violations;
  }

  /**
   * Extract key findings (discrepancies, anomalies) from the consolidated report.
   *
   * @param {Object} report - Consolidated audit report
   * @returns {Array} Simplified finding objects
   */
  _extractFindings(report) {
    const findings = [];

    // Support both consolidated report and raw aggregated data
    const documentAnalyses = report.documentAnalysis || report.documentAnalyses || [];
    const forensicData = report.forensicFindings || report.forensicReport || {};
    const discrepancies = forensicData.discrepancies || [];

    // Document anomalies
    for (const doc of documentAnalyses) {
      if (Array.isArray(doc.anomalies)) {
        for (const a of doc.anomalies) {
          findings.push({
            type: 'anomaly',
            source: doc.documentName || 'Unknown Document',
            field: a.field || '',
            severity: a.severity || 'medium',
            description: a.description || ''
          });
        }
      }
    }

    // Forensic discrepancies
    if (Array.isArray(discrepancies)) {
      for (const d of discrepancies) {
        findings.push({
          type: 'discrepancy',
          severity: d.severity || 'medium',
          description: d.description || d.type || ''
        });
      }
    }

    return findings;
  }

  /**
   * Parse Claude's JSON response, handling markdown code fences.
   *
   * @param {string} responseText - Raw Claude response
   * @returns {Object} Parsed object or { rawResponse, parseError }
   */
  _parseClaudeResponse(responseText) {
    if (!responseText || typeof responseText !== 'string' || responseText.trim().length === 0) {
      return { rawResponse: responseText || '', parseError: 'Empty response' };
    }

    try {
      return JSON.parse(responseText);
    } catch (directParseError) {
      // Try to extract JSON from markdown code fences
      const jsonMatch = responseText.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (jsonMatch) {
        try {
          return JSON.parse(jsonMatch[1].trim());
        } catch (fenceParseError) {
          // Fall through
        }
      }

      return {
        rawResponse: responseText,
        parseError: directParseError.message
      };
    }
  }

  /**
   * Format letter type enum to human-readable name.
   *
   * @param {string} letterType
   * @returns {string}
   */
  _formatLetterTypeName(letterType) {
    const names = {
      qualified_written_request: 'Qualified Written Request (QWR)',
      notice_of_error: 'Notice of Error',
      request_for_information: 'Request for Information (RFI)'
    };
    return names[letterType] || letterType;
  }
}

module.exports = new DisputeLetterService();
