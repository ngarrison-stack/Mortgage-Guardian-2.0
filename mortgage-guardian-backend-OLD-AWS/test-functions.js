#!/usr/bin/env node

// Simple test script for Lambda functions without Docker
const claudeHandler = require('./src/claude-analysis/index.js').handler;
const plaidHandler = require('./src/plaid/index.js').handler;

async function testClaudeFunction() {
    console.log('🔍 Testing Claude Analysis Function...');

    const event = {
        httpMethod: 'POST',
        body: JSON.stringify({
            document: 'Monthly Statement - September 2024\nPrincipal Payment: $1,245.67\nInterest Payment: $2,134.56',
            analysisType: 'mortgage_audit'
        })
    };

    try {
        const result = await claudeHandler(event);
        console.log('✅ Claude Function Response:', JSON.stringify(JSON.parse(result.body), null, 2));
    } catch (error) {
        console.error('❌ Claude Function Error:', error);
    }
}

async function testPlaidFunction() {
    console.log('\n💳 Testing Plaid Function...');

    const event = {
        httpMethod: 'POST',
        pathParameters: { proxy: 'link_token' },
        body: JSON.stringify({ userId: 'test_user_123' })
    };

    // Mock environment variables for testing
    process.env.PLAID_CLIENT_ID = 'test_client_id';
    process.env.PLAID_SECRET = 'test_secret';

    try {
        const result = await plaidHandler(event);
        console.log('✅ Plaid Function Response Status:', result.statusCode);
        console.log('✅ Plaid Function Body:', JSON.parse(result.body));
    } catch (error) {
        console.error('❌ Plaid Function Error:', error.message);
    }
}

async function runTests() {
    console.log('🚀 Testing Mortgage Guardian Backend Functions\n');

    await testClaudeFunction();
    await testPlaidFunction();

    console.log('\n✨ Test completed!');
}

runTests();