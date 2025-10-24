const express = require('express');
const router = express.Router();
const plaidService = require('../services/plaidService');

// POST /v1/plaid/link_token
// Create Plaid Link token for bank connection
router.post('/link_token', async (req, res, next) => {
  try {
    const { user_id, clientName } = req.body;

    if (!user_id) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'user_id is required'
      });
    }

    const linkToken = await plaidService.createLinkToken({
      userId: user_id,
      clientName: clientName || 'Mortgage Guardian'
    });

    res.json({
      link_token: linkToken,
      expiration: new Date(Date.now() + 3600000).toISOString() // 1 hour
    });

  } catch (error) {
    console.error('Link token creation error:', error);
    next(error);
  }
});

// POST /v1/plaid/sandbox_public_token
// Create sandbox public token (for testing)
router.post('/sandbox_public_token', async (req, res, next) => {
  try {
    const { institution_id, initial_products } = req.body;

    const publicToken = await plaidService.createSandboxPublicToken({
      institutionId: institution_id || 'ins_109508',
      initialProducts: initial_products || ['transactions']
    });

    res.json({
      public_token: publicToken
    });

  } catch (error) {
    console.error('Sandbox token creation error:', error);
    next(error);
  }
});

// POST /v1/plaid/exchange_token
// Exchange public token for access token
router.post('/exchange_token', async (req, res, next) => {
  try {
    const { public_token } = req.body;

    if (!public_token) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'public_token is required'
      });
    }

    const result = await plaidService.exchangePublicToken(public_token);

    res.json({
      access_token: result.accessToken,
      item_id: result.itemId
    });

  } catch (error) {
    console.error('Token exchange error:', error);
    next(error);
  }
});

// POST /v1/plaid/accounts
// Get account information
router.post('/accounts', async (req, res, next) => {
  try {
    const { access_token } = req.body;

    if (!access_token) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'access_token is required'
      });
    }

    const accounts = await plaidService.getAccounts(access_token);

    res.json({
      accounts,
      total: accounts.length
    });

  } catch (error) {
    console.error('Get accounts error:', error);
    next(error);
  }
});

// POST /v1/plaid/transactions
// Get transaction history
router.post('/transactions', async (req, res, next) => {
  try {
    const { access_token, start_date, end_date } = req.body;

    if (!access_token) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'access_token is required'
      });
    }

    const transactions = await plaidService.getTransactions({
      accessToken: access_token,
      startDate: start_date || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
      endDate: end_date || new Date().toISOString().split('T')[0]
    });

    res.json({
      transactions,
      total: transactions.length
    });

  } catch (error) {
    console.error('Get transactions error:', error);
    next(error);
  }
});

// POST /v1/plaid/test
// Test Plaid connection
router.post('/test', async (req, res, next) => {
  try {
    const status = await plaidService.testConnection();
    res.json(status);
  } catch (error) {
    console.error('Plaid test error:', error);
    next(error);
  }
});

module.exports = router;
