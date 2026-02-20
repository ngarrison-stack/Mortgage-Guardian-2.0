/**
 * Database Fixture Factories
 *
 * Factory functions that create plain JavaScript objects matching the data
 * structures used by the application's services and database schema.
 * These fixtures are designed for use with mocked Supabase client - they
 * return plain objects, not actual database records.
 *
 * All factories accept optional overrides and provide sensible defaults.
 * Timestamps use ISO 8601 format via new Date().toISOString().
 *
 * Usage:
 *   const { createTestUser, createTestDocument } = require('../fixtures/dbFixtures');
 *   const user = createTestUser({ email: 'custom@test.com' });
 *   const doc = createTestDocument({ userId: user.id });
 */

const { v4: uuidv4 } = require('uuid');

// Counter for generating sequential IDs when uuid is not available
let _idCounter = 0;

/**
 * Generate a unique ID. Uses uuid if available, falls back to a simple counter.
 * @returns {string} Unique identifier
 */
function generateId() {
  try {
    return uuidv4();
  } catch {
    _idCounter++;
    return `test-id-${_idCounter}-${Date.now()}`;
  }
}

/**
 * Create a test user fixture.
 *
 * Matches the user structure expected by Supabase auth and the documents table
 * (user_id foreign key). The shape mirrors supabase.auth.getUser() response data.
 *
 * @param {Object} [overrides={}] - Override default values
 * @param {string} [overrides.userId='test-user-id'] - User ID
 * @param {string} [overrides.email='test@example.com'] - User email
 * @param {string} [overrides.name='Test User'] - Display name
 * @param {string} [overrides.role='authenticated'] - User role
 * @returns {Object} User fixture object
 */
function createTestUser({
  userId = 'test-user-id',
  email = 'test@example.com',
  name = 'Test User',
  role = 'authenticated'
} = {}) {
  const now = new Date().toISOString();

  return {
    id: userId,
    email,
    app_metadata: {
      provider: 'email'
    },
    user_metadata: {
      name
    },
    aud: 'authenticated',
    role,
    created_at: now,
    updated_at: now
  };
}

/**
 * Create a test document fixture.
 *
 * Matches the documents table schema used by documentService.js:
 *   - document_id, user_id, file_name, document_type, status,
 *     storage_path, analysis_results, metadata, created_at, updated_at
 *
 * @param {Object} [overrides={}] - Override default values
 * @param {string} [overrides.documentId] - Document ID (auto-generated if omitted)
 * @param {string} [overrides.userId='test-user-id'] - Owning user ID
 * @param {string} [overrides.fileName='test-document.pdf'] - File name
 * @param {string} [overrides.documentType='mortgage_statement'] - Document type
 * @param {string} [overrides.status='uploaded'] - Processing status
 * @param {Object} [overrides.metadata={}] - Additional metadata
 * @returns {Object} Document fixture object
 */
function createTestDocument({
  documentId,
  userId = 'test-user-id',
  fileName = 'test-document.pdf',
  documentType = 'mortgage_statement',
  status = 'uploaded',
  metadata = {}
} = {}) {
  const id = documentId || generateId();
  const now = new Date().toISOString();

  return {
    document_id: id,
    user_id: userId,
    file_name: fileName,
    document_type: documentType,
    status,
    storage_path: `documents/${userId}/${id}`,
    analysis_results: null,
    metadata,
    created_at: now,
    updated_at: now
  };
}

/**
 * Create a test analysis result fixture.
 *
 * Matches the analysis result structure returned by claudeService.analyzeDocument()
 * and stored in the documents table's analysis_results column.
 *
 * @param {Object} [overrides={}] - Override default values
 * @param {string} [overrides.documentId] - Associated document ID (auto-generated if omitted)
 * @param {number} [overrides.confidence=0.95] - Overall confidence score (0-1)
 * @param {string} [overrides.model='claude-3-5-sonnet-20241022'] - Model used
 * @param {Array}  [overrides.issues] - Detected issues array
 * @returns {Object} Analysis result fixture object
 */
function createTestAnalysis({
  documentId,
  confidence = 0.95,
  model = 'claude-3-5-sonnet-20241022',
  issues
} = {}) {
  const id = documentId || generateId();
  const now = new Date().toISOString();

  const defaultIssues = [
    {
      title: 'Escrow Calculation Discrepancy',
      description: 'The escrow payment amount does not match the sum of projected disbursements.',
      severity: 'Medium',
      category: 'Escrow',
      potentialImpact: 450
    }
  ];

  return {
    document_id: id,
    confidence,
    model,
    summary: 'Test analysis of mortgage document',
    keyFigures: {
      principalBalance: 250000,
      interestRate: 3.75,
      monthlyPayment: 1158.04,
      escrowBalance: 3200.00
    },
    issues: issues || defaultIssues,
    recommendations: [
      'Request an escrow analysis from your servicer',
      'Verify property tax amounts with your county assessor'
    ],
    usage: {
      inputTokens: 1250,
      outputTokens: 480
    },
    analyzed_at: now
  };
}

/**
 * Create a test Plaid transaction fixture.
 *
 * Matches the transaction structure returned by plaidService.getTransactions()
 * and the Plaid API transaction object format.
 *
 * @param {Object} [overrides={}] - Override default values
 * @param {string} [overrides.transactionId] - Transaction ID (auto-generated if omitted)
 * @param {string} [overrides.accountId='test-account-id'] - Associated account ID
 * @param {number} [overrides.amount=1000] - Transaction amount (positive = debit)
 * @param {string} [overrides.date] - Transaction date in YYYY-MM-DD format
 * @param {string} [overrides.name='Mortgage Payment'] - Transaction name/description
 * @param {string} [overrides.category='Payment'] - Transaction category
 * @param {string} [overrides.merchantName='Wells Fargo Home Mortgage'] - Merchant name
 * @returns {Object} Plaid transaction fixture object
 */
function createTestTransaction({
  transactionId,
  accountId = 'test-account-id',
  amount = 1000,
  date,
  name = 'Mortgage Payment',
  category = 'Payment',
  merchantName = 'Wells Fargo Home Mortgage'
} = {}) {
  const id = transactionId || generateId();
  const transactionDate = date || new Date().toISOString().split('T')[0];

  return {
    transaction_id: id,
    account_id: accountId,
    amount,
    iso_currency_code: 'USD',
    date: transactionDate,
    datetime: null,
    authorized_date: transactionDate,
    name,
    merchant_name: merchantName,
    category: [category],
    category_id: '16001000',
    pending: false,
    payment_channel: 'online',
    transaction_type: 'special',
    location: {
      address: null,
      city: null,
      region: null,
      postal_code: null,
      country: null
    },
    payment_meta: {
      reference_number: null,
      ppd_id: null,
      payee: null
    }
  };
}

/**
 * Reset the internal ID counter (useful between test suites)
 */
function resetFixtures() {
  _idCounter = 0;
}

module.exports = {
  createTestUser,
  createTestDocument,
  createTestAnalysis,
  createTestTransaction,
  resetFixtures
};
