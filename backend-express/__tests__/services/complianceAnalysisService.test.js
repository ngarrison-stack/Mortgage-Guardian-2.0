/**
 * Unit tests for ComplianceAnalysisService (services/complianceAnalysisService.js)
 *
 * Covers: analyzeViolations, analyzeStateViolations, generateLegalNarrative,
 * _parseClaudeResponse, _mergeEnhancements, _buildCompliancePrompt,
 * _buildNarrativePrompt, _buildStateViolationPrompt, _groupByStatute,
 * _createBatches, and lazy client initialization.
 */

const mockMessagesCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate }
  }));
});

// Mock logger to suppress output in tests
jest.mock('../../utils/logger', () => ({
  createLogger: () => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn()
  })
}));

// Mock taxonomy lookups
jest.mock('../../config/federalStatuteTaxonomy', () => ({
  getStatuteById: jest.fn((id) => {
    if (id === 'respa') {
      return {
        name: 'RESPA',
        citation: '12 U.S.C. § 2601',
        regulatoryBody: 'CFPB',
        sections: [
          {
            id: 'respa_s10',
            section: 'Section 10',
            title: 'Escrow Accounts',
            regulatoryReference: '12 CFR § 1024.17',
            requirements: ['Annual escrow analysis'],
            penalties: 'Actual damages plus statutory damages'
          }
        ]
      };
    }
    return undefined;
  })
}));

jest.mock('../../config/stateStatuteTaxonomy', () => ({
  getStateStatuteById: jest.fn((state, id) => {
    if (state === 'CA' && id === 'ca_hbor') {
      return {
        name: 'California Homeowner Bill of Rights',
        citation: 'Cal. Civ. Code §§ 2923.4-2924.12',
        enforcementBody: 'CA DFPI'
      };
    }
    return undefined;
  }),
  getStateSectionById: jest.fn((state, id) => {
    if (state === 'CA' && id === 'ca_hbor_dual_tracking') {
      return {
        id: 'ca_hbor_dual_tracking',
        section: '§ 2924.11',
        title: 'Prohibition of Dual Tracking',
        regulatoryReference: 'Cal. Civ. Code § 2924.11',
        requirements: ['No dual tracking'],
        penalties: 'Injunctive relief and damages'
      };
    }
    return undefined;
  })
}));

// Save original env
const originalEnv = process.env.ANTHROPIC_API_KEY;

// Re-require AFTER mocks
const complianceAnalysisService = require('../../services/complianceAnalysisService');

// ============================================================
// Helpers
// ============================================================

function makeViolation(overrides = {}) {
  return {
    id: 'viol-001',
    statuteId: 'respa',
    sectionId: 'respa_s10',
    statuteName: 'RESPA',
    sectionTitle: 'Escrow Accounts',
    citation: '12 U.S.C. § 2601',
    severity: 'high',
    description: 'Escrow overcharge detected',
    evidence: [{ sourceType: 'discrepancy', sourceId: 'disc-001', description: 'Overcharge' }],
    legalBasis: 'RESPA Section 10',
    potentialPenalties: 'Statutory damages',
    recommendations: [],
    ...overrides
  };
}

function makeStateViolation(overrides = {}) {
  return {
    id: 'state-viol-001',
    statuteId: 'ca_hbor',
    sectionId: 'ca_hbor_dual_tracking',
    statuteName: 'California Homeowner Bill of Rights',
    sectionTitle: 'Prohibition of Dual Tracking',
    citation: 'Cal. Civ. Code § 2924.11',
    severity: 'critical',
    description: 'Dual tracking violation',
    evidence: [{ sourceType: 'discrepancy', sourceId: 'disc-001', description: 'Dual tracking' }],
    legalBasis: 'Cal. Civ. Code § 2924.11',
    potentialPenalties: 'Injunctive relief',
    recommendations: [],
    jurisdiction: 'CA',
    ...overrides
  };
}

function makeClaudeEnhancementResponse(count = 1) {
  const enhancedViolations = [];
  for (let i = 0; i < count; i++) {
    enhancedViolations.push({
      index: i,
      detailedLegalBasis: `Detailed legal basis for violation ${i}`,
      potentialPenalties: `Penalty exposure for violation ${i}`,
      recommendations: [`Remedial action ${i}-a`, `Remedial action ${i}-b`],
      regulatoryImplications: `Regulatory implications for violation ${i}`
    });
  }
  return { enhancedViolations };
}

function mockClaudeResponse(jsonObj) {
  return {
    content: [{ text: JSON.stringify(jsonObj) }],
    usage: { input_tokens: 500, output_tokens: 200 }
  };
}

// ============================================================
// Tests
// ============================================================

describe('ComplianceAnalysisService', () => {
  beforeEach(() => {
    mockMessagesCreate.mockReset();
    process.env.ANTHROPIC_API_KEY = 'test-key-123';
    // Reset the lazy client so each test starts fresh
    complianceAnalysisService._client = null;
  });

  afterAll(() => {
    process.env.ANTHROPIC_API_KEY = originalEnv;
  });

  // ================================================================
  // _getClient — lazy initialization
  // ================================================================
  describe('_getClient', () => {
    it('throws when ANTHROPIC_API_KEY is missing', () => {
      delete process.env.ANTHROPIC_API_KEY;
      expect(() => complianceAnalysisService._getClient()).toThrow(
        'Compliance analysis requires ANTHROPIC_API_KEY'
      );
    });

    it('returns a client when ANTHROPIC_API_KEY is set', () => {
      const client = complianceAnalysisService._getClient();
      expect(client).toBeDefined();
      expect(client.messages).toBeDefined();
    });

    it('reuses the same client on subsequent calls', () => {
      const client1 = complianceAnalysisService._getClient();
      const client2 = complianceAnalysisService._getClient();
      expect(client1).toBe(client2);
    });
  });

  // ================================================================
  // analyzeViolations
  // ================================================================
  describe('analyzeViolations', () => {
    it('returns empty result for null violations', async () => {
      const result = await complianceAnalysisService.analyzeViolations(null, { caseId: 'C1' });
      expect(result.enhancedViolations).toEqual([]);
      expect(result.legalNarrative).toBe('');
      expect(result.analysisMetadata.totalViolations).toBe(0);
      expect(result.analysisMetadata.claudeCallsMade).toBe(0);
    });

    it('returns empty result for empty array', async () => {
      const result = await complianceAnalysisService.analyzeViolations([], {});
      expect(result.enhancedViolations).toEqual([]);
      expect(result.analysisMetadata.totalViolations).toBe(0);
    });

    it('returns empty result for non-array violations', async () => {
      const result = await complianceAnalysisService.analyzeViolations('not-an-array');
      expect(result.enhancedViolations).toEqual([]);
    });

    it('enhances violations with Claude response', async () => {
      const violation = makeViolation();
      const enhancementData = makeClaudeEnhancementResponse(1);

      // First call: violation enhancement; Second call: narrative
      mockMessagesCreate
        .mockResolvedValueOnce(mockClaudeResponse(enhancementData))
        .mockResolvedValueOnce({
          content: [{ text: 'Legal narrative text here.' }],
          usage: { input_tokens: 300, output_tokens: 100 }
        });

      const result = await complianceAnalysisService.analyzeViolations(
        [violation],
        { caseId: 'C1', documentTypes: ['mortgage_statement'], discrepancySummary: 'test' }
      );

      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.enhancedViolations[0].legalBasis).toBe('Detailed legal basis for violation 0');
      expect(result.enhancedViolations[0].recommendations).toEqual(['Remedial action 0-a', 'Remedial action 0-b']);
      expect(result.enhancedViolations[0].regulatoryImplications).toBe('Regulatory implications for violation 0');
      expect(result.legalNarrative).toBe('Legal narrative text here.');
      expect(result.analysisMetadata.claudeCallsMade).toBe(2); // 1 enhancement + 1 narrative
      expect(result.analysisMetadata.totalViolations).toBe(1);
      expect(result.analysisMetadata.model).toBeDefined();
    });

    it('handles parse error gracefully — returns violations unchanged', async () => {
      const violation = makeViolation();

      // Return invalid JSON (non-parseable)
      mockMessagesCreate
        .mockResolvedValueOnce({
          content: [{ text: 'This is not JSON at all' }],
          usage: { input_tokens: 100, output_tokens: 50 }
        })
        .mockResolvedValueOnce({
          content: [{ text: '' }],
          usage: { input_tokens: 100, output_tokens: 50 }
        });

      const result = await complianceAnalysisService.analyzeViolations([violation], { caseId: 'C2' });

      // Violation returned unchanged (graceful degradation)
      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.enhancedViolations[0].legalBasis).toBe('RESPA Section 10');
    });

    it('handles Claude API error gracefully — returns violations unchanged', async () => {
      const violation = makeViolation();

      mockMessagesCreate
        .mockRejectedValueOnce(new Error('API rate limit exceeded'))
        .mockResolvedValueOnce({
          content: [{ text: '' }],
          usage: { input_tokens: 50, output_tokens: 10 }
        });

      const result = await complianceAnalysisService.analyzeViolations([violation], { caseId: 'C3' });

      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.enhancedViolations[0].legalBasis).toBe('RESPA Section 10');
    });

    it('handles narrative generation failure gracefully', async () => {
      const violation = makeViolation();
      const enhancementData = makeClaudeEnhancementResponse(1);

      // Enhancement succeeds, narrative fails
      mockMessagesCreate
        .mockResolvedValueOnce(mockClaudeResponse(enhancementData))
        .mockRejectedValueOnce(new Error('Narrative generation failed'));

      const result = await complianceAnalysisService.analyzeViolations([violation], { caseId: 'C4' });

      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.legalNarrative).toBe('');
      // generateLegalNarrative catches its own errors internally and returns '',
      // so it never throws to caller — claudeCallsMade++ still executes
      expect(result.analysisMetadata.claudeCallsMade).toBe(2);
    });

    it('groups violations by statute and batches correctly', async () => {
      const violations = [
        makeViolation({ statuteId: 'respa', id: 'v1' }),
        makeViolation({ statuteId: 'respa', id: 'v2' }),
        makeViolation({ statuteId: 'tila', id: 'v3' })
      ];

      const resp1 = makeClaudeEnhancementResponse(2);
      const resp2 = makeClaudeEnhancementResponse(1);

      mockMessagesCreate
        .mockResolvedValueOnce(mockClaudeResponse(resp1))  // respa batch
        .mockResolvedValueOnce(mockClaudeResponse(resp2))  // tila batch
        .mockResolvedValueOnce({                            // narrative
          content: [{ text: 'Narrative' }],
          usage: { input_tokens: 100, output_tokens: 50 }
        });

      const result = await complianceAnalysisService.analyzeViolations(violations, { caseId: 'C5' });

      expect(result.enhancedViolations).toHaveLength(3);
      expect(result.analysisMetadata.claudeCallsMade).toBe(3);
      expect(result.analysisMetadata.totalViolations).toBe(3);
    });

    it('tracks token usage from Claude responses', async () => {
      const violation = makeViolation();
      const enhancementData = makeClaudeEnhancementResponse(1);

      mockMessagesCreate
        .mockResolvedValueOnce({
          content: [{ text: JSON.stringify(enhancementData) }],
          usage: { input_tokens: 500, output_tokens: 200 }
        })
        .mockResolvedValueOnce({
          content: [{ text: 'Narrative text' }],
          usage: { input_tokens: 300, output_tokens: 150 }
        });

      const result = await complianceAnalysisService.analyzeViolations([violation], { caseId: 'C6' });

      expect(result.analysisMetadata.totalInputTokens).toBe(500);
      expect(result.analysisMetadata.totalOutputTokens).toBe(200);
    });

    it('handles response with no usage object', async () => {
      const violation = makeViolation();
      const enhancementData = makeClaudeEnhancementResponse(1);

      mockMessagesCreate
        .mockResolvedValueOnce({
          content: [{ text: JSON.stringify(enhancementData) }]
          // no usage field
        })
        .mockResolvedValueOnce({
          content: [{ text: 'Narrative' }],
          usage: { input_tokens: 100, output_tokens: 50 }
        });

      const result = await complianceAnalysisService.analyzeViolations([violation], {});

      expect(result.analysisMetadata.totalInputTokens).toBe(0);
      expect(result.analysisMetadata.totalOutputTokens).toBe(0);
    });

    it('works without caseContext (defaults to {})', async () => {
      const result = await complianceAnalysisService.analyzeViolations(null);
      expect(result.enhancedViolations).toEqual([]);
      expect(result.analysisMetadata.totalViolations).toBe(0);
    });
  });

  // ================================================================
  // analyzeStateViolations
  // ================================================================
  describe('analyzeStateViolations', () => {
    it('returns empty result for null state violations', async () => {
      const result = await complianceAnalysisService.analyzeStateViolations(null, { caseId: 'S1' });
      expect(result.enhancedViolations).toEqual([]);
      expect(result.analysisMetadata.totalViolations).toBe(0);
      expect(result.analysisMetadata.claudeCallsMade).toBe(0);
    });

    it('returns empty result for empty array', async () => {
      const result = await complianceAnalysisService.analyzeStateViolations([], {});
      expect(result.enhancedViolations).toEqual([]);
    });

    it('returns empty result for non-array input', async () => {
      const result = await complianceAnalysisService.analyzeStateViolations('bad-input');
      expect(result.enhancedViolations).toEqual([]);
    });

    it('enhances state violations with Claude response', async () => {
      const violation = makeStateViolation();
      const enhancementData = makeClaudeEnhancementResponse(1);

      mockMessagesCreate.mockResolvedValueOnce(mockClaudeResponse(enhancementData));

      const result = await complianceAnalysisService.analyzeStateViolations(
        [violation],
        { caseId: 'S2', documentTypes: ['loan_estimate'] }
      );

      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.enhancedViolations[0].legalBasis).toBe('Detailed legal basis for violation 0');
      expect(result.enhancedViolations[0].recommendations).toHaveLength(2);
      expect(result.analysisMetadata.claudeCallsMade).toBe(1);
      expect(result.analysisMetadata.totalViolations).toBe(1);
    });

    it('handles parse error for state violations gracefully', async () => {
      const violation = makeStateViolation();

      mockMessagesCreate.mockResolvedValueOnce({
        content: [{ text: 'Not valid JSON' }],
        usage: { input_tokens: 100, output_tokens: 50 }
      });

      const result = await complianceAnalysisService.analyzeStateViolations([violation], {});
      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.enhancedViolations[0].legalBasis).toBe('Cal. Civ. Code § 2924.11');
    });

    it('handles Claude API error for state violations gracefully', async () => {
      const violation = makeStateViolation();

      mockMessagesCreate.mockRejectedValueOnce(new Error('Service unavailable'));

      const result = await complianceAnalysisService.analyzeStateViolations([violation], { caseId: 'S3' });
      expect(result.enhancedViolations).toHaveLength(1);
      expect(result.enhancedViolations[0].legalBasis).toBe('Cal. Civ. Code § 2924.11');
    });

    it('groups state violations by statute', async () => {
      const v1 = makeStateViolation({ statuteId: 'ca_hbor', id: 'sv1' });
      const v2 = makeStateViolation({ statuteId: 'ca_civ', id: 'sv2' });

      mockMessagesCreate
        .mockResolvedValueOnce(mockClaudeResponse(makeClaudeEnhancementResponse(1)))
        .mockResolvedValueOnce(mockClaudeResponse(makeClaudeEnhancementResponse(1)));

      const result = await complianceAnalysisService.analyzeStateViolations([v1, v2], { caseId: 'S4' });

      expect(result.enhancedViolations).toHaveLength(2);
      expect(result.analysisMetadata.claudeCallsMade).toBe(2);
    });

    it('tracks token usage for state analysis', async () => {
      const violation = makeStateViolation();

      mockMessagesCreate.mockResolvedValueOnce({
        content: [{ text: JSON.stringify(makeClaudeEnhancementResponse(1)) }],
        usage: { input_tokens: 400, output_tokens: 180 }
      });

      const result = await complianceAnalysisService.analyzeStateViolations([violation], {});
      expect(result.analysisMetadata.totalInputTokens).toBe(400);
      expect(result.analysisMetadata.totalOutputTokens).toBe(180);
    });

    it('works without caseContext', async () => {
      const result = await complianceAnalysisService.analyzeStateViolations(null);
      expect(result.enhancedViolations).toEqual([]);
    });
  });

  // ================================================================
  // generateLegalNarrative
  // ================================================================
  describe('generateLegalNarrative', () => {
    it('returns empty string when no violations provided', async () => {
      const result = await complianceAnalysisService.generateLegalNarrative([], {});
      expect(result).toBe('');
    });

    it('returns empty string for null violations and no state violations', async () => {
      const result = await complianceAnalysisService.generateLegalNarrative(null, {});
      expect(result).toBe('');
    });

    it('generates narrative for federal violations only', async () => {
      mockMessagesCreate.mockResolvedValueOnce({
        content: [{ text: '## Compliance Report\n\nSerious violations found.' }],
        usage: { input_tokens: 200, output_tokens: 100 }
      });

      const result = await complianceAnalysisService.generateLegalNarrative(
        [makeViolation()],
        { caseId: 'N1', documentTypes: ['closing_disclosure'] }
      );

      expect(result).toContain('Compliance Report');
    });

    it('generates narrative including state violations', async () => {
      mockMessagesCreate.mockResolvedValueOnce({
        content: [{ text: 'Federal and state violations found.' }],
        usage: { input_tokens: 200, output_tokens: 100 }
      });

      const result = await complianceAnalysisService.generateLegalNarrative(
        [makeViolation()],
        { caseId: 'N2' },
        [makeStateViolation()]
      );

      expect(result).toContain('violations found');
    });

    it('generates narrative for state violations only (empty federal)', async () => {
      mockMessagesCreate.mockResolvedValueOnce({
        content: [{ text: 'State-only narrative.' }],
        usage: { input_tokens: 150, output_tokens: 80 }
      });

      const result = await complianceAnalysisService.generateLegalNarrative(
        [],
        { caseId: 'N3' },
        [makeStateViolation()]
      );

      expect(result).toBe('State-only narrative.');
    });

    it('returns empty string on Claude API error', async () => {
      mockMessagesCreate.mockRejectedValueOnce(new Error('API error'));

      const result = await complianceAnalysisService.generateLegalNarrative(
        [makeViolation()],
        { caseId: 'N4' }
      );

      expect(result).toBe('');
    });
  });

  // ================================================================
  // _parseClaudeResponse
  // ================================================================
  describe('_parseClaudeResponse', () => {
    it('parses valid JSON directly', () => {
      const input = '{"enhancedViolations": []}';
      const result = complianceAnalysisService._parseClaudeResponse(input);
      expect(result).toEqual({ enhancedViolations: [] });
    });

    it('extracts JSON from markdown code fences', () => {
      const input = '```json\n{"enhancedViolations": [{"index": 0}]}\n```';
      const result = complianceAnalysisService._parseClaudeResponse(input);
      expect(result.enhancedViolations).toHaveLength(1);
    });

    it('extracts JSON from plain code fences (no json tag)', () => {
      const input = '```\n{"data": true}\n```';
      const result = complianceAnalysisService._parseClaudeResponse(input);
      expect(result.data).toBe(true);
    });

    it('returns parseError for empty string', () => {
      const result = complianceAnalysisService._parseClaudeResponse('');
      expect(result.parseError).toBe('Empty response');
    });

    it('returns parseError for null input', () => {
      const result = complianceAnalysisService._parseClaudeResponse(null);
      expect(result.parseError).toBe('Empty response');
    });

    it('returns parseError for undefined input', () => {
      const result = complianceAnalysisService._parseClaudeResponse(undefined);
      expect(result.parseError).toBe('Empty response');
    });

    it('returns parseError for whitespace-only string', () => {
      const result = complianceAnalysisService._parseClaudeResponse('   \n\t  ');
      expect(result.parseError).toBe('Empty response');
    });

    it('returns parseError for non-string input', () => {
      const result = complianceAnalysisService._parseClaudeResponse(12345);
      expect(result.parseError).toBe('Empty response');
    });

    it('returns parseError for completely invalid text', () => {
      const result = complianceAnalysisService._parseClaudeResponse('This is not JSON at all');
      expect(result.parseError).toBeDefined();
      expect(result.rawResponse).toBe('This is not JSON at all');
    });

    it('returns parseError when code fence contains invalid JSON', () => {
      const input = '```json\n{invalid json here}\n```';
      const result = complianceAnalysisService._parseClaudeResponse(input);
      expect(result.parseError).toBeDefined();
      expect(result.rawResponse).toBe(input);
    });
  });

  // ================================================================
  // _mergeEnhancements
  // ================================================================
  describe('_mergeEnhancements', () => {
    it('merges enhancements by index', () => {
      const violations = [makeViolation({ id: 'v1' }), makeViolation({ id: 'v2' })];
      const parsed = {
        enhancedViolations: [
          { index: 0, detailedLegalBasis: 'New basis 0', potentialPenalties: 'Penalty 0', recommendations: ['Fix 0'], regulatoryImplications: 'Implication 0' },
          { index: 1, detailedLegalBasis: 'New basis 1', potentialPenalties: 'Penalty 1', recommendations: ['Fix 1'], regulatoryImplications: 'Implication 1' }
        ]
      };

      const result = complianceAnalysisService._mergeEnhancements(violations, parsed);
      expect(result[0].legalBasis).toBe('New basis 0');
      expect(result[1].legalBasis).toBe('New basis 1');
      expect(result[0].recommendations).toEqual(['Fix 0']);
    });

    it('returns violations unchanged when parsed has no enhancedViolations', () => {
      const violations = [makeViolation()];
      const result = complianceAnalysisService._mergeEnhancements(violations, {});
      expect(result).toEqual(violations);
    });

    it('returns violations unchanged when enhancedViolations is not an array', () => {
      const violations = [makeViolation()];
      const result = complianceAnalysisService._mergeEnhancements(violations, { enhancedViolations: 'bad' });
      expect(result).toEqual(violations);
    });

    it('leaves unmatched violations unchanged', () => {
      const violations = [makeViolation({ id: 'v1' }), makeViolation({ id: 'v2' })];
      const parsed = {
        enhancedViolations: [
          { index: 0, detailedLegalBasis: 'Enhanced', recommendations: ['Fix'] }
        ]
      };

      const result = complianceAnalysisService._mergeEnhancements(violations, parsed);
      expect(result[0].legalBasis).toBe('Enhanced');
      expect(result[1].legalBasis).toBe('RESPA Section 10'); // unchanged
    });

    it('falls back to original values when enhancement fields are empty', () => {
      const violations = [makeViolation({ legalBasis: 'Original', potentialPenalties: 'Original penalty' })];
      const parsed = {
        enhancedViolations: [
          { index: 0, detailedLegalBasis: '', potentialPenalties: '', recommendations: null }
        ]
      };

      const result = complianceAnalysisService._mergeEnhancements(violations, parsed);
      // Empty strings are falsy, so fallback to original
      expect(result[0].legalBasis).toBe('Original');
      expect(result[0].potentialPenalties).toBe('Original penalty');
      expect(result[0].recommendations).toEqual([]);
    });
  });

  // ================================================================
  // _groupByStatute
  // ================================================================
  describe('_groupByStatute', () => {
    it('groups violations by statuteId', () => {
      const violations = [
        makeViolation({ statuteId: 'respa' }),
        makeViolation({ statuteId: 'tila' }),
        makeViolation({ statuteId: 'respa' })
      ];
      const grouped = complianceAnalysisService._groupByStatute(violations);
      expect(Object.keys(grouped)).toEqual(['respa', 'tila']);
      expect(grouped['respa']).toHaveLength(2);
      expect(grouped['tila']).toHaveLength(1);
    });

    it('uses "unknown" key for violations without statuteId', () => {
      const violations = [makeViolation({ statuteId: undefined })];
      const grouped = complianceAnalysisService._groupByStatute(violations);
      expect(grouped['unknown']).toHaveLength(1);
    });
  });

  // ================================================================
  // _createBatches
  // ================================================================
  describe('_createBatches', () => {
    it('creates single batch for small arrays', () => {
      const items = [1, 2, 3];
      const batches = complianceAnalysisService._createBatches(items, 10);
      expect(batches).toHaveLength(1);
      expect(batches[0]).toEqual([1, 2, 3]);
    });

    it('splits arrays into correct batch sizes', () => {
      const items = Array.from({ length: 25 }, (_, i) => i);
      const batches = complianceAnalysisService._createBatches(items, 10);
      expect(batches).toHaveLength(3);
      expect(batches[0]).toHaveLength(10);
      expect(batches[1]).toHaveLength(10);
      expect(batches[2]).toHaveLength(5);
    });

    it('handles empty array', () => {
      const batches = complianceAnalysisService._createBatches([], 10);
      expect(batches).toHaveLength(0);
    });
  });

  // ================================================================
  // _buildCompliancePrompt
  // ================================================================
  describe('_buildCompliancePrompt', () => {
    it('builds prompt with statute context', () => {
      const violations = [makeViolation()];
      const statute = {
        name: 'RESPA',
        citation: '12 U.S.C. § 2601',
        regulatoryBody: 'CFPB',
        sections: [
          { id: 'respa_s10', section: 'Section 10', title: 'Escrow', regulatoryReference: '12 CFR § 1024.17', requirements: [], penalties: '' }
        ]
      };
      const prompt = complianceAnalysisService._buildCompliancePrompt(violations, statute, { caseId: 'T1', documentTypes: ['statement'] });

      expect(prompt).toContain('RESPA');
      expect(prompt).toContain('CFPB');
      expect(prompt).toContain('12 U.S.C. § 2601');
      expect(prompt).toContain('T1');
    });

    it('handles undefined statute gracefully', () => {
      const violations = [makeViolation()];
      const prompt = complianceAnalysisService._buildCompliancePrompt(violations, undefined, {});

      expect(prompt).toContain('Unknown Statute');
      expect(prompt).toContain('Unknown Citation');
      expect(prompt).toContain('Unknown');
    });

    it('handles case context with no documentTypes', () => {
      const violations = [makeViolation()];
      const prompt = complianceAnalysisService._buildCompliancePrompt(violations, undefined, { caseId: 'T2' });
      expect(prompt).toContain('N/A');
    });
  });

  // ================================================================
  // _buildNarrativePrompt
  // ================================================================
  describe('_buildNarrativePrompt', () => {
    it('builds narrative prompt for federal violations only', () => {
      const prompt = complianceAnalysisService._buildNarrativePrompt(
        [makeViolation()],
        { caseId: 'NP1', documentTypes: ['mortgage_statement'] }
      );

      expect(prompt).toContain('NP1');
      expect(prompt).toContain('3-5 paragraph');
      expect(prompt).not.toContain('State Law Violations');
    });

    it('includes state violations section when provided', () => {
      const prompt = complianceAnalysisService._buildNarrativePrompt(
        [makeViolation()],
        { caseId: 'NP2' },
        [makeStateViolation()]
      );

      expect(prompt).toContain('State Law Violations');
      expect(prompt).toContain('4-6 paragraph');
      expect(prompt).toContain('CA');
      expect(prompt).toContain('State Law Analysis');
    });

    it('handles empty state violations array (no state section)', () => {
      const prompt = complianceAnalysisService._buildNarrativePrompt(
        [makeViolation()],
        {},
        []
      );

      expect(prompt).not.toContain('State Law Violations');
    });
  });

  // ================================================================
  // _buildStateViolationPrompt
  // ================================================================
  describe('_buildStateViolationPrompt', () => {
    it('builds state prompt with jurisdiction info', () => {
      const violations = [makeStateViolation()];
      const prompt = complianceAnalysisService._buildStateViolationPrompt(violations, { caseId: 'SP1' });

      expect(prompt).toContain('CA');
      expect(prompt).toContain('SP1');
      expect(prompt).toContain('state regulatory compliance attorney');
    });

    it('handles violations without jurisdiction', () => {
      const violations = [makeStateViolation({ jurisdiction: undefined })];
      const prompt = complianceAnalysisService._buildStateViolationPrompt(violations, {});

      expect(prompt).toContain('Unknown');
    });

    it('handles violations without statuteId or sectionId', () => {
      const violations = [makeStateViolation({ statuteId: undefined, sectionId: undefined, jurisdiction: 'CA' })];
      const prompt = complianceAnalysisService._buildStateViolationPrompt(violations, {});

      // Should not throw, should handle gracefully
      expect(prompt).toContain('CA');
    });

    it('collects statute info from taxonomy for known statutes', () => {
      const violations = [makeStateViolation({ statuteId: 'ca_hbor', sectionId: 'ca_hbor_dual_tracking', jurisdiction: 'CA' })];
      const prompt = complianceAnalysisService._buildStateViolationPrompt(violations, { caseId: 'SP2' });

      expect(prompt).toContain('California Homeowner Bill of Rights');
    });
  });
});
