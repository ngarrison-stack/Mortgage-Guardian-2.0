const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');

// Initialize Plaid client
const configuration = new Configuration({
    basePath: PlaidEnvironments.sandbox, // Use sandbox for development
    baseOptions: {
        headers: {
            'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
            'PLAID-SECRET': process.env.PLAID_SECRET,
        },
    },
});

const client = new PlaidApi(configuration);

exports.handler = async (event) => {
    console.log('Plaid Function triggered');
    console.log('Event:', JSON.stringify(event, null, 2));

    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };

    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    try {
        const path = event.pathParameters?.proxy || '';
        const method = event.httpMethod;
        const body = event.body ? JSON.parse(event.body) : {};

        console.log(`Processing ${method} request for path: ${path}`);

        // Route to appropriate handler
        switch (path) {
            case 'link/token/create':
                return await handleLinkToken(headers, body);

            case 'link_token':
                return await handleLinkToken(headers, body);

            case 'link/token/exchange':
                return await handleExchangeToken(headers, body);

            case 'exchange_token':
                return await handleExchangeToken(headers, body);

            case 'accounts/get':
                return await handleGetAccounts(headers, body);

            case 'accounts':
                return await handleGetAccounts(headers, body);

            case 'transactions':
                return await handleGetTransactions(headers, body);

            default:
                return {
                    statusCode: 404,
                    headers,
                    body: JSON.stringify({
                        error: 'Endpoint not found',
                        availableEndpoints: ['link_token', 'exchange_token', 'accounts', 'transactions']
                    })
                };
        }

    } catch (error) {
        console.error('Error in Plaid Function:', error);

        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Internal server error',
                message: 'Failed to process Plaid request',
                details: process.env.NODE_ENV === 'development' ? error.message : undefined
            })
        };
    }
};

async function handleLinkToken(headers, body) {
    try {
        const { userId } = body;

        const request = {
            user: {
                client_user_id: userId || 'default_user'
            },
            client_name: 'Mortgage Guardian',
            products: ['transactions'],
            country_codes: ['US'],
            language: 'en'
        };

        const response = await client.linkTokenCreate(request);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                link_token: response.data.link_token,
                expiration: response.data.expiration
            })
        };

    } catch (error) {
        console.error('Link token creation error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Failed to create link token',
                message: error.message
            })
        };
    }
}

async function handleExchangeToken(headers, body) {
    try {
        const { public_token } = body;

        if (!public_token) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({
                    error: 'public_token is required'
                })
            };
        }

        const response = await client.itemPublicTokenExchange({
            public_token: public_token
        });

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                access_token: response.data.access_token,
                item_id: response.data.item_id
            })
        };

    } catch (error) {
        console.error('Token exchange error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Failed to exchange token',
                message: error.message
            })
        };
    }
}

async function handleGetAccounts(headers, body) {
    try {
        const { access_token } = body;

        if (!access_token) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({
                    error: 'access_token is required'
                })
            };
        }

        const response = await client.accountsGet({
            access_token: access_token
        });

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                accounts: response.data.accounts,
                item: response.data.item
            })
        };

    } catch (error) {
        console.error('Get accounts error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Failed to get accounts',
                message: error.message
            })
        };
    }
}

async function handleGetTransactions(headers, body) {
    try {
        const { access_token, start_date, end_date, count = 100 } = body;

        if (!access_token) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({
                    error: 'access_token is required'
                })
            };
        }

        const request = {
            access_token: access_token,
            start_date: start_date || '2023-01-01',
            end_date: end_date || new Date().toISOString().split('T')[0],
            count: Math.min(count, 500) // Limit to 500 transactions
        };

        const response = await client.transactionsGet(request);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                transactions: response.data.transactions,
                accounts: response.data.accounts,
                total_transactions: response.data.total_transactions
            })
        };

    } catch (error) {
        console.error('Get transactions error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Failed to get transactions',
                message: error.message
            })
        };
    }
}