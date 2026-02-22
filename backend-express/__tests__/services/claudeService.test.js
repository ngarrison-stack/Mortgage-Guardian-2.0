/**
 * Unit tests for ClaudeService (services/claudeService.js)
 *
 * Tests analyzeDocument, buildMortgageAnalysisPrompt, and testConnection
 * with a fully mocked Anthropic SDK to avoid real API calls.
 */

// Must be hoisted above any require() — mocks the module-scope `new Anthropic()`
const mockMessagesCreate = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  return jest.fn().mockImplementation(() => ({
    messages: { create: mockMessagesCreate }
  }));
});

const Anthropic = require('@anthropic-ai/sdk');

// Re-require the service AFTER the mock is in place so the module-scope
// `new Anthropic(...)` uses our mock constructor.
const claudeService = require('../../services/claudeService');

// ============================================================
// analyzeDocument
// ============================================================
describe('ClaudeService', () => {
  describe('analyzeDocument', () => {
    const mockApiResponse = {
      content: [{ text: 'Analysis result text' }],
      model: 'claude-3-5-sonnet-20241022',
      usage: { input_tokens: 100, output_tokens: 50 },
      stop_reason: 'end_turn'
    };

    beforeEach(() => {
      mockMessagesCreate.mockReset();
    });

    it('returns formatted response on success', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      const result = await claudeService.analyzeDocument({ prompt: 'Analyze this document' });

      expect(result).toEqual({
        content: 'Analysis result text',
        model: 'claude-3-5-sonnet-20241022',
        usage: { inputTokens: 100, outputTokens: 50 },
        stopReason: 'end_turn'
      });
    });

    it('forwards model, maxTokens, temperature parameters', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      await claudeService.analyzeDocument({
        prompt: 'test prompt',
        model: 'claude-3-opus-20240229',
        maxTokens: 2048,
        temperature: 0.5
      });

      expect(mockMessagesCreate).toHaveBeenCalledWith({
        model: 'claude-3-opus-20240229',
        max_tokens: 2048,
        temperature: 0.5,
        messages: [{ role: 'user', content: 'test prompt' }]
      });
    });

    it('uses default model when not specified', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      await claudeService.analyzeDocument({ prompt: 'test' });

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({ model: 'claude-3-5-sonnet-20241022' })
      );
    });

    it('uses default maxTokens=4096 and temperature=0.1', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      await claudeService.analyzeDocument({ prompt: 'test' });

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          max_tokens: 4096,
          temperature: 0.1
        })
      );
    });

    it('throws on 401 authentication error', async () => {
      const authError = new Error('Authentication failed');
      authError.status = 401;
      mockMessagesCreate.mockRejectedValue(authError);

      await expect(
        claudeService.analyzeDocument({ prompt: 'test' })
      ).rejects.toThrow('Authentication failed');

      await expect(
        claudeService.analyzeDocument({ prompt: 'test' })
      ).rejects.toMatchObject({ status: 401 });
    });

    it('throws on 429 rate limit error', async () => {
      const rateLimitError = new Error('Rate limit exceeded');
      rateLimitError.status = 429;
      mockMessagesCreate.mockRejectedValue(rateLimitError);

      await expect(
        claudeService.analyzeDocument({ prompt: 'test' })
      ).rejects.toThrow('Rate limit exceeded');

      await expect(
        claudeService.analyzeDocument({ prompt: 'test' })
      ).rejects.toMatchObject({ status: 429 });
    });

    it('throws on network error', async () => {
      mockMessagesCreate.mockRejectedValue(new Error('Network error'));

      await expect(
        claudeService.analyzeDocument({ prompt: 'test' })
      ).rejects.toThrow('Network error');
    });

    it('passes prompt as user message content', async () => {
      mockMessagesCreate.mockResolvedValue(mockApiResponse);

      await claudeService.analyzeDocument({ prompt: 'Analyze my mortgage statement' });

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          messages: [{ role: 'user', content: 'Analyze my mortgage statement' }]
        })
      );
    });
  });

  // ============================================================
  // buildMortgageAnalysisPrompt
  // ============================================================
  describe('buildMortgageAnalysisPrompt', () => {
    const sampleText = 'Monthly payment: $1,234.56. Principal balance: $250,000.';

    it('returns mortgage_statement prompt containing document text', () => {
      const prompt = claudeService.buildMortgageAnalysisPrompt(sampleText, 'mortgage_statement');

      expect(prompt).toContain(sampleText);
      expect(prompt).toMatch(/mortgage auditor/i);
    });

    it('returns escrow_statement prompt', () => {
      const prompt = claudeService.buildMortgageAnalysisPrompt(sampleText, 'escrow_statement');

      expect(prompt).toContain(sampleText);
      expect(prompt).toMatch(/escrow/i);
    });

    it('returns payment_history prompt', () => {
      const prompt = claudeService.buildMortgageAnalysisPrompt(sampleText, 'payment_history');

      expect(prompt).toContain(sampleText);
      expect(prompt).toMatch(/payment history/i);
    });

    it('returns default prompt for unknown type', () => {
      const prompt = claudeService.buildMortgageAnalysisPrompt(sampleText, 'unknown_type');

      expect(prompt).toContain(sampleText);
      expect(prompt).toMatch(/document analyst/i);
    });

    it('returns default prompt when documentType is undefined', () => {
      const prompt = claudeService.buildMortgageAnalysisPrompt(sampleText);

      // Default parameter is 'mortgage_statement', not the fallback default
      expect(prompt).toContain(sampleText);
      expect(prompt).toMatch(/mortgage auditor/i);
    });

    it('embeds documentText in all prompt variants', () => {
      const uniqueText = 'UNIQUE_MARKER_TEXT_12345';
      const types = ['mortgage_statement', 'escrow_statement', 'payment_history', 'unknown_type'];

      types.forEach((type) => {
        const prompt = claudeService.buildMortgageAnalysisPrompt(uniqueText, type);
        expect(prompt).toContain(uniqueText);
      });
    });
  });

  // ============================================================
  // testConnection
  // ============================================================
  describe('testConnection', () => {
    beforeEach(() => {
      mockMessagesCreate.mockReset();
    });

    it('returns success with message when API responds', async () => {
      mockMessagesCreate.mockResolvedValue({
        content: [{ text: 'API connection successful' }],
        model: 'claude-3-5-sonnet-20241022',
        usage: { input_tokens: 10, output_tokens: 5 },
        stop_reason: 'end_turn'
      });

      const result = await claudeService.testConnection();

      expect(result).toEqual({
        success: true,
        message: 'API connection successful'
      });
    });

    it('returns failure with error when API throws', async () => {
      mockMessagesCreate.mockRejectedValue(new Error('Connection refused'));

      const result = await claudeService.testConnection();

      expect(result).toEqual({
        success: false,
        error: 'Connection refused'
      });
    });

    it('calls analyzeDocument with maxTokens: 20', async () => {
      mockMessagesCreate.mockResolvedValue({
        content: [{ text: 'OK' }],
        model: 'claude-3-5-sonnet-20241022',
        usage: { input_tokens: 10, output_tokens: 3 },
        stop_reason: 'end_turn'
      });

      await claudeService.testConnection();

      expect(mockMessagesCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          max_tokens: 20
        })
      );
    });
  });
});
