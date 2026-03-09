/**
 * Unit tests for PlaidCrossReferenceService
 *
 * Tests crossReferencePayments matching logic (12 cases) and
 * extractPaymentsFromAnalysis helper (4 cases). Pure data transformation —
 * no external API calls to mock.
 */

const plaidCrossReferenceService = require('../../services/plaidCrossReferenceService');

// ---------------------------------------------------------------------------
// Mock data helpers
// ---------------------------------------------------------------------------

function makeDocPayment(overrides = {}) {
  return {
    documentId: 'doc-001',
    documentType: 'servicing',
    documentSubtype: 'monthly_statement',
    date: '2024-01-01',
    amount: 1500.00,
    description: 'Monthly mortgage payment',
    fieldSource: 'monthlyPayment',
    ...overrides
  };
}

function makePlaidTxn(overrides = {}) {
  return {
    transactionId: 'txn-001',
    amount: 1500.00,
    date: '2024-01-01',
    name: 'MORTGAGE PAYMENT',
    merchantName: 'ABC Mortgage Co',
    category: ['Payment', 'Mortgage'],
    pending: false,
    ...overrides
  };
}

// ---------------------------------------------------------------------------
// crossReferencePayments tests
// ---------------------------------------------------------------------------

describe('PlaidCrossReferenceService', () => {
  describe('crossReferencePayments', () => {

    // Case 1: Perfect match
    test('should produce matched status with variance 0 for exact match', () => {
      const docPayments = [makeDocPayment()];
      const plaidTxns = [makePlaidTxn()];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.matchedPayments).toHaveLength(1);
      expect(result.matchedPayments[0]).toMatchObject({
        documentDate: '2024-01-01',
        documentAmount: 1500.00,
        transactionDate: '2024-01-01',
        transactionAmount: 1500.00,
        status: 'matched',
        variance: 0,
        documentId: 'doc-001',
        transactionId: 'txn-001'
      });
      expect(result.unmatchedDocumentPayments).toHaveLength(0);
      expect(result.unmatchedTransactions).toHaveLength(0);
    });

    // Case 2: Close match — amounts within tolerance
    test('should produce close_match when amounts differ within tolerance', () => {
      const docPayments = [makeDocPayment({ amount: 1500.00 })];
      const plaidTxns = [makePlaidTxn({ amount: 1500.01 })];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.matchedPayments).toHaveLength(1);
      expect(result.matchedPayments[0].status).toBe('close_match');
      expect(result.matchedPayments[0].variance).toBeCloseTo(0.01, 4);
    });

    // Case 3: Date tolerance — within 5-day default
    test('should match transactions within date tolerance', () => {
      const docPayments = [makeDocPayment({ date: '2024-01-01' })];
      const plaidTxns = [makePlaidTxn({ date: '2024-01-03' })];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.matchedPayments).toHaveLength(1);
      expect(result.matchedPayments[0].status).toBe('matched');
      expect(result.matchedPayments[0].transactionDate).toBe('2024-01-03');
    });

    // Case 4: Mismatch — amount outside tolerance
    test('should produce mismatch when amount differs significantly', () => {
      const docPayments = [makeDocPayment({ amount: 1500.00 })];
      const plaidTxns = [makePlaidTxn({ amount: 1200.00, date: '2024-01-01' })];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.matchedPayments).toHaveLength(1);
      expect(result.matchedPayments[0].status).toBe('mismatch');
      expect(result.matchedPayments[0].variance).toBe(300);
    });

    // Case 5: Unmatched document payment — no transaction within tolerance
    test('should report unmatched document payment when no transaction found', () => {
      const docPayments = [makeDocPayment({ date: '2024-01-01' })];
      const plaidTxns = [makePlaidTxn({ date: '2024-03-01' })]; // way outside date tolerance

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.unmatchedDocumentPayments).toHaveLength(1);
      expect(result.unmatchedDocumentPayments[0]).toMatchObject({
        date: '2024-01-01',
        amount: 1500.00,
        documentId: 'doc-001',
        description: 'Monthly mortgage payment',
        reason: expect.stringMatching(/no_matching_transaction|date_outside_tolerance/)
      });
    });

    // Case 6: Unmatched Plaid transaction
    test('should report unmatched Plaid transactions with possibleMatch hint', () => {
      const docPayments = [makeDocPayment({ date: '2024-01-01' })];
      const plaidTxns = [
        makePlaidTxn({ date: '2024-01-01' }), // will match doc payment
        makePlaidTxn({ transactionId: 'txn-002', date: '2024-02-01', amount: 1500.00 })
      ];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.matchedPayments).toHaveLength(1);
      expect(result.unmatchedTransactions).toHaveLength(1);
      expect(result.unmatchedTransactions[0]).toMatchObject({
        date: '2024-02-01',
        amount: 1500.00,
        transactionId: 'txn-002',
        name: 'MORTGAGE PAYMENT'
      });
      expect(result.unmatchedTransactions[0]).toHaveProperty('possibleMatch');
    });

    // Case 7: Empty inputs
    test('should return empty results for empty inputs without errors', () => {
      const result1 = plaidCrossReferenceService.crossReferencePayments([], []);
      expect(result1.matchedPayments).toHaveLength(0);
      expect(result1.unmatchedDocumentPayments).toHaveLength(0);
      expect(result1.unmatchedTransactions).toHaveLength(0);
      expect(result1.summary.totalDocumentPayments).toBe(0);
      expect(result1.summary.totalPlaidTransactions).toBe(0);
      expect(result1.summary.paymentVerified).toBe(true); // vacuously true

      const result2 = plaidCrossReferenceService.crossReferencePayments(
        [makeDocPayment()], []
      );
      expect(result2.unmatchedDocumentPayments).toHaveLength(1);
      expect(result2.summary.paymentVerified).toBe(false);

      const result3 = plaidCrossReferenceService.crossReferencePayments(
        [], [makePlaidTxn()]
      );
      expect(result3.unmatchedTransactions).toHaveLength(1);
    });

    // Case 8: Pending transactions excluded
    test('should exclude pending Plaid transactions from matching', () => {
      const docPayments = [makeDocPayment()];
      const plaidTxns = [makePlaidTxn({ pending: true })];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.matchedPayments).toHaveLength(0);
      expect(result.unmatchedDocumentPayments).toHaveLength(1);
      // Pending transactions should not appear in unmatched either
      expect(result.summary.totalPlaidTransactions).toBe(0);
    });

    // Case 9: Escrow analysis
    test('should produce escrow analysis when escrowDocumentedMonthly provided', () => {
      const docPayments = [makeDocPayment()];
      const plaidTxns = [
        makePlaidTxn(),
        makePlaidTxn({
          transactionId: 'txn-escrow-1',
          amount: 3500.00,
          date: '2024-01-15',
          name: 'PROPERTY TAX PAYMENT',
          category: ['Tax', 'Property Tax'],
          pending: false
        }),
        makePlaidTxn({
          transactionId: 'txn-escrow-2',
          amount: 1200.00,
          date: '2024-02-15',
          name: 'HOMEOWNERS INSURANCE',
          category: ['Insurance', 'Home Insurance'],
          pending: false
        })
      ];

      const result = plaidCrossReferenceService.crossReferencePayments(
        docPayments,
        plaidTxns,
        { escrowDocumentedMonthly: 350.00 }
      );

      expect(result.escrowAnalysis).not.toBeNull();
      expect(result.escrowAnalysis.documentedMonthlyEscrow).toBe(350.00);
      expect(result.escrowAnalysis.actualDisbursements.length).toBeGreaterThan(0);
      expect(typeof result.escrowAnalysis.discrepancy).toBe('number');
      expect(Array.isArray(result.escrowAnalysis.findings)).toBe(true);
    });

    // Case 10: Fee analysis
    test('should produce fee analysis when documentedFees provided', () => {
      const docPayments = [makeDocPayment()];
      const plaidTxns = [
        makePlaidTxn(),
        makePlaidTxn({
          transactionId: 'txn-fee-1',
          amount: 50.00,
          date: '2024-01-20',
          name: 'LATE FEE',
          category: ['Fee', 'Late Fee'],
          pending: false
        })
      ];

      const result = plaidCrossReferenceService.crossReferencePayments(
        docPayments,
        plaidTxns,
        {
          documentedFees: [
            { type: 'late_fee', amount: 35.00, documentId: 'doc-001' }
          ]
        }
      );

      expect(result.feeAnalysis).not.toBeNull();
      expect(result.feeAnalysis.documentedFees).toHaveLength(1);
      expect(result.feeAnalysis.transactionFees.length).toBeGreaterThan(0);
      expect(Array.isArray(result.feeAnalysis.irregularities)).toBe(true);
    });

    // Case 11: Multiple document payments competing for same transaction
    test('should pick best match when multiple doc payments could match same transaction', () => {
      const docPayments = [
        makeDocPayment({ documentId: 'doc-001', date: '2024-01-01', amount: 1500.00 }),
        makeDocPayment({ documentId: 'doc-002', date: '2024-01-02', amount: 1500.00 })
      ];
      const plaidTxns = [
        makePlaidTxn({ transactionId: 'txn-001', date: '2024-01-01', amount: 1500.00 })
      ];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      // Best match (exact date) should win
      expect(result.matchedPayments).toHaveLength(1);
      expect(result.matchedPayments[0].documentId).toBe('doc-001');
      expect(result.matchedPayments[0].transactionId).toBe('txn-001');
      // The other should be unmatched
      expect(result.unmatchedDocumentPayments).toHaveLength(1);
      expect(result.unmatchedDocumentPayments[0].documentId).toBe('doc-002');
    });

    // Case 12: Custom tolerance options override defaults
    test('should respect custom tolerance options', () => {
      const docPayments = [makeDocPayment({ date: '2024-01-01', amount: 1500.00 })];
      const plaidTxns = [makePlaidTxn({ date: '2024-01-08', amount: 1500.05 })];

      // Default tolerance (5 days, $0.01) — should NOT match (8 days out)
      const result1 = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);
      expect(result1.matchedPayments).toHaveLength(0);
      expect(result1.unmatchedDocumentPayments).toHaveLength(1);

      // Custom tolerance (10 days, $0.10) — should match
      const result2 = plaidCrossReferenceService.crossReferencePayments(
        docPayments,
        plaidTxns,
        { dateTolerance: 10, amountTolerance: 0.10 }
      );
      expect(result2.matchedPayments).toHaveLength(1);
      expect(result2.matchedPayments[0].status).toBe('close_match');
    });

    // Summary verification
    test('should produce correct summary with paymentVerified flag', () => {
      // 5 doc payments, 4 matching → 80% → paymentVerified = true
      const docPayments = [
        makeDocPayment({ documentId: 'doc-1', date: '2024-01-01' }),
        makeDocPayment({ documentId: 'doc-2', date: '2024-02-01' }),
        makeDocPayment({ documentId: 'doc-3', date: '2024-03-01' }),
        makeDocPayment({ documentId: 'doc-4', date: '2024-04-01' }),
        makeDocPayment({ documentId: 'doc-5', date: '2024-05-01' })
      ];
      const plaidTxns = [
        makePlaidTxn({ transactionId: 'txn-1', date: '2024-01-01' }),
        makePlaidTxn({ transactionId: 'txn-2', date: '2024-02-01' }),
        makePlaidTxn({ transactionId: 'txn-3', date: '2024-03-01' }),
        makePlaidTxn({ transactionId: 'txn-4', date: '2024-04-01' })
      ];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.summary.totalDocumentPayments).toBe(5);
      expect(result.summary.totalPlaidTransactions).toBe(4);
      expect(result.summary.matched).toBe(4);
      expect(result.summary.unmatched).toBe(1);
      expect(result.summary.paymentVerified).toBe(true); // 4/5 = 80%
    });

    test('should set paymentVerified false when below 80% threshold', () => {
      // 5 doc payments, only 3 matching → 60% → paymentVerified = false
      const docPayments = [
        makeDocPayment({ documentId: 'doc-1', date: '2024-01-01' }),
        makeDocPayment({ documentId: 'doc-2', date: '2024-02-01' }),
        makeDocPayment({ documentId: 'doc-3', date: '2024-03-01' }),
        makeDocPayment({ documentId: 'doc-4', date: '2024-04-01' }),
        makeDocPayment({ documentId: 'doc-5', date: '2024-05-01' })
      ];
      const plaidTxns = [
        makePlaidTxn({ transactionId: 'txn-1', date: '2024-01-01' }),
        makePlaidTxn({ transactionId: 'txn-2', date: '2024-02-01' }),
        makePlaidTxn({ transactionId: 'txn-3', date: '2024-03-01' })
      ];

      const result = plaidCrossReferenceService.crossReferencePayments(docPayments, plaidTxns);

      expect(result.summary.paymentVerified).toBe(false); // 3/5 = 60%
    });
  });

  // ---------------------------------------------------------------------------
  // extractPaymentsFromAnalysis tests
  // ---------------------------------------------------------------------------

  describe('extractPaymentsFromAnalysis', () => {

    // Case 1: Monthly statement with monthlyPayment + paymentDueDate
    test('should extract payment from monthly statement analysis', () => {
      const reports = [
        {
          documentId: 'doc-001',
          documentType: 'servicing',
          documentSubtype: 'monthly_statement',
          extractedData: {
            amounts: { monthlyPayment: 1523.47 },
            dates: { paymentDueDate: '2024-02-01' }
          },
          error: false
        }
      ];

      const payments = plaidCrossReferenceService.extractPaymentsFromAnalysis(reports);

      expect(payments).toHaveLength(1);
      expect(payments[0]).toMatchObject({
        documentId: 'doc-001',
        documentType: 'servicing',
        documentSubtype: 'monthly_statement',
        date: '2024-02-01',
        amount: 1523.47,
        fieldSource: 'monthlyPayment'
      });
      expect(payments[0].description).toBeDefined();
    });

    // Case 2: Payment history with multiple entries
    test('should extract multiple payments from payment history', () => {
      const reports = [
        {
          documentId: 'doc-002',
          documentType: 'servicing',
          documentSubtype: 'payment_history',
          extractedData: {
            payments: [
              { date: '2024-01-01', amount: 1500.00 },
              { date: '2024-02-01', amount: 1500.00 },
              { date: '2024-03-01', amount: 1500.00 }
            ]
          },
          error: false
        }
      ];

      const payments = plaidCrossReferenceService.extractPaymentsFromAnalysis(reports);

      expect(payments).toHaveLength(3);
      payments.forEach(p => {
        expect(p.documentId).toBe('doc-002');
        expect(p.amount).toBe(1500.00);
        expect(p.documentType).toBe('servicing');
        expect(p.documentSubtype).toBe('payment_history');
      });
    });

    // Case 3: Document without payment fields → empty array
    test('should return empty array for document without payment fields', () => {
      const reports = [
        {
          documentId: 'doc-003',
          documentType: 'origination',
          documentSubtype: 'closing_disclosure',
          extractedData: {
            amounts: { loanAmount: 250000, cashToClose: 12500 },
            rates: { interestRate: 6.25 }
          },
          error: false
        }
      ];

      const payments = plaidCrossReferenceService.extractPaymentsFromAnalysis(reports);

      expect(payments).toHaveLength(0);
    });

    // Case 4: Analysis report with error → skip
    test('should skip reports with error flag', () => {
      const reports = [
        {
          documentId: 'doc-004',
          documentType: 'servicing',
          documentSubtype: 'monthly_statement',
          extractedData: {
            amounts: { monthlyPayment: 1523.47 },
            dates: { paymentDueDate: '2024-02-01' }
          },
          error: true
        }
      ];

      const payments = plaidCrossReferenceService.extractPaymentsFromAnalysis(reports);

      expect(payments).toHaveLength(0);
    });

    // Mixed input — combines multiple report types
    test('should handle mixed reports correctly', () => {
      const reports = [
        {
          documentId: 'doc-stmt',
          documentType: 'servicing',
          documentSubtype: 'monthly_statement',
          extractedData: {
            amounts: { monthlyPayment: 1500.00 },
            dates: { paymentDueDate: '2024-01-01' }
          },
          error: false
        },
        {
          documentId: 'doc-err',
          documentType: 'servicing',
          documentSubtype: 'monthly_statement',
          extractedData: {
            amounts: { monthlyPayment: 1600.00 },
            dates: { paymentDueDate: '2024-02-01' }
          },
          error: true
        },
        {
          documentId: 'doc-hist',
          documentType: 'servicing',
          documentSubtype: 'payment_history',
          extractedData: {
            payments: [
              { date: '2024-03-01', amount: 1500.00 }
            ]
          },
          error: false
        },
        {
          documentId: 'doc-other',
          documentType: 'origination',
          documentSubtype: 'closing_disclosure',
          extractedData: {
            amounts: { loanAmount: 250000 }
          },
          error: false
        }
      ];

      const payments = plaidCrossReferenceService.extractPaymentsFromAnalysis(reports);

      // 1 from statement + 1 from payment history = 2 (error skipped, closing has no payments)
      expect(payments).toHaveLength(2);
      const ids = payments.map(p => p.documentId);
      expect(ids).toContain('doc-stmt');
      expect(ids).toContain('doc-hist');
      expect(ids).not.toContain('doc-err');
    });
  });
});
