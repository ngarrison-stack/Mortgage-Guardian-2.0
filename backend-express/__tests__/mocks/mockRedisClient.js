/**
 * Mock Redis Client (ioredis v5 compatible)
 *
 * In-memory implementation matching ioredis v5 API signatures used in:
 *   - services/financialSecurityService.js
 *   - services/vendorNeutralSecurityService.js
 *
 * Supports: get, set, setex, del, exists, incr, decr, expire, ttl,
 *           sadd, sismember, srem, smembers, keys, flushall
 *
 * All methods return Promises (matching ioredis async behavior).
 *
 * Usage:
 *   const { createMockRedisClient } = require('./__tests__/mocks/mockRedisClient');
 *   const redis = createMockRedisClient();
 *   await redis.set('key', 'value');
 *   await redis.get('key'); // => 'value'
 *   redis.clear(); // reset between tests
 */

/**
 * Create a mock Redis client with in-memory storage
 * @returns {Object} Mock Redis client matching ioredis v5 API
 */
function createMockRedisClient() {
  // In-memory stores
  let _store = new Map();       // key => value (strings/numbers)
  let _sets = new Map();        // key => Set (for set operations)
  let _expiries = new Map();    // key => { expireAt: timestamp }
  let _callHistory = [];

  /**
   * Check if a key has expired and remove it if so
   * @param {string} key
   * @returns {boolean} true if key is still valid (not expired)
   */
  function isKeyValid(key) {
    if (_expiries.has(key)) {
      const { expireAt } = _expiries.get(key);
      if (Date.now() >= expireAt) {
        // Key has expired - remove it
        _store.delete(key);
        _sets.delete(key);
        _expiries.delete(key);
        return false;
      }
    }
    return true;
  }

  const client = {
    // ============================================
    // STRING OPERATIONS
    // ============================================

    /**
     * Get the value of a key
     * @param {string} key
     * @returns {Promise<string|null>}
     */
    async get(key) {
      _callHistory.push({ method: 'get', args: [key], timestamp: new Date().toISOString() });
      if (!isKeyValid(key)) return null;
      const value = _store.get(key);
      return value !== undefined ? value : null;
    },

    /**
     * Set the value of a key, with optional EX (seconds) or PX (milliseconds) expiry
     * Supports: set(key, value), set(key, value, 'EX', seconds), set(key, value, 'PX', ms)
     * @param {string} key
     * @param {string|number} value
     * @param {...*} args - Optional expiry arguments
     * @returns {Promise<string>} 'OK'
     */
    async set(key, value, ...args) {
      _callHistory.push({ method: 'set', args: [key, value, ...args], timestamp: new Date().toISOString() });
      _store.set(key, String(value));

      // Parse optional expiry args: 'EX' seconds or 'PX' milliseconds
      for (let i = 0; i < args.length; i += 2) {
        const flag = typeof args[i] === 'string' ? args[i].toUpperCase() : null;
        const val = args[i + 1];
        if (flag === 'EX' && val != null) {
          _expiries.set(key, { expireAt: Date.now() + (Number(val) * 1000) });
        } else if (flag === 'PX' && val != null) {
          _expiries.set(key, { expireAt: Date.now() + Number(val) });
        }
      }

      return 'OK';
    },

    /**
     * Set key with expiry in seconds (shorthand for SET key value EX seconds)
     * @param {string} key
     * @param {number} seconds - TTL in seconds
     * @param {string|number} value
     * @returns {Promise<string>} 'OK'
     */
    async setex(key, seconds, value) {
      _callHistory.push({ method: 'setex', args: [key, seconds, value], timestamp: new Date().toISOString() });
      _store.set(key, String(value));
      _expiries.set(key, { expireAt: Date.now() + (seconds * 1000) });
      return 'OK';
    },

    /**
     * Delete one or more keys
     * @param {...string} keys
     * @returns {Promise<number>} Number of keys removed
     */
    async del(...keys) {
      // Flatten in case an array is passed
      const flatKeys = keys.flat();
      _callHistory.push({ method: 'del', args: flatKeys, timestamp: new Date().toISOString() });
      let count = 0;
      for (const key of flatKeys) {
        if (_store.has(key) || _sets.has(key)) {
          _store.delete(key);
          _sets.delete(key);
          _expiries.delete(key);
          count++;
        }
      }
      return count;
    },

    /**
     * Check if one or more keys exist
     * @param {...string} keys
     * @returns {Promise<number>} Number of keys that exist
     */
    async exists(...keys) {
      const flatKeys = keys.flat();
      _callHistory.push({ method: 'exists', args: flatKeys, timestamp: new Date().toISOString() });
      let count = 0;
      for (const key of flatKeys) {
        if (isKeyValid(key) && (_store.has(key) || _sets.has(key))) {
          count++;
        }
      }
      return count;
    },

    /**
     * Increment the integer value of a key by 1
     * @param {string} key
     * @returns {Promise<number>} New value after increment
     */
    async incr(key) {
      _callHistory.push({ method: 'incr', args: [key], timestamp: new Date().toISOString() });
      if (!isKeyValid(key)) {
        _store.set(key, '0');
      }
      const current = parseInt(_store.get(key) || '0', 10);
      const newVal = current + 1;
      _store.set(key, String(newVal));
      return newVal;
    },

    /**
     * Decrement the integer value of a key by 1
     * @param {string} key
     * @returns {Promise<number>} New value after decrement
     */
    async decr(key) {
      _callHistory.push({ method: 'decr', args: [key], timestamp: new Date().toISOString() });
      if (!isKeyValid(key)) {
        _store.set(key, '0');
      }
      const current = parseInt(_store.get(key) || '0', 10);
      const newVal = current - 1;
      _store.set(key, String(newVal));
      return newVal;
    },

    /**
     * Increment the integer value of a key by a given amount
     * @param {string} key
     * @param {number} increment
     * @returns {Promise<number>} New value
     */
    async incrby(key, increment) {
      _callHistory.push({ method: 'incrby', args: [key, increment], timestamp: new Date().toISOString() });
      if (!isKeyValid(key)) {
        _store.set(key, '0');
      }
      const current = parseInt(_store.get(key) || '0', 10);
      const newVal = current + increment;
      _store.set(key, String(newVal));
      return newVal;
    },

    // ============================================
    // EXPIRY OPERATIONS
    // ============================================

    /**
     * Set a key's time to live in seconds
     * @param {string} key
     * @param {number} seconds
     * @returns {Promise<number>} 1 if timeout was set, 0 if key does not exist
     */
    async expire(key, seconds) {
      _callHistory.push({ method: 'expire', args: [key, seconds], timestamp: new Date().toISOString() });
      if (!_store.has(key) && !_sets.has(key)) {
        return 0;
      }
      _expiries.set(key, { expireAt: Date.now() + (seconds * 1000) });
      return 1;
    },

    /**
     * Get the remaining TTL of a key in seconds
     * @param {string} key
     * @returns {Promise<number>} TTL in seconds, -1 if no expiry, -2 if key doesn't exist
     */
    async ttl(key) {
      _callHistory.push({ method: 'ttl', args: [key], timestamp: new Date().toISOString() });

      if (!isKeyValid(key)) return -2;
      if (!_store.has(key) && !_sets.has(key)) return -2;
      if (!_expiries.has(key)) return -1;

      const { expireAt } = _expiries.get(key);
      const remaining = Math.ceil((expireAt - Date.now()) / 1000);
      return remaining > 0 ? remaining : -2;
    },

    /**
     * Get the remaining TTL of a key in milliseconds
     * @param {string} key
     * @returns {Promise<number>} TTL in ms, -1 if no expiry, -2 if key doesn't exist
     */
    async pttl(key) {
      _callHistory.push({ method: 'pttl', args: [key], timestamp: new Date().toISOString() });

      if (!isKeyValid(key)) return -2;
      if (!_store.has(key) && !_sets.has(key)) return -2;
      if (!_expiries.has(key)) return -1;

      const { expireAt } = _expiries.get(key);
      const remaining = expireAt - Date.now();
      return remaining > 0 ? remaining : -2;
    },

    // ============================================
    // SET OPERATIONS
    // ============================================

    /**
     * Add one or more members to a set
     * @param {string} key
     * @param {...string} members
     * @returns {Promise<number>} Number of members added (not already present)
     */
    async sadd(key, ...members) {
      const flatMembers = members.flat();
      _callHistory.push({ method: 'sadd', args: [key, ...flatMembers], timestamp: new Date().toISOString() });

      if (!_sets.has(key)) {
        _sets.set(key, new Set());
      }
      const set = _sets.get(key);
      let added = 0;
      for (const member of flatMembers) {
        if (!set.has(String(member))) {
          set.add(String(member));
          added++;
        }
      }
      return added;
    },

    /**
     * Check if a member is in a set
     * @param {string} key
     * @param {string} member
     * @returns {Promise<number>} 1 if member exists, 0 if not
     */
    async sismember(key, member) {
      _callHistory.push({ method: 'sismember', args: [key, member], timestamp: new Date().toISOString() });

      if (!isKeyValid(key)) return 0;
      const set = _sets.get(key);
      if (!set) return 0;
      return set.has(String(member)) ? 1 : 0;
    },

    /**
     * Remove one or more members from a set
     * @param {string} key
     * @param {...string} members
     * @returns {Promise<number>} Number of members removed
     */
    async srem(key, ...members) {
      const flatMembers = members.flat();
      _callHistory.push({ method: 'srem', args: [key, ...flatMembers], timestamp: new Date().toISOString() });

      const set = _sets.get(key);
      if (!set) return 0;
      let removed = 0;
      for (const member of flatMembers) {
        if (set.delete(String(member))) {
          removed++;
        }
      }
      return removed;
    },

    /**
     * Get all members of a set
     * @param {string} key
     * @returns {Promise<Array<string>>}
     */
    async smembers(key) {
      _callHistory.push({ method: 'smembers', args: [key], timestamp: new Date().toISOString() });

      if (!isKeyValid(key)) return [];
      const set = _sets.get(key);
      if (!set) return [];
      return Array.from(set);
    },

    // ============================================
    // KEY OPERATIONS
    // ============================================

    /**
     * Find all keys matching a pattern
     * Supports simple glob: * matches everything
     * @param {string} pattern
     * @returns {Promise<Array<string>>}
     */
    async keys(pattern) {
      _callHistory.push({ method: 'keys', args: [pattern], timestamp: new Date().toISOString() });

      const allKeys = new Set([..._store.keys(), ..._sets.keys()]);
      if (pattern === '*') {
        return Array.from(allKeys).filter(k => isKeyValid(k));
      }

      // Simple glob matching: convert * to .*
      const regex = new RegExp('^' + pattern.replace(/\*/g, '.*').replace(/\?/g, '.') + '$');
      return Array.from(allKeys).filter(k => isKeyValid(k) && regex.test(k));
    },

    /**
     * Delete all keys in the current database
     * @returns {Promise<string>} 'OK'
     */
    async flushall() {
      _callHistory.push({ method: 'flushall', args: [], timestamp: new Date().toISOString() });
      _store.clear();
      _sets.clear();
      _expiries.clear();
      return 'OK';
    },

    // ============================================
    // CONNECTION (no-ops for compatibility)
    // ============================================

    async ping() {
      _callHistory.push({ method: 'ping', args: [], timestamp: new Date().toISOString() });
      return 'PONG';
    },

    async quit() {
      _callHistory.push({ method: 'quit', args: [], timestamp: new Date().toISOString() });
      return 'OK';
    },

    async disconnect() {
      _callHistory.push({ method: 'disconnect', args: [], timestamp: new Date().toISOString() });
      return 'OK';
    },

    // Status property (ioredis uses this)
    status: 'ready',

    // Event emitter stubs
    on(event, callback) {
      return client;
    },

    once(event, callback) {
      return client;
    },

    // ============================================
    // TEST UTILITY METHODS
    // ============================================

    /**
     * Clear all data and reset state (use between tests)
     */
    clear() {
      _store.clear();
      _sets.clear();
      _expiries.clear();
      _callHistory = [];
    },

    /**
     * Get call history
     * @returns {Array} Call history entries
     */
    getCallHistory() {
      return [..._callHistory];
    },

    /**
     * Get the number of times a specific method was called
     * @param {string} methodName
     * @returns {number}
     */
    getCallCount(methodName) {
      return _callHistory.filter(call => call.method === methodName).length;
    },

    /**
     * Get the current size of the store (for debugging)
     * @returns {Object} { strings, sets, expiries }
     */
    getStoreSize() {
      return {
        strings: _store.size,
        sets: _sets.size,
        expiries: _expiries.size
      };
    }
  };

  return client;
}

module.exports = { createMockRedisClient };
