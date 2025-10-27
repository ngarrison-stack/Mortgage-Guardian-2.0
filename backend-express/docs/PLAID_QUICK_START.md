# Plaid API Quick Start Guide

## 5-Minute Setup

### 1. Get Plaid Credentials

1. Sign up at https://dashboard.plaid.com/
2. Navigate to Team Settings → Keys
3. Copy your `client_id` and `secret` for sandbox

### 2. Configure Environment

```bash
cd backend-express
cp .env.example .env
```

Edit `.env`:
```bash
PLAID_CLIENT_ID=your-client-id-here
PLAID_SECRET=your-secret-here
PLAID_ENV=sandbox
```

### 3. Install Dependencies

```bash
npm install
```

### 4. Start Server

```bash
npm run dev
```

### 5. Test Connection

```bash
curl -X POST http://localhost:3000/v1/plaid/test
```

Expected response:
```json
{
  "success": true,
  "usingMock": false,
  "environment": "sandbox",
  "webhookConfigured": false,
  "apiConnectivity": "healthy"
}
```

---

## Common Use Cases

### Create Link Token for iOS App

**Endpoint:** `POST /v1/plaid/link_token`

```bash
curl -X POST http://localhost:3000/v1/plaid/link_token \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_12345",
    "client_name": "Mortgage Guardian"
  }'
```

Response:
```json
{
  "link_token": "link-sandbox-abc123...",
  "expiration": "2024-01-15T14:30:00.000Z",
  "request_id": "req_xyz"
}
```

**Use this link_token in iOS Plaid Link SDK.**

---

### Exchange Public Token

After Plaid Link succeeds in iOS:

**Endpoint:** `POST /v1/plaid/exchange_token`

```bash
curl -X POST http://localhost:3000/v1/plaid/exchange_token \
  -H "Content-Type: application/json" \
  -d '{
    "public_token": "public-sandbox-abc123..."
  }'
```

Response:
```json
{
  "access_token": "access-sandbox-xyz789...",
  "item_id": "item_123",
  "request_id": "req_abc"
}
```

**Store `access_token` securely! Never log it or expose it.**

---

### Get Account Balances

**Endpoint:** `POST /v1/plaid/accounts`

```bash
curl -X POST http://localhost:3000/v1/plaid/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "access-sandbox-xyz789..."
  }'
```

Response:
```json
{
  "accounts": [
    {
      "accountId": "acc_123",
      "name": "Plaid Checking",
      "type": "depository",
      "subtype": "checking",
      "mask": "0000",
      "balances": {
        "available": 100.0,
        "current": 110.0,
        "currency": "USD"
      }
    }
  ],
  "item": {
    "itemId": "item_123",
    "institutionId": "ins_109508"
  }
}
```

---

### Get Transactions (Last 30 Days)

**Endpoint:** `POST /v1/plaid/transactions`

```bash
curl -X POST http://localhost:3000/v1/plaid/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "access-sandbox-xyz789...",
    "start_date": "2024-01-01",
    "end_date": "2024-01-31",
    "count": 100
  }'
```

Response:
```json
{
  "transactions": [
    {
      "transactionId": "txn_123",
      "accountId": "acc_123",
      "amount": 12.50,
      "date": "2024-01-15",
      "name": "Starbucks",
      "merchantName": "Starbucks",
      "category": ["Food and Drink", "Coffee Shop"],
      "pending": false
    }
  ],
  "totalTransactions": 45
}
```

---

## Sandbox Testing

### Test Bank Credentials

**Institution:** First Platypus Bank (ins_109508)

**Success:**
- Username: `user_good`
- Password: `pass_good`

**Invalid Credentials:**
- Username: `user_bad`
- Password: `pass_bad`

**Institution Error:**
- Username: `user_error`
- Password: `pass_error`

### Quick Test Flow

1. Create link token
2. Use link token in Plaid Link (or create sandbox token)
3. Exchange for access token
4. Fetch accounts and transactions

**Shortcut for testing (no Link UI):**

```bash
# 1. Create sandbox public token
curl -X POST http://localhost:3000/v1/plaid/sandbox_public_token \
  -H "Content-Type: application/json" \
  -d '{"institution_id": "ins_109508"}'

# Response: {"public_token": "public-sandbox-..."}

# 2. Exchange it
curl -X POST http://localhost:3000/v1/plaid/exchange_token \
  -H "Content-Type: application/json" \
  -d '{"public_token": "public-sandbox-..."}'

# Response: {"access_token": "access-sandbox-..."}

# 3. Get data
curl -X POST http://localhost:3000/v1/plaid/accounts \
  -H "Content-Type: application/json" \
  -d '{"access_token": "access-sandbox-..."}'
```

---

## Error Handling

### Common Errors

**400 Bad Request:**
```json
{
  "error": "Bad Request",
  "message": "Missing required fields: access_token"
}
```

**Fix:** Include all required fields in request body.

---

**401 Unauthorized (Webhook):**
```json
{
  "error": "Unauthorized",
  "message": "Invalid webhook signature"
}
```

**Fix:** Configure `PLAID_WEBHOOK_VERIFICATION_KEY` in .env.

---

**Plaid API Error:**
```json
{
  "error": "Plaid API Error",
  "type": "INVALID_REQUEST",
  "code": "INVALID_ACCESS_TOKEN",
  "message": "The access token is invalid",
  "displayMessage": "Please reconnect your bank account"
}
```

**Fix:**
- Token expired: Create new link token in update mode
- Token invalid: User needs to reconnect via Plaid Link

---

## Environment Variables Reference

### Required

```bash
PLAID_CLIENT_ID=your-client-id
PLAID_SECRET=your-secret
```

### Optional

```bash
# Environment (default: sandbox)
PLAID_ENV=sandbox|development|production

# Webhook URL (for real-time updates)
PLAID_WEBHOOK_URL=https://yourdomain.com/v1/plaid/webhook

# Webhook verification key (get from Plaid Dashboard)
PLAID_WEBHOOK_VERIFICATION_KEY=your-webhook-key

# Server config
PORT=3000
NODE_ENV=development

# Rate limiting (defaults shown)
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# CORS (default: *)
ALLOWED_ORIGINS=*
```

---

## API Endpoints Reference

### Link & Token Management
- `POST /v1/plaid/link_token` - Create Link token
- `POST /v1/plaid/exchange_token` - Exchange public token
- `POST /v1/plaid/sandbox_public_token` - Create sandbox token (testing)

### Data Retrieval
- `POST /v1/plaid/accounts` - Get account balances
- `POST /v1/plaid/transactions` - Get transaction history
- `POST /v1/plaid/item` - Get item information

### Item Management
- `POST /v1/plaid/item/webhook` - Update webhook URL
- `DELETE /v1/plaid/item` - Remove item

### Webhooks
- `POST /v1/plaid/webhook` - Receive Plaid webhooks

### Testing
- `POST /v1/plaid/test` - Test connection

---

## iOS Integration

### 1. Fetch Link Token

```swift
let response = try await fetch("/v1/plaid/link_token", body: [
    "user_id": userId
])
let linkToken = response.link_token
```

### 2. Present Plaid Link

```swift
let config = LinkTokenConfiguration(token: linkToken) { success in
    // Exchange public token
    await self.exchangeToken(success.publicToken)
}
let handler = Plaid.create(config)
handler.open(presentUsing: .viewController(self))
```

### 3. Exchange Token

```swift
let response = try await fetch("/v1/plaid/exchange_token", body: [
    "public_token": publicToken
])

// Store access token in Keychain (NEVER UserDefaults!)
KeychainHelper.save(response.access_token, for: "plaid_access_token")
```

### 4. Fetch Data

```swift
let accessToken = KeychainHelper.get("plaid_access_token")

let accounts = try await fetch("/v1/plaid/accounts", body: [
    "access_token": accessToken
])

let transactions = try await fetch("/v1/plaid/transactions", body: [
    "access_token": accessToken,
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
])
```

---

## Webhook Setup (Optional)

Webhooks provide real-time updates when new transactions are available.

### 1. Expose Local Server (Development)

```bash
# Install ngrok: https://ngrok.com/
ngrok http 3000
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)

### 2. Update .env

```bash
PLAID_WEBHOOK_URL=https://abc123.ngrok.io/v1/plaid/webhook
```

### 3. Configure in Plaid Dashboard

1. Go to https://dashboard.plaid.com/
2. Navigate to Webhooks
3. Add webhook URL
4. Copy verification key to .env:

```bash
PLAID_WEBHOOK_VERIFICATION_KEY=your-key-here
```

### 4. Restart Server

```bash
npm run dev
```

### 5. Test Webhook

From Plaid Dashboard, send a test webhook. Check your server logs:

```
Received Plaid webhook: { type: 'TRANSACTIONS', code: 'DEFAULT_UPDATE', itemId: 'item_123' }
```

---

## Troubleshooting

### "Using Mock Plaid Service"

**Problem:** Server uses mock service instead of real Plaid API.

**Solution:** Configure `PLAID_CLIENT_ID` and `PLAID_SECRET` in .env file.

---

### "Invalid access token format"

**Problem:** Access token is malformed or missing.

**Solution:** Ensure token starts with `access-` or `access_sandbox-`.

---

### "Rate limit exceeded"

**Problem:** Too many requests in short time.

**Solution:**
- Wait 15 minutes (default window)
- Implement client-side throttling
- Use webhooks instead of polling

---

### "Item login required"

**Problem:** Bank connection expired or credentials changed.

**Solution:**
1. Create new link token with `access_token` parameter (update mode)
2. Present Link to user
3. User re-authenticates
4. Connection restored

```bash
curl -X POST http://localhost:3000/v1/plaid/link_token \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_12345",
    "access_token": "access-sandbox-existing-token"
  }'
```

---

## Next Steps

1. **Read Full Documentation:** See `docs/PLAID_API.md` for complete API reference
2. **Review Security:** See `docs/PLAID_SECURITY.md` for security best practices
3. **Implement Database Storage:** Store access tokens and transactions securely
4. **Set Up Webhooks:** Enable real-time updates
5. **Deploy to Production:** Follow production checklist in `PLAID_UPDATE_SUMMARY.md`

---

## Getting Help

**Documentation:**
- Full API Docs: `docs/PLAID_API.md`
- Security Guide: `docs/PLAID_SECURITY.md`
- Update Summary: `PLAID_UPDATE_SUMMARY.md`

**Plaid Resources:**
- Official Docs: https://plaid.com/docs/
- Dashboard: https://dashboard.plaid.com/
- Support: support@plaid.com

**Quick Questions:**
- Check `docs/PLAID_API.md` first
- Review error messages (include `request_id` when asking for help)
- Test in sandbox before production

