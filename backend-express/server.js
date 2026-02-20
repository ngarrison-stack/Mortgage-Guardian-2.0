const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

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

// Body parsing
app.use(express.json({ limit: '50mb' })); // Large limit for document uploads
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Logging
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

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
  console.error('Error:', err);

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
    console.log('🚀 Mortgage Guardian Backend (AWS-Free)');
    console.log('========================================');
    console.log(`✅ Server running on port ${PORT}`);
    console.log(`✅ Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`✅ Claude API: ${process.env.ANTHROPIC_API_KEY ? 'Configured' : '❌ Missing'}`);
    console.log(`✅ Plaid: ${process.env.PLAID_CLIENT_ID ? 'Configured' : '❌ Missing'}`);
    console.log(`✅ Supabase: ${process.env.SUPABASE_URL ? 'Configured' : '❌ Missing'}`);
    console.log('========================================');
    console.log(`📡 Ready to accept requests at http://localhost:${PORT}`);
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    process.exit(0);
  });
}

// Export for Vercel serverless
module.exports = app;
