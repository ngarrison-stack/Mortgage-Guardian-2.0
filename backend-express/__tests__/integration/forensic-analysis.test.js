/**
 * Cross-Document Forensic Analysis Integration Tests
 *
 * Verifies the forensic analysis API endpoints and orchestration flow:
 * 1. POST /v1/cases/:caseId/forensic-analysis triggers cross-document analysis
 * 2. GET /v1/cases/:caseId/forensic-analysis retrieves stored results
 * 3. End-to-end flow: create case -> add docs -> analyze -> retrieve
 *
 * Mocks external boundaries only: Supabase, Anthropic SDK, Plaid SDK.
 * Lets internal service logic (aggregation, comparison, cross-reference) run.
 */

// ============================================================
// MOCKS — set up before any module imports
// ============================================================

const { createMockSupabaseClient } = require('../mocks/mockSupabaseClient');
const mockClaudeService = require('../mocks/mockClaudeService');
const request = require('supertest');

const mockClient = createMockSupabaseClient();

// Mock @supabase/supabase-js before any module loads it
jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockClient)
}));

// Mock claudeService for backward-compat
jest.mock('../../services/claudeService', () => mockClaudeService);

// Mock Anthropic SDK (used by crossDocumentComparisonService)
const mockAnthropicCreate = jest.fn();
jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockAnthropicCreate }
  }));
});

// Mock pdf-parse (used by ocrService)
jest.mock('pdf-parse', () => {
  return jest.fn().mockResolvedValue({
    text: 'Mock mortgage document text.',
    numpages: 1,
    info: { Title: 'Mock Document' }
  });
});

// Mock documentService
const mockDocumentService = {
  uploadDocument: jest.fn().mockResolvedValue({ documentId: 'doc-1', storagePath: 'mock/path' }),
  getDocumentsByUser: jest.fn().mockResolvedValue([]),
  getDocument: jest.fn().mockResolvedValue(null),
  deleteDocument: jest.fn().mockResolvedValue({ success: true }),
  getContentType: jest.fn().mockReturnValue('application/pdf')
};
jest.mock('../../services/documentService', () => mockDocumentService);

// Mock plaid services to prevent initialization errors
const mockPlaidService = {
  createLinkToken: jest.fn().mockResolvedValue({ link_token: 'mock', expiration: '2025-01-01T00:00:00Z', request_id: 'req' }),
  exchangePublicToken: jest.fn().mockResolvedValue({ accessToken: 'tok', itemId: 'item', requestId: 'req' }),
  getAccounts: jest.fn().mockResolvedValue({ accounts: [], item: {}, request_id: 'req' }),
  getTransactions: jest.fn().mockResolvedValue({
    transactions: [],
    total_transactions: 0,
    accounts: [],
    request_id: 'req'
  }),
  getItem: jest.fn().mockResolvedValue({ itemId: 'item', institutionId: 'inst' }),
  removeItem: jest.fn().mockResolvedValue({ removed: true, request_id: 'req' }),
  updateWebhook: jest.fn().mockResolvedValue({ itemId: 'item', webhook: 'https://mock' }),
  createSandboxPublicToken: jest.fn().mockResolvedValue('public-sandbox-mock'),
  testConnection: jest.fn().mockResolvedValue({ success: true }),
  verifyWebhookSignature: jest.fn().mockReturnValue(true)
};
jest.mock('../../services/plaidService', () => mockPlaidService);

jest.mock('../../services/plaidDataService', () => ({
  upsertPlaidItem: jest.fn().mockResolvedValue({ success: true }),
  getItem: jest.fn().mockResolvedValue({ success: true, data: { access_token: 'mock', user_id: 'mock' } }),
  storeTransactions: jest.fn().mockResolvedValue({ success: true }),
  upsertAccounts: jest.fn().mockResolvedValue({ success: true }),
  createNotification: jest.fn().mockResolvedValue({ success: true }),
  removeTransactions: jest.fn().mockResolvedValue({ success: true }),
  updateItemStatus: jest.fn().mockResolvedValue({ success: true })
}));

// ============================================================
// TEST FIXTURES
// ============================================================

const TEST_USER_ID = 'mock-user-id-12345';
const OTHER_USER_ID = 'other-user-id-99999';
const TEST_CASE_ID = 'case-forensic-001';

/** Realistic analysis report for a monthly statement */
const STATEMENT_ANALYSIS = {
  documentInfo: { documentType: 'servicing', documentSubtype: 'monthly_statement' },
  extractedData: {
    dates: { statementDate: '2024-01-15', paymentDueDate: '2024-02-01' },
    amounts: { principalBalance: 245000, monthlyPayment: 1500, escrowBalance: 3200 },
    rates: { interestRate: 4.5 },
    parties: { borrower: 'Jane Doe', servicer: 'Test Bank' },
    identifiers: { loanNumber: '12345' },
    terms: {},
    custom: {}
  },
  anomalies: [
    {
      field: 'monthlyPayment',
      type: 'unusual_value',
      severity: 'medium',
      description: 'Monthly payment appears lower than expected',
      expectedValue: '$1,575.00',
      actualValue: '$1,500.00'
    }
  ],
  summary: {
    overview: 'Monthly statement with potential payment discrepancy.',
    keyFindings: ['Payment amount may not match amortization schedule'],
    riskLevel: 'medium',
    recommendations: ['Request payment amortization schedule from servicer']
  },
  completeness: {
    score: 85,
    presentFields: ['principalBalance', 'monthlyPayment', 'interestRate'],
    missingFields: ['escrowBreakdown'],
    missingCritical: [],
    totalExpectedFields: 10
  }
};

/** Realistic analysis report for a closing disclosure */
const CLOSING_ANALYSIS = {
  documentInfo: { documentType: 'origination', documentSubtype: 'closing_disclosure' },
  extractedData: {
    dates: { closingDate: '2022-03-15', firstPaymentDate: '2022-05-01' },
    amounts: { loanAmount: 260000, monthlyPayment: 1575, closingCosts: 8500 },
    rates: { interestRate: 4.25 },
    parties: { borrower: 'Jane Doe', lender: 'Original Lender Inc' },
    identifiers: { loanNumber: '12345' },
    terms: { loanTerm: '30 years', loanType: 'conventional' },
    custom: {}
  },
  anomalies: [],
  summary: {
    overview: 'Standard closing disclosure for conventional 30-year mortgage.',
    keyFindings: [],
    riskLevel: 'low',
    recommendations: []
  },
  completeness: {
    score: 95,
    presentFields: ['loanAmount', 'interestRate', 'monthlyPayment', 'closingCosts'],
    missingFields: [],
    missingCritical: [],
    totalExpectedFields: 8
  }
};

/** Realistic analysis report for a payment history */
const PAYMENT_HISTORY_ANALYSIS = {
  documentInfo: { documentType: 'servicing', documentSubtype: 'payment_history' },
  extractedData: {
    dates: { periodStart: '2023-01-01', periodEnd: '2024-01-01' },
    amounts: { totalPayments: 18000, averagePayment: 1500 },
    rates: {},
    parties: { borrower: 'Jane Doe', servicer: 'Test Bank' },
    identifiers: { loanNumber: '12345' },
    terms: {},
    custom: {
      payments: [
        { date: '2024-01-01', amount: 1500, status: 'applied' },
        { date: '2023-12-01', amount: 1500, status: 'applied' },
        { date: '2023-11-01', amount: 1500, status: 'applied' }
      ]
    }
  },
  anomalies: [],
  summary: {
    overview: 'Payment history showing regular monthly payments.',
    keyFindings: [],
    riskLevel: 'low',
    recommendations: []
  },
  completeness: {
    score: 90,
    presentFields: ['totalPayments', 'averagePayment', 'payments'],
    missingFields: ['latePayments'],
    missingCritical: [],
    totalExpectedFields: 6
  }
};

/** Case data with 3 analyzed documents */
const MOCK_CASE_WITH_DOCS = {
  id: TEST_CASE_ID,
  user_id: TEST_USER_ID,
  case_name: 'Doe Mortgage Review',
  borrower_name: 'Jane Doe',
  loan_number: '12345',
  status: 'in_review',
  forensic_analysis: null,
  documents: [
    {
      document_id: 'doc-stmt-001',
      user_id: TEST_USER_ID,
      case_id: TEST_CASE_ID,
      document_type: 'servicing',
      document_subtype: 'monthly_statement',
      analysis_results: STATEMENT_ANALYSIS
    },
    {
      document_id: 'doc-close-001',
      user_id: TEST_USER_ID,
      case_id: TEST_CASE_ID,
      document_type: 'origination',
      document_subtype: 'closing_disclosure',
      analysis_results: CLOSING_ANALYSIS
    },
    {
      document_id: 'doc-pay-001',
      user_id: TEST_USER_ID,
      case_id: TEST_CASE_ID,
      document_type: 'servicing',
      document_subtype: 'payment_history',
      analysis_results: PAYMENT_HISTORY_ANALYSIS
    }
  ]
};

/** Case with only 1 document (insufficient for forensic analysis) */
const MOCK_CASE_ONE_DOC = {
  id: 'case-one-doc',
  user_id: TEST_USER_ID,
  case_name: 'Single Doc Case',
  status: 'open',
  forensic_analysis: null,
  documents: [
    {
      document_id: 'doc-single-001',
      user_id: TEST_USER_ID,
      case_id: 'case-one-doc',
      document_type: 'servicing',
      document_subtype: 'monthly_statement',
      analysis_results: STATEMENT_ANALYSIS
    }
  ]
};

/** Claude comparison response (used by crossDocumentComparisonService) */
const MOCK_COMPARISON_RESPONSE = {
  content: [{
    text: JSON.stringify({
      discrepancies: [
        {
          type: 'amount_mismatch',
          severity: 'high',
          field: 'interestRate',
          description: 'Interest rate changed from 4.25% at closing to 4.5% on current statement without documented rate change event',
          documentA: {
            documentId: 'doc-stmt-001',
            documentType: 'servicing',
            documentSubtype: 'monthly_statement',
            field: 'interestRate',
            value: '4.5%'
          },
          documentB: {
            documentId: 'doc-close-001',
            documentType: 'origination',
            documentSubtype: 'closing_disclosure',
            field: 'interestRate',
            value: '4.25%'
          },
          forensicSignificance: 'Rate increase without documentation may violate loan terms'
        }
      ],
      timelineEvents: [
        {
          date: '2022-03-15',
          event: 'Loan closed',
          source: 'closing_disclosure',
          documentId: 'doc-close-001'
        },
        {
          date: '2024-01-15',
          event: 'Statement issued',
          source: 'monthly_statement',
          documentId: 'doc-stmt-001'
        }
      ],
      timelineViolations: [],
      comparisonSummary: 'Interest rate discrepancy detected between closing and current statement.'
    })
  }],
  model: 'claude-sonnet-4-5-20250514',
  usage: { input_tokens: 2000, output_tokens: 800 },
  stop_reason: 'end_turn'
};

/** Plaid transactions fixture */
const MOCK_PLAID_TRANSACTIONS = [
  {
    transaction_id: 'txn-001',
    date: '2024-01-01',
    amount: 1500,
    name: 'Mortgage Payment Test Bank',
    category: ['Payment', 'Loan'],
    pending: false
  },
  {
    transaction_id: 'txn-002',
    date: '2023-12-01',
    amount: 1500,
    name: 'Mortgage Payment Test Bank',
    category: ['Payment', 'Loan'],
    pending: false
  },
  {
    transaction_id: 'txn-003',
    date: '2023-11-01',
    amount: 1500,
    name: 'Mortgage Payment Test Bank',
    category: ['Payment', 'Loan'],
    pending: false
  }
];

// ============================================================
// SETUP
// ============================================================

process.env.SUPABASE_URL = 'https://mock.supabase.co';
process.env.SUPABASE_ANON_KEY = 'mock-anon-key';
process.env.ANTHROPIC_API_KEY = 'test-key';
process.env.NODE_ENV = 'production';
process.env.VERCEL = '1';

let app;
let caseFileService;

beforeAll(() => {
  // Clear cached modules so mocks take effect
  const modulesToClear = [
    '../../server',
    '../../routes/claude',
    '../../routes/plaid',
    '../../routes/documents',
    '../../routes/cases',
    '../../routes/health',
    '../../middleware/auth',
    '../../services/documentPipelineService',
    '../../services/classificationService',
    '../../services/documentAnalysisService',
    '../../services/ocrService',
    '../../services/caseFileService',
    '../../services/forensicAnalysisService',
    '../../services/crossDocumentAggregationService',
    '../../services/crossDocumentComparisonService',
    '../../services/plaidCrossReferenceService'
  ];

  for (const mod of modulesToClear) {
    try {
      delete require.cache[require.resolve(mod)];
    } catch {
      // Not cached yet
    }
  }

  app = require('../../server');
  caseFileService = require('../../services/caseFileService');
  process.env.NODE_ENV = 'test';
});

afterAll(() => {
  delete process.env.VERCEL;
  delete process.env.ANTHROPIC_API_KEY;
});

beforeEach(() => {
  mockClient.reset();
  mockClaudeService.reset();
  mockAnthropicCreate.mockReset();
  jest.clearAllMocks();

  // Default: caseFileService uses mock mode (no supabase configured)
  // We need to seed mock cases for tests
  caseFileService.mockCases.clear();
  caseFileService.mockDocCaseMap.clear();
});

/**
 * Helper: seed the mock case file service with a case and its documents.
 * Since caseFileService.getCase in mock mode only returns basic doc stubs,
 * we mock it directly for forensic tests that need full analysis_results.
 */
function seedCaseWithDocs(caseData) {
  // Store the case in mockCases
  caseFileService.mockCases.set(caseData.id, {
    id: caseData.id,
    user_id: caseData.user_id,
    case_name: caseData.case_name,
    borrower_name: caseData.borrower_name || null,
    loan_number: caseData.loan_number || null,
    status: caseData.status || 'open',
    forensic_analysis: caseData.forensic_analysis || null,
    documents: caseData.documents || []
  });

  // We need to spy on getCase to return full doc data with analysis_results
  jest.spyOn(caseFileService, 'getCase').mockImplementation(async ({ caseId, userId }) => {
    const stored = caseFileService.mockCases.get(caseId);
    if (!stored || stored.user_id !== userId) return null;
    return { ...stored };
  });

  // Spy on updateCase for persistence
  jest.spyOn(caseFileService, 'updateCase').mockImplementation(async ({ caseId, userId, updates }) => {
    const stored = caseFileService.mockCases.get(caseId);
    if (!stored || stored.user_id !== userId) throw new Error('Case not found');
    Object.assign(stored, updates);
    caseFileService.mockCases.set(caseId, stored);
    return stored;
  });
}

/**
 * Helper: set up Anthropic mock for comparison responses.
 * Called once per comparison pair.
 */
function setupComparisonMocks(responseOverride) {
  const resp = responseOverride || MOCK_COMPARISON_RESPONSE;
  mockAnthropicCreate.mockResolvedValue(resp);
}

// ============================================================
// POST /v1/cases/:caseId/forensic-analysis
// ============================================================
describe('POST /v1/cases/:caseId/forensic-analysis', () => {

  test('should return 401 without authentication', async () => {
    const res = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`);

    expect(res.status).toBe(401);
  });

  test('should return 200 with forensic analysis for case with multiple analyzed documents', async () => {
    seedCaseWithDocs(MOCK_CASE_WITH_DOCS);
    setupComparisonMocks();

    const res = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.caseId).toBe(TEST_CASE_ID);
    expect(res.body.status).toBe('completed');
    expect(res.body.forensicAnalysis).toBeDefined();
    expect(res.body.forensicAnalysis.caseId).toBe(TEST_CASE_ID);
    expect(res.body.forensicAnalysis.documentsAnalyzed).toBeGreaterThanOrEqual(2);
    expect(res.body.forensicAnalysis.summary).toBeDefined();
  });

  test('should return 200 with status:error for non-existent case', async () => {
    // getCase returns null for unknown case — aggregation throws "Case not found"
    jest.spyOn(caseFileService, 'getCase').mockResolvedValue(null);

    const res = await request(app)
      .post('/v1/cases/nonexistent-case/forensic-analysis')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('error');
    expect(res.body.error).toBeDefined();
  });

  test('should return 200 with warning for case with insufficient analyzed documents', async () => {
    seedCaseWithDocs(MOCK_CASE_ONE_DOC);

    const res = await request(app)
      .post('/v1/cases/case-one-doc/forensic-analysis')
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    // Should complete but with warning about insufficient docs
    const body = res.body;
    expect(body.status).toBe('completed');
    expect(body.forensicAnalysis.documentsAnalyzed).toBeLessThan(2);
    expect(body.forensicAnalysis._metadata.warnings).toBeDefined();
    expect(body.forensicAnalysis._metadata.warnings.length).toBeGreaterThan(0);
  });

  test('should accept optional Plaid access token in body', async () => {
    seedCaseWithDocs(MOCK_CASE_WITH_DOCS);
    setupComparisonMocks();

    // Set up Plaid transactions response
    mockPlaidService.getTransactions.mockResolvedValue({
      transactions: MOCK_PLAID_TRANSACTIONS,
      total_transactions: 3,
      accounts: [],
      request_id: 'req-plaid'
    });

    const res = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token')
      .send({ plaidAccessToken: 'access-sandbox-test-token' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('completed');
    expect(res.body.forensicAnalysis.paymentVerification).toBeDefined();
  });

  test('should validate body schema and reject invalid dateTolerance', async () => {
    const res = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token')
      .send({ dateTolerance: 50 }); // max is 30

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  test('should validate body schema and reject invalid amountTolerance', async () => {
    const res = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token')
      .send({ amountTolerance: 200 }); // max is 100

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bad Request');
  });

  test('should include discrepancies from document pair comparisons', async () => {
    seedCaseWithDocs(MOCK_CASE_WITH_DOCS);
    setupComparisonMocks();

    const res = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    const analysis = res.body.forensicAnalysis;
    expect(Array.isArray(analysis.discrepancies)).toBe(true);
    // Our mock comparison returns at least 1 discrepancy per pair
    expect(analysis.discrepancies.length).toBeGreaterThan(0);
    // Each discrepancy should have required fields
    for (const disc of analysis.discrepancies) {
      expect(disc.type).toBeDefined();
      expect(disc.severity).toBeDefined();
      expect(disc.description).toBeDefined();
    }
  });

  test('should include timeline events sorted by date', async () => {
    seedCaseWithDocs(MOCK_CASE_WITH_DOCS);
    setupComparisonMocks();

    const res = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(res.status).toBe(200);
    const timeline = res.body.forensicAnalysis.timeline;
    expect(timeline).toBeDefined();
    expect(Array.isArray(timeline.events)).toBe(true);

    // Verify events are sorted by date
    for (let i = 1; i < timeline.events.length; i++) {
      const prev = timeline.events[i - 1].date || '';
      const curr = timeline.events[i].date || '';
      expect(prev.localeCompare(curr)).toBeLessThanOrEqual(0);
    }
  });

  test('should include payment verification when Plaid token provided', async () => {
    seedCaseWithDocs(MOCK_CASE_WITH_DOCS);
    setupComparisonMocks();

    mockPlaidService.getTransactions.mockResolvedValue({
      transactions: MOCK_PLAID_TRANSACTIONS,
      total_transactions: 3,
      accounts: [{ account_id: 'acct-1', name: 'Checking' }],
      request_id: 'req-plaid-2'
    });

    const res = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token')
      .send({
        plaidAccessToken: 'access-sandbox-token',
        transactionStartDate: '2023-01-01',
        transactionEndDate: '2024-01-31'
      });

    expect(res.status).toBe(200);
    const pv = res.body.forensicAnalysis.paymentVerification;
    expect(pv).toBeDefined();
    expect(pv.transactionsAnalyzed).toBe(3);
    expect(pv.dateRange).toBeDefined();
  });
});

// ============================================================
// GET /v1/cases/:caseId/forensic-analysis
// ============================================================
describe('GET /v1/cases/:caseId/forensic-analysis', () => {

  test('should return 401 without authentication', async () => {
    const res = await request(app)
      .get(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`);

    expect(res.status).toBe(401);
  });

  test('should return 404 when no analysis exists for case', async () => {
    // Case exists but has no forensic_analysis
    const caseNoAnalysis = { ...MOCK_CASE_WITH_DOCS, forensic_analysis: null };
    seedCaseWithDocs(caseNoAnalysis);

    const res = await request(app)
      .get(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
    expect(res.body.message).toContain('No forensic analysis found');
  });

  test('should return 404 when case does not exist', async () => {
    jest.spyOn(caseFileService, 'getCase').mockResolvedValue(null);

    const res = await request(app)
      .get('/v1/cases/nonexistent/forensic-analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
  });

  test('should return stored forensic analysis for previously analyzed case', async () => {
    const storedAnalysis = {
      caseId: TEST_CASE_ID,
      analyzedAt: '2024-06-15T10:30:00Z',
      documentsAnalyzed: 3,
      discrepancies: [
        { id: 'disc-001', type: 'amount_mismatch', severity: 'high', description: 'Interest rate mismatch' }
      ],
      timeline: { events: [], violations: [] },
      paymentVerification: null,
      summary: {
        totalDiscrepancies: 1,
        criticalFindings: 0,
        highFindings: 1,
        riskLevel: 'high',
        keyFindings: ['Interest rate mismatch'],
        recommendations: []
      }
    };

    const caseWithAnalysis = {
      ...MOCK_CASE_WITH_DOCS,
      forensic_analysis: storedAnalysis
    };
    seedCaseWithDocs(caseWithAnalysis);

    const res = await request(app)
      .get(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(200);
    expect(res.body.caseId).toBe(TEST_CASE_ID);
    expect(res.body.status).toBe('completed');
    expect(res.body.forensicAnalysis).toBeDefined();
    expect(res.body.forensicAnalysis.documentsAnalyzed).toBe(3);
    expect(res.body.forensicAnalysis.discrepancies).toHaveLength(1);
    expect(res.body.forensicAnalysis.summary.riskLevel).toBe('high');
  });

  test('should enforce user isolation (user A cannot access user B analysis)', async () => {
    // Seed case owned by OTHER user
    const otherUserCase = {
      ...MOCK_CASE_WITH_DOCS,
      id: 'case-other-user',
      user_id: OTHER_USER_ID,
      forensic_analysis: { caseId: 'case-other-user', summary: { riskLevel: 'high' } }
    };

    caseFileService.mockCases.set('case-other-user', {
      ...otherUserCase
    });

    // getCase spy checks user_id match
    jest.spyOn(caseFileService, 'getCase').mockImplementation(async ({ caseId, userId }) => {
      const stored = caseFileService.mockCases.get(caseId);
      if (!stored || stored.user_id !== userId) return null;
      return { ...stored };
    });

    // Request with TEST_USER_ID (from mock auth) should not see other user's case
    const res = await request(app)
      .get('/v1/cases/case-other-user/forensic-analysis')
      .set('Authorization', 'Bearer valid-token');

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('NotFound');
  });
});

// ============================================================
// END-TO-END FORENSIC FLOW
// ============================================================
describe('End-to-end forensic flow', () => {

  test('should process: trigger forensic analysis -> retrieve results', async () => {
    seedCaseWithDocs(MOCK_CASE_WITH_DOCS);
    setupComparisonMocks();

    // Step 1: Trigger forensic analysis
    const postRes = await request(app)
      .post(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token')
      .send({});

    expect(postRes.status).toBe(200);
    expect(postRes.body.status).toBe('completed');

    const forensicResult = postRes.body.forensicAnalysis;
    expect(forensicResult.caseId).toBe(TEST_CASE_ID);
    expect(forensicResult.documentsAnalyzed).toBeGreaterThanOrEqual(2);

    // Step 2: The orchestrator persists results via updateCase
    // Update the mock to reflect persistence
    const storedCase = caseFileService.mockCases.get(TEST_CASE_ID);
    expect(storedCase).toBeDefined();

    // Refresh the getCase spy to return the updated case (with forensic_analysis)
    jest.spyOn(caseFileService, 'getCase').mockImplementation(async ({ caseId, userId }) => {
      const stored = caseFileService.mockCases.get(caseId);
      if (!stored || stored.user_id !== userId) return null;
      return { ...stored };
    });

    // Step 3: Retrieve stored results
    const getRes = await request(app)
      .get(`/v1/cases/${TEST_CASE_ID}/forensic-analysis`)
      .set('Authorization', 'Bearer valid-token');

    expect(getRes.status).toBe(200);
    expect(getRes.body.status).toBe('completed');
    expect(getRes.body.forensicAnalysis).toBeDefined();
    expect(getRes.body.forensicAnalysis.caseId).toBe(TEST_CASE_ID);
  });
});
