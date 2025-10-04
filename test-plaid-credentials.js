const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');

// Test Plaid credentials
const configuration = new Configuration({
    basePath: PlaidEnvironments.sandbox,
    baseOptions: {
        headers: {
            'PLAID-CLIENT-ID': '68bdabb75b00b300221d6a6f',
            'PLAID-SECRET': 'd6fb7eb39202fe6d245be89b1cd99c',
        },
    },
});

const client = new PlaidApi(configuration);

async function testPlaidCredentials() {
    try {
        console.log('Testing Plaid credentials...');

        const request = {
            user: {
                client_user_id: 'test_user_credentials'
            },
            client_name: 'Mortgage Guardian Test',
            products: ['transactions'],
            country_codes: ['US'],
            language: 'en'
        };

        const response = await client.linkTokenCreate(request);

        console.log('✅ SUCCESS: Plaid credentials are working!');
        console.log('Link Token:', response.data.link_token);
        console.log('Expiration:', response.data.expiration);

        return true;

    } catch (error) {
        console.log('❌ FAILED: Plaid credentials test failed');
        console.log('Error:', error.message);
        if (error.response?.data) {
            console.log('Error details:', error.response.data);
        }
        return false;
    }
}

testPlaidCredentials().then(success => {
    if (success) {
        console.log('\n🎉 Plaid integration is ready!');
    } else {
        console.log('\n💥 Fix Plaid credentials and try again.');
    }
});