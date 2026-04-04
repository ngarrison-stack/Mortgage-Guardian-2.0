'use strict';

const fs = require('fs');
const path = require('path');

const healthSuite = require('./health');
const apiSuite = require('./api');
const stressSuite = require('./stress');

const RESULTS_DIR = path.join(__dirname, '..', 'results');

/**
 * Format a Date as YYYY-MM-DD.
 * @param {Date} d
 * @returns {string}
 */
function formatDate(d) {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Serialize a suite's result array into a plain JSON-safe format.
 * @param {Array<{name: string, result: object}>} suiteResults
 * @returns {Array<object>}
 */
function serializeSuiteResults(suiteResults) {
  return suiteResults.map(({ name, result }) => ({
    endpoint: name,
    latency: {
      p50: result.latency.p50,
      p95: result.latency.p95,
      p99: result.latency.p99,
      average: result.latency.average,
    },
    requests: {
      total: result.requests.total,
      average: result.requests.average,
    },
    errors: result.errors,
    timeouts: result.timeouts,
  }));
}

/**
 * Run all suites (health, api, stress) in sequence, aggregate results,
 * and write a JSON baseline to loadtest/results/baseline-YYYY-MM-DD.json.
 *
 * @returns {Promise<Array<{name: string, result: object}>>}
 */
async function run() {
  const generatedAt = new Date().toISOString();
  const allResults = [];

  // ── health ──────────────────────────────────────────────────────────────────
  console.log('\nRunning suite: health');
  console.log('='.repeat(40));
  const healthResults = await healthSuite.run();
  allResults.push(...healthResults);

  // ── api ─────────────────────────────────────────────────────────────────────
  console.log('\nRunning suite: api');
  console.log('='.repeat(40));
  const apiResults = await apiSuite.run();
  allResults.push(...apiResults);

  // ── stress ──────────────────────────────────────────────────────────────────
  console.log('\nRunning suite: stress');
  console.log('='.repeat(40));
  const stressResults = await stressSuite.run();
  allResults.push(...stressResults);

  // ── write JSON baseline ──────────────────────────────────────────────────────
  try {
    fs.mkdirSync(RESULTS_DIR, { recursive: true });

    const dateStr = formatDate(new Date());
    const outPath = path.join(RESULTS_DIR, `baseline-${dateStr}.json`);

    const payload = {
      generatedAt,
      suites: {
        health: serializeSuiteResults(healthResults),
        api: serializeSuiteResults(apiResults),
        stress: serializeSuiteResults(stressResults),
      },
    };

    fs.writeFileSync(outPath, JSON.stringify(payload, null, 2), 'utf8');
    console.log(`\n  Baseline JSON written to: ${outPath}`);
  } catch (err) {
    console.error(`  Warning: Could not write baseline JSON: ${err.message}`);
  }

  return allResults;
}

module.exports = { run };
