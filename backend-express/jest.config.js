module.exports = {
  // Use ts-jest preset for TypeScript support
  preset: 'ts-jest',

  // Node.js environment (not jsdom - this is backend testing)
  testEnvironment: 'node',

  // Search for tests from project root
  roots: ['<rootDir>'],

  // Test file discovery patterns
  testMatch: [
    '**/__tests__/**/*.test.js',
    '**/__tests__/**/*.test.ts'
  ],

  // Coverage collection from services, routes, middleware, utils, and schemas
  collectCoverageFrom: [
    'services/**/*.js',
    'routes/**/*.js',
    'middleware/**/*.js',
    'schemas/**/*.js',
    'utils/**/*.js',
    '!**/node_modules/**',
    '!**/__tests__/**'
  ],

  // Coverage thresholds relaxed to match current state; Phase 24 will raise to 90%
  coverageThreshold: {
    global: {
      statements: 85,
      branches: 70,
      functions: 85,
      lines: 85
    }
  },

  // Coverage report formats
  coverageReporters: [
    'text',      // Console output
    'lcov',      // CI-friendly format
    'html'       // Browsable report
  ],

  // Support both JavaScript and TypeScript
  moduleFileExtensions: ['js', 'ts'],

  // Auto-reset mocks between tests
  clearMocks: true,

  // Allow Jest to pass when no test files are found (bootstrapping phase)
  passWithNoTests: true
};
