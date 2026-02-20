/**
 * Mock Supabase Client
 *
 * Factory function returning a mock client matching @supabase/supabase-js v2 API.
 * Mirrors actual usage in services/documentService.js and services/plaidDataService.js.
 *
 * Supports:
 *   - auth.getUser(), auth.signIn(), auth.signOut()
 *   - from(table).select/insert/update/delete/upsert with chainable .eq(), .neq(), .in(), .order(), .range(), .single()
 *   - storage.from(bucket).upload(), .download(), .remove()
 *   - Configurable responses via setResponse/setError/reset
 *
 * Usage:
 *   const { createMockSupabaseClient } = require('./__tests__/mocks/mockSupabaseClient');
 *   const supabase = createMockSupabaseClient();
 *   supabase.setResponse('from', { data: [{ id: 1 }], error: null });
 */

/**
 * Create a chainable query builder that resolves to { data, error }
 * Mimics Supabase PostgREST query builder behavior
 */
function createQueryBuilder(defaultResponse, errorOverride) {
  // The query builder is a thenable object (has .then()) so it can be awaited directly
  // or chained with additional methods like .eq(), .single(), etc.
  const builder = {
    _response: defaultResponse || { data: [], error: null },
    _error: errorOverride || null,

    // Filter methods (chainable)
    eq(column, value) {
      return builder;
    },
    neq(column, value) {
      return builder;
    },
    gt(column, value) {
      return builder;
    },
    gte(column, value) {
      return builder;
    },
    lt(column, value) {
      return builder;
    },
    lte(column, value) {
      return builder;
    },
    like(column, pattern) {
      return builder;
    },
    ilike(column, pattern) {
      return builder;
    },
    is(column, value) {
      return builder;
    },
    in(column, values) {
      return builder;
    },
    contains(column, value) {
      return builder;
    },
    containedBy(column, value) {
      return builder;
    },
    not(column, operator, value) {
      return builder;
    },
    or(filters) {
      return builder;
    },
    filter(column, operator, value) {
      return builder;
    },

    // Modifier methods (chainable)
    order(column, options) {
      return builder;
    },
    limit(count) {
      return builder;
    },
    range(from, to) {
      return builder;
    },
    select(columns) {
      return builder;
    },

    // Terminal methods (return promise-like)
    single() {
      const response = builder._error
        ? { data: null, error: builder._error }
        : builder._response;

      // For single(), if data is an array, return first element
      if (response.data && Array.isArray(response.data)) {
        return {
          data: response.data[0] || null,
          error: response.error,
          then: (resolve) => resolve({ data: response.data[0] || null, error: response.error })
        };
      }
      return {
        ...response,
        then: (resolve) => resolve(response)
      };
    },

    maybeSingle() {
      return builder.single();
    },

    // Make builder thenable (so it can be awaited)
    then(resolve, reject) {
      const response = builder._error
        ? { data: null, error: builder._error }
        : builder._response;

      if (resolve) {
        return Promise.resolve(response).then(resolve, reject);
      }
      return Promise.resolve(response);
    }
  };

  return builder;
}

/**
 * Create a mock Supabase client instance
 * @returns {Object} Mock Supabase client with auth, from, storage, and test helpers
 */
function createMockSupabaseClient() {
  // Configurable overrides
  let _responseOverrides = {};  // { 'from': {...}, 'auth': {...}, 'storage': {...} }
  let _errorOverrides = {};     // { 'from': Error, 'auth': Error, 'storage': Error }
  let _callHistory = [];

  const client = {
    // ============================================
    // AUTH
    // ============================================
    auth: {
      async getUser(token) {
        _callHistory.push({ method: 'auth.getUser', args: { token }, timestamp: new Date().toISOString() });

        if (_errorOverrides.auth) {
          return { data: { user: null }, error: _errorOverrides.auth };
        }

        if (_responseOverrides.auth) {
          return _responseOverrides.auth;
        }

        return {
          data: {
            user: {
              id: 'mock-user-id-12345',
              email: 'test@example.com',
              app_metadata: { provider: 'email' },
              user_metadata: { name: 'Test User' },
              aud: 'authenticated',
              role: 'authenticated',
              created_at: '2024-01-01T00:00:00.000Z'
            }
          },
          error: null
        };
      },

      async signInWithPassword({ email, password }) {
        _callHistory.push({ method: 'auth.signInWithPassword', args: { email }, timestamp: new Date().toISOString() });

        if (_errorOverrides.auth) {
          return { data: { user: null, session: null }, error: _errorOverrides.auth };
        }

        return {
          data: {
            user: {
              id: 'mock-user-id-12345',
              email,
              role: 'authenticated'
            },
            session: {
              access_token: 'mock-access-token',
              refresh_token: 'mock-refresh-token',
              expires_in: 3600,
              token_type: 'bearer'
            }
          },
          error: null
        };
      },

      async signOut() {
        _callHistory.push({ method: 'auth.signOut', args: {}, timestamp: new Date().toISOString() });
        return { error: null };
      },

      async getSession() {
        _callHistory.push({ method: 'auth.getSession', args: {}, timestamp: new Date().toISOString() });
        return {
          data: {
            session: {
              access_token: 'mock-access-token',
              refresh_token: 'mock-refresh-token',
              expires_in: 3600,
              token_type: 'bearer',
              user: {
                id: 'mock-user-id-12345',
                email: 'test@example.com'
              }
            }
          },
          error: null
        };
      }
    },

    // ============================================
    // DATABASE (from)
    // ============================================

    /**
     * Query builder for database operations
     * Matches: supabase.from(table).select/insert/update/delete/upsert
     *
     * @param {string} table - Table name
     * @returns {Object} Query builder with chainable methods
     */
    from(table) {
      _callHistory.push({ method: 'from', args: { table }, timestamp: new Date().toISOString() });

      const defaultError = _errorOverrides.from || null;
      const customResponse = _responseOverrides.from || null;

      return {
        select(columns) {
          _callHistory.push({ method: 'from.select', args: { table, columns }, timestamp: new Date().toISOString() });
          const response = customResponse || { data: [], error: null };
          return createQueryBuilder(response, defaultError);
        },

        insert(data) {
          _callHistory.push({ method: 'from.insert', args: { table, data }, timestamp: new Date().toISOString() });
          const insertedData = Array.isArray(data) ? data : [data];
          const response = customResponse || { data: insertedData, error: null };
          return createQueryBuilder(response, defaultError);
        },

        update(data) {
          _callHistory.push({ method: 'from.update', args: { table, data }, timestamp: new Date().toISOString() });
          const response = customResponse || { data: [data], error: null };
          return createQueryBuilder(response, defaultError);
        },

        delete() {
          _callHistory.push({ method: 'from.delete', args: { table }, timestamp: new Date().toISOString() });
          const response = customResponse || { data: [], error: null };
          return createQueryBuilder(response, defaultError);
        },

        upsert(data, options) {
          _callHistory.push({ method: 'from.upsert', args: { table, data, options }, timestamp: new Date().toISOString() });
          const upsertedData = Array.isArray(data) ? data : [data];
          const response = customResponse || { data: upsertedData, error: null };
          return createQueryBuilder(response, defaultError);
        }
      };
    },

    // ============================================
    // STORAGE
    // ============================================
    storage: {
      from(bucket) {
        _callHistory.push({ method: 'storage.from', args: { bucket }, timestamp: new Date().toISOString() });

        return {
          async upload(path, fileBody, options) {
            _callHistory.push({ method: 'storage.upload', args: { bucket, path, options }, timestamp: new Date().toISOString() });

            if (_errorOverrides.storage) {
              return { data: null, error: _errorOverrides.storage };
            }

            if (_responseOverrides.storage) {
              return _responseOverrides.storage;
            }

            return {
              data: { path, id: 'mock-file-id', fullPath: `${bucket}/${path}` },
              error: null
            };
          },

          async download(path) {
            _callHistory.push({ method: 'storage.download', args: { bucket, path }, timestamp: new Date().toISOString() });

            if (_errorOverrides.storage) {
              return { data: null, error: _errorOverrides.storage };
            }

            // Return a mock Blob-like object
            const mockContent = Buffer.from('mock file content');
            return {
              data: {
                arrayBuffer: async () => mockContent.buffer,
                text: async () => 'mock file content',
                size: mockContent.length,
                type: 'application/octet-stream'
              },
              error: null
            };
          },

          async remove(paths) {
            _callHistory.push({ method: 'storage.remove', args: { bucket, paths }, timestamp: new Date().toISOString() });

            if (_errorOverrides.storage) {
              return { data: null, error: _errorOverrides.storage };
            }

            return {
              data: paths.map(p => ({ name: p })),
              error: null
            };
          },

          getPublicUrl(path) {
            _callHistory.push({ method: 'storage.getPublicUrl', args: { bucket, path }, timestamp: new Date().toISOString() });
            return {
              data: { publicUrl: `https://mock-supabase.co/storage/v1/object/public/${bucket}/${path}` }
            };
          }
        };
      }
    },

    // ============================================
    // TEST CONFIGURATION METHODS
    // ============================================

    /**
     * Set a custom response for a specific area
     * @param {string} area - 'from', 'auth', or 'storage'
     * @param {Object} response - Response data ({ data, error } format)
     */
    setResponse(area, response) {
      _responseOverrides[area] = response;
    },

    /**
     * Set an error for a specific area
     * @param {string} area - 'from', 'auth', or 'storage'
     * @param {Object} error - Error object (Supabase errors are { message, code, details })
     */
    setError(area, error) {
      _errorOverrides[area] = error;
    },

    /**
     * Reset all overrides and call history
     */
    reset() {
      _responseOverrides = {};
      _errorOverrides = {};
      _callHistory = [];
    },

    /**
     * Get history of all calls made to this mock
     * @returns {Array} Call history entries
     */
    getCallHistory() {
      return [..._callHistory];
    },

    /**
     * Get the number of times a specific method was called
     * @param {string} methodName - Method name (e.g. 'from.insert', 'auth.getUser')
     * @returns {number} Call count
     */
    getCallCount(methodName) {
      return _callHistory.filter(call => call.method === methodName).length;
    }
  };

  return client;
}

module.exports = { createMockSupabaseClient };
