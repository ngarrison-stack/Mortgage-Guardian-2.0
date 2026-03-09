/**
 * Compliance Analysis Service
 *
 * Uses Claude AI to generate litigation-grade legal analysis for compliance
 * violations identified by the ComplianceRuleEngine (14-03). While the rule
 * engine identifies violations mechanically, this service explains WHY a
 * finding constitutes a violation, what the legal consequences are, and
 * what remedial actions are appropriate.
 *
 * Input:  violations[] (from rule engine), caseContext
 * Output: { enhancedViolations[], legalNarrative, analysisMetadata }
 */

const Anthropic = require('@anthropic-ai/sdk');
const { createLogger } = require('../utils/logger');
const { getStatuteById } = require('../config/federalStatuteTaxonomy');

const logger = createLogger('compliance-analysis');

const DEFAULT_MODEL = 'claude-sonnet-4-5-20250514';
const DEFAULT_TEMPERATURE = 0.1;
const MAX_VIOLATIONS_PER_BATCH = 10;
const VIOLATION_MAX_TOKENS = 4096;
const NARRATIVE_MAX_TOKENS = 2048;

class ComplianceAnalysisService {
  constructor() {
    this._client = null;
  }

  /**
   * Lazily initialize the Anthropic client.
   * Deferred so missing API key only errors when analysis is actually needed.
   */
  _getClient() {
    if (!this._client) {
      if (!process.env.ANTHROPIC_API_KEY) {
        throw new Error('Compliance analysis requires ANTHROPIC_API_KEY');
      }
      this._client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    }
    return this._client;
  }

  /**
   * Main method — enhance violations with AI-generated legal analysis.
   *
   * @param {Array} violations - Violation objects from ComplianceRuleEngine
   * @param {Object} [caseContext] - Case context { caseId, documentTypes, discrepancySummary }
   * @returns {Promise<Object>} { enhancedViolations, legalNarrative, analysisMetadata }
   */
  async analyzeViolations(violations, caseContext) {
    const startTime = Date.now();
    const context = caseContext || {};

    if (!Array.isArray(violations) || violations.length === 0) {
      logger.info('No violations to analyze', { caseId: context.caseId });
      return {
        enhancedViolations: [],
        legalNarrative: '',
        analysisMetadata: {
          totalViolations: 0,
          claudeCallsMade: 0,
          durationMs: Date.now() - startTime,
          model: DEFAULT_MODEL
        }
      };
    }

    // Group violations by statuteId for batched analysis
    const groupedByStatute = this._groupByStatute(violations);
    let enhancedViolations = [];
    let claudeCallsMade = 0;
    let totalInputTokens = 0;
    let totalOutputTokens = 0;

    for (const [statuteId, statuteViolations] of Object.entries(groupedByStatute)) {
      // Batch violations (max 10 per Claude call)
      const batches = this._createBatches(statuteViolations, MAX_VIOLATIONS_PER_BATCH);

      for (const batch of batches) {
        try {
          const statute = getStatuteById(statuteId);
          const prompt = this._buildCompliancePrompt(batch, statute, context);

          const client = this._getClient();
          const response = await client.messages.create({
            model: DEFAULT_MODEL,
            max_tokens: VIOLATION_MAX_TOKENS,
            temperature: DEFAULT_TEMPERATURE,
            messages: [{ role: 'user', content: prompt }]
          });

          claudeCallsMade++;
          const usage = response.usage || {};
          totalInputTokens += usage.input_tokens || 0;
          totalOutputTokens += usage.output_tokens || 0;

          const responseText = response.content[0].text;
          const parsed = this._parseClaudeResponse(responseText);

          if (parsed.parseError) {
            logger.warn('Failed to parse Claude compliance response', {
              statuteId,
              parseError: parsed.parseError
            });
            // Graceful degradation: return violations unchanged
            enhancedViolations.push(...batch);
          } else {
            const enhanced = this._mergeEnhancements(batch, parsed);
            enhancedViolations.push(...enhanced);
          }
        } catch (error) {
          logger.error('Claude compliance analysis call failed', {
            error: error.message,
            statuteId,
            batchSize: batch.length
          });
          // Graceful degradation: return violations unchanged
          enhancedViolations.push(...batch);
        }
      }
    }

    // Generate legal narrative
    let legalNarrative = '';
    try {
      legalNarrative = await this.generateLegalNarrative(enhancedViolations, context);
      claudeCallsMade++;
    } catch (error) {
      logger.error('Legal narrative generation failed', { error: error.message });
    }

    const durationMs = Date.now() - startTime;
    logger.info('Compliance analysis completed', {
      caseId: context.caseId,
      totalViolations: violations.length,
      claudeCallsMade,
      durationMs,
      totalInputTokens,
      totalOutputTokens
    });

    return {
      enhancedViolations,
      legalNarrative,
      analysisMetadata: {
        totalViolations: violations.length,
        claudeCallsMade,
        durationMs,
        model: DEFAULT_MODEL,
        totalInputTokens,
        totalOutputTokens
      }
    };
  }

  /**
   * Generate a case-level legal narrative summarizing all violations.
   *
   * @param {Array} violations - Enhanced violations array
   * @param {Object} [caseContext] - Case context
   * @returns {Promise<string>} Markdown-formatted legal narrative
   */
  async generateLegalNarrative(violations, caseContext) {
    const context = caseContext || {};

    if (!Array.isArray(violations) || violations.length === 0) {
      return '';
    }

    try {
      const prompt = this._buildNarrativePrompt(violations, context);
      const client = this._getClient();

      const response = await client.messages.create({
        model: DEFAULT_MODEL,
        max_tokens: NARRATIVE_MAX_TOKENS,
        temperature: DEFAULT_TEMPERATURE,
        messages: [{ role: 'user', content: prompt }]
      });

      return response.content[0].text;
    } catch (error) {
      logger.error('Legal narrative Claude call failed', { error: error.message });
      return '';
    }
  }

  /**
   * Build a statute-specific prompt for Claude to enhance violations.
   *
   * @param {Array} violations - Violations for this statute batch
   * @param {Object|undefined} statute - Statute from federalStatuteTaxonomy
   * @param {Object} caseContext - Case context
   * @returns {string} Prompt string
   */
  _buildCompliancePrompt(violations, statute, caseContext) {
    const statuteName = statute ? statute.name : 'Unknown Statute';
    const statuteCitation = statute ? statute.citation : 'Unknown Citation';
    const regulatoryBody = statute ? statute.regulatoryBody : 'Unknown';

    // Collect relevant sections
    const sectionDetails = [];
    if (statute && Array.isArray(statute.sections)) {
      const relevantSectionIds = new Set(violations.map(v => v.sectionId));
      for (const section of statute.sections) {
        if (relevantSectionIds.has(section.id)) {
          sectionDetails.push({
            id: section.id,
            section: section.section,
            title: section.title,
            regulatoryReference: section.regulatoryReference,
            requirements: section.requirements,
            penalties: section.penalties
          });
        }
      }
    }

    const violationSummaries = violations.map((v, i) => ({
      index: i,
      id: v.id,
      sectionId: v.sectionId,
      sectionTitle: v.sectionTitle,
      severity: v.severity,
      description: v.description,
      evidence: v.evidence,
      legalBasis: v.legalBasis,
      potentialPenalties: v.potentialPenalties
    }));

    return `You are a federal regulatory compliance attorney specializing in mortgage servicing law. Analyze the following violations under ${statuteName} (${statuteCitation}), enforced by ${regulatoryBody}.

## Statute Context

**Statute:** ${statuteName}
**Citation:** ${statuteCitation}
**Regulatory Body:** ${regulatoryBody}

### Relevant Sections:
${JSON.stringify(sectionDetails, null, 2)}

## Case Context

Case ID: ${caseContext.caseId || 'N/A'}
Document Types: ${Array.isArray(caseContext.documentTypes) ? caseContext.documentTypes.join(', ') : 'N/A'}
Discrepancy Summary: ${caseContext.discrepancySummary || 'N/A'}

## Violations to Analyze

${JSON.stringify(violationSummaries, null, 2)}

## Instructions

For EACH violation above, provide enhanced legal analysis. Respond with valid JSON in this format:

\`\`\`json
{
  "enhancedViolations": [
    {
      "index": 0,
      "detailedLegalBasis": "Detailed explanation citing specific regulatory provisions and why this finding constitutes a violation",
      "potentialPenalties": "Specific penalty exposure based on the statute and severity",
      "recommendations": ["Specific remedial action 1", "Specific remedial action 2"],
      "regulatoryImplications": "Broader regulatory implications of this violation"
    }
  ]
}
\`\`\`

Cite specific regulatory provisions (CFR sections, U.S.C. sections). Be precise and litigation-ready.
Respond ONLY with valid JSON. No explanation outside the JSON.`;
  }

  /**
   * Build the narrative prompt for case-level legal summary.
   *
   * @param {Array} enhancedViolations - All enhanced violations
   * @param {Object} caseContext - Case context
   * @returns {string} Prompt string
   */
  _buildNarrativePrompt(enhancedViolations, caseContext) {
    // Collect unique statute names
    const statuteNames = [...new Set(enhancedViolations.map(v => v.statuteName).filter(Boolean))];

    const violationSummaries = enhancedViolations.map(v => ({
      id: v.id,
      statuteName: v.statuteName,
      sectionTitle: v.sectionTitle,
      severity: v.severity,
      description: v.description,
      citation: v.citation
    }));

    return `You are a senior regulatory compliance attorney preparing a compliance report narrative for a mortgage servicing audit case.

## Case Context

Case ID: ${caseContext.caseId || 'N/A'}
Document Types: ${Array.isArray(caseContext.documentTypes) ? caseContext.documentTypes.join(', ') : 'N/A'}
Statutes Implicated: ${statuteNames.join(', ') || 'N/A'}

## Violations Found

${JSON.stringify(violationSummaries, null, 2)}

## Instructions

Write a 3-5 paragraph legal narrative suitable for inclusion in a formal compliance report. The narrative should:

1. **Overview**: Summarize the nature and scope of violations found
2. **Most Serious Concerns**: Highlight the most critical violations and their implications for the borrower
3. **Regulatory Implications**: Explain the regulatory exposure and potential enforcement consequences
4. **Recommended Actions**: Outline specific remedial steps the servicer should take

Use professional legal tone. Reference specific statutes and regulations. This narrative will accompany the detailed violation findings in the compliance report.

Respond with the narrative text in markdown format (no JSON wrapper needed).`;
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

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /**
   * Group violations by their statuteId.
   *
   * @param {Array} violations
   * @returns {Object} Map of statuteId -> violations[]
   */
  _groupByStatute(violations) {
    const grouped = {};
    for (const v of violations) {
      const key = v.statuteId || 'unknown';
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(v);
    }
    return grouped;
  }

  /**
   * Split an array into batches of maxSize.
   *
   * @param {Array} items
   * @param {number} maxSize
   * @returns {Array<Array>}
   */
  _createBatches(items, maxSize) {
    const batches = [];
    for (let i = 0; i < items.length; i += maxSize) {
      batches.push(items.slice(i, i + maxSize));
    }
    return batches;
  }

  /**
   * Merge Claude-generated enhancements back into violation objects.
   *
   * @param {Array} violations - Original violation batch
   * @param {Object} parsed - Parsed Claude response with enhancedViolations
   * @returns {Array} Enhanced violations
   */
  _mergeEnhancements(violations, parsed) {
    if (!parsed.enhancedViolations || !Array.isArray(parsed.enhancedViolations)) {
      return violations;
    }

    // Build a lookup by index
    const enhancementMap = {};
    for (const enhancement of parsed.enhancedViolations) {
      if (enhancement.index !== undefined) {
        enhancementMap[enhancement.index] = enhancement;
      }
    }

    return violations.map((v, i) => {
      const enhancement = enhancementMap[i];
      if (!enhancement) return v;

      return {
        ...v,
        legalBasis: enhancement.detailedLegalBasis || v.legalBasis,
        potentialPenalties: enhancement.potentialPenalties || v.potentialPenalties,
        recommendations: Array.isArray(enhancement.recommendations)
          ? enhancement.recommendations
          : v.recommendations || [],
        regulatoryImplications: enhancement.regulatoryImplications || undefined
      };
    });
  }
}

module.exports = new ComplianceAnalysisService();
