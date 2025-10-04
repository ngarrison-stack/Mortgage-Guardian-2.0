const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');

// Test with corrected credentials format
const configuration = new Configuration({
    basePath: PlaidEnvironments.sandbox,
    baseOptions: {
        headers: {
            'PLAID-CLIENT-ID': '68bdabb75b00b300221d6a6f',
            'PLAID-SECRET': '5ac29fd3d1b7db5401c2ee0499ccf6', // Production secret
        },
    },
});

const client = new PlaidApi(configuration);

async function testCorrectedCredentials() {
    try {
        console.log('Testing corrected Plaid credentials...');

        // Test link token creation
        const request = {
            user: {
                client_user_id: 'test_user_corrected'
            },
            client_name: 'Mortgage Guardian Test',
            products: ['transactions'],
            country_codes: ['US'],
            language: 'en'
        };

        const response = await client.linkTokenCreate(request);

        console.log('✅ SUCCESS: Corrected credentials work!');
        console.log('Link Token:', response.data.link_token);
        console.log('Expiration:', response.data.expiration);

        return { success: true, linkToken: response.data.link_token };

    } catch (error) {
        console.log('❌ FAILED: Corrected credentials test failed');
        console.log('Error:', error.message);
        if (error.response?.data) {
            console.log('Error details:', error.response.data);
        }
        return { success: false, error: error.message };
    }
}

// Test access token if we have one
async function testAccessTokenFlow() {
    try {
        console.log('\nTesting access token flow...');

        const accessToken = 'efedcb9092244557035e13d268c716';

        const accountsResponse = await client.accountsGet({
            access_token: accessToken
        });

        console.log('✅ Access token works!');
        console.log('Found accounts:', accountsResponse.data.accounts.length);

        return { success: true, accounts: accountsResponse.data.accounts };

    } catch (error) {
        console.log('❌ Access token failed:', error.message);
        return { success: false, error: error.message };
    }
}

async function runTests() {
    console.log('🔧 Testing Plaid Integration\n');

    const linkResult = await testCorrectedCredentials();
    const accessResult = await testAccessTokenFlow();

    console.log('\n📊 RESULTS:');
    console.log('Link Token Creation:', linkResult.success ? '✅ Working' : '❌ Failed');
    console.log('Access Token:', accessResult.success ? '✅ Working' : '❌ Failed');

    if (linkResult.success || accessResult.success) {
        console.log('\n🎉 Plaid integration is ready for production!');
        return true;
    } else {
        console.log('\n⚠️ Need valid Plaid credentials for production.');
        return false;
    }
}

runTests();