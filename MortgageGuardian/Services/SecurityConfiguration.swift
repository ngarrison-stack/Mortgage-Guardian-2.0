import Foundation
import Security

/// Security configuration and constants for Mortgage Guardian app
public struct SecurityConfiguration {

    // MARK: - Encryption Configuration

    /// AES encryption key size (256-bit)
    public static let encryptionKeySize = 256

    /// Default encryption context for general data
    public static let defaultEncryptionContext = "general"

    /// Document encryption context prefix
    public static let documentEncryptionPrefix = "document:"

    /// User data encryption context
    public static let userDataEncryptionContext = "user_data"

    /// API token encryption context
    public static let apiTokenEncryptionContext = "api_tokens"

    // MARK: - Session Configuration

    /// Default session timeout (5 minutes)
    public static let defaultSessionTimeout: TimeInterval = 300

    /// Maximum session duration (2 hours)
    public static let maxSessionDuration: TimeInterval = 7200

    /// Session extension interval (30 seconds)
    public static let sessionExtensionInterval: TimeInterval = 30

    // MARK: - Biometric Authentication Configuration

    /// Biometric authentication prompt for document access
    public static let biometricPromptDocumentAccess = "Authenticate to access your mortgage documents"

    /// Biometric authentication prompt for settings
    public static let biometricPromptSettings = "Authenticate to modify security settings"

    /// Biometric authentication prompt for export
    public static let biometricPromptExport = "Authenticate to export documents"

    /// Biometric authentication prompt for API access
    public static let biometricPromptAPIAccess = "Authenticate to access secure API"

    // MARK: - Keychain Configuration

    /// Keychain service identifier
    public static let keychainService = "com.mortgageguardian.keychain"

    /// Keychain access group (for app extensions)
    public static let keychainAccessGroup = "group.com.mortgageguardian.shared"

    /// Document keychain key prefix
    public static let documentKeychainPrefix = "mg_doc_"

    /// API token keychain key prefix
    public static let apiTokenKeychainPrefix = "mg_api_"

    /// User data keychain key prefix
    public static let userDataKeychainPrefix = "mg_user_"

    /// Encryption key keychain prefix
    public static let encryptionKeyPrefix = "mg_key_"

    // MARK: - Network Security Configuration

    /// Pinned certificate hashes for production API
    public static let pinnedCertificateHashes: [String: [String]] = [
        "api.mortgageguardian.com": [
            // Add actual certificate hashes in production
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
        ],
        "cdn.mortgageguardian.com": [
            "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=",
            "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD="
        ]
    ]

    /// API request timeout (30 seconds)
    public static let apiRequestTimeout: TimeInterval = 30

    /// API request retry attempts
    public static let apiRetryAttempts = 3

    /// API rate limiting - requests per minute
    public static let apiRateLimit = 60

    // MARK: - Device Security Configuration

    /// Jailbreak detection paths
    public static let jailbreakDetectionPaths = [
        "/Applications/Cydia.app",
        "/Applications/blackra1n.app",
        "/Applications/FakeCarrier.app",
        "/Applications/Icy.app",
        "/Applications/IntelliScreen.app",
        "/Applications/MxTube.app",
        "/Applications/RockApp.app",
        "/Applications/SBSettings.app",
        "/Applications/WinterBoard.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
        "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
        "/private/var/lib/apt/",
        "/private/var/lib/cydia/",
        "/private/var/mobile/Library/SBSettings/Themes",
        "/private/var/stash",
        "/private/var/tmp/cydia.log",
        "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
        "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        "/usr/bin/sshd",
        "/usr/libexec/sftp-server",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/bin/bash",
        "/Library/MobileSubstrate/MobileSubstrate.dylib"
    ]

    /// Suspicious file system paths to monitor
    public static let suspiciousFilePaths = [
        "/var/tmp/cydia.log",
        "/var/lib/cydia",
        "/var/cache/apt",
        "/etc/apt",
        "/tmp/cydia.log",
        "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist"
    ]

    // MARK: - Data Retention Configuration

    /// Maximum document retention period (7 years for mortgage documents)
    public static let maxDocumentRetentionDays = 2555 // 7 years

    /// Audit log retention period (1 year)
    public static let auditLogRetentionDays = 365

    /// Session log retention period (30 days)
    public static let sessionLogRetentionDays = 30

    /// Temporary file cleanup interval (1 hour)
    public static let tempFileCleanupInterval: TimeInterval = 3600

    // MARK: - Compliance Configuration

    /// GDPR data processing purposes
    public static let gdprProcessingPurposes = [
        "mortgage_document_management",
        "financial_analysis",
        "audit_compliance",
        "security_monitoring"
    ]

    /// Data classification levels
    public enum DataClassification: String, CaseIterable {
        case publicData = "public"
        case internalData = "internal"
        case confidentialData = "confidential"
        case restrictedData = "restricted"

        var encryptionRequired: Bool {
            switch self {
            case .publicData, .internalData:
                return false
            case .confidentialData, .restrictedData:
                return true
            }
        }

        var biometricRequired: Bool {
            switch self {
            case .publicData, .internalData, .confidentialData:
                return false
            case .restrictedData:
                return true
            }
        }
    }

    // MARK: - Security Policies

    /// Minimum iOS version required for security features
    public static let minimumIOSVersion = "14.0"

    /// Required security features for app operation
    public static let requiredSecurityFeatures: [SecurityFeature] = [
        .devicePasscode,
        .keychainAccess,
        .secureEnclave
    ]

    /// Optional security features that enhance protection
    public static let optionalSecurityFeatures: [SecurityFeature] = [
        .biometricAuthentication,
        .faceID,
        .touchID
    ]

    public enum SecurityFeature {
        case devicePasscode
        case keychainAccess
        case secureEnclave
        case biometricAuthentication
        case faceID
        case touchID
    }

    // MARK: - Error Messages

    public struct ErrorMessages {
        public static let biometricNotAvailable = "Biometric authentication is not available on this device. Please ensure you have Face ID or Touch ID enabled in Settings."
        public static let biometricNotEnrolled = "No biometric credentials are enrolled. Please set up Face ID or Touch ID in Settings."
        public static let deviceNotSecure = "This device does not meet the minimum security requirements. Please enable a device passcode."
        public static let jailbrokenDevice = "This app cannot run on jailbroken devices for security reasons."
        public static let networkSecurityViolation = "A network security violation was detected. Please check your connection."
        public static let sessionExpired = "Your session has expired for security reasons. Please authenticate again."
        public static let encryptionFailed = "Failed to encrypt sensitive data. Please try again."
        public static let decryptionFailed = "Failed to decrypt data. The data may be corrupted or compromised."
        public static let certificatePinningFailed = "Server certificate validation failed. This may indicate a security threat."
    }

    // MARK: - Security Headers

    public struct SecurityHeaders {
        public static let userAgent = "MortgageGuardian/1.0 (iOS; Secure)"
        public static let contentType = "application/json; charset=utf-8"
        public static let acceptEncoding = "gzip, deflate, br"
        public static let cacheControl = "no-cache, no-store, must-revalidate"
        public static let pragma = "no-cache"
        public static let expires = "0"

        /// Generate security headers for API requests
        public static func generateHeaders() -> [String: String] {
            return [
                "User-Agent": userAgent,
                "Content-Type": contentType,
                "Accept-Encoding": acceptEncoding,
                "Cache-Control": cacheControl,
                "Pragma": pragma,
                "Expires": expires,
                "X-Content-Type-Options": "nosniff",
                "X-Frame-Options": "DENY",
                "X-XSS-Protection": "1; mode=block"
            ]
        }
    }

    // MARK: - Audit Configuration

    public struct AuditConfiguration {
        /// Events that require immediate logging
        public static let criticalEvents: Set<String> = [
            "biometric_auth_failure",
            "session_expired",
            "device_compromised",
            "certificate_pinning_failure",
            "network_security_violation",
            "unauthorized_access_attempt"
        ]

        /// Events that can be batched
        public static let standardEvents: Set<String> = [
            "biometric_auth_success",
            "session_started",
            "data_encrypted",
            "data_decrypted",
            "key_generated"
        ]

        /// Maximum audit log entry size
        public static let maxLogEntrySize = 1024 // bytes

        /// Audit log batch size for transmission
        public static let auditLogBatchSize = 50

        /// Audit log transmission interval
        public static let auditLogTransmissionInterval: TimeInterval = 300 // 5 minutes
    }

    // MARK: - Development vs Production Configuration

    #if DEBUG
    /// Development configuration (less restrictive)
    public static let isDevelopmentMode = true
    public static let allowInsecureConnections = true
    public static let enableSecurityLogging = true
    public static let enableDetailedAuditLogs = true
    #else
    /// Production configuration (strict security)
    public static let isDevelopmentMode = false
    public static let allowInsecureConnections = false
    public static let enableSecurityLogging = false
    public static let enableDetailedAuditLogs = false
    #endif

    // MARK: - Validation Methods

    /// Validate if the current iOS version meets minimum requirements
    public static func validateIOSVersion() -> Bool {
        let systemVersion = UIDevice.current.systemVersion
        return systemVersion.compare(minimumIOSVersion, options: .numeric) != .orderedAscending
    }

    /// Check if all required security features are available
    public static func validateSecurityFeatures() -> [SecurityFeature] {
        var missingFeatures: [SecurityFeature] = []

        for feature in requiredSecurityFeatures {
            if !isSecurityFeatureAvailable(feature) {
                missingFeatures.append(feature)
            }
        }

        return missingFeatures
    }

    /// Check if a specific security feature is available
    public static func isSecurityFeatureAvailable(_ feature: SecurityFeature) -> Bool {
        switch feature {
        case .devicePasscode:
            let context = LAContext()
            return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)

        case .keychainAccess:
            // Test keychain access
            let testKey = "security_test_key"
            let testData = Data("test".utf8)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: testKey,
                kSecValueData as String: testData
            ]

            SecItemDelete(query as CFDictionary)
            let status = SecItemAdd(query as CFDictionary, nil)
            SecItemDelete(query as CFDictionary)

            return status == errSecSuccess

        case .secureEnclave:
            // Check for Secure Enclave availability (A7 chip and later)
            return TARGET_OS_SIMULATOR == 0 // Secure Enclave not available in simulator

        case .biometricAuthentication:
            let context = LAContext()
            return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)

        case .faceID:
            let context = LAContext()
            _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            return context.biometryType == .faceID

        case .touchID:
            let context = LAContext()
            _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            return context.biometryType == .touchID
        }
    }
}

// MARK: - Security Policy Enforcement

public class SecurityPolicyEnforcer {

    /// Enforce minimum security requirements
    public static func enforceSecurityPolicies() throws {
        // Check iOS version
        guard SecurityConfiguration.validateIOSVersion() else {
            throw SecurityPolicyError.insufficientIOSVersion
        }

        // Check required security features
        let missingFeatures = SecurityConfiguration.validateSecurityFeatures()
        guard missingFeatures.isEmpty else {
            throw SecurityPolicyError.missingSecurityFeatures(missingFeatures)
        }

        // Additional policy checks can be added here
    }

    /// Validate data classification compliance
    public static func validateDataClassification(
        _ classification: SecurityConfiguration.DataClassification,
        encryptionEnabled: Bool,
        biometricRequired: Bool
    ) throws {
        if classification.encryptionRequired && !encryptionEnabled {
            throw SecurityPolicyError.encryptionRequired(classification)
        }

        if classification.biometricRequired && !biometricRequired {
            throw SecurityPolicyError.biometricRequired(classification)
        }
    }
}

// MARK: - Security Policy Errors

public enum SecurityPolicyError: LocalizedError {
    case insufficientIOSVersion
    case missingSecurityFeatures([SecurityConfiguration.SecurityFeature])
    case encryptionRequired(SecurityConfiguration.DataClassification)
    case biometricRequired(SecurityConfiguration.DataClassification)

    public var errorDescription: String? {
        switch self {
        case .insufficientIOSVersion:
            return "This app requires iOS \(SecurityConfiguration.minimumIOSVersion) or later."

        case .missingSecurityFeatures(let features):
            let featureNames = features.map { "\($0)" }.joined(separator: ", ")
            return "Missing required security features: \(featureNames)"

        case .encryptionRequired(let classification):
            return "Encryption is required for \(classification.rawValue) data classification."

        case .biometricRequired(let classification):
            return "Biometric authentication is required for \(classification.rawValue) data classification."
        }
    }
}

// MARK: - Required Imports

import LocalAuthentication
import UIKit