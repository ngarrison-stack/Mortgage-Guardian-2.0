/**
 * Dispute Letter Service Tests
 *
 * Tests generateDisputeLetter() for all 3 RESPA letter types,
 * error handling, graceful degradation, and JSON extraction fallback.
 *
 * Mocks: Anthropic SDK (no API key needed for tests)
 */

let mockCreate;

jest.mock('@anthropic-ai/sdk', () => {
  mockCreate = jest.fn();
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockCreate }
  }));
});

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

function makeMockLetterResponse() {
  return {
    subject: 'Qualified Written Request Regarding Loan #12345',
    salutation: 'Dear Loan Servicing Department:',
    body: '## Qualified Written Request\n\nThis letter constitutes a Qualified Written Request under RESPA Section 6...',
    demands: [
      'Provide a complete payment history for the life of the loan',
      'Correct the escrow account balance discrepancy',
      'Refund all improperly assessed late fees'
    ],
    legalCitations: [
      '12 U.S.C. § 2605(e)',
      '12 CFR 1024.35',
      '12 CFR 1024.36'
    ],
    responseDeadline: '30 business days from receipt of this letter',
    closingStatement: 'Please respond within the timeframe required by federal law. Sincerely, [Borrower Name]'
  };
}

function makeConsolidatedReport() {
  return {
    caseSummary: {
      caseId: 'case-001',
      borrowerName: 'Jane Doe',
      loanNumber: '12345',
      propertyAddress: '123 Main St, Springfield, IL 62701',
      servicerName: 'ABC Mortgage Servicing',
      servicerAddress: '456 Corporate Blvd, Suite 100, Chicago, IL 60601'
    },
    documentAnalyses: [
      {
        documentId: 'doc-001',
        documentName: 'statement-jan.pdf',
        type: 'mortgage_statement',
        anomalies: [
          { id: 'anom-001', field: 'escrowBalance', severity: 'high', description: 'Escrow shortage not disclosed' }
        ]
      }
    ],
    forensicReport: {
      discrepancies: [
        { id: 'disc-001', type: 'payment_mismatch', severity: 'critical', description: 'Payment credited 5 days late' }
      ],
      timeline: { violations: [] },
      paymentVerification: { verified: false }
    },
    complianceReport: {
      violations: [
        {
          id: 'viol-001',
          statuteName: 'RESPA',
          citation: '12 U.S.C. § 2605(e)',
          severity: 'high',
          description: 'Failure to respond to qualified written request within 30 days',
          legalBasis: 'RESPA Section 6(e) requires a substantive response within 30 business days'
        }
      ],
      stateViolations: [
        {
          id: 'sviol-001',
          jurisdiction: 'IL',
          statuteName: 'Illinois Interest Act',
          citation: '815 ILCS 205/4',
          severity: 'medium',
          description: 'Interest overcharge on escrow account'
        }
      ]
    }
  };
}

const disputeLetterService = require('../../services/disputeLetterService');

beforeEach(() => {
  process.env.ANTHROPIC_API_KEY = 'test-key-for-testing';
  mockCreate.mockReset();
  // Reset the lazy client so it re-initializes with the mock
  disputeLetterService._client = null;
});

afterEach(() => {
  delete process.env.ANTHROPIC_API_KEY;
});

// ---------------------------------------------------------------------------
// generateDisputeLetter — Happy Paths
// ---------------------------------------------------------------------------

describe('generateDisputeLetter', () => {
  test('generates a qualified_written_request with all required fields', async () => {
    const mockResponse = makeMockLetterResponse();
    mockCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(mockResponse) }],
      usage: { input_tokens: 500, output_tokens: 800 }
    });

    const result = await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    expect(result.error).toBeUndefined();
    expect(result.letterType).toBe('qualified_written_request');
    expect(result.generatedAt).toBeDefined();
    expect(result.content.subject).toBe(mockResponse.subject);
    expect(result.content.salutation).toBe(mockResponse.salutation);
    expect(result.content.body).toContain('Qualified Written Request');
    expect(result.content.demands).toHaveLength(3);
    expect(result.content.legalCitations).toContain('12 U.S.C. § 2605(e)');
    expect(result.content.responseDeadline).toBe('30 business days from receipt of this letter');
    expect(result.content.closingStatement).toBeDefined();
    expect(result.recipientInfo.servicerName).toBe('ABC Mortgage Servicing');
    expect(result.recipientInfo.servicerAddress).toBe('456 Corporate Blvd, Suite 100, Chicago, IL 60601');
  });

  test('generates a notice_of_error letter', async () => {
    const mockResponse = {
      ...makeMockLetterResponse(),
      subject: 'Notice of Error Regarding Loan #12345'
    };
    mockCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(mockResponse) }],
      usage: { input_tokens: 450, output_tokens: 700 }
    });

    const result = await disputeLetterService.generateDisputeLetter(
      'notice_of_error',
      makeConsolidatedReport()
    );

    expect(result.error).toBeUndefined();
    expect(result.letterType).toBe('notice_of_error');
    expect(result.content.subject).toContain('Notice of Error');
    expect(result.content.demands).toBeInstanceOf(Array);
    expect(result.content.legalCitations).toBeInstanceOf(Array);
  });

  test('generates a request_for_information letter', async () => {
    const mockResponse = {
      ...makeMockLetterResponse(),
      subject: 'Request for Information Regarding Loan #12345'
    };
    mockCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(mockResponse) }],
      usage: { input_tokens: 400, output_tokens: 600 }
    });

    const result = await disputeLetterService.generateDisputeLetter(
      'request_for_information',
      makeConsolidatedReport()
    );

    expect(result.error).toBeUndefined();
    expect(result.letterType).toBe('request_for_information');
    expect(result.content.subject).toContain('Request for Information');
  });

  test('passes violation data to Claude in the prompt', async () => {
    const mockResponse = makeMockLetterResponse();
    mockCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(mockResponse) }],
      usage: { input_tokens: 500, output_tokens: 800 }
    });

    await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    expect(mockCreate).toHaveBeenCalledTimes(1);
    const callArgs = mockCreate.mock.calls[0][0];
    const prompt = callArgs.messages[0].content;

    expect(prompt).toContain('RESPA');
    expect(prompt).toContain('12 U.S.C. § 2605(e)');
    expect(prompt).toContain('Failure to respond to qualified written request');
  });

  test('passes servicer name in the prompt', async () => {
    const mockResponse = makeMockLetterResponse();
    mockCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(mockResponse) }],
      usage: { input_tokens: 500, output_tokens: 800 }
    });

    await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    const prompt = mockCreate.mock.calls[0][0].messages[0].content;
    expect(prompt).toContain('ABC Mortgage Servicing');
  });

  test('uses correct model and temperature', async () => {
    const mockResponse = makeMockLetterResponse();
    mockCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(mockResponse) }],
      usage: { input_tokens: 500, output_tokens: 800 }
    });

    await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    const callArgs = mockCreate.mock.calls[0][0];
    expect(callArgs.model).toBe('claude-sonnet-4-5-20250514');
    expect(callArgs.temperature).toBe(0.1);
  });
});

// ---------------------------------------------------------------------------
// generateDisputeLetter — Error Cases
// ---------------------------------------------------------------------------

describe('generateDisputeLetter — error handling', () => {
  test('returns error for invalid letter type', async () => {
    const result = await disputeLetterService.generateDisputeLetter(
      'invalid_type',
      makeConsolidatedReport()
    );

    expect(result.error).toBe(true);
    expect(result.errorMessage).toContain('Invalid letter type');
    expect(result.letterType).toBe('invalid_type');
    expect(mockCreate).not.toHaveBeenCalled();
  });

  test('returns error for null letter type', async () => {
    const result = await disputeLetterService.generateDisputeLetter(
      null,
      makeConsolidatedReport()
    );

    expect(result.error).toBe(true);
    expect(result.errorMessage).toContain('Invalid letter type');
    expect(result.letterType).toBe('unknown');
  });

  test('returns error for missing consolidated report', async () => {
    const result = await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      null
    );

    expect(result.error).toBe(true);
    expect(result.errorMessage).toContain('Consolidated report is required');
    expect(result.letterType).toBe('qualified_written_request');
    expect(mockCreate).not.toHaveBeenCalled();
  });

  test('returns error for non-object consolidated report', async () => {
    const result = await disputeLetterService.generateDisputeLetter(
      'notice_of_error',
      'not an object'
    );

    expect(result.error).toBe(true);
    expect(result.errorMessage).toContain('Consolidated report is required');
  });

  test('returns error object on Claude API failure — never throws', async () => {
    mockCreate.mockRejectedValueOnce(new Error('API rate limit exceeded'));

    const result = await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    expect(result.error).toBe(true);
    expect(result.errorMessage).toBe('API rate limit exceeded');
    expect(result.letterType).toBe('qualified_written_request');
  });

  test('returns error when Claude returns unparseable response', async () => {
    mockCreate.mockResolvedValueOnce({
      content: [{ text: 'This is not JSON at all' }],
      usage: { input_tokens: 100, output_tokens: 50 }
    });

    const result = await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    expect(result.error).toBe(true);
    expect(result.errorMessage).toContain('Failed to parse generated letter');
  });

  test('returns error when Claude returns empty response', async () => {
    mockCreate.mockResolvedValueOnce({
      content: [{ text: '' }],
      usage: { input_tokens: 100, output_tokens: 0 }
    });

    const result = await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    expect(result.error).toBe(true);
    expect(result.errorMessage).toContain('Failed to parse generated letter');
  });
});

// ---------------------------------------------------------------------------
// Markdown code fence JSON extraction fallback
// ---------------------------------------------------------------------------

describe('generateDisputeLetter — code fence fallback', () => {
  test('successfully parses JSON wrapped in markdown code fences', async () => {
    const mockResponse = makeMockLetterResponse();
    const wrappedText = '```json\n' + JSON.stringify(mockResponse, null, 2) + '\n```';
    mockCreate.mockResolvedValueOnce({
      content: [{ text: wrappedText }],
      usage: { input_tokens: 500, output_tokens: 800 }
    });

    const result = await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    expect(result.error).toBeUndefined();
    expect(result.letterType).toBe('qualified_written_request');
    expect(result.content.subject).toBe(mockResponse.subject);
    expect(result.content.demands).toHaveLength(3);
  });

  test('successfully parses JSON wrapped in generic code fences (no json tag)', async () => {
    const mockResponse = makeMockLetterResponse();
    const wrappedText = '```\n' + JSON.stringify(mockResponse) + '\n```';
    mockCreate.mockResolvedValueOnce({
      content: [{ text: wrappedText }],
      usage: { input_tokens: 500, output_tokens: 800 }
    });

    const result = await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    expect(result.error).toBeUndefined();
    expect(result.content.subject).toBe(mockResponse.subject);
  });
});

// ---------------------------------------------------------------------------
// _extractRecipientInfo
// ---------------------------------------------------------------------------

describe('_extractRecipientInfo', () => {
  test('extracts servicer info from full case summary', () => {
    const report = makeConsolidatedReport();
    const info = disputeLetterService._extractRecipientInfo(report);

    expect(info.servicerName).toBe('ABC Mortgage Servicing');
    expect(info.servicerAddress).toBe('456 Corporate Blvd, Suite 100, Chicago, IL 60601');
  });

  test('returns defaults when servicer info is missing', () => {
    const info = disputeLetterService._extractRecipientInfo({});

    expect(info.servicerName).toBe('Unknown Servicer');
    expect(info.servicerAddress).toBe('Address Not Available');
  });

  test('returns defaults when caseSummary is missing', () => {
    const info = disputeLetterService._extractRecipientInfo({ caseSummary: undefined });

    expect(info.servicerName).toBe('Unknown Servicer');
    expect(info.servicerAddress).toBe('Address Not Available');
  });
});

// ---------------------------------------------------------------------------
// Content defaults for missing fields
// ---------------------------------------------------------------------------

describe('generateDisputeLetter — content defaults', () => {
  test('provides empty defaults when Claude returns partial response', async () => {
    const partialResponse = {
      subject: 'Partial Letter',
      body: 'Some body text'
      // Missing: salutation, demands, legalCitations, responseDeadline, closingStatement
    };
    mockCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(partialResponse) }],
      usage: { input_tokens: 300, output_tokens: 200 }
    });

    const result = await disputeLetterService.generateDisputeLetter(
      'qualified_written_request',
      makeConsolidatedReport()
    );

    expect(result.error).toBeUndefined();
    expect(result.content.subject).toBe('Partial Letter');
    expect(result.content.body).toBe('Some body text');
    expect(result.content.salutation).toBe('');
    expect(result.content.demands).toEqual([]);
    expect(result.content.legalCitations).toEqual([]);
    expect(result.content.responseDeadline).toBe('');
    expect(result.content.closingStatement).toBe('');
  });

  test('handles report with no violations or findings gracefully', async () => {
    const mockResponse = makeMockLetterResponse();
    mockCreate.mockResolvedValueOnce({
      content: [{ text: JSON.stringify(mockResponse) }],
      usage: { input_tokens: 300, output_tokens: 600 }
    });

    const emptyReport = {
      caseSummary: { servicerName: 'Test Servicer' },
      documentAnalyses: [],
      forensicReport: { discrepancies: [] },
      complianceReport: { violations: [], stateViolations: [] }
    };

    const result = await disputeLetterService.generateDisputeLetter(
      'notice_of_error',
      emptyReport
    );

    expect(result.error).toBeUndefined();
    expect(result.letterType).toBe('notice_of_error');
    expect(result.recipientInfo.servicerName).toBe('Test Servicer');
  });
});
