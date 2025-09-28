import Foundation
import Security

/// Simple Keychain helper for storing API keys and service account JSON blobs.
final class SecureKeyManager {
    static let shared = SecureKeyManager()
    private init() {}

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case itemNotFound
        case dataConversionFailed
    }

    func saveAPIKey(_ key: String, forService service: String) throws {
        guard let data = key.data(using: .utf8) else { throw KeychainError.dataConversionFailed }

        // Delete existing item if present
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)

        let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                  kSecAttrService as String: service,
                                  kSecValueData as String: data]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    func getAPIKey(forService service: String) throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { throw KeychainError.itemNotFound }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }

        guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return key
    }
}
import Foundation
import Security
import SwiftUI

enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "API key not found. Please configure your API keys in Settings."
        case .duplicateItem:
            return "API key already exists. Please update it instead."
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        case .invalidData:
            return "Invalid data format in keychain"
        }
    }
}

@MainActor
class SecureKeyManager: ObservableObject {
    static let shared = SecureKeyManager()

    @Published var hasClaudeKey = false
    @Published var hasPlaidKeys = false
    @Published var hasMarketDataKey = false

    private init() {
        checkAPIKeysStatus()
    }

    // MARK: - Save API Keys

    func saveAPIKey(_ key: String, forService service: APIService) throws {
        // First try to delete any existing key
        deleteAPIKey(forService: service)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.rawValue,
            kSecAttrAccount as String: "MortgageGuardian",
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        checkAPIKeysStatus()
    }

    // MARK: - Retrieve API Keys

    func getAPIKey(forService service: APIService) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.rawValue,
            kSecAttrAccount as String: "MortgageGuardian",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return key
    }

    // MARK: - Update API Keys

    func updateAPIKey(_ key: String, forService service: APIService) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.rawValue,
            kSecAttrAccount as String: "MortgageGuardian"
        ]

        let update: [String: Any] = [
            kSecValueData as String: key.data(using: .utf8)!
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, create it
            try saveAPIKey(key, forService: service)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }

        checkAPIKeysStatus()
    }

    // MARK: - Delete API Keys

    func deleteAPIKey(forService service: APIService) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.rawValue,
            kSecAttrAccount as String: "MortgageGuardian"
        ]

        SecItemDelete(query as CFDictionary)
        checkAPIKeysStatus()
    }

    // MARK: - Check Status

    func checkAPIKeysStatus() {
        hasClaudeKey = (try? getAPIKey(forService: .claude)) != nil
        hasPlaidKeys = ((try? getAPIKey(forService: .plaidClientId)) != nil) &&
                       ((try? getAPIKey(forService: .plaidSecret)) != nil)
        hasMarketDataKey = (try? getAPIKey(forService: .marketData)) != nil
    }

    // MARK: - Convenience Methods

    func hasAllRequiredKeys() -> Bool {
        return hasClaudeKey && hasPlaidKeys
    }

    func getMissingKeys() -> [APIService] {
        var missing: [APIService] = []

        if !hasClaudeKey {
            missing.append(.claude)
        }

        if (try? getAPIKey(forService: .plaidClientId)) == nil {
            missing.append(.plaidClientId)
        }

        if (try? getAPIKey(forService: .plaidSecret)) == nil {
            missing.append(.plaidSecret)
        }

        return missing
    }
}

// MARK: - API Service Enum

enum APIService: String, CaseIterable {
    // Core Services
    case claude = "com.mortgageguardian.api.claude"
    case plaidClientId = "com.mortgageguardian.api.plaid.client"
    case plaidSecret = "com.mortgageguardian.api.plaid.secret"

    // Market Data Services
    case marketData = "com.mortgageguardian.api.marketdata"
    case realEstate = "com.mortgageguardian.api.realestate"
    case federalReserve = "com.mortgageguardian.api.fedreserve"

    var displayName: String {
        switch self {
        case .claude:
            return "Claude API Key"
        case .plaidClientId:
            return "Plaid Client ID"
        case .plaidSecret:
            return "Plaid Secret"
        case .marketData:
            return "Market Data API"
        case .realEstate:
            return "Real Estate API"
        case .federalReserve:
            return "Federal Reserve API"
        }
    }

    var description: String {
        switch self {
        case .claude:
            return "Required for AI-powered document analysis"
        case .plaidClientId, .plaidSecret:
            return "Required for bank account integration"
        case .marketData:
            return "Optional: For real-time market data"
        case .realEstate:
            return "Optional: For property valuations"
        case .federalReserve:
            return "Optional: For interest rate data"
        }
    }

    var isRequired: Bool {
        switch self {
        case .claude, .plaidClientId, .plaidSecret:
            return true
        default:
            return false
        }
    }

    static let baseURLs: [APIService: String] = [
        .claude: "https://api.anthropic.com/v1",
        .realEstate: "https://api.realestatedata.com/v1",
        .marketData: "https://api.marketdata.com/v1",
        .federalReserve: "https://api.federalreserve.gov/v1"
    ]
}