/**
 * Schema Validation Integration Tests
 *
 * Tests all 13 Joi schemas with valid inputs, invalid inputs, and edge cases.
 * Calls schema.validate(input) directly — no Express or supertest needed.
 *
 * Schemas tested:
 *   Documents (4): uploadDocumentSchema, getDocumentsSchema, getDocumentSchema, deleteDocumentSchema
 *   Plaid (8): linkTokenSchema, exchangeTokenSchema, accountsSchema, transactionsSchema,
 *              itemSchema, updateWebhookSchema, deleteItemSchema, sandboxTokenSchema
 *   Claude (1): analyzeSchema
 */

const {
  uploadDocumentSchema,
  getDocumentsSchema,
  getDocumentSchema,
  deleteDocumentSchema
} = require('../../schemas/documents');

const {
  linkTokenSchema,
  exchangeTokenSchema,
  accountsSchema,
  transactionsSchema,
  itemSchema,
  updateWebhookSchema,
  deleteItemSchema,
  sandboxTokenSchema
} = require('../../schemas/plaid');

const {
  analyzeSchema
} = require('../../schemas/claude');

// ==============================================================================
// Document Schemas
// ==============================================================================
describe('Document schemas', () => {
  // ------------------------------------------------
  // uploadDocumentSchema
  // ------------------------------------------------
  describe('uploadDocumentSchema', () => {
    const validComplete = {
      documentId: 'doc-001',
      userId: 'user-123',
      fileName: 'mortgage-statement.pdf',
      content: 'base64-encoded-content-here',
      documentType: 'mortgage_statement',
      analysisResults: { score: 95 },
      metadata: { source: 'upload' }
    };

    const validMinimal = {
      documentId: 'doc-002',
      userId: 'user-456',
      fileName: 'doc.pdf',
      content: 'some-content'
    };

    test('accepts valid complete body', () => {
      const { error, value } = uploadDocumentSchema.validate(validComplete);
      expect(error).toBeUndefined();
      expect(value.documentId).toBe('doc-001');
      expect(value.documentType).toBe('mortgage_statement');
      expect(value.analysisResults).toEqual({ score: 95 });
      expect(value.metadata).toEqual({ source: 'upload' });
    });

    test('accepts valid minimal body (required fields only)', () => {
      const { error, value } = uploadDocumentSchema.validate(validMinimal);
      expect(error).toBeUndefined();
      expect(value.documentType).toBe('unknown'); // default
    });

    test('rejects missing required fields', () => {
      const { error } = uploadDocumentSchema.validate({}, { abortEarly: false });
      expect(error).toBeDefined();
      expect(error.details.length).toBeGreaterThanOrEqual(4); // documentId, userId, fileName, content
    });

    test('rejects missing documentId', () => {
      const { error } = uploadDocumentSchema.validate({
        userId: 'user-1', fileName: 'f.pdf', content: 'c'
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('documentId');
    });

    test('strips extra fields', () => {
      const { error, value } = uploadDocumentSchema.validate(
        { ...validMinimal, hackerField: 'malicious' },
        { stripUnknown: true }
      );
      expect(error).toBeUndefined();
      expect(value).not.toHaveProperty('hackerField');
    });

    test('trims whitespace from string fields', () => {
      const { error, value } = uploadDocumentSchema.validate({
        documentId: '  doc-trimmed  ',
        userId: '  user-trimmed  ',
        fileName: '  file.pdf  ',
        content: 'content-not-trimmed'
      });
      expect(error).toBeUndefined();
      expect(value.documentId).toBe('doc-trimmed');
      expect(value.userId).toBe('user-trimmed');
      expect(value.fileName).toBe('file.pdf');
    });
  });

  // ------------------------------------------------
  // getDocumentsSchema
  // ------------------------------------------------
  describe('getDocumentsSchema', () => {
    test('accepts valid query with all params', () => {
      const { error, value } = getDocumentsSchema.validate({
        userId: 'user-123',
        limit: 100,
        offset: 50
      });
      expect(error).toBeUndefined();
      expect(value.limit).toBe(100);
      expect(value.offset).toBe(50);
    });

    test('applies defaults for limit and offset', () => {
      const { error, value } = getDocumentsSchema.validate({
        userId: 'user-123'
      });
      expect(error).toBeUndefined();
      expect(value.limit).toBe(50);
      expect(value.offset).toBe(0);
    });

    test('rejects limit > 500', () => {
      const { error } = getDocumentsSchema.validate({
        userId: 'user-123',
        limit: 501
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('limit');
    });

    test('rejects offset < 0', () => {
      const { error } = getDocumentsSchema.validate({
        userId: 'user-123',
        offset: -1
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('offset');
    });

    test('rejects missing userId', () => {
      const { error } = getDocumentsSchema.validate({});
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('userId');
    });

    test('coerces string numbers for limit and offset', () => {
      const { error, value } = getDocumentsSchema.validate({
        userId: 'user-123',
        limit: '25',
        offset: '10'
      });
      expect(error).toBeUndefined();
      expect(value.limit).toBe(25);
      expect(value.offset).toBe(10);
    });
  });

  // ------------------------------------------------
  // getDocumentSchema
  // ------------------------------------------------
  describe('getDocumentSchema', () => {
    test('accepts valid userId', () => {
      const { error, value } = getDocumentSchema.validate({
        userId: 'user-789'
      });
      expect(error).toBeUndefined();
      expect(value.userId).toBe('user-789');
    });

    test('rejects missing userId', () => {
      const { error } = getDocumentSchema.validate({});
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('userId');
    });

    test('trims userId whitespace', () => {
      const { error, value } = getDocumentSchema.validate({
        userId: '  user-trimmed  '
      });
      expect(error).toBeUndefined();
      expect(value.userId).toBe('user-trimmed');
    });
  });

  // ------------------------------------------------
  // deleteDocumentSchema
  // ------------------------------------------------
  describe('deleteDocumentSchema', () => {
    test('accepts valid userId', () => {
      const { error, value } = deleteDocumentSchema.validate({
        userId: 'user-delete-123'
      });
      expect(error).toBeUndefined();
      expect(value.userId).toBe('user-delete-123');
    });

    test('rejects missing userId', () => {
      const { error } = deleteDocumentSchema.validate({});
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('userId');
    });
  });
});

// ==============================================================================
// Plaid Schemas
// ==============================================================================
describe('Plaid schemas', () => {
  // ------------------------------------------------
  // linkTokenSchema
  // ------------------------------------------------
  describe('linkTokenSchema', () => {
    test('accepts valid complete body', () => {
      const { error, value } = linkTokenSchema.validate({
        user_id: 'user-123',
        client_name: 'Mortgage Guardian',
        redirect_uri: 'https://example.com/callback',
        access_token: 'access-token-123',
        products: ['transactions', 'auth']
      });
      expect(error).toBeUndefined();
      expect(value.user_id).toBe('user-123');
      expect(value.products).toEqual(['transactions', 'auth']);
    });

    test('accepts valid minimal body (user_id only)', () => {
      const { error, value } = linkTokenSchema.validate({
        user_id: 'user-456'
      });
      expect(error).toBeUndefined();
      expect(value.user_id).toBe('user-456');
    });

    test('rejects user_id longer than 255 characters', () => {
      const { error } = linkTokenSchema.validate({
        user_id: 'x'.repeat(256)
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('user_id');
    });

    test('accepts user_id at exactly 255 characters', () => {
      const { error } = linkTokenSchema.validate({
        user_id: 'x'.repeat(255)
      });
      expect(error).toBeUndefined();
    });

    test('rejects products as non-array', () => {
      const { error } = linkTokenSchema.validate({
        user_id: 'user-123',
        products: 'transactions' // should be array
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('products');
    });

    test('rejects missing user_id', () => {
      const { error } = linkTokenSchema.validate({});
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('user_id');
    });

    test('rejects invalid redirect_uri', () => {
      const { error } = linkTokenSchema.validate({
        user_id: 'user-123',
        redirect_uri: 'not-a-uri'
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('redirect_uri');
    });
  });

  // ------------------------------------------------
  // exchangeTokenSchema
  // ------------------------------------------------
  describe('exchangeTokenSchema', () => {
    test('accepts valid public token', () => {
      const { error, value } = exchangeTokenSchema.validate({
        public_token: 'public-sandbox-abc123'
      });
      expect(error).toBeUndefined();
      expect(value.public_token).toBe('public-sandbox-abc123');
    });

    test('accepts with optional fields', () => {
      const { error, value } = exchangeTokenSchema.validate({
        public_token: 'public-production-xyz',
        user_id: 'user-123',
        institution_id: 'ins_456'
      });
      expect(error).toBeUndefined();
      expect(value.user_id).toBe('user-123');
      expect(value.institution_id).toBe('ins_456');
    });

    test('rejects token not starting with "public-"', () => {
      const { error } = exchangeTokenSchema.validate({
        public_token: 'invalid-token-format'
      });
      expect(error).toBeDefined();
      expect(error.message).toContain('Invalid public token format');
    });

    test('rejects missing public_token', () => {
      const { error } = exchangeTokenSchema.validate({});
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('public_token');
    });
  });

  // ------------------------------------------------
  // accountsSchema
  // ------------------------------------------------
  describe('accountsSchema', () => {
    test('accepts access token starting with "access-"', () => {
      const { error, value } = accountsSchema.validate({
        access_token: 'access-sandbox-abc123'
      });
      expect(error).toBeUndefined();
      expect(value.access_token).toBe('access-sandbox-abc123');
    });

    test('accepts access token starting with "access_sandbox-"', () => {
      const { error, value } = accountsSchema.validate({
        access_token: 'access_sandbox-token-xyz'
      });
      expect(error).toBeUndefined();
      expect(value.access_token).toBe('access_sandbox-token-xyz');
    });

    test('accepts with optional account_ids', () => {
      const { error, value } = accountsSchema.validate({
        access_token: 'access-prod-token',
        account_ids: ['acct-1', 'acct-2']
      });
      expect(error).toBeUndefined();
      expect(value.account_ids).toEqual(['acct-1', 'acct-2']);
    });

    test('rejects invalid access token format', () => {
      const { error } = accountsSchema.validate({
        access_token: 'invalid-token'
      });
      expect(error).toBeDefined();
      expect(error.message).toContain('Invalid access token format');
    });

    test('rejects missing access_token', () => {
      const { error } = accountsSchema.validate({});
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('access_token');
    });
  });

  // ------------------------------------------------
  // transactionsSchema
  // ------------------------------------------------
  describe('transactionsSchema', () => {
    const validComplete = {
      access_token: 'access-sandbox-txn',
      start_date: '2024-01-01',
      end_date: '2024-12-31',
      account_ids: ['acct-1'],
      count: 250,
      offset: 10
    };

    test('accepts valid complete body', () => {
      const { error, value } = transactionsSchema.validate(validComplete);
      expect(error).toBeUndefined();
      expect(value.count).toBe(250);
      expect(value.offset).toBe(10);
    });

    test('applies defaults for count and offset', () => {
      const { error, value } = transactionsSchema.validate({
        access_token: 'access-sandbox-txn',
        start_date: '2024-01-01',
        end_date: '2024-06-30'
      });
      expect(error).toBeUndefined();
      expect(value.count).toBe(100);
      expect(value.offset).toBe(0);
    });

    test('rejects invalid date format', () => {
      const { error } = transactionsSchema.validate({
        access_token: 'access-sandbox-txn',
        start_date: '01-01-2024', // wrong format
        end_date: '2024-12-31'
      });
      expect(error).toBeDefined();
      expect(error.message).toContain('YYYY-MM-DD');
    });

    test('rejects invalid end_date format', () => {
      const { error } = transactionsSchema.validate({
        access_token: 'access-sandbox-txn',
        start_date: '2024-01-01',
        end_date: 'December 31, 2024'
      });
      expect(error).toBeDefined();
      expect(error.message).toContain('YYYY-MM-DD');
    });

    test('rejects count out of range (> 500)', () => {
      const { error } = transactionsSchema.validate({
        access_token: 'access-sandbox-txn',
        start_date: '2024-01-01',
        end_date: '2024-12-31',
        count: 501
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('count');
    });

    test('rejects count < 1', () => {
      const { error } = transactionsSchema.validate({
        access_token: 'access-sandbox-txn',
        start_date: '2024-01-01',
        end_date: '2024-12-31',
        count: 0
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('count');
    });

    test('rejects negative offset', () => {
      const { error } = transactionsSchema.validate({
        access_token: 'access-sandbox-txn',
        start_date: '2024-01-01',
        end_date: '2024-12-31',
        offset: -1
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('offset');
    });

    test('rejects invalid access token', () => {
      const { error } = transactionsSchema.validate({
        access_token: 'bad-token',
        start_date: '2024-01-01',
        end_date: '2024-12-31'
      });
      expect(error).toBeDefined();
      expect(error.message).toContain('Invalid access token format');
    });
  });

  // ------------------------------------------------
  // itemSchema
  // ------------------------------------------------
  describe('itemSchema', () => {
    test('accepts valid access token', () => {
      const { error, value } = itemSchema.validate({
        access_token: 'access-sandbox-item-123'
      });
      expect(error).toBeUndefined();
      expect(value.access_token).toBe('access-sandbox-item-123');
    });

    test('rejects invalid access token format', () => {
      const { error } = itemSchema.validate({
        access_token: 'not-valid'
      });
      expect(error).toBeDefined();
      expect(error.message).toContain('Invalid access token format');
    });

    test('rejects missing access_token', () => {
      const { error } = itemSchema.validate({});
      expect(error).toBeDefined();
    });
  });

  // ------------------------------------------------
  // updateWebhookSchema
  // ------------------------------------------------
  describe('updateWebhookSchema', () => {
    test('accepts valid with https URL', () => {
      const { error, value } = updateWebhookSchema.validate({
        access_token: 'access-sandbox-wh',
        webhook: 'https://example.com/webhook'
      });
      expect(error).toBeUndefined();
      expect(value.webhook).toBe('https://example.com/webhook');
    });

    test('accepts valid with http URL', () => {
      const { error, value } = updateWebhookSchema.validate({
        access_token: 'access-sandbox-wh',
        webhook: 'http://localhost:3000/webhook'
      });
      expect(error).toBeUndefined();
      expect(value.webhook).toBe('http://localhost:3000/webhook');
    });

    test('rejects invalid URL', () => {
      const { error } = updateWebhookSchema.validate({
        access_token: 'access-sandbox-wh',
        webhook: 'not-a-url'
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('webhook');
    });

    test('rejects missing webhook', () => {
      const { error } = updateWebhookSchema.validate({
        access_token: 'access-sandbox-wh'
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('webhook');
    });

    test('rejects invalid access token', () => {
      const { error } = updateWebhookSchema.validate({
        access_token: 'bad-token',
        webhook: 'https://example.com/webhook'
      });
      expect(error).toBeDefined();
      expect(error.message).toContain('Invalid access token format');
    });
  });

  // ------------------------------------------------
  // deleteItemSchema
  // ------------------------------------------------
  describe('deleteItemSchema', () => {
    test('accepts valid access token', () => {
      const { error, value } = deleteItemSchema.validate({
        access_token: 'access-sandbox-del'
      });
      expect(error).toBeUndefined();
      expect(value.access_token).toBe('access-sandbox-del');
    });

    test('rejects invalid access token format', () => {
      const { error } = deleteItemSchema.validate({
        access_token: 'wrong-prefix-token'
      });
      expect(error).toBeDefined();
      expect(error.message).toContain('Invalid access token format');
    });

    test('rejects missing access_token', () => {
      const { error } = deleteItemSchema.validate({});
      expect(error).toBeDefined();
    });
  });

  // ------------------------------------------------
  // sandboxTokenSchema
  // ------------------------------------------------
  describe('sandboxTokenSchema', () => {
    test('accepts valid complete body', () => {
      const { error, value } = sandboxTokenSchema.validate({
        institution_id: 'ins_109508',
        initial_products: ['transactions', 'auth']
      });
      expect(error).toBeUndefined();
      expect(value.institution_id).toBe('ins_109508');
      expect(value.initial_products).toEqual(['transactions', 'auth']);
    });

    test('accepts empty body (all fields optional)', () => {
      const { error, value } = sandboxTokenSchema.validate({});
      expect(error).toBeUndefined();
      expect(value).toEqual({});
    });

    test('accepts with only institution_id', () => {
      const { error, value } = sandboxTokenSchema.validate({
        institution_id: 'ins_12345'
      });
      expect(error).toBeUndefined();
      expect(value.institution_id).toBe('ins_12345');
    });

    test('accepts with only initial_products', () => {
      const { error, value } = sandboxTokenSchema.validate({
        initial_products: ['transactions']
      });
      expect(error).toBeUndefined();
      expect(value.initial_products).toEqual(['transactions']);
    });
  });
});

// ==============================================================================
// Claude Schemas
// ==============================================================================
describe('Claude schemas', () => {
  // ------------------------------------------------
  // analyzeSchema
  // ------------------------------------------------
  describe('analyzeSchema', () => {
    test('accepts valid body with prompt only', () => {
      const { error, value } = analyzeSchema.validate({
        prompt: 'Analyze this mortgage document'
      });
      expect(error).toBeUndefined();
      expect(value.prompt).toBe('Analyze this mortgage document');
      expect(value.model).toBe('claude-3-5-sonnet-20241022'); // default
      expect(value.maxTokens).toBe(4096); // default
      expect(value.temperature).toBe(0.1); // default
    });

    test('accepts valid body with documentText only', () => {
      const { error, value } = analyzeSchema.validate({
        documentText: 'Mortgage statement content here...'
      });
      expect(error).toBeUndefined();
      expect(value.documentText).toBe('Mortgage statement content here...');
    });

    test('accepts valid body with both prompt and documentText', () => {
      const { error, value } = analyzeSchema.validate({
        prompt: 'Analyze for errors',
        documentText: 'Statement content...',
        model: 'claude-3-opus-20240229',
        maxTokens: 8192,
        temperature: 0.5,
        documentType: 'escrow_analysis'
      });
      expect(error).toBeUndefined();
      expect(value.prompt).toBe('Analyze for errors');
      expect(value.documentText).toBe('Statement content...');
      expect(value.model).toBe('claude-3-opus-20240229');
      expect(value.maxTokens).toBe(8192);
      expect(value.temperature).toBe(0.5);
      expect(value.documentType).toBe('escrow_analysis');
    });

    test('rejects body with neither prompt nor documentText (or() failure)', () => {
      const { error } = analyzeSchema.validate({
        model: 'claude-3-5-sonnet-20241022'
      });
      expect(error).toBeDefined();
      // or() constraint should produce an error about missing alternatives
      expect(error.message).toMatch(/prompt|documentText/);
    });

    test('rejects empty body', () => {
      const { error } = analyzeSchema.validate({});
      expect(error).toBeDefined();
    });

    test('rejects maxTokens below minimum (0)', () => {
      const { error } = analyzeSchema.validate({
        prompt: 'test',
        maxTokens: 0
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('maxTokens');
    });

    test('rejects maxTokens above maximum (100001)', () => {
      const { error } = analyzeSchema.validate({
        prompt: 'test',
        maxTokens: 100001
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('maxTokens');
    });

    test('rejects temperature below 0', () => {
      const { error } = analyzeSchema.validate({
        prompt: 'test',
        temperature: -0.1
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('temperature');
    });

    test('rejects temperature above 1', () => {
      const { error } = analyzeSchema.validate({
        prompt: 'test',
        temperature: 1.1
      });
      expect(error).toBeDefined();
      expect(error.details[0].path).toContain('temperature');
    });

    test('accepts temperature at boundaries (0 and 1)', () => {
      const { error: err0 } = analyzeSchema.validate({
        prompt: 'test',
        temperature: 0
      });
      expect(err0).toBeUndefined();

      const { error: err1 } = analyzeSchema.validate({
        prompt: 'test',
        temperature: 1
      });
      expect(err1).toBeUndefined();
    });

    test('accepts maxTokens at boundaries (1 and 100000)', () => {
      const { error: errMin } = analyzeSchema.validate({
        prompt: 'test',
        maxTokens: 1
      });
      expect(errMin).toBeUndefined();

      const { error: errMax } = analyzeSchema.validate({
        prompt: 'test',
        maxTokens: 100000
      });
      expect(errMax).toBeUndefined();
    });

    test('trims whitespace from string fields', () => {
      const { error, value } = analyzeSchema.validate({
        prompt: '  analyze this  ',
        documentType: '  mortgage  '
      });
      expect(error).toBeUndefined();
      expect(value.prompt).toBe('analyze this');
      expect(value.documentType).toBe('mortgage');
    });

    test('coerces string maxTokens to number', () => {
      const { error, value } = analyzeSchema.validate({
        prompt: 'test',
        maxTokens: '2048'
      });
      expect(error).toBeUndefined();
      expect(value.maxTokens).toBe(2048);
      expect(typeof value.maxTokens).toBe('number');
    });

    test('applies all defaults when only prompt provided', () => {
      const { error, value } = analyzeSchema.validate({
        prompt: 'test prompt'
      });
      expect(error).toBeUndefined();
      expect(value).toEqual({
        prompt: 'test prompt',
        model: 'claude-3-5-sonnet-20241022',
        maxTokens: 4096,
        temperature: 0.1
      });
    });
  });
});
