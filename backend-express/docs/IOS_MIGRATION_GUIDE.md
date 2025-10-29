# iOS Client Migration Guide

## Overview

The backend Plaid API has been updated with enhanced features while maintaining backward compatibility. This guide helps you migrate the iOS client to take advantage of new capabilities.

**Current Status:** Your iOS app will continue to work without changes. This guide is for optional enhancements.

---

## What's Changed

### Backward Compatible Changes

✅ **No breaking changes** - All existing endpoints work as before

✅ **Enhanced responses** - Additional fields added (existing fields unchanged)

✅ **New endpoints** - Optional endpoints for advanced features

### New Features Available

1. **Enhanced Account Information** - Item metadata, verification status
2. **Pagination Support** - Fetch large transaction sets efficiently
3. **Item Management** - Check connection status, update webhooks
4. **Better Error Handling** - Structured error responses with display messages
5. **Personal Finance Categories** - Enhanced transaction categorization

---

## Migration Steps

### Step 1: No Changes Required (Existing Functionality)

Your current implementation continues to work:

```swift
// These calls work exactly as before
let linkToken = try await fetchLinkToken()
let result = try await exchangePublicToken(publicToken)
let accounts = try await fetchAccountsWithAccessToken(accessToken)
let transactions = try await getTransactions(...)
```

### Step 2: Optional Enhancements

Choose which enhancements to implement based on your needs.

---

## Enhancement 1: Handle Extended Account Data

### What's New

The `/accounts` endpoint now returns additional item metadata:

```json
{
  "accounts": [...],
  "item": {
    "itemId": "item_123",
    "institutionId": "ins_109508",
    "webhook": "...",
    "availableProducts": ["balance", "transactions"],
    "billedProducts": ["auth", "transactions"],
    "error": null
  },
  "requestId": "req_abc"
}
```

### iOS Update

Update your `PlaidAccount` model:

```swift
// Add new model for Item metadata
struct PlaidItem: Codable {
    let itemId: String
    let institutionId: String
    let webhook: String?
    let availableProducts: [String]
    let billedProducts: [String]
    let error: PlaidItemError?
    let consentExpirationTime: String?
}

struct PlaidItemError: Codable {
    let errorType: String
    let errorCode: String
    let errorMessage: String
    let displayMessage: String?
}

// Update accounts response model
struct AccountsResponse: Codable {
    let accounts: [PlaidAccount]
    let item: PlaidItem?
    let requestId: String?
}
```

Update `fetchAccountsWithAccessToken`:

```swift
private func fetchAccountsWithAccessToken(_ accessToken: String) async throws {
    guard let url = URL(string: "\(apiBaseURL)/accounts") else {
        throw PlaidError.invalidConfiguration
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody = ["access_token": accessToken]
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await networkSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw PlaidError.accountsFetchFailed
    }

    // Parse enhanced response
    let responseData = try JSONDecoder().decode(AccountsResponse.self, from: data)

    await MainActor.run {
        self.accounts = responseData.accounts

        // Check for item errors
        if let itemError = responseData.item?.error {
            if itemError.errorCode == "ITEM_LOGIN_REQUIRED" {
                // Prompt user to re-authenticate
                self.errorMessage = itemError.displayMessage ?? "Please reconnect your bank"
                self.needsReauthentication = true
            }
        }
    }
}
```

### Benefits

- Detect when bank connection needs re-authentication
- Display institution-specific information
- Monitor connection health
- Handle errors proactively

---

## Enhancement 2: Implement Transaction Pagination

### What's New

Transactions endpoint now supports pagination for large datasets:

```json
{
  "transactions": [...],
  "totalTransactions": 523,
  "accounts": [...],
  "requestId": "req_abc"
}
```

### iOS Update

Add pagination to transaction fetching:

```swift
struct TransactionsResponse: Codable {
    let transactions: [PlaidTransaction]
    let totalTransactions: Int
    let accounts: [PlaidAccountInfo]?
    let requestId: String?
}

struct PlaidAccountInfo: Codable {
    let accountId: String
    let name: String
    let type: String
    let subtype: String
    let mask: String?
}

func fetchAllTransactions(
    accessToken: String,
    startDate: String,
    endDate: String
) async throws -> [PlaidTransaction] {
    var allTransactions: [PlaidTransaction] = []
    var offset = 0
    let batchSize = 100

    while true {
        let response = try await fetchTransactionsBatch(
            accessToken: accessToken,
            startDate: startDate,
            endDate: endDate,
            count: batchSize,
            offset: offset
        )

        allTransactions.append(contentsOf: response.transactions)

        logger.info("Fetched \(allTransactions.count) of \(response.totalTransactions) transactions")

        // Check if we've fetched all transactions
        if allTransactions.count >= response.totalTransactions {
            break
        }

        offset += batchSize
    }

    return allTransactions
}

private func fetchTransactionsBatch(
    accessToken: String,
    startDate: String,
    endDate: String,
    count: Int,
    offset: Int
) async throws -> TransactionsResponse {
    guard let url = URL(string: "\(apiBaseURL)/transactions") else {
        throw PlaidError.invalidConfiguration
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody: [String: Any] = [
        "access_token": accessToken,
        "start_date": startDate,
        "end_date": endDate,
        "count": count,
        "offset": offset
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await networkSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw PlaidError.transactionsFetchFailed
    }

    return try JSONDecoder().decode(TransactionsResponse.self, from: data)
}
```

### Benefits

- Fetch large transaction histories efficiently
- Show progress to users during sync
- Reduce memory usage
- Handle large date ranges

---

## Enhancement 3: Enhanced Transaction Data

### What's New

Transactions now include additional fields:

```swift
struct PlaidTransaction: Codable {
    let transactionId: String
    let accountId: String
    let amount: Double
    let date: String
    let authorizedDate: String?
    let name: String
    let merchantName: String?
    let originalDescription: String?
    let category: [String]?
    let categoryId: String?

    // NEW: Personal Finance Categories
    let personalFinanceCategory: PersonalFinanceCategory?

    let pending: Bool
    let pendingTransactionId: String?
    let paymentChannel: String?
    let transactionType: String?
    let transactionCode: String?

    // NEW: Location data
    let location: TransactionLocation?

    // NEW: Payment metadata
    let paymentMeta: PaymentMetadata?

    let accountOwner: String?
    let isoCurrencyCode: String?
    let unofficialCurrencyCode: String?
}

struct PersonalFinanceCategory: Codable {
    let primary: String
    let detailed: String
    let confidenceLevel: String?
}

struct TransactionLocation: Codable {
    let address: String?
    let city: String?
    let region: String?
    let postalCode: String?
    let country: String?
    let lat: Double?
    let lon: Double?
}

struct PaymentMetadata: Codable {
    let referenceNumber: String?
    let ppdId: String?
    let payee: String?
    let byOrderOf: String?
    let payer: String?
    let paymentMethod: String?
    let paymentProcessor: String?
    let reason: String?
}
```

### Benefits

- Better transaction categorization
- Location-based features
- Enhanced payment details
- Improved mortgage payment detection

---

## Enhancement 4: Handle Update Mode (Re-authentication)

### What's New

Link token creation now supports update mode for re-authentication:

```swift
func handleReauthentication(accessToken: String) async throws {
    // Create link token in update mode
    guard let url = URL(string: "\(apiBaseURL)/link_token") else {
        throw PlaidError.invalidConfiguration
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody: [String: Any] = [
        "user_id": currentUserId,
        "access_token": accessToken  // This enables update mode
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await networkSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw PlaidError.linkTokenFailed
    }

    let responseJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let linkToken = responseJson?["link_token"] as? String else {
        throw PlaidError.linkTokenFailed
    }

    // Present Link for re-authentication
    await presentPlaidLink(linkToken: linkToken)
}
```

### Benefits

- Seamless re-authentication flow
- Maintain same item_id and account_ids
- Better user experience
- Preserve historical data

---

## Enhancement 5: Improved Error Handling

### What's New

Errors now include structured information:

```swift
struct PlaidAPIError: Codable {
    let error: String
    let type: String?
    let code: String?
    let message: String
    let displayMessage: String?
    let requestId: String?
}

extension PlaidLinkService {
    func handleAPIError(_ error: Error, data: Data?) throws {
        // Try to parse Plaid API error
        if let data = data,
           let plaidError = try? JSONDecoder().decode(PlaidAPIError.self, from: data) {

            // Use display message for user-facing errors
            let userMessage = plaidError.displayMessage ?? plaidError.message

            // Log technical details for debugging
            logger.error("Plaid API Error", metadata: [
                "type": "\(plaidError.type ?? "unknown")",
                "code": "\(plaidError.code ?? "unknown")",
                "requestId": "\(plaidError.requestId ?? "unknown")"
            ])

            // Handle specific error codes
            if plaidError.code == "ITEM_LOGIN_REQUIRED" {
                await handleReauthentication(accessToken: currentAccessToken)
            }

            throw PlaidError.apiError(userMessage)
        }

        throw error
    }
}
```

### Benefits

- User-friendly error messages
- Better debugging with request IDs
- Automatic re-authentication prompts
- Improved error recovery

---

## Enhancement 6: Item Management

### New Endpoints

**Get Item Status:**

```swift
func getItemStatus(accessToken: String) async throws -> PlaidItem {
    guard let url = URL(string: "\(apiBaseURL)/item") else {
        throw PlaidError.invalidConfiguration
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody = ["access_token": accessToken]
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await networkSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw PlaidError.itemFetchFailed
    }

    return try JSONDecoder().decode(PlaidItem.self, from: data)
}
```

**Remove Item:**

```swift
func removeAccount(_ account: PlaidAccount) async throws {
    guard let accessToken = getAccessToken(for: account.id) else {
        throw PlaidError.accessTokenNotFound
    }

    guard let url = URL(string: "\(apiBaseURL)/item") else {
        throw PlaidError.invalidConfiguration
    }

    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody = ["access_token": accessToken]
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await networkSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw PlaidError.itemRemovalFailed
    }

    // Remove locally
    await MainActor.run {
        accounts.removeAll { $0.id == account.id }
        removeAccessToken(for: account.id)
        saveAccountsToStorage()
    }

    logger.info("Successfully removed account: \(account.name)")
}
```

### Benefits

- Check connection health
- Gracefully disconnect accounts
- Monitor consent expiration
- Better account management UI

---

## Migration Priority

### High Priority (Recommended)

1. ✅ **Enhanced Error Handling** - Better UX and debugging
2. ✅ **Item Status Monitoring** - Detect issues proactively
3. ✅ **Re-authentication Flow** - Handle expired connections

### Medium Priority (Nice to Have)

4. ⚠️ **Transaction Pagination** - If fetching >100 transactions
5. ⚠️ **Extended Account Data** - For richer UI

### Low Priority (Optional)

6. ℹ️ **Enhanced Transaction Fields** - For advanced features
7. ℹ️ **Item Management** - For account settings screen

---

## Testing Your Changes

### 1. Test Existing Functionality

Ensure nothing broke:

```swift
// Test basic flow
let linkToken = try await fetchLinkToken()
XCTAssertNotNil(linkToken)

let accounts = try await fetchAccounts()
XCTAssertFalse(accounts.isEmpty)
```

### 2. Test New Features

```swift
// Test pagination
let allTransactions = try await fetchAllTransactions(
    accessToken: testAccessToken,
    startDate: "2023-01-01",
    endDate: "2024-01-31"
)
XCTAssertGreaterThan(allTransactions.count, 100)

// Test item status
let item = try await getItemStatus(accessToken: testAccessToken)
XCTAssertNotNil(item.itemId)

// Test error handling
do {
    try await fetchAccounts(invalidToken)
    XCTFail("Should throw error")
} catch let error as PlaidAPIError {
    XCTAssertNotNil(error.displayMessage)
}
```

---

## Rollback Plan

If you encounter issues:

1. **No code changes needed** - Backend is backward compatible
2. **Remove new code** - Revert to previous iOS implementation
3. **Existing functionality preserved** - Your app continues to work

---

## Support

### Documentation

- Backend API: `backend-express/docs/PLAID_API.md`
- Security Guide: `backend-express/docs/PLAID_SECURITY.md`
- Quick Start: `backend-express/docs/PLAID_QUICK_START.md`

### Testing

Test your changes against:
- Sandbox environment first
- Development environment
- Production environment (after thorough testing)

### Getting Help

- Check error `requestId` in API responses
- Review backend logs
- Test with curl commands first
- Contact backend team with specific request IDs

---

## Summary

**Current State:** Your iOS app works without changes

**Recommended Updates:**
1. Enhanced error handling (30 min)
2. Item status monitoring (30 min)
3. Re-authentication flow (1 hour)

**Optional Updates:**
- Transaction pagination (1 hour)
- Extended data models (1-2 hours)

**Total Time Investment:** 2-5 hours for full enhancement

**Risk Level:** Low - All changes are additive and backward compatible

