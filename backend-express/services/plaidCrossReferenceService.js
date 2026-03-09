/**
 * Plaid Transaction Cross-Reference Service
 *
 * Matches document-extracted payment data against actual Plaid bank transactions
 * to detect payment discrepancies, misapplied payments, escrow errors, and fee
 * irregularities. Pure data transformation — no external API calls.
 *
 * Plaid amount convention: positive = money leaving account (debits/payments),
 * negative = deposits/credits.
 */

const { createLogger } = require('../utils/logger');
const logger = createLogger('plaid-cross-reference');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_DATE_TOLERANCE = 5;     // days
const DEFAULT_AMOUNT_TOLERANCE = 0.01; // dollars
const VERIFICATION_THRESHOLD = 0.80;   // 80% matched/close_match → verified

/** Keywords that identify escrow-related transactions */
const ESCROW_KEYWORDS = [
  'tax', 'property tax', 'insurance', 'home insurance', 'homeowners insurance',
  'hazard insurance', 'escrow', 'hoa', 'flood insurance', 'pmi',
  'mortgage insurance', 'county tax'
];

/** Keywords that identify fee-related transactions */
const FEE_KEYWORDS = [
  'late fee', 'nsf fee', 'insufficient funds', 'returned check',
  'inspection fee', 'bpo fee', 'appraisal fee', 'legal fee',
  'attorney fee', 'foreclosure fee', 'modification fee',
  'processing fee', 'service fee', 'convenience fee'
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Calculate absolute day difference between two YYYY-MM-DD date strings.
 * @param {string} dateA
 * @param {string} dateB
 * @returns {number} Absolute day difference
 */
function daysBetween(dateA, dateB) {
  const a = new Date(dateA + 'T00:00:00Z');
  const b = new Date(dateB + 'T00:00:00Z');
  return Math.abs(Math.round((a - b) / (1000 * 60 * 60 * 24)));
}

/**
 * Check if a transaction name/category matches any keywords.
 * @param {{ name: string, category: string[] }} txn
 * @param {string[]} keywords
 * @returns {boolean}
 */
function matchesKeywords(txn, keywords) {
  const searchText = [
    txn.name || '',
    txn.merchantName || '',
    ...(Array.isArray(txn.category) ? txn.category : [])
  ].join(' ').toLowerCase();

  return keywords.some(kw => searchText.includes(kw.toLowerCase()));
}

/**
 * Classify a fee transaction type from its name/category.
 * @param {{ name: string, category: string[] }} txn
 * @returns {string}
 */
function classifyFeeType(txn) {
  const text = [txn.name || '', ...(Array.isArray(txn.category) ? txn.category : [])].join(' ').toLowerCase();
  if (text.includes('late')) return 'late_fee';
  if (text.includes('nsf') || text.includes('insufficient')) return 'nsf_fee';
  if (text.includes('inspection')) return 'inspection_fee';
  if (text.includes('legal') || text.includes('attorney')) return 'legal_fee';
  if (text.includes('appraisal') || text.includes('bpo')) return 'appraisal_fee';
  return 'other_fee';
}

// ---------------------------------------------------------------------------
// PlaidCrossReferenceService
// ---------------------------------------------------------------------------

class PlaidCrossReferenceService {
  /**
   * Cross-reference document payment data against Plaid bank transactions.
   *
   * @param {Array} documentPayments - Payments extracted from documents
   * @param {Array} plaidTransactions - Raw Plaid transactions
   * @param {Object} [options={}] - Matching options
   * @returns {Object} Cross-reference result
   */
  crossReferencePayments(documentPayments = [], plaidTransactions = [], options = {}) {
    const dateTolerance = options.dateTolerance ?? DEFAULT_DATE_TOLERANCE;
    const amountTolerance = options.amountTolerance ?? DEFAULT_AMOUNT_TOLERANCE;
    const escrowDocumentedMonthly = options.escrowDocumentedMonthly ?? null;
    const documentedFees = options.documentedFees ?? [];

    // Step 1: Filter out pending transactions
    const activeTxns = plaidTransactions.filter(t => !t.pending);

    // Step 2: Sort both by date
    const sortedDocPayments = [...documentPayments].sort((a, b) => a.date.localeCompare(b.date));
    const sortedTxns = [...activeTxns].sort((a, b) => a.date.localeCompare(b.date));

    // Step 3 & 4: Greedy matching
    const matchedPayments = [];
    const usedTxnIds = new Set();
    const matchedDocIds = new Set();

    // Build all candidate pairs with scores
    const candidates = [];
    for (const doc of sortedDocPayments) {
      for (const txn of sortedTxns) {
        const dateDiff = daysBetween(doc.date, txn.date);
        if (dateDiff > dateTolerance) continue;

        const amountDiff = Math.abs(doc.amount - txn.amount);
        // Score: lower is better (date diff in days + amount diff scaled)
        const score = dateDiff + amountDiff;
        candidates.push({ doc, txn, dateDiff, amountDiff, score });
      }
    }

    // Sort by score (best first) for greedy matching
    candidates.sort((a, b) => a.score - b.score);

    for (const { doc, txn, dateDiff, amountDiff } of candidates) {
      if (usedTxnIds.has(txn.transactionId) || matchedDocIds.has(doc.documentId + '|' + doc.date)) continue;

      let status;
      if (amountDiff === 0) {
        status = 'matched';
      } else if (amountDiff <= amountTolerance) {
        status = 'close_match';
      } else {
        status = 'mismatch';
      }

      matchedPayments.push({
        documentDate: doc.date,
        documentAmount: doc.amount,
        transactionDate: txn.date,
        transactionAmount: txn.amount,
        status,
        variance: amountDiff,
        documentId: doc.documentId,
        transactionId: txn.transactionId
      });

      usedTxnIds.add(txn.transactionId);
      matchedDocIds.add(doc.documentId + '|' + doc.date);
    }

    // Step 5: Unmatched document payments
    const unmatchedDocumentPayments = sortedDocPayments
      .filter(doc => !matchedDocIds.has(doc.documentId + '|' + doc.date))
      .map(doc => {
        // Determine reason
        let reason = 'no_matching_transaction';
        // Check if there was a candidate that didn't qualify
        const nearestTxn = sortedTxns
          .filter(t => !usedTxnIds.has(t.transactionId))
          .sort((a, b) => daysBetween(doc.date, a.date) - daysBetween(doc.date, b.date))[0];

        if (nearestTxn) {
          const dd = daysBetween(doc.date, nearestTxn.date);
          const ad = Math.abs(doc.amount - nearestTxn.amount);
          if (dd > dateTolerance) reason = 'date_outside_tolerance';
          else if (ad > amountTolerance) reason = 'amount_outside_tolerance';
        }

        return {
          date: doc.date,
          amount: doc.amount,
          documentId: doc.documentId,
          description: doc.description || '',
          reason
        };
      });

    // Step 6: Unmatched Plaid transactions
    const unmatchedTransactions = sortedTxns
      .filter(txn => !usedTxnIds.has(txn.transactionId))
      .map(txn => {
        // Find nearest doc payment as possibleMatch hint
        let possibleMatch = null;
        if (sortedDocPayments.length > 0) {
          const nearest = sortedDocPayments
            .sort((a, b) => {
              const scoreA = daysBetween(txn.date, a.date) + Math.abs(txn.amount - a.amount);
              const scoreB = daysBetween(txn.date, b.date) + Math.abs(txn.amount - b.amount);
              return scoreA - scoreB;
            })[0];
          possibleMatch = nearest ? nearest.documentId : null;
        }

        return {
          date: txn.date,
          amount: txn.amount,
          transactionId: txn.transactionId,
          name: txn.name || '',
          possibleMatch
        };
      });

    // Escrow analysis
    const escrowAnalysis = this._analyzeEscrow(activeTxns, escrowDocumentedMonthly);

    // Fee analysis
    const feeAnalysis = this._analyzeFees(activeTxns, documentedFees);

    // Summary
    const matchedCount = matchedPayments.filter(m => m.status === 'matched').length;
    const closeMatchCount = matchedPayments.filter(m => m.status === 'close_match').length;
    const totalDoc = documentPayments.length;

    const verifiedRatio = totalDoc > 0
      ? (matchedCount + closeMatchCount) / totalDoc
      : 1; // vacuously true when no doc payments

    const summary = {
      totalDocumentPayments: totalDoc,
      totalPlaidTransactions: activeTxns.length,
      matched: matchedCount,
      closeMatches: closeMatchCount,
      unmatched: unmatchedDocumentPayments.length,
      paymentVerified: verifiedRatio >= VERIFICATION_THRESHOLD
    };

    logger.debug('Cross-reference complete', {
      docPayments: totalDoc,
      plaidTxns: activeTxns.length,
      matched: matchedCount,
      closeMatches: closeMatchCount,
      unmatched: unmatchedDocumentPayments.length,
      verified: summary.paymentVerified
    });

    return {
      matchedPayments,
      unmatchedDocumentPayments,
      unmatchedTransactions,
      escrowAnalysis,
      feeAnalysis,
      summary
    };
  }

  /**
   * Extract payment data from analysis reports.
   *
   * @param {Array} analysisReports - Array of document analysis report objects
   * @returns {Array} Extracted document payments
   */
  extractPaymentsFromAnalysis(analysisReports = []) {
    const payments = [];

    for (const report of analysisReports) {
      // Case 4: Skip error reports
      if (report.error) continue;

      const { documentId, documentType, documentSubtype, extractedData } = report;
      if (!extractedData) continue;

      // Case 2: Payment history with multiple entries
      if (extractedData.payments && Array.isArray(extractedData.payments)) {
        for (const entry of extractedData.payments) {
          if (entry.date && entry.amount != null) {
            payments.push({
              documentId,
              documentType,
              documentSubtype,
              date: entry.date,
              amount: entry.amount,
              description: entry.description || `Payment from ${documentSubtype}`,
              fieldSource: 'payments'
            });
          }
        }
        continue;
      }

      // Case 1: Monthly statement with monthlyPayment + paymentDueDate
      const monthlyPayment = extractedData.amounts?.monthlyPayment;
      const paymentDueDate = extractedData.dates?.paymentDueDate;

      if (monthlyPayment != null && paymentDueDate) {
        payments.push({
          documentId,
          documentType,
          documentSubtype,
          date: paymentDueDate,
          amount: monthlyPayment,
          description: `Monthly payment from ${documentSubtype}`,
          fieldSource: 'monthlyPayment'
        });
      }
    }

    logger.debug('Extracted payments from analysis', { reportCount: analysisReports.length, paymentCount: payments.length });

    return payments;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /**
   * Analyze escrow disbursements vs documented monthly escrow.
   * @private
   */
  _analyzeEscrow(transactions, documentedMonthlyEscrow) {
    if (documentedMonthlyEscrow == null) return null;

    const escrowTxns = transactions.filter(txn => matchesKeywords(txn, ESCROW_KEYWORDS));

    const actualDisbursements = escrowTxns.map(txn => ({
      date: txn.date,
      amount: txn.amount,
      description: txn.name || 'Escrow disbursement'
    }));

    const totalDisbursed = actualDisbursements.reduce((sum, d) => sum + d.amount, 0);

    // Estimate expected escrow over the period covered by disbursements
    let expectedEscrow = 0;
    if (actualDisbursements.length > 0) {
      const dates = actualDisbursements.map(d => new Date(d.date + 'T00:00:00Z'));
      const minDate = new Date(Math.min(...dates));
      const maxDate = new Date(Math.max(...dates));
      const monthSpan = Math.max(1, Math.round((maxDate - minDate) / (1000 * 60 * 60 * 24 * 30.44)) + 1);
      expectedEscrow = documentedMonthlyEscrow * monthSpan;
    }

    const discrepancy = Math.abs(totalDisbursed - expectedEscrow);

    const findings = [];
    if (discrepancy > 0.01) {
      findings.push(
        `Escrow discrepancy of $${discrepancy.toFixed(2)} detected. ` +
        `Documented monthly escrow: $${documentedMonthlyEscrow.toFixed(2)}, ` +
        `total disbursements: $${totalDisbursed.toFixed(2)}.`
      );
    }

    if (actualDisbursements.length === 0) {
      findings.push('No escrow-related disbursements found in Plaid transactions.');
    }

    return {
      documentedMonthlyEscrow: documentedMonthlyEscrow,
      actualDisbursements,
      discrepancy,
      findings
    };
  }

  /**
   * Analyze fees: compare documented fees vs fee-like Plaid transactions.
   * @private
   */
  _analyzeFees(transactions, documentedFees) {
    if (!documentedFees || documentedFees.length === 0) {
      // Check if there are undocumented fee transactions even without documented fees
      const feeTxns = transactions.filter(txn => matchesKeywords(txn, FEE_KEYWORDS));
      if (feeTxns.length === 0) return null;

      const transactionFees = feeTxns.map(txn => ({
        type: classifyFeeType(txn),
        amount: txn.amount,
        transactionDate: txn.date,
        transactionId: txn.transactionId
      }));

      return {
        documentedFees: [],
        transactionFees,
        irregularities: transactionFees.map(tf => ({
          description: `Undocumented ${tf.type} of $${tf.amount.toFixed(2)} on ${tf.transactionDate}`,
          severity: tf.amount >= 100 ? 'high' : 'medium',
          amount: tf.amount
        }))
      };
    }

    const feeTxns = transactions.filter(txn => matchesKeywords(txn, FEE_KEYWORDS));

    const transactionFees = feeTxns.map(txn => ({
      type: classifyFeeType(txn),
      amount: txn.amount,
      transactionDate: txn.date,
      transactionId: txn.transactionId
    }));

    const irregularities = [];

    // Check for undocumented transaction fees
    for (const tf of transactionFees) {
      const documented = documentedFees.find(df =>
        df.type === tf.type && Math.abs(df.amount - tf.amount) < 0.01
      );
      if (!documented) {
        irregularities.push({
          description: `Undocumented ${tf.type} of $${tf.amount.toFixed(2)} on ${tf.transactionDate}`,
          severity: tf.amount >= 100 ? 'high' : 'medium',
          amount: tf.amount
        });
      }
    }

    // Check for documented fees with amount mismatches in transactions
    for (const df of documentedFees) {
      const matchingTxn = transactionFees.find(tf => tf.type === df.type);
      if (matchingTxn && Math.abs(matchingTxn.amount - df.amount) >= 0.01) {
        irregularities.push({
          description: `Fee amount mismatch: documented ${df.type} $${df.amount.toFixed(2)} vs actual $${matchingTxn.amount.toFixed(2)}`,
          severity: 'high',
          amount: Math.abs(matchingTxn.amount - df.amount)
        });
      }
    }

    return {
      documentedFees,
      transactionFees,
      irregularities
    };
  }
}

module.exports = new PlaidCrossReferenceService();
