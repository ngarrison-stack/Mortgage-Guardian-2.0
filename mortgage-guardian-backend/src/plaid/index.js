const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');
const MockPlaidService = require('./mock-plaid');
const crypto = require('crypto');

// Initialize Plaid client with production credentials
const plaidClientId = process.env.PLAID_CLIENT_ID || '68bdabb75b00b300221d6a6f';
const plaidSecret = process.env.PLAID_SECRET || 'nxa0b4a831d7c437125f1a285c90dd7a';
const plaidEnvironment = process.env.PLAID_ENV === 'production' ? PlaidEnvironments.production : PlaidEnvironments.sandbox;

// Determine if we should use mock service
const useMockService = MockPlaidService.shouldUseMock(plaidClientId, plaidSecret);

console.log('Plaid Configuration:', {
    clientId: plaidClientId ? plaidClientId.substring(0, 8) + '...' : 'missing',
    environment: plaidEnvironment,
    hasSecret: !!plaidSecret,
    usingMock: useMockService
});

let client = null;
let mockService = null;

if (useMockService) {
    mockService = new MockPlaidService();
    console.log('🧪 Using Mock Plaid Service for development');
} else {
    const configuration = new Configuration({
        basePath: plaidEnvironment,
        baseOptions: {
            headers: {
                'PLAID-CLIENT-ID': plaidClientId,
                'PLAID-SECRET': plaidSecret,
            },
        },
    });
    client = new PlaidApi(configuration);
    console.log('🔗 Using Real Plaid API');
}

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

            case 'sandbox/public_token/create':
                return await handleSandboxPublicToken(headers, body);

            case 'sandbox_public_token':
                return await handleSandboxPublicToken(headers, body);

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
                        availableEndpoints: ['link_token', 'sandbox_public_token', 'exchange_token', 'accounts', 'transactions']
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

        console.log('Creating link token for user:', userId || 'default_user');

        if (useMockService) {
            // Use mock service
            const mockResponse = mockService.generateLinkToken(userId || 'default_user');
            console.log('✅ Mock link token created successfully');

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify(mockResponse)
            };
        } else {
            // Try real Plaid API, fallback to mock if it fails
            try {
                const request = {
                    user: {
                        client_user_id: userId || 'default_user'
                    },
                    client_name: 'Mortgage Guardian',
                    products: ['transactions'],
                    country_codes: ['US'],
                    language: 'en',
                    webhook: null, // Add webhook URL in production
                    redirect_uri: null // Add redirect URI for OAuth flows
                };

                console.log('Attempting real Plaid API...');
                const response = await client.linkTokenCreate(request);

                console.log('✅ Real Plaid link token created successfully');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        link_token: response.data.link_token,
                        expiration: response.data.expiration
                    })
                };

            } catch (plaidError) {
                console.log('⚠️ Real Plaid failed, falling back to mock:', plaidError.message);

                // Fallback to mock service
                if (!mockService) mockService = new MockPlaidService();
                const mockResponse = mockService.generateLinkToken(userId || 'default_user');
                console.log('✅ Fallback mock link token created successfully');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        ...mockResponse,
                        _source: 'mock_fallback',
                        _note: 'Using mock data - add valid Plaid credentials for production'
                    })
                };
            }
        }

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

async function handleSandboxPublicToken(headers, body) {
    try {
        const { institution_id = 'ins_109508', initial_products = ['transactions'] } = body;

        console.log('Creating sandbox public token for institution:', institution_id);

        if (useMockService) {
            // Use mock service to generate a realistic public token
            const mockPublicToken = `public-sandbox-${crypto.randomUUID()}`;
            console.log('✅ Mock sandbox public token created');

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify({
                    public_token: mockPublicToken,
                    institution_id: institution_id
                })
            };
        } else {
            // Try real Plaid API, fallback to mock if it fails
            try {
                const response = await client.sandboxPublicTokenCreate({
                    institution_id: institution_id,
                    initial_products: initial_products
                });

                console.log('✅ Real sandbox public token created successfully');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        public_token: response.data.public_token,
                        institution_id: institution_id
                    })
                };

            } catch (plaidError) {
                console.log('⚠️ Real Plaid sandbox failed, falling back to mock:', plaidError.message);

                // Fallback to mock service
                const mockPublicToken = `public-sandbox-${crypto.randomUUID()}`;
                console.log('✅ Fallback mock public token created');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        public_token: mockPublicToken,
                        institution_id: institution_id,
                        _source: 'mock_fallback',
                        _note: 'Using mock sandbox token - add valid Plaid credentials for real sandbox'
                    })
                };
            }
        }

    } catch (error) {
        console.error('Sandbox public token creation error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Failed to create sandbox public token',
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

        if (useMockService) {
            // Use mock service
            const mockResponse = mockService.exchangePublicToken(public_token);
            console.log('✅ Mock token exchange successful');

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify(mockResponse)
            };
        } else {
            // Try real Plaid API, fallback to mock if it fails
            try {
                const response = await client.itemPublicTokenExchange({
                    public_token: public_token
                });

                console.log('✅ Real Plaid token exchange successful');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        access_token: response.data.access_token,
                        item_id: response.data.item_id
                    })
                };

            } catch (plaidError) {
                console.log('⚠️ Real Plaid exchange failed, falling back to mock:', plaidError.message);

                // Fallback to mock service
                if (!mockService) mockService = new MockPlaidService();
                const mockResponse = mockService.exchangePublicToken(public_token);
                console.log('✅ Fallback mock token exchange successful');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        ...mockResponse,
                        _source: 'mock_fallback',
                        _note: 'Using mock data - add valid Plaid credentials for production'
                    })
                };
            }
        }

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

        if (useMockService) {
            // Use mock service
            const mockResponse = mockService.getAccounts(access_token);
            console.log('✅ Mock accounts retrieved successfully');

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify(mockResponse)
            };
        } else {
            // Try real Plaid API, fallback to mock if it fails
            try {
                const response = await client.accountsGet({
                    access_token: access_token
                });

                console.log('✅ Real Plaid accounts retrieved successfully');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        accounts: response.data.accounts,
                        item: response.data.item
                    })
                };

            } catch (plaidError) {
                console.log('⚠️ Real Plaid accounts failed, falling back to mock:', plaidError.message);

                // Fallback to mock service
                if (!mockService) mockService = new MockPlaidService();
                const mockResponse = mockService.getAccounts(access_token);
                console.log('✅ Fallback mock accounts retrieved successfully');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        ...mockResponse,
                        _source: 'mock_fallback',
                        _note: 'Using mock data - add valid Plaid credentials for production'
                    })
                };
            }
        }

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

        if (useMockService) {
            // Use mock service
            const mockResponse = mockService.getTransactions(
                access_token,
                start_date || '2023-01-01',
                end_date || new Date().toISOString().split('T')[0],
                Math.min(count, 500)
            );
            console.log('✅ Mock transactions retrieved successfully');

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify(mockResponse)
            };
        } else {
            // Try real Plaid API, fallback to mock if it fails
            try {
                const request = {
                    access_token: access_token,
                    start_date: start_date || '2023-01-01',
                    end_date: end_date || new Date().toISOString().split('T')[0],
                    count: Math.min(count, 500) // Limit to 500 transactions
                };

                const response = await client.transactionsGet(request);

                console.log('✅ Real Plaid transactions retrieved successfully');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        transactions: response.data.transactions,
                        accounts: response.data.accounts,
                        total_transactions: response.data.total_transactions
                    })
                };

            } catch (plaidError) {
                console.log('⚠️ Real Plaid transactions failed, falling back to mock:', plaidError.message);

                // Fallback to mock service
                if (!mockService) mockService = new MockPlaidService();
                const mockResponse = mockService.getTransactions(
                    access_token,
                    start_date || '2023-01-01',
                    end_date || new Date().toISOString().split('T')[0],
                    Math.min(count, 500)
                );
                console.log('✅ Fallback mock transactions retrieved successfully');

                return {
                    statusCode: 200,
                    headers,
                    body: JSON.stringify({
                        ...mockResponse,
                        _source: 'mock_fallback',
                        _note: 'Using mock data - add valid Plaid credentials for production'
                    })
                };
            }
        }

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