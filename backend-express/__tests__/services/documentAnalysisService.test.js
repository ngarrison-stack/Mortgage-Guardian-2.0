/**
 * Unit tests for DocumentAnalysisService (services/documentAnalysisService.js)
 *
 * Tests analyzeDocument, prompt engineering, completeness scoring, anomaly
 * handling, error handling, and configuration with a fully mocked Anthropic SDK.
 */

// Must be hoisted above any require() — mocks the module-scope `new Anthropic()`
const mockMessagesCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate }
  }));
});

const documentAnalysisService = require('../../services/documentAnalysisService');

// ---------------------------------------------------------------------------
// Mock data helpers
// ---------------------------------------------------------------------------

function createMockAnalysisResponse(overrides = {}) {
  const base = {
    extractedData: {
      dates: { statementDate: '2024-01-15', paymentDueDate: '2024-02-01' },
      amounts: { principalBalance: 245000, monthlyPayment: 1523.47, escrowBalance: 3421.00 },
      rates: { interestRate: 6.5 },
      parties: { borrower: 'John Smith', servicer: 'Wells Fargo' },
      identifiers: { loanNumber: '****1234', propertyAddress: '123 Main St' },
      terms: { loanType: 'fixed' },
      custom: {}
    },
    anomalies: [
      {
        field: 'monthlyPayment',
        type: 'calculation_error',
        severity: 'high',
        description: 'Payment amount does not match P&I calculation',
        expectedValue: 1498.23,
        actualValue: 1523.47
      }
    ],
    summary: {
      overview: 'Monthly mortgage statement with payment calculation discrepancy.',
      keyFindings: ['Payment amount exceeds expected P&I by $25.24'],
      riskLevel: 'medium',
      recommendations: ['Request payment breakdown from servicer']
    }
  };

  // Deep merge overrides
  const merged = { ...base, ...overrides };
  if (overrides.extractedData) {
    merged.extractedData = { ...base.extractedData, ...overrides.extractedData };
  }
  if (overrides.summary) {
    merged.summary = { ...base.summary, ...overrides.summary };
  }

  return {
    content: [{ text: JSON.stringify(merged) }],
    model: 'claude-sonnet-4-5-20250514',
    usage: { input_tokens: 1500, output_tokens: 800 }
  };
}

function createClassification(type = 'servicing', subtype = 'monthly_statement', confidence = 0.95) {
  return {
    classificationType: type,
    classificationSubtype: subtype,
    confidence,
    extractedMetadata: {}
  };
}

const sampleDocumentText = `
  MORTGAGE STATEMENT
  Account Number: ****5678
  Statement Date: January 15, 2024
  Borrower: John Smith
  Property: 123 Main St, Springfield, IL 62701
  Servicer: Wells Fargo Home Mortgage

  Principal Balance: $245,000.00
  Monthly Payment: $1,523.47
  Interest Rate: 6.500%
  Escrow Balance: $3,421.00
  Next Payment Due: February 1, 2024
`;

// ============================================================================
// Tests
// ============================================================================
describe('DocumentAnalysisService', () => {
  beforeEach(() => {
    mockMessagesCreate.mockReset();
  });

  // ==========================================================================
  // analyzeDocument - basic functionality
  // ==========================================================================
  describe('analyzeDocument - basic functionality', () => {
    it('returns structured analysis report for servicing document', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification('servicing', 'monthly_statement');

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.documentInfo).toBeDefined();
      expect(result.extractedData).toBeDefined();
      expect(result.anomalies).toBeDefined();
      expect(result.completeness).toBeDefined();
      expect(result.summary).toBeDefined();
      expect(result.documentInfo.documentType).toBe('servicing');
      expect(result.documentInfo.documentSubtype).toBe('monthly_statement');
    });

    it('returns structured analysis report for origination document', async () => {
      const origResponse = createMockAnalysisResponse({
        extractedData: {
          dates: { closingDate: '2024-03-15' },
          amounts: { loanAmount: 300000, cashToClose: 12500 },
          rates: { interestRate: 5.75, apr: 5.92 },
          parties: { borrower: 'Jane Doe', lender: 'Chase Bank', seller: 'ABC Homes' },
          identifiers: { propertyAddress: '456 Oak Ave' },
          terms: { loanType: 'conventional', loanTerm: '30 years' },
          custom: {}
        },
        summary: {
          overview: 'Closing disclosure for conventional loan.',
          keyFindings: ['APR within tolerance of Loan Estimate'],
          riskLevel: 'low',
          recommendations: []
        },
        anomalies: []
      });
      mockMessagesCreate.mockResolvedValue(origResponse);
      const classification = createClassification('origination', 'closing_disclosure');

      const result = await documentAnalysisService.analyzeDocument(
        'Closing Disclosure document text here',
        classification
      );

      expect(result.documentInfo.documentType).toBe('origination');
      expect(result.documentInfo.documentSubtype).toBe('closing_disclosure');
      expect(result.extractedData.rates.interestRate).toBe(5.75);
    });

    it('returns structured analysis report for correspondence document', async () => {
      const corrResponse = createMockAnalysisResponse({
        extractedData: {
          dates: { noticeDate: '2024-06-01', cureDeadline: '2024-07-01' },
          amounts: { defaultAmount: 8500 },
          rates: {},
          parties: { borrower: 'Bob Johnson', servicer: 'Nationstar' },
          identifiers: { loanNumber: '****9876', propertyAddress: '789 Elm St' },
          terms: {},
          custom: {}
        },
        summary: {
          overview: 'Foreclosure notice with 30-day cure period.',
          keyFindings: ['Cure deadline may be insufficient under state law'],
          riskLevel: 'high',
          recommendations: ['Verify state notice requirements']
        },
        anomalies: []
      });
      mockMessagesCreate.mockResolvedValue(corrResponse);
      const classification = createClassification('correspondence', 'foreclosure_notice');

      const result = await documentAnalysisService.analyzeDocument(
        'Foreclosure notice text here',
        classification
      );

      expect(result.documentInfo.documentType).toBe('correspondence');
      expect(result.summary.riskLevel).toBe('high');
    });

    it('includes documentInfo metadata (type, subtype, model, timestamp)', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification('servicing', 'monthly_statement', 0.95);

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.documentInfo.documentType).toBe('servicing');
      expect(result.documentInfo.documentSubtype).toBe('monthly_statement');
      expect(result.documentInfo.modelUsed).toBe('claude-sonnet-4-5-20250514');
      expect(result.documentInfo.analyzedAt).toBeDefined();
      expect(result.documentInfo.confidence).toBe(0.95);
      // Verify analyzedAt is a valid ISO date
      expect(new Date(result.documentInfo.analyzedAt).toISOString()).toBe(result.documentInfo.analyzedAt);
    });

    it('passes correct model and parameters to Claude API', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification();

      await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          model: 'claude-sonnet-4-5-20250514',
          max_tokens: 8192,
          temperature: 0.1,
          messages: [
            {
              role: 'user',
              content: expect.any(String)
            }
          ]
        })
      );
    });

    it('uses type-specific prompt for each document category', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());

      const categories = [
        { type: 'servicing', subtype: 'monthly_statement', keyword: 'servicing category' },
        { type: 'origination', subtype: 'closing_disclosure', keyword: 'origination category' },
        { type: 'correspondence', subtype: 'foreclosure_notice', keyword: 'correspondence category' },
        { type: 'legal', subtype: 'assignment_of_mortgage', keyword: 'legal category' },
        { type: 'financial', subtype: 'bank_statement', keyword: 'financial category' },
        { type: 'regulatory', subtype: 'respa_disclosure', keyword: 'regulatory category' }
      ];

      for (const cat of categories) {
        mockMessagesCreate.mockClear();
        const classification = createClassification(cat.type, cat.subtype);
        await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

        const calledPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
        expect(calledPrompt).toContain(cat.keyword);
      }
    });
  });

  // ==========================================================================
  // analyzeDocument - prompt engineering
  // ==========================================================================
  describe('analyzeDocument - prompt engineering', () => {
    it('builds servicing-specific prompt for monthly_statement', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification('servicing', 'monthly_statement');

      await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      const calledPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(calledPrompt).toContain('monthly_statement');
      expect(calledPrompt).toContain('Payment amount matches principal + interest + escrow');
      expect(calledPrompt).toContain('RESPA limits');
      expect(calledPrompt).toContain('forensic mortgage analyst');
    });

    it('builds origination-specific prompt for closing_disclosure', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification('origination', 'closing_disclosure');

      await documentAnalysisService.analyzeDocument('Closing disclosure text', classification);

      const calledPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(calledPrompt).toContain('closing_disclosure');
      expect(calledPrompt).toContain('origination category');
      expect(calledPrompt).toContain('APR calculation');
    });

    it('builds correspondence-specific prompt for foreclosure_notice', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification('correspondence', 'foreclosure_notice');

      await documentAnalysisService.analyzeDocument('Foreclosure notice text', classification);

      const calledPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(calledPrompt).toContain('foreclosure_notice');
      expect(calledPrompt).toContain('correspondence category');
      expect(calledPrompt).toContain('borrower rights');
    });

    it('falls back to generic prompt for unknown document type', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification('unknown', 'unclassified');

      await documentAnalysisService.analyzeDocument('Some unknown document', classification);

      const calledPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(calledPrompt).toContain('unknown/unclassified');
      expect(calledPrompt).toContain('Internal consistency');
    });

    it('includes document text in prompt', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification();
      const uniqueText = 'UNIQUE_MARKER_TEXT_98765_FOR_TESTING';

      await documentAnalysisService.analyzeDocument(uniqueText, classification);

      const calledPrompt = mockMessagesCreate.mock.calls[0][0].messages[0].content;
      expect(calledPrompt).toContain(uniqueText);
    });
  });

  // ==========================================================================
  // analyzeDocument - completeness scoring
  // ==========================================================================
  describe('analyzeDocument - completeness scoring', () => {
    it('calculates completeness score from extracted fields', async () => {
      // monthly_statement critical: principalBalance, monthlyPayment, interestRate, paymentDueDate, statementDate
      // monthly_statement expected: escrowBalance, lateCharges, unpaidFees, borrower, loanNumber, servicer, propertyAddress
      // Total expected = 12
      // We provide 5 of them: principalBalance, monthlyPayment, interestRate, statementDate, escrowBalance
      const partialResponse = createMockAnalysisResponse({
        extractedData: {
          dates: { statementDate: '2024-01-15' },
          amounts: { principalBalance: 245000, monthlyPayment: 1523.47, escrowBalance: 3421.00 },
          rates: { interestRate: 6.5 },
          parties: {},
          identifiers: {},
          terms: {},
          custom: {}
        }
      });
      mockMessagesCreate.mockResolvedValue(partialResponse);
      const classification = createClassification('servicing', 'monthly_statement');

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.completeness).toBeDefined();
      expect(result.completeness.score).toBeGreaterThan(0);
      expect(result.completeness.score).toBeLessThan(100);
      expect(result.completeness.totalExpectedFields).toBe(12);
      expect(result.completeness.presentFields.length).toBeGreaterThan(0);
      expect(result.completeness.missingFields.length).toBeGreaterThan(0);
    });

    it('identifies missing critical fields', async () => {
      // Provide only non-critical fields
      const partialResponse = createMockAnalysisResponse({
        extractedData: {
          dates: {},
          amounts: { escrowBalance: 3421.00 },
          rates: {},
          parties: { borrower: 'John Smith', servicer: 'Wells Fargo' },
          identifiers: { loanNumber: '****1234' },
          terms: {},
          custom: {}
        }
      });
      mockMessagesCreate.mockResolvedValue(partialResponse);
      const classification = createClassification('servicing', 'monthly_statement');

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      // critical: principalBalance, monthlyPayment, interestRate, paymentDueDate, statementDate
      // None of the critical fields are present
      expect(result.completeness.missingCritical.length).toBeGreaterThan(0);
      expect(result.completeness.missingCritical).toContain('principalBalance');
      expect(result.completeness.missingCritical).toContain('interestRate');
    });

    it('identifies missing expected fields', async () => {
      const partialResponse = createMockAnalysisResponse({
        extractedData: {
          dates: { statementDate: '2024-01-15', paymentDueDate: '2024-02-01' },
          amounts: { principalBalance: 245000, monthlyPayment: 1523.47 },
          rates: { interestRate: 6.5 },
          parties: {},
          identifiers: {},
          terms: {},
          custom: {}
        }
      });
      mockMessagesCreate.mockResolvedValue(partialResponse);
      const classification = createClassification('servicing', 'monthly_statement');

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      // Expected fields not provided: escrowBalance, lateCharges, unpaidFees, borrower, loanNumber, servicer, propertyAddress
      expect(result.completeness.missingFields).toContain('escrowBalance');
      expect(result.completeness.missingFields).toContain('borrower');
      expect(result.completeness.missingFields).toContain('loanNumber');
    });

    it('returns 100% for fully extracted document', async () => {
      // Provide ALL critical + expected fields for monthly_statement
      const fullResponse = createMockAnalysisResponse({
        extractedData: {
          dates: { statementDate: '2024-01-15', paymentDueDate: '2024-02-01' },
          amounts: { principalBalance: 245000, monthlyPayment: 1523.47, escrowBalance: 3421.00, lateCharges: 0, unpaidFees: 0 },
          rates: { interestRate: 6.5 },
          parties: { borrower: 'John Smith', servicer: 'Wells Fargo' },
          identifiers: { loanNumber: '****1234', propertyAddress: '123 Main St' },
          terms: {},
          custom: {}
        }
      });
      mockMessagesCreate.mockResolvedValue(fullResponse);
      const classification = createClassification('servicing', 'monthly_statement');

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.completeness.score).toBe(100);
      expect(result.completeness.missingFields).toHaveLength(0);
      expect(result.completeness.missingCritical).toHaveLength(0);
    });

    it('returns 0% when no expected fields found', async () => {
      const emptyResponse = createMockAnalysisResponse({
        extractedData: {
          dates: {},
          amounts: {},
          rates: {},
          parties: {},
          identifiers: {},
          terms: {},
          custom: {}
        }
      });
      mockMessagesCreate.mockResolvedValue(emptyResponse);
      const classification = createClassification('servicing', 'monthly_statement');

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.completeness.score).toBe(0);
      expect(result.completeness.presentFields).toHaveLength(0);
      expect(result.completeness.missingFields.length).toBe(result.completeness.totalExpectedFields);
    });
  });

  // ==========================================================================
  // analyzeDocument - anomaly handling
  // ==========================================================================
  describe('analyzeDocument - anomaly handling', () => {
    it('returns anomalies from Claude analysis', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification();

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.anomalies).toHaveLength(1);
      expect(result.anomalies[0].field).toBe('monthlyPayment');
      expect(result.anomalies[0].type).toBe('calculation_error');
      expect(result.anomalies[0].severity).toBe('high');
      expect(result.anomalies[0].description).toContain('P&I calculation');
    });

    it('elevates severity for anomalies on critical fields', async () => {
      // principalBalance is a critical field for monthly_statement
      const response = createMockAnalysisResponse({
        anomalies: [
          {
            field: 'principalBalance',
            type: 'unusual_value',
            severity: 'low',
            description: 'Principal balance seems unusually low'
          }
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);
      const classification = createClassification('servicing', 'monthly_statement');

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      // Should be elevated from 'low' to 'high' because principalBalance is critical
      expect(result.anomalies[0].field).toBe('principalBalance');
      expect(result.anomalies[0].severity).toBe('high');
    });

    it('handles empty anomalies array', async () => {
      const response = createMockAnalysisResponse({ anomalies: [] });
      mockMessagesCreate.mockResolvedValue(response);
      const classification = createClassification();

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.anomalies).toHaveLength(0);
      expect(Array.isArray(result.anomalies)).toBe(true);
    });

    it('categorizes anomaly types correctly', async () => {
      const response = createMockAnalysisResponse({
        anomalies: [
          { field: 'monthlyPayment', type: 'calculation_error', severity: 'high', description: 'Math error' },
          { field: 'escrowBalance', type: 'unusual_value', severity: 'medium', description: 'Unusual value' },
          { field: 'lateCharges', type: 'regulatory_concern', severity: 'high', description: 'RESPA concern' }
        ]
      });
      mockMessagesCreate.mockResolvedValue(response);
      const classification = createClassification('servicing', 'monthly_statement');

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.anomalies).toHaveLength(3);
      expect(result.anomalies[0].type).toBe('calculation_error');
      expect(result.anomalies[1].type).toBe('unusual_value');
      expect(result.anomalies[2].type).toBe('regulatory_concern');
    });
  });

  // ==========================================================================
  // analyzeDocument - error handling
  // ==========================================================================
  describe('analyzeDocument - error handling', () => {
    it('handles Claude API error gracefully', async () => {
      const apiError = new Error('API rate limit exceeded');
      apiError.status = 429;
      mockMessagesCreate.mockRejectedValue(apiError);
      const classification = createClassification();

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.error).toBe(true);
      expect(result.errorMessage).toBe('API rate limit exceeded');
      expect(result.rawResponse).toBeNull();
      expect(result.documentInfo).toBeDefined();
      expect(result.documentInfo.documentType).toBe('servicing');
    });

    it('handles invalid JSON response from Claude', async () => {
      mockMessagesCreate.mockResolvedValue({
        content: [{ text: 'This is not valid JSON at all, just plain text.' }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 500, output_tokens: 200 }
      });
      const classification = createClassification();

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(result.parseError).toBeDefined();
      expect(result.rawResponse).toBe('This is not valid JSON at all, just plain text.');
      expect(result.documentInfo).toBeDefined();
    });

    it('handles partial JSON response from Claude', async () => {
      // JSON that is valid but missing required sections
      const partialJson = JSON.stringify({
        extractedData: {
          dates: { statementDate: '2024-01-15' }
          // Missing amounts, rates, parties, identifiers, terms, custom
        }
        // Missing anomalies, summary
      });
      mockMessagesCreate.mockResolvedValue({
        content: [{ text: partialJson }],
        model: 'claude-sonnet-4-5-20250514',
        usage: { input_tokens: 500, output_tokens: 100 }
      });
      const classification = createClassification();

      const result = await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      // Should still return a result, not throw
      expect(result.documentInfo).toBeDefined();
      expect(result.extractedData).toBeDefined();
      expect(result.anomalies).toBeDefined();
      expect(result.summary).toBeDefined();
    });

    it('throws on missing document text', async () => {
      const classification = createClassification();

      await expect(
        documentAnalysisService.analyzeDocument(null, classification)
      ).rejects.toThrow('Document text is required');

      await expect(
        documentAnalysisService.analyzeDocument('', classification)
      ).rejects.toThrow('Document text is required');

      await expect(
        documentAnalysisService.analyzeDocument(undefined, classification)
      ).rejects.toThrow('Document text is required');
    });

    it('throws on missing classification', async () => {
      await expect(
        documentAnalysisService.analyzeDocument(sampleDocumentText, null)
      ).rejects.toThrow('Classification object is required');

      await expect(
        documentAnalysisService.analyzeDocument(sampleDocumentText, undefined)
      ).rejects.toThrow('Classification object is required');
    });

    it('throws on classification missing required fields', async () => {
      await expect(
        documentAnalysisService.analyzeDocument(sampleDocumentText, {})
      ).rejects.toThrow('Classification must include classificationType and classificationSubtype');

      await expect(
        documentAnalysisService.analyzeDocument(sampleDocumentText, { classificationType: 'servicing' })
      ).rejects.toThrow('Classification must include classificationType and classificationSubtype');
    });

    it('handles empty document text (whitespace only) gracefully', async () => {
      const classification = createClassification();

      await expect(
        documentAnalysisService.analyzeDocument('   ', classification)
      ).rejects.toThrow('Document text is required');
    });
  });

  // ==========================================================================
  // analyzeDocument - configuration
  // ==========================================================================
  describe('analyzeDocument - configuration', () => {
    it('uses default model when not specified', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification();

      await documentAnalysisService.analyzeDocument(sampleDocumentText, classification);

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          model: 'claude-sonnet-4-5-20250514'
        })
      );
    });

    it('accepts custom model via options', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification();

      await documentAnalysisService.analyzeDocument(sampleDocumentText, classification, {
        model: 'claude-3-5-sonnet-20241022'
      });

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          model: 'claude-3-5-sonnet-20241022'
        })
      );
    });

    it('accepts custom maxTokens via options', async () => {
      mockMessagesCreate.mockResolvedValue(createMockAnalysisResponse());
      const classification = createClassification();

      await documentAnalysisService.analyzeDocument(sampleDocumentText, classification, {
        maxTokens: 4096
      });

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          max_tokens: 4096
        })
      );
    });
  });

  // ==========================================================================
  // _parseAnalysisResponse
  // ==========================================================================
  describe('_parseAnalysisResponse', () => {
    it('parses valid JSON correctly', () => {
      const data = { extractedData: { dates: {} }, anomalies: [], summary: {} };
      const result = documentAnalysisService._parseAnalysisResponse(JSON.stringify(data));

      expect(result.extractedData).toBeDefined();
      expect(result.anomalies).toEqual([]);
    });

    it('extracts JSON from markdown code fences', () => {
      const data = { extractedData: { dates: { testDate: '2024-01-01' } }, anomalies: [], summary: {} };
      const wrappedResponse = '```json\n' + JSON.stringify(data) + '\n```';

      const result = documentAnalysisService._parseAnalysisResponse(wrappedResponse);

      expect(result.extractedData).toBeDefined();
      expect(result.extractedData.dates.testDate).toBe('2024-01-01');
    });

    it('returns rawResponse and parseError for non-JSON text', () => {
      const result = documentAnalysisService._parseAnalysisResponse('Not JSON at all.');

      expect(result.rawResponse).toBe('Not JSON at all.');
      expect(result.parseError).toBeDefined();
      expect(typeof result.parseError).toBe('string');
    });
  });

  // ==========================================================================
  // _calculateCompleteness (direct unit test)
  // ==========================================================================
  describe('_calculateCompleteness', () => {
    it('returns correct structure', () => {
      const extractedData = {
        dates: { statementDate: '2024-01-15' },
        amounts: { principalBalance: 245000 },
        rates: {},
        parties: {},
        identifiers: {},
        terms: {},
        custom: {}
      };

      const result = documentAnalysisService._calculateCompleteness(
        extractedData, 'servicing', 'monthly_statement'
      );

      expect(result).toHaveProperty('score');
      expect(result).toHaveProperty('totalExpectedFields');
      expect(result).toHaveProperty('presentFields');
      expect(result).toHaveProperty('missingFields');
      expect(result).toHaveProperty('missingCritical');
      expect(typeof result.score).toBe('number');
      expect(Array.isArray(result.presentFields)).toBe(true);
      expect(Array.isArray(result.missingFields)).toBe(true);
      expect(Array.isArray(result.missingCritical)).toBe(true);
    });

    it('ignores null values in completeness counting', () => {
      const extractedData = {
        dates: { statementDate: null, paymentDueDate: '2024-02-01' },
        amounts: { principalBalance: null },
        rates: {},
        parties: {},
        identifiers: {},
        terms: {},
        custom: {}
      };

      const result = documentAnalysisService._calculateCompleteness(
        extractedData, 'servicing', 'monthly_statement'
      );

      // Only paymentDueDate should count as present
      expect(result.presentFields).toContain('paymentDueDate');
      expect(result.presentFields).not.toContain('statementDate');
      expect(result.presentFields).not.toContain('principalBalance');
    });
  });

  // ==========================================================================
  // _categorizeAnomalies (direct unit test)
  // ==========================================================================
  describe('_categorizeAnomalies', () => {
    it('does not elevate severity for non-critical fields', () => {
      // nextPaymentAmount is optional for monthly_statement
      const anomalies = [
        { field: 'nextPaymentAmount', type: 'unusual_value', severity: 'low', description: 'Unusual value' }
      ];

      const result = documentAnalysisService._categorizeAnomalies(
        anomalies, 'servicing', 'monthly_statement'
      );

      expect(result[0].severity).toBe('low');
    });

    it('handles anomalies with missing fields gracefully', () => {
      const anomalies = [
        { description: 'Some issue' }
      ];

      const result = documentAnalysisService._categorizeAnomalies(
        anomalies, 'servicing', 'monthly_statement'
      );

      expect(result[0].field).toBe('unknown');
      expect(result[0].type).toBe('unusual_value');
      expect(result[0].severity).toBeDefined();
    });
  });
});
