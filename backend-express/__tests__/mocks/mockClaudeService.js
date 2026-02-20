/**
 * Mock Claude AI Service
 *
 * Matches the interface of services/claudeService.js (ClaudeService class singleton).
 * Provides configurable responses and error simulation for isolated unit testing.
 *
 * Usage:
 *   const mockClaude = require('./__tests__/mocks/mockClaudeService');
 *   mockClaude.setResponse({ content: 'custom response' });
 *   mockClaude.setError(new Error('API failure'));
 *   mockClaude.reset();
 */

// Default response matching the real ClaudeService.analyzeDocument return shape
const DEFAULT_RESPONSE = {
  content: JSON.stringify({
    summary: 'Mock analysis of mortgage document',
    keyFigures: {
      principalBalance: 250000,
      interestRate: 3.75,
      monthlyPayment: 1158.04,
      escrowBalance: 3200.00
    },
    issues: [
      {
        title: 'Escrow Calculation Discrepancy',
        description: 'The escrow payment amount does not match the sum of projected disbursements.',
        severity: 'Medium',
        category: 'Escrow',
        potentialImpact: 450
      }
    ],
    recommendations: [
      'Request an escrow analysis from your servicer',
      'Verify property tax amounts with your county assessor'
    ]
  }),
  model: 'claude-3-5-sonnet-20241022',
  usage: {
    inputTokens: 1250,
    outputTokens: 480
  },
  stopReason: 'end_turn'
};

const DEFAULT_TEST_CONNECTION_RESPONSE = {
  success: true,
  message: 'API connection successful'
};

// Internal state
let _customResponse = null;
let _customError = null;
let _callHistory = [];

const mockClaudeService = {
  /**
   * Analyze document using Claude AI (mock)
   * Matches: ClaudeService.analyzeDocument({ prompt, model, maxTokens, temperature })
   *
   * @param {Object} params
   * @param {string} params.prompt - The prompt to send
   * @param {string} [params.model] - Model identifier
   * @param {number} [params.maxTokens] - Maximum tokens in response
   * @param {number} [params.temperature] - Temperature setting
   * @returns {Promise<Object>} Mock analysis response
   */
  async analyzeDocument({ prompt, model = 'claude-3-5-sonnet-20241022', maxTokens = 4096, temperature = 0.1 } = {}) {
    _callHistory.push({
      method: 'analyzeDocument',
      args: { prompt, model, maxTokens, temperature },
      timestamp: new Date().toISOString()
    });

    if (_customError) {
      const error = _customError;
      _customError = null; // Reset after throwing (one-shot error)
      throw error;
    }

    if (_customResponse) {
      return { ...DEFAULT_RESPONSE, ..._customResponse };
    }

    return { ...DEFAULT_RESPONSE };
  },

  /**
   * Build specialized prompt for mortgage document analysis (mock)
   * Matches: ClaudeService.buildMortgageAnalysisPrompt(documentText, documentType)
   *
   * @param {string} documentText - Document text to analyze
   * @param {string} [documentType='mortgage_statement'] - Type of document
   * @returns {string} Prompt string
   */
  buildMortgageAnalysisPrompt(documentText, documentType = 'mortgage_statement') {
    _callHistory.push({
      method: 'buildMortgageAnalysisPrompt',
      args: { documentText, documentType },
      timestamp: new Date().toISOString()
    });

    return `Mock analysis prompt for ${documentType}: ${documentText ? documentText.substring(0, 100) : '(empty)'}`;
  },

  /**
   * Test Claude API connection (mock)
   * Matches: ClaudeService.testConnection()
   *
   * @returns {Promise<Object>} Connection status
   */
  async testConnection() {
    _callHistory.push({
      method: 'testConnection',
      args: {},
      timestamp: new Date().toISOString()
    });

    if (_customError) {
      const error = _customError;
      _customError = null;
      return {
        success: false,
        error: error.message
      };
    }

    return { ...DEFAULT_TEST_CONNECTION_RESPONSE };
  },

  // ============================================
  // TEST CONFIGURATION METHODS
  // ============================================

  /**
   * Set a custom response for the next call(s)
   * @param {Object} data - Response data to merge with defaults
   */
  setResponse(data) {
    _customResponse = data;
  },

  /**
   * Set an error to throw on the next call
   * Error is consumed after one use (one-shot)
   * @param {Error} error - Error to throw
   */
  setError(error) {
    _customError = error;
  },

  /**
   * Reset mock to default state
   * Clears custom responses, errors, and call history
   */
  reset() {
    _customResponse = null;
    _customError = null;
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
   * @param {string} methodName - Name of the method
   * @returns {number} Call count
   */
  getCallCount(methodName) {
    return _callHistory.filter(call => call.method === methodName).length;
  }
};

module.exports = mockClaudeService;
