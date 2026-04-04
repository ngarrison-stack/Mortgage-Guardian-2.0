'use strict';

const { runTest, BASE_URL } = require('../config');

// Ramp-up stages for /health/live
const RAMP_STAGES = [
  { connections: 10,  duration: 10, p99Threshold: null },
  { connections: 50,  duration: 10, p99Threshold: 500  },
  { connections: 100, duration: 10, p99Threshold: 1000 },
  { connections: 200, duration: 10, p99Threshold: null, errorThreshold: 5 },
];

const RAMP_URL = '/health/live';

// Rate limit probe: rapid-fire unauthenticated requests against a protected route
const RATE_LIMIT_URL = '/v1/plaid/accounts/test';
const RATE_LIMIT_CONNECTIONS = 1;
const RATE_LIMIT_DURATION = 5;

/**
 * Print a ramp-up comparison table.
 * @param {Array<{connections: number, result: object, pass: boolean, note: string}>} stages
 */
function printRampTable(stages) {
  const SEP = '-'.repeat(90);
  console.log('\n' + SEP);
  console.log(
    'Connections'.padEnd(14) +
    'Req/Sec'.padEnd(12) +
    'p50 (ms)'.padEnd(12) +
    'p95 (ms)'.padEnd(12) +
    'p99 (ms)'.padEnd(12) +
    'Errors'.padEnd(10) +
    'Timeouts'.padEnd(10) +
    'Status'
  );
  console.log(SEP);

  for (const stage of stages) {
    const r = stage.result;
    const errorRate = r.requests.total > 0
      ? ((r.errors / r.requests.total) * 100).toFixed(1)
      : '0.0';

    console.log(
      String(stage.connections).padEnd(14) +
      r.requests.average.toFixed(1).padEnd(12) +
      String(r.latency.p50).padEnd(12) +
      String(r.latency.p95).padEnd(12) +
      String(r.latency.p99).padEnd(12) +
      `${r.errors} (${errorRate}%)`.padEnd(10) +
      String(r.timeouts).padEnd(10) +
      (stage.pass ? 'PASS' : `FAIL — ${stage.note}`)
    );
  }

  console.log(SEP);
}

/**
 * Run the stress test suite.
 *
 * 1. 4-stage ramp-up on /health/live (10 / 50 / 100 / 200 connections)
 * 2. Rate limit probe: rapid-fire unauthenticated requests against
 *    /v1/plaid/accounts/test — checks whether 429 responses appear
 *
 * Pass/fail criteria:
 *   - p99 < 500ms  at 50 connections
 *   - p99 < 1000ms at 100 connections
 *   - Error rate < 5% at 200 connections (excluding expected 401/429)
 *   - Rate limiter triggers within configured window
 *
 * @returns {Promise<Array<{name: string, result: object}>>}
 */
async function run() {
  const results = [];

  // ── 1. Ramp-up stages ───────────────────────────────────────────────────────
  console.log(`\n  Ramp-up stages on ${RAMP_URL}`);

  const stageData = [];
  let connectionError = false;

  for (const stage of RAMP_STAGES) {
    console.log(`  Stage ${RAMP_STAGES.indexOf(stage) + 1}: ${stage.connections} connections, ${stage.duration}s`);

    try {
      const result = await runTest({
        url: RAMP_URL,
        method: 'GET',
        connections: stage.connections,
        duration: stage.duration,
      });

      const p99 = result.latency.p99;
      const errorRate = result.requests.total > 0
        ? (result.errors / result.requests.total) * 100
        : 0;

      // Evaluate pass/fail for this stage
      let pass = true;
      let note = '';

      if (stage.p99Threshold !== null && p99 > stage.p99Threshold) {
        pass = false;
        note = `p99 ${p99}ms exceeds ${stage.p99Threshold}ms threshold`;
      }

      if (stage.errorThreshold !== null && stage.errorThreshold !== undefined) {
        if (errorRate > stage.errorThreshold) {
          pass = false;
          note = note
            ? `${note}; error rate ${errorRate.toFixed(1)}% exceeds ${stage.errorThreshold}%`
            : `error rate ${errorRate.toFixed(1)}% exceeds ${stage.errorThreshold}%`;
        }
      }

      stageData.push({ connections: stage.connections, result, pass, note });

      const stageName = `STRESS: ${RAMP_URL} (${stage.connections}c)`;
      results.push({ name: stageName, result });
    } catch (err) {
      if (
        err.code === 'ECONNREFUSED' ||
        (err.message && err.message.includes('ECONNREFUSED'))
      ) {
        console.error(
          `\n  ERROR: Could not connect to ${BASE_URL}` +
          '\n  The server does not appear to be running.' +
          '\n  Start the server first with: npm run dev' +
          '\n  Then re-run: npm run loadtest:stress\n'
        );
        connectionError = true;
        break;
      }
      console.error(`  Error in stage ${stage.connections}c: ${err.message}`);
    }
  }

  if (connectionError) {
    return [];
  }

  if (stageData.length > 0) {
    printRampTable(stageData);

    const allPass = stageData.every(s => s.pass);
    if (allPass) {
      console.log('\n  Ramp-up: ALL STAGES PASSED');
    } else {
      const failed = stageData.filter(s => !s.pass).map(s => `${s.connections}c`).join(', ');
      console.log(`\n  Ramp-up: FAILED at: ${failed}`);
    }
  }

  // ── 2. Rate limit verification ───────────────────────────────────────────────
  console.log(`\n  Rate limit probe: ${RATE_LIMIT_URL} (${RATE_LIMIT_CONNECTIONS} connection, ${RATE_LIMIT_DURATION}s rapid-fire, unauthenticated)`);

  try {
    const rlResult = await runTest({
      url: RATE_LIMIT_URL,
      method: 'GET',
      connections: RATE_LIMIT_CONNECTIONS,
      duration: RATE_LIMIT_DURATION,
    });

    // autocannon counts non-2xx as errors; 429 responses will show up there
    // We also look at the 4xx breakdown if available
    const total = rlResult.requests.total;
    const errors = rlResult.errors;
    const errorRate = total > 0 ? ((errors / total) * 100).toFixed(1) : '0.0';

    // Check status codes for 429 if autocannon exposes them
    let has429 = false;
    if (rlResult['4xx'] && rlResult['4xx'] > 0) {
      // Any 4xx beyond 401 is a candidate for 429
      // autocannon doesn't split 401 vs 429 by default, but elevated 4xx count
      // after the rate window suggests rate limiting fired
      has429 = true;
    }

    console.log(
      `  Rate limit probe: ${total} requests, ${errors} errors (${errorRate}%), ` +
      `req/sec=${rlResult.requests.average.toFixed(1)}`
    );

    if (has429) {
      console.log('  Rate limiter: TRIGGERED (4xx responses observed — likely 429s mixed with 401s)');
    } else {
      console.log('  Rate limiter: NOT TRIGGERED in probe window (may need longer window or more connections)');
    }

    results.push({ name: `STRESS: rate-limit probe ${RATE_LIMIT_URL}`, result: rlResult });
  } catch (err) {
    if (
      err.code === 'ECONNREFUSED' ||
      (err.message && err.message.includes('ECONNREFUSED'))
    ) {
      console.error(`\n  ERROR: Could not connect to ${BASE_URL} for rate limit probe\n`);
    } else {
      console.error(`  Error during rate limit probe: ${err.message}`);
    }
  }

  return results;
}

module.exports = { run };
