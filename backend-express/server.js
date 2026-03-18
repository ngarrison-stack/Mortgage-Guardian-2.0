const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const { createLogger, morganStream } = require('./utils/logger');
const logger = createLogger('server');

// Process-level error handlers — must be registered early, before any async work
process.on('uncaughtException', (err) => {
  logger.error('Uncaught exception — process will exit', {
    error: err.message,
    stack: err.stack,
    name: err.name
  });
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.warn('Unhandled promise rejection', {
    reason: reason instanceof Error
      ? { message: reason.message, stack: reason.stack, name: reason.name }
      : String(reason)
  });
});

// Import middleware
const requestId = require('./middleware/requestId');
const { requireAuth } = require('./middleware/auth');

// Import routes
const claudeRoutes = require('./routes/claude');
const plaidRoutes = require('./routes/plaid');
const documentRoutes = require('./routes/documents');
const caseRoutes = require('./routes/cases');
const complianceRoutes = require('./routes/compliance');
const reportRoutes = require('./routes/reports');
const healthRoutes = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// MIDDLEWARE
// ============================================

// Security headers
app.use(helmet());

// Request ID — assign unique ID for log correlation (before all other middleware)
app.use(requestId);

// Compression
app.use(compression());

// CORS - Allow iOS app to connect
// When credentials: true, origin cannot be '*' (CORS spec violation — browsers reject silently).
// Using origin: true echoes back the request's Origin header, which is spec-compliant.
const corsOrigin = process.env.ALLOWED_ORIGINS === '*'
  ? true
  : process.env.ALLOWED_ORIGINS?.split(',');

if (process.env.ALLOWED_ORIGINS === '*' && process.env.NODE_ENV === 'production') {
  logger.warn('CORS configured with wildcard origin — restrict ALLOWED_ORIGINS in production');
}

const corsOptions = {
  origin: corsOrigin,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-App-Version'],
  credentials: true
};
app.use(cors(corsOptions));

// Body parsing — 25MB accommodates base64 overhead (~33% larger than binary) for a 20MB PDF limit
app.use(express.json({ limit: '25mb' }));
app.use(express.urlencoded({ extended: true, limit: '25mb' }));

// HTTP request logging via Winston
app.use(morgan('combined', { stream: morganStream }));

// Rate limiting - protect against abuse
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes default
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // 100 requests per window
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/v1/', limiter);

// Authentication — require JWT for all /v1/ routes (public paths excluded in middleware)
app.use('/v1/', requireAuth);

// ============================================
// ROUTES
// ============================================

// Health check (no rate limit)
app.use('/', healthRoutes);

// API v1 routes
app.use('/v1/ai/claude', claudeRoutes);
app.use('/v1/plaid', plaidRoutes);
app.use('/v1/documents', documentRoutes);
app.use('/v1', complianceRoutes);
app.use('/v1', reportRoutes);
app.use('/v1/cases', caseRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`,
    availableRoutes: [
      'GET /health',
      'POST /v1/ai/claude/analyze',
      'POST /v1/plaid/link_token',
      'POST /v1/plaid/exchange_token',
      'POST /v1/plaid/accounts',
      'POST /v1/plaid/transactions',
      'POST /v1/documents/upload',
      'POST /v1/documents/process',
      'GET /v1/documents/pipeline',
      'GET /v1/documents/:documentId/analysis',
      'GET /v1/documents/:documentId/status',
      'POST /v1/documents/:documentId/retry',
      'POST /v1/documents/:documentId/complete',
      'GET /v1/documents',
      'GET /v1/documents/:documentId',
      'DELETE /v1/documents/:documentId',
      'POST /v1/cases',
      'GET /v1/cases',
      'GET /v1/cases/:caseId',
      'PUT /v1/cases/:caseId',
      'DELETE /v1/cases/:caseId',
      'POST /v1/cases/:caseId/forensic-analysis',
      'GET /v1/cases/:caseId/forensic-analysis',
      'POST /v1/cases/:caseId/compliance',
      'GET /v1/cases/:caseId/compliance',
      'POST /v1/cases/:caseId/report',
      'GET /v1/cases/:caseId/report',
      'POST /v1/cases/:caseId/report/letter',
      'GET /v1/compliance/statutes',
      'GET /v1/compliance/statutes/:statuteId',
      'POST /v1/cases/:caseId/documents',
      'DELETE /v1/cases/:caseId/documents/:documentId'
    ]
  });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack, method: req.method, path: req.path });

  const statusCode = err.statusCode || 500;
  const message = process.env.NODE_ENV === 'production'
    ? 'Internal server error'
    : err.message;

  res.status(statusCode).json({
    error: 'Error',
    message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// ============================================
// ENVIRONMENT VALIDATION
// ============================================

function validateEnvironment() {
  if (process.env.NODE_ENV === 'test') {
    return; // Skip validation in test environment
  }

  const required = {
    'SUPABASE_URL': 'Supabase database connection',
    'SUPABASE_ANON_KEY': 'Supabase anonymous key for auth',
  };

  const recommended = {
    'ANTHROPIC_API_KEY': 'Claude AI document analysis',
    'PLAID_CLIENT_ID': 'Plaid banking integration',
    'PLAID_SECRET': 'Plaid banking integration',
  };

  const missing = [];
  const warnings = [];

  for (const [key, desc] of Object.entries(required)) {
    if (!process.env[key]) missing.push(`${key} (${desc})`);
  }

  for (const [key, desc] of Object.entries(recommended)) {
    if (!process.env[key]) warnings.push(`${key} (${desc})`);
  }

  if (warnings.length > 0) {
    logger.warn('Missing recommended environment variables', { missing: warnings });
  }

  if (missing.length > 0) {
    logger.error('Missing required environment variables', { missing });
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  logger.info('Environment validation passed');
}

// ============================================
// START SERVER (only when run directly)
// ============================================

// For local development and non-serverless deployments
if (require.main === module) {
  validateEnvironment();

  const server = app.listen(PORT, () => {
    logger.info('Server started', {
      port: PORT,
      env: process.env.NODE_ENV || 'development',
      services: {
        claude: !!process.env.ANTHROPIC_API_KEY,
        plaid: !!process.env.PLAID_CLIENT_ID,
        supabase: !!process.env.SUPABASE_URL
      }
    });
  });

  // Graceful shutdown — stop accepting connections, drain in-flight requests, then exit
  let shuttingDown = false;
  function gracefulShutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;

    logger.info(`${signal} received, starting graceful shutdown`);

    // Force exit after 10 seconds if cleanup hangs
    const forceExitTimeout = setTimeout(() => {
      logger.error('Graceful shutdown timed out after 10s, forcing exit');
      process.exit(1);
    }, 10000);
    forceExitTimeout.unref();

    server.close(() => {
      logger.info('Server closed, exiting');
      process.exit(0);
    });
  }

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}

// Export for Vercel serverless
module.exports = app;
