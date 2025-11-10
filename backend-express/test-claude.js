require('dotenv').config();
const Anthropic = require('@anthropic-ai/sdk');

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY || ''
});

async function test() {
  if (!process.env.ANTHROPIC_API_KEY) {
    console.error('Error: ANTHROPIC_API_KEY not found in environment variables');
    process.exit(1);
  }

  try {
    const response = await client.messages.create({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 50,
      messages: [{
        role: 'user',
        content: 'Say "Hello from Mortgage Guardian!" in one sentence.'
      }]
    });
    console.log('Success:', response.content[0].text);
  } catch (error) {
    console.error('Error:', error.message);
  }
}

test();
