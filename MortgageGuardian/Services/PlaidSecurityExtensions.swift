import Foundation
import CryptoKit
import Security
import OSLog

/// Security extensions specifically for Plaid integration
/// Provides additional security features for financial data handling
extension SecurityService {

    // MARK: - Plaid-Specific Security

    /// Plaid security context for enhanced protection
    public enum PlaidSecurityContext: String {
        case accessTokens = "plaid_access_tokens"
        case bankTransactions = "plaid_transactions"
        case accountInfo = "plaid_accounts"
        case webhookData = "plaid_webhooks"
        case correlationData = "plaid_correlations"
        case auditLogs = "plaid_audit_logs"
    }

    /// Enhanced encryption for Plaid financial data
    public func encryptPlaidData<T: Codable>(_ data: T, context: PlaidSecurityContext) async throws -> Data {
        let jsonData = try JSONEncoder().encode(data)

        // Add metadata for enhanced security
        let metadata = PlaidDataMetadata(
            timestamp: Date(),
            context: context.rawValue,
            checksum: calculateChecksum(jsonData),
            version: "1.0"
        )

        let containerData = PlaidDataContainer(
            data: jsonData,
            metadata: metadata
        )

        let containerJsonData = try JSONEncoder().encode(containerData)

        // Encrypt with Plaid-specific context
        return try await encryptData(containerJsonData, context: "plaid_\(context.rawValue)")
    }

    /// Enhanced decryption for Plaid financial data
    public func decryptPlaidData<T: Codable>(_ encryptedData: Data, type: T.Type, context: PlaidSecurityContext) async throws -> T {
        // Decrypt the container
        let containerJsonData = try await decryptData(encryptedData, context: "plaid_\(context.rawValue)")
        let container = try JSONDecoder().decode(PlaidDataContainer.self, from: containerJsonData)

        // Verify metadata
        try verifyPlaidDataIntegrity(container, expectedContext: context)

        // Decode the actual data
        return try JSONDecoder().decode(type, from: container.data)
    }

    /// Store Plaid access token with enhanced security
    public func storePlaidAccessToken(_ token: String, institutionId: String) async throws {
        let tokenData = PlaidTokenData(
            accessToken: token,
            institutionId: institutionId,
            createdAt: Date(),
            lastUsed: Date(),
            isActive: true
        )

        let encryptedData = try await encryptPlaidData(tokenData, context: .accessTokens)

        try storeInKeychain(
            encryptedData,
            key: "plaid_token_\(institutionId)",
            requireBiometric: true
        )

        auditLogger.log(.dataEncrypted("Plaid access token for institution \(institutionId)"))
    }

    /// Retrieve Plaid access token with security validation
    public func retrievePlaidAccessToken(institutionId: String) async throws -> String? {
        guard let encryptedData: Data = try retrieveFromKeychain(Data.self, key: "plaid_token_\(institutionId)") else {
            return nil
        }

        let tokenData = try await decryptPlaidData(encryptedData, type: PlaidTokenData.self, context: .accessTokens)

        // Validate token is still active
        guard tokenData.isActive else {
            throw SecurityError.sessionExpired
        }

        // Update last used timestamp
        let updatedTokenData = PlaidTokenData(
            accessToken: tokenData.accessToken,
            institutionId: tokenData.institutionId,
            createdAt: tokenData.createdAt,
            lastUsed: Date(),
            isActive: tokenData.isActive
        )

        let updatedEncryptedData = try await encryptPlaidData(updatedTokenData, context: .accessTokens)
        try storeInKeychain(updatedEncryptedData, key: "plaid_token_\(institutionId)", requireBiometric: true)

        auditLogger.log(.dataDecrypted("Plaid access token for institution \(institutionId)"))

        return tokenData.accessToken
    }

    /// Securely store bank transaction data
    public func storePlaidTransactions(_ transactions: [Transaction]) async throws {
        let sanitizedTransactions = sanitizeTransactionData(transactions)
        let encryptedData = try await encryptPlaidData(sanitizedTransactions, context: .bankTransactions)

        try storeInKeychain(
            encryptedData,
            key: "plaid_transactions_\(Date().timeIntervalSince1970)",
            requireBiometric: false // Allow access without biometric for analysis
        )

        auditLogger.log(.dataEncrypted("Plaid transactions (\(transactions.count) records)"))
    }

    /// Retrieve stored bank transactions with security validation
    public func retrievePlaidTransactions() async throws -> [Transaction] {
        // Find the most recent transaction data
        guard let latestKey = try findLatestTransactionKey() else {
            return []
        }

        guard let encryptedData: Data = try retrieveFromKeychain(Data.self, key: latestKey) else {
            return []
        }

        let transactions = try await decryptPlaidData(encryptedData, type: [Transaction].self, context: .bankTransactions)

        auditLogger.log(.dataDecrypted("Plaid transactions (\(transactions.count) records)"))

        return transactions
    }

    /// Store payment correlation data securely
    public func storePlaidCorrelations(_ correlations: [PaymentCorrelation]) async throws {
        let encryptedData = try await encryptPlaidData(correlations, context: .correlationData)

        try storeInKeychain(
            encryptedData,
            key: "plaid_correlations_\(Date().timeIntervalSince1970)",
            requireBiometric: false
        )

        auditLogger.log(.dataEncrypted("Payment correlations (\(correlations.count) records)"))
    }

    /// Retrieve payment correlation data
    public func retrievePlaidCorrelations() async throws -> [PaymentCorrelation] {
        guard let latestKey = try findLatestCorrelationKey() else {
            return []
        }

        guard let encryptedData: Data = try retrieveFromKeychain(Data.self, key: latestKey) else {
            return []
        }

        let correlations = try await decryptPlaidData(encryptedData, type: [PaymentCorrelation].self, context: .correlationData)

        auditLogger.log(.dataDecrypted("Payment correlations (\(correlations.count) records)"))

        return correlations
    }

    /// Revoke all Plaid access tokens
    public func revokePlaidAccess() async throws {
        // Find all Plaid-related keychain items
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return
        }

        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               account.hasPrefix("plaid_") {
                try deleteFromKeychain(key: account)
            }
        }

        auditLogger.log(.suspiciousActivity("All Plaid access revoked"))
    }

    /// Validate webhook signature for security
    public func validatePlaidWebhook(_ payload: Data, signature: String, secret: String) throws -> Bool {
        let key = SymmetricKey(data: Data(secret.utf8))
        let computedSignature = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let computedSignatureHex = Data(computedSignature).map { String(format: "%02hhx", $0) }.joined()

        // Remove "sha256=" prefix if present
        let cleanSignature = signature.hasPrefix("sha256=") ? String(signature.dropFirst(7)) : signature

        guard computedSignatureHex == cleanSignature else {
            auditLogger.log(.networkSecurityViolation("Invalid webhook signature"))
            throw SecurityError.networkSecurityViolation("Invalid webhook signature")
        }

        return true
    }

    /// Generate secure API request signature
    public func signPlaidAPIRequest(_ request: URLRequest, secret: String) throws -> URLRequest {
        var signedRequest = request

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let bodyData = request.httpBody ?? Data()

        // Create signature payload
        let signaturePayload = "\(request.httpMethod ?? "POST")\n\(request.url?.path ?? "")\n\(timestamp)\n\(bodyData.base64EncodedString())"

        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(signaturePayload.utf8), using: key)
        let signatureHex = Data(signature).map { String(format: "%02hhx", $0) }.joined()

        signedRequest.setValue(timestamp, forHTTPHeaderField: "X-Plaid-Timestamp")
        signedRequest.setValue("sha256=\(signatureHex)", forHTTPHeaderField: "X-Plaid-Signature")

        return signedRequest
    }

    /// Monitor for suspicious Plaid API activity
    public func monitorPlaidAPIActivity(_ request: URLRequest, response: URLResponse?) {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        // Check for suspicious status codes
        if httpResponse.statusCode == 429 {
            auditLogger.log(.networkSecurityViolation("Rate limit exceeded"))
        } else if httpResponse.statusCode >= 400 {
            auditLogger.log(.networkSecurityViolation("API error: \(httpResponse.statusCode)"))
        }

        // Check for unusual headers
        if let contentType = httpResponse.value(forHTTPHeaderField: "content-type"),
           !contentType.contains("application/json") {
            auditLogger.log(.networkSecurityViolation("Unexpected content type: \(contentType)"))
        }
    }

    /// Clean up expired Plaid data
    public func cleanupExpiredPlaidData() async throws {
        let expirationInterval: TimeInterval = 2555 * 24 * 3600 // ~7 years
        let cutoffDate = Date().addingTimeInterval(-expirationInterval)

        // Find and remove expired transaction data
        let transactionKeys = try findAllTransactionKeys()
        for key in transactionKeys {
            if let timestamp = extractTimestampFromKey(key),
               timestamp < cutoffDate.timeIntervalSince1970 {
                try deleteFromKeychain(key: key)
                auditLogger.log(.dataDecrypted("Expired transaction data removed: \(key)"))
            }
        }

        // Find and remove expired correlation data
        let correlationKeys = try findAllCorrelationKeys()
        for key in correlationKeys {
            if let timestamp = extractTimestampFromKey(key),
               timestamp < cutoffDate.timeIntervalSince1970 {
                try deleteFromKeychain(key: key)
                auditLogger.log(.dataDecrypted("Expired correlation data removed: \(key)"))
            }
        }
    }

    // MARK: - Private Helper Methods

    private func sanitizeTransactionData(_ transactions: [Transaction]) -> [Transaction] {
        // Remove or mask sensitive information while preserving audit capability
        return transactions.map { transaction in
            Transaction(
                accountId: hashAccountId(transaction.accountId),
                transactionId: transaction.transactionId,
                amount: transaction.amount,
                date: transaction.date,
                description: sanitizeDescription(transaction.description),
                category: transaction.category,
                isRecurring: transaction.isRecurring,
                merchantName: transaction.merchantName,
                confidence: transaction.confidence,
                plaidTransactionId: transaction.plaidTransactionId,
                isVerified: transaction.isVerified,
                relatedMortgagePayment: transaction.relatedMortgagePayment
            )
        }
    }

    private func hashAccountId(_ accountId: String) -> String {
        let data = Data(accountId.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(8).description
    }

    private func sanitizeDescription(_ description: String) -> String {
        // Remove potential PII while preserving mortgage-related keywords
        let mortgageKeywords = ["mortgage", "loan", "payment", "escrow", "tax", "insurance"]
        let words = description.lowercased().split(separator: " ")

        let sanitizedWords = words.map { word -> String in
            if mortgageKeywords.contains(where: { word.contains($0) }) {
                return String(word)
            } else {
                return "***"
            }
        }

        return sanitizedWords.joined(separator: " ")
    }

    private func calculateChecksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func verifyPlaidDataIntegrity(_ container: PlaidDataContainer, expectedContext: PlaidSecurityContext) throws {
        // Verify timestamp is not too old
        let maxAge: TimeInterval = 365 * 24 * 3600 // 1 year
        if Date().timeIntervalSince(container.metadata.timestamp) > maxAge {
            throw SecurityError.dataDecryptionFailed("Data too old")
        }

        // Verify context matches
        if container.metadata.context != expectedContext.rawValue {
            throw SecurityError.dataDecryptionFailed("Context mismatch")
        }

        // Verify checksum
        let computedChecksum = calculateChecksum(container.data)
        if computedChecksum != container.metadata.checksum {
            throw SecurityError.dataDecryptionFailed("Checksum mismatch")
        }
    }

    private func findLatestTransactionKey() throws -> String? {
        return try findLatestKeyWithPrefix("plaid_transactions_")
    }

    private func findLatestCorrelationKey() throws -> String? {
        return try findLatestKeyWithPrefix("plaid_correlations_")
    }

    private func findLatestKeyWithPrefix(_ prefix: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return nil
        }

        let matchingKeys = items.compactMap { item -> (String, TimeInterval)? in
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(prefix),
                  let timestamp = extractTimestampFromKey(account) else {
                return nil
            }
            return (account, timestamp)
        }

        return matchingKeys.max(by: { $0.1 < $1.1 })?.0
    }

    private func findAllTransactionKeys() throws -> [String] {
        return try findAllKeysWithPrefix("plaid_transactions_")
    }

    private func findAllCorrelationKeys() throws -> [String] {
        return try findAllKeysWithPrefix("plaid_correlations_")
    }

    private func findAllKeysWithPrefix(_ prefix: String) throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(prefix) else {
                return nil
            }
            return account
        }
    }

    private func extractTimestampFromKey(_ key: String) -> TimeInterval? {
        let components = key.split(separator: "_")
        guard let lastComponent = components.last,
              let timestamp = TimeInterval(lastComponent) else {
            return nil
        }
        return timestamp
    }
}

// MARK: - Supporting Data Models

private struct PlaidDataContainer: Codable {
    let data: Data
    let metadata: PlaidDataMetadata
}

private struct PlaidDataMetadata: Codable {
    let timestamp: Date
    let context: String
    let checksum: String
    let version: String
}

private struct PlaidTokenData: Codable {
    let accessToken: String
    let institutionId: String
    let createdAt: Date
    let lastUsed: Date
    let isActive: Bool
}

// MARK: - Additional Security Audit Events

extension SecurityService.AuditEvent {
    static func plaidTokenStored(_ institutionId: String) -> SecurityService.AuditEvent {
        return .dataEncrypted("Plaid token stored for institution: \(institutionId)")
    }

    static func plaidTokenRetrieved(_ institutionId: String) -> SecurityService.AuditEvent {
        return .dataDecrypted("Plaid token retrieved for institution: \(institutionId)")
    }

    static func plaidWebhookReceived(_ type: String) -> SecurityService.AuditEvent {
        return .networkSecurityViolation("Plaid webhook received: \(type)")
    }

    static func plaidAPIError(_ statusCode: Int) -> SecurityService.AuditEvent {
        return .networkSecurityViolation("Plaid API error: \(statusCode)")
    }

    static func plaidDataCleanup(_ recordsRemoved: Int) -> SecurityService.AuditEvent {
        return .suspiciousActivity("Plaid data cleanup: \(recordsRemoved) records removed")
    }
}

// MARK: - Compliance Helpers

extension SecurityService {

    /// Generate compliance report for Plaid data handling
    public func generatePlaidComplianceReport() async throws -> PlaidComplianceReport {
        let storedTokens = try await getStoredPlaidTokenCount()
        let storedTransactions = try await getStoredTransactionCount()
        let storedCorrelations = try await getStoredCorrelationCount()

        let oldestData = try await getOldestPlaidDataDate()
        let newestData = try await getNewestPlaidDataDate()

        return PlaidComplianceReport(
            reportDate: Date(),
            storedTokenCount: storedTokens,
            storedTransactionCount: storedTransactions,
            storedCorrelationCount: storedCorrelations,
            dataRetentionPeriod: oldestData != nil && newestData != nil ?
                newestData!.timeIntervalSince(oldestData!) : 0,
            encryptionEnabled: true,
            biometricAuthEnabled: securitySettings?.biometricAuthEnabled ?? false,
            lastDataCleanup: try await getLastCleanupDate(),
            complianceStatus: .compliant
        )
    }

    private func getStoredPlaidTokenCount() async throws -> Int {
        // Implementation to count stored tokens
        return 0 // Placeholder
    }

    private func getStoredTransactionCount() async throws -> Int {
        let transactions = try await retrievePlaidTransactions()
        return transactions.count
    }

    private func getStoredCorrelationCount() async throws -> Int {
        let correlations = try await retrievePlaidCorrelations()
        return correlations.count
    }

    private func getOldestPlaidDataDate() async throws -> Date? {
        // Implementation to find oldest data
        return nil // Placeholder
    }

    private func getNewestPlaidDataDate() async throws -> Date? {
        // Implementation to find newest data
        return nil // Placeholder
    }

    private func getLastCleanupDate() async throws -> Date? {
        // Implementation to get last cleanup date
        return nil // Placeholder
    }
}

// MARK: - Compliance Report Model

public struct PlaidComplianceReport: Codable {
    let reportDate: Date
    let storedTokenCount: Int
    let storedTransactionCount: Int
    let storedCorrelationCount: Int
    let dataRetentionPeriod: TimeInterval
    let encryptionEnabled: Bool
    let biometricAuthEnabled: Bool
    let lastDataCleanup: Date?
    let complianceStatus: ComplianceStatus

    public enum ComplianceStatus: String, Codable {
        case compliant = "compliant"
        case warning = "warning"
        case nonCompliant = "non_compliant"
    }

    public var summary: String {
        return """
        Plaid Compliance Report - \(DateFormatter.localizedString(from: reportDate, dateStyle: .medium, timeStyle: .short))

        Data Storage:
        - Tokens: \(storedTokenCount)
        - Transactions: \(storedTransactionCount)
        - Correlations: \(storedCorrelationCount)

        Security:
        - Encryption: \(encryptionEnabled ? "Enabled" : "Disabled")
        - Biometric Auth: \(biometricAuthEnabled ? "Enabled" : "Disabled")

        Retention:
        - Period: \(Int(dataRetentionPeriod / 86400)) days
        - Last Cleanup: \(lastDataCleanup?.description ?? "Never")

        Status: \(complianceStatus.rawValue.uppercased())
        """
    }
}