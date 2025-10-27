const Anthropic = require('@anthropic-ai/sdk');

const client = new Anthropic({
  apiKey: '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'
});

async function test() {
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
