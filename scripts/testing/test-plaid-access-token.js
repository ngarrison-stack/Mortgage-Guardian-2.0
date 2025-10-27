const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');

// Test with access token
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

async function testAccessToken() {
    try {
        console.log('Testing Plaid access token...');

        const accessToken = 'efedcb9092244557035e13d268c716';

        // Test accounts endpoint
        const accountsResponse = await client.accountsGet({
            access_token: accessToken
        });

        console.log('✅ SUCCESS: Access token is working!');
        console.log('Accounts found:', accountsResponse.data.accounts.length);

        accountsResponse.data.accounts.forEach((account, index) => {
            console.log(`Account ${index + 1}:`, {
                id: account.account_id,
                name: account.name,
                type: account.type,
                subtype: account.subtype,
                mask: account.mask
            });
        });

        return true;

    } catch (error) {
        console.log('❌ FAILED: Access token test failed');
        console.log('Error:', error.message);
        if (error.response?.data) {
            console.log('Error details:', error.response.data);
        }
        return false;
    }
}

testAccessToken().then(success => {
    if (success) {
        console.log('\n🎉 Plaid access token is valid!');
    } else {
        console.log('\n💥 Access token test failed.');
    }
});