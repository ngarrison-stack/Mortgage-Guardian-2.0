const express = require('express');
const router = express.Router();

// Docker healthcheck: prefer /health/live for container liveness probes
// and /health/ready for readiness probes.

/**
 * Perform readiness checks against configured services.
 * Returns an object with check results and an overall ready status.
 */
async function performReadinessChecks(req) {
  const checks = {};
  let allReady = true;

  // Supabase check — use app.locals if available, otherwise skip
  const supabase = req.app.locals.supabase;
  if (supabase) {
    const start = Date.now();
    try {
      await Promise.race([
        supabase.from('users').select('count').limit(1),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000))
      ]);
      checks.supabase = { status: 'connected', latencyMs: Date.now() - start };
    } catch {
      checks.supabase = { status: 'disconnected', latencyMs: Date.now() - start };
      allReady = false;
    }
  } else if (process.env.SUPABASE_URL) {
    checks.supabase = { status: 'not-initialized', latencyMs: 0 };
    allReady = false;
  }

  // Redis check — optional, not required
  const redis = req.app.locals.redis;
  if (redis) {
    const start = Date.now();
    try {
      await Promise.race([
        redis.ping(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 2000))
      ]);
      checks.redis = { status: 'connected', latencyMs: Date.now() - start };
    } catch {
      checks.redis = { status: 'disconnected', latencyMs: Date.now() - start };
      // Redis is NOT required — do not set allReady = false
    }
  } else {
    checks.redis = { status: 'not-configured', latencyMs: 0 };
  }

  return { checks, allReady };
}

// Health check endpoint - no authentication required
// Backward-compatible: keeps existing response shape, adds deep checks
router.get('/health', async (req, res) => {
  const { checks, allReady } = await performReadinessChecks(req);

  const health = {
    status: allReady ? 'healthy' : 'degraded',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: '2.0.0',
    services: {
      anthropic: !!process.env.ANTHROPIC_API_KEY,
      plaid: !!process.env.PLAID_CLIENT_ID,
      supabase: !!process.env.SUPABASE_URL
    },
    checks
  };

  res.status(200).json(health);
});

// Liveness probe — confirms the process is responding
router.get('/health/live', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Readiness probe — deep checks against configured services
router.get('/health/ready', async (req, res) => {
  const { checks, allReady } = await performReadinessChecks(req);

  const statusCode = allReady ? 200 : 503;
  res.status(statusCode).json({
    status: allReady ? 'ready' : 'not_ready',
    checks
  });
});

// Metrics endpoint — returns request metrics snapshot
router.get('/metrics', (req, res) => {
  let getMetrics;
  try {
    getMetrics = require('../middleware/metrics').getMetrics;
  } catch {
    return res.status(503).json({ error: 'Metrics not available' });
  }
  res.status(200).json(getMetrics());
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
