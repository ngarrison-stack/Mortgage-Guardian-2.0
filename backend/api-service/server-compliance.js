const express = require('express');
const cors = require('cors');
const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// COMPLIANCE NOTICE: This application is for mortgage servicing compliance
// NO MOCK DATA ALLOWED - All data must be from real financial institutions

// Plaid Configuration - PRODUCTION CREDENTIALS REQUIRED
const plaidClientId = process.env.PLAID_CLIENT_ID;
const plaidSecret = process.env.PLAID_SECRET;
const plaidEnvironment = process.env.PLAID_ENV === 'production'
    ? PlaidEnvironments.production
    : PlaidEnvironments.sandbox;

// Validate credentials are present
if (!plaidClientId || !plaidSecret) {
    console.error('❌ CRITICAL ERROR: Missing Plaid credentials');
    console.error('❌ COMPLIANCE REQUIREMENT: Valid PLAID_CLIENT_ID and PLAID_SECRET required');
    console.error('❌ This application handles mortgage data - no fake data permitted');
    console.error('❌ Please contact Plaid to obtain valid production credentials');
    process.exit(1);
}

// Initialize Plaid client
const configuration = new Configuration({
    basePath: plaidEnvironment,
    baseOptions: {
        headers: {
            'PLAID-CLIENT-ID': plaidClientId,
            'PLAID-SECRET': plaidSecret,
        },
    },
});

const client = new PlaidApi(configuration);

console.log('🏦 Mortgage Guardian Compliance API Starting...');
console.log('🔐 Plaid Environment:', plaidEnvironment);
console.log('🚫 Mock Data: DISABLED (Compliance Required)');

// Helper function for Plaid API calls with proper error handling
async function callPlaidAPI(apiCall, errorContext) {
    try {
        console.log(`🔗 Calling Plaid API: ${errorContext}`);
        const response = await apiCall();
        console.log(`✅ Plaid API Success: ${errorContext}`);
        return { success: true, data: response.data };
    } catch (error) {
        console.error(`❌ Plaid API Error: ${errorContext}`, error.message);

        const plaidError = error.response?.data || {};
        return {
            success: false,
            error: {
                message: `${errorContext} failed`,
                plaid_error: plaidError.error_message || error.message,
                error_code: plaidError.error_code || 'UNKNOWN_ERROR',
                error_type: plaidError.error_type || 'API_ERROR',
                documentation_url: plaidError.documentation_url,
                request_id: plaidError.request_id,
                suggested_action: plaidError.suggested_action
            }
        };
    }
}

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'Mortgage Guardian Compliance API',
        version: '2.0.0',
        compliance_mode: 'ENABLED',
        mock_data: 'DISABLED',
        plaid_environment: plaidEnvironment,
        timestamp: new Date().toISOString()
    });
});

// Create Link Token - Required for Plaid Link initialization
app.post('/api/v1/plaid/link_token', async (req, res) => {
    try {
        const { userId, products = ['transactions'], webhook } = req.body;

        if (!userId) {
            return res.status(400).json({
                error: 'Missing required field: userId',
                message: 'User ID is required for compliance tracking'
            });
        }

        const result = await callPlaidAPI(
            () => client.linkTokenCreate({
                user: { client_user_id: userId },
                client_name: 'Mortgage Guardian',
                products: products,
                country_codes: ['US'],
                language: 'en',
                webhook: webhook || null
            }),
            'Link Token Creation'
        );

        if (result.success) {
            res.json(result.data);
        } else {
            res.status(400).json(result.error);
        }
    } catch (error) {
        console.error('Link token creation error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to create link token'
        });
    }
});

// Exchange Public Token for Access Token
app.post('/api/v1/plaid/exchange_token', async (req, res) => {
    try {
        const { public_token } = req.body;

        if (!public_token) {
            return res.status(400).json({
                error: 'Missing required field: public_token',
                message: 'Public token is required to exchange for access token'
            });
        }

        const result = await callPlaidAPI(
            () => client.itemPublicTokenExchange({ public_token }),
            'Public Token Exchange'
        );

        if (result.success) {
            res.json(result.data);
        } else {
            res.status(400).json(result.error);
        }
    } catch (error) {
        console.error('Token exchange error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to exchange public token'
        });
    }
});

// Get Account Information
app.post('/api/v1/plaid/accounts', async (req, res) => {
    try {
        const { access_token } = req.body;

        if (!access_token) {
            return res.status(400).json({
                error: 'Missing required field: access_token',
                message: 'Access token is required to retrieve account data'
            });
        }

        const result = await callPlaidAPI(
            () => client.accountsGet({ access_token }),
            'Account Retrieval'
        );

        if (result.success) {
            res.json(result.data);
        } else {
            res.status(400).json(result.error);
        }
    } catch (error) {
        console.error('Account retrieval error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to retrieve account information'
        });
    }
});

// Get Transaction History
app.post('/api/v1/plaid/transactions', async (req, res) => {
    try {
        const { access_token, start_date, end_date, count = 100 } = req.body;

        if (!access_token) {
            return res.status(400).json({
                error: 'Missing required field: access_token',
                message: 'Access token is required to retrieve transaction data'
            });
        }

        if (!start_date || !end_date) {
            return res.status(400).json({
                error: 'Missing required fields: start_date and end_date',
                message: 'Date range is required for compliance and audit purposes'
            });
        }

        const result = await callPlaidAPI(
            () => client.transactionsGet({
                access_token,
                start_date,
                end_date,
                count: Math.min(parseInt(count), 500) // Limit to 500 transactions
            }),
            'Transaction Retrieval'
        );

        if (result.success) {
            res.json(result.data);
        } else {
            res.status(400).json(result.error);
        }
    } catch (error) {
        console.error('Transaction retrieval error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to retrieve transaction data'
        });
    }
});

// Alternative GET endpoint for transactions (your requested format)
app.get('/api/v1/plaid/transactions/:access_token', async (req, res) => {
    try {
        const { access_token } = req.params;
        const { start_date, end_date, count = 100 } = req.query;

        if (!start_date || !end_date) {
            return res.status(400).json({
                error: 'Missing required query parameters: start_date and end_date',
                message: 'Date range is required for compliance and audit purposes'
            });
        }

        const result = await callPlaidAPI(
            () => client.transactionsGet({
                access_token,
                start_date,
                end_date,
                count: Math.min(parseInt(count), 500)
            }),
            'Transaction Retrieval (GET)'
        );

        if (result.success) {
            res.json(result.data);
        } else {
            res.status(400).json(result.error);
        }
    } catch (error) {
        console.error('Transaction retrieval error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to retrieve transaction data'
        });
    }
});

// Create Sandbox Public Token (for testing with valid credentials only)
app.post('/api/v1/plaid/sandbox_public_token', async (req, res) => {
    try {
        if (plaidEnvironment !== PlaidEnvironments.sandbox) {
            return res.status(403).json({
                error: 'Sandbox endpoint not available in production',
                message: 'This endpoint is only available in sandbox environment'
            });
        }

        const { institution_id = 'ins_109508', initial_products = ['transactions'], override_accounts } = req.body;

        const result = await callPlaidAPI(
            () => client.sandboxPublicTokenCreate({
                institution_id,
                initial_products,
                override_accounts
            }),
            'Sandbox Public Token Creation'
        );

        if (result.success) {
            res.json(result.data);
        } else {
            res.status(400).json(result.error);
        }
    } catch (error) {
        console.error('Sandbox token creation error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to create sandbox public token'
        });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({
        error: 'Internal server error',
        message: 'An unexpected error occurred'
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Endpoint not found',
        message: 'The requested API endpoint does not exist',
        available_endpoints: [
            'GET /health',
            'POST /api/v1/plaid/link_token',
            'POST /api/v1/plaid/exchange_token',
            'POST /api/v1/plaid/accounts',
            'POST /api/v1/plaid/transactions',
            'GET /api/v1/plaid/transactions/:access_token',
            'POST /api/v1/plaid/sandbox_public_token (sandbox only)'
        ]
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`🏦 Mortgage Guardian Compliance API running on port ${PORT}`);
    console.log(`📡 Health check: http://localhost:${PORT}/health`);
    console.log(`🔗 API Base URL: http://localhost:${PORT}/api/v1/plaid`);
    console.log(`⚖️ COMPLIANCE MODE: All data from real financial institutions only`);
    console.log(`🚫 MOCK DATA: Completely disabled for regulatory compliance`);
    console.log(`✅ Ready for mortgage servicing compliance audits`);
});

module.exports = app;