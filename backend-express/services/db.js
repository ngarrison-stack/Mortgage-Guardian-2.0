/**
 * Database Connection Pool
 *
 * Provides a shared pg Pool instance for all service files.
 * Connects to Neon (or any Postgres) using DATABASE_URL.
 *
 * Replaces @supabase/supabase-js database calls with direct SQL.
 */

const { Pool } = require('pg');
const { createLogger } = require('../utils/logger');

const logger = createLogger('db');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL !== 'false' ? { rejectUnauthorized: false } : false,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  logger.error('Unexpected database pool error', { error: err.message });
});

/**
 * Execute a parameterized query.
 *
 * @param {string} text - SQL query with $1, $2, ... placeholders
 * @param {Array} params - Parameter values
 * @returns {Promise<import('pg').QueryResult>}
 */
async function query(text, params) {
  const start = Date.now();
  const result = await pool.query(text, params);
  const duration = Date.now() - start;

  if (duration > 500) {
    logger.warn('Slow query detected', { text: text.slice(0, 100), duration, rows: result.rowCount });
  }

  return result;
}

module.exports = { pool, query };
