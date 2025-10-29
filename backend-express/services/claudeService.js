const Anthropic = require('@anthropic-ai/sdk');

// Initialize Anthropic client
const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

class ClaudeService {
  /**
   * Analyze document using Claude AI
   */
  async analyzeDocument({ prompt, model = 'claude-3-5-sonnet-20241022', maxTokens = 4096, temperature = 0.1 }) {
    try {
      const response = await client.messages.create({
        model,
        max_tokens: maxTokens,
        temperature,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      });

      return {
        content: response.content[0].text,
        model: response.model,
        usage: {
          inputTokens: response.usage.input_tokens,
          outputTokens: response.usage.output_tokens
        },
        stopReason: response.stop_reason
      };

    } catch (error) {
      console.error('Claude API error:', error);
      throw error;
    }
  }

  /**
   * Build specialized prompt for mortgage document analysis
   */
  buildMortgageAnalysisPrompt(documentText, documentType = 'mortgage_statement') {
    const prompts = {
      mortgage_statement: `You are an expert mortgage auditor. Analyze this mortgage statement and identify any errors, discrepancies, or issues.

Document to analyze:
${documentText}

Please provide:
1. **Summary**: Brief overview of the statement
2. **Key Figures**: Principal balance, interest rate, payment amount, escrow balance
3. **Detected Issues**: Any errors, miscalculations, or red flags
4. **Severity**: Rate each issue as High/Medium/Low
5. **Recommendations**: Steps the homeowner should take

Format your response as structured JSON with these fields:
{
  "summary": "...",
  "keyFigures": {
    "principalBalance": 0,
    "interestRate": 0,
    "monthlyPayment": 0,
    "escrowBalance": 0
  },
  "issues": [
    {
      "title": "...",
      "description": "...",
      "severity": "High|Medium|Low",
      "category": "...",
      "potentialImpact": 0
    }
  ],
  "recommendations": ["..."]
}`,

      escrow_statement: `You are an expert in mortgage escrow account auditing. Analyze this escrow statement for errors.

Document to analyze:
${documentText}

Look for:
- Incorrect property tax calculations
- Insurance premium discrepancies
- Escrow shortage/surplus issues
- Missing or duplicate payments
- Interest calculation errors

Provide detailed analysis in JSON format.`,

      payment_history: `You are a mortgage payment history auditor. Analyze this payment history for discrepancies.

Document to analyze:
${documentText}

Check for:
- Missing payments not recorded
- Late fee charges that shouldn't apply
- Incorrect payment allocation (principal vs interest)
- Unexplained balance changes

Provide analysis in JSON format.`,

      default: `You are an expert mortgage document analyst. Analyze this document and identify any issues or important information.

Document to analyze:
${documentText}

Provide a comprehensive analysis with any findings, issues, or recommendations.`
    };

    return prompts[documentType] || prompts.default;
  }

  /**
   * Test Claude API connection
   */
  async testConnection() {
    try {
      const result = await this.analyzeDocument({
        prompt: 'Say "API connection successful" in 5 words or less.',
        maxTokens: 20
      });

      return {
        success: true,
        message: result.content
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }
}

module.exports = new ClaudeService();
