const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const { createLogger, morganStream } = require('./utils/logger');
const logger = createLogger('server');

// Import middleware
const { requireAuth } = require('./middleware/auth');

// Import routes
const claudeRoutes = require('./routes/claude');
const plaidRoutes = require('./routes/plaid');
const documentRoutes = require('./routes/documents');
const healthRoutes = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// MIDDLEWARE
// ============================================

// Security headers
app.use(helmet());

// Compression
app.use(compression());

// CORS - Allow iOS app to connect
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS === '*' ? '*' : process.env.ALLOWED_ORIGINS?.split(','),
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
      'GET /v1/documents',
      'GET /v1/documents/:documentId',
      'DELETE /v1/documents/:documentId'
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
// START SERVER (only in non-serverless environments)
// ============================================

// For local development and non-serverless deployments
if (process.env.NODE_ENV !== 'production' || !process.env.VERCEL) {
  app.listen(PORT, () => {
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

  // Graceful shutdown
  process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down');
    process.exit(0);
  });
}

// Export for Vercel serverless
module.exports = app;
