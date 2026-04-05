'use strict';

/**
 * Request metrics middleware — collects request counts, error rates,
 * status code distribution, and response time percentiles.
 *
 * No external dependencies. Metrics are not persisted across restarts.
 */

const HISTOGRAM_SIZE = 1000;

// Singleton metrics state
const state = {
  totalRequests: 0,
  totalErrors: 0,
  statusCodes: new Map(),
  responseTimeHistogram: new Array(HISTOGRAM_SIZE),
  histogramIndex: 0,
  histogramCount: 0,
  startTime: Date.now()
};

/**
 * Express middleware — records request timing and status on finish.
 */
function metricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();

  res.on('finish', () => {
    const durationNs = Number(process.hrtime.bigint() - start);
    const durationMs = durationNs / 1e6;

    state.totalRequests++;

    if (res.statusCode >= 500) {
      state.totalErrors++;
    }

    const code = String(res.statusCode);
    state.statusCodes.set(code, (state.statusCodes.get(code) || 0) + 1);

    // Ring buffer for response times
    state.responseTimeHistogram[state.histogramIndex] = durationMs;
    state.histogramIndex = (state.histogramIndex + 1) % HISTOGRAM_SIZE;
    if (state.histogramCount < HISTOGRAM_SIZE) {
      state.histogramCount++;
    }
  });

  next();
}

/**
 * Compute a percentile from a sorted array.
 */
function percentile(sorted, p) {
  if (sorted.length === 0) return 0;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

/**
 * Return a snapshot of current metrics.
 */
function getMetrics() {
  const uptimeSeconds = Math.floor((Date.now() - state.startTime) / 1000);

  // Build sorted copy of active histogram entries
  const count = state.histogramCount;
  const times = [];
  for (let i = 0; i < count; i++) {
    times.push(state.responseTimeHistogram[i]);
  }
  times.sort((a, b) => a - b);

  const sum = times.reduce((s, t) => s + t, 0);
  const avg = count > 0 ? sum / count : 0;

  // Convert statusCodes Map to plain object
  const statusCodesObj = {};
  for (const [code, cnt] of state.statusCodes) {
    statusCodesObj[code] = cnt;
  }

  return {
    uptime: uptimeSeconds,
    requests: {
      total: state.totalRequests,
      errors: state.totalErrors,
      errorRate: state.totalRequests > 0
        ? parseFloat(((state.totalErrors / state.totalRequests) * 100).toFixed(2))
        : 0
    },
    statusCodes: statusCodesObj,
    responseTime: {
      avg: parseFloat(avg.toFixed(2)),
      p50: parseFloat(percentile(times, 50).toFixed(2)),
      p95: parseFloat(percentile(times, 95).toFixed(2)),
      p99: parseFloat(percentile(times, 99).toFixed(2))
    },
    memory: {
      rss: process.memoryUsage().rss,
      heapUsed: process.memoryUsage().heapUsed,
      heapTotal: process.memoryUsage().heapTotal
    }
  };
}

/**
 * Reset all metrics — useful for testing.
 */
function resetMetrics() {
  state.totalRequests = 0;
  state.totalErrors = 0;
  state.statusCodes.clear();
  state.responseTimeHistogram = new Array(HISTOGRAM_SIZE);
  state.histogramIndex = 0;
  state.histogramCount = 0;
  state.startTime = Date.now();
}

module.exports = metricsMiddleware;
module.exports.metricsMiddleware = metricsMiddleware;
module.exports.getMetrics = getMetrics;
module.exports.resetMetrics = resetMetrics;
