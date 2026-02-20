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

  // Coverage collection from services and routes
  collectCoverageFrom: [
    'services/**/*.js',
    'routes/**/*.js',
    '!**/node_modules/**',
    '!**/__tests__/**'
  ],

  // Enforce 90% coverage threshold (per PROJECT.md requirements)
  coverageThreshold: {
    global: {
      statements: 90,
      branches: 90,
      functions: 90,
      lines: 90
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
