const express = require('express');
const router = express.Router();
const claudeService = require('../services/claudeService');
const { validate } = require('../middleware/validate');
const { analyzeSchema } = require('../schemas/claude');

// POST /v1/ai/claude/analyze
// Analyze mortgage documents using Claude AI
router.post('/analyze', validate(analyzeSchema), async (req, res, next) => {
  try {
    const { prompt, model, maxTokens, temperature, documentText, documentType } = req.body;

    // Build analysis prompt
    let analysisPrompt = prompt;
    if (!analysisPrompt && documentText) {
      analysisPrompt = claudeService.buildMortgageAnalysisPrompt(documentText, documentType);
    }

    console.log(`Analyzing document (type: ${documentType || 'unknown'}, length: ${analysisPrompt.length} chars)`);

    // Call Claude API
    const result = await claudeService.analyzeDocument({
      prompt: analysisPrompt,
      model,
      maxTokens,
      temperature
    });

    res.json({
      success: true,
      analysis: result.content,
      model: result.model,
      usage: result.usage,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Claude analysis error:', error);

    // Handle specific error types
    if (error.status === 401) {
      return res.status(401).json({
        error: 'Authentication Error',
        message: 'Invalid Claude API key. Please check your ANTHROPIC_API_KEY environment variable.'
      });
    }

    if (error.status === 429) {
      return res.status(429).json({
        error: 'Rate Limit Exceeded',
        message: 'Too many requests to Claude API. Please try again later.'
      });
    }

    next(error);
  }
});

// POST /v1/ai/claude/test
// Test Claude API connection
router.post('/test', async (req, res, next) => {
  try {
    const result = await claudeService.analyzeDocument({
      prompt: 'Say "Hello from Mortgage Guardian backend!" in one sentence.',
      model: 'claude-3-5-sonnet-20241022',
      maxTokens: 50,
      temperature: 0.5
    });

    res.json({
      success: true,
      message: 'Claude API is working!',
      response: result.content,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Claude test error:', error);
    next(error);
  }
});

module.exports = router;
