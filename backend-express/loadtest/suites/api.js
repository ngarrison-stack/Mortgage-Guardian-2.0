'use strict';

const { runTest, BASE_URL } = require('../config');

// Unauthenticated baseline tests — measure auth middleware + routing overhead
// Expects 401 responses; no external services called
const UNAUTH_TESTS = [
  {
    name: 'POST /v1/documents/process',
    url: '/v1/documents/process',
    method: 'POST',
    connections: 10,
    duration: 15,
    expectedStatus: 401,
  },
  {
    name: 'GET /v1/plaid/accounts/test',
    url: '/v1/plaid/accounts/test',
    method: 'GET',
    connections: 10,
    duration: 15,
    expectedStatus: 401,
  },
  {
    name: 'POST /v1/ai/claude/analyze',
    url: '/v1/ai/claude/analyze',
    method: 'POST',
    connections: 10,
    duration: 15,
    expectedStatus: 401,
  },
];

/**
 * Run the API route load test suite.
 *
 * Mode 1 (default): Unauthenticated — measures 401 response latency to assess
 *   auth middleware overhead without calling external services.
 * Mode 2 (AUTH_TOKEN env var set): Authenticated — includes Bearer token in
 *   headers. Note: authenticated requests may call external services (Plaid,
 *   Claude AI) which introduces variable latency.
 *
 * @returns {Promise<Array<{name: string, result: object}>>}
 */
async function run() {
  const authToken = process.env.AUTH_TOKEN;
  const results = [];

  if (authToken) {
    console.log('\n  Mode: AUTHENTICATED (AUTH_TOKEN detected)');
    console.log('  WARNING: Authenticated requests may call external services (Plaid, Claude AI).');
    console.log('  External service latency will affect results.\n');
  } else {
    console.log('\n  Mode: UNAUTHENTICATED BASELINE');
    console.log('  Measuring auth middleware + routing overhead via 401 responses.');
    console.log('  Set AUTH_TOKEN env var to run authenticated tests.\n');
  }

  for (const test of UNAUTH_TESTS) {
    console.log(`  Testing: ${test.name} (${test.connections} connections, ${test.duration}s)`);

    const headers = {};
    if (authToken) {
      headers['Authorization'] = `Bearer ${authToken}`;
    }

    try {
      const result = await runTest({
        url: test.url,
        method: test.method,
        connections: test.connections,
        duration: test.duration,
        headers: Object.keys(headers).length > 0 ? headers : undefined,
      });

      const p99 = result.latency.p99;
      const errorRate = result.requests.total > 0
        ? ((result.errors / result.requests.total) * 100).toFixed(1)
        : '0.0';

      console.log(
        `  Result: p50=${result.latency.p50}ms p95=${result.latency.p95}ms p99=${p99}ms` +
        ` req/sec=${result.requests.average.toFixed(1)} errors=${result.errors} (${errorRate}%)`
      );

      results.push({ name: test.name, result });
    } catch (err) {
      if (
        err.code === 'ECONNREFUSED' ||
        (err.message && err.message.includes('ECONNREFUSED'))
      ) {
        console.error(
          `\n  ERROR: Could not connect to ${BASE_URL}` +
          '\n  The server does not appear to be running.' +
          '\n  Start the server first with: npm run dev' +
          '\n  Then re-run: npm run loadtest:api\n'
        );
        return [];
      }
      console.error(`  Error testing ${test.name}: ${err.message}`);
    }
  }

  return results;
}

module.exports = { run };
