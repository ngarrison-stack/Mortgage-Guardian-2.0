'use strict';

const path = require('path');
const fs = require('fs');

const SUITES_DIR = path.join(__dirname, 'suites');
const VALID_SUITES = ['health', 'api', 'stress', 'all'];

function printHelp() {
  console.log(`
Mortgage Guardian Load Test Runner
===================================

Usage:
  node loadtest/runner.js --suite <name>

Options:
  --suite <name>   Test suite to run. One of: ${VALID_SUITES.join(', ')}
  --help           Show this help message

Suites:
  health    Health/readiness endpoint baselines
  api       API endpoint load tests
  stress    High-concurrency stress tests
  all       Run all available suites

Examples:
  node loadtest/runner.js --suite health
  node loadtest/runner.js --suite all

npm scripts:
  npm run loadtest              # Runs with no suite (shows help)
  npm run loadtest:health       # Runs health suite
`);
}

/**
 * Print a summary table from an array of result objects.
 * Each result should have: { name, result }
 */
function printSummaryTable(results) {
  const SEP = '-'.repeat(110);
  console.log('\n' + SEP);
  console.log(
    padRight('Endpoint', 25) +
    padRight('Requests', 10) +
    padRight('Req/Sec', 10) +
    padRight('p50 (ms)', 10) +
    padRight('p95 (ms)', 10) +
    padRight('p99 (ms)', 10) +
    padRight('Errors', 10) +
    padRight('Timeouts', 10) +
    'Status'
  );
  console.log(SEP);

  let hasFailure = false;

  for (const { name, result } of results) {
    const p99 = result.latency.p99;
    const totalRequests = result.requests.total;
    const errors = result.errors;
    const timeouts = result.timeouts;
    const errorRate = totalRequests > 0 ? (errors / totalRequests) * 100 : 0;
    const failed = p99 > 1000 || errorRate > 1;

    if (failed) hasFailure = true;

    console.log(
      padRight(name, 25) +
      padRight(String(totalRequests), 10) +
      padRight(result.requests.average.toFixed(1), 10) +
      padRight(String(result.latency.p50), 10) +
      padRight(String(result.latency.p95), 10) +
      padRight(String(p99), 10) +
      padRight(String(errors), 10) +
      padRight(String(timeouts), 10) +
      (failed ? 'FAIL' : 'PASS')
    );
  }

  console.log(SEP);

  if (hasFailure) {
    console.log('\nFAILED: One or more tests exceeded thresholds (p99 > 1000ms or error rate > 1%)');
  } else {
    console.log('\nALL PASSED');
  }

  return hasFailure;
}

function padRight(str, len) {
  return String(str).padEnd(len);
}

async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--help') || args.includes('-h')) {
    printHelp();
    process.exit(0);
  }

  // Default to running all suites when no arguments provided
  if (args.length === 0) {
    console.log('No --suite specified — running all suites by default.');
    const allSuitePath = path.join(SUITES_DIR, 'all.js');
    if (!fs.existsSync(allSuitePath)) {
      console.error('Error: all.js suite not found. Use --suite to specify a suite.');
      process.exit(1);
    }
    try {
      const allModule = require(allSuitePath);
      const results = await allModule.run();
      if (Array.isArray(results) && results.length > 0) {
        const hasFailure = printSummaryTable(results);
        process.exit(hasFailure ? 1 : 0);
      } else {
        console.log('\nNo results collected.');
        process.exit(1);
      }
    } catch (err) {
      console.error('Error running all suites:', err.message);
      process.exit(1);
    }
    return;
  }

  const suiteIdx = args.indexOf('--suite');
  if (suiteIdx === -1 || !args[suiteIdx + 1]) {
    console.error('Error: --suite argument is required. Use --help for usage.');
    process.exit(1);
  }

  const suiteName = args[suiteIdx + 1];

  if (!VALID_SUITES.includes(suiteName)) {
    console.error(`Error: Unknown suite "${suiteName}". Valid suites: ${VALID_SUITES.join(', ')}`);
    process.exit(1);
  }

  const suitesToRun = suiteName === 'all'
    ? VALID_SUITES.filter(s => s !== 'all')
    : [suiteName];

  let allResults = [];

  for (const suite of suitesToRun) {
    const suitePath = path.join(SUITES_DIR, `${suite}.js`);
    if (!fs.existsSync(suitePath)) {
      console.warn(`Warning: Suite file not found: ${suitePath} — skipping`);
      continue;
    }

    console.log(`\nRunning suite: ${suite}`);
    console.log('='.repeat(40));

    try {
      const suiteModule = require(suitePath);
      const results = await suiteModule.run();
      if (Array.isArray(results)) {
        allResults = allResults.concat(results);
      }
    } catch (err) {
      console.error(`Error running suite "${suite}":`, err.message);
    }
  }

  if (allResults.length > 0) {
    const hasFailure = printSummaryTable(allResults);
    process.exit(hasFailure ? 1 : 0);
  } else {
    console.log('\nNo results collected.');
    process.exit(1);
  }
}

// Export for testing
module.exports = { printSummaryTable, padRight };

main();
