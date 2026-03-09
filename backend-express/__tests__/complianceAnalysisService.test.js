/**
 * Compliance Analysis Service Tests
 *
 * Unit tests for ComplianceAnalysisService — the Claude AI integration layer
 * that enhances mechanical rule-engine violations with legal narratives.
 *
 * Anthropic client is mocked. Federal statute taxonomy and rule mappings
 * are tested against real config data.
 */

// ---------------------------------------------------------------------------
// Mock Anthropic SDK before requiring the service
// ---------------------------------------------------------------------------

const mockCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockCreate }
  }));
});

// Set API key so lazy init succeeds
process.env.ANTHROPIC_API_KEY = 'test-key-for-compliance-analysis';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeViolation(overrides = {}) {
  return {
    id: 'viol-001',
    statuteId: 'respa',
    sectionId: 'respa_s10',
    statuteName: 'Real Estate Settlement Procedures Act (RESPA)',
    sectionTitle: 'Escrow Account Requirements',
    citation: '12 U.S.C. § 2601 et seq.; 12 CFR § 1024.17',
    severity: 'high',
    description: 'Escrow account violation detected: Escrow balance discrepancy of $450 identified.',
    evidence: [{ sourceType: 'discrepancy', sourceId: 'disc-001', description: 'Escrow mismatch' }],
    legalBasis: 'RESPA Section 10 limits escrow cushions.',
    potentialPenalties: 'Actual damages, statutory damages up to $2,000 for individual actions, attorney fees and costs.',
    recommendations: [],
    ...overrides
  };
}

function makeCaseContext(overrides = {}) {
  return {
    caseId: 'case-test-001',
    documentTypes: ['servicing', 'origination'],
    discrepancySummary: '3 discrepancies found across 5 documents',
    ...overrides
  };
}

function mockClaudeEnhancementResponse(violations) {
  return {
    content: [{
      text: JSON.stringify({
        enhancedViolations: violations.map((v, i) => ({
          index: i,
          detailedLegalBasis: `Under ${v.citation || 'the statute'}, the servicer has an affirmative obligation to maintain escrow accounts in compliance with federal requirements. The identified discrepancy constitutes a violation of 12 CFR § 1024.17.`,
          potentialPenalties: 'Borrower may recover actual damages plus statutory damages up to $2,000 per violation under 12 U.S.C. § 2609.',
          recommendations: [
            'Conduct immediate escrow account reconciliation',
            'Refund any overcharges to borrower within 30 days',
            'Implement automated escrow calculation verification'
          ],
          regulatoryImplications: 'Pattern of escrow mismanagement may trigger CFPB supervisory action.'
        }))
      })
    }],
    usage: { input_tokens: 1500, output_tokens: 800 }
  };
}

function mockClaudeNarrativeResponse() {
  return {
    content: [{
      text: '## Compliance Analysis Summary\n\nThe audit identified significant violations of federal mortgage servicing regulations. The most concerning findings involve escrow account mismanagement under RESPA Section 10.\n\nThese violations expose the servicer to both individual and class action liability.'
    }],
    usage: { input_tokens: 1000, output_tokens: 400 }
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ComplianceAnalysisService', () => {
  let service;

  beforeAll(() => {
    service = require('../services/complianceAnalysisService');
  });

  beforeEach(() => {
    mockCreate.mockReset();
    // Reset the client so lazy init re-initializes
    service._client = null;
  });

  // -------------------------------------------------------------------------
  // analyzeViolations()
  // -------------------------------------------------------------------------
  describe('analyzeViolations()', () => {
    it('returns enhanced violations with legalBasis and recommendations when Claude responds', async () => {
      const violations = [makeViolation()];
      const context = makeCaseContext();

      mockCreate
        .mockResolvedValueOnce(mockClaudeEnhancementResponse(violations))
        .mockResolvedValueOnce(mockClaudeNarrativeResponse());

      const result = await service.analyzeViolations(violations, context);

      expect(result).toHaveProperty('enhancedViolations');
      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.enhancedViolations[0].legalBasis).toContain('12 CFR');
      expect(result.enhancedViolations[0].recommendations).toHaveLength(3);
      expect(result.enhancedViolations[0].regulatoryImplications).toBeDefined();
      expect(result).toHaveProperty('legalNarrative');
      expect(result.legalNarrative).toContain('Compliance Analysis');
      expect(result).toHaveProperty('analysisMetadata');
      expect(result.analysisMetadata.totalViolations).toBe(1);
      expect(result.analysisMetadata.claudeCallsMade).toBeGreaterThanOrEqual(2);
    });

    it('returns original violations unchanged when Claude call fails (graceful degradation)', async () => {
      const violations = [makeViolation()];
      const context = makeCaseContext();

      mockCreate.mockRejectedValue(new Error('API rate limit exceeded'));

      const result = await service.analyzeViolations(violations, context);

      expect(result.enhancedViolations).toHaveLength(1);
      // Should have original legalBasis, not enhanced
      expect(result.enhancedViolations[0].legalBasis).toBe('RESPA Section 10 limits escrow cushions.');
      expect(result.legalNarrative).toBe('');
    });

    it('groups violations by statute for batched Claude calls', async () => {
      const violations = [
        makeViolation({ id: 'viol-001', statuteId: 'respa', sectionId: 'respa_s10' }),
        makeViolation({ id: 'viol-002', statuteId: 'tila', sectionId: 'tila_disclosure', statuteName: 'Truth in Lending Act (TILA) / Regulation Z' }),
        makeViolation({ id: 'viol-003', statuteId: 'respa', sectionId: 'respa_s6' })
      ];
      const context = makeCaseContext();

      // Two statute groups (respa, tila) + one narrative call = 3 calls
      mockCreate
        .mockResolvedValueOnce(mockClaudeEnhancementResponse([violations[0], violations[2]]))
        .mockResolvedValueOnce(mockClaudeEnhancementResponse([violations[1]]))
        .mockResolvedValueOnce(mockClaudeNarrativeResponse());

      const result = await service.analyzeViolations(violations, context);

      expect(result.enhancedViolations).toHaveLength(3);
      // At least 3 Claude calls: 2 statute batches + 1 narrative
      expect(mockCreate).toHaveBeenCalledTimes(3);
    });

    it('handles empty violations array', async () => {
      const result = await service.analyzeViolations([], makeCaseContext());

      expect(result.enhancedViolations).toEqual([]);
      expect(result.legalNarrative).toBe('');
      expect(result.analysisMetadata.totalViolations).toBe(0);
      expect(result.analysisMetadata.claudeCallsMade).toBe(0);
      expect(mockCreate).not.toHaveBeenCalled();
    });

    it('handles null/missing caseContext gracefully', async () => {
      const violations = [makeViolation()];

      mockCreate
        .mockResolvedValueOnce(mockClaudeEnhancementResponse(violations))
        .mockResolvedValueOnce(mockClaudeNarrativeResponse());

      const result = await service.analyzeViolations(violations, null);

      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.analysisMetadata.totalViolations).toBe(1);
    });

    it('handles non-array violations input', async () => {
      const result = await service.analyzeViolations(null, makeCaseContext());
      expect(result.enhancedViolations).toEqual([]);
      expect(result.analysisMetadata.claudeCallsMade).toBe(0);
    });
  });

  // -------------------------------------------------------------------------
  // generateLegalNarrative()
  // -------------------------------------------------------------------------
  describe('generateLegalNarrative()', () => {
    it('returns markdown narrative string when Claude responds', async () => {
      const violations = [makeViolation()];
      mockCreate.mockResolvedValueOnce(mockClaudeNarrativeResponse());

      const narrative = await service.generateLegalNarrative(violations, makeCaseContext());

      expect(typeof narrative).toBe('string');
      expect(narrative).toContain('Compliance Analysis');
      expect(narrative.length).toBeGreaterThan(0);
    });

    it('returns empty string when Claude fails', async () => {
      const violations = [makeViolation()];
      mockCreate.mockRejectedValue(new Error('Service unavailable'));

      const narrative = await service.generateLegalNarrative(violations, makeCaseContext());

      expect(narrative).toBe('');
    });

    it('includes all statute names in narrative prompt', async () => {
      const violations = [
        makeViolation({ statuteName: 'RESPA' }),
        makeViolation({ statuteName: 'TILA', statuteId: 'tila' })
      ];
      mockCreate.mockResolvedValueOnce(mockClaudeNarrativeResponse());

      await service.generateLegalNarrative(violations, makeCaseContext());

      const callArgs = mockCreate.mock.calls[0][0];
      const prompt = callArgs.messages[0].content;
      expect(prompt).toContain('RESPA');
      expect(prompt).toContain('TILA');
    });

    it('returns empty string for empty violations', async () => {
      const narrative = await service.generateLegalNarrative([], makeCaseContext());
      expect(narrative).toBe('');
      expect(mockCreate).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // _buildCompliancePrompt()
  // -------------------------------------------------------------------------
  describe('_buildCompliancePrompt()', () => {
    it('includes statute name and citation', () => {
      const { getStatuteById } = require('../config/federalStatuteTaxonomy');
      const statute = getStatuteById('respa');
      const violations = [makeViolation()];

      const prompt = service._buildCompliancePrompt(violations, statute, makeCaseContext());

      expect(prompt).toContain('Real Estate Settlement Procedures Act (RESPA)');
      expect(prompt).toContain('12 U.S.C. § 2601 et seq.');
    });

    it('includes relevant sections and requirements', () => {
      const { getStatuteById } = require('../config/federalStatuteTaxonomy');
      const statute = getStatuteById('respa');
      const violations = [makeViolation({ sectionId: 'respa_s10' })];

      const prompt = service._buildCompliancePrompt(violations, statute, makeCaseContext());

      expect(prompt).toContain('Escrow Account Requirements');
      expect(prompt).toContain('regulatoryReference');
    });

    it('includes violation details', () => {
      const { getStatuteById } = require('../config/federalStatuteTaxonomy');
      const statute = getStatuteById('respa');
      const violations = [makeViolation({ description: 'Escrow cushion exceeded RESPA limit by $200' })];

      const prompt = service._buildCompliancePrompt(violations, statute, makeCaseContext());

      expect(prompt).toContain('Escrow cushion exceeded RESPA limit by $200');
    });

    it('requests JSON output format', () => {
      const { getStatuteById } = require('../config/federalStatuteTaxonomy');
      const statute = getStatuteById('respa');
      const violations = [makeViolation()];

      const prompt = service._buildCompliancePrompt(violations, statute, makeCaseContext());

      expect(prompt).toContain('JSON');
      expect(prompt).toContain('enhancedViolations');
    });

    it('handles null statute gracefully', () => {
      const violations = [makeViolation()];
      const prompt = service._buildCompliancePrompt(violations, null, makeCaseContext());

      expect(prompt).toContain('Unknown Statute');
      expect(prompt).toContain('Unknown Citation');
    });
  });

  // -------------------------------------------------------------------------
  // _parseClaudeResponse()
  // -------------------------------------------------------------------------
  describe('_parseClaudeResponse()', () => {
    it('parses clean JSON response', () => {
      const data = { enhancedViolations: [{ index: 0, detailedLegalBasis: 'test' }] };
      const result = service._parseClaudeResponse(JSON.stringify(data));

      expect(result).toEqual(data);
      expect(result.parseError).toBeUndefined();
    });

    it('extracts JSON from markdown code fences', () => {
      const data = { enhancedViolations: [{ index: 0, detailedLegalBasis: 'test' }] };
      const wrapped = '```json\n' + JSON.stringify(data) + '\n```';
      const result = service._parseClaudeResponse(wrapped);

      expect(result).toEqual(data);
    });

    it('returns { rawResponse, parseError } on invalid JSON', () => {
      const result = service._parseClaudeResponse('not valid json at all');

      expect(result).toHaveProperty('rawResponse', 'not valid json at all');
      expect(result).toHaveProperty('parseError');
      expect(typeof result.parseError).toBe('string');
    });

    it('handles empty response', () => {
      const result = service._parseClaudeResponse('');
      expect(result).toHaveProperty('parseError', 'Empty response');

      const resultNull = service._parseClaudeResponse(null);
      expect(resultNull).toHaveProperty('parseError', 'Empty response');
    });

    it('extracts JSON from code fence without json label', () => {
      const data = { enhancedViolations: [] };
      const wrapped = '```\n' + JSON.stringify(data) + '\n```';
      const result = service._parseClaudeResponse(wrapped);

      expect(result).toEqual(data);
    });
  });

  // -------------------------------------------------------------------------
  // _mergeEnhancements()
  // -------------------------------------------------------------------------
  describe('_mergeEnhancements()', () => {
    it('merges enhancement data into violation objects', () => {
      const violations = [makeViolation()];
      const parsed = {
        enhancedViolations: [{
          index: 0,
          detailedLegalBasis: 'Enhanced legal basis text',
          potentialPenalties: 'Enhanced penalties',
          recommendations: ['Action 1', 'Action 2'],
          regulatoryImplications: 'Pattern concern'
        }]
      };

      const result = service._mergeEnhancements(violations, parsed);

      expect(result[0].legalBasis).toBe('Enhanced legal basis text');
      expect(result[0].potentialPenalties).toBe('Enhanced penalties');
      expect(result[0].recommendations).toEqual(['Action 1', 'Action 2']);
      expect(result[0].regulatoryImplications).toBe('Pattern concern');
      // Other fields preserved
      expect(result[0].id).toBe('viol-001');
      expect(result[0].statuteId).toBe('respa');
    });

    it('returns original violations when parsed has no enhancedViolations', () => {
      const violations = [makeViolation()];
      const result = service._mergeEnhancements(violations, {});

      expect(result[0].legalBasis).toBe('RESPA Section 10 limits escrow cushions.');
    });
  });

  // -------------------------------------------------------------------------
  // Claude call configuration
  // -------------------------------------------------------------------------
  describe('Claude call configuration', () => {
    it('uses temperature 0.1 and claude-sonnet-4-5 model', async () => {
      const violations = [makeViolation()];
      mockCreate
        .mockResolvedValueOnce(mockClaudeEnhancementResponse(violations))
        .mockResolvedValueOnce(mockClaudeNarrativeResponse());

      await service.analyzeViolations(violations, makeCaseContext());

      const firstCall = mockCreate.mock.calls[0][0];
      expect(firstCall.temperature).toBe(0.1);
      expect(firstCall.model).toBe('claude-sonnet-4-5-20250514');
      expect(firstCall.max_tokens).toBe(4096);
    });

    it('uses 2048 max_tokens for narrative calls', async () => {
      const violations = [makeViolation()];
      mockCreate.mockResolvedValueOnce(mockClaudeNarrativeResponse());

      await service.generateLegalNarrative(violations, makeCaseContext());

      const callArgs = mockCreate.mock.calls[0][0];
      expect(callArgs.max_tokens).toBe(2048);
    });
  });
});
