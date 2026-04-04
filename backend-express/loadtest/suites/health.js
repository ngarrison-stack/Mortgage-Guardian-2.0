'use strict';

const { runTest, BASE_URL } = require('../config');

const TESTS = [
  {
    name: 'GET /health/live',
    url: '/health/live',
    method: 'GET',
    connections: 10,
    duration: 10,
    expectedP99: 50,
  },
  {
    name: 'GET /health/ready',
    url: '/health/ready',
    method: 'GET',
    connections: 10,
    duration: 10,
    expectedP99: null, // External deps may vary
    note: 'Readiness check — external dependency latency expected',
  },
  {
    name: 'GET /metrics',
    url: '/metrics',
    method: 'GET',
    connections: 10,
    duration: 10,
    expectedP99: 100,
  },
];

/**
 * Run the health endpoint load test suite.
 * @returns {Promise<Array<{name: string, result: object}>>}
 */
async function run() {
  const results = [];

  for (const test of TESTS) {
    console.log(`\n  Testing: ${test.name} (${test.connections} connections, ${test.duration}s)`);
    if (test.note) {
      console.log(`  Note: ${test.note}`);
    }

    try {
      const result = await runTest({
        url: test.url,
        method: test.method,
        connections: test.connections,
        duration: test.duration,
      });

      const p99 = result.latency.p99;
      const threshold = test.expectedP99 ? `< ${test.expectedP99}ms` : 'N/A';
      const status = test.expectedP99
        ? (p99 <= test.expectedP99 ? 'OK' : 'EXCEEDED')
        : 'INFO';

      console.log(`  Result: p99=${p99}ms (threshold: ${threshold}) [${status}]`);

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
          '\n  Then re-run: npm run loadtest:health\n'
        );
        return [];
      }
      console.error(`  Error testing ${test.name}: ${err.message}`);
    }
  }

  return results;
}

module.exports = { run };
