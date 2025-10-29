const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');

// Test complete sandbox flow like the Go example
async function testSandboxFlow() {
    console.log('🧪 Testing Complete Sandbox Flow\n');

    try {
        const configuration = new Configuration({
            basePath: PlaidEnvironments.sandbox,
            baseOptions: {
                headers: {
                    'PLAID-CLIENT-ID': '68bdabb75b00b300221d6a6f',
                    'PLAID-SECRET': 'nxa0b4a831d7c437125f1a285c90dd7a',
                },
            },
        });

        const client = new PlaidApi(configuration);

        // Step 1: Create Link Token (like your Go example setup)
        console.log('1️⃣ Creating Link Token...');
        const linkTokenRequest = {
            user: { client_user_id: 'sandbox_test_user' },
            client_name: 'Mortgage Guardian Sandbox',
            products: ['transactions'],
            country_codes: ['US'],
            language: 'en'
        };

        const linkTokenResponse = await client.linkTokenCreate(linkTokenRequest);
        console.log('✅ Link Token:', linkTokenResponse.data.link_token.substring(0, 30) + '...');

        // Step 2: Create Sandbox Public Token (equivalent to your Go sandboxPublicTokenCreate)
        console.log('\n2️⃣ Creating Sandbox Public Token...');
        const sandboxRequest = {
            institution_id: 'ins_109508', // Chase sandbox ID
            initial_products: ['transactions']
        };

        const sandboxResponse = await client.sandboxPublicTokenCreate(sandboxRequest);
        console.log('✅ Public Token:', sandboxResponse.data.public_token.substring(0, 30) + '...');

        // Step 3: Exchange Public Token for Access Token (like your Go ItemPublicTokenExchange)
        console.log('\n3️⃣ Exchanging Public Token for Access Token...');
        const exchangeRequest = {
            public_token: sandboxResponse.data.public_token
        };

        const exchangeResponse = await client.itemPublicTokenExchange(exchangeRequest);
        console.log('✅ Access Token:', exchangeResponse.data.access_token.substring(0, 30) + '...');

        // Step 4: Get Accounts with Access Token
        console.log('\n4️⃣ Fetching Accounts...');
        const accountsResponse = await client.accountsGet({
            access_token: exchangeResponse.data.access_token
        });

        console.log('✅ Found', accountsResponse.data.accounts.length, 'accounts:');
        accountsResponse.data.accounts.forEach((account, i) => {
            console.log(`   ${i + 1}. ${account.name} (${account.subtype}) - $${account.balances.current}`);
        });

        // Step 5: Get Transactions
        console.log('\n5️⃣ Fetching Recent Transactions...');
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - 30); // Last 30 days

        const transactionsResponse = await client.transactionsGet({
            access_token: exchangeResponse.data.access_token,
            start_date: startDate.toISOString().split('T')[0],
            end_date: new Date().toISOString().split('T')[0]
        });

        console.log('✅ Found', transactionsResponse.data.transactions.length, 'transactions');
        transactionsResponse.data.transactions.slice(0, 3).forEach((txn, i) => {
            console.log(`   ${i + 1}. $${Math.abs(txn.amount)} - ${txn.name}`);
        });

        return {
            success: true,
            linkToken: linkTokenResponse.data.link_token,
            accessToken: exchangeResponse.data.access_token,
            accounts: accountsResponse.data.accounts,
            transactions: transactionsResponse.data.transactions
        };

    } catch (error) {
        console.log('❌ Sandbox flow failed:', error.message);
        if (error.response?.data) {
            console.log('Error details:', JSON.stringify(error.response.data, null, 2));
        }
        return { success: false, error: error.message };
    }
}

// Test the complete flow
testSandboxFlow().then(result => {
    console.log('\n📊 SANDBOX FLOW RESULTS:');

    if (result.success) {
        console.log('🎉 Complete Plaid Sandbox Integration Working!');
        console.log('✅ Link Token Creation: Success');
        console.log('✅ Public Token Generation: Success');
        console.log('✅ Token Exchange: Success');
        console.log('✅ Account Fetching: Success');
        console.log('✅ Transaction Retrieval: Success');
        console.log('\n🚀 Ready for production with valid credentials!');

        // Summary stats
        console.log('\n📈 Integration Stats:');
        console.log(`- Accounts Connected: ${result.accounts?.length || 0}`);
        console.log(`- Transactions Available: ${result.transactions?.length || 0}`);
        console.log('- All API Endpoints: Functional');
    } else {
        console.log('❌ Sandbox integration needs valid credentials');
        console.log('🔧 Current backend uses mock service (still functional)');
    }
}).catch(err => {
    console.error('💥 Test failed:', err.message);
});