/**
 * Unit tests for ClassificationService (services/classificationService.js)
 *
 * Tests classifyDocument, _buildClassificationPrompt, _parseClassificationResponse,
 * getValidTypes, and getSubtypes with a fully mocked Anthropic SDK.
 */

// Must be hoisted above any require() — mocks the module-scope `new Anthropic()`
const mockMessagesCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate }
  }));
});

const classificationService = require('../../services/classificationService');
const { DOCUMENT_TAXONOMY } = require('../../services/classificationService');

// ============================================================
// classifyDocument
// ============================================================
describe('ClassificationService', () => {
  describe('classifyDocument', () => {
    const sampleDocumentText = `
      MORTGAGE STATEMENT
      Account Number: ****5678
      Statement Date: January 15, 2024
      Borrower: John Smith
      Property: 123 Main St, Springfield, IL 62701
      Servicer: Wells Fargo Home Mortgage

      Principal Balance: $245,000.00
      Monthly Payment: $1,432.56
      Escrow Balance: $3,892.30
      Next Payment Due: February 15, 2024
    `;

    const mockClassificationResponse = {
      classificationType: 'servicing',
      classificationSubtype: 'monthly_statement',
      confidence: 0.95,
      extractedMetadata: {
        dates: ['2024-01-15', '2024-02-15'],
        amounts: ['$245,000.00', '$1,432.56', '$3,892.30'],
        parties: ['Wells Fargo Home Mortgage', 'John Smith'],
        accountNumbers: ['****5678'],
        propertyAddress: '123 Main St, Springfield, IL 62701'
      },
      reasoning: 'Document contains monthly mortgage statement with payment details, escrow balance, and next payment due date typical of servicing statements.'
    };

    const mockApiResponse = {
      content: [{ text: JSON.stringify(mockClassificationResponse) }],
      model: 'claude-sonnet-4-5-20250514',
      usage: { input_tokens: 500, output_tokens: 200 },
      stop_reason: 'end_turn'
    };

    beforeEach(() => {
      mockMessagesCreate.mockReset();
    });

    // Test 1: Successful classification
    it('returns structured classification result on success', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      const result = await classificationService.classifyDocument(sampleDocumentText);

      expect(result).toEqual(expect.objectContaining(mockClassificationResponse));
      expect(result.classificationType).toBe('servicing');
      expect(result.classificationSubtype).toBe('monthly_statement');
      expect(result.confidence).toBe(0.95);
      expect(result.extractedMetadata).toBeDefined();
      expect(result.extractedMetadata.dates).toHaveLength(2);
      expect(result.extractedMetadata.parties).toContain('John Smith');
      expect(result.reasoning).toBeDefined();
    });

    it('calls Claude with correct model and parameters', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      await classificationService.classifyDocument(sampleDocumentText);

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          model: 'claude-sonnet-4-5-20250514',
          max_tokens: 2048,
          temperature: 0.1,
          messages: [
            {
              role: 'user',
              content: expect.stringContaining('forensic mortgage document classifier')
            }
          ]
        })
      );
    });

    // Test 2: Classification with existing type hint
    it('includes existing type hint in prompt when provided', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      await classificationService.classifyDocument(sampleDocumentText, {
        existingType: 'mortgage_statement'
      });

      const calledPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(calledPrompt).toContain('mortgage_statement');
      expect(calledPrompt).toContain('uploader suggested');
      expect(calledPrompt).toContain('starting point but override');
      expect(calledPrompt).not.toContain('Classify independently');
    });

    it('includes classify independently when no hint provided', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      await classificationService.classifyDocument(sampleDocumentText);

      const calledPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(calledPrompt).toContain('Classify independently');
      expect(calledPrompt).not.toContain('uploader suggested');
    });

    // Test 3: Unknown document
    it('handles unknown document classification gracefully', async () => {
      const unknownResponse = {
        classificationType: 'unknown',
        classificationSubtype: 'unclassified',
        confidence: 0.3,
        extractedMetadata: {
          dates: [],
          amounts: [],
          parties: [],
          accountNumbers: [],
          propertyAddress: null
        },
        reasoning: 'Document does not match any known mortgage document type.'
      };

      mockMessagesCreate.mockResolvedValue({
        content: [{ text: JSON.stringify(unknownResponse) }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 200, output_tokens: 100 },
        stop_reason: 'end_turn'
      });

      const result = await classificationService.classifyDocument('Random unrelated text that is not a mortgage document.');

      expect(result.classificationType).toBe('unknown');
      expect(result.classificationSubtype).toBe('unclassified');
      expect(result.confidence).toBe(0.3);
    });

    // Test 7: API error handling
    it('throws and logs error when Claude API fails', async () => {
      const apiError = new Error('API rate limit exceeded');
      apiError.status = 429;
      mockMessagesCreate.mockRejectedValue(apiError);

      await expect(
        classificationService.classifyDocument(sampleDocumentText)
      ).rejects.toThrow('API rate limit exceeded');
    });

    it('throws on network error', async () => {
      mockMessagesCreate.mockRejectedValue(new Error('Network error'));

      await expect(
        classificationService.classifyDocument(sampleDocumentText)
      ).rejects.toThrow('Network error');
    });
  });

  // ============================================================
  // _buildClassificationPrompt
  // ============================================================
  describe('_buildClassificationPrompt', () => {
    const sampleText = 'Sample mortgage document text.';

    it('includes forensic classifier system context', () => {
      const prompt = classificationService._buildClassificationPrompt(sampleText);

      expect(prompt).toContain('forensic mortgage document classifier');
      expect(prompt).toContain('litigation support');
    });

    it('includes the full document taxonomy', () => {
      const prompt = classificationService._buildClassificationPrompt(sampleText);

      expect(prompt).toContain('origination');
      expect(prompt).toContain('servicing');
      expect(prompt).toContain('correspondence');
      expect(prompt).toContain('legal');
      expect(prompt).toContain('financial');
      expect(prompt).toContain('regulatory');
    });

    it('includes the document text', () => {
      const uniqueText = 'UNIQUE_DOCUMENT_MARKER_67890';
      const prompt = classificationService._buildClassificationPrompt(uniqueText);

      expect(prompt).toContain(uniqueText);
    });

    it('includes JSON response format instructions', () => {
      const prompt = classificationService._buildClassificationPrompt(sampleText);

      expect(prompt).toContain('classificationType');
      expect(prompt).toContain('classificationSubtype');
      expect(prompt).toContain('confidence');
      expect(prompt).toContain('extractedMetadata');
      expect(prompt).toContain('reasoning');
    });

    it('includes existing type hint when provided', () => {
      const prompt = classificationService._buildClassificationPrompt(sampleText, 'escrow_statement');

      expect(prompt).toContain('escrow_statement');
      expect(prompt).toContain('uploader suggested');
      expect(prompt).toContain('starting point but override');
      expect(prompt).not.toContain('Classify independently');
    });

    it('includes classify independently when no hint provided', () => {
      const prompt = classificationService._buildClassificationPrompt(sampleText);

      expect(prompt).toContain('Classify independently');
      expect(prompt).not.toContain('uploader suggested');
    });

    it('includes unknown/unclassified fallback instruction', () => {
      const prompt = classificationService._buildClassificationPrompt(sampleText);

      expect(prompt).toContain('unknown');
      expect(prompt).toContain('unclassified');
    });
  });

  // ============================================================
  // _parseClassificationResponse
  // ============================================================
  describe('_parseClassificationResponse', () => {
    // Test 4: Malformed Claude response
    it('returns rawResponse and parseError for non-JSON text', () => {
      const result = classificationService._parseClassificationResponse(
        'This is not valid JSON at all.'
      );

      expect(result.rawResponse).toBe('This is not valid JSON at all.');
      expect(result.parseError).toBeDefined();
      expect(typeof result.parseError).toBe('string');
    });

    it('parses valid JSON response correctly', () => {
      const validResponse = {
        classificationType: 'origination',
        classificationSubtype: 'promissory_note',
        confidence: 0.88,
        extractedMetadata: { dates: ['2024-03-01'] },
        reasoning: 'Contains promissory note language.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(validResponse)
      );

      expect(result.classificationType).toBe('origination');
      expect(result.classificationSubtype).toBe('promissory_note');
      expect(result.confidence).toBe(0.88);
    });

    // Test 5: Confidence clamping
    it('clamps confidence > 1 down to 1', () => {
      const response = {
        classificationType: 'servicing',
        classificationSubtype: 'monthly_statement',
        confidence: 1.5,
        extractedMetadata: {},
        reasoning: 'High confidence.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidence).toBe(1);
    });

    it('clamps confidence < 0 up to 0', () => {
      const response = {
        classificationType: 'servicing',
        classificationSubtype: 'monthly_statement',
        confidence: -0.3,
        extractedMetadata: {},
        reasoning: 'Low confidence.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidence).toBe(0);
    });

    it('does not modify confidence within valid range', () => {
      const response = {
        classificationType: 'legal',
        classificationSubtype: 'court_order',
        confidence: 0.75,
        extractedMetadata: {},
        reasoning: 'Normal confidence.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidence).toBe(0.75);
    });

    // Taxonomy validation
    it('resets invalid classificationType to unknown', () => {
      const response = {
        classificationType: 'nonexistent_category',
        classificationSubtype: 'something',
        confidence: 0.8,
        extractedMetadata: {},
        reasoning: 'Invalid type.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.classificationType).toBe('unknown');
      expect(result.classificationSubtype).toBe('unclassified');
    });

    it('allows unknown classificationType to pass through', () => {
      const response = {
        classificationType: 'unknown',
        classificationSubtype: 'unclassified',
        confidence: 0.2,
        extractedMetadata: {},
        reasoning: 'Unrecognized document.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.classificationType).toBe('unknown');
      expect(result.classificationSubtype).toBe('unclassified');
    });

    it('allows valid taxonomy types to pass through', () => {
      const validTypes = ['origination', 'servicing', 'correspondence', 'legal', 'financial', 'regulatory'];

      validTypes.forEach(type => {
        const response = {
          classificationType: type,
          classificationSubtype: DOCUMENT_TAXONOMY[type].subtypes[0],
          confidence: 0.9,
          extractedMetadata: {},
          reasoning: `Valid ${type} document.`
        };

        const result = classificationService._parseClassificationResponse(
          JSON.stringify(response)
        );

        expect(result.classificationType).toBe(type);
      });
    });
  });

  // ============================================================
  // Confidence level gating
  // ============================================================
  describe('confidence level assignment', () => {
    it('assigns high confidenceLevel when confidence >= 0.7', () => {
      const response = {
        classificationType: 'servicing',
        classificationSubtype: 'monthly_statement',
        confidence: 0.85,
        extractedMetadata: {},
        reasoning: 'High confidence.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidenceLevel).toBe('high');
    });

    it('assigns high confidenceLevel at exactly 0.7 threshold', () => {
      const response = {
        classificationType: 'servicing',
        classificationSubtype: 'monthly_statement',
        confidence: 0.7,
        extractedMetadata: {},
        reasoning: 'At threshold.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidenceLevel).toBe('high');
    });

    it('assigns medium confidenceLevel when confidence between 0.4 and 0.7', () => {
      const response = {
        classificationType: 'servicing',
        classificationSubtype: 'monthly_statement',
        confidence: 0.55,
        extractedMetadata: {},
        reasoning: 'Medium confidence.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidenceLevel).toBe('medium');
    });

    it('assigns medium confidenceLevel at exactly 0.4 threshold', () => {
      const response = {
        classificationType: 'servicing',
        classificationSubtype: 'monthly_statement',
        confidence: 0.4,
        extractedMetadata: {},
        reasoning: 'At low threshold.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidenceLevel).toBe('medium');
    });

    it('assigns low confidenceLevel when confidence < 0.4', () => {
      const response = {
        classificationType: 'unknown',
        classificationSubtype: 'unclassified',
        confidence: 0.2,
        extractedMetadata: {},
        reasoning: 'Low confidence.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidenceLevel).toBe('low');
    });

    it('assigns low confidenceLevel at confidence 0', () => {
      const response = {
        classificationType: 'unknown',
        classificationSubtype: 'unclassified',
        confidence: 0,
        extractedMetadata: {},
        reasoning: 'Zero confidence.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidenceLevel).toBe('low');
    });

    it('does not set confidenceLevel when confidence is not a number', () => {
      const response = {
        classificationType: 'servicing',
        classificationSubtype: 'monthly_statement',
        extractedMetadata: {},
        reasoning: 'No confidence provided.'
      };

      const result = classificationService._parseClassificationResponse(
        JSON.stringify(response)
      );

      expect(result.confidenceLevel).toBeUndefined();
    });

    it('returns confidenceLevel from classifyDocument', async () => {
      mockMessagesCreate.mockResolvedValue({
        content: [{ text: JSON.stringify({
          classificationType: 'servicing',
          classificationSubtype: 'monthly_statement',
          confidence: 0.95,
          extractedMetadata: {},
          reasoning: 'Test.'
        }) }]
      });

      const result = await classificationService.classifyDocument('test text');
      expect(result.confidenceLevel).toBe('high');
    });
  });

  // ============================================================
  // getValidTypes / getSubtypes — Test 6: Taxonomy validation
  // ============================================================
  describe('getValidTypes', () => {
    it('returns all 6 taxonomy categories', () => {
      const types = classificationService.getValidTypes();

      expect(Object.keys(types)).toHaveLength(6);
      expect(Object.keys(types)).toEqual(
        expect.arrayContaining([
          'origination', 'servicing', 'correspondence',
          'legal', 'financial', 'regulatory'
        ])
      );
    });

    it('each category has a label and subtypes array', () => {
      const types = classificationService.getValidTypes();

      Object.values(types).forEach(category => {
        expect(category).toHaveProperty('label');
        expect(category).toHaveProperty('subtypes');
        expect(Array.isArray(category.subtypes)).toBe(true);
        expect(category.subtypes.length).toBeGreaterThan(0);
      });
    });
  });

  describe('getSubtypes', () => {
    it('returns subtypes array for origination', () => {
      const subtypes = classificationService.getSubtypes('origination');

      expect(Array.isArray(subtypes)).toBe(true);
      expect(subtypes).toContain('loan_application_1003');
      expect(subtypes).toContain('promissory_note');
      expect(subtypes).toContain('closing_disclosure');
      expect(subtypes.length).toBe(12);
    });

    it('returns subtypes array for servicing', () => {
      const subtypes = classificationService.getSubtypes('servicing');

      expect(Array.isArray(subtypes)).toBe(true);
      expect(subtypes).toContain('monthly_statement');
      expect(subtypes).toContain('escrow_analysis');
      expect(subtypes.length).toBe(9);
    });

    it('returns null for nonexistent type', () => {
      const subtypes = classificationService.getSubtypes('nonexistent');
      expect(subtypes).toBeNull();
    });

    it('returns null for undefined type', () => {
      const subtypes = classificationService.getSubtypes(undefined);
      expect(subtypes).toBeNull();
    });

    it('returns correct subtypes for all 6 categories', () => {
      const expectedCounts = {
        origination: 12,
        servicing: 9,
        correspondence: 11,
        legal: 10,
        financial: 6,
        regulatory: 6
      };

      Object.entries(expectedCounts).forEach(([type, count]) => {
        const subtypes = classificationService.getSubtypes(type);
        expect(subtypes).toHaveLength(count);
      });
    });
  });

  // ============================================================
  // DOCUMENT_TAXONOMY export
  // ============================================================
  describe('DOCUMENT_TAXONOMY export', () => {
    it('is exported as a module property', () => {
      expect(DOCUMENT_TAXONOMY).toBeDefined();
      expect(typeof DOCUMENT_TAXONOMY).toBe('object');
    });

    it('has 6 categories', () => {
      expect(Object.keys(DOCUMENT_TAXONOMY)).toHaveLength(6);
    });

    it('has 54+ total subtypes across all categories', () => {
      const totalSubtypes = Object.values(DOCUMENT_TAXONOMY)
        .reduce((sum, cat) => sum + cat.subtypes.length, 0);

      expect(totalSubtypes).toBeGreaterThanOrEqual(54);
    });

    it('all subtypes are unique strings', () => {
      const allSubtypes = Object.values(DOCUMENT_TAXONOMY)
        .flatMap(cat => cat.subtypes);

      const uniqueSubtypes = new Set(allSubtypes);
      expect(uniqueSubtypes.size).toBe(allSubtypes.length);
    });
  });
});
