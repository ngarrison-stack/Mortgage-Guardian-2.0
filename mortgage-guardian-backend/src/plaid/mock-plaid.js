// Mock Plaid service for development and testing
// This provides realistic Plaid API responses without requiring valid credentials

const crypto = require('crypto');

class MockPlaidService {
    constructor() {
        this.mockAccounts = [
            {
                account_id: 'mock_account_1',
                name: 'Chase Checking',
                type: 'depository',
                subtype: 'checking',
                mask: '1234',
                balances: {
                    available: 12543.67,
                    current: 12543.67,
                    limit: null,
                    iso_currency_code: 'USD'
                }
            },
            {
                account_id: 'mock_account_2',
                name: 'Wells Fargo Savings',
                type: 'depository',
                subtype: 'savings',
                mask: '5678',
                balances: {
                    available: 25000.00,
                    current: 25000.00,
                    limit: null,
                    iso_currency_code: 'USD'
                }
            },
            {
                account_id: 'mock_account_3',
                name: 'Citi Credit Card',
                type: 'credit',
                subtype: 'credit card',
                mask: '9012',
                balances: {
                    available: 7500.00,
                    current: -2456.33,
                    limit: 10000.00,
                    iso_currency_code: 'USD'
                }
            },
            {
                account_id: 'mock_account_4',
                name: 'Plaid Student Loan',
                type: 'loan',
                subtype: 'student',
                mask: '5678',
                balances: {
                    available: null,
                    current: 45123.00,
                    limit: null,
                    iso_currency_code: 'USD'
                },
                liability: {
                    type: 'student',
                    origination_date: '2022-01-01',
                    principal: 45123,
                    nominal_apr: 4.23,
                    guarantor: 'DEPT OF ED',
                    loan_name: 'Plaid Student Loan',
                    repayment_model: {
                        type: 'standard',
                        non_repayment_months: 12,
                        repayment_months: 120
                    }
                }
            }
        ];

        this.mockTransactions = [
            {
                transaction_id: 'mock_txn_1',
                account_id: 'mock_account_1',
                amount: -1200.00,
                date: '2025-10-01',
                name: 'MORTGAGE PAYMENT',
                merchant_name: 'QUICKEN LOANS',
                category: ['Payment', 'Mortgage'],
                account_owner: null
            },
            {
                transaction_id: 'mock_txn_2',
                account_id: 'mock_account_1',
                amount: -85.43,
                date: '2025-09-30',
                name: 'ESCROW SHORTAGE',
                merchant_name: 'QUICKEN LOANS',
                category: ['Payment', 'Mortgage'],
                account_owner: null
            },
            {
                transaction_id: 'mock_txn_3',
                account_id: 'mock_account_1',
                amount: 3500.00,
                date: '2025-09-29',
                name: 'PAYROLL DEPOSIT',
                merchant_name: 'ACME CORP',
                category: ['Deposit', 'Payroll'],
                account_owner: null
            }
        ];
    }

    generateLinkToken(userId) {
        const linkToken = `link-sandbox-${crypto.randomUUID()}`;
        const expiration = new Date();
        expiration.setHours(expiration.getHours() + 4); // 4 hours from now

        return {
            link_token: linkToken,
            expiration: expiration.toISOString()
        };
    }

    exchangePublicToken(publicToken) {
        const accessToken = `access-sandbox-${crypto.randomUUID()}`;
        const itemId = `item-sandbox-${crypto.randomUUID()}`;

        return {
            access_token: accessToken,
            item_id: itemId
        };
    }

    getAccounts(accessToken) {
        return {
            accounts: this.mockAccounts,
            item: {
                item_id: `item-sandbox-${crypto.randomUUID()}`,
                institution_id: 'ins_3',
                webhook: null,
                error: null,
                available_products: ['transactions', 'auth'],
                billed_products: ['transactions']
            }
        };
    }

    getTransactions(accessToken, startDate, endDate, count = 100) {
        // Filter transactions by date range if provided
        let filteredTransactions = this.mockTransactions;

        if (startDate) {
            filteredTransactions = filteredTransactions.filter(txn =>
                new Date(txn.date) >= new Date(startDate)
            );
        }

        if (endDate) {
            filteredTransactions = filteredTransactions.filter(txn =>
                new Date(txn.date) <= new Date(endDate)
            );
        }

        // Limit results
        filteredTransactions = filteredTransactions.slice(0, Math.min(count, 500));

        return {
            transactions: filteredTransactions,
            accounts: this.mockAccounts,
            total_transactions: filteredTransactions.length
        };
    }

    // Helper to check if we should use mock service
    static shouldUseMock(clientId, secret) {
        // Force mock mode if explicitly requested
        if (process.env.USE_MOCK_PLAID === 'true') return true;

        // Use real Plaid if we have what looks like valid credentials
        if (clientId && secret && secret.length >= 30) {
            console.log('🔗 Attempting to use real Plaid API');
            return false;
        }

        // Default to mock for safety
        console.log('🧪 Using Mock Plaid Service (safer fallback)');
        return true;
    }
}

module.exports = MockPlaidService;