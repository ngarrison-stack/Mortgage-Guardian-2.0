/**
 * Unit tests for CrossDocumentComparisonService
 *
 * Tests compareDocumentPair, prompt construction, response parsing, error
 * handling, comparison type routing, and result enrichment with a fully
 * mocked Anthropic SDK.
 */

// Must be hoisted above any require() — mocks the module-scope `new Anthropic()`
const mockMessagesCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate }
  }));
});

const crossDocumentComparisonService = require('../../services/crossDocumentComparisonService');

// ---------------------------------------------------------------------------
// Mock data helpers
// ---------------------------------------------------------------------------

function mockDocA(overrides = {}) {
  return {
    documentId: 'doc-001',
    documentType: 'servicing',
    documentSubtype: 'monthly_statement',
    extractedData: {
      amounts: { principalBalance: 245000, monthlyPayment: 1523.47, escrowBalance: 3421.00 },
      dates: { statementDate: '2024-01-15', paymentDueDate: '2024-02-01' },
      rates: { interestRate: 6.5 },
      identifiers: { loanNumber: '****1234', propertyAddress: '123 Main St' }
    },
    anomalies: [
      { field: 'monthlyPayment', type: 'calculation_error', severity: 'high', description: 'Payment exceeds expected P&I' }
    ],
    completeness: { score: 85 },
    ...overrides
  };
}

function mockDocB(overrides = {}) {
  return {
    documentId: 'doc-002',
    documentType: 'origination',
    documentSubtype: 'closing_disclosure',
    extractedData: {
      amounts: { loanAmount: 250000, monthlyPayment: 1498.23, cashToClose: 12500 },
      rates: { interestRate: 6.25, apr: 6.42 },
      identifiers: { loanNumber: '****1234', propertyAddress: '123 Main St' }
    },
    anomalies: [],
    completeness: { score: 92 },
    ...overrides
  };
}

function mockComparisonConfig(overrides = {}) {
  return {
    pairId: 'stmt-vs-closing',
    comparisonFields: ['rates', 'amounts'],
    discrepancyTypes: ['amount_mismatch', 'term_contradiction', 'calculation_error'],
    forensicSignificance: 'high',
    ...overrides
  };
}

function mockClaudeResponse(overrides = {}) {
  const base = {
    discrepancies: [
      {
        id: 'disc-001',
        type: 'amount_mismatch',
        severity: 'high',
        description: 'Interest rate on monthly statement (6.5%) differs from closing disclosure (6.25%). Unless an ARM adjustment occurred, this suggests an incorrect rate is being applied.',
        documentA: { field: 'interestRate', value: 6.5 },
        documentB: { field: 'interestRate', value: 6.25 },
        regulation: 'TILA Section 128',
        forensicNote: 'A 0.25% rate difference on a $245,000 balance results in approximately $51/month overcharge.'
      }
    ],
    timelineEvents: [
      {
        date: '2024-01-15',
        documentId: 'doc-001',
        documentType: 'servicing',
        event: 'Monthly statement issued showing 6.5% rate',
        significance: 'notable'
      }
    ],
    timelineViolations: [],
    comparisonSummary: 'Interest rate discrepancy detected between closing disclosure and current statement. The monthly payment is $25.24 higher than original terms suggest.'
  };

  const merged = { ...base, ...overrides };

  return {
    content: [{ text: JSON.stringify(merged) }],
    model: 'claude-sonnet-4-5-20250514',
    usage: { input_tokens: 2500, output_tokens: 1200 }
  };
}

// ============================================================================
// Tests
// ============================================================================
describe('CrossDocumentComparisonService', () => {
  beforeEach(() => {
    mockMessagesCreate.mockReset();
  });

  // ==========================================================================
  // compareDocumentPair - basic functionality
  // ==========================================================================
  describe('compareDocumentPair', () => {
    it('should call Anthropic API with correct system prompt', async () => {
      mockMessagesCreate.mockResolvedValue(mockClaudeResponse());

      await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(mockMessagesCreate).toHaveBeenCalledTimes(1);
      const callArgs = mockMessagesCreate.mock.calls[0][0];
      expect(callArgs.system).toContain('forensic mortgage document analyst');
      expect(callArgs.system).toContain('major law firm');
      expect(callArgs.system).toContain('valid JSON');
    });

    it('should include both documents extractedData in user prompt', async () => {
      mockMessagesCreate.mockResolvedValue(mockClaudeResponse());

      await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      const userPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      // DocA data
      expect(userPrompt).toContain('doc-001');
      expect(userPrompt).toContain('servicing/monthly_statement');
      // DocB data
      expect(userPrompt).toContain('doc-002');
      expect(userPrompt).toContain('origination/closing_disclosure');
    });

    it('should include comparison-type-specific instructions', async () => {
      mockMessagesCreate.mockResolvedValue(mockClaudeResponse());

      await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig({ pairId: 'stmt-vs-closing' })
      );

      const userPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(userPrompt).toContain('closing disclosure');
      expect(userPrompt).toContain('ARM');
    });

    it('should parse valid JSON response into structured output', async () => {
      mockMessagesCreate.mockResolvedValue(mockClaudeResponse());

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.pairId).toBe('stmt-vs-closing');
      expect(result.documentA.documentId).toBe('doc-001');
      expect(result.documentB.documentId).toBe('doc-002');
      expect(result.discrepancies).toHaveLength(1);
      expect(result.discrepancies[0].type).toBe('amount_mismatch');
      expect(result.timelineEvents).toHaveLength(1);
      expect(result.comparisonSummary).toContain('Interest rate discrepancy');
      expect(result.error).toBeUndefined();
    });

    it('should handle markdown code fence wrapped JSON responses', async () => {
      const data = {
        discrepancies: [{ id: 'disc-001', type: 'amount_mismatch', severity: 'high', description: 'Rate mismatch', documentA: { field: 'rate', value: 6.5 }, documentB: { field: 'rate', value: 6.25 } }],
        timelineEvents: [],
        timelineViolations: [],
        comparisonSummary: 'Rate mismatch found.'
      };
      const fencedResponse = '```json\n' + JSON.stringify(data) + '\n```';
      mockMessagesCreate.mockResolvedValue({
        content: [{ text: fencedResponse }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 1000, output_tokens: 500 }
      });

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.discrepancies).toHaveLength(1);
      expect(result.comparisonSummary).toBe('Rate mismatch found.');
      expect(result.error).toBeUndefined();
    });

    it('should return error object for Anthropic API failures (do not throw)', async () => {
      const apiError = new Error('API rate limit exceeded');
      apiError.status = 429;
      mockMessagesCreate.mockRejectedValue(apiError);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.error).toBe(true);
      expect(result.errorMessage).toBe('API rate limit exceeded');
      expect(result.pairId).toBe('stmt-vs-closing');
      expect(result.discrepancies).toHaveLength(0);
    });

    it('should return error object for JSON parse failures with rawResponse', async () => {
      mockMessagesCreate.mockResolvedValue({
        content: [{ text: 'This is not valid JSON at all.' }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 1000, output_tokens: 50 }
      });

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.error).toBe(true);
      expect(result.errorMessage).toBe('Failed to parse comparison response');
      expect(result.rawResponse).toBe('This is not valid JSON at all.');
    });

    it('should return error object when docA is null/missing', async () => {
      const result = await crossDocumentComparisonService.compareDocumentPair(
        null, mockDocB(), mockComparisonConfig()
      );

      expect(result.error).toBe(true);
      expect(result.errorMessage).toBe('Missing document data');
      expect(mockMessagesCreate).not.toHaveBeenCalled();
    });

    it('should return error object when docB is null/missing', async () => {
      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), null, mockComparisonConfig()
      );

      expect(result.error).toBe(true);
      expect(result.errorMessage).toBe('Missing document data');
    });

    it('should return error object when extractedData is empty on both documents', async () => {
      const emptyDocA = mockDocA({ extractedData: {} });
      const emptyDocB = mockDocB({ extractedData: {} });

      const result = await crossDocumentComparisonService.compareDocumentPair(
        emptyDocA, emptyDocB, mockComparisonConfig()
      );

      expect(result.error).toBe(true);
      expect(result.errorMessage).toBe('Both documents have empty extracted data');
      expect(mockMessagesCreate).not.toHaveBeenCalled();
    });

    it('should include document anomalies as context in prompt', async () => {
      mockMessagesCreate.mockResolvedValue(mockClaudeResponse());
      const docA = mockDocA({
        anomalies: [
          { field: 'escrowBalance', type: 'unusual_value', severity: 'medium', description: 'Escrow seems high' }
        ]
      });

      await crossDocumentComparisonService.compareDocumentPair(
        docA, mockDocB(), mockComparisonConfig()
      );

      const userPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(userPrompt).toContain('Known Anomalies');
      expect(userPrompt).toContain('escrowBalance');
      expect(userPrompt).toContain('Escrow seems high');
    });

    it('should use correct model, max_tokens, and temperature', async () => {
      mockMessagesCreate.mockResolvedValue(mockClaudeResponse());

      await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      const callArgs = mockMessagesCreate.mock.calls[0][0];
      expect(callArgs.model).toBe('claude-sonnet-4-5-20250514');
      expect(callArgs.max_tokens).toBe(4096);
      expect(callArgs.temperature).toBe(0.1);
    });

    it('should return error when comparisonConfig is missing', async () => {
      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), null
      );

      expect(result.error).toBe(true);
      expect(result.errorMessage).toBe('Missing comparison configuration');
      expect(result.pairId).toBe('unknown');
    });

    it('should proceed when only one document has extractedData', async () => {
      mockMessagesCreate.mockResolvedValue(mockClaudeResponse({ discrepancies: [], comparisonSummary: 'Limited comparison.' }));
      const emptyDocB = mockDocB({ extractedData: {} });

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), emptyDocB, mockComparisonConfig()
      );

      // Should still call Claude — one doc has data
      expect(mockMessagesCreate).toHaveBeenCalledTimes(1);
      expect(result.error).toBeUndefined();
    });
  });

  // ==========================================================================
  // comparison instructions
  // ==========================================================================
  describe('comparison instructions', () => {
    it('should return stmt-vs-stmt instructions for matching pair ID', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('stmt-vs-stmt');
      expect(instructions).toContain('balance progression');
      expect(instructions).toContain('principal balance');
      expect(instructions).toContain('escrow balance trajectory');
    });

    it('should return closing-vs-note instructions for matching pair ID', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('closing-vs-note');
      expect(instructions).toContain('MUST match exactly');
      expect(instructions).toContain('Loan amount must be identical');
      expect(instructions).toContain('foundational origination documents');
    });

    it('should return stmt-vs-paymenthistory instructions', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('stmt-vs-paymenthistory');
      expect(instructions).toContain('payment application accuracy');
      expect(instructions).toContain('phantom late fees');
    });

    it('should return stmt-vs-escrow instructions', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('stmt-vs-escrow');
      expect(instructions).toContain('escrow balance tracking');
      expect(instructions).toContain('RESPA');
      expect(instructions).toContain('1/6 of annual disbursements');
    });

    it('should return stmt-vs-modification instructions', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('stmt-vs-modification');
      expect(instructions).toContain('modification terms');
      expect(instructions).toContain('effective date');
    });

    it('should return stmt-vs-armadjust instructions', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('stmt-vs-armadjust');
      expect(instructions).toContain('ARM rate adjustment');
      expect(instructions).toContain('adjustment notice');
    });

    it('should return correspondence-vs-stmt instructions', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('correspondence-vs-stmt');
      expect(instructions).toContain('servicer correspondence');
      expect(instructions).toContain('misrepresented account status');
    });

    it('should return legal-vs-stmt instructions', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('legal-vs-stmt');
      expect(instructions).toContain('legal proceedings');
      expect(instructions).toContain('Inflated amounts');
    });

    it('should return default instructions for unknown pair ID', () => {
      const instructions = crossDocumentComparisonService._getComparisonInstructions('totally-unknown-pair');
      expect(instructions).toContain('general forensic comparison');
      expect(instructions).toContain('shared fields');
    });

    it('should include forensic focus areas specific to each pair type', async () => {
      mockMessagesCreate.mockResolvedValue(mockClaudeResponse());

      // stmt-vs-stmt focuses on balance progression
      await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(),
        mockDocA({ documentId: 'doc-003' }),
        mockComparisonConfig({ pairId: 'stmt-vs-stmt' })
      );

      const prompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(prompt).toContain('balance progression');
      expect(prompt).toContain('fee changes');
    });
  });

  // ==========================================================================
  // response enrichment
  // ==========================================================================
  describe('response enrichment', () => {
    it('should assign discrepancy IDs if Claude omits them', async () => {
      const response = mockClaudeResponse({
        discrepancies: [
          { type: 'amount_mismatch', severity: 'high', description: 'Rate mismatch', documentA: { field: 'rate', value: 6.5 }, documentB: { field: 'rate', value: 6.25 } },
          { type: 'fee_irregularity', severity: 'medium', description: 'Fee change', documentA: { field: 'fees', value: 50 }, documentB: { field: 'fees', value: 100 } }
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.discrepancies[0].id).toBe('disc-001');
      expect(result.discrepancies[1].id).toBe('disc-002');
    });

    it('should validate discrepancy type is from allowed enum', async () => {
      const response = mockClaudeResponse({
        discrepancies: [
          { id: 'disc-001', type: 'invented_type', severity: 'high', description: 'Some issue', documentA: { field: 'x', value: 1 }, documentB: { field: 'x', value: 2 } }
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      // Invalid type should be normalized to 'amount_mismatch' default
      expect(result.discrepancies[0].type).toBe('amount_mismatch');
    });

    it('should validate severity is from allowed enum', async () => {
      const response = mockClaudeResponse({
        discrepancies: [
          { id: 'disc-001', type: 'amount_mismatch', severity: 'extreme', description: 'Bad issue', documentA: { field: 'x', value: 1 }, documentB: { field: 'x', value: 2 } }
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      // Invalid severity should be normalized to 'medium' default
      expect(result.discrepancies[0].severity).toBe('medium');
    });

    it('should handle missing optional fields gracefully (regulation, forensicNote)', async () => {
      const response = mockClaudeResponse({
        discrepancies: [
          { id: 'disc-001', type: 'amount_mismatch', severity: 'high', description: 'Rate diff', documentA: { field: 'rate', value: 6.5 }, documentB: { field: 'rate', value: 6.25 } }
          // No regulation or forensicNote
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.discrepancies[0].regulation).toBeUndefined();
      expect(result.discrepancies[0].forensicNote).toBeUndefined();
      expect(result.discrepancies[0].type).toBe('amount_mismatch');
    });

    it('should handle missing discrepancy description', async () => {
      const response = mockClaudeResponse({
        discrepancies: [
          { id: 'disc-001', type: 'amount_mismatch', severity: 'high', documentA: { field: 'rate', value: 6.5 }, documentB: { field: 'rate', value: 6.25 } }
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.discrepancies[0].description).toBe('Discrepancy detected between documents');
    });

    it('should handle missing documentA/documentB refs in discrepancy', async () => {
      const response = mockClaudeResponse({
        discrepancies: [
          { id: 'disc-001', type: 'amount_mismatch', severity: 'high', description: 'Some issue' }
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.discrepancies[0].documentA).toEqual({ field: 'unknown', value: null });
      expect(result.discrepancies[0].documentB).toEqual({ field: 'unknown', value: null });
    });

    it('should enrich timeline violations with defaults for missing fields', async () => {
      const response = mockClaudeResponse({
        timelineViolations: [
          { description: 'Late notice violation' }
          // Missing severity and relatedDocuments
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.timelineViolations[0].severity).toBe('high');
      expect(result.timelineViolations[0].relatedDocuments).toEqual(['doc-001', 'doc-002']);
    });

    it('should handle empty arrays from Claude gracefully', async () => {
      const response = mockClaudeResponse({
        discrepancies: [],
        timelineEvents: [],
        timelineViolations: [],
        comparisonSummary: 'No issues found.'
      });
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.discrepancies).toHaveLength(0);
      expect(result.timelineEvents).toHaveLength(0);
      expect(result.timelineViolations).toHaveLength(0);
      expect(result.comparisonSummary).toBe('No issues found.');
    });

    it('should handle missing arrays from Claude response', async () => {
      // Claude returns object without expected arrays
      const response = {
        content: [{ text: JSON.stringify({ comparisonSummary: 'Incomplete response.' }) }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 1000, output_tokens: 100 }
      };
      mockMessagesCreate.mockResolvedValue(response);

      const result = await crossDocumentComparisonService.compareDocumentPair(
        mockDocA(), mockDocB(), mockComparisonConfig()
      );

      expect(result.discrepancies).toHaveLength(0);
      expect(result.timelineEvents).toHaveLength(0);
      expect(result.timelineViolations).toHaveLength(0);
      expect(result.comparisonSummary).toBe('Incomplete response.');
    });
  });

  // ==========================================================================
  // _parseResponse (direct unit tests)
  // ==========================================================================
  describe('_parseResponse', () => {
    it('should parse valid JSON correctly', () => {
      const data = { discrepancies: [], comparisonSummary: 'OK' };
      const result = crossDocumentComparisonService._parseResponse(JSON.stringify(data));

      expect(result.discrepancies).toEqual([]);
      expect(result.comparisonSummary).toBe('OK');
    });

    it('should extract JSON from markdown code fences', () => {
      const data = { discrepancies: [{ id: 'disc-001' }], comparisonSummary: 'Found issue' };
      const wrapped = '```json\n' + JSON.stringify(data) + '\n```';

      const result = crossDocumentComparisonService._parseResponse(wrapped);

      expect(result.discrepancies).toHaveLength(1);
      expect(result.discrepancies[0].id).toBe('disc-001');
    });

    it('should return rawResponse and parseError for non-JSON text', () => {
      const result = crossDocumentComparisonService._parseResponse('Not JSON.');

      expect(result.rawResponse).toBe('Not JSON.');
      expect(result.parseError).toBeDefined();
    });

    it('should handle code fences without json language tag', () => {
      const data = { discrepancies: [], comparisonSummary: 'Clean' };
      const wrapped = '```\n' + JSON.stringify(data) + '\n```';

      const result = crossDocumentComparisonService._parseResponse(wrapped);

      expect(result.comparisonSummary).toBe('Clean');
    });
  });

  // ==========================================================================
  // _filterExtractedData (direct unit tests)
  // ==========================================================================
  describe('_filterExtractedData', () => {
    it('should filter to only requested comparison fields', () => {
      const extractedData = {
        amounts: { principalBalance: 245000 },
        rates: { interestRate: 6.5 },
        dates: { statementDate: '2024-01-15' },
        identifiers: { loanNumber: '****1234' }
      };

      const result = crossDocumentComparisonService._filterExtractedData(
        extractedData, ['amounts', 'rates']
      );

      expect(result.amounts).toBeDefined();
      expect(result.rates).toBeDefined();
      expect(result.identifiers).toBeDefined(); // Always included
      expect(result.dates).toBeUndefined(); // Not in comparisonFields
    });

    it('should return empty object for null extractedData', () => {
      const result = crossDocumentComparisonService._filterExtractedData(null, ['amounts']);
      expect(result).toEqual({});
    });

    it('should return extractedData as-is for null comparisonFields', () => {
      const data = { amounts: { x: 1 } };
      const result = crossDocumentComparisonService._filterExtractedData(data, null);
      expect(result).toEqual(data);
    });
  });

  // ==========================================================================
  // _buildDocRef (direct unit tests)
  // ==========================================================================
  describe('_buildDocRef', () => {
    it('should build reference from valid document', () => {
      const ref = crossDocumentComparisonService._buildDocRef(mockDocA());
      expect(ref).toEqual({
        documentId: 'doc-001',
        documentType: 'servicing',
        documentSubtype: 'monthly_statement'
      });
    });

    it('should return unknowns for null document', () => {
      const ref = crossDocumentComparisonService._buildDocRef(null);
      expect(ref).toEqual({
        documentId: 'unknown',
        documentType: 'unknown',
        documentSubtype: 'unknown'
      });
    });

    it('should handle document with missing fields', () => {
      const ref = crossDocumentComparisonService._buildDocRef({ documentId: 'doc-999' });
      expect(ref.documentId).toBe('doc-999');
      expect(ref.documentType).toBe('unknown');
      expect(ref.documentSubtype).toBe('unknown');
    });
  });
});
