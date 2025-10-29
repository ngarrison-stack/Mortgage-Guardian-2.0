# Plaid API Integration Documentation

## Overview

This document describes the production-ready Plaid API integration for the Mortgage Guardian backend. The implementation follows Plaid API v2024 standards with comprehensive security, error handling, and webhook support.

## Table of Contents

1. [Authentication & Security](#authentication--security)
2. [API Endpoints](#api-endpoints)
3. [Webhook Integration](#webhook-integration)
4. [Error Handling](#error-handling)
5. [Best Practices](#best-practices)
6. [iOS Integration](#ios-integration)
7. [Testing](#testing)

---

## Authentication & Security

### Environment Configuration

Configure the following environment variables:

```bash
PLAID_CLIENT_ID=your-client-id
PLAID_SECRET=your-secret-key
PLAID_ENV=sandbox|development|production
PLAID_WEBHOOK_URL=https://your-domain.com/v1/plaid/webhook
PLAID_WEBHOOK_VERIFICATION_KEY=your-webhook-key
```

### Environments

- **Sandbox**: Testing with fake data (free)
- **Development**: Testing with real banks, up to 100 items (free)
- **Production**: Live production use (requires Plaid approval)

### Access Token Security

**CRITICAL SECURITY NOTES:**

1. **Never expose access tokens** to the client or in logs
2. **Store access tokens encrypted** in your database
3. **Associate tokens with user IDs** using secure methods
4. **Rotate tokens** if compromised
5. **Use HTTPS** for all API communications
6. **Implement rate limiting** to prevent abuse

---

## API Endpoints

All endpoints are prefixed with `/v1/plaid`

### 1. Create Link Token

**Endpoint:** `POST /v1/plaid/link_token`

Initialize Plaid Link flow to connect a bank account.

**Request Body:**
```json
{
  "user_id": "unique-user-identifier",
  "client_name": "Mortgage Guardian",
  "redirect_uri": "https://app.example.com/oauth-redirect",
  "access_token": "access-token-for-update-mode",
  "products": ["auth", "transactions"]
}
```

**Required Fields:**
- `user_id`: Unique identifier for your user (max 255 chars)

**Optional Fields:**
- `client_name`: Display name shown in Plaid Link (default: "Mortgage Guardian")
- `redirect_uri`: OAuth redirect URI for institutions requiring OAuth
- `access_token`: For update mode (re-authentication of existing connection)
- `products`: Array of Plaid products (default: ["auth", "transactions"])

**Response:**
```json
{
  "link_token": "link-sandbox-...",
  "expiration": "2024-01-15T10:30:00.000Z",
  "request_id": "req_..."
}
```

**Link Token Lifetime:** 4 hours

**Example:**
```javascript
const response = await fetch('https://api.example.com/v1/plaid/link_token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_12345',
    client_name: 'Mortgage Guardian'
  })
});
const { link_token } = await response.json();
```

---

### 2. Exchange Public Token

**Endpoint:** `POST /v1/plaid/exchange_token`

Exchange a public token (from Plaid Link success) for an access token.

**Request Body:**
```json
{
  "public_token": "public-sandbox-..."
}
```

**Required Fields:**
- `public_token`: Public token from Plaid Link success callback

**Response:**
```json
{
  "access_token": "access-sandbox-...",
  "item_id": "item_...",
  "request_id": "req_...",
  "warning": "Store access_token securely. Never expose in logs or to unauthorized parties."
}
```

**Security Warning:**
This endpoint returns the access token. In a typical production setup, you should:
1. Store the access token encrypted in your database
2. Associate it with the user_id
3. Return only a reference ID to the client
4. Never send the access token to the iOS client

For this mortgage auditing use case where the iOS app manages connections, we return it, but it MUST be stored securely in the iOS Keychain.

**Example:**
```javascript
const response = await fetch('https://api.example.com/v1/plaid/exchange_token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    public_token: 'public-sandbox-abc123...'
  })
});
const { access_token, item_id } = await response.json();
// CRITICAL: Store access_token securely!
```

---

### 3. Get Accounts

**Endpoint:** `POST /v1/plaid/accounts`

Retrieve account information and balances.

**Request Body:**
```json
{
  "access_token": "access-sandbox-...",
  "account_ids": ["acc_123", "acc_456"]
}
```

**Required Fields:**
- `access_token`: Plaid access token

**Optional Fields:**
- `account_ids`: Array of specific account IDs to fetch (fetches all if omitted)

**Response:**
```json
{
  "accounts": [
    {
      "accountId": "acc_...",
      "name": "Plaid Checking",
      "officialName": "Plaid Gold Standard 0% Interest Checking",
      "type": "depository",
      "subtype": "checking",
      "mask": "0000",
      "balances": {
        "available": 100.0,
        "current": 110.0,
        "limit": null,
        "currency": "USD",
        "unofficialCurrency": null
      },
      "verificationStatus": "verified"
    }
  ],
  "item": {
    "itemId": "item_...",
    "institutionId": "ins_...",
    "webhook": "https://your-domain.com/webhook",
    "availableProducts": ["balance", "identity", "transactions"],
    "billedProducts": ["auth", "transactions"],
    "consentExpirationTime": null,
    "updateType": "background"
  },
  "requestId": "req_..."
}
```

**Account Types:**
- `depository`: Checking, savings, money market, CD
- `credit`: Credit cards
- `loan`: Mortgages, auto loans, student loans
- `investment`: Brokerage, retirement accounts

**Example:**
```javascript
const response = await fetch('https://api.example.com/v1/plaid/accounts', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    access_token: 'access-sandbox-...'
  })
});
const { accounts, item } = await response.json();
```

---

### 4. Get Transactions

**Endpoint:** `POST /v1/plaid/transactions`

Retrieve transaction history with pagination support.

**Request Body:**
```json
{
  "access_token": "access-sandbox-...",
  "start_date": "2024-01-01",
  "end_date": "2024-01-31",
  "account_ids": ["acc_123"],
  "count": 100,
  "offset": 0
}
```

**Required Fields:**
- `access_token`: Plaid access token
- `start_date`: Start date in YYYY-MM-DD format
- `end_date`: End date in YYYY-MM-DD format

**Optional Fields:**
- `account_ids`: Array of specific account IDs (fetches all if omitted)
- `count`: Number of transactions to fetch (1-500, default: 100)
- `offset`: Pagination offset (default: 0)

**Constraints:**
- Maximum date range: 2 years (730 days)
- Maximum count per request: 500
- Transactions available: Up to 24 months of history

**Response:**
```json
{
  "transactions": [
    {
      "transactionId": "txn_...",
      "accountId": "acc_...",
      "amount": 12.50,
      "date": "2024-01-15",
      "authorizedDate": "2024-01-14",
      "name": "Starbucks",
      "merchantName": "Starbucks",
      "originalDescription": "STARBUCKS STORE 12345",
      "category": ["Food and Drink", "Restaurants", "Coffee Shop"],
      "categoryId": "13005043",
      "personalFinanceCategory": {
        "primary": "FOOD_AND_DRINK",
        "detailed": "FOOD_AND_DRINK_COFFEE"
      },
      "pending": false,
      "pendingTransactionId": null,
      "paymentChannel": "in store",
      "transactionType": "place",
      "transactionCode": null,
      "location": {
        "address": "123 Main St",
        "city": "San Francisco",
        "region": "CA",
        "postalCode": "94101",
        "country": "US",
        "lat": 37.7749,
        "lon": -122.4194
      },
      "paymentMeta": {
        "referenceNumber": "123456",
        "ppdId": null,
        "payee": null,
        "byOrderOf": null,
        "payer": null,
        "paymentMethod": null,
        "paymentProcessor": null,
        "reason": null
      },
      "accountOwner": null,
      "isoCurrencyCode": "USD",
      "unofficialCurrencyCode": null
    }
  ],
  "totalTransactions": 150,
  "accounts": [
    {
      "accountId": "acc_...",
      "name": "Plaid Checking",
      "type": "depository",
      "subtype": "checking",
      "mask": "0000"
    }
  ],
  "requestId": "req_..."
}
```

**Pagination Example:**
```javascript
// Fetch first 100 transactions
let offset = 0;
let allTransactions = [];

while (true) {
  const response = await fetch('https://api.example.com/v1/plaid/transactions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      access_token: 'access-sandbox-...',
      start_date: '2024-01-01',
      end_date: '2024-01-31',
      count: 100,
      offset: offset
    })
  });

  const { transactions, totalTransactions } = await response.json();
  allTransactions = [...allTransactions, ...transactions];

  if (allTransactions.length >= totalTransactions) break;
  offset += 100;
}
```

---

### 5. Get Item Information

**Endpoint:** `POST /v1/plaid/item`

Retrieve information about a bank connection (Item).

**Request Body:**
```json
{
  "access_token": "access-sandbox-..."
}
```

**Response:**
```json
{
  "itemId": "item_...",
  "institutionId": "ins_109508",
  "webhook": "https://your-domain.com/webhook",
  "error": null,
  "availableProducts": ["balance", "identity", "transactions"],
  "billedProducts": ["auth", "transactions"],
  "consentExpirationTime": "2025-01-15T10:30:00.000Z",
  "updateType": "background",
  "requestId": "req_..."
}
```

**Item Errors:**
If the `error` field is not null, it indicates an issue with the connection:
- `ITEM_LOGIN_REQUIRED`: User needs to re-authenticate via Link update mode
- `ITEM_NOT_SUPPORTED`: Institution no longer supported
- `INSUFFICIENT_CREDENTIALS`: Additional credentials required

---

### 6. Update Webhook URL

**Endpoint:** `POST /v1/plaid/item/webhook`

Update the webhook URL for an Item.

**Request Body:**
```json
{
  "access_token": "access-sandbox-...",
  "webhook": "https://your-domain.com/v1/plaid/webhook"
}
```

**Required Fields:**
- `access_token`: Plaid access token
- `webhook`: New webhook URL (must be HTTPS in production)

**Response:**
```json
{
  "itemId": "item_...",
  "webhook": "https://your-domain.com/v1/plaid/webhook",
  "requestId": "req_..."
}
```

---

### 7. Remove Item

**Endpoint:** `DELETE /v1/plaid/item`

Remove an Item and revoke access to the institution.

**Request Body:**
```json
{
  "access_token": "access-sandbox-..."
}
```

**Response:**
```json
{
  "removed": true,
  "requestId": "req_..."
}
```

**Note:** After removal, the access token becomes invalid and cannot be used.

---

### 8. Create Sandbox Public Token (Testing Only)

**Endpoint:** `POST /v1/plaid/sandbox_public_token`

Create a sandbox public token for testing without Plaid Link.

**Only available in sandbox/development environments.**

**Request Body:**
```json
{
  "institution_id": "ins_109508",
  "initial_products": ["transactions"]
}
```

**Response:**
```json
{
  "public_token": "public-sandbox-..."
}
```

**Common Sandbox Institution IDs:**
- `ins_109508`: First Platypus Bank (default)
- `ins_109509`: First Gingham Credit Union
- `ins_109510`: Tattersall Federal Credit Union

---

### 9. Test Connection

**Endpoint:** `POST /v1/plaid/test`

Test Plaid API connection and configuration.

**Request Body:** None

**Response:**
```json
{
  "success": true,
  "usingMock": false,
  "environment": "sandbox",
  "webhookConfigured": true,
  "apiConnectivity": "healthy",
  "message": "Connected to real Plaid API"
}
```

---

## Webhook Integration

### Webhook Endpoint

**Endpoint:** `POST /v1/plaid/webhook`

Receives real-time notifications from Plaid about account and transaction updates.

### Webhook Types

#### 1. TRANSACTIONS Webhooks

**INITIAL_UPDATE**
- Triggered when initial transaction data is ready
- Occurs within a few minutes of Item creation

**HISTORICAL_UPDATE**
- Triggered when historical transaction data is ready
- Can take up to several hours

**DEFAULT_UPDATE**
- Triggered when new transactions are available
- Occurs daily or when new transactions are detected

**TRANSACTIONS_REMOVED**
- Triggered when transactions are removed
- Includes array of removed transaction IDs

#### 2. ITEM Webhooks

**ERROR**
- Triggered when an Item-level error occurs
- Common errors:
  - `ITEM_LOGIN_REQUIRED`: User needs to re-authenticate
  - `INVALID_CREDENTIALS`: Credentials are incorrect
  - `INSTITUTION_DOWN`: Bank is temporarily unavailable

**PENDING_EXPIRATION**
- Triggered when user consent is about to expire
- Gives advance notice to prompt re-authentication

**USER_PERMISSION_REVOKED**
- Triggered when user revokes permission at the bank

**WEBHOOK_UPDATE_ACKNOWLEDGED**
- Confirmation that webhook URL was updated

#### 3. AUTH Webhooks

**AUTOMATICALLY_VERIFIED**
- Account numbers automatically verified

**VERIFICATION_EXPIRED**
- Verification has expired and needs renewal

### Webhook Security

Webhooks are verified using HMAC-SHA256 signatures.

**Configuration:**
```bash
PLAID_WEBHOOK_VERIFICATION_KEY=your-webhook-key-from-plaid-dashboard
```

**Verification Process:**
1. Extract `Plaid-Verification` header
2. Compute HMAC-SHA256 of raw request body using verification key
3. Compare signatures using constant-time comparison
4. Reject if signatures don't match

**Security Requirements:**
- Webhook URL must be HTTPS in production
- Always verify webhook signatures
- Respond with 200 OK to acknowledge receipt
- Process webhooks asynchronously

### Webhook Payload Example

```json
{
  "webhook_type": "TRANSACTIONS",
  "webhook_code": "DEFAULT_UPDATE",
  "item_id": "item_...",
  "error": null,
  "new_transactions": 15,
  "removed_transactions": []
}
```

### Webhook Handler Implementation

The current implementation includes skeleton handlers for all webhook types. You should implement:

1. **Database lookups**: Map `item_id` to your user_id
2. **Data fetching**: Call `getTransactions()` to fetch new data
3. **Storage**: Save transactions to your database
4. **User notifications**: Notify users of new data or errors

---

## Error Handling

### Error Response Format

```json
{
  "error": "Plaid API Error",
  "type": "INVALID_REQUEST",
  "code": "INVALID_ACCESS_TOKEN",
  "message": "The access token is invalid",
  "displayMessage": "We couldn't connect to your bank. Please reconnect your account.",
  "stack": "..." // Only in development
}
```

### Common Error Types

#### INVALID_REQUEST
- `INVALID_ACCESS_TOKEN`: Token is invalid or expired
- `INVALID_PUBLIC_TOKEN`: Public token is invalid
- `MISSING_FIELDS`: Required fields are missing

#### INVALID_INPUT
- `INVALID_FIELD`: Field has invalid value
- `INVALID_DATE`: Date format is incorrect
- `DATE_RANGE_TOO_LARGE`: Date range exceeds 2 years

#### ITEM_ERROR
- `ITEM_LOGIN_REQUIRED`: User must re-authenticate
- `INSUFFICIENT_CREDENTIALS`: Additional info required
- `ITEM_LOCKED`: Account is locked at bank

#### RATE_LIMIT_EXCEEDED
- Too many requests in short period
- Implement exponential backoff

#### API_ERROR
- Temporary Plaid API issue
- Retry with exponential backoff

### Error Handling Best Practices

1. **Check error type and code** to determine handling strategy
2. **Use displayMessage** for user-facing error messages
3. **Implement retry logic** with exponential backoff for transient errors
4. **Log errors** with request_id for debugging with Plaid support
5. **Prompt re-authentication** for `ITEM_LOGIN_REQUIRED`
6. **Monitor error rates** to detect systematic issues

### Retry Strategy Example

```javascript
async function callPlaidWithRetry(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      // Retry on rate limits and API errors
      if (error.type === 'RATE_LIMIT_EXCEEDED' || error.type === 'API_ERROR') {
        if (i === maxRetries - 1) throw error;
        const delay = Math.pow(2, i) * 1000; // Exponential backoff
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      // Don't retry other errors
      throw error;
    }
  }
}
```

---

## Best Practices

### 1. Access Token Management

**DO:**
- Store access tokens encrypted in your database
- Associate tokens with user IDs using secure methods
- Rotate tokens if compromised
- Delete tokens when users disconnect accounts

**DON'T:**
- Expose access tokens in API responses to clients
- Log access tokens
- Store tokens in plain text
- Share tokens between users

### 2. Transaction Syncing

**Strategy:**
- Use webhooks for real-time updates
- Implement incremental sync (fetch only new transactions)
- Store last sync timestamp per Item
- Handle transaction removals/modifications

**Example Sync Logic:**
```javascript
async function syncTransactions(accessToken, lastSyncDate) {
  const endDate = new Date().toISOString().split('T')[0];
  const startDate = lastSyncDate || getDate30DaysAgo();

  let offset = 0;
  let allTransactions = [];

  while (true) {
    const result = await getTransactions({
      accessToken,
      startDate,
      endDate,
      count: 500,
      offset
    });

    allTransactions = [...allTransactions, ...result.transactions];

    if (allTransactions.length >= result.totalTransactions) break;
    offset += 500;
  }

  // Store transactions in database
  await storeTransactions(allTransactions);

  // Update last sync timestamp
  await updateLastSyncDate(endDate);
}
```

### 3. Error Recovery

**For ITEM_LOGIN_REQUIRED:**
1. Notify user via push notification/email
2. Generate new Link token with `access_token` (update mode)
3. Present Link to user for re-authentication
4. Resume data sync after successful update

**For Institution Issues:**
1. Monitor Item status via webhooks
2. Display appropriate messages to users
3. Retry automatically after cooldown period
4. Remove Item if institution permanently unavailable

### 4. Performance Optimization

**Caching:**
- Cache account information (refresh daily)
- Don't cache transactions (always fetch latest)
- Cache institution metadata

**Pagination:**
- Use appropriate page sizes (100-500)
- Implement cursor-based pagination for large datasets
- Process pages asynchronously

**Rate Limiting:**
- Respect Plaid rate limits
- Implement client-side throttling
- Use webhook updates instead of polling

### 5. Security Checklist

- [ ] Access tokens stored encrypted
- [ ] Webhook signatures verified
- [ ] HTTPS used for all communications
- [ ] Rate limiting implemented
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention
- [ ] CORS configured appropriately
- [ ] Sensitive data not logged
- [ ] Regular security audits

---

## iOS Integration

### Integration with PlaidLinkService.swift

The iOS client uses the provided backend API endpoints. Key integration points:

#### 1. Initialize Link

```swift
// iOS calls backend to get link token
let linkTokenResponse = await fetch("/v1/plaid/link_token", {
    user_id: userId
})

// Use link_token to initialize Plaid Link SDK
let linkConfiguration = LinkTokenConfiguration(
    token: linkTokenResponse.link_token
) { success in
    // Handle success
    await self.exchangePublicToken(success.publicToken)
}
```

#### 2. Exchange Token

```swift
// Exchange public token for access token
let response = await fetch("/v1/plaid/exchange_token", {
    public_token: publicToken
})

// Store access token in iOS Keychain (NEVER UserDefaults)
KeychainHelper.save(response.access_token, for: "plaid_access_token")
```

#### 3. Fetch Accounts

```swift
// Retrieve stored access token
let accessToken = KeychainHelper.get("plaid_access_token")

// Fetch accounts
let response = await fetch("/v1/plaid/accounts", {
    access_token: accessToken
})

// Update UI with account data
self.accounts = response.accounts
```

#### 4. Fetch Transactions

```swift
let accessToken = KeychainHelper.get("plaid_access_token")

let response = await fetch("/v1/plaid/transactions", {
    access_token: accessToken,
    start_date: "2024-01-01",
    end_date: "2024-01-31",
    count: 100,
    offset: 0
})

// Process transactions for mortgage auditing
self.analyzeTransactions(response.transactions)
```

### iOS Security Requirements

1. **Keychain Storage**: Store access tokens in iOS Keychain, never UserDefaults
2. **Certificate Pinning**: Implement certificate pinning for API calls
3. **Biometric Auth**: Require Face ID/Touch ID before accessing Plaid data
4. **Data Encryption**: Encrypt cached transaction data using AES-256
5. **Memory Security**: Clear sensitive data from memory after use

---

## Testing

### Testing Strategy

#### 1. Unit Tests
Test individual service methods with mock responses.

#### 2. Integration Tests
Test end-to-end flows with Plaid sandbox.

#### 3. Webhook Tests
Use Plaid Dashboard to trigger test webhooks.

### Sandbox Testing

**Available Institutions:**
- First Platypus Bank (ins_109508)
- First Gingham Credit Union (ins_109509)
- Tattersall Federal Credit Union (ins_109510)

**Test Credentials:**
- Username: `user_good`
- Password: `pass_good`

**Trigger Specific Scenarios:**
- Username: `user_good`, Password: `pass_good` - Success
- Username: `user_bad`, Password: `pass_bad` - Invalid credentials
- Username: `user_error`, Password: `pass_error` - Institution error

### Test Webhook Locally

Use ngrok to expose local server:

```bash
ngrok http 3000
# Use ngrok URL as PLAID_WEBHOOK_URL
# Example: https://abc123.ngrok.io/v1/plaid/webhook
```

### Monitoring & Debugging

**Request IDs:**
Every Plaid response includes a `request_id`. Save this for debugging.

**Plaid Dashboard:**
- View all API requests and responses
- Monitor webhook delivery
- Test webhook endpoints
- View Item status and errors

**Logging:**
Log the following (without sensitive data):
- Request timestamps
- Request IDs
- Error types and codes
- Webhook events

---

## Production Checklist

Before going to production:

- [ ] Plaid Production access approved
- [ ] Environment set to `production`
- [ ] Webhook URL configured with HTTPS
- [ ] Webhook signature verification enabled
- [ ] Access tokens stored encrypted
- [ ] Rate limiting configured
- [ ] Error monitoring setup
- [ ] Certificate pinning implemented (iOS)
- [ ] Security audit completed
- [ ] Privacy policy updated
- [ ] Terms of service updated
- [ ] User consent flows implemented
- [ ] Data retention policy defined
- [ ] Backup and recovery procedures tested

---

## Support & Resources

**Plaid Documentation:**
- https://plaid.com/docs/

**Plaid Dashboard:**
- https://dashboard.plaid.com/

**Support:**
- Plaid Support: support@plaid.com
- Slack Community: https://plaid.com/slack

**Rate Limits:**
- Sandbox: No limits
- Development: 100 requests per second
- Production: Custom limits based on agreement

---

## Appendix: API Compatibility Matrix

### iOS Client Compatibility

| iOS Endpoint | Backend Endpoint | Status | Notes |
|--------------|------------------|--------|-------|
| `fetchLinkToken()` | `/link_token` | ✅ Compatible | Request body format matches |
| `exchangePublicToken()` | `/exchange_token` | ✅ Compatible | Returns access token |
| `fetchAccountsWithAccessToken()` | `/accounts` | ⚠️ Enhanced | Returns additional item metadata |
| `getTransactions()` | `/transactions` | ⚠️ Enhanced | Added pagination and more fields |

### Migration Notes

The iOS client may need minor updates to handle enhanced response formats:
1. Account responses now include `item` metadata
2. Transaction responses include `totalTransactions` and pagination fields
3. All responses include `requestId` for debugging

These are additive changes and won't break existing functionality.

---

## Version History

- **v2.0.0** (2024-01): Production-ready implementation with webhooks
- **v1.0.0** (2024-01): Initial implementation

