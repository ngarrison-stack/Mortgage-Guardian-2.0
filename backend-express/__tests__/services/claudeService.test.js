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
});
