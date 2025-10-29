const express = require('express');
const router = express.Router();

// Health check endpoint - no authentication required
router.get('/health', (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: '2.0.0',
    services: {
      anthropic: !!process.env.ANTHROPIC_API_KEY,
      plaid: !!process.env.PLAID_CLIENT_ID,
      supabase: !!process.env.SUPABASE_URL
    }
  };

  res.status(200).json(health);
});

// Root endpoint
router.get('/', (req, res) => {
  res.json({
    name: 'Mortgage Guardian API',
    version: '2.0.0',
    description: 'AWS-free backend using Railway + Supabase',
    documentation: '/health',
    endpoints: {
      health: 'GET /health',
      claude: 'POST /v1/ai/claude/analyze',
      plaid: {
        linkToken: 'POST /v1/plaid/link_token',
        exchangeToken: 'POST /v1/plaid/exchange_token',
        accounts: 'POST /v1/plaid/accounts',
        transactions: 'POST /v1/plaid/transactions'
      },
      documents: {
        upload: 'POST /v1/documents/upload',
        list: 'GET /v1/documents',
        get: 'GET /v1/documents/:documentId',
        delete: 'DELETE /v1/documents/:documentId'
      }
    }
  });
});

module.exports = router;
