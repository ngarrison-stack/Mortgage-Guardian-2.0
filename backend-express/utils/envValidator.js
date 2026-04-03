/**
 * Environment Variable Validator
 *
 * Joi-based validation for all environment variables with four categories:
 * - Required: server won't start without these
 * - Feature: warns but doesn't crash (degrades gracefully)
 * - Optional: have sensible defaults
 * - Production-only: required only when NODE_ENV=production
 *
 * Usage:
 *   const { validateEnvironment, getConfig } = require('./envValidator');
 *   validateEnvironment();         // throws on missing required vars
 *   const config = getConfig();    // frozen config singleton
 */

const Joi = require('joi');
const { createLogger } = require('./logger');

const logger = createLogger('env-validator');

// Hex string pattern (64 chars = 32-byte key)
const HEX_64 = /^[0-9a-fA-F]{64}$/;

/**
 * Build the Joi schema. Separated so tests can inspect it if needed.
 */
function buildSchema(isProduction) {
  const schema = Joi.object({
    // ── Required ──────────────────────────────────────────────
    SUPABASE_URL: Joi.string()
      .uri({ scheme: 'https' })
      .required()
      .messages({
        'string.uri': 'SUPABASE_URL must start with https://',
        'any.required': 'SUPABASE_URL is required (Supabase database connection)',
        'string.empty': 'SUPABASE_URL cannot be empty'
      }),
    SUPABASE_ANON_KEY: Joi.string().required().messages({
      'any.required': 'SUPABASE_ANON_KEY is required (Supabase anonymous key)',
      'string.empty': 'SUPABASE_ANON_KEY cannot be empty'
    }),
    SUPABASE_SERVICE_KEY: Joi.string().required().messages({
      'any.required': 'SUPABASE_SERVICE_KEY is required (Supabase service role key)',
      'string.empty': 'SUPABASE_SERVICE_KEY cannot be empty'
    }),
    DOCUMENT_ENCRYPTION_KEY: Joi.string().pattern(HEX_64).required().messages({
      'string.pattern.base': 'DOCUMENT_ENCRYPTION_KEY must be exactly 64 hex characters (generate with: openssl rand -hex 32)',
      'any.required': 'DOCUMENT_ENCRYPTION_KEY is required (document encryption)',
      'string.empty': 'DOCUMENT_ENCRYPTION_KEY cannot be empty'
    }),

    // ── Feature (optional but warned) ─────────────────────────
    ANTHROPIC_API_KEY: Joi.string().optional().allow(''),
    PLAID_CLIENT_ID: Joi.string().optional().allow(''),
    PLAID_SECRET: Joi.string().optional().allow(''),
    PLAID_ENV: Joi.string().valid('sandbox', 'development', 'production').optional().allow(''),

    // ── Optional with defaults ────────────────────────────────
    PORT: Joi.number().integer().min(1).max(65535).default(3000),
    NODE_ENV: Joi.string().valid('development', 'production', 'test', 'staging').default('development'),
    RATE_LIMIT_WINDOW_MS: Joi.number().integer().positive().default(900000),
    RATE_LIMIT_MAX_REQUESTS: Joi.number().integer().positive().default(100),
    ALLOWED_ORIGINS: Joi.string().default('*'),
    LOG_LEVEL: Joi.string().valid('error', 'warn', 'info', 'http', 'verbose', 'debug', 'silly').optional(),
    PLAID_WEBHOOK_URL: Joi.string().uri().optional().allow(''),
    PLAID_WEBHOOK_VERIFICATION_KEY: Joi.string().optional().allow(''),

    // ── Infrastructure (optional) ─────────────────────────────
    REDIS_HOST: Joi.string().optional().allow(''),
    REDIS_PORT: Joi.number().integer().min(1).max(65535).optional(),
    REDIS_PASSWORD: Joi.string().optional().allow(''),
    JWT_SECRET: Joi.string().optional().allow(''),
    AWS_REGION: Joi.string().optional().allow(''),
    USE_CLOUD_HSM: Joi.string().optional().allow(''),
    VAULT_TOKEN: Joi.string().optional().allow(''),
    KMS_KEY_ID: Joi.string().optional().allow(''),
    KMS_SIGNING_KEY_ID: Joi.string().optional().allow(''),
    ELASTICSEARCH_URL: Joi.string().optional().allow(''),
    ELASTICSEARCH_USER: Joi.string().optional().allow(''),
    ELASTICSEARCH_PASSWORD: Joi.string().optional().allow('')
  }).options({ allowUnknown: true, stripUnknown: false });

  return schema;
}

/**
 * Validate environment variables and return a frozen config object.
 * Throws on missing required vars. Warns for missing feature vars.
 * Skips validation entirely when NODE_ENV=test.
 *
 * @returns {Object} Frozen configuration object with parsed/defaulted values
 */
function validateEnvironment() {
  // Skip validation in test environment
  if (process.env.NODE_ENV === 'test') {
    return Object.freeze({});
  }

  const isProduction = process.env.NODE_ENV === 'production';
  const schema = buildSchema(isProduction);

  // Validate against schema
  const { error, value } = schema.validate(process.env, {
    abortEarly: false
  });

  if (error) {
    const messages = error.details.map(d => d.message);
    logger.error('Environment validation failed', { errors: messages });
    throw new Error(`Environment validation failed:\n  - ${messages.join('\n  - ')}`);
  }

  // ── Feature var warnings ────────────────────────────────────
  const featureWarnings = [];

  if (!value.ANTHROPIC_API_KEY) {
    featureWarnings.push('ANTHROPIC_API_KEY missing — AI document analysis will be unavailable');
  }
  if (!value.PLAID_CLIENT_ID || !value.PLAID_SECRET) {
    featureWarnings.push('PLAID_CLIENT_ID and/or PLAID_SECRET missing — banking integration will be unavailable');
  }
  if (!value.PLAID_ENV) {
    featureWarnings.push('PLAID_ENV missing — Plaid environment not configured');
  }

  if (featureWarnings.length > 0) {
    logger.warn('Missing feature environment variables — some features will be disabled', {
      warnings: featureWarnings
    });
  }

  // ── Production-only checks ──────────────────────────────────
  if (isProduction) {
    const prodErrors = [];

    if (value.ALLOWED_ORIGINS === '*') {
      prodErrors.push('ALLOWED_ORIGINS must not be "*" in production — specify explicit origins');
    }
    if (!value.PLAID_WEBHOOK_VERIFICATION_KEY) {
      prodErrors.push('PLAID_WEBHOOK_VERIFICATION_KEY is required in production for webhook security');
    }

    if (prodErrors.length > 0) {
      logger.error('Production environment validation failed', { errors: prodErrors });
      throw new Error(`Production environment validation failed:\n  - ${prodErrors.join('\n  - ')}`);
    }
  }

  // ── Build config ────────────────────────────────────────────
  const config = Object.freeze({
    // Server
    port: value.PORT,
    nodeEnv: value.NODE_ENV,
    logLevel: value.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
    rateLimitWindowMs: value.RATE_LIMIT_WINDOW_MS,
    rateLimitMaxRequests: value.RATE_LIMIT_MAX_REQUESTS,
    allowedOrigins: value.ALLOWED_ORIGINS,

    // Supabase
    supabaseUrl: value.SUPABASE_URL,
    supabaseAnonKey: value.SUPABASE_ANON_KEY,
    supabaseServiceKey: value.SUPABASE_SERVICE_KEY,

    // Security
    documentEncryptionKey: value.DOCUMENT_ENCRYPTION_KEY,
    jwtSecret: value.JWT_SECRET || '',

    // AI
    anthropicApiKey: value.ANTHROPIC_API_KEY || '',

    // Plaid
    plaidClientId: value.PLAID_CLIENT_ID || '',
    plaidSecret: value.PLAID_SECRET || '',
    plaidEnv: value.PLAID_ENV || '',
    plaidWebhookUrl: value.PLAID_WEBHOOK_URL || '',
    plaidWebhookVerificationKey: value.PLAID_WEBHOOK_VERIFICATION_KEY || '',

    // Infrastructure
    redisHost: value.REDIS_HOST || '',
    redisPort: value.REDIS_PORT || undefined,
    redisPassword: value.REDIS_PASSWORD || '',
    awsRegion: value.AWS_REGION || '',
    useCloudHsm: value.USE_CLOUD_HSM || '',
    vaultToken: value.VAULT_TOKEN || '',
    kmsKeyId: value.KMS_KEY_ID || '',
    kmsSigningKeyId: value.KMS_SIGNING_KEY_ID || '',
    elasticsearchUrl: value.ELASTICSEARCH_URL || '',
    elasticsearchUser: value.ELASTICSEARCH_USER || '',
    elasticsearchPassword: value.ELASTICSEARCH_PASSWORD || ''
  });

  logger.info('Environment validation passed');
  return config;
}

// ── Singleton ───────────────────────────────────────────────
let _config = null;

/**
 * Get the validated config singleton. Lazy-validates on first access.
 * @returns {Object} Frozen configuration object
 */
function getConfig() {
  if (!_config) {
    _config = validateEnvironment();
  }
  return _config;
}

module.exports = { validateEnvironment, getConfig };
