/**
 * Tests for utils/envValidator.js
 *
 * Each test isolates process.env and re-requires the module to avoid
 * cross-contamination from require-time side effects in other modules.
 */

// Mock the logger module before anything else
jest.mock('../../utils/logger', () => ({
  createLogger: () => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn()
  }),
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
    child: jest.fn().mockReturnValue({
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
      debug: jest.fn()
    })
  },
  morganStream: { write: jest.fn() },
  createRequestLogger: jest.fn()
}));

const VALID_ENV = {
  NODE_ENV: 'development',
  SUPABASE_URL: 'https://test-project.supabase.co',
  SUPABASE_ANON_KEY: 'test-anon-key',
  SUPABASE_SERVICE_KEY: 'test-service-key',
  DOCUMENT_ENCRYPTION_KEY: 'a'.repeat(64),
  ANTHROPIC_API_KEY: 'sk-ant-test',
  PLAID_CLIENT_ID: 'plaid-client-id',
  PLAID_SECRET: 'plaid-secret',
  PLAID_ENV: 'sandbox'
};

let savedEnv;

beforeEach(() => {
  savedEnv = { ...process.env };
  jest.resetModules();
  // Clear all env vars that the validator cares about
  const keysToRemove = [
    'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_KEY',
    'DOCUMENT_ENCRYPTION_KEY', 'ANTHROPIC_API_KEY', 'PLAID_CLIENT_ID',
    'PLAID_SECRET', 'PLAID_ENV', 'PORT', 'NODE_ENV',
    'RATE_LIMIT_WINDOW_MS', 'RATE_LIMIT_MAX_REQUESTS', 'ALLOWED_ORIGINS',
    'LOG_LEVEL', 'PLAID_WEBHOOK_URL', 'PLAID_WEBHOOK_VERIFICATION_KEY',
    'REDIS_HOST', 'REDIS_PORT', 'REDIS_PASSWORD', 'JWT_SECRET',
    'AWS_REGION', 'USE_CLOUD_HSM', 'VAULT_TOKEN', 'KMS_KEY_ID',
    'KMS_SIGNING_KEY_ID', 'ELASTICSEARCH_URL', 'ELASTICSEARCH_USER',
    'ELASTICSEARCH_PASSWORD'
  ];
  keysToRemove.forEach(k => delete process.env[k]);
});

afterEach(() => {
  process.env = savedEnv;
});

function loadValidator() {
  return require('../../utils/envValidator');
}

function setEnv(overrides = {}) {
  Object.assign(process.env, { ...VALID_ENV, ...overrides });
}

// ────────────────────────────────────────────────────────────
// Required variables
// ────────────────────────────────────────────────────────────

describe('envValidator - required variables', () => {
  test('throws when SUPABASE_URL is missing', () => {
    setEnv({ SUPABASE_URL: '' });
    delete process.env.SUPABASE_URL;
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/SUPABASE_URL/);
  });

  test('throws when SUPABASE_ANON_KEY is missing', () => {
    setEnv({ SUPABASE_ANON_KEY: '' });
    delete process.env.SUPABASE_ANON_KEY;
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/SUPABASE_ANON_KEY/);
  });

  test('throws when SUPABASE_SERVICE_KEY is missing', () => {
    setEnv({ SUPABASE_SERVICE_KEY: '' });
    delete process.env.SUPABASE_SERVICE_KEY;
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/SUPABASE_SERVICE_KEY/);
  });

  test('throws when DOCUMENT_ENCRYPTION_KEY is missing', () => {
    setEnv({ DOCUMENT_ENCRYPTION_KEY: '' });
    delete process.env.DOCUMENT_ENCRYPTION_KEY;
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/DOCUMENT_ENCRYPTION_KEY/);
  });

  test('succeeds when all required vars are present', () => {
    setEnv();
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).not.toThrow();
  });
});

// ────────────────────────────────────────────────────────────
// Feature variables (warn, don't crash)
// ────────────────────────────────────────────────────────────

describe('envValidator - feature variables', () => {
  test('warns but does not throw when ANTHROPIC_API_KEY is missing', () => {
    setEnv();
    delete process.env.ANTHROPIC_API_KEY;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config).toBeDefined();
    expect(config.anthropicApiKey).toBe('');
  });

  test('warns but does not throw when PLAID_CLIENT_ID and PLAID_SECRET are missing', () => {
    setEnv();
    delete process.env.PLAID_CLIENT_ID;
    delete process.env.PLAID_SECRET;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config).toBeDefined();
    expect(config.plaidClientId).toBe('');
    expect(config.plaidSecret).toBe('');
  });

  test('warns but does not throw when PLAID_ENV is missing', () => {
    setEnv();
    delete process.env.PLAID_ENV;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config).toBeDefined();
  });
});

// ────────────────────────────────────────────────────────────
// Production-only checks
// ────────────────────────────────────────────────────────────

describe('envValidator - production checks', () => {
  test('throws when ALLOWED_ORIGINS is * in production', () => {
    setEnv({
      NODE_ENV: 'production',
      ALLOWED_ORIGINS: '*',
      PLAID_WEBHOOK_VERIFICATION_KEY: 'some-key'
    });
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/ALLOWED_ORIGINS/);
  });

  test('throws when PLAID_WEBHOOK_VERIFICATION_KEY is missing in production', () => {
    setEnv({
      NODE_ENV: 'production',
      ALLOWED_ORIGINS: 'https://example.com'
    });
    delete process.env.PLAID_WEBHOOK_VERIFICATION_KEY;
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/PLAID_WEBHOOK_VERIFICATION_KEY/);
  });

  test('succeeds in production with all production requirements met', () => {
    setEnv({
      NODE_ENV: 'production',
      ALLOWED_ORIGINS: 'https://example.com',
      PLAID_WEBHOOK_VERIFICATION_KEY: 'webhook-key'
    });
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).not.toThrow();
  });
});

// ────────────────────────────────────────────────────────────
// Format validation
// ────────────────────────────────────────────────────────────

describe('envValidator - format validation', () => {
  test('throws when SUPABASE_URL does not start with https://', () => {
    setEnv({ SUPABASE_URL: 'http://bad-url.supabase.co' });
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/SUPABASE_URL/);
  });

  test('throws when DOCUMENT_ENCRYPTION_KEY is not 64 hex chars', () => {
    setEnv({ DOCUMENT_ENCRYPTION_KEY: 'tooshort' });
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/DOCUMENT_ENCRYPTION_KEY/);
  });

  test('throws when DOCUMENT_ENCRYPTION_KEY has non-hex chars', () => {
    setEnv({ DOCUMENT_ENCRYPTION_KEY: 'g'.repeat(64) });
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow(/DOCUMENT_ENCRYPTION_KEY/);
  });

  test('throws when PORT is not numeric', () => {
    setEnv({ PORT: 'not-a-number' });
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).toThrow();
  });

  test('accepts valid PORT number', () => {
    setEnv({ PORT: '8080' });
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config.port).toBe(8080);
  });
});

// ────────────────────────────────────────────────────────────
// Default value application
// ────────────────────────────────────────────────────────────

describe('envValidator - default values', () => {
  test('applies default PORT of 3000', () => {
    setEnv();
    delete process.env.PORT;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config.port).toBe(3000);
  });

  test('applies default RATE_LIMIT_WINDOW_MS of 900000', () => {
    setEnv();
    delete process.env.RATE_LIMIT_WINDOW_MS;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config.rateLimitWindowMs).toBe(900000);
  });

  test('applies default RATE_LIMIT_MAX_REQUESTS of 100', () => {
    setEnv();
    delete process.env.RATE_LIMIT_MAX_REQUESTS;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config.rateLimitMaxRequests).toBe(100);
  });

  test('applies default ALLOWED_ORIGINS of *', () => {
    setEnv();
    delete process.env.ALLOWED_ORIGINS;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config.allowedOrigins).toBe('*');
  });

  test('applies LOG_LEVEL debug for development', () => {
    setEnv({ NODE_ENV: 'development' });
    delete process.env.LOG_LEVEL;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config.logLevel).toBe('debug');
  });

  test('applies LOG_LEVEL info for production', () => {
    setEnv({
      NODE_ENV: 'production',
      ALLOWED_ORIGINS: 'https://example.com',
      PLAID_WEBHOOK_VERIFICATION_KEY: 'key'
    });
    delete process.env.LOG_LEVEL;
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(config.logLevel).toBe('info');
  });

  test('returns frozen config object', () => {
    setEnv();
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(Object.isFrozen(config)).toBe(true);
    // Verify mutation is silently ignored (strict mode would throw)
    config.port = 9999;
    expect(config.port).toBe(3000);
  });
});

// ────────────────────────────────────────────────────────────
// Test environment
// ────────────────────────────────────────────────────────────

describe('envValidator - test environment', () => {
  test('skips validation when NODE_ENV=test', () => {
    // Set NODE_ENV to test with NO required vars
    process.env.NODE_ENV = 'test';
    const { validateEnvironment } = loadValidator();
    expect(() => validateEnvironment()).not.toThrow();
  });

  test('returns frozen empty object when NODE_ENV=test', () => {
    process.env.NODE_ENV = 'test';
    const { validateEnvironment } = loadValidator();
    const config = validateEnvironment();
    expect(Object.isFrozen(config)).toBe(true);
  });
});

// ────────────────────────────────────────────────────────────
// getConfig singleton
// ────────────────────────────────────────────────────────────

describe('envValidator - getConfig', () => {
  test('returns the same object on repeated calls', () => {
    setEnv();
    const { getConfig } = loadValidator();
    const config1 = getConfig();
    const config2 = getConfig();
    expect(config1).toBe(config2);
  });
});
