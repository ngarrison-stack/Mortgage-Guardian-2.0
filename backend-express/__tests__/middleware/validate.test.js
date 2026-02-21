/**
 * Validate Middleware Unit Tests
 *
 * Tests the validate middleware factory in isolation.
 * Uses Joi directly to create test schemas — does NOT import endpoint-specific schemas.
 *
 * Covers:
 *   - validate(schema) returns Express middleware function
 *   - Valid body input: calls next(), replaces req.body with validated value
 *   - Invalid body input: returns 400 with { error: 'Bad Request', message: '...' }
 *   - stripUnknown: extra fields removed from req.body
 *   - abortEarly: false — multiple validation errors in single message
 *   - Type coercion: string "123" coerced to number 123
 *   - Query source: validate(schema, 'query') validates req.query
 *   - Params source: validate(schema, 'params') validates req.params
 */

const Joi = require('joi');
const { validate } = require('../../middleware/validate');

/**
 * Create mock Express req/res/next objects for middleware testing
 */
function createMockReqResNext(overrides = {}) {
  const req = {
    body: {},
    query: {},
    params: {},
    ...overrides
  };

  const res = {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis()
  };

  const next = jest.fn();

  return { req, res, next };
}

describe('validate middleware', () => {
  // ==================================================
  // Factory behavior
  // ==================================================
  describe('factory behavior', () => {
    test('returns an Express middleware function', () => {
      const schema = Joi.object({ name: Joi.string() });
      const middleware = validate(schema);

      expect(typeof middleware).toBe('function');
      expect(middleware.length).toBe(3); // (req, res, next)
    });

    test('defaults to body source when no source specified', () => {
      const schema = Joi.object({ name: Joi.string().required() });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: { name: 'test' }
      });

      middleware(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.body).toEqual({ name: 'test' });
    });
  });

  // ==================================================
  // Valid body input
  // ==================================================
  describe('valid body input', () => {
    test('calls next() when body passes validation', () => {
      const schema = Joi.object({
        name: Joi.string().required(),
        age: Joi.number().integer()
      });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: { name: 'Alice', age: 30 }
      });

      middleware(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith(); // called with no arguments
      expect(res.status).not.toHaveBeenCalled();
      expect(res.json).not.toHaveBeenCalled();
    });

    test('replaces req.body with validated value', () => {
      const schema = Joi.object({
        email: Joi.string().trim().required()
      });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: { email: '  user@example.com  ' }
      });

      middleware(req, res, next);

      expect(req.body).toEqual({ email: 'user@example.com' });
    });
  });

  // ==================================================
  // Invalid body input
  // ==================================================
  describe('invalid body input', () => {
    test('returns 400 with error format { error, message }', () => {
      const schema = Joi.object({
        name: Joi.string().required()
      });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: {} // missing required name
      });

      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledTimes(1);

      const responseBody = res.json.mock.calls[0][0];
      expect(responseBody).toHaveProperty('error', 'Bad Request');
      expect(responseBody).toHaveProperty('message');
      expect(typeof responseBody.message).toBe('string');
      expect(responseBody.message).toContain('name');
    });

    test('does not call next() on validation failure', () => {
      const schema = Joi.object({
        id: Joi.number().required()
      });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: {} // missing required id
      });

      middleware(req, res, next);

      expect(next).not.toHaveBeenCalled();
    });
  });

  // ==================================================
  // stripUnknown
  // ==================================================
  describe('stripUnknown behavior', () => {
    test('removes extra fields not defined in schema', () => {
      const schema = Joi.object({
        name: Joi.string().required()
      });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: { name: 'Bob', extraField: 'should be removed', another: 123 }
      });

      middleware(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.body).toEqual({ name: 'Bob' });
      expect(req.body).not.toHaveProperty('extraField');
      expect(req.body).not.toHaveProperty('another');
    });
  });

  // ==================================================
  // abortEarly: false
  // ==================================================
  describe('abortEarly: false behavior', () => {
    test('reports multiple validation errors in a single message', () => {
      const schema = Joi.object({
        name: Joi.string().required(),
        email: Joi.string().email().required(),
        age: Joi.number().integer().required()
      });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: {} // missing all three required fields
      });

      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);

      const responseBody = res.json.mock.calls[0][0];
      // Message should contain all three field names, comma-separated
      expect(responseBody.message).toContain('name');
      expect(responseBody.message).toContain('email');
      expect(responseBody.message).toContain('age');
      // Comma-separated means at least two commas for three errors
      const commaCount = (responseBody.message.match(/,/g) || []).length;
      expect(commaCount).toBeGreaterThanOrEqual(2);
    });
  });

  // ==================================================
  // Type coercion
  // ==================================================
  describe('type coercion', () => {
    test('coerces string "123" to number 123 when schema expects number', () => {
      const schema = Joi.object({
        count: Joi.number().integer().required()
      });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: { count: '123' }
      });

      middleware(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.body).toEqual({ count: 123 });
      expect(typeof req.body.count).toBe('number');
    });

    test('coerces string "true" to boolean when schema expects boolean', () => {
      const schema = Joi.object({
        active: Joi.boolean().required()
      });
      const middleware = validate(schema);

      const { req, res, next } = createMockReqResNext({
        body: { active: 'true' }
      });

      middleware(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.body).toEqual({ active: true });
      expect(typeof req.body.active).toBe('boolean');
    });
  });

  // ==================================================
  // Query source
  // ==================================================
  describe('query source', () => {
    test('validates req.query when source is "query"', () => {
      const schema = Joi.object({
        page: Joi.number().integer().min(1).required(),
        limit: Joi.number().integer().min(1).max(100).default(10)
      });
      const middleware = validate(schema, 'query');

      const { req, res, next } = createMockReqResNext({
        query: { page: '2' },
        body: { unrelated: 'data' }
      });

      middleware(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.query).toEqual({ page: 2, limit: 10 });
      // Body should not be touched
      expect(req.body).toEqual({ unrelated: 'data' });
    });

    test('returns 400 when query validation fails', () => {
      const schema = Joi.object({
        page: Joi.number().integer().min(1).required()
      });
      const middleware = validate(schema, 'query');

      const { req, res, next } = createMockReqResNext({
        query: {} // missing required page
      });

      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(next).not.toHaveBeenCalled();
    });
  });

  // ==================================================
  // Params source
  // ==================================================
  describe('params source', () => {
    test('validates req.params when source is "params"', () => {
      const schema = Joi.object({
        id: Joi.string().required()
      });
      const middleware = validate(schema, 'params');

      const { req, res, next } = createMockReqResNext({
        params: { id: 'doc-123' },
        body: { other: 'data' }
      });

      middleware(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.params).toEqual({ id: 'doc-123' });
      expect(req.body).toEqual({ other: 'data' });
    });

    test('returns 400 when params validation fails', () => {
      const schema = Joi.object({
        id: Joi.string().uuid().required()
      });
      const middleware = validate(schema, 'params');

      const { req, res, next } = createMockReqResNext({
        params: { id: 'not-a-uuid' }
      });

      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(next).not.toHaveBeenCalled();
    });

    test('strips unknown params fields', () => {
      const schema = Joi.object({
        id: Joi.string().required()
      });
      const middleware = validate(schema, 'params');

      const { req, res, next } = createMockReqResNext({
        params: { id: 'abc', extra: 'removed' }
      });

      middleware(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(req.params).toEqual({ id: 'abc' });
      expect(req.params).not.toHaveProperty('extra');
    });
  });
});
