'use strict';

const http = require('http');
const { runTest, BASE_URL } = require('../config');

const LOAD_CONNECTIONS = 50;
const LOAD_DURATION = 30;
const POLL_INTERVAL_MS = 2000;
const COOLDOWN_MS = 5000;
const PEAK_RSS_THRESHOLD = 104857600; // 100 MB
const LEAK_RATIO = 1.5;

/**
 * Fetch JSON from a URL using http.get.
 * @param {string} url
 * @returns {Promise<object>}
 */
function fetchJSON(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (err) {
          reject(new Error(`Failed to parse JSON from ${url}: ${err.message}`));
        }
      });
    }).on('error', reject);
  });
}

/**
 * Poll /metrics at intervals during load, collecting memory snapshots.
 * @param {string} metricsUrl
 * @param {number} durationMs
 * @param {number} intervalMs
 * @returns {Promise<Array<object>>}
 */
function pollMemory(metricsUrl, durationMs, intervalMs) {
  return new Promise((resolve) => {
    const snapshots = [];
    const start = Date.now();

    const timer = setInterval(async () => {
      try {
        const metrics = await fetchJSON(metricsUrl);
        if (metrics.memory) {
          snapshots.push({
            timestamp: Date.now() - start,
            rss: metrics.memory.rss,
            heapUsed: metrics.memory.heapUsed,
            heapTotal: metrics.memory.heapTotal,
          });
        }
      } catch (_) {
        // Ignore polling errors during load
      }

      if (Date.now() - start >= durationMs) {
        clearInterval(timer);
        resolve(snapshots);
      }
    }, intervalMs);
  });
}

/**
 * Format bytes as a human-readable string.
 * @param {number} bytes
 * @returns {string}
 */
function formatBytes(bytes) {
  const mb = (bytes / (1024 * 1024)).toFixed(2);
  return `${mb} MB`;
}

/**
 * Run the memory profiling suite.
 *
 * 1. GET /metrics for initial memory baseline
 * 2. Run 50 connections for 30s against /health/live, polling /metrics every 2s
 * 3. Wait 5s for GC, then poll memory again
 * 4. Report initial/peak/post-load memory
 * 5. Pass/fail: peak RSS < 100 MB; warn if post-load RSS > 1.5x initial
 *
 * @returns {Promise<Array<{name: string, result: object}>>}
 */
async function run() {
  const metricsUrl = `${BASE_URL}/metrics`;

  // ── Step 1: Initial memory baseline ──────────────────────────────────────
  console.log('\n  Capturing initial memory baseline...');
  let initialMetrics;
  try {
    initialMetrics = await fetchJSON(metricsUrl);
  } catch (err) {
    if (
      err.code === 'ECONNREFUSED' ||
      (err.message && err.message.includes('ECONNREFUSED'))
    ) {
      console.error(
        `\n  ERROR: Could not connect to ${BASE_URL}` +
        '\n  The server does not appear to be running.' +
        '\n  Start the server first with: npm run dev' +
        '\n  Then re-run: npm run loadtest:memory\n'
      );
      return [];
    }
    throw err;
  }

  const initialRSS = initialMetrics.memory.rss;
  const initialHeapUsed = initialMetrics.memory.heapUsed;
  const initialHeapTotal = initialMetrics.memory.heapTotal;

  console.log(`  Initial RSS: ${formatBytes(initialRSS)}`);
  console.log(`  Initial Heap Used: ${formatBytes(initialHeapUsed)}`);
  console.log(`  Initial Heap Total: ${formatBytes(initialHeapTotal)}`);

  // ── Step 2: Load + memory polling ────────────────────────────────────────
  console.log(`\n  Running load: ${LOAD_CONNECTIONS} connections for ${LOAD_DURATION}s against /health/live`);
  console.log(`  Polling /metrics every ${POLL_INTERVAL_MS / 1000}s...\n`);

  const [loadResult, snapshots] = await Promise.all([
    runTest({
      url: '/health/live',
      method: 'GET',
      connections: LOAD_CONNECTIONS,
      duration: LOAD_DURATION,
    }),
    pollMemory(metricsUrl, LOAD_DURATION * 1000, POLL_INTERVAL_MS),
  ]);

  // ── Step 3: Cooldown and post-load measurement ───────────────────────────
  console.log(`  Waiting ${COOLDOWN_MS / 1000}s for GC cooldown...`);
  await new Promise((resolve) => setTimeout(resolve, COOLDOWN_MS));

  const postMetrics = await fetchJSON(metricsUrl);
  const postRSS = postMetrics.memory.rss;

  // ── Step 4: Compute peak values ──────────────────────────────────────────
  let peakRSS = initialRSS;
  let peakHeapUsed = initialHeapUsed;
  let peakHeapTotal = initialHeapTotal;

  for (const snap of snapshots) {
    if (snap.rss > peakRSS) peakRSS = snap.rss;
    if (snap.heapUsed > peakHeapUsed) peakHeapUsed = snap.heapUsed;
    if (snap.heapTotal > peakHeapTotal) peakHeapTotal = snap.heapTotal;
  }

  // Include post-load values in peak calculation
  if (postRSS > peakRSS) peakRSS = postRSS;

  // ── Step 5: Report ───────────────────────────────────────────────────────
  console.log('\n  Memory Profile Results:');
  console.log('  ' + '-'.repeat(50));
  console.log(`  Initial RSS:       ${formatBytes(initialRSS)}`);
  console.log(`  Peak RSS:          ${formatBytes(peakRSS)}`);
  console.log(`  Post-load RSS:     ${formatBytes(postRSS)}`);
  console.log(`  Peak Heap Used:    ${formatBytes(peakHeapUsed)}`);
  console.log(`  Peak Heap Total:   ${formatBytes(peakHeapTotal)}`);
  console.log(`  Snapshots taken:   ${snapshots.length}`);
  console.log('  ' + '-'.repeat(50));

  // Pass/fail: peak RSS < 100 MB
  const rssPassed = peakRSS < PEAK_RSS_THRESHOLD;
  console.log(`  Peak RSS < 100MB:  ${rssPassed ? 'PASS' : 'FAIL'} (${formatBytes(peakRSS)})`);

  // Warn if post-load RSS > 1.5x initial (potential memory leak)
  const leakRatio = postRSS / initialRSS;
  const leakWarning = leakRatio > LEAK_RATIO;
  if (leakWarning) {
    console.log(`  WARNING: Post-load RSS is ${leakRatio.toFixed(2)}x initial — potential memory leak`);
  } else {
    console.log(`  Post-load/initial ratio: ${leakRatio.toFixed(2)}x (< ${LEAK_RATIO}x threshold)`);
  }

  // ── Build result compatible with runner.js format ────────────────────────
  const result = {
    latency: {
      p50: loadResult.latency.p50,
      p95: loadResult.latency.p95,
      p99: loadResult.latency.p99,
    },
    requests: {
      total: loadResult.requests.total,
      average: loadResult.requests.average,
    },
    errors: loadResult.errors,
    timeouts: loadResult.timeouts,
    memoryProfile: {
      initial: {
        rss: initialRSS,
        heapUsed: initialHeapUsed,
        heapTotal: initialHeapTotal,
      },
      peak: {
        rss: peakRSS,
        heapUsed: peakHeapUsed,
        heapTotal: peakHeapTotal,
      },
      postLoad: {
        rss: postRSS,
      },
      leakRatio: parseFloat(leakRatio.toFixed(2)),
      leakWarning,
      rssPassed,
      snapshots: snapshots.length,
    },
  };

  return [{ name: 'Memory Profile (/health/live)', result }];
}

module.exports = { run };
