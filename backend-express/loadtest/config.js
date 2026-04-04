'use strict';

const autocannon = require('autocannon');

const BASE_URL = process.env.LOADTEST_BASE_URL || 'http://localhost:3000';
const DEFAULT_DURATION = 10;
const DEFAULT_CONNECTIONS = 10;

/**
 * Run a load test using autocannon.
 * @param {object} opts
 * @param {string} opts.url - Full URL or path (will be appended to BASE_URL if relative)
 * @param {string} [opts.method='GET'] - HTTP method
 * @param {number} [opts.duration] - Duration in seconds
 * @param {number} [opts.connections] - Number of concurrent connections
 * @param {object} [opts.headers] - Additional headers
 * @param {string|object} [opts.body] - Request body
 * @returns {Promise<object>} autocannon result object
 */
function runTest(opts) {
  const url = opts.url.startsWith('http') ? opts.url : `${BASE_URL}${opts.url}`;

  const config = {
    url,
    method: opts.method || 'GET',
    duration: opts.duration || DEFAULT_DURATION,
    connections: opts.connections || DEFAULT_CONNECTIONS,
  };

  if (opts.headers) {
    config.headers = opts.headers;
  }

  if (opts.body) {
    config.body = typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body);
    config.headers = {
      'content-type': 'application/json',
      ...(config.headers || {}),
    };
  }

  return new Promise((resolve, reject) => {
    const instance = autocannon(config, (err, result) => {
      if (err) {
        reject(err);
      } else {
        resolve(result);
      }
    });

    // Suppress default autocannon output
    autocannon.track(instance, { renderProgressBar: false });
  });
}

module.exports = {
  BASE_URL,
  DEFAULT_DURATION,
  DEFAULT_CONNECTIONS,
  runTest,
};
