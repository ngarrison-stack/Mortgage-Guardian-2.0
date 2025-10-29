import Foundation
import LinkKit

/// Plaid configuration and setup utilities for Mortgage Guardian
public class PlaidConfiguration {

    // MARK: - Environment Configuration

    /// Plaid environment settings
    public struct Environment {
        static let current: PLKEnvironment = {
            #if DEBUG
            return .sandbox
            #else
            return .production
            #endif
        }()

        static let baseURL: String = {
            switch current {
            case .sandbox:
                return "https://sandbox.plaid.com"
            case .development:
                return "https://development.plaid.com"
            case .production:
                return "https://production.plaid.com"
            @unknown default:
                return "https://sandbox.plaid.com"
            }
        }()
    }

    // MARK: - Product Configuration

    /// Plaid products required for mortgage auditing
    public static let requiredProducts: [PLKProduct] = [
        .transactions,  // For payment tracking
        .auth,         // For account verification
        .identity      // For account holder verification
    ]

    /// Additional optional products
    public static let optionalProducts: [PLKProduct] = [
        .assets,       // For financial verification
        .liabilities   // For debt tracking
    ]

    // MARK: - Link Configuration

    /// Create Link configuration for account linking
    public static func createLinkConfiguration(
        token: String,
        onSuccess: @escaping (PLKLinkSuccess) -> Void,
        onEvent: @escaping (PLKLinkEvent) -> Void,
        onExit: @escaping (PLKLinkExit) -> Void
    ) -> PLKLinkTokenConfiguration {

        var config = PLKLinkTokenConfiguration(token: token, onSuccess: onSuccess)
        config.onEvent = onEvent
        config.onExit = onExit

        return config
    }

    /// Create Link configuration with update mode for re-authentication
    public static func createUpdateConfiguration(
        token: String,
        onSuccess: @escaping (PLKLinkSuccess) -> Void,
        onEvent: @escaping (PLKLinkEvent) -> Void,
        onExit: @escaping (PLKLinkExit) -> Void
    ) -> PLKLinkTokenConfiguration {

        var config = createLinkConfiguration(
            token: token,
            onSuccess: onSuccess,
            onEvent: onEvent,
            onExit: onExit
        )

        // Configure for update mode
        return config
    }

    // MARK: - Institution Configuration

    /// Preferred financial institutions for mortgage tracking
    public static let preferredInstitutions: [String] = [
        "ins_3", // Chase
        "ins_4", // Bank of America
        "ins_5", // Wells Fargo
        "ins_6", // Citibank
        "ins_116861", // Navy Federal Credit Union
        "ins_109512", // USAA
        // Add more as needed
    ]

    /// Institution-specific configuration
    public struct InstitutionConfig {
        let institutionId: String
        let name: String
        let supportedProducts: [PLKProduct]
        let specialHandling: Bool

        static let configurations: [String: InstitutionConfig] = [
            "ins_3": InstitutionConfig(
                institutionId: "ins_3",
                name: "Chase",
                supportedProducts: [.transactions, .auth, .identity],
                specialHandling: false
            ),
            "ins_4": InstitutionConfig(
                institutionId: "ins_4",
                name: "Bank of America",
                supportedProducts: [.transactions, .auth, .identity],
                specialHandling: true // May require additional verification
            ),
            "ins_5": InstitutionConfig(
                institutionId: "ins_5",
                name: "Wells Fargo",
                supportedProducts: [.transactions, .auth, .identity, .assets],
                specialHandling: false
            )
        ]
    }

    // MARK: - Account Type Configuration

    /// Account types relevant for mortgage tracking
    public struct AccountTypeConfig {
        static let relevantTypes: Set<PLKAccountType> = [
            .depository, // Checking, savings accounts
            .credit      // Credit cards (for balance transfers, etc.)
        ]

        static let relevantSubtypes: Set<PLKAccountSubtype> = [
            .checking,
            .savings,
            .moneyMarket,
            .cd, // Certificate of deposit
            .creditCard
        ]

        /// Check if account type is relevant for mortgage auditing
        public static func isRelevantAccount(type: PLKAccountType, subtype: PLKAccountSubtype?) -> Bool {
            guard relevantTypes.contains(type) else { return false }

            if let subtype = subtype {
                return relevantSubtypes.contains(subtype)
            }

            return true
        }
    }

    // MARK: - Transaction Filtering

    /// Categories relevant for mortgage auditing
    public struct TransactionCategories {

        // Primary mortgage-related categories
        static let mortgagePayments: Set<String> = [
            "Payment", "Loan Payment", "Mortgage Payment"
        ]

        static let housingCategories: Set<String> = [
            "Mortgage Payment",
            "Property Tax",
            "Home Insurance",
            "HOA Dues",
            "Home Improvement",
            "Utilities"
        ]

        // Fee-related categories
        static let feeCategories: Set<String> = [
            "Late Fee",
            "Service Fee",
            "Processing Fee",
            "Bank Fee"
        ]

        /// Check if transaction category is relevant for mortgage auditing
        public static func isRelevantCategory(_ category: [String]) -> Bool {
            let categorySet = Set(category.map { $0.lowercased() })

            let relevantKeywords = [
                "mortgage", "loan", "property", "tax", "insurance",
                "escrow", "hoa", "homeowner", "home"
            ]

            return relevantKeywords.contains { keyword in
                categorySet.contains { $0.contains(keyword) }
            }
        }
    }

    // MARK: - Error Handling Configuration

    /// Error codes that require specific handling
    public struct ErrorHandling {

        /// Errors that require re-authentication
        static let reAuthRequired: Set<String> = [
            "ITEM_LOGIN_REQUIRED",
            "ACCESS_NOT_GRANTED",
            "ITEM_LOCKED"
        ]

        /// Errors that are temporary and should be retried
        static let retryableErrors: Set<String> = [
            "PLANNED_MAINTENANCE",
            "INSTITUTION_DOWN",
            "RATE_LIMIT_EXCEEDED"
        ]

        /// Errors that indicate permanent failure
        static let permanentErrors: Set<String> = [
            "ITEM_NOT_FOUND",
            "ACCESS_NOT_GRANTED",
            "INSUFFICIENT_CREDENTIALS"
        ]

        /// Get retry delay for specific error
        public static func getRetryDelay(for errorCode: String) -> TimeInterval {
            switch errorCode {
            case "RATE_LIMIT_EXCEEDED":
                return 60.0 // 1 minute
            case "INSTITUTION_DOWN":
                return 300.0 // 5 minutes
            case "PLANNED_MAINTENANCE":
                return 900.0 // 15 minutes
            default:
                return 30.0 // 30 seconds default
            }
        }
    }

    // MARK: - Webhook Configuration

    /// Webhook event types to handle
    public struct WebhookConfig {

        /// Transaction webhook codes
        static let transactionWebhooks: Set<String> = [
            "INITIAL_UPDATE",
            "HISTORICAL_UPDATE",
            "DEFAULT_UPDATE",
            "TRANSACTIONS_REMOVED"
        ]

        /// Item webhook codes
        static let itemWebhooks: Set<String> = [
            "ERROR",
            "PENDING_EXPIRATION",
            "USER_PERMISSION_REVOKED",
            "WEBHOOK_UPDATE_ACKNOWLEDGED"
        ]

        /// Income webhook codes
        static let incomeWebhooks: Set<String> = [
            "PRODUCT_READY",
            "ERROR"
        ]

        /// Priority levels for different webhook types
        enum WebhookPriority {
            case high, medium, low

            static func priority(for webhookType: String, code: String) -> WebhookPriority {
                switch (webhookType, code) {
                case ("ITEM", "ERROR"):
                    return .high
                case ("TRANSACTIONS", "DEFAULT_UPDATE"):
                    return .medium
                case ("TRANSACTIONS", "INITIAL_UPDATE"):
                    return .high
                default:
                    return .low
                }
            }
        }
    }

    // MARK: - Rate Limiting Configuration

    /// API rate limiting settings
    public struct RateLimit {
        static let requestsPerSecond = 1.0
        static let requestsPerMinute = 60
        static let requestsPerHour = 3600

        /// Burst allowance for critical operations
        static let burstAllowance = 5

        /// Backoff multiplier for rate limit errors
        static let backoffMultiplier = 2.0

        /// Maximum backoff time
        static let maxBackoffTime: TimeInterval = 300.0 // 5 minutes
    }

    // MARK: - Data Retention Configuration

    /// Data retention policies for compliance
    public struct DataRetention {

        /// How long to keep transaction data (in days)
        static let transactionRetentionDays = 2555 // ~7 years

        /// How long to keep access tokens (in days)
        static let tokenRetentionDays = 365 // 1 year

        /// How long to keep audit logs (in days)
        static let auditLogRetentionDays = 2555 // ~7 years

        /// Cleanup frequency (in days)
        static let cleanupFrequencyDays = 30

        /// Data types subject to automatic cleanup
        enum DataType {
            case transactions
            case tokens
            case auditLogs
            case tempFiles

            var retentionPeriod: TimeInterval {
                switch self {
                case .transactions:
                    return TimeInterval(transactionRetentionDays * 24 * 3600)
                case .tokens:
                    return TimeInterval(tokenRetentionDays * 24 * 3600)
                case .auditLogs:
                    return TimeInterval(auditLogRetentionDays * 24 * 3600)
                case .tempFiles:
                    return TimeInterval(7 * 24 * 3600) // 1 week
                }
            }
        }
    }

    // MARK: - Security Configuration

    /// Security settings for Plaid integration
    public struct Security {

        /// Require biometric authentication for sensitive operations
        static let requireBiometricAuth = true

        /// Enable certificate pinning
        static let enableCertificatePinning = true

        /// Minimum TLS version
        static let minimumTLSVersion = "1.3"

        /// Enable request/response logging (disable in production)
        static let enableAPILogging: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()

        /// Token encryption settings
        static let tokenEncryptionRequired = true
        static let useHardwareSecurityModule = true

        /// Session timeout for cached data
        static let sessionTimeout: TimeInterval = 900 // 15 minutes

        /// Maximum failed attempts before lockout
        static let maxFailedAttempts = 3

        /// Lockout duration after failed attempts
        static let lockoutDuration: TimeInterval = 300 // 5 minutes
    }

    // MARK: - Feature Flags

    /// Feature flags for gradual rollout and testing
    public struct FeatureFlags {

        /// Enable real-time transaction monitoring
        static let enableRealTimeSync = true

        /// Enable automatic payment correlation
        static let enableAutoCorrelation = true

        /// Enable advanced transaction categorization
        static let enableAdvancedCategorization = true

        /// Enable webhook processing
        static let enableWebhooks = true

        /// Enable background sync
        static let enableBackgroundSync = true

        /// Enable transaction prediction
        static let enableTransactionPrediction = false // Experimental

        /// Enable machine learning categorization
        static let enableMLCategorization = false // Future feature

        /// Enable multi-account correlation
        static let enableMultiAccountCorrelation = true

        /// Maximum number of linked accounts
        static let maxLinkedAccounts = 10

        /// Enable beta features for testing
        static let enableBetaFeatures: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()
    }

    // MARK: - Performance Configuration

    /// Performance optimization settings
    public struct Performance {

        /// Transaction fetch batch size
        static let transactionBatchSize = 500

        /// Maximum concurrent API requests
        static let maxConcurrentRequests = 3

        /// Cache expiration time
        static let cacheExpirationTime: TimeInterval = 3600 // 1 hour

        /// Background queue priority
        static let backgroundQueueQOS = DispatchQoS.utility

        /// Enable aggressive caching
        static let enableAggressiveCaching = true

        /// Prefetch window (days)
        static let prefetchWindowDays = 90

        /// Memory warning threshold (MB)
        static let memoryWarningThreshold = 100

        /// Database vacuum frequency (days)
        static let dbVacuumFrequency = 7
    }

    // MARK: - Validation Methods

    /// Validate Plaid configuration
    public static func validateConfiguration() -> [String] {
        var errors: [String] = []

        // Check required environment variables
        if ProcessInfo.processInfo.environment["PLAID_CLIENT_ID"]?.isEmpty ?? true {
            errors.append("PLAID_CLIENT_ID environment variable not set")
        }

        if ProcessInfo.processInfo.environment["PLAID_SANDBOX_SECRET"]?.isEmpty ?? true {
            errors.append("PLAID_SANDBOX_SECRET environment variable not set")
        }

        // Check LinkKit framework availability
        if !LinkKit.isAvailable {
            errors.append("LinkKit framework not available")
        }

        // Check network connectivity requirements
        // Additional validation as needed

        return errors
    }

    /// Get configuration summary for debugging
    public static func getConfigurationSummary() -> [String: Any] {
        return [
            "environment": Environment.current.rawValue,
            "baseURL": Environment.baseURL,
            "requiredProducts": requiredProducts.map { $0.rawValue },
            "securityEnabled": Security.requireBiometricAuth,
            "webhooksEnabled": FeatureFlags.enableWebhooks,
            "backgroundSyncEnabled": FeatureFlags.enableBackgroundSync,
            "maxLinkedAccounts": FeatureFlags.maxLinkedAccounts,
            "transactionRetentionDays": DataRetention.transactionRetentionDays
        ]
    }
}

// MARK: - Extensions

extension PLKProduct {
    var displayName: String {
        switch self {
        case .transactions:
            return "Transactions"
        case .auth:
            return "Account Authentication"
        case .identity:
            return "Identity Verification"
        case .assets:
            return "Asset Verification"
        case .liabilities:
            return "Liabilities"
        case .investments:
            return "Investments"
        case .creditDetails:
            return "Credit Details"
        @unknown default:
            return "Unknown Product"
        }
    }
}

extension PLKAccountType {
    var displayName: String {
        switch self {
        case .depository:
            return "Depository"
        case .credit:
            return "Credit"
        case .loan:
            return "Loan"
        case .investment:
            return "Investment"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }
}

extension PLKAccountSubtype {
    var displayName: String {
        switch self {
        case .checking:
            return "Checking"
        case .savings:
            return "Savings"
        case .moneyMarket:
            return "Money Market"
        case .cd:
            return "Certificate of Deposit"
        case .creditCard:
            return "Credit Card"
        case .mortgage:
            return "Mortgage"
        case .lineOfCredit:
            return "Line of Credit"
        default:
            return "Other"
        }
    }
}