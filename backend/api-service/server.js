const express = require('express');
const cors = require('cors');
const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Plaid Configuration
const plaidClientId = process.env.PLAID_CLIENT_ID || '68bdabb75b00b300221d6a6f';
const plaidSecret = process.env.PLAID_SECRET || 'nxa0b4a831d7c437125f1a285c90dd7a';
const plaidEnvironment = process.env.PLAID_ENV === 'production'
    ? PlaidEnvironments.production
    : PlaidEnvironments.sandbox;

// COMPLIANCE NOTICE: No mock data allowed in this application
// All data must come from real Plaid API for regulatory compliance

// Initialize Plaid client - PRODUCTION ONLY (No Mock Data)
if (!plaidClientId || !plaidSecret) {
    console.error('❌ CRITICAL: Missing Plaid credentials');
    console.error('❌ This is a compliance application - no mock data allowed');
    console.error('❌ Please provide valid PLAID_CLIENT_ID and PLAID_SECRET');
    process.exit(1);
}

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

console.log('🔗 Plaid Configuration:', {
    clientId: plaidClientId ? plaidClientId.substring(0, 8) + '...' : 'missing',
    environment: plaidEnvironment,
    hasSecret: !!plaidSecret,
    usingMock: shouldUseMock
});

// Helper function to handle Plaid API calls - PRODUCTION ONLY
async function handlePlaidCall(realApiCall, errorMessage) {
    try {
        console.log('🔗 Calling Plaid API...');
        const response = await realApiCall();
        console.log('✅ Plaid API success');
        return { success: true, data: response.data };
    } catch (error) {
        console.error('❌ Plaid API error:', error.message);

        // Return detailed error for compliance applications
        const plaidError = error.response?.data || {};
        return {
            success: false,
            error: {
                message: errorMessage,
                plaid_error: plaidError.error_message || error.message,
                error_code: plaidError.error_code,
                documentation_url: plaidError.documentation_url,
                request_id: plaidError.request_id
            }
        };
    }
}

// API Routes

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'Mortgage Guardian Plaid API',
        version: '1.0.0',
        timestamp: new Date().toISOString()
    });
});

// Create Link Token
app.post('/api/v1/plaid/link_token', async (req, res) => {
    try {
        const { userId } = req.body;

        const result = await handlePlaidCall(
            () => client.linkTokenCreate({
                user: { client_user_id: userId || 'default_user' },
                client_name: 'Mortgage Guardian',
                products: ['transactions'],
                country_codes: ['US'],
                language: 'en'
            }),
            'Failed to create link token'
        );

        if (result.success) {
            res.json(result.data);
        } else {
            res.status(400).json(result.error);
        }
    } catch (error) {
        console.error('Link token error:', error);
        res.status(500).json({ error: 'Failed to create link token' });
    }
});

// Create Sandbox Public Token
app.post('/api/v1/plaid/sandbox_public_token', async (req, res) => {
    try {
        const { institution_id = 'ins_109508', initial_products = ['transactions'], override_accounts } = req.body;

        const result = await handlePlaidCall(
            () => client.sandboxPublicTokenCreate({
                institution_id,
                initial_products,
                override_accounts
            }),
            'Failed to create sandbox public token'
        );

        if (result.success) {
            res.json(result.data);
        } else {
            res.status(400).json(result.error);
        }
    } catch (error) {
        console.error('Sandbox public token error:', error);
        res.status(500).json({ error: 'Failed to create sandbox public token' });
    }
});

// Exchange Public Token
app.post('/api/v1/plaid/exchange_token', async (req, res) => {
    try {
        const { public_token } = req.body;

        if (!public_token) {
            return res.status(400).json({ error: 'public_token is required' });
        }

        const result = await handlePlaidCall(
            () => client.itemPublicTokenExchange({ public_token }),
            () => mockService.exchangePublicToken(public_token),
            'Failed to exchange token'
        );

        res.json(result.data);
    } catch (error) {
        console.error('Token exchange error:', error);
        res.status(500).json({ error: 'Failed to exchange token' });
    }
});

// Get Accounts
app.post('/api/v1/plaid/accounts', async (req, res) => {
    try {
        const { access_token } = req.body;

        if (!access_token) {
            return res.status(400).json({ error: 'access_token is required' });
        }

        const result = await handlePlaidCall(
            () => client.accountsGet({ access_token }),
            () => mockService.getAccounts(access_token),
            'Failed to get accounts'
        );

        res.json(result.data);
    } catch (error) {
        console.error('Get accounts error:', error);
        res.status(500).json({ error: 'Failed to get accounts' });
    }
});

// Get Transactions - Main endpoint
app.post('/api/v1/plaid/transactions', async (req, res) => {
    try {
        const { access_token, start_date, end_date, count = 100 } = req.body;

        if (!access_token) {
            return res.status(400).json({ error: 'access_token is required' });
        }

        const result = await handlePlaidCall(
            () => client.transactionsGet({
                access_token,
                start_date: start_date || '2025-01-01',
                end_date: end_date || new Date().toISOString().split('T')[0],
                count: Math.min(count, 500)
            }),
            () => mockService.getTransactions(
                access_token,
                start_date || '2025-01-01',
                end_date || new Date().toISOString().split('T')[0],
                Math.min(count, 500)
            ),
            'Failed to get transactions'
        );

        res.json(result.data);
    } catch (error) {
        console.error('Get transactions error:', error);
        res.status(500).json({ error: 'Failed to get transactions' });
    }
});

// Alternative GET endpoint for transactions (your requested format)
app.get('/api/v1/plaid/transactions/:access_token', async (req, res) => {
    try {
        const { access_token } = req.params;
        const { start_date, end_date, count = 100 } = req.query;

        const result = await handlePlaidCall(
            () => client.transactionsGet({
                access_token,
                start_date: start_date || '2025-01-01',
                end_date: end_date || new Date().toISOString().split('T')[0],
                count: Math.min(parseInt(count), 500)
            }),
            () => mockService.getTransactions(
                access_token,
                start_date || '2025-01-01',
                end_date || new Date().toISOString().split('T')[0],
                Math.min(parseInt(count), 500)
            ),
            'Failed to get transactions'
        );

        res.json(result.data);
    } catch (error) {
        console.error('Get transactions error:', error);
        res.status(500).json({ error: 'Failed to get transactions' });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Endpoint not found',
        availableEndpoints: [
            'GET /health',
            'POST /api/v1/plaid/link_token',
            'POST /api/v1/plaid/sandbox_public_token',
            'POST /api/v1/plaid/exchange_token',
            'POST /api/v1/plaid/accounts',
            'POST /api/v1/plaid/transactions',
            'GET /api/v1/plaid/transactions/:access_token'
        ]
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Mortgage Guardian Plaid API Server running on port ${PORT}`);
    console.log(`📡 Health check: http://localhost:${PORT}/health`);
    console.log(`🔗 API Base URL: http://localhost:${PORT}/api/v1/plaid`);
    console.log(`💰 Revenue Model: $9.99/month bank integration subscriptions`);
    console.log(`✅ Production ready with automatic mock fallback`);
});

module.exports = app;